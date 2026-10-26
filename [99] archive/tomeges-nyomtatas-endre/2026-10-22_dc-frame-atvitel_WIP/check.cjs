const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');
const crypto = require('crypto');
const assert = require('assert/strict');
const project = path.resolve(__dirname, '../..');
const basePath = path.join(project, '05_FINAL/abap-2026-10-17/ZPR_DC_FRAME.abap');
const legacyPath = path.join(project, '01_SOURCES/QU5/ZEBF_PR_DC_FRAME.abap');
const logReferencePath = path.join(project, '05_FINAL/abap-2026-10-17/ZPR_CREATE_STOCK.abap');
const target = path.join(__dirname, 'ZPR_DC_FRAME.abap');
const sha = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const read = p => fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n');
const original = read(basePath);
const source = read(target);
const active = source.split('\n').filter(l => !/^\s*\*/.test(l)).map(l => l.replace(/".*$/, '')).join('\n');
const form = (s, n) => {
  const m = s.match(new RegExp('^FORM ' + n + '\\b[\\s\\S]*?^ENDFORM\\.', 'mi'));
  assert(m, 'Missing FORM ' + n);
  return m[0];
};
const checks = [];
function check(name, fn) { fn(); checks.push({name, result: 'PASS'}); }

check('original_QU5_and_DHC_bytes_unchanged', () => {
  assert.equal(sha(legacyPath), '6cd368d6a28b89fb6a5c3f3378ce559526e9aba3904e8fea27826dc6dac9b84d');
  assert.equal(sha(basePath), 'eac7f8ca2f5ea37ff9145a62c2e4784d03c5b3f059e2878c108b911f6c82a868');
  assert.equal(sha(logReferencePath), '99c57aa7a2703d2b094adef600359b72ea45bb3064f630c36cfbff8ac2a06e5e');
});
check('no_legacy_or_search_help_dependency_and_expected_log_class', () => {
  assert(/^REPORT zpr_dc_frame MESSAGE-ID zpr\./mi.test(source));
  assert(!/\b(zebf\w*|zprh_stock|filename|zprt_mssfile)\b/i.test(active));
  assert(/TYPE REF TO zcl_pr_log/i.test(active));
  assert(!/^\s*INCLUDE\b/mi.test(active));
  const forms = new Set([...active.matchAll(/^FORM\s+(\w+)/gmi)].map(m => m[1].toLowerCase()));
  for (const m of active.matchAll(/\bPERFORM\s+(\w+)/gi)) assert(forms.has(m[1].toLowerCase()), m[1]);
  assert.equal(forms.size, [...active.matchAll(/^ENDFORM\./gmi)].length);
  for (const n of ['ENQUEUE_EZPRT_STOCK', 'DEQUEUE_EZPRT_STOCK', 'F4IF_INT_TABLE_VALUE_REQUEST']) {
    assert(active.includes("'" + n + "'"), n);
  }
});
check('four_operations_validation_lock_and_SUBMIT_preserved_from_DHC', () => {
  for (const n of ['check_stockid', 'run_report', 'lock_stock', 'unlock_stock']) {
    assert.equal(form(source, n), form(original, n), n);
  }
  const events = s => s.match(/START-OF-SELECTION\.[\s\S]*?ENDCASE\./)[0];
  assert.equal(events(source), events(original));
  const child = read(path.join(project, '05_FINAL/abap-2026-10-17/ZPR_DCQM_EXCLUDE.abap'));
  assert(/p_stokid TYPE zprd_stock_id/i.test(child));
  assert(/p_modif\s+TYPE flag NO-DISPLAY/i.test(child));
});
check('business_changes_identical_except_BAL_message_handling', () => {
  let transformed = form(source, 'change_dc_status')
    .replace('        lv_log_error TYPE abap_bool,\n', '')
    .replace(/INSERT ls_msg INTO TABLE lt_msg\./g, 'APPEND ls_msg TO lt_msg.')
    .replace('  PERFORM log_write USING lt_msg CHANGING lv_log_error.\n  IF lv_log_error EQ abap_true.\n    RETURN.\n  ENDIF.',
      '  PERFORM log_write USING lt_msg.');
  assert.equal(transformed, form(original, 'change_dc_status'));
  assert.equal(form(source, 'get_count').replace(/INSERT ls_msg INTO TABLE ct_msg\./g, 'APPEND ls_msg TO ct_msg.'),
    form(original, 'get_count'));
  const updates = [...active.matchAll(/UPDATE zprt_stock SET[\s\S]*?\./g)];
  assert.equal(updates.length, 1);
  const update = updates[0][0];
  const setFields = [...update.matchAll(/\b(\w+)\s*=\s*@/g)].map(m => m[1]);
  assert.deepEqual(setFields, ['dccompl', 'chuser', 'chdate', 'chtime', 'stock_id']);
});
check('DDIC_field_references_match_local_DHC_snapshots', () => {
  function ddlFields(name) {
    const s = read(path.join(project, '01_SOURCES/DHC/2026-10-15_doc-rip', name + '.table'));
    return new Set([...s.matchAll(/^\s*(?:key\s+)?(\w+)\s*:/gmi)].map(m => m[1].toLowerCase()));
  }
  const stock = ddlFields('ZPRT_STOCK');
  const oldStock = read(path.join(project, '01_SOURCES/DHC/ZPRT_STOCK.table'));
  for (const m of oldStock.matchAll(/^(\w+)\t/gm)) stock.add(m[1].toLowerCase());
  for (const f of ['stock_id', 'status', 'closed', 'dccompl', 'qmcompl', 'chuser', 'chdate', 'chtime']) assert(stock.has(f), f);
  for (const m of active.matchAll(/\b(?:gs_stock|ls_stock|zprt_stock)-(\w+)/gi)) assert(stock.has(m[1].toLowerCase()), m[0]);
  const dcqm = ddlFields('ZPRT_DCQM');
  for (const f of ['prd_stock_id', 'block_dc']) assert(dcqm.has(f), f);
  assert(/key stock_id\s*:/i.test(read(path.join(project, '01_SOURCES/DHC/2026-10-15_doc-rip/ZPRT_STOCK.table'))));
});
check('T100_and_textpool_complete_without_literal_MESSAGES', () => {
  const messages = new Map(read(path.join(__dirname, 'ZPR.messages.tsv')).trim().split('\n').slice(1)
    .map(l => { const c = l.split('\t'); return [c[1], c[3]]; }));
  const constants = new Map([...active.matchAll(/(\w+)\s+TYPE symsgno VALUE '(\d{3})'/gi)].map(m => [m[1].toLowerCase(), m[2]]));
  for (const m of active.matchAll(/gc_msgno-(\w+)/gi)) assert(constants.has(m[1].toLowerCase()), m[0]);
  for (const [name, number] of constants) assert(messages.has(number), name + '/' + number);
  assert.equal(constants.size, messages.size);
  for (const text of messages.values()) assert(text.length <= 73, text);
  const textRows = read(path.join(__dirname, 'ZPR_DC_FRAME.texts.tsv')).trim().split('\n').slice(1).map(l => l.split('\t'));
  for (const m of active.matchAll(/\btext-(\d{3})/gi)) assert(textRows.some(r => r[0] === 'I' && r[1] === m[1]), m[0]);
  for (const param of ['P_STOKID', 'P_MOD', 'P_DISP', 'P_ENG', 'P_ENGV']) assert(textRows.some(r => r[0] === 'S' && r[1] === param), param);
  assert(!/MESSAGE\s+(?:[sewiax]\d{3}\s+WITH\s+)?'/i.test(active));
});
check('FINAL_log_class_pattern_commits_and_error_propagation', () => {
  const log = form(source, 'log_write');
  const reference = form(read(logReferencePath), 'log_write');
  const adapted = reference
    .replace('FORM log_write.', 'FORM log_write USING ut_msg TYPE bal_t_msg\n               CHANGING cv_error TYPE abap_bool.')
    .replace('lv_text TYPE string.', 'lv_text TYPE string,\n        lv_dummy TYPE string.')
    .replace(/\blo_log\b/g, 'lr_log').replace(/\bgv_log_error\b/g, 'cv_error')
    .replace(/\bgt_messages\b/g, 'ut_msg').replace(/\bgv_dummy\b/g, 'lv_dummy')
    .replace(/\bgc_log_subobject\b/g, 'gc_log_subobj')
    .replace("'A napló nem menthető/megjeleníthető:'", 'text-102');
  assert.equal(log, adapted);
  assert(log.includes('cv_error = abap_false.'));
  assert(log.includes('cv_error = abap_true.'));
  assert(log.indexOf('lr_log->close( ).') < log.indexOf('COMMIT WORK.'));
  assert(log.indexOf('COMMIT WORK.') < log.indexOf('lr_log->display( ).'));
  assert(log.includes('CATCH cx_root INTO lr_error.\n      ROLLBACK WORK.'));
  assert(!/CALL FUNCTION 'BAL_|iv_extnumber|extnumber\s*=/i.test(log));
  assert(!/APPEND\b/.test(active));
  const change = form(source, 'change_dc_status');
  assert(change.indexOf('PERFORM unlock_stock.') < change.indexOf('PERFORM log_write'));
  assert(change.includes('IF lv_log_error EQ abap_true.\n    RETURN.\n  ENDIF.'));
});
check('F4_limit_and_cancellation_do_not_clear_selected_stock', () => {
  const f4 = form(source, 'stock_f4');
  assert(f4.includes('UP TO 5000 ROWS'));
  assert(f4.includes('ORDER BY stock_id DESCENDING.'));
  assert(f4.includes('window_title    = text-101'));
  assert(f4.includes('IF sy-subrc = 0.\n    READ TABLE lt_returns'));
  assert(!/CLEAR p_stokid/i.test(f4));
});

for (const [name, input] of [['DHC-valtozasok_WIP.diff', basePath], ['QU5-DHC-atultetes_WIP.diff', legacyPath]]) {
  check(name + '_forward_and_reverse_byte_exact', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'dc-frame-'));
    const tempFile = path.join(tmp, 'ZPR_DC_FRAME.abap');
    try {
      fs.copyFileSync(input, tempFile);
      for (const reverse of [false, true]) {
        const args = ['-c', 'core.autocrlf=false', 'apply', '--whitespace=nowarn'];
        if (reverse) args.push('--reverse');
        args.push(path.join(__dirname, name));
        const p = cp.spawnSync('git', args, {cwd: tmp, encoding: 'utf8'});
        assert.equal(p.status, 0, p.stderr || String(p.error));
        assert(fs.readFileSync(tempFile).equals(fs.readFileSync(reverse ? input : target)), name + ' bytes');
      }
    } finally {
      if (fs.existsSync(tempFile)) fs.unlinkSync(tempFile);
      fs.rmdirSync(tmp);
    }
  });
}

const parser = {executed: false, reason: 'No local @abaplint/core supplied; no network package installation performed.'};
if (process.argv[2]) {
  const core = require(process.argv[2]);
  const config = core.Config.getDefault(core.Version.v754).get();
  config.rules = {parser_error: true};
  const registry = new core.Registry(new core.Config(JSON.stringify(config)));
  registry.addFile(new core.MemoryFile('zpr_dc_frame.prog.abap', source));
  registry.parse();
  parser.executed = true;
  delete parser.reason;
  parser.version = core.Registry.abaplintVersion();
  parser.abapVersion = '7.54';
  parser.issues = registry.findIssues().map(i => ({row: i.getStart().getRow(), message: i.getMessage()}));
  assert.equal(parser.issues.length, 0, JSON.stringify(parser.issues));
}
fs.writeFileSync(path.join(__dirname, 'validation.json'), JSON.stringify({
  date: '2026-10-22', checks, parser,
  sapConnectionUsed: false, sapSyntaxCheck: false, atcSci: false, guiRuntimeTest: false,
  note: 'Local source/schema and byte-exact diff checks only. Active target state is unverified.'
}, null, 2) + '\n');
const inputs = [basePath, legacyPath, logReferencePath,
  path.join(project, '01_SOURCES/DHC/2026-10-15_doc-rip/ZPRT_DCQM.table'),
  path.join(project, '01_SOURCES/DHC/2026-10-15_doc-rip/ZPRT_STOCK.table'),
  path.join(project, '01_SOURCES/DHC/ZPRT_STOCK.table'),
  path.join(project, '05_FINAL/abap-2026-10-17/ZPR_DCQM_EXCLUDE.abap')];
const hashEntry = (file, relativeTo) => ({path: path.relative(relativeTo, file).replace(/\\/g, '/'), sha256: sha(file)});
const files = fs.readdirSync(__dirname).filter(n => n !== 'manifest.json' && fs.statSync(path.join(__dirname, n)).isFile());
fs.writeFileSync(path.join(__dirname, 'manifest.json'), JSON.stringify({
  date: '2026-10-22', status: 'WIP', target: 'ZPR_DC_FRAME',
  inputs: inputs.map(f => hashEntry(f, project)),
  files: files.map(n => hashEntry(path.join(__dirname, n), __dirname))
}, null, 2) + '\n');
console.log(JSON.stringify({checksPassed: checks.length, parser, filesHashed: files.length}, null, 2));
