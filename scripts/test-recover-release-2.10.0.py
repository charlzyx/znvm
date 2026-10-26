#!/usr/bin/env python3
"""Pure recovery fixtures. All GitHub/subprocess side effects are mocked."""
import copy
import importlib.util
import json
import hashlib
import io
import tempfile
import zipfile
from types import SimpleNamespace
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('recovery', Path(__file__).with_name('recover-release-2.10.0.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
r = m.r
CONTROL = 'c' * 40
EXPECTED = {name: '0' * 64 for name in r.NAMES}


def release(draft=True, assets=False):
    return {'id': m.RELEASE_ID, 'tag_name': r.VERSION, 'target_commitish': m.SOURCE,
            'draft': draft, 'prerelease': False, 'created_at': m.CREATED,
            'author': {'id': 41898282, 'login': 'github-actions[bot]'},
            'assets': [{'id': 100 + i, 'name': name, 'state': 'uploaded', 'size': 10,
                        'digest': 'sha256:' + EXPECTED[name]}
                       for i, name in enumerate(sorted(r.NAMES))] if assets else []}


def evidence():
    result = {}
    for path, ident in [('.github/workflows/ci.yml', 40361365007),
                        ('.github/workflows/linux-compat.yml', 40361365436),
                        ('.github/workflows/windows.yml', 40361365067),
                        ('.github/workflows/release-request.yml', m.RUN)]:
        result[f'actions/runs/{ident}'] = {'id': ident, 'head_sha': m.SOURCE, 'path': path,
            'event': 'push', 'head_branch': 'main', 'status': 'completed',
            'conclusion': 'failure' if ident == m.RUN else 'success', 'run_attempt': 2}
    result[f'actions/runs/{m.RUN}/attempts/1/jobs?per_page=100'] = {'jobs': [
        {'id': ident, 'name': name, 'status': 'completed', 'conclusion': 'success'}
        for ident, name in {121707468755: 'Build (x86_64-windows-gnu)',
                           121707468758: 'Build (aarch64-windows-gnu)',
                           121707468761: 'Build (x86_64-macos)',
                           121707468766: 'Build (aarch64-linux-musl)',
                           121707468900: 'Build (aarch64-macos)',
                           121707469163: 'Build (x86_64-linux-musl)',
                           121710034671: 'Assemble and verify the six build artifacts',
                           121710125195: 'Test exact Windows release candidate (x64)',
                           121710125414: 'Test exact Windows release candidate (arm64)'}.items()]}
    result[f'actions/artifacts/{m.ARTIFACT}'] = {'id': m.ARTIFACT, 'name': 'release-candidate',
        'expired': False, 'digest': m.DIGEST, 'workflow_run': {'id': m.RUN, 'head_sha': m.SOURCE}}
    return result


class RecoveryTests(unittest.TestCase):
    def env(self):
        return {'GITHUB_REPOSITORY': r.REPOSITORY, 'GH_REPO': r.REPOSITORY,
                'GITHUB_EVENT_NAME': 'push', 'GITHUB_REF': 'refs/heads/main', 'GITHUB_SHA': CONTROL}

    def changes(self):
        return '\n'.join('A\t' + path for path in sorted(m.FILES))

    def test_context_exact_control_commit_only(self):
        with patch.dict(os.environ, self.env(), clear=True), patch.object(m, 'git', side_effect=[CONTROL, m.SOURCE, self.changes()]), patch.object(m.Path, 'read_text', return_value=json.dumps(m.MARKER)), patch.object(r, 'verify_versions'), patch.object(r, 'check_main') as main:
            self.assertEqual(m.context(), CONTROL)
        main.assert_called_once_with(CONTROL)

    def test_context_wrong_repo_event_branch_rejected(self):
        for change in ({'GITHUB_REPOSITORY': 'fork/znvm'}, {'GH_REPO': 'other/repo'},
                       {'GITHUB_EVENT_NAME': 'pull_request'}, {'GITHUB_REF': 'refs/heads/feature'}):
            with patch.dict(os.environ, self.env() | change, clear=True), patch.object(m, 'git') as git, self.assertRaises(RuntimeError):
                m.context()
            git.assert_not_called()

    def test_context_wrong_head_parent_or_changed_old_file_rejected(self):
        invalid = [[m.SOURCE], [CONTROL, 'd' * 40], [CONTROL, m.SOURCE + ' ' + 'd' * 40],
                   [CONTROL, m.SOURCE, self.changes().replace('A\t', 'M\t', 1)],
                   [CONTROL, m.SOURCE, self.changes() + '\nM\tsrc/main.zig']]
        for values in invalid:
            with patch.dict(os.environ, self.env(), clear=True), patch.object(m, 'git', side_effect=values), self.assertRaises(RuntimeError):
                m.context()

    def test_context_marker_changes_rejected(self):
        for change in ({'enabled': False}, {'release_id': m.RELEASE_ID + 1}, {'candidate_digest': 'wrong'},
                       {'source_sha': CONTROL}, {'extra': True}):
            with patch.dict(os.environ, self.env(), clear=True), patch.object(m, 'git', side_effect=[CONTROL, m.SOURCE, self.changes()]), patch.object(m.Path, 'read_text', return_value=json.dumps(m.MARKER | change)), self.assertRaises(RuntimeError):
                m.context()

    def test_source_evidence_success_is_read_only(self):
        fixtures = evidence()
        with patch.object(r, 'api', side_effect=lambda path: fixtures[path]) as api:
            m.source_evidence()
        self.assertTrue(all(len(call.args) == 1 for call in api.call_args_list))

    def test_wrong_source_ci_identity_or_result_rejected(self):
        for change in ({'head_sha': CONTROL}, {'path': '.github/workflows/other.yml'},
                       {'event': 'pull_request'}, {'head_branch': 'feature'}, {'conclusion': 'cancelled'}):
            fixtures = evidence()
            fixtures['actions/runs/40361365007'].update(change)
            with patch.object(r, 'api', side_effect=lambda path: fixtures[path]), self.assertRaises(RuntimeError):
                m.source_evidence()

    def test_original_attempt_changed_rejected(self):
        for change in ({'run_attempt': 3}, {'head_sha': CONTROL}, {'status': 'in_progress'}, {'conclusion': 'success'}):
            fixtures = evidence()
            fixtures[f'actions/runs/{m.RUN}'].update(change)
            with patch.object(r, 'api', side_effect=lambda path: fixtures[path]), self.assertRaises(RuntimeError):
                m.source_evidence()

    def test_native_candidate_job_must_be_exact_success(self):
        for change in ({'id': 123}, {'name': 'different job'}, {'conclusion': 'failure'}):
            fixtures = evidence()
            fixtures[f'actions/runs/{m.RUN}/attempts/1/jobs?per_page=100']['jobs'][1].update(change)
            with patch.object(r, 'api', side_effect=lambda path: fixtures[path]), self.assertRaises(RuntimeError):
                m.source_evidence()

    def test_artifact_identity_digest_run_and_source_rejected(self):
        for change in ({'id': m.ARTIFACT + 1}, {'expired': True}, {'digest': 'sha256:wrong'},
                       {'workflow_run': {'id': 1, 'head_sha': m.SOURCE}},
                       {'workflow_run': {'id': m.RUN, 'head_sha': CONTROL}}):
            fixtures = evidence()
            fixtures[f'actions/artifacts/{m.ARTIFACT}'].update(change)
            with patch.object(r, 'api', side_effect=lambda path: fixtures[path]), self.assertRaises(RuntimeError):
                m.source_evidence()

    def test_owned_empty_receipt_by_exact_id(self):
        with patch.object(r, 'api', return_value=release()) as api:
            m.owned(True, {}, {})
        api.assert_called_once_with(f'releases/{m.RELEASE_ID}')

    def test_owned_wrong_receipt_rejected(self):
        for change in ({'id': m.RELEASE_ID + 1}, {'draft': False}, {'tag_name': 'v9.0.0'},
                       {'target_commitish': CONTROL}, {'created_at': 'different'},
                       {'author': {'id': 1, 'login': 'github-actions[bot]'}},
                       {'author': {'id': 41898282, 'login': 'someone-else'}}):
            with patch.object(r, 'api', return_value=release() | change), self.assertRaises(RuntimeError):
                m.owned(True, {}, {})

    def test_initial_partial_upload_never_resumed(self):
        with patch.object(r, 'api', return_value=release(assets=True)), self.assertRaises(RuntimeError):
            m.owned(True, {}, {})

    def test_recorded_asset_id_size_hash_changes_rejected(self):
        original = release(assets=True)
        records = r.asset_snapshot(original, EXPECTED)
        for change in ({'id': 999}, {'size': 999}, {'digest': 'sha256:wrong'}):
            current = copy.deepcopy(original)
            current['assets'][0].update(change)
            with patch.object(r, 'api', return_value=current), self.assertRaises(RuntimeError):
                m.owned(True, EXPECTED, records)

    def test_listing_temporarily_missing_then_same_id(self):
        with patch.object(m, 'identity', return_value=release()), patch.object(r, 'check_main') as main, patch.object(r, 'find_release', side_effect=[None, release()]), patch.object(r, 'api', return_value=None), patch.object(m.time, 'sleep') as sleep:
            m.wait_listing(CONTROL, True)
        self.assertEqual(main.call_count, 2)
        sleep.assert_called_once_with(3)

    def test_listing_timeout_read_only_no_retry_writes(self):
        with patch.object(m, 'identity', return_value=release()), patch.object(r, 'check_main'), patch.object(r, 'find_release', return_value=None) as listing, patch.object(r, 'api') as api, patch.object(m.time, 'sleep') as sleep, self.assertRaises(RuntimeError):
            m.wait_listing(CONTROL, True)
        self.assertEqual(listing.call_count, 5)
        self.assertEqual(sleep.call_count, 4)
        self.assertTrue(all(len(call.args) == 1 for call in api.call_args_list))

    def test_listing_foreign_or_duplicate_stops_immediately(self):
        for value in (release() | {'id': m.RELEASE_ID + 1}, RuntimeError('duplicate releases')):
            mock = patch.object(r, 'find_release', side_effect=value) if isinstance(value, Exception) else patch.object(r, 'find_release', return_value=value)
            with patch.object(m, 'identity', return_value=release()), patch.object(r, 'check_main'), mock, patch.object(m.time, 'sleep') as sleep, self.assertRaises(RuntimeError):
                m.wait_listing(CONTROL, True)
            sleep.assert_not_called()

    def test_listing_alias_or_tag_conflict_rejected(self):
        for responses in ([release() | {'id': m.RELEASE_ID + 1}],
                          [None, {'object': {'type': 'commit', 'sha': CONTROL}}]):
            with patch.object(m, 'identity', return_value=release()), patch.object(r, 'check_main'), patch.object(r, 'find_release', return_value=release()), patch.object(r, 'api', side_effect=responses), self.assertRaises(RuntimeError):
                m.wait_listing(CONTROL, True)

    def test_listing_rechecks_exact_identity_before_missing_collection(self):
        with patch.object(r, 'check_main'), patch.object(m, 'identity', side_effect=RuntimeError('owned draft changed')), patch.object(r, 'find_release') as listing, patch.object(m.time, 'sleep') as sleep, self.assertRaises(RuntimeError):
            m.wait_listing(CONTROL, True)
        listing.assert_not_called()
        sleep.assert_not_called()

    def archive_fixture(self, bad_entry=None):
        data = {name: name.encode() for name in r.ASSETS}
        data['SHA256SUMS'] = ''.join(hashlib.sha256(data[name]).hexdigest() + '  ' + name + '\n' for name in r.ASSETS).encode()
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, 'w', zipfile.ZIP_DEFLATED) as archive:
            for i, (name, content) in enumerate(data.items()):
                archive.writestr(bad_entry if i == 0 and bad_entry else name, content)
        return stream.getvalue()

    def test_download_fixed_receipt_extracts_exact_files(self):
        payload = self.archive_fixture()
        original_stat = Path.stat
        def stat(path, *args, **kwargs):
            return SimpleNamespace(st_size=7669311) if path.name == 'candidate.zip' else original_stat(path, *args, **kwargs)
        def command(args, stdout, stderr):
            stdout.write(payload)
            return SimpleNamespace(returncode=0)
        with tempfile.TemporaryDirectory() as temp:
            destination = Path(temp) / 'candidate'
            with patch.object(m, 'context', return_value=CONTROL), patch.object(m, 'source_evidence'), patch.object(m, 'owned'), patch.object(m, 'wait_listing'), patch.object(r, 'check_main'), patch.object(m, 'DIGEST', 'sha256:' + hashlib.sha256(payload).hexdigest()), patch.object(Path, 'stat', stat), patch.object(m.subprocess, 'run', side_effect=command) as run:
                m.download(destination)
            self.assertEqual({p.name for p in destination.iterdir()}, r.NAMES)
            self.assertEqual(len(r.local_hashes(destination)), 7)
            self.assertIn(f'repos/{r.REPOSITORY}/actions/artifacts/{m.ARTIFACT}/zip', run.call_args.args[0])

    def test_download_receipt_mismatch_or_unsafe_entry_never_extracts(self):
        original_stat = Path.stat
        for wrong_digest, wrong_size, bad_entry in [(True, False, None), (False, True, None), (False, False, '../escape')]:
            payload = self.archive_fixture(bad_entry)
            def stat(path, *args, **kwargs):
                return SimpleNamespace(st_size=1 if wrong_size else 7669311) if path.name == 'candidate.zip' else original_stat(path, *args, **kwargs)
            def command(args, stdout, stderr):
                stdout.write(payload)
                return SimpleNamespace(returncode=0)
            digest = 'sha256:wrong' if wrong_digest else 'sha256:' + hashlib.sha256(payload).hexdigest()
            with tempfile.TemporaryDirectory() as temp:
                destination = Path(temp) / 'candidate'
                with patch.object(m, 'context', return_value=CONTROL), patch.object(m, 'source_evidence'), patch.object(m, 'owned'), patch.object(m, 'wait_listing'), patch.object(r, 'check_main'), patch.object(m, 'DIGEST', digest), patch.object(Path, 'stat', stat), patch.object(m.subprocess, 'run', side_effect=command), patch.object(r, 'upload_asset') as upload, self.assertRaises(RuntimeError):
                    m.download(destination)
                upload.assert_not_called()
                self.assertFalse(destination.exists())
                self.assertFalse((Path(temp) / 'escape').exists())

    def test_recover_success_uses_only_owned_release_and_source(self):
        published = release(False, True)
        records = r.asset_snapshot(published, EXPECTED)
        with patch.object(m, 'context', return_value=CONTROL), patch.object(m, 'source_evidence'), patch.object(r, 'local_hashes', return_value=EXPECTED), patch.object(m, 'owned'), patch.object(m, 'wait_listing'), patch.object(r, 'check_main'), patch.object(r, 'upload_asset', side_effect=lambda ident, path, digest: records[path.name]) as upload, patch.object(r, 'verify_remote') as verify, patch.object(r, 'verify_public'), patch.object(r, 'api', return_value=published) as api:
            m.recover('fixture')
        self.assertEqual(upload.call_count, 7)
        self.assertTrue(all(call.args[0] == m.RELEASE_ID for call in upload.call_args_list))
        self.assertTrue(all(call.args[:2] == (m.RELEASE_ID, m.SOURCE) for call in verify.call_args_list))
        api.assert_called_once_with(f'releases/{m.RELEASE_ID}', 'PATCH', {'draft': False, 'make_latest': 'true'})

    def test_recovery_preflight_blocked_has_zero_writes(self):
        with patch.object(m, 'context', return_value=CONTROL), patch.object(m, 'source_evidence'), patch.object(r, 'local_hashes', return_value=EXPECTED), patch.object(m, 'owned', side_effect=RuntimeError('partial draft')), patch.object(r, 'api') as api, patch.object(r, 'upload_asset') as upload, self.assertRaises(RuntimeError):
            m.recover('fixture')
        api.assert_not_called()
        upload.assert_not_called()

    def test_recover_listing_permanently_missing_has_zero_writes(self):
        with patch.object(m, 'context', return_value=CONTROL), patch.object(m, 'source_evidence'), patch.object(r, 'local_hashes', return_value=EXPECTED), patch.object(m, 'owned'), patch.object(m, 'identity', return_value=release()), patch.object(r, 'find_release', return_value=None), patch.object(m.time, 'sleep'), patch.object(r, 'check_main'), patch.object(r, 'api') as api, patch.object(r, 'upload_asset') as upload, self.assertRaises(RuntimeError):
            m.recover('fixture')
        api.assert_not_called()
        upload.assert_not_called()

    def test_recover_owned_missing_or_partial_has_zero_writes(self):
        for missing in (True, False):
            response = patch.object(r, 'api', side_effect=RuntimeError('owned ID 404')) if missing else patch.object(r, 'api', return_value=release(True, True))
            with patch.object(m, 'context', return_value=CONTROL), patch.object(m, 'source_evidence'), patch.object(r, 'local_hashes', return_value=EXPECTED), response as api, patch.object(r, 'upload_asset') as upload, self.assertRaises(RuntimeError):
                m.recover('fixture')
            upload.assert_not_called()
            api.assert_called_once_with(f'releases/{m.RELEASE_ID}')

    def test_changed_publish_response_never_retries_or_reports_success(self):
        records = r.asset_snapshot(release(True, True), EXPECTED)
        for identity_change in (True, False):
            published = release(False, True)
            if identity_change:
                published['id'] += 1
            else:
                published['assets'][0]['id'] += 1000
            with patch.object(m, 'context', return_value=CONTROL), patch.object(m, 'source_evidence'), patch.object(r, 'local_hashes', return_value=EXPECTED), patch.object(m, 'owned'), patch.object(m, 'wait_listing'), patch.object(r, 'check_main'), patch.object(r, 'upload_asset', side_effect=lambda ident, path, digest: records[path.name]) as upload, patch.object(r, 'verify_remote') as verify, patch.object(r, 'verify_public') as public, patch.object(r, 'api', return_value=published) as api, self.assertRaises(RuntimeError):
                m.recover('fixture')
            self.assertEqual(upload.call_count, 7)
            api.assert_called_once_with(f'releases/{m.RELEASE_ID}', 'PATCH', {'draft': False, 'make_latest': 'true'})
            verify.assert_called_once()
            public.assert_not_called()

    def test_partial_upload_failure_is_not_retried_or_cleaned(self):
        records = r.asset_snapshot(release(True, True), EXPECTED)
        calls = []
        def upload(ident, path, digest):
            calls.append(path.name)
            if len(calls) == 2:
                raise RuntimeError('unknown upload outcome')
            return records[path.name]
        with patch.object(m, 'context', return_value=CONTROL), patch.object(m, 'source_evidence'), patch.object(r, 'local_hashes', return_value=EXPECTED), patch.object(m, 'owned'), patch.object(m, 'wait_listing'), patch.object(r, 'check_main'), patch.object(r, 'upload_asset', side_effect=upload), patch.object(r, 'api') as api, self.assertRaises(RuntimeError):
            m.recover('fixture')
        self.assertEqual(len(calls), 2)
        api.assert_not_called()


if __name__ == '__main__':
    unittest.main()
