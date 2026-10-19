const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const assert = require('assert/strict');
const root = process.cwd();
const temp = path.join(root, '.tmp/doc-status-qa-20261015');
const folder = '[03] projects/tomeges-nyomtatas-endre/04_ASSETS/abap/';
const program = folder + 'ZPR_DOC_STATUS.abap';
const texts = folder + '2026-10-15_doc-status-qa-textelemek_WIP.tsv';
const patches = [folder + '2026-10-15_doc-status-qa-uzenetek_WIP.diff',
  folder + '2026-10-15_doc-status-qa-tablamuveletek_WIP.diff'];
function git(args, cwd = root, env = process.env, allowed = [0]) {
  const r = cp.spawnSync('git', ['-c', 'safe.directory=' + root.replaceAll('\\', '/'),
    '-c', 'core.autocrlf=false', ...args], {cwd, env, encoding: 'utf8'});
  if (!allowed.includes(r.status)) throw new Error(r.stderr || r.stdout || String(r.error));
  return r.stdout;
}
function diff(left, right) {
  const raw = git(['diff', '--no-index', '--', left, right], root, process.env, [0, 1]);
  const lines = raw.split('\n');
  const hunk = lines.findIndex(l => l.startsWith('@@'));
  assert(hunk >= 0, 'Expected diff hunks');
  return `diff --git "a/${program}" "b/${program}"\n--- "a/${program}"\n+++ "b/${program}"\n`
    + lines.slice(hunk).join('\n');
}
const tsv = fs.readFileSync(texts, 'utf8').replace(/\r\n/g, '\n');
assert(tsv.endsWith('\n'));
const tsvLines = tsv.trimEnd().split('\n');
const newTextDiff = `diff --git "a/${texts}" "b/${texts}"\nnew file mode 100644\n--- /dev/null\n+++ "b/${texts}"\n@@ -0,0 +1,${tsvLines.length} @@\n`
  + tsvLines.map(l => '+' + l).join('\n') + '\n';
fs.writeFileSync(patches[0], diff(path.join(temp, 'before.abap'), path.join(temp, 'messages.abap')) + newTextDiff);
fs.writeFileSync(patches[1], diff(path.join(temp, 'messages.abap'), path.join(root, program)));
const mirror = path.join(temp, 'verify');
fs.mkdirSync(path.join(mirror, folder), {recursive: true});
assert(!fs.existsSync(path.join(mirror, texts)), 'Use a fresh validation directory');
fs.copyFileSync(path.join(temp, 'before.abap'), path.join(mirror, program));
const env = {...process.env, GIT_CEILING_DIRECTORIES: temp};
for (const patch of patches) {
  git(['apply', '--check', path.join(root, patch)], mirror, env);
  git(['apply', path.join(root, patch)], mirror, env);
}
assert.deepEqual(fs.readFileSync(path.join(mirror, program)), fs.readFileSync(program));
assert.deepEqual(fs.readFileSync(path.join(mirror, texts)), fs.readFileSync(texts));
for (const patch of [...patches].reverse()) {
  git(['apply', '--reverse', '--check', path.join(root, patch)], mirror, env);
  git(['apply', '--reverse', path.join(root, patch)], mirror, env);
}
assert.deepEqual(fs.readFileSync(path.join(mirror, program)), fs.readFileSync(path.join(temp, 'before.abap')));
assert(!fs.existsSync(path.join(mirror, texts)));
const source = fs.readFileSync(program, 'utf8');
const active = source.split(/\r?\n/).filter(l => !/^\s*\*/.test(l)).join('\n');
assert(!/\bMESSAGE\s+'/i.test(active), 'Literal in active MESSAGE');
const expected = new Map(tsvLines.slice(1).map(l => l.split('\t')));
assert.equal(expected.size, 4);
for (const id of ['101', '102', '103', '104']) {
  assert(expected.get(id), 'Missing text: ' + id);
  assert(new RegExp('MESSAGE text-' + id + '\\b', 'i').test(active));
}
const tableBefore = fs.readFileSync(path.join(temp, 'messages.abap'), 'utf8');
const selection = text => /SELECT \* FROM zpr_terti INTO TABLE lt_terti[\s\S]*?CHECK lt_terti IS NOT INITIAL\./i.exec(text)[0];
assert.equal(selection(source), selection(tableBefore), 'Changed TERTI selection');
assert(/DELETE zpr_terti FROM TABLE lt_terti\.[\r\n ]+IF sy-subrc <> 0\./i.test(active));
assert(/INSERT gv_log_handle INTO TABLE lt_handles\./i.test(active));
const evidence = {patches, forwardApplication: 'byte-identical to final source and TSV',
  reverseApplication: 'byte-identical to original baseline; TSV removed',
  messageTextSymbols: [...expected.keys()], activeMessageLiterals: 0,
  tertiSelectionUnchanged: true, tertiFullKeyDelete: true, handleInsert: true,
  limitations: 'Local checks only; no SAP QA/ATC, text pool maintenance or DDIC index verification.'};
fs.writeFileSync('[03] projects/tomeges-nyomtatas-endre/02_NOTES/2026-10-15_doc-status-qa-ellenorzes_WIP.json', JSON.stringify(evidence, null, 2) + '\n');
console.log(JSON.stringify(evidence, null, 2));
