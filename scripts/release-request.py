#!/usr/bin/env python3
"""One-shot v2.10.0 release; no recovery, asset replacement, or tag mutation.

GitHub CLI uses the job's GH_TOKEN. Tests mock all remote calls.
"""
import hashlib
from http.client import IncompleteRead
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
from urllib.parse import quote
import time
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

REPOSITORY = 'charlzyx/znvm'
VERSION = 'v2.10.0'
MAX_ASSET_BYTES = 128 * 1024 * 1024
MAX_MANIFEST_BYTES = 4096
TARGETS = ('x86_64-linux-musl', 'aarch64-linux-musl', 'x86_64-macos',
           'aarch64-macos', 'x86_64-windows', 'aarch64-windows')
ASSETS = tuple(f'znvm-{VERSION}-{t}' + ('.zip' if 'windows' in t else '') for t in TARGETS)
NAMES = set(ASSETS) | {'SHA256SUMS'}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def api(path, method='GET', data=None, optional=False):
    cmd = ['gh', 'api', f'repos/{REPOSITORY}/{path}', '--method', method]
    if data is not None:
        cmd += ['--input', '-']
    p = subprocess.run(cmd, input=json.dumps(data).encode() if data is not None else None,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode:
        if optional and method == 'GET' and b'HTTP 404' in p.stderr:
            return None
        raise RuntimeError(f'GitHub API {method} {path} failed: {p.stderr.decode()}')
    return json.loads(p.stdout) if p.stdout.strip() else None


def context():
    require(os.environ.get('GITHUB_REPOSITORY') == REPOSITORY and os.environ.get('GH_REPO') == REPOSITORY,
            'Only the literal charlzyx/znvm repository is authorized')
    require(os.environ.get('GITHUB_EVENT_NAME') == 'push', 'Only push events allowed')
    require(os.environ.get('GITHUB_REF') == 'refs/heads/main', 'Only main allowed')
    sha = os.environ.get('GITHUB_SHA', '')
    require(re.fullmatch('[0-9a-f]{40}', sha), 'Expected exact commit SHA')
    marker = json.loads(Path('release-request.json').read_text())
    require(marker == {'enabled': True, 'version': '2.10.0'} and marker['enabled'] is True,
            'Request must be literal enabled=true/version=2.10.0 only')
    head = subprocess.run(['git', 'rev-parse', '--verify', 'HEAD^{commit}'],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(head.returncode == 0 and head.stdout.decode().strip() == sha,
            'Checked-out HEAD differs from GITHUB_SHA')
    verify_versions()
    return sha


def verify_versions():
    checks = {
        'src/main.zig': 'const ZNVM_VERSION = "v2.10.0";',
        'src/commands.zig': '"v2.10.0"',
        'install.sh': 'ZNVM_VERSION="v2.10.0"',
        'install-as-nvm.sh': 'ZNVM_VERSION="v2.10.0"',
        'website/src/components/hero.tsx': 'const version = "v2.10.0";',
    }
    for path, expected in checks.items():
        require(expected in Path(path).read_text(), f'Version mismatch: {path}')
    source = Path('install-as-nvm.sh').read_bytes()
    for path in ('website/public/install.sh', 'website/public/install-as-nvm.sh'):
        require(Path(path).read_bytes() == source, f'Installer not synchronized: {path}')
    for path in ('.github/workflows/release.yml', '.github/workflows/release-request.yml'):
        require('version: 0.17.0' in Path(path).read_text(), f'Zig pin mismatch: {path}')


def check_main(sha):
    obj = api('git/ref/heads/main')['object']
    require(obj.get('type') == 'commit' and obj.get('sha') == sha,
            'main moved; stop release without modifying tags/assets')


def tag_commit(tag):
    obj = tag['object']
    # Support ordinary annotated tags without accepting chains or foreign objects.
    if obj['type'] == 'tag':
        obj = api('git/tags/' + obj['sha'])['object']
    require(obj['type'] == 'commit', 'Tag does not point to a commit')
    return obj['sha']


def release_identity(release, sha, draft, release_id=None):
    ident = release.get('id')
    require(type(ident) is int and ident > 0, 'Invalid release ID')
    require(release_id is None or ident == release_id, 'Release ID changed')
    require(release.get('tag_name') == VERSION and release.get('target_commitish') == sha,
            'Release source identity changed')
    require(release.get('draft') is draft and release.get('prerelease') is False,
            'Unexpected release lifecycle state')
    require(type(release.get('assets')) is list, 'Invalid release asset collection')
    return ident


def asset_snapshot(release, expected):
    records = {}
    ids = set()
    for asset in release['assets']:
        ident, name, size = asset.get('id'), asset.get('name'), asset.get('size')
        require(type(ident) is int and ident > 0 and ident not in ids, 'Invalid/duplicate asset ID')
        require(name in expected and name not in records, 'Unexpected/duplicate asset name')
        require(type(size) is int and size >= 0 and asset.get('state') == 'uploaded', 'Incomplete asset upload')
        digest = asset.get('digest')
        require(digest is None or digest == 'sha256:' + expected[name], 'Remote asset digest differs')
        records[name] = {'id': ident, 'name': name, 'size': size, 'sha256': expected[name]}
        ids.add(ident)
    require(set(records) == set(expected), 'Release asset set is incomplete/unexpected')
    return records


def find_release():
    # GET /releases/tags documents published releases only. List with the current
    # token to detect drafts too, including duplicate drafts sharing this tag.
    matches = []
    for page in range(1, 101):
        releases = api(f'releases?per_page=100&page={page}')
        require(type(releases) is list, 'Invalid release listing')
        matches.extend(item for item in releases if item.get('tag_name') == VERSION)
        require(len(matches) <= 1, 'Multiple releases use requested tag; stop')
        if len(releases) < 100:
            return matches[0] if matches else None
    raise RuntimeError('Release listing exceeded safety bound; cannot prove absence')


def state(sha):
    tag = api(f'git/ref/tags/{VERSION}', optional=True)
    release = find_release()
    if tag is None and release is None:
        return None
    require(tag is not None and release is not None,
            'Partial release/tag exists; explicit operator recovery required')
    require(tag_commit(tag) == sha, 'Existing tag points to a different commit')
    release_identity(release, sha, False)
    names = [asset['name'] for asset in release['assets']]
    require(len(names) == 7 and set(names) == NAMES, 'Existing release asset set is incomplete/unexpected')
    return release


def check_tag_owner(release_id, sha, draft):
    # A changed tag lookup is a stop signal, never a new upload/download target.
    alias = find_release()
    require(alias is not None, 'Owned release disappeared')
    release_identity(alias, sha, draft, release_id)
    published_alias = api(f'releases/tags/{VERSION}', optional=draft)
    if published_alias is not None:
        release_identity(published_alias, sha, draft, release_id)
    else:
        require(draft, 'Published tag lookup missing')
    tag = api(f'git/ref/tags/{VERSION}', optional=True)
    require((draft and tag is None) or (tag is not None and tag_commit(tag) == sha),
            'Tag source changed')


def upload_asset(release_id, path, digest):
    path = Path(path)
    url = f'https://uploads.github.com/repos/{REPOSITORY}/releases/{release_id}/assets?name={quote(path.name, safe="")}'
    # Direct numeric release endpoint, one request, never --clobber/retry.
    p = subprocess.run(['gh', 'api', url, '--method', 'POST',
                        '--header', 'Content-Type: application/octet-stream', '--input', str(path)],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(p.returncode == 0, f'Asset upload failed; retain draft for recovery: {p.stderr.decode()}')
    asset = json.loads(p.stdout)
    record = asset_snapshot({'assets': [asset]}, {path.name: digest})[path.name]
    require(record['size'] == path.stat().st_size, 'Uploaded asset size differs')
    print(json.dumps({'uploaded_asset': record, 'release_id': release_id}), flush=True)
    return record


def local_hashes(directory):
    directory = Path(directory)
    require({p.name for p in directory.iterdir()} == NAMES, 'Expected exactly seven staged files')
    for name in NAMES:
        info = (directory / name).lstat()
        require(stat.S_ISREG(info.st_mode), f'Staged asset is not a regular non-symlink file: {name}')
        limit = MAX_MANIFEST_BYTES if name == 'SHA256SUMS' else MAX_ASSET_BYTES
        require(0 < info.st_size <= limit, f'Staged asset size is outside bounds: {name}')
    expected = {}
    lines = (directory / 'SHA256SUMS').read_text().splitlines()
    require(len(lines) == 6, 'Expected six checksum records')
    for line in lines:
        m = re.fullmatch(r'([a-f0-9]{64})  (\S+)', line)
        require(m is not None, 'Malformed checksum record')
        digest, name = m.groups()
        require(name in ASSETS and name not in expected, 'Unknown/duplicate checksum filename')
        expected[name] = digest
    require(set(expected) == set(ASSETS), 'Missing checksum')
    for name, digest in expected.items():
        p = directory / name
        require(p.is_file() and not p.is_symlink(), 'Staged asset is not a regular file')
        require(hashlib.sha256(p.read_bytes()).hexdigest() == digest, f'Hash mismatch: {name}')
    expected['SHA256SUMS'] = hashlib.sha256((directory / 'SHA256SUMS').read_bytes()).hexdigest()
    return expected


def verify_remote(release_id, sha, draft, expected, records):
    current = api(f'releases/{release_id}')
    release_identity(current, sha, draft, release_id)
    require(asset_snapshot(current, expected) == records, 'Asset identity/size changed')
    with tempfile.TemporaryDirectory(prefix='znvm-release-verify-') as temp:
        for name, record in records.items():
            destination = Path(temp) / name
            with destination.open('wb') as output:
                p = subprocess.run(['gh', 'api',
                    f'repos/{REPOSITORY}/releases/assets/{record["id"]}',
                    '--header', 'Accept: application/octet-stream'], stdout=output, stderr=subprocess.PIPE)
            require(p.returncode == 0, f'Asset ID download failed: {p.stderr.decode()}')
            require(destination.stat().st_size == record['size'], 'Downloaded asset size differs')
        require(local_hashes(temp) == expected, 'Downloaded asset IDs differ from tested build')
    current = api(f'releases/{release_id}')
    release_identity(current, sha, draft, release_id)
    require(asset_snapshot(current, expected) == records, 'Asset identity changed during verification')


def verify_public(expected):
    # Public URLs must work without the job token after publication. CDN propagation
    # and connection failures are retryable reads; bad hashes and auth errors are not.
    attempts = 5
    for name, digest in expected.items():
        url = f'https://github.com/{REPOSITORY}/releases/download/{VERSION}/{name}'
        for attempt in range(attempts):
            try:
                with urlopen(url, timeout=120) as response:
                    actual = hashlib.sha256()
                    for chunk in iter(lambda: response.read(1024 * 1024), b''):
                        actual.update(chunk)
                require(actual.hexdigest() == digest, f'Public download hash mismatch: {name}')
                break
            except HTTPError as error:
                if error.code != 404 and not 500 <= error.code < 600:
                    raise
                if attempt == attempts - 1:
                    raise
            except (URLError, ConnectionError, TimeoutError, IncompleteRead):
                if attempt == attempts - 1:
                    raise
            # 5 total attempts per exact URL, with at most 33 seconds of backoff.
            time.sleep(min(3 * 2 ** attempt, 12))


def publish(directory):
    sha = context()
    expected = local_hashes(directory)
    check_main(sha)
    existing = state(sha)
    if existing is not None:
        release_id = release_identity(existing, sha, False)
        records = asset_snapshot(existing, expected)
        verify_remote(release_id, sha, False, expected, records)
        check_tag_owner(release_id, sha, False)
        verify_public(expected)
        check_tag_owner(release_id, sha, False)
        check_main(sha)
        print('Existing exact release ID, source and all tested asset IDs/bytes match; no changes.')
        return
    check_main(sha)
    require(state(sha) is None, 'Release appeared concurrently; stop')
    release = api('releases', 'POST', {
        'tag_name': VERSION, 'target_commitish': sha, 'name': VERSION, 'draft': True,
        'prerelease': False, 'body': 'Windows x64 and ARM64 native support. See CHANGELOG.md at this tag.'})
    release_id = release_identity(release, sha, True)
    require(release['assets'] == [], 'Created draft unexpectedly contains assets')
    # Flush the ownership receipt before any follow-up writes. Failures retain draft.
    print(json.dumps({'created_release_id': release_id, 'tag': VERSION, 'source_sha': sha}), flush=True)
    records = {}
    for name in sorted(NAMES):
        check_tag_owner(release_id, sha, True)
        records[name] = upload_asset(release_id, Path(directory) / name, expected[name])
    verify_remote(release_id, sha, True, expected, records)
    # Re-read the SAME release and exact asset IDs immediately before publication.
    current = api(f'releases/{release_id}')
    release_identity(current, sha, True, release_id)
    require(asset_snapshot(current, expected) == records, 'Draft asset IDs changed before publication')
    check_tag_owner(release_id, sha, True)
    check_main(sha)
    published = api(f'releases/{release_id}', 'PATCH', {'draft': False, 'make_latest': 'true'})
    release_identity(published, sha, False, release_id)
    require(asset_snapshot(published, expected) == records, 'Published asset IDs changed')
    verify_remote(release_id, sha, False, expected, records)
    check_tag_owner(release_id, sha, False)
    verify_public(expected)
    check_tag_owner(release_id, sha, False)
    check_main(sha)
    print(f'Published verified release ID {release_id}, {VERSION} at {sha}; seven exact asset IDs, no main edits.')


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['guard']:
            sha = context()
            check_main(sha)
            existing = state(sha)
            print('Complete existing release will require byte verification.' if existing else 'Read-only preflight passed; draft visibility/absence must be rechecked with publish token.')
        elif len(sys.argv) == 3 and sys.argv[1] == 'publish':
            publish(sys.argv[2])
        else:
            raise RuntimeError('Usage: release-request.py guard | publish <asset-directory>')
    except Exception as error:
        print(f'RELEASE STOPPED: {error}', file=sys.stderr)
        sys.exit(1)
