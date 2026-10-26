#!/usr/bin/env python3
"""Recover only the empty draft whose creation receipt is in run 40361365360/attempt 2.
No create/delete/tag writes, replacement uploads, or old partial-upload recovery.
"""
import hashlib
import tempfile
import zipfile
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time

spec = importlib.util.spec_from_file_location('original_release', Path(__file__).with_name('release-request.py'))
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
SOURCE = 'b0f45c7b661e63d93055ae7e809bc877c7af5579'
RELEASE_ID = 424643933
CREATED = '2026-10-26T19:00:21Z'
RUN = 40361365360
ARTIFACT = 12668716726
DIGEST = 'sha256:1395d058abc018aac1702478a01278bc2613c5a8762fede8dbb0aced1f56d3a9'
FILES = frozenset({'.github/workflows/recover-release-2.10.0.yml',
                  'scripts/recover-release-2.10.0.py', 'scripts/test-recover-release-2.10.0.py',
                  'release-recovery-2.10.0.json'})
MARKER = {'enabled': True, 'release_id': RELEASE_ID, 'source_sha': SOURCE,
          'candidate_run_id': RUN, 'candidate_artifact_id': ARTIFACT, 'candidate_digest': DIGEST}


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


def context():
    r.require(os.environ.get('GITHUB_REPOSITORY') == r.REPOSITORY and
              os.environ.get('GH_REPO') == r.REPOSITORY, 'Wrong repository')
    r.require(os.environ.get('GITHUB_EVENT_NAME') == 'push' and
              os.environ.get('GITHUB_REF') == 'refs/heads/main', 'Only main push permitted')
    control = os.environ.get('GITHUB_SHA', '')
    r.require(git('rev-parse', 'HEAD') == control and control != SOURCE, 'Invalid recovery checkout')
    r.require(git('show', '-s', '--format=%P', control) == SOURCE, 'Recovery must have one parent: source')
    changes = git('diff-tree', '--no-commit-id', '--name-status', '-r', control).splitlines()
    r.require(set(changes) == {'A\t' + p for p in FILES}, 'Recovery diff is not the exact four added files')
    marker = json.loads(Path('release-recovery-2.10.0.json').read_text())
    r.require(marker == MARKER and marker.get('enabled') is True and
              type(marker.get('release_id')) is int, 'Recovery marker changed')
    r.verify_versions()
    r.check_main(control)
    return control


def source_evidence():
    # Exact source workflow paths/events, not names or a PR-head success.
    for path, ident in [('.github/workflows/ci.yml', 40361365007),
                        ('.github/workflows/linux-compat.yml', 40361365436),
                        ('.github/workflows/windows.yml', 40361365067)]:
        run = r.api(f'actions/runs/{ident}')
        r.require(run.get('head_sha') == SOURCE and run.get('path') == path and
                  run.get('event') == 'push' and run.get('head_branch') == 'main' and
                  run.get('status') == 'completed' and run.get('conclusion') == 'success',
                  'Source CI evidence changed')
    run = r.api(f'actions/runs/{RUN}')
    r.require(run.get('head_sha') == SOURCE and run.get('path') == '.github/workflows/release-request.yml'
              and run.get('event') == 'push' and run.get('head_branch') == 'main'
              and run.get('run_attempt') == 2 and run.get('status') == 'completed'
              and run.get('conclusion') == 'failure', 'Original publication attempt changed')
    jobs = r.api(f'actions/runs/{RUN}/attempts/1/jobs?per_page=100')['jobs']
    required = {121707468755: 'Build (x86_64-windows-gnu)',
                121707468758: 'Build (aarch64-windows-gnu)',
                121707468761: 'Build (x86_64-macos)',
                121707468766: 'Build (aarch64-linux-musl)',
                121707468900: 'Build (aarch64-macos)',
                121707469163: 'Build (x86_64-linux-musl)',
                121710034671: 'Assemble and verify the six build artifacts',
                121710125195: 'Test exact Windows release candidate (x64)',
                121710125414: 'Test exact Windows release candidate (arm64)'}
    for ident, name in required.items():
        found = [j for j in jobs if j.get('id') == ident]
        r.require(len(found) == 1 and found[0].get('name') == name and
                  found[0].get('status') == 'completed' and found[0].get('conclusion') == 'success',
                  'Candidate native test evidence changed')
    artifact = r.api(f'actions/artifacts/{ARTIFACT}')
    r.require(artifact.get('id') == ARTIFACT and artifact.get('name') == 'release-candidate' and
              artifact.get('expired') is False and artifact.get('digest') == DIGEST and
              artifact.get('workflow_run', {}).get('id') == RUN and
              artifact.get('workflow_run', {}).get('head_sha') == SOURCE,
              'Candidate artifact identity/digest changed')


def download(directory):
    """Download the original immutable artifact archive; enforce its full receipt digest."""
    control = context()
    source_evidence()
    owned(True, {}, {})
    wait_listing(control, True)
    destination = Path(directory)
    r.require(not destination.exists(), 'Candidate destination already exists')
    with tempfile.TemporaryDirectory(prefix='znvm-owned-candidate-') as temporary:
        archive = Path(temporary) / 'candidate.zip'
        with archive.open('wb') as output:
            result = subprocess.run(['gh', 'api',
                f'repos/{r.REPOSITORY}/actions/artifacts/{ARTIFACT}/zip'],
                stdout=output, stderr=subprocess.PIPE)
        r.require(result.returncode == 0, 'Candidate archive download failed')
        r.require(archive.stat().st_size == 7669311 and
                  'sha256:' + hashlib.sha256(archive.read_bytes()).hexdigest() == DIGEST,
                  'Candidate archive receipt digest/size differs')
        with zipfile.ZipFile(archive) as package:
            entries = package.infolist()
            r.require(len(entries) == 7 and {e.filename for e in entries} == r.NAMES,
                      'Candidate archive entry set differs')
            for entry in entries:
                limit = r.MAX_MANIFEST_BYTES if entry.filename == 'SHA256SUMS' else r.MAX_ASSET_BYTES
                r.require(not entry.is_dir() and not entry.flag_bits & 1 and
                          0 < entry.file_size <= limit,
                          'Invalid candidate archive entry')
            destination.mkdir()
            for entry in entries:
                # Exact flat allowlist; no extractall or archive filesystem metadata.
                (destination / entry.filename).write_bytes(package.read(entry))
    r.local_hashes(destination)
    r.check_main(control)


def identity(draft):
    release = r.api(f'releases/{RELEASE_ID}')
    r.release_identity(release, SOURCE, draft, RELEASE_ID)
    r.require(release.get('author', {}).get('id') == 41898282 and
              release.get('author', {}).get('login') == 'github-actions[bot]' and
              release.get('created_at') == CREATED, 'Draft creation receipt identity changed')
    return release


def owned(draft, expected, records):
    release = identity(draft)
    r.require(r.asset_snapshot(release, expected) == records, 'Owned asset set/IDs changed')
    return release


def wait_listing(control, draft):
    # A missing list item NEVER means absence. Exact ID remains authoritative;
    # bounded read-only waiting preserves duplicate/alias conflict detection.
    for attempt in range(5):
        r.check_main(control)
        identity(draft)
        release = r.find_release()
        if release is not None:
            r.release_identity(release, SOURCE, draft, RELEASE_ID)
            alias = r.api(f'releases/tags/{r.VERSION}', optional=draft)
            if alias is not None:
                r.release_identity(alias, SOURCE, draft, RELEASE_ID)
            else:
                r.require(draft, 'Published alias missing')
            tag = r.api(f'git/ref/tags/{r.VERSION}', optional=True)
            r.require((draft and tag is None) or
                      (tag is not None and r.tag_commit(tag) == SOURCE), 'Tag source changed')
            return
        if attempt < 4:
            time.sleep(3)
    raise RuntimeError('Owned release not visible in listing; retain draft, no retry writes')


def recover(directory):
    control = context()
    source_evidence()
    expected = r.local_hashes(directory)
    owned(True, {}, {})  # This entry point NEVER resumes an old partial upload.
    wait_listing(control, True)
    records = {}
    for name in sorted(r.NAMES):
        wait_listing(control, True)
        owned(True, {n: expected[n] for n in records}, records)
        r.check_main(control)
        records[name] = r.upload_asset(RELEASE_ID, Path(directory) / name, expected[name])
    r.verify_remote(RELEASE_ID, SOURCE, True, expected, records)
    wait_listing(control, True)
    owned(True, expected, records)
    source_evidence()
    r.check_main(control)
    published = r.api(f'releases/{RELEASE_ID}', 'PATCH', {'draft': False, 'make_latest': 'true'})
    r.release_identity(published, SOURCE, False, RELEASE_ID)
    r.require(r.asset_snapshot(published, expected) == records, 'Published asset IDs changed')
    r.verify_remote(RELEASE_ID, SOURCE, False, expected, records)
    wait_listing(control, False)
    owned(False, expected, records)
    r.verify_public(expected)
    wait_listing(control, False)
    owned(False, expected, records)
    r.check_main(control)
    print(json.dumps({'published_release_id': RELEASE_ID, 'binary_source_sha': SOURCE,
                      'recovery_control_sha': control, 'verified_public_assets': records}), flush=True)


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['preflight']:
            control = context()
            source_evidence()
            owned(True, {}, {})
            wait_listing(control, True)
            print('Exact empty owned draft and candidate evidence verified; no writes.')
        elif len(sys.argv) == 3 and sys.argv[1] == 'download':
            download(sys.argv[2])
        elif len(sys.argv) == 3 and sys.argv[1] == 'recover':
            recover(sys.argv[2])
        else:
            raise RuntimeError('Usage: recover-release-2.10.0.py preflight | download <candidate> | recover <candidate>')
    except Exception as error:
        print(f'RECOVERY STOPPED: {error}', file=sys.stderr)
        sys.exit(1)
