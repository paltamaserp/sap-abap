const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const os = require('os');
const crypto = require('crypto');
const assert = require('assert/strict');
const root = 'C:/Users/T13214/Documents/work/sap-abap-main';
const dir = path.join(root, '[03] projects/tomeges-nyomtatas-endre/03_DRAFTS/2026-10-21_release-stock-new-riport_WIP');
const base = path.resolve(dir, '../../05_FINAL/abap-2026-10-17');
const name = 'ZPR_CLOSE_STOCK.abap';
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read = file => fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
const original = read(path.join(base, name));
const report = read(path.join(dir, name));
const cls = read(path.join(base, 'ZCL_PR_STOCK.class.abap'));
const routine = report.match(/^FORM release_stock_new\.[\s\S]*?^ENDFORM\.\n\n/m)[0];
const checks = [];
function check(name, fn) { fn(); checks.push(name); }
check('exact_05_FINAL_base_and_class_unchanged', () => {
  assert.equal(sha(path.join(base, name)), 'bb5c6e1fd26f395a981d8ab0a3ac84a93c2f12888a04cd377766119c5911339e');
  assert.equal(sha(path.join(base, 'ZCL_PR_STOCK.class.abap')), '90a9893883cc9976974193feec6b2a86c498ff3ff73604e79b78f6df9b9f662e');
  assert(!fs.existsSync(path.join(dir, 'ZCL_PR_STOCK.class.abap')));
});
check('only_button_and_new_form_changed', () => {
  const restored = report.replace(routine, '').replace('       PERFORM release_stock_new.', '       PERFORM release_stock.');
  assert.equal(restored, original);
  assert.equal((routine.match(/zcl_pr_stock=>close_stock\( iv_stock = p_stokid \)/g) || []).length, 1);
  assert(!/iv_remote_only|ev_success|ev_remote_success|it_exclude_envelopes|->eon_dcqmcompleted/.test(routine));
});
check('preconditions_and_fresh_post_call_CL_check', () => {
  for (const part of ['AUTHORITY-CHECK', 'gv_locked_stock <> p_stokid', 'PERFORM determine_mode.', 'PERFORM select_data.', 'lt_displayed <> gt_alv', 'IF gv_total = 0.']) assert(routine.includes(part), part);
  const call = routine.indexOf('zcl_pr_stock=>close_stock(');
  const select = routine.indexOf('SELECT SINGLE * FROM zprt_stock BYPASSING BUFFER');
  const guard = routine.indexOf('IF ls_after-status <> gc_status_closed.');
  const update = routine.indexOf('UPDATE zprt_stock');
  assert(call < select && select < guard && guard < update);
  assert(routine.indexOf('RETURN.') < call);
  assert(routine.includes('IF sy-subrc <> 0.\n          gv_uncertain = abap_true.'));
  assert(routine.slice(guard, update).includes('EXIT.'));
  assert(!/sy-subrc\s*=\s*0[\s\S]*?gv_saved\s*=\s*abap_true/i.test(routine));
  assert(cls.includes("iv_new_status = 'CL'"));
  assert(cls.includes('IF ls_output-parameters-success = abap_true.'));
});
check('update_scope_status_CH_only_and_failed_save_not_successful', () => {
  const update = routine.match(/UPDATE zprt_stock[\s\S]*?AND stock_status_er = space\./)[0];
  for (const part of ['status = gc_status_closed', 'chuser = sy-uname', 'chdate = sy-datum', 'chtime = sy-uzeit',
    'WHERE stock_id = p_stokid', 'AND status = gc_status_closed', 'AND closed = space']) assert(update.includes(part), part);
  assert(!/\b(?:cruser|crdate|crtime|priority|erdat_clo|ernam_clo|ertim_clo)\s*=/i.test(update));
  assert(!/SET closed\s*=|\bclosed\s*=\s*abap_true/i.test(update));
  assert(routine.includes('IF sy-subrc <> 0 OR sy-dbcnt <> 1.\n          ROLLBACK WORK.'));
  assert(routine.includes('COMMIT WORK.\n        gv_saved = abap_true.'));
  assert(!/DELETE FROM|PERFORM (?:send_priority|save_release|prepare_regmail|get_priority|confirm_release)\b/.test(routine));
});
check('failure_lock_refresh_and_texts', () => {
  for (const part of ['IF lv_class_started = abap_true.', 'PERFORM mark_uncertain_state.', 'PERFORM sync_lock.', 'PERFORM unlock_stock.', 'PERFORM refresh_grid.', 'gv_busy = abap_false.']) assert(routine.includes(part));
  const texts = read(path.join(dir, 'ZPR_CLOSE_STOCK.texts.tsv'));
  for (const match of routine.matchAll(/\btext-(2\d{2})\b/gi)) assert(texts.includes(match[1] + '\tHU\t'));
  assert(texts.includes('Nincs jogosultság'));
});
function git(args, options = {}, expected = 0) {
  const result = cp.spawnSync('git', ['-c', 'safe.directory=' + root, ...args], {encoding: 'utf8', ...options});
  assert.equal(result.status, expected, result.stderr || String(result.error));
  return result.stdout;
}
const diff = git(['diff', '--no-index', '--', path.join(base, name), path.join(dir, name)], {}, 1);
const patch = diff.split('\n').map(line => {
  if (line.startsWith('diff --git ')) return 'diff --git a/' + name + ' b/' + name;
  if (line.startsWith('--- ')) return '--- a/' + name;
  if (line.startsWith('+++ ')) return '+++ b/' + name;
  return line;
}).join('\n');
fs.writeFileSync(path.join(dir, '2026-10-21_release-stock-new-riport_WIP.diff'), patch);
check('report_only_patch_round_trip_byte_exact', () => {
  const staging = fs.mkdtempSync(path.join(os.tmpdir(), 'release-stock-new-report-'));
  try {
    fs.copyFileSync(path.join(base, name), path.join(staging, name));
    git(['apply', '--check', '--whitespace=nowarn', '-'], {cwd: staging, input: patch});
    git(['apply', '--whitespace=nowarn', '-'], {cwd: staging, input: patch});
    assert(fs.readFileSync(path.join(staging, name)).equals(fs.readFileSync(path.join(dir, name))));
    git(['apply', '--reverse', '--whitespace=nowarn', '-'], {cwd: staging, input: patch});
    assert(fs.readFileSync(path.join(staging, name)).equals(fs.readFileSync(path.join(base, name))));
  } finally {
    fs.unlinkSync(path.join(staging, name));
    fs.rmdirSync(staging);
  }
});
const result = {status: 'WIP', date: '2026-10-21', baseline: base, checks, passed: checks.length,
  kind: 'Local source-contract and patch checks; not SAP execution',
  classModified: false, successDetection: 'Observed QM-to-CL database transition under the existing dialog lock',
  sapConnected: false, sapCompilation: false, parserExecuted: false, atc: false, abapUnitExecuted: false,
  originalSha256: sha(path.join(base, name)), sha256: sha(path.join(dir, name)),
  classSha256: sha(path.join(base, 'ZCL_PR_STOCK.class.abap'))};
fs.writeFileSync(path.join(dir, 'source-check.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result));
