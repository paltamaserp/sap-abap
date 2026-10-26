const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const os = require('os');
const assert = require('assert/strict');
const crypto = require('crypto');
const project = path.resolve(__dirname, '../..');
const input = path.join(project, '05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap');
const target = path.join(__dirname, 'ZPR_CLOSE_STOCK.abap');
const sha = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const baseHash = 'bb5c6e1fd26f395a981d8ab0a3ac84a93c2f12888a04cd377766119c5911339e';
assert.equal(sha(input), baseHash, 'The user-designated baseline changed; review before rebuilding.');
const original = fs.readFileSync(input, 'utf8').replace(/\r\n/g, '\n');
let source = original;
const replacements = [];
function replace(before, after) {
  assert.equal(source.split(before).length, 2, 'Expected one occurrence: ' + before);
  source = source.replace(before, after);
  replacements.push({before, after});
}
replace('  gv_busy = abap_true.\n\n  PERFORM lock_stock.',
  "  gv_busy = abap_true.\n  PERFORM log_now USING 'I' text-310 space.\n\n  PERFORM lock_stock.");
replace('        PERFORM save_release USING lt_regmail.', `        PERFORM log_now USING 'I' text-321 space.
        PERFORM save_release USING lt_regmail.
        IF gv_saved = abap_true.
          PERFORM log_now USING 'S' text-322 space.
        ELSE.
          PERFORM log_now USING 'E' text-323 space.
        ENDIF.`);
replace("    PERFORM add_message USING 'E' 'A stock nem lett lezárva:' p_stokid space.\n  ENDIF.\n  PERFORM log_write.",
  `    PERFORM add_message USING 'E' 'A stock nem lett lezárva:' p_stokid space.
  ENDIF.
  IF gv_saved = abap_true.
    PERFORM log_now USING 'S' text-311 space.
  ELSE.
    PERFORM log_now USING 'E' text-312 space.
  ENDIF.
  PERFORM log_write.`);
replace('        lv_port      TYPE prx_logical_port_name,\n        lr_error     TYPE REF TO cx_root.',
  '        lv_port      TYPE prx_logical_port_name,\n        lv_call_start TYPE timestampl,\n        lv_call_end   TYPE timestampl,\n        lr_error     TYPE REF TO cx_root.');
replace('  CLEAR: gv_call_started, gv_remote_success.\n\n  LOOP AT gt_alv',
  '  CLEAR: gv_call_started, gv_remote_success.\n  PERFORM log_stock_totals.\n\n  LOOP AT gt_alv');
replace("        PERFORM add_message USING 'E' 'Az Inspire logikai portja üres.'\n          space space.\n        RETURN.",
  `        PERFORM add_message USING 'E' 'Az Inspire logikai portja üres.'
          space space.
        PERFORM log_now USING 'E' text-318 space.
        RETURN.`);
replace('      gv_call_started = abap_true.\n      lo_proxy->eon_dcqmcompleted(',
  `      GET TIME STAMP FIELD lv_call_start.
      PERFORM log_at USING 'I' text-313 lv_call_start lv_port.
      gv_call_started = abap_true.
      lo_proxy->eon_dcqmcompleted(`);
replace('        EXPORTING input = ls_input IMPORTING output = ls_output ).\n\n    CATCH cx_ai_application_fault INTO lr_error.',
  `        EXPORTING input = ls_input IMPORTING output = ls_output ).
      GET TIME STAMP FIELD lv_call_end.

    CATCH cx_ai_application_fault INTO lr_error.
      GET TIME STAMP FIELD lv_call_end.
      IF lv_call_start IS NOT INITIAL.
        PERFORM log_inspire_end USING 'E' text-315
          lv_call_start lv_call_end.
      ELSE.
        PERFORM log_now USING 'E' text-318 space.
      ENDIF.`);
replace("        p_stokid space.\n      RETURN.\n    CATCH cx_root INTO lr_error.\n      PERFORM add_exception USING lr_error.\n      IF gv_call_started = abap_true.",
  `        p_stokid space.
      RETURN.
    CATCH cx_root INTO lr_error.
      GET TIME STAMP FIELD lv_call_end.
      IF lv_call_start IS NOT INITIAL.
        PERFORM log_inspire_end USING 'E' text-316
          lv_call_start lv_call_end.
      ELSE.
        PERFORM log_now USING 'E' text-318 space.
      ENDIF.
      PERFORM add_exception USING lr_error.
      IF gv_call_started = abap_true.`);
replace('  IF ls_output-parameters-success <> abap_true.\n',
  `  IF ls_output-parameters-success <> abap_true.
    PERFORM log_inspire_end USING 'E' text-315
      lv_call_start lv_call_end.
`);
replace('  gv_remote_success = abap_true.\n  gv_error = abap_false.',
  `  PERFORM log_inspire_end USING 'S' text-314
    lv_call_start lv_call_end.
  gv_remote_success = abap_true.
  gv_error = abap_false.`);

const helpers = `
"Logging only: use the complete stock, including allowed and excluded rows.
FORM log_stock_totals.
  TYPES: BEGIN OF ty_log_row,
           package_id TYPE zprt_dcqm-package_id,
           doc_no     TYPE zprt_dcqm-doc_no,
         END OF ty_log_row.
  DATA: lt_rows        TYPE STANDARD TABLE OF ty_log_row,
        ls_row         TYPE ty_log_row,
        lt_packages    TYPE SORTED TABLE OF zprt_dcqm-package_id
                         WITH UNIQUE KEY table_line,
        lt_documents   TYPE SORTED TABLE OF zprt_dcqm-doc_no
                         WITH UNIQUE KEY table_line,
        lv_count       TYPE i,
        lv_no_package  TYPE i,
        lv_no_document TYPE i,
        lv_number      TYPE c LENGTH 20,
        lv_error_text  TYPE string,
        lr_error       TYPE REF TO cx_root.

  PERFORM log_now USING 'I' text-307 space.
  TRY.
      SELECT package_id doc_no FROM zprt_dcqm INTO TABLE lt_rows
        WHERE prd_stock_id = p_stokid.
      LOOP AT lt_rows INTO ls_row.
        IF ls_row-package_id IS INITIAL.
          ADD 1 TO lv_no_package.
        ELSE.
          INSERT ls_row-package_id INTO TABLE lt_packages.
        ENDIF.
        IF ls_row-doc_no IS INITIAL.
          ADD 1 TO lv_no_document.
        ELSE.
          INSERT ls_row-doc_no INTO TABLE lt_documents.
        ENDIF.
      ENDLOOP.
      DESCRIBE TABLE lt_packages LINES lv_count.
      WRITE lv_count TO lv_number LEFT-JUSTIFIED.
      PERFORM add_message USING 'I' text-301 lv_number space.
      DESCRIBE TABLE lt_documents LINES lv_count.
      WRITE lv_count TO lv_number LEFT-JUSTIFIED.
      PERFORM add_message USING 'I' text-302 lv_number space.
      DESCRIBE TABLE lt_rows LINES lv_count.
      WRITE lv_count TO lv_number LEFT-JUSTIFIED.
      PERFORM add_message USING 'I' text-303 lv_number space.
      IF lv_no_package > 0.
        WRITE lv_no_package TO lv_number LEFT-JUSTIFIED.
        PERFORM add_message USING 'W' text-304 lv_number space.
      ENDIF.
      IF lv_no_document > 0.
        WRITE lv_no_document TO lv_number LEFT-JUSTIFIED.
        PERFORM add_message USING 'W' text-305 lv_number space.
      ENDIF.
    CATCH cx_root INTO lr_error.
      lv_error_text = lr_error->get_text( ).
      PERFORM add_message USING 'W' text-306 p_stokid lv_error_text.
  ENDTRY.
ENDFORM.

FORM log_now USING uv_type TYPE symsgty uv_event TYPE clike
                   uv_detail TYPE clike.
  DATA lv_stamp TYPE timestampl.
  GET TIME STAMP FIELD lv_stamp.
  PERFORM log_at USING uv_type uv_event lv_stamp uv_detail.
ENDFORM.

FORM log_at USING uv_type TYPE symsgty uv_event TYPE clike
                  uv_stamp TYPE timestampl uv_detail TYPE clike.
  DATA: lv_time   TYPE c LENGTH 40,
        lv_detail TYPE c LENGTH 100.
  lv_time = |{ uv_stamp TIMESTAMP = ISO TIMEZONE = 'UTC' } UTC|.
  CONCATENATE p_stokid uv_detail INTO lv_detail SEPARATED BY space.
  PERFORM add_message USING uv_type uv_event lv_time lv_detail.
ENDFORM.

FORM log_inspire_end USING uv_type TYPE symsgty uv_event TYPE clike
                          uv_start TYPE timestampl uv_end TYPE timestampl.
  DATA: lv_seconds TYPE p LENGTH 12 DECIMALS 3,
        lv_number  TYPE c LENGTH 30,
        lv_detail  TYPE c LENGTH 60.
  "Timestamp arithmetic must use calendar-aware subtraction.
  TRY.
      lv_seconds = cl_abap_tstmp=>subtract(
        tstmp1 = uv_end tstmp2 = uv_start ).
      WRITE lv_seconds TO lv_number LEFT-JUSTIFIED
        DECIMALS 3 NO-GROUPING.
      CONCATENATE lv_number text-319 INTO lv_detail SEPARATED BY space.
    CATCH cx_root.
      lv_detail = text-320.
  ENDTRY.
  PERFORM log_at USING uv_type uv_event uv_end lv_detail.
ENDFORM.
`;
source += helpers;
fs.writeFileSync(target, source.replace(/\n/g, '\r\n'));
const diffResult = cp.spawnSync('git', ['-c', 'core.autocrlf=false', 'diff', '--no-index', '--no-ext-diff', '--', input, target], {encoding: 'utf8'});
assert.equal(diffResult.status, 1, diffResult.stderr || String(diffResult.error));
const patch = diffResult.stdout.replace(/^diff --git .*$/m, 'diff --git a/ZPR_CLOSE_STOCK.abap b/ZPR_CLOSE_STOCK.abap')
  .replace(/^--- .*$/m, '--- a/ZPR_CLOSE_STOCK.abap').replace(/^\+\+\+ .*$/m, '+++ b/ZPR_CLOSE_STOCK.abap');
const patchFile = path.join(__dirname, 'ZPR_CLOSE_STOCK_naplo_WIP.diff');
fs.writeFileSync(patchFile, patch);

const checks = [];
function check(name, fn) { fn(); checks.push({name, result: 'PASS'}); }
check('source_baseline_unchanged_and_only_declared_logging_edits', () => {
  assert.equal(sha(input), baseHash);
  let restored = source.slice(0, -helpers.length);
  for (const {before, after} of [...replacements].reverse()) {
    assert.equal(restored.split(after).length, 2);
    restored = restored.replace(after, before);
  }
  assert.equal(restored, original);
});
check('business_database_LUW_proxy_and_payload_statements_unchanged', () => {
  const statements = s => s.match(/\b(?:UPDATE|DELETE FROM|COMMIT WORK|ROLLBACK WORK|lo_proxy->eon_dcqmcompleted\()[\s\S]*?\.(?:\r?\n|$)/g) || [];
  assert.deepEqual(statements(source), statements(original));
  const payload = s => s.match(/^  ls_input-.*$/gm);
  assert.deepEqual(payload(source), payload(original));
  assert(!/zcl_pr_stock=>close_stock\([^*]/.test(source.replace(/^\*.*$/gm, '')));
});
check('all_existing_forms_except_release_and_send_are_identical', () => {
  const forms = s => new Map([...s.matchAll(/^FORM (\w+)\b[\s\S]*?^ENDFORM\./gm)].map(m => [m[1], m[0]]));
  const before = forms(original), after = forms(source);
  for (const [name, body] of before) if (!['release_stock', 'send_priority'].includes(name)) assert.equal(after.get(name), body, name);
  for (const m of source.matchAll(/\bPERFORM (\w+)/gi)) assert(after.has(m[1].toLowerCase()), m[1]);
});
check('full_stock_counts_match_DHC_schema_without_ALV_or_fanout_join', () => {
  const ddl = fs.readFileSync(path.join(project, '01_SOURCES/DHC/2026-10-15_doc-rip/ZPRT_DCQM.table'), 'utf8');
  for (const field of ['package_id', 'doc_no', 'prd_stock_id']) assert(new RegExp('\\b' + field + '\\s*:').test(ddl), field);
  assert(helpers.includes('WHERE prd_stock_id = p_stokid.'));
  assert(!/\bgt_alv\b|\bJOIN\b|\bFOR ALL ENTRIES\b|\bSELECT DISTINCT\b/i.test(helpers));
  assert(helpers.includes('INSERT ls_row-package_id INTO TABLE lt_packages.'));
  assert(helpers.includes('INSERT ls_row-doc_no INTO TABLE lt_documents.'));
  assert(helpers.includes('DESCRIBE TABLE lt_rows LINES lv_count.'));
  assert(!/\b(gv_total|gv_excluded|gv_allowed|gv_error|gv_uncertain|gv_saved)\s*=/.test(helpers));
});
check('one_proxy_call_and_success_rejection_exception_end_events', () => {
  assert.equal((source.match(/lo_proxy->eon_dcqmcompleted\(/g) || []).length, 1);
  const send = source.match(/^FORM send_priority\.[\s\S]*?^ENDFORM\./m)[0];
  assert(send.indexOf('PERFORM log_at USING') < send.indexOf('lo_proxy->eon_dcqmcompleted('));
  assert.equal((send.match(/PERFORM log_inspire_end/g) || []).length, 4);
  assert(send.includes("PERFORM log_inspire_end USING 'S' text-314"));
  assert(send.includes("PERFORM log_inspire_end USING 'E' text-316"));
  assert(send.includes("PERFORM log_now USING 'E' text-318"));
});
check('only_new_report_texts_no_new_T100_or_class_or_include', () => {
  const tsv = fs.readFileSync(path.join(__dirname, 'ZPR_CLOSE_STOCK.texts.tsv'), 'utf8');
  const newRefs = new Set([...source.matchAll(/\btext-(3\d{2})\b/gi)].map(m => m[1]));
  const entries = tsv.trim().split(/\r?\n/).slice(1).map(l => l.split('\t')[0]);
  assert.deepEqual([...newRefs].sort(), entries.sort());
  assert(!/\btext-3\d{2}\b/i.test(original));
  assert.equal((source.match(/^\s*INCLUDE\b/gm) || []).length, (original.match(/^\s*INCLUDE\b/gm) || []).length);
});
check('diff_forward_and_reverse_restore_exact_CRLF_bytes', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'close-stock-log-'));
  const work = path.join(tmp, 'ZPR_CLOSE_STOCK.abap');
  try {
    fs.copyFileSync(input, work);
    for (const reverse of [false, true]) {
      const args = ['-c', 'core.autocrlf=false', 'apply', '--whitespace=nowarn'];
      if (reverse) args.push('--reverse');
      args.push(patchFile);
      const p = cp.spawnSync('git', args, {cwd: tmp, encoding: 'utf8'});
      assert.equal(p.status, 0, p.stderr || String(p.error));
      assert(fs.readFileSync(work).equals(fs.readFileSync(reverse ? input : target)));
    }
  } finally {
    if (fs.existsSync(work)) fs.unlinkSync(work);
    fs.rmdirSync(tmp);
  }
});
const parser = {executed: false, reason: 'No local ABAP parser available; SAP not accessed.'};
if (process.argv[2]) {
  const core = require(process.argv[2]);
  const cfg = core.Config.getDefault(core.Version.v754).get();
  cfg.rules = {parser_error: true};
  const registry = new core.Registry(new core.Config(JSON.stringify(cfg)));
  registry.addFile(new core.MemoryFile('zpr_close_stock.prog.abap', source));
  registry.parse();
  parser.executed = true;
  delete parser.reason;
  parser.version = core.Registry.abaplintVersion();
  parser.issues = registry.findIssues().map(i => ({row: i.getStart().getRow(), message: i.getMessage()}));
  assert.equal(parser.issues.length, 0, JSON.stringify(parser.issues));
}
fs.writeFileSync(path.join(__dirname, 'validation.json'), JSON.stringify({
  date: '2026-10-22', checks, parser, baselineSHA256: sha(input), reportSHA256: sha(target),
  diffSHA256: sha(patchFile), sapSyntaxCheck: false, atcSci: false, runtimeTest: false,
  scope: 'Only new files in this local directory; no other SAP object or original file changed.'
}, null, 2) + '\n');
console.log(JSON.stringify({checksPassed: checks.length, parser, report: target}, null, 2));
