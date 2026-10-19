const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const assert = require('assert/strict');
const root = process.cwd();
const temp = __dirname;
const drafts = path.join(root, '[03] projects/tomeges-nyomtatas-endre/03_DRAFTS');
const current = path.join(drafts, '2026-10-16_cockpit_WIP');
const files = ['LZPR_COCKPITTOP.abap', 'LZPR_COCKPITO01.abap'];
const read = p => fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n');
function git(args, allowed = [0]) {
  const r = cp.spawnSync('git', ['-c', 'safe.directory=' + root.replaceAll('\\', '/'), '-c', 'core.autocrlf=false', ...args], {cwd: temp, encoding:'utf8', env: {...process.env, GIT_CEILING_DIRECTORIES:path.dirname(temp)}});
  assert(allowed.includes(r.status), r.stderr || r.stdout || String(r.error));
  return r.stdout;
}
const before = Object.fromEntries(files.map(f => [f, read(path.join(temp, f))]));
let patch = '';
for (const file of files) {
  fs.writeFileSync(path.join(temp, 'before.txt'), before[file]);
  fs.writeFileSync(path.join(temp, 'after.txt'), read(path.join(current, file)));
  const raw = git(['diff','--no-index','--','before.txt','after.txt'], [1]);
  patch += `diff --git a/${file} b/${file}\n--- a/${file}\n+++ b/${file}\n` + raw.slice(raw.indexOf('@@'));
  fs.writeFileSync(path.join(temp, file), before[file]);
}
const out = path.join(drafts, '2026-10-17_cockpit-hidden-okcodes_WIP.diff');
fs.writeFileSync(out, patch);
git(['apply','--check',out]);
git(['apply',out]);
for (const f of files) assert.equal(read(path.join(temp,f)), read(path.join(current,f)));
git(['apply','--check','--reverse',out]);
git(['apply','--reverse',out]);
for (const f of files) assert.equal(read(path.join(temp,f)), before[f]);
console.log('QA diff: forward and reverse exact normalized match.');
