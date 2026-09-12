"""Negative cases for the gate itself, using disposable test repositories."""
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('test_runner', ROOT / 'tests/run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RunnerContract(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'tests/sdk').mkdir(parents=True)
        self.script = self.root / 'tests/sdk/example.py'
        self.script.write_text('print("executed")', encoding='utf-8')
        self.case = {'id': 'sdk.example', 'suite': 'sdk', 'path': 'tests/sdk/example.py', 'args': []}
        self.manifest = {'schema': 1, 'cases': [self.case]}

    def test_valid_inventory(self):
        self.assertEqual(runner.inventory(self.root, self.manifest), [self.case])

    def test_unregistered_file_fails(self):
        (self.root / 'tests/sdk/forgotten.lua').write_text('assert(false)')
        with self.assertRaisesRegex(ValueError, 'unregistered'):
            runner.inventory(self.root, self.manifest)

    def test_duplicate_identity_and_command_fail(self):
        for name in ('sdk.example', 'sdk.alias'):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, 'duplicate'):
                runner.inventory(self.root, dict(self.manifest, cases=[self.case, dict(self.case, id=name)]))

    def test_missing_unsafe_and_wrong_suite_paths_fail(self):
        for path in ('tests/sdk/missing.py', '../escape.py', 'tests/../../escape.py', 'C:/escape.py', 'tests\\sdk\\example.py', 'tests//sdk/example.py'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                runner.inventory(self.root, dict(self.manifest, cases=[dict(self.case, path=path)]))
        with self.assertRaisesRegex(ValueError, 'match suite'):
            runner.inventory(self.root, dict(self.manifest, cases=[dict(self.case, suite='ui')]))

    def test_arguments_remain_distinct_argv(self):
        case = dict(self.case, args=['space value', '$(not a shell)', '--check'])
        self.assertEqual(runner.command(case)[-3:], case['args'])
        runner.inventory(self.root, dict(self.manifest, cases=[self.case, dict(case, id='sdk.variant')]))

    def test_nested_spec_is_rejected(self):
        (self.root / 'tests/sdk/nested.lua').write_text('dofile("tests/ui/interaction.lua")')
        cases = [self.case, dict(self.case, id='sdk.nested', path='tests/sdk/nested.lua')]
        with self.assertRaisesRegex(ValueError, 'another spec'):
            runner.inventory(self.root, dict(self.manifest, cases=cases))

    def test_support_is_not_an_executable_case(self):
        (self.root / 'tests/support').mkdir()
        (self.root / 'tests/support/native.lua').write_text('return {}')
        runner.inventory(self.root, self.manifest)

    def test_selection_is_explicit(self):
        bench = dict(self.case, id='benchmarks.example', suite='benchmarks')
        cases = [self.case, bench]
        self.assertEqual(runner.select(cases, [], [], False), [self.case])
        self.assertEqual(runner.select(cases, ['benchmarks'], [], False), [bench])
        with self.assertRaises(ValueError): runner.select(cases, [], ['typo'], False)
        with self.assertRaises(ValueError): runner.select(cases, ['ui'], [], False)

    def test_nonzero_and_timeout_never_pass(self):
        result = runner.execute([sys.executable, '-c', 'print("failure evidence");raise SystemExit(7)'], self.root, 5)
        self.assertEqual((result['status'], result['exitCode']), ('failed', 7))
        self.assertIn('failure evidence', result['output'])
        result = runner.execute([sys.executable, '-c', 'import time;print("before timeout",flush=True);time.sleep(5)'], self.root, .5)
        self.assertEqual(result['status'], 'timeout')
        self.assertIn('before timeout', result['output'])

    def test_spawn_failure_is_reported(self):
        self.assertEqual(runner.execute([str(self.root/'absent')], self.root, 1)['status'], 'failed')

    def test_failure_continues_and_report_keeps_evidence(self):
        self.script.write_text('raise SystemExit(7)', encoding='utf-8')
        (self.root/'tests/sdk/after.py').write_text('print("after failure")', encoding='utf-8')
        cases = [self.case, dict(self.case, id='sdk.after', path='tests/sdk/after.py')]
        (self.root/'tests/suites.json').write_text(json.dumps(dict(self.manifest, cases=cases)))
        report = self.root/'report.json'
        with patch.object(runner, 'ROOT', self.root), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(['--report', str(report)]), 1)
        result = json.loads(report.read_text(encoding='utf-8'))
        self.assertFalse(result['passed'])
        self.assertEqual(result['scope'], 'full')
        self.assertEqual([r['status'] for r in result['results']], ['failed', 'passed'])
        self.assertIn('after failure', result['results'][1]['output'])

    def test_selected_report_cannot_claim_full_coverage(self):
        (self.root/'tests/suites.json').write_text(json.dumps(self.manifest))
        report = self.root/'selected.json'
        with patch.object(runner, 'ROOT', self.root), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(['--case', 'sdk.example', '--report', str(report)]), 0)
        self.assertEqual(json.loads(report.read_text())['scope'], 'selected')

    def test_assertions_cannot_be_disabled_by_environment(self):
        with patch.dict('os.environ', {'PYTHONOPTIMIZE': '1'}):
            result = runner.execute([sys.executable, '-c', 'assert False, "active assertions"'], self.root, 5)
        self.assertEqual(result['status'], 'failed')
        self.assertIn('active assertions', result['output'])


if __name__ == '__main__':
    unittest.main()
