const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const assert = require('assert/strict');
const project = path.resolve(__dirname, '../..');
const daily = path.join(project, '05_FINAL/abap-2026-10-17');
const read = file => fs.readFileSync(file, 'utf8');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const report = read(path.join(__dirname, 'ZPR_CLOSE_STOCK.abap'));
const stockClass = read(path.join(__dirname, 'ZCL_PR_STOCK.abap'));
const classBase = read(path.join(project, '01_SOURCES/DHC/ZCL_PR_STOCK.abap'));
const active = source => source.split(/\r?\n/).filter(l => !/^\s*\*/.test(l))
  .map(l => l.replace(/".*$/, '')).join('\n');
const getForm = (source, name) => new RegExp('^FORM ' + name + '\\b[\\s\\S]*?^ENDFORM\\.', 'mi').exec(source)[0];
const getMethod = (source, name) => new RegExp('^\\s*METHOD ' + name + '\\.[\\s\\S]*?^\\s*ENDMETHOD\\.', 'mi').exec(source)[0];
const normalize = value => value.replace(/\r\n/g, '\n').trim();
const checks = [];
function check(name, run) {run(); checks.push(name);}

check('originalReportUnchanged', () => assert.equal(sha(path.join(daily, 'ZPR_CLOSE_STOCK.abap')), 'a527b0f65c82a4d995007f35764c76a2a4e7ca465e014a5650643acea8265eec'));
check('originalClassUnchanged', () => assert.equal(sha(path.join(project, '01_SOURCES/DHC/ZCL_PR_STOCK.abap')), 'fa7efec820d9a5538c7455317fe1cad69dfa5a6e513d101c40ead701ff6a78aa'));
let expanded = report;
for (const name of ['ZPR_STOCK_REPORT_O01', 'ZPR_STOCK_REPORT_I01']) {
  const file = name + '.abap';
  check(file + 'Unchanged', () => assert.equal(sha(path.join(__dirname, file)), sha(path.join(daily, file))));
  expanded = expanded.replace(new RegExp('INCLUDE ' + name + '\\.', 'i'), read(path.join(__dirname, file)));
}
check('allFormsResolved', () => {
  const forms = new Set([...active(expanded).matchAll(/^FORM\s+(\w+)/gmi)].map(m => m[1].toLowerCase()));
  for (const m of active(expanded).matchAll(/\bPERFORM\s+(\w+)/gi)) assert(forms.has(m[1].toLowerCase()), m[1]);
});
check('allClassMethodsImplemented', () => {
  const definitions = [...active(stockClass).matchAll(/CLASS-METHODS\s+(\w+)/gi)].map(m => m[1].toLowerCase());
  const implementations = [...active(stockClass).matchAll(/^\s*METHOD\s+(\w+)\./gmi)].map(m => m[1].toLowerCase());
  assert.deepEqual([...definitions].sort(), [...implementations].sort());
  assert(!/\b(?:PERFORM|p_stokid|gt_alv|gv_saved|gv_locked_stock|gv_remote_success)\b/i.test(active(stockClass)));
});
check('unrelatedClassMethodsUnchanged', () => {
  for (const name of ['check_status', 'get_stock_header', 'update_status']) {
    assert.equal(normalize(getMethod(stockClass, name)), normalize(getMethod(classBase, name)));
  }
});
check('singleInspireCallInClassOnly', () => {
  assert(!/eon_dcqmcompleted|UPDATE\s+zprt_stock|DELETE\s+FROM/i.test(active(report)));
  assert.equal([...active(stockClass).matchAll(/lo_proxy->eon_dcqmcompleted\(/gi)].length, 1);
  assert.equal([...getForm(report, 'release_stock').matchAll(/zcl_pr_stock=>close_stock\(/gi)].length, 1);
  assert(/iv_priority\s+IS SUPPLIED/i.test(getMethod(stockClass, 'close_stock')));
});
check('lockBeforeScreenAndToolbarRequiresOwnLock', () => {
  const start = active(report).split('START-OF-SELECTION.')[1].split('INCLUDE')[0];
  assert(start.indexOf('PERFORM sync_lock.') < start.indexOf('CALL SCREEN 0100.'));
  assert(/gv_locked_stock = p_stokid/i.test(getMethod(report, 'on_toolbar')));
  assert(/gv_locked_stock <> p_stokid/i.test(getForm(report, 'release_stock')));
  assert(/iv_lock_held = abap_true/i.test(getForm(report, 'release_stock')));
  assert(/iv_display_log = abap_false/i.test(getForm(report, 'release_stock')));
  assert(/PERFORM unlock_stock/i.test(getForm(report, 'exit_screen')));
});
check('explicitRemoteSuccessBeforeSaving', () => {
  assert(/ls_output-parameters-success <> abap_true/i.test(getMethod(stockClass, 'send_priority')));
  assert(/lv_remote_success <> abap_true[\s\S]*?EXIT\.[\s\S]*?save_release\(/i.test(getMethod(stockClass, 'close_stock')));
  const save = getMethod(stockClass, 'save_release');
  assert(/COMMIT WORK\.\s*ev_saved = abap_true/i.test(save));
  assert(/sy-subrc <> 0 OR sy-dbcnt <> 1/i.test(save));
});
check('closeFieldsAndUpdatePredicatePreserved', () => {
  const save = getMethod(stockClass, 'save_release');
  const update = /UPDATE zprt_stock\s+SET[\s\S]*?\./i.exec(save)[0];
  for (const field of ['closed','status','priority','erdat_clo','ernam_clo','ertim_clo','chuser','chdate','chtime']) {
    assert(new RegExp('\\b' + field + '\\s*=', 'i').test(update), field);
  }
  assert(/WHERE stock_id = iv_stock\s+AND closed = space\s+AND status = gc_status_qm\s+AND stock_status_er = space/i.test(update));
  assert(!/\b(?:cruser|crdate|crtime)\s*=/i.test(update));
  assert(!/update_status\(/i.test(getMethod(stockClass, 'close_stock')));
});
check('excludedEnvelopeAndRegmailPathPreserved', () => {
  assert(/ls_input-exclude_envelopes-envelope = lt_envelopes/i.test(getMethod(stockClass, 'send_priority')));
  const prepare = getMethod(stockClass, 'prepare_regmail');
  assert(/WHERE zisu_ragszam_128 = ls_alv-regmailnumber\s+AND envelope_id = ls_alv-envelope\s+AND exbilldocno = ls_alv-doc_no/i.test(prepare));
  const save = getMethod(stockClass, 'save_release');
  assert(/DELETE FROM \(gc_terti_table\)/i.test(save));
  assert(/DELETE FROM \(gc_f064_table\)/i.test(save));
});
check('viewHeaderDoesNotInvokeRelease', () => {
  const header = getForm(report, 'build_header');
  assert(!/release_stock|close_stock\(|gv_saved/i.test(header));
  for (const field of ['p_stokid','gv_total','gv_excluded','gv_allowed']) assert(header.includes(field));
  assert(/PERFORM build_header/i.test(getForm(report, 'refresh_grid')));
  assert(/MESSAGE gv_block_reason TYPE 'I'/i.test(getForm(report, 'show_mode_message')));
});
check('textReferencesComplete', () => {
  for (const [name, source] of [['ZPR_CLOSE_STOCK', report], ['ZCL_PR_STOCK', stockClass]]) {
    const ids = new Set(read(path.join(__dirname, name + '.texts.tsv')).trim().split(/\r?\n/).slice(1).map(l => l.split('\t')[0]));
    for (const m of source.matchAll(/\btext-(\d{3})\b/gi)) {
      if (Number(m[1]) >= 101) assert(ids.has(m[1]), name + ':' + m[1]);
    }
  }
  assert(!active(report).includes('|'));
});
check('sevenHarmlessModeRegressionTestsIncluded', () => assert.equal([...report.matchAll(/\w+\s+FOR TESTING[,\.]/gi)].length, 7));

if (process.argv[2]) {
  const core = require(path.resolve(process.argv[2]));
  const config = core.Config.getDefault(core.Version.v754).get();
  config.rules = {parser_error:true};
  const registry = new core.Registry(new core.Config(JSON.stringify(config)));
  registry.addFile(new core.MemoryFile('zpr_close_stock.prog.abap', expanded));
  registry.addFile(new core.MemoryFile('zcl_pr_stock.clas.abap', stockClass));
  registry.parse();
  const issues = registry.findIssues().map(i => ({file:i.getFilename(), row:i.getStart().getRow(), message:i.getMessage()}));
  fs.writeFileSync(path.join(__dirname, 'parser-check.json'), JSON.stringify({tool:'@abaplint/core',
    version:core.Registry.abaplintVersion(), abapVersion:'7.54', issues}, null, 2) + '\n');
  assert.equal(issues.length, 0, JSON.stringify(issues));
}

const result = {kind:'local source and integration contract checks', checks, passed:checks.length,
  sapConnected:false, sapCompilation:false, atc:false, abapUnitExecuted:false};
fs.writeFileSync(path.join(__dirname, 'source-check.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result));
