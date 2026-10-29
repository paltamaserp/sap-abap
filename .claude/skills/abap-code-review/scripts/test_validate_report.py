"""Synthetic local checks of result aggregation; never connects to SAP."""
import copy
import tempfile
import json
import subprocess
import sys
from pathlib import Path
import unittest
from validate_report import digest, evaluate


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'source.abap').write_text('Synthetic local fixture, not SAP code.', encoding='utf-8')
        (self.root / 'readback.abap').write_bytes((self.root / 'source.abap').read_bytes())
        (self.root / 'response.json').write_text('{"synthetic": true}', encoding='utf-8')
        fingerprint = digest(self.root / 'source.abap')
        common = dict(status='passed', source_sha256=fingerprint, checked_at='2026-10-27T12:00:00Z',
                      evidence=[dict(file='response.json', sha256=digest(self.root / 'response.json'))])
        self.obj = dict(name='ZCL_SYNTHETIC_FIXTURE', type='CLAS', system='TEST', client='000',
                        source_sha256=fingerprint, checks={
                            'syntax': dict(common, errors=0, warnings=0, unresolved_warnings=0, checked_version='active'),
                            'active_readback': dict(common, version='active', expected_file='source.abap', actual_file='readback.abap'),
                            'unit': dict(common, completed=True, run_id='synthetic-unit', tests=3, failures=0, errors=0, skipped=0),
                            'qa': dict(common, completed=True, tool='Synthetic ATC fixture', variant='SYNTHETIC', run_id='synthetic-qa',
                                       checking_system='TEST', blocking_findings=0, unresolved_findings=0)})

    def result(self):
        return evaluate({'objects': [self.obj]}, self.root)['result']

    def test_complete_evidence_passes(self):
        self.assertEqual(self.result(), 'SIKERES')

    def test_missing_gate_is_partial(self):
        del self.obj['checks']['qa']
        self.assertEqual(self.result(), 'RÉSZLEGES')

    def test_zero_tests_and_pending_runs_do_not_pass(self):
        self.obj['checks']['unit']['tests'] = 0
        self.assertEqual(self.result(), 'RÉSZLEGES')
        self.obj['checks']['unit'].update(tests=3, completed=False)
        self.assertEqual(self.result(), 'RÉSZLEGES')

    def test_wrong_active_source_fails(self):
        (self.root / 'readback.abap').write_text('Changed.', encoding='utf-8')
        self.assertEqual(self.result(), 'HIBÁS')

    def test_checkclass_is_not_atc(self):
        self.obj['checks']['qa']['tool'] = 'mcp__sap_abap_adt__CheckClass'
        self.assertEqual(self.result(), 'HIBÁS')

    def test_pending_qa_does_not_pass(self):
        self.obj['checks']['qa']['completed'] = False
        self.assertEqual(self.result(), 'RÉSZLEGES')

    def test_evidence_tampering_fails(self):
        (self.root / 'response.json').write_text('changed evidence', encoding='utf-8')
        self.assertEqual(self.result(), 'HIBÁS')

    def test_unresolved_warning_is_partial(self):
        self.obj['checks']['syntax'].update(warnings=1, unresolved_warnings=1)
        self.assertEqual(self.result(), 'RÉSZLEGES')

    def test_old_source_fingerprint_is_partial(self):
        self.obj['checks']['syntax']['source_sha256'] = '0' * 64
        self.assertEqual(self.result(), 'RÉSZLEGES')

    def test_ddic_can_explain_no_unit_but_qa_cannot_be_skipped(self):
        self.obj['checks']['unit'] = dict(status='not_applicable', reason='Pure DDIC fixture, no executable logic.')
        self.assertEqual(self.result(), 'SIKERES')
        self.obj['checks']['qa'] = dict(status='not_applicable', reason='No runner.')
        self.assertEqual(self.result(), 'RÉSZLEGES')

    def test_unknown_scope_and_no_tests_are_not_full_success(self):
        self.obj.update(system=None, client=None, source_sha256=None)
        self.obj['checks'] = {}
        self.assertEqual(self.result(), 'RÉSZLEGES')
        with self.assertRaises(ValueError):
            evaluate({'objects': []}, self.root)

    def test_failed_gate_dominates_missing_gate(self):
        self.obj['checks']['syntax'] = dict(status='failed', reason='Synthetic syntax error.')
        del self.obj['checks']['qa']
        self.assertEqual(self.result(), 'HIBÁS')

    def test_evidence_cannot_escape_report_folder(self):
        self.obj['checks']['syntax'] = copy.deepcopy(self.obj['checks']['syntax'])
        self.obj['checks']['syntax']['evidence'][0]['file'] = '../outside.json'
        self.assertEqual(self.result(), 'HIBÁS')

    def test_cli_exit_codes_and_saved_summary(self):
        report = self.root / 'synthetic_WIP.json'
        script = Path(__file__).with_name('validate_report.py')
        for expected_result, code in [('SIKERES', 0), ('RÉSZLEGES', 2), ('HIBÁS', 1)]:
            if code == 2:
                self.obj['checks']['qa'] = dict(status='not_run', reason='Synthetic missing QA.')
            if code == 1:
                self.obj['checks']['syntax'] = dict(status='failed', reason='Synthetic error.')
            report.write_text(json.dumps({'objects': [self.obj]}), encoding='utf-8')
            run = subprocess.run([sys.executable, str(script), str(report)], capture_output=True, text=True, encoding='utf-8')
            self.assertEqual(run.returncode, code, run.stderr)
            saved = json.loads((self.root / 'synthetic_eredmeny_WIP.json').read_text(encoding='utf-8'))
            self.assertEqual(saved['result'], expected_result)


if __name__ == '__main__':
    unittest.main(testRunner=unittest.TextTestRunner(stream=sys.stdout, verbosity=2))
