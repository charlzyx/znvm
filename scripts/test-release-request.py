#!/usr/bin/env python3
"""Pure fixtures: never creates tags/releases or calls GitHub."""
import hashlib
import io
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release_request', Path(__file__).with_name('release-request.py'))
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
SHA = 'a' * 40
HASHES = {name: '0' * 64 for name in r.NAMES}


def release_fixture(draft=False, assets=True):
    return {'id': 42, 'tag_name': r.VERSION, 'target_commitish': SHA,
            'draft': draft, 'prerelease': False,
            'assets': [{'id': i + 100, 'name': name, 'size': 10, 'state': 'uploaded',
                        'digest': 'sha256:' + HASHES[name]}
                       for i, name in enumerate(sorted(r.NAMES))] if assets else []}



class ReleaseGuards(unittest.TestCase):
    def test_release_asset_contract_is_four_unix_and_two_windows_zips(self):
        self.assertEqual(set(r.ASSETS), {
            'znvm-v2.10.0-x86_64-linux-musl', 'znvm-v2.10.0-aarch64-linux-musl',
            'znvm-v2.10.0-x86_64-macos', 'znvm-v2.10.0-aarch64-macos',
            'znvm-v2.10.0-x86_64-windows.zip', 'znvm-v2.10.0-aarch64-windows.zip'})
        self.assertEqual(r.NAMES, set(r.ASSETS) | {'SHA256SUMS'})

    def remote(self, tag=True, release=True, draft=False, sha=SHA, names=None):
        tag_value = {'object': {'type': 'commit', 'sha': sha}} if tag else None
        release_value = {'id': 42, 'target_commitish': SHA, 'tag_name': r.VERSION, 'draft': draft, 'prerelease': False,
                         'assets': [{'name': n} for n in (r.NAMES if names is None else names)]} if release else None
        return patch.object(r, 'api', side_effect=[tag_value, [release_value] if release_value else []])

    def test_absent_remote_is_new(self):
        with self.remote(False, False):
            self.assertIsNone(r.state(SHA))

    def test_only_tag_fails(self):
        with self.remote(True, False), self.assertRaises(RuntimeError):
            r.state(SHA)

    def test_draft_fails(self):
        with self.remote(draft=True), self.assertRaises(RuntimeError):
            r.state(SHA)

    def test_wrong_tag_sha_fails(self):
        with self.remote(sha='b' * 40), self.assertRaises(RuntimeError):
            r.state(SHA)

    def test_missing_asset_fails(self):
        with self.remote(names=list(r.ASSETS)), self.assertRaises(RuntimeError):
            r.state(SHA)

    def test_duplicate_asset_fails(self):
        with self.remote(names=[*r.ASSETS, r.ASSETS[0]]), self.assertRaises(RuntimeError):
            r.state(SHA)

    def test_complete_metadata_requires_later_byte_check(self):
        with self.remote():
            self.assertIsNotNone(r.state(SHA))

    def test_main_moved_fails(self):
        with patch.object(r, 'api', return_value={'object': {'sha': 'b' * 40}}), self.assertRaises(RuntimeError):
            r.check_main(SHA)

    def test_wrong_event_or_branch_fails(self):
        for env in ({'GITHUB_EVENT_NAME': 'pull_request'}, {'GITHUB_EVENT_NAME': 'push', 'GITHUB_REF': 'refs/heads/feature'}):
            with patch.dict(os.environ, env, clear=True), self.assertRaises(RuntimeError):
                r.context()

    def test_api_error_is_not_absence(self):
        from subprocess import CompletedProcess
        with patch.dict(os.environ, {'GH_REPO': 'fixture/fixture'}), patch.object(r.subprocess, 'run', return_value=CompletedProcess([], 1, b'', b'HTTP 403')), self.assertRaises(RuntimeError):
            r.api('releases/tags/v2.10.0', optional=True)

    def test_api_404_is_absence(self):
        from subprocess import CompletedProcess
        with patch.dict(os.environ, {'GH_REPO': 'fixture/fixture'}), patch.object(r.subprocess, 'run', return_value=CompletedProcess([], 1, b'', b'HTTP 404')):
            self.assertIsNone(r.api('releases/tags/v2.10.0', optional=True))

    def test_marker_exact_boolean_version_and_fields(self):
        env = {'GITHUB_EVENT_NAME': 'push', 'GITHUB_REF': 'refs/heads/main', 'GITHUB_SHA': SHA}
        invalid = ({'enabled': 1, 'version': '2.10.0'}, {'enabled': True, 'version': '9.0.0'},
                   {'enabled': True, 'version': '2.10.0', 'extra': 'unsafe'}, {'enabled': False, 'version': '2.10.0'})
        for marker in invalid:
            with patch.dict(os.environ, env, clear=True), patch.object(r.Path, 'read_text', return_value=json.dumps(marker)), self.assertRaises(RuntimeError):
                r.context()

    def test_existing_release_noop_requires_remote_hashes(self):
        with patch.object(r, 'context', return_value=SHA), patch.object(r, 'local_hashes', return_value=HASHES), patch.object(r, 'check_main'), patch.object(r, 'state', return_value=release_fixture()), patch.object(r, 'verify_remote', side_effect=RuntimeError('mismatch')), patch.object(r, 'api') as api, self.assertRaises(RuntimeError):
            r.publish('fixture')
        api.assert_not_called()

    def test_complete_existing_release_has_no_writes(self):
        with patch.object(r, 'context', return_value=SHA), patch.object(r, 'local_hashes', return_value=HASHES), patch.object(r, 'check_main'), patch.object(r, 'state', return_value=release_fixture()), patch.object(r, 'verify_remote') as remote, patch.object(r, 'verify_public') as public, patch.object(r, 'check_tag_owner'), patch.object(r, 'api') as api:
            r.publish('fixture')
        self.assertEqual(remote.call_args.args[:3], (42, SHA, False))
        public.assert_called_once()
        api.assert_not_called()

    def test_main_movement_prevents_draft_creation(self):
        with patch.object(r, 'context', return_value=SHA), patch.object(r, 'local_hashes', return_value=HASHES), patch.object(r, 'check_main', side_effect=RuntimeError('main moved')), patch.object(r, 'api') as api, self.assertRaises(RuntimeError):
            r.publish('fixture')
        api.assert_not_called()

    def test_upload_failure_retains_draft_without_retry_publish_or_cleanup(self):
        with patch.object(r, 'context', return_value=SHA), patch.object(r, 'local_hashes', return_value=HASHES), patch.object(r, 'check_main'), patch.object(r, 'state', return_value=None), patch.object(r, 'api', return_value=release_fixture(True, False)) as api, patch.object(r, 'check_tag_owner'), patch.object(r, 'upload_asset', side_effect=RuntimeError('partial upload')) as upload, self.assertRaises(RuntimeError):
            r.publish('fixture')
        self.assertEqual(api.call_count, 1)
        self.assertEqual(api.call_args.args[1], 'POST')
        upload.assert_called_once()

    def test_main_moves_after_upload_prevents_publish(self):
        draft = release_fixture(True)
        records = r.asset_snapshot(draft, HASHES)
        with patch.object(r, 'context', return_value=SHA), patch.object(r, 'local_hashes', return_value=HASHES), patch.object(r, 'check_main', side_effect=[None, None, RuntimeError('main moved')]), patch.object(r, 'state', return_value=None), patch.object(r, 'api', side_effect=[release_fixture(True, False), draft]) as api, patch.object(r, 'check_tag_owner'), patch.object(r, 'upload_asset', side_effect=lambda ident, path, digest: records[path.name]) as upload, patch.object(r, 'verify_remote'), self.assertRaises(RuntimeError):
            r.publish('fixture')
        self.assertEqual(upload.call_count, 7)
        self.assertFalse(any(len(call.args) > 1 and call.args[1] in ('PATCH', 'DELETE') for call in api.call_args_list))

    def test_invalid_create_response_never_uploads(self):
        changes = ({'id': True}, {'id': 0}, {'draft': False}, {'tag_name': 'v9.0.0'},
                   {'target_commitish': 'b' * 40}, {'assets': [{'id': 100}]})
        for change in changes:
            draft = release_fixture(True, False) | change
            with patch.object(r, 'context', return_value=SHA), patch.object(r, 'local_hashes', return_value=HASHES), patch.object(r, 'check_main'), patch.object(r, 'state', return_value=None), patch.object(r, 'api', return_value=draft) as api, patch.object(r, 'upload_asset') as upload, self.assertRaises(RuntimeError):
                r.publish('fixture')
            upload.assert_not_called()
            api.assert_called_once()

    def test_same_tag_replaced_by_other_draft_stops_upload(self):
        foreign = release_fixture(True, False) | {'id': 99}
        with patch.object(r, 'context', return_value=SHA), patch.object(r, 'local_hashes', return_value=HASHES), patch.object(r, 'check_main'), patch.object(r, 'state', return_value=None), patch.object(r, 'api', side_effect=[release_fixture(True, False), [foreign]]) as api, patch.object(r, 'upload_asset') as upload, self.assertRaises(RuntimeError):
            r.publish('fixture')
        upload.assert_not_called()
        self.assertEqual(api.call_count, 2)

    def test_replaced_asset_id_fails_before_download(self):
        draft = release_fixture(True)
        records = r.asset_snapshot(draft, HASHES)
        draft['assets'][0]['id'] = 999
        with patch.object(r, 'api', return_value=draft), patch.object(r.subprocess, 'run') as command, self.assertRaises(RuntimeError):
            r.verify_remote(42, SHA, True, HASHES, records)
        command.assert_not_called()

    def test_existing_release_replaced_after_download_fails(self):
        with patch.object(r, 'context', return_value=SHA), patch.object(r, 'local_hashes', return_value=HASHES), patch.object(r, 'check_main'), patch.object(r, 'state', return_value=release_fixture()), patch.object(r, 'verify_remote'), patch.object(r, 'api', return_value=[release_fixture() | {'id': 99}]), patch.object(r, 'verify_public') as public, self.assertRaises(RuntimeError):
            r.publish('fixture')
        public.assert_not_called()

    def test_upload_targets_numeric_release_id_and_records_asset_id(self):
        from subprocess import CompletedProcess
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'fixture.zip'
            path.write_bytes(b'x')
            digest = hashlib.sha256(b'x').hexdigest()
            asset = {'id': 123, 'name': path.name, 'size': 1, 'state': 'uploaded', 'digest': 'sha256:' + digest}
            with patch.dict(os.environ, {'GH_REPO': 'fixture/fixture'}), patch.object(r.subprocess, 'run', return_value=CompletedProcess([], 0, json.dumps(asset).encode(), b'')) as command:
                result = r.upload_asset(42, path, digest)
            self.assertEqual(result['id'], 123)
            args = command.call_args.args[0]
            self.assertIn('https://uploads.github.com/repos/fixture/fixture/releases/42/assets?name=fixture.zip', args)
            self.assertNotIn('--clobber', args)

    def test_download_targets_recorded_asset_id_not_tag(self):
        from subprocess import CompletedProcess
        expected = {'fixture.zip': hashlib.sha256(b'x').hexdigest()}
        release = release_fixture(True, False)
        release['assets'] = [{'id': 123, 'name': 'fixture.zip', 'size': 1, 'state': 'uploaded'}]
        records = r.asset_snapshot(release, expected)
        def download(args, stdout, stderr):
            stdout.write(b'x')
            return CompletedProcess(args, 0, b'', b'')
        with patch.dict(os.environ, {'GH_REPO': 'fixture/fixture'}), patch.object(r, 'api', return_value=release), patch.object(r, 'local_hashes', return_value=expected), patch.object(r.subprocess, 'run', side_effect=download) as command:
            r.verify_remote(42, SHA, True, expected, records)
        self.assertIn('repos/fixture/fixture/releases/assets/123', command.call_args.args[0])
        self.assertNotIn(r.VERSION, command.call_args.args[0])

    def test_successful_publish_only_patches_created_id(self):
        draft, published = release_fixture(True), release_fixture(False)
        records = r.asset_snapshot(draft, HASHES)
        with patch.object(r, 'context', return_value=SHA), patch.object(r, 'local_hashes', return_value=HASHES), patch.object(r, 'check_main'), patch.object(r, 'state', return_value=None), patch.object(r, 'api', side_effect=[release_fixture(True, False), draft, published]) as api, patch.object(r, 'check_tag_owner'), patch.object(r, 'upload_asset', side_effect=lambda ident, path, digest: records[path.name]) as upload, patch.object(r, 'verify_remote') as remote, patch.object(r, 'verify_public'):
            r.publish('fixture')
        self.assertTrue(all(call.args[0] == 42 for call in upload.call_args_list))
        self.assertTrue(all(call.args[0] == 42 for call in remote.call_args_list))
        patches = [call for call in api.call_args_list if len(call.args) > 1 and call.args[1] == 'PATCH']
        self.assertEqual(len(patches), 1)
        self.assertEqual(patches[0].args[0], 'releases/42')

    def test_draft_discovery_does_not_use_published_tag_endpoint(self):
        draft = release_fixture(True, False)
        with patch.object(r, 'api', return_value=[draft]) as api:
            self.assertEqual(r.find_release(), draft)
        self.assertEqual(api.call_args.args[0], 'releases?per_page=100&page=1')

    def test_duplicate_drafts_are_ambiguous(self):
        with patch.object(r, 'api', return_value=[release_fixture(True, False), release_fixture(True, False) | {'id': 99}]), self.assertRaises(RuntimeError):
            r.find_release()

    def test_partial_draft_without_tag_fails(self):
        with patch.object(r, 'api', side_effect=[None, [release_fixture(True, False)]]), self.assertRaises(RuntimeError):
            r.state(SHA)

    def test_release_discovery_paginates(self):
        first = [{'tag_name': 'v0.0.0'}] * 100
        with patch.object(r, 'api', side_effect=[first, [release_fixture()]]) as api:
            self.assertEqual(r.find_release()['id'], 42)
        self.assertEqual(api.call_count, 2)

    def test_owned_draft_without_tag_or_published_alias_is_valid(self):
        with patch.object(r, 'api', side_effect=[[release_fixture(True, False)], None, None]) as api:
            r.check_tag_owner(42, SHA, True)
        self.assertEqual(api.call_args_list[1].kwargs, {'optional': True})

    def test_draft_alias_other_id_fails(self):
        with patch.object(r, 'api', side_effect=[[release_fixture(True, False)], release_fixture(True, False) | {'id': 99}]), self.assertRaises(RuntimeError):
            r.check_tag_owner(42, SHA, True)

    def test_owned_draft_existing_wrong_tag_sha_fails(self):
        tag = {'object': {'type': 'commit', 'sha': 'b' * 40}}
        with patch.object(r, 'api', side_effect=[[release_fixture(True, False)], None, tag]), self.assertRaises(RuntimeError):
            r.check_tag_owner(42, SHA, True)

    def test_published_requires_tag_alias_and_exact_source(self):
        tag = {'object': {'type': 'commit', 'sha': SHA}}
        with patch.object(r, 'api', side_effect=[[release_fixture()], release_fixture(), tag]) as api:
            r.check_tag_owner(42, SHA, False)
        self.assertEqual(api.call_args_list[1].kwargs, {'optional': False})
        with patch.object(r, 'api', side_effect=[[release_fixture()], None]), self.assertRaises(RuntimeError):
            r.check_tag_owner(42, SHA, False)

    def test_public_transients_retry_same_url_then_succeed(self):
        content = b'fixture binary'
        url = 'https://fixture.invalid'
        transient = [r.HTTPError(url, 404, 'Not Found', {}, None),
                     r.HTTPError(url, 503, 'Unavailable', {}, None),
                     r.URLError('connection reset'), TimeoutError('timeout')]
        for error in transient:
            with patch.dict(os.environ, {'GH_REPO': 'fixture/fixture'}), patch.object(r, 'urlopen', side_effect=[error, io.BytesIO(content)]) as get, patch.object(r.time, 'sleep') as sleep:
                r.verify_public({'fixture.exe': hashlib.sha256(content).hexdigest()})
            self.assertEqual(get.call_count, 2)
            self.assertEqual(get.call_args_list[0], get.call_args_list[1])
            sleep.assert_called_once_with(3)

    def test_public_retry_exhaustion_is_bounded(self):
        error = r.HTTPError('https://fixture.invalid', 404, 'Not Found', {}, None)
        with patch.dict(os.environ, {'GH_REPO': 'fixture/fixture'}), patch.object(r, 'urlopen', side_effect=error) as get, patch.object(r.time, 'sleep') as sleep, self.assertRaises(r.HTTPError):
            r.verify_public({'fixture.exe': '0' * 64})
        self.assertEqual(get.call_count, 5)
        self.assertEqual([call.args[0] for call in sleep.call_args_list], [3, 6, 12, 12])

    def test_public_auth_errors_are_not_retried(self):
        for status in (401, 403):
            error = r.HTTPError('https://fixture.invalid', status, 'Denied', {}, None)
            with patch.dict(os.environ, {'GH_REPO': 'fixture/fixture'}), patch.object(r, 'urlopen', side_effect=error) as get, patch.object(r.time, 'sleep') as sleep, self.assertRaises(r.HTTPError):
                r.verify_public({'fixture.exe': '0' * 64})
            get.assert_called_once()
            sleep.assert_not_called()

    def test_public_hash_mismatch_is_not_retried(self):
        with patch.dict(os.environ, {'GH_REPO': 'fixture/fixture'}), patch.object(r, 'urlopen', return_value=io.BytesIO(b'tampered')) as get, patch.object(r.time, 'sleep') as sleep, self.assertRaises(RuntimeError):
            r.verify_public({'fixture.exe': '0' * 64})
        get.assert_called_once()
        sleep.assert_not_called()

    def test_public_midstream_connection_failure_restarts_hash(self):
        class BrokenStream(io.BytesIO):
            def read(self, size):
                raise ConnectionResetError('reset while reading')
        content = b'complete fixture'
        with patch.dict(os.environ, {'GH_REPO': 'fixture/fixture'}), patch.object(r, 'urlopen', side_effect=[BrokenStream(b'partial'), io.BytesIO(content)]) as get, patch.object(r.time, 'sleep'):
            r.verify_public({'fixture.exe': hashlib.sha256(content).hexdigest()})
        self.assertEqual(get.call_count, 2)


    def test_hashes_and_tampering(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp)
            lines = []
            for name in r.ASSETS:
                content = name.encode()
                (p / name).write_bytes(content)
                lines.append(f'{hashlib.sha256(content).hexdigest()}  {name}\n')
            (p / 'SHA256SUMS').write_text(''.join(lines))
            self.assertEqual(len(r.local_hashes(p)), 7)
            (p / r.ASSETS[0]).write_bytes(b'tampered')
            with self.assertRaises(RuntimeError):
                r.local_hashes(p)

    def test_checksum_traversal_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp)
            for name in r.ASSETS:
                (p / name).write_bytes(b'')
            (p / 'SHA256SUMS').write_text(('0' * 64 + '  ../escape\n') * 6)
            with self.assertRaises(RuntimeError):
                r.local_hashes(p)


if __name__ == '__main__':
    unittest.main()
