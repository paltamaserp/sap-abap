const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const assert = require('assert/strict');
const root = process.cwd();
const temp = path.join(root, '.tmp/doc-status-stock-package-20261015');
const mirror = path.join(temp, 'verify-sequence');
const folder = '[03] projects/tomeges-nyomtatas-endre/04_ASSETS/abap/';
const program = folder + 'ZPR_DOC_STATUS.abap';
const patches = [folder + '2026-10-15_doc-status-package-id-spool_WIP.diff',
  folder + '2026-10-15_doc-status-stock-package-kapcsolat_WIP.diff'];
assert(!fs.existsSync(mirror));
fs.mkdirSync(path.dirname(path.join(mirror, program)), {recursive: true});
const baseline = path.join(root, '.tmp/doc-status-package-20261015/before.abap');
fs.copyFileSync(baseline, path.join(mirror, program));
function apply(patch, reverse = false) {
  const r = cp.spawnSync('git', ['-c', 'safe.directory=' + root.replaceAll('\\', '/'),
    '-c', 'core.autocrlf=false', 'apply', ...(reverse ? ['--reverse'] : []),
    '--whitespace=error', path.join(root, patch)], {
    cwd: mirror, encoding: 'utf8', env: {...process.env, GIT_CEILING_DIRECTORIES: temp},
  });
  assert.equal(r.status, 0, r.stderr || r.stdout);
}
for (const patch of patches) apply(patch);
assert.deepEqual(fs.readFileSync(path.join(mirror, program)), fs.readFileSync(program));
for (const patch of [...patches].reverse()) apply(patch, true);
assert.deepEqual(fs.readFileSync(path.join(mirror, program)), fs.readFileSync(baseline));
const report = '[03] projects/tomeges-nyomtatas-endre/02_NOTES/2026-10-15_doc-status-stock-package-diff-ellenorzes_WIP.json';
const result = JSON.parse(fs.readFileSync(report, 'utf8'));
result.combinedPatchSequence = {patches, forwardAndReverse: 'byte-identical to current source and pre-spool baseline'};
fs.writeFileSync(report, JSON.stringify(result, null, 2) + '\n');
console.log('Both patches apply in order and reverse to exact baseline.');
