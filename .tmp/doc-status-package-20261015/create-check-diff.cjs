const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const assert = require('assert/strict');
const root = process.cwd();
const temp = path.join(root, '.tmp/doc-status-package-20261015');
const program = '[03] projects/tomeges-nyomtatas-endre/04_ASSETS/abap/ZPR_DOC_STATUS.abap';
const patch = '[03] projects/tomeges-nyomtatas-endre/04_ASSETS/abap/2026-10-15_doc-status-package-id-spool_WIP.diff';
function git(args, cwd = root, allowed = [0]) {
  const result = cp.spawnSync('git', ['-c', 'safe.directory=' + root.replaceAll('\\', '/'),
    '-c', 'core.autocrlf=false', ...args], {
    cwd, encoding: 'utf8', env: {...process.env, GIT_CEILING_DIRECTORIES: temp},
  });
  assert(allowed.includes(result.status), result.stderr || result.stdout || String(result.error));
  return result.stdout;
}
assert(!fs.existsSync(patch), 'Preserve existing patch');
const raw = git(['diff', '--no-index', '--', path.join(temp, 'before.abap'), program], root, [1]);
const lines = raw.split('\n');
const hunk = lines.findIndex(line => line.startsWith('@@'));
assert(hunk >= 0);
fs.writeFileSync(patch, `diff --git "a/${program}" "b/${program}"\n--- "a/${program}"\n+++ "b/${program}"\n`
  + lines.slice(hunk).join('\n'));
const mirror = path.join(temp, 'verify');
assert(!fs.existsSync(mirror), 'Use fresh validation directory');
fs.mkdirSync(path.dirname(path.join(mirror, program)), {recursive: true});
fs.copyFileSync(path.join(temp, 'before.abap'), path.join(mirror, program));
git(['apply', '--check', path.join(root, patch)], mirror);
git(['apply', '--whitespace=error', path.join(root, patch)], mirror);
assert.deepEqual(fs.readFileSync(path.join(mirror, program)), fs.readFileSync(program));
git(['apply', '--reverse', '--check', path.join(root, patch)], mirror);
git(['apply', '--reverse', path.join(root, patch)], mirror);
assert.deepEqual(fs.readFileSync(path.join(mirror, program)), fs.readFileSync(path.join(temp, 'before.abap')));
const result = {patch, baseline: 'local source immediately before PACKAGE_ID change',
  forwardApplication: 'byte-identical to modified ABAP source',
  reverseApplication: 'byte-identical to original local baseline',
  whitespaceCheck: 'passed', hunks: lines.filter(line => line.startsWith('@@')).length,
  limitations: 'Local patch checks only; no SAP calls or ABAP runtime execution.'};
fs.writeFileSync('[03] projects/tomeges-nyomtatas-endre/02_NOTES/2026-10-15_doc-status-package-id-diff-ellenorzes_WIP.json',
  JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result, null, 2));
