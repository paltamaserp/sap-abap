const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');
const crypto = require('crypto');
const cp = require('child_process');
const dir = __dirname;
const project = path.resolve(dir, '../..');
const root = path.resolve(project, '../..');
const temp = path.join(root, '.tmp/cockpit-20261016/patch-check');
fs.mkdirSync(temp, {recursive: true});
const read = file => fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
const get = name => read(path.join(dir, name));
const historicalProject = path.join(root, '[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/project');
const baselineReport = read(path.join(historicalProject, '05_FINAL/abap-2026-10-16/ZPR_DCQM_EXCLUDE.abap'));
const report = get('ZPR_DCQM_EXCLUDE.abap');
const adapter = get('ZPR_DCQM_EXCLUDE_C01.abap');
const qm = get('ZPR_QM.abap');
const qmBase = read(path.join(project, '01_SOURCES/QU5/ZPR_QM.abap'));
const cockpit = get('LZPR_COCKPITTOP.abap') + '\n' + get('LZPR_COCKPITO01.abap') + '\n' + get('Z_PR_COCKPIT.abap');
function code(text) {
  return text.split('\n').filter(l => !/^\s*\*/.test(l)).map(l => l.replace(/".*$/, '')).join('\n');
}
const reportCode = code(report + '\n' + adapter + '\n' + get('ZPR_DCQM_EXCLUDE_O01.abap') + '\n' + get('ZPR_DCQM_EXCLUDE_I01.abap'));
const cockpitCode = code(cockpit);
// Internal results must never be accepted as function codes from the screen.
assert(!/'#(?:STOCK|CANCEL)'/i.test(cockpitCode), 'Hidden internal OK-code remains');
assert.deepEqual([...cockpitCode.matchAll(/^\s*save_ok\s*=\s*([^\n]+)/gmi)].map(m => m[1].trim()), ['ok_code.']);
const prepareCommand = /MODULE prepare_command INPUT\.[\s\S]*?ENDMODULE\./i.exec(cockpitCode)[0];
assert(/CLEAR: gv_stock_changed, gv_dm_close_cancelled\.[\s\S]*?PERFORM accept_stock\.[\s\S]*?IF gv_stock_changed = abap_true OR gv_dm_close_cancelled = abap_true\.\s+LEAVE TO SCREEN 100\./i.test(prepareCommand));
assert(/DATA: gv_stock_changed\s+TYPE abap_bool,\s+gv_dm_close_cancelled TYPE abap_bool\./i.test(cockpitCode));
function form(text, name) {
  const m = new RegExp('^FORM\\s+' + name + '\\b[\\s\\S]*?^ENDFORM\\.[^\\n]*', 'mi').exec(text);
  assert(m, 'Missing FORM: ' + name);
  return m[0];
}
// These are the business operations that the integration must preserve.
for (const name of ['select_data', 'save_row', 'check_stockid', 'build_ranges',
  'check_changed', 'check_entered_data', 'check_entered_data_popup', 'unlock_stock']) {
  assert.equal(form(report, name), form(baselineReport, name), 'Unexpected business change: ' + name);
}
const oldCockpit = read(path.join(project, '01_SOURCES/DHC/ZPR_COCKPIT/LZPR_COCKPITO01.abap'));
for (const text of [oldCockpit, get('LZPR_COCKPITO01.abap')]) {
  const transitions = [...text.matchAll(/zcl_pr_stock=>(check_status|update_status)\([\s\S]*?\)\./gi)].map(m => m[0]);
  if (text === oldCockpit) var previousTransitions = transitions;
  else assert.deepEqual(transitions, previousTransitions, 'Existing stock actions changed');
}
const forms = new Set([...reportCode.matchAll(/^FORM\s+(\w+)/gmi)].map(m => m[1].toLowerCase()));
const qmCode = code(qm);
const qmForms = new Set([...qmCode.matchAll(/^FORM\s+(\w+)/gmi)].map(m => m[1].toLowerCase()));
for (const m of reportCode.matchAll(/\bPERFORM\s+(\w+)/gi)) assert(forms.has(m[1].toLowerCase()), 'Unresolved report FORM: ' + m[1]);
const groupForms = new Set([...cockpitCode.matchAll(/^FORM\s+(\w+)/gmi)].map(m => m[1].toLowerCase()));
for (const m of cockpitCode.matchAll(/\bPERFORM\s+(\w+)([\s\S]*?)\./gi)) {
  const name = m[1].toLowerCase();
  if (/IN PROGRAM (zpr_dcqm_exclude|zpr_qm)/i.test(m[2])) {
    const isQm = /IN PROGRAM zpr_qm\b/i.test(m[2]);
    assert((isQm ? qmForms : forms).has(name), 'Missing external adapter: ' + name);
    const actual = m[2].replace(/IN PROGRAM (zpr_dcqm_exclude|zpr_qm)/i, '').trim().split(/\s+/).filter(t => t && !/^(USING|CHANGING)$/i.test(t));
    const definition = form(isQm ? qmCode : reportCode, name).split('.')[0];
    const expected = [...definition.matchAll(/\bTYPE\s+\w+/gi)].length;
    assert.equal(actual.length, expected, 'External FORM parameter count: ' + name);
  } else assert(groupForms.has(name), 'Unresolved cockpit FORM: ' + name);
}
const modules = new Set([...cockpitCode.matchAll(/^MODULE\s+(\w+)/gmi)].map(m => m[1].toLowerCase()));
for (const file of ['ZPR_COCKPIT_0100.flow.abap','ZPR_COCKPIT_1010.flow.abap']) {
  for (const m of code(get(file)).matchAll(/MODULE\s+(\w+)/gi)) assert(modules.has(m[1].toLowerCase()), 'Missing screen module: ' + m[1]);
}
assert(!/\b(SUBMIT|CALL TRANSACTION|LEAVE PROGRAM)\b/i.test(cockpitCode + '\n' + code(adapter)));
assert(!/\b(SET PF-STATUS|SET TITLEBAR|SET SCREEN|LEAVE SCREEN|LEAVE TO SCREEN|LEAVE LIST-PROCESSING)\b/i.test(code(adapter)));
const actualFilters = [...baselineReport.matchAll(/^\s*(so_\w+)\s+FOR\s+/gmi)].map(m => m[1].toLowerCase()).sort();
const reset = /REFRESH:([\s\S]*?)\./i.exec(adapter)[1];
assert.deepEqual([...reset.matchAll(/\bso_\w+/gi)].map(m => m[0].toLowerCase()).sort(), actualFilters);
assert(/PERFORM leave_alv/.test(form(report, 'save_data')));
assert(/IF gv_embedded = abap_false\.\s+PERFORM leave_alv\./.test(form(report, 'save_data')));
assert(/AUTHORITY-CHECK OBJECT 'S_TCODE'[\s\S]*?IF sy-subrc <> 0\./.test(adapter));
const flow = get('ZPR_COCKPIT_0100.flow.abap');
assert(flow.indexOf('CALL SUBSCREEN t_sub_sc.', flow.indexOf('PROCESS AFTER INPUT.')) < flow.indexOf('  MODULE user_command.'));
assert(/INCLUDING gs_tabstrip-prog gs_tabstrip-subscreen/i.test(flow), 'External QM screen program must be honored');
const classImplementation = text => /CLASS lcl_qm IMPLEMENTATION\.[\s\S]*?ENDCLASS\./i.exec(text)[0];
assert.equal(classImplementation(qm), classImplementation(qmBase), 'QM business controller changed');
for (const block of ['b_main','b_layout']) {
  const expression = new RegExp('SELECTION-SCREEN BEGIN OF BLOCK ' + block + '\\b[\\s\\S]*?SELECTION-SCREEN END OF BLOCK ' + block + '\\.', 'i');
  assert.equal(expression.exec(qm)[0], expression.exec(qmBase)[0], 'Original QM input block changed');
}
assert(/SELECTION-SCREEN BEGIN OF SCREEN 1100 AS SUBSCREEN/i.test(qmCode));
assert(/INCLUDE BLOCKS b_main[\s\S]*?INCLUDE BLOCKS b_layout/i.test(qmCode));
assert(/gs_tabstrip-prog = 'ZPR_QM'\.\s+gs_tabstrip-subscreen = '1100'/i.test(cockpitCode));
const qmOpen = code(form(qm,'cockpit_open'));
assert(/AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD 'ZPR_QM'/i.test(qmOpen));
assert(!/lcl_qm=>start\(|\b(?:COMMIT|UPDATE|ENQUEUE|CALL SELECTION-SCREEN|CALL TRANSACTION|SUBMIT)\b/i.test(qmOpen));
assert(/p_stock = iv_stock_id/i.test(qmOpen));
assert(/gv_cockpit_stock <> iv_stock_id/i.test(qmOpen));
assert(/CLEAR: p_disp, p_rel, p_relb, p_vari, gv_cockpit_run_requested/i.test(qmOpen));
const qmExecute = code(form(qm,'cockpit_execute'));
assert(qmExecute.indexOf('CLEAR gv_cockpit_run_requested.') < qmExecute.indexOf('SUBMIT zpr_qm'));
assert(!/lcl_qm=>start\s*\(/i.test(qmExecute), 'External adapter must not start screen 2000 in the host program group');
assert(/SUBMIT zpr_qm[\s\S]*?AND RETURN\./i.test(qmExecute));
for (const name of ['p_stock','p_mod','p_disp','p_rel','p_relb','p_vari']) {
  const value = name === 'p_stock' ? 'gv_cockpit_stock' : name;
  assert(new RegExp('WITH ' + name + '\\s*=\\s*' + value + '\\b', 'i').test(qmExecute), 'Missing QM submit value: ' + name);
}
assert(/PUSHBUTTON \/1\(24\) pb_qrun USER-COMMAND qrun/i.test(qmCode));
assert(/pb_qrun = 'QM indítása'\(101\)/i.test(qmCode));
assert(/PERFORM cockpit_execute IN PROGRAM zpr_qm[\s\S]*?IF gv_qm_command_handled = abap_true\.\s+CLEAR save_ok\.\s+RETURN/i.test(cockpitCode));
assert(/screen-name = 'P_STOCK'\.\s+screen-input = 0/i.test(qmCode));
assert(/AT SELECTION-SCREEN\.\s+IF sy-dynnr = '1100'[\s\S]*?gv_cockpit_run_requested = abap_true\.\s+CLEAR sscrfields-ucomm\.\s+ENDIF\./i.test(qmCode));
assert(/PERFORM qm_close/i.test(form(cockpit,'reset_cockpit')));
assert(/PERFORM qm_close/i.test(form(cockpit,'accept_stock')));
assert(/MODULE cancel INPUT\.[\s\S]*?PERFORM qm_close\.\s+LEAVE TO SCREEN 0/i.test(cockpitCode));
// A host-provided parent must not trigger the old container-initial guard.
const createControls = code(form(report, 'create_controls_0100'));
assert(!/CHECK go_alv_grid_cont_01 IS INITIAL/i.test(createControls));
assert(/IF go_alv_grid_cont_01 IS INITIAL\.\s+CREATE OBJECT go_alv_grid_cont_01/i.test(createControls));
assert(/MODULE dm_controls OUTPUT\.[\s\S]*?CREATE OBJECT go_dm_container[\s\S]*?USING go_dm_container\./i.test(cockpitCode));
const dmControls = /MODULE dm_controls OUTPUT\.[\s\S]*?ENDMODULE\./i.exec(cockpitCode)[0];
assert(!/\b(repid|dynnr|no_autodef_progid_dynnr)\s*=/i.test(dmControls), 'Subscreen constructor must use automatic dynpro binding');
assert(/go_alv_grid_cont_01 = io_container\./i.test(form(adapter, 'cockpit_pbo')));
assert(/IF lv_ok = abap_true\.\s+FREE go_dm_container\.\s+CLEAR gv_dm_ready/i.test(code(form(cockpit, 'dm_close'))));
const dmClose = code(form(cockpit, 'dm_close'));
assert(/CLEAR gv_dm_close_cancelled\.\s+CHECK gv_dm_ready = abap_true\./i.test(dmClose), 'Stale cancellation on inactive DM');
assert(/ELSE\.\s+gv_dm_close_cancelled = abap_true\./i.test(dmClose));
assert(/PERFORM dm_close\.\s+CHECK gv_dm_close_cancelled = abap_false\./i.test(code(form(cockpit, 'reset_cockpit'))));
assert(/PERFORM dm_open\.\s+gv_stock_changed = abap_true\./i.test(code(form(cockpit, 'accept_stock'))));
assert(/\t102\tA DM lista képernyőkonténere nem hozható létre\./.test(get('2026-10-17_cockpit-textelemek_WIP.tsv')));
function git(args, cwd = root, allowed = [0]) {
  const r = cp.spawnSync('git', ['-c', 'safe.directory=' + root.replaceAll('\\','/'), '-c', 'core.autocrlf=false', ...args], {
    cwd, encoding:'utf8',
    env: {...process.env, GIT_CEILING_DIRECTORIES:path.dirname(temp)}
  });
  assert(allowed.includes(r.status), r.stderr || r.stdout || String(r.error));
  return r.stdout;
}
const pairs = [
  ['LZPR_COCKPITTOP.abap', '01_SOURCES/DHC/ZPR_COCKPIT/LZPR_COCKPITTOP.abap'],
  ['LZPR_COCKPITO01.abap', '01_SOURCES/DHC/ZPR_COCKPIT/LZPR_COCKPITO01.abap'],
  ['Z_PR_COCKPIT.abap', '01_SOURCES/DHC/ZPR_COCKPIT/Z_PR_COCKPIT.abap'],
  ['ZPR_COCKPIT_0100.flow.abap', '01_SOURCES/DHC/0100_Nyomtatáscockpittabstryp.screen'],
  ['ZPR_COCKPIT_1010.flow.abap', '01_SOURCES/DHC/1010_DMtételek.abap'],
  ['ZPR_DCQM_EXCLUDE.abap', path.relative(project, path.join(historicalProject, '05_FINAL/abap-2026-10-16/ZPR_DCQM_EXCLUDE.abap'))],
  ['ZPR_DCQM_EXCLUDE_C01.abap', null],
  ['ZPR_QM.abap', '01_SOURCES/QU5/ZPR_QM.abap']
];
let patch = '';
for (const [name, old] of pairs) {
  const before = old ? read(path.join(project, old)) : '';
  const after = get(name);
  fs.writeFileSync(path.join(temp, 'before.txt'), before);
  fs.writeFileSync(path.join(temp, 'after.txt'), after);
  const raw = git(['diff','--no-index','--','before.txt','after.txt'], temp, [1]);
  const hunk = raw.indexOf('@@');
  assert(hunk >= 0);
  patch += `diff --git a/${name} b/${name}\n` + (old ? '' : 'new file mode 100644\n')
    + `--- ${old ? 'a/' + name : '/dev/null'}\n+++ b/${name}\n` + raw.slice(hunk);
  if (old) fs.writeFileSync(path.join(temp, name), before);
}
const patchPath = path.join(dir, 'ABAP-valtozasok_WIP.diff');
fs.writeFileSync(patchPath, patch);
git(['apply','--check',patchPath], temp);
git(['apply',patchPath], temp);
for (const [name] of pairs) assert.equal(read(path.join(temp,name)), get(name), 'Forward patch mismatch: ' + name);
git(['apply','--check','--reverse',patchPath], temp);
git(['apply','--reverse',patchPath], temp);
for (const [name, old] of pairs) {
  if (old) assert.equal(read(path.join(temp,name)), read(path.join(project, old)), 'Reverse patch mismatch: ' + name);
  else assert(!fs.existsSync(path.join(temp,name)), 'New file remains after reverse');
}
const files = fs.readdirSync(dir).filter(f => f.endsWith('.abap'));
const hashes = Object.fromEntries(files.map(file => [file, crypto.createHash('sha256').update(fs.readFileSync(path.join(dir,file))).digest('hex')]));
const result = {
  status:'WIP', date:'2026-10-18',
  checks: {localFormResolution:true, externalAdapterParameterCounts:true,
    screenModuleResolution:true, selectionFilterResetComplete:true,
    businessFormsPreserved:true, existingStatusActionsPreserved:true,
    embeddedNavigationRestricted:true, transactionAuthorityCheck:true,
    hostParentReferenceWiring:true, standaloneContainerCreationPreserved:true,
    hostDynproBindingAutomatic:true,
    internalResultsIndependentOfFunctionCodes:true, cancellationClearedBeforeInactiveDmReturn:true,
    hostReferenceReleasedOnlyAfterConfirmedClose:true, newErrorTextDocumented:true,
    qmExternalSelectionSubscreen:true, qmOriginalInputBlocksAndBusinessControllerPreserved:true,
    qmStockPrefilledAndReadOnly:true, qmNoBusinessOperationOnTabOpen:true,
    qmExecuteRequestConsumedBeforeDispatch:true, qmResetExitAndStockSwitchCleanup:true,
    qmEditorRunsInSeparateReportSession:true, qmAllSixSubmitValuesPassed:true,
    qmButtonHasTranslatableDefaultText:true,
    diffForwardAndReverse:'exact normalized source match'},
  parser:null, sapCompilation:false, atc:false, functionalTest:false,
  limitation:'Csak helyi szerkezeti és diffellenőrzés; az SAP-futtatás, aktív forrás, képernyőgeometria, DDIC és üzleti működés nincs ellenőrizve.',
  sha256:hashes
};
fs.writeFileSync(path.join(dir,'HELYI-ELLENORZES_WIP.json'), JSON.stringify(result,null,2) + '\n');
console.log(JSON.stringify(result.checks,null,2));
