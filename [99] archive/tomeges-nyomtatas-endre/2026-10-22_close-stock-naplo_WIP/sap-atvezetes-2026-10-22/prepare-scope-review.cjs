'use strict';
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const dir = __dirname;
const parent = path.dirname(dir);
const read = name => fs.readFileSync(path.join(dir, name), 'utf8').replace(/\r\n/g, '\n');
const activeReport = read('ZPR_CLOSE_STOCK-active-before.abap');
const activeClass = read('ZCL_PR_STOCK-active-before.abap');
const localReport = fs.readFileSync(path.join(parent, 'ZPR_CLOSE_STOCK.abap'), 'utf8').replace(/\r\n/g, '\n');
let report = activeReport;
let cls = activeClass;
function edit(source, before, after) {
  assert.equal(source.split(before).length, 2, before);
  return source.replace(before, after);
}
// Keep the active class-based workflow. The report records orchestration only.
report = edit(report, '  gv_busy = abap_true.\n  TRY.\n      DO 1 TIMES.',
  "  gv_busy = abap_true.\n  PERFORM log_now USING 'I' text-310 space.\n  TRY.\n      DO 1 TIMES.");
report = edit(report, '        lv_class_started = abap_true.\n        zcl_pr_stock=>close_stock( iv_stock = p_stokid ).',
  `        PERFORM log_stock_totals.
        PERFORM log_now USING 'I' text-313 space.
        lv_class_started = abap_true.
        zcl_pr_stock=>close_stock( iv_stock = p_stokid ).
        PERFORM log_now USING 'I' text-314 space.`);
report = edit(report, '        GET TIME.\n        UPDATE zprt_stock',
  "        GET TIME.\n        PERFORM log_now USING 'I' text-321 space.\n        UPDATE zprt_stock");
report = edit(report, "          PERFORM add_message USING 'E' text-206 p_stokid space.",
  "          PERFORM log_now USING 'E' text-323 space.\n          PERFORM add_message USING 'E' text-206 p_stokid space.");
report = edit(report, "        PERFORM add_message USING 'S' text-207 p_stokid space.",
  "        PERFORM log_now USING 'S' text-322 space.\n        PERFORM add_message USING 'S' text-207 p_stokid space.");
report = edit(report, "    PERFORM add_message USING 'E' text-208 p_stokid space.\n  ENDIF.\n  PERFORM log_write.",
  `    PERFORM add_message USING 'E' text-208 p_stokid space.
  ENDIF.
  IF gv_saved = abap_true.
    PERFORM log_now USING 'S' text-311 space.
  ELSE.
    PERFORM log_now USING 'E' text-312 space.
  ENDIF.
  PERFORM log_write.`);
const helpers = localReport.slice(localReport.indexOf('"Logging only:'));
assert(helpers.startsWith('"Logging only:'));
report += '\n' + helpers.slice(0, helpers.indexOf('FORM log_inspire_end'));
// Exact wire-call timing stays in the class where the proxy is invoked.
cls = edit(cls, '    DATA lv_logical_port_name TYPE prx_logical_port_name.',
  `    DATA lv_logical_port_name TYPE prx_logical_port_name.
    DATA: lv_call_start TYPE timestampl,
          lv_call_end TYPE timestampl,
          lv_log_stamp TYPE c LENGTH 40,
          lv_seconds TYPE p LENGTH 12 DECIMALS 3,
          lv_log_duration TYPE c LENGTH 40.`);
cls = edit(cls, '          CALL METHOD lo_dcqm->eon_dcqmcompleted',
  `          GET TIME STAMP FIELD lv_call_start.
          lv_log_stamp = |{ lv_call_start TIMESTAMP = ISO TIMEZONE = 'UTC' } UTC|.
          MESSAGE s000(zpr) WITH text-901 iv_stock lv_log_stamp INTO lv_dummy.
          lo_log->add_system_message( ).
          CALL METHOD lo_dcqm->eon_dcqmcompleted`);
cls = edit(cls, '              output = ls_output.\n        CATCH cx_ai_system_fault',
  '              output = ls_output.\n          GET TIME STAMP FIELD lv_call_end.\n        CATCH cx_ai_system_fault');
cls = edit(cls, '        CATCH cx_ai_system_fault INTO lx_system_fault.',
  '        CATCH cx_ai_system_fault INTO lx_system_fault.\n          GET TIME STAMP FIELD lv_call_end.');
cls = edit(cls, '        CATCH cx_ai_application_fault INTO DATA(lx_application_fault).',
  '        CATCH cx_ai_application_fault INTO DATA(lx_application_fault).\n          GET TIME STAMP FIELD lv_call_end.');
cls = edit(cls, '      ENDTRY.\n    ENDIF.\n\n* ---------------------------------------------------------------*\n* Hibakezelés',
  `      ENDTRY.
      IF lv_call_start IS NOT INITIAL AND lv_call_end IS NOT INITIAL.
        lv_log_stamp = |{ lv_call_end TIMESTAMP = ISO TIMEZONE = 'UTC' } UTC|.
        IF lv_error_flag IS INITIAL.
          MESSAGE s000(zpr) WITH text-902 iv_stock lv_log_stamp INTO lv_dummy.
        ELSE.
          MESSAGE e000(zpr) WITH text-903 iv_stock lv_log_stamp INTO lv_dummy.
        ENDIF.
        lo_log->add_system_message( ).
        TRY.
            lv_seconds = cl_abap_tstmp=>subtract(
              tstmp1 = lv_call_end tstmp2 = lv_call_start ).
            WRITE lv_seconds TO lv_log_duration LEFT-JUSTIFIED
              DECIMALS 3 NO-GROUPING.
            MESSAGE s000(zpr) WITH text-904 iv_stock lv_log_duration INTO lv_dummy.
            lo_log->add_system_message( ).
          CATCH cx_root.
            "Optional timing must not alter business error handling.
        ENDTRY.
      ENDIF.
    ENDIF.

* ---------------------------------------------------------------*
* Hibakezelés`);
function saveAndDiff(name, contents, originalName, diffName) {
  const output = path.join(dir, name);
  fs.writeFileSync(output, contents.replace(/\n/g, '\r\n'));
  const result = cp.spawnSync('git', ['-c','core.autocrlf=false','diff','--no-index','--no-ext-diff','--',path.join(dir, originalName),output], {encoding:'utf8'});
  assert.equal(result.status, 1, result.stderr);
  const canonical = result.stdout.replace(/^diff --git .*$/m, 'diff --git a/'+name+' b/'+name)
    .replace(/^--- .*$/m, '--- a/'+name).replace(/^\+\+\+ .*$/m, '+++ b/'+name);
  fs.writeFileSync(path.join(dir,diffName),canonical);
}
saveAndDiff('ZPR_CLOSE_STOCK-DHC100-javaslat.abap',report,'ZPR_CLOSE_STOCK-active-before.abap','ZPR_CLOSE_STOCK-DHC100-javaslat.diff');
saveAndDiff('ZCL_PR_STOCK-inspire-javaslat.abap',cls,'ZCL_PR_STOCK-active-before.abap','ZCL_PR_STOCK-inspire-javaslat.diff');
const reportTexts = fs.readFileSync(path.join(parent, 'ZPR_CLOSE_STOCK.texts.tsv'), 'utf8')
  .replace('Inspire DCQMCompleted hívás indul:', 'CLOSE_STOCK osztályhívás indul:')
  .replace('Inspire hívás vége - sikeres válasz:', 'CLOSE_STOCK osztályhívás visszatért:');
fs.writeFileSync(path.join(dir, 'ZPR_CLOSE_STOCK-DHC100-javaslat.texts.tsv'), reportTexts);
const statementList = s => s.match(/^\s*(?:UPDATE|DELETE FROM|COMMIT WORK|ROLLBACK WORK|zcl_pr_stock=>close_stock\(|CALL METHOD lo_dcqm->eon_dcqmcompleted)[\s\S]*?\.(?:\n|$)/gm);
assert.deepEqual(statementList(report),statementList(activeReport));
assert.deepEqual(statementList(cls),statementList(activeClass));
assert(report.includes('       PERFORM release_stock_new.'));
assert(!cls.includes('iv_extnumber'));
console.log(JSON.stringify({localReviewOnly:true,activeSAPObjectsWritten:false,reportWorkflowPreserved:true,classPayloadAndLUWPreserved:true,extraClassTextElements:4}));
