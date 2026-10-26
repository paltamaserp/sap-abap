const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const assert = require('assert/strict');
const project = path.resolve(__dirname, '../..');
const base = path.join(project, '05_FINAL/abap-2026-10-17/ZPR_DC_FRAME.abap');
const legacy = path.join(project, '01_SOURCES/QU5/ZEBF_PR_DC_FRAME.abap');
const logReference = path.join(project, '05_FINAL/abap-2026-10-17/ZPR_CREATE_STOCK.abap');
const target = path.join(__dirname, 'ZPR_DC_FRAME.abap');
let source = fs.readFileSync(base, 'utf8').replace(/\r\n/g, '\n');
function replaceOnce(before, after) {
  assert.equal(source.split(before).length, 2, 'Expected exactly one occurrence: ' + before);
  source = source.replace(before, after);
}
replaceOnce('* Tranzakció: ZPR_DC (report transaction, szelekciós kép 1000) ???',
  '* Local transfer package: 2026-10-22; selection screen 1000.');
replaceOnce('DATA: gs_stock TYPE zprt_stock,\n      gv_dummy TYPE string.\n* LOG\nDATA: go_log TYPE REF TO zcl_pr_log.', `TYPES: BEGIN OF ty_stock_f4,
         stock_id TYPE zprt_stock-stock_id,
         status   TYPE zprt_stock-status,
         closed   TYPE zprt_stock-closed,
         dccompl  TYPE zprt_stock-dccompl,
         qmcompl  TYPE zprt_stock-qmcompl,
       END OF ty_stock_f4.

DATA: gs_stock TYPE zprt_stock.`);
replaceOnce('PARAMETERS: p_stokid TYPE zprd_stock_id\n              OBLIGATORY\n              MATCHCODE OBJECT zprh_stock.',
  'PARAMETERS: p_stokid TYPE zprd_stock_id OBLIGATORY.');
replaceOnce('START-OF-SELECTION.', `AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_stokid.
  PERFORM stock_f4.

START-OF-SELECTION.`);
replaceOnce('        lv_error     TYPE abap_bool,', '        lv_error     TYPE abap_bool,\n        lv_log_error TYPE abap_bool,');
replaceOnce('  PERFORM log_write USING lt_msg.', `  PERFORM log_write USING lt_msg CHANGING lv_log_error.
  IF lv_log_error EQ abap_true.
    RETURN.
  ENDIF.`);
// BAL_T_MSG and BAL_T_LOGH may use table categories that reject APPEND.
source = source.replace(/APPEND ls_msg TO (lt_msg|ct_msg)\./g, 'INSERT ls_msg INTO TABLE $1.');
const logStart = source.indexOf('FORM log_write USING ut_msg TYPE bal_t_msg.');
assert(logStart >= 0);
// Adapt only the logging FORM from the user-designated FINAL file.
// Its REPORT name differs from its filename; no stock logic is imported.
const reference = fs.readFileSync(logReference, 'utf8').replace(/\r\n/g, '\n');
const logMatch = reference.match(/^FORM log_write\.[\s\S]*?^ENDFORM\./m);
assert(logMatch, 'Missing LOG_WRITE in FINAL logging reference');
const logForm = logMatch[0]
  .replace('FORM log_write.', 'FORM log_write USING ut_msg TYPE bal_t_msg\n               CHANGING cv_error TYPE abap_bool.')
  .replace('lv_text TYPE string.', 'lv_text TYPE string,\n        lv_dummy TYPE string.')
  .replace(/\blo_log\b/g, 'lr_log')
  .replace(/\bgv_log_error\b/g, 'cv_error')
  .replace(/\bgt_messages\b/g, 'ut_msg')
  .replace(/\bgv_dummy\b/g, 'lv_dummy')
  .replace(/\bgc_log_subobject\b/g, 'gc_log_subobj')
  .replace("'A napló nem menthető/megjeleníthető:'", 'text-102');
source = source.slice(0, logStart) + logForm + '\n\n' + `FORM stock_f4.
  DATA: lt_stocks  TYPE STANDARD TABLE OF ty_stock_f4,
        lt_returns TYPE STANDARD TABLE OF ddshretval,
        ls_return  TYPE ddshretval.

  SELECT stock_id status closed dccompl qmcompl
    FROM zprt_stock INTO TABLE lt_stocks UP TO 5000 ROWS
    ORDER BY stock_id DESCENDING.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield        = 'STOCK_ID'
      value_org       = 'S'
      window_title    = text-101
    TABLES
      value_tab       = lt_stocks
      return_tab      = lt_returns
    EXCEPTIONS
      parameter_error = 1
      no_values_found = 2
      OTHERS          = 3.
  IF sy-subrc = 0.
    READ TABLE lt_returns INTO ls_return INDEX 1.
    IF sy-subrc = 0.
      p_stokid = ls_return-fieldval.
    ENDIF.
  ENDIF.
ENDFORM.                    " STOCK_F4
`;
fs.writeFileSync(target, source.replace(/\n/g, '\r\n'));
function diff(input, name, label) {
  const result = cp.spawnSync('git', ['-c', 'core.autocrlf=false', 'diff', '--no-index', '--no-ext-diff', '--', input, target], {encoding: 'utf8'});
  assert.equal(result.status, 1, result.stderr || String(result.error));
  const patch = result.stdout.replace(/^diff --git .*$/m, 'diff --git a/' + label + ' b/ZPR_DC_FRAME.abap')
    .replace(/^--- .*$/m, '--- a/' + label).replace(/^\+\+\+ .*$/m, '+++ b/ZPR_DC_FRAME.abap');
  fs.writeFileSync(path.join(__dirname, name), patch);
}
diff(base, 'DHC-valtozasok_WIP.diff', 'ZPR_DC_FRAME.abap');
diff(legacy, 'QU5-DHC-atultetes_WIP.diff', 'ZPR_DC_FRAME.abap');
console.log('Created ZPR_DC_FRAME.abap and two baseline-specific diffs.');
