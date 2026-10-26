import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { execFile } from 'node:child_process';
import { DatabaseSync } from 'node:sqlite';

const folder = path.dirname(fileURLToPath(import.meta.url));
const project = path.resolve(folder, '../..');
const baselinePath = path.join(project, '05_FINAL/abap-2026-10-17/ZPR_DOC_STATUS.abap');
const baseline = await fs.readFile(baselinePath);
const candidate = await fs.readFile(path.join(folder, 'ZPR_DOC_STATUS.abap'));
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(hash(baseline), 'b3b55a72a772a4fd3a65567f29e5c82006ed37df86156bbcbd5d2a486afd5b06');
const source = candidate.toString('utf8');
const original = baseline.toString('utf8');
const form = (text, name) => new RegExp('^FORM ' + name + '\\b[\\s\\S]*?^ENDFORM\\.', 'mi').exec(text)?.[0];
const checks = [];
const check = (name, run) => { run(); checks.push(name); };
const helper = form(source, 'update_stock_delivery');
check('Csak a meglévő feldolgozó rutin és az új AD-rutin változik', () => {
  for (const match of original.matchAll(/^FORM (\w+)/gmi)) {
    if (['process_locked_stock'].includes(match[1].toLowerCase())) continue;
    assert.equal(form(source, match[1]), form(original, match[1]), match[1]);
  }
  // Outside PROCESS_LOCKED_STOCK and the new FORM, only OBLIGATORY is removed.
  const stripped = source.replace(form(source, 'process_locked_stock'), '')
    .replace(helper + '\r\n\r\n', '');
  assert.equal(stripped, original.replace(form(original, 'process_locked_stock'), '')
    .replace('                  OBLIGATORY\r\n', ''));
});
check('Stockszűrés opcionális; kényszerített ismétléshez továbbra is kötelező', () => {
  assert(!/SELECT-OPTIONS so_stock[\s\S]*?OBLIGATORY[\s\S]*?MATCHCODE/.test(source));
  assert(source.includes("WHERE stock_id IN so_stock AND status = 'CL'."));
  assert(source.includes('IF p_stat = abap_true AND so_stock[] IS INITIAL.'));
});
check('Stockzár és zár alatti CL/CLOSED ellenőrzés megmarad', () => {
  assert.equal(form(source, 'process_stock'), form(original, 'process_stock'));
  assert(/IF sy-subrc <> 0 OR ls_stock-closed <> abap_true\s+OR ls_stock-status <> 'CL'\./.test(source));
});
check('AD-ellenőrzés mindkét kilépési útban, a dokumentumciklus után', () => {
  const processing = form(source, 'process_locked_stock');
  assert.equal([...processing.matchAll(/PERFORM update_stock_delivery USING iv_stock\./g)].length, 2);
  assert(/IF lt_requested IS INITIAL\.[\s\S]*?PERFORM update_stock_delivery USING iv_stock\.\s+RETURN\./.test(processing));
  assert(/PERFORM process_document USING iv_stock ls_document ls_response\.\s+ENDLOOP\.\s+PERFORM update_stock_delivery/.test(processing));
});
check('Üres és hiányos halmazból nincs AD; sikertelen UPDATE rollback', () => {
  assert(/IF lv_total = 0\.[\s\S]*?RETURN\.\s+ENDIF\./.test(helper));
  assert(/IF lv_missing > 0\.[\s\S]*?RETURN\.\s+ENDIF\./.test(helper));
  assert(/IF sy-subrc <> 0 OR sy-dbcnt <> 1\.\s+ROLLBACK WORK\./.test(helper));
  assert(/COMMIT WORK AND WAIT\.\s+IF sy-subrc <> 0\.[\s\S]*?RETURN\./.test(helper));
});
check('Minden új naplószöveg fordítható és TSV-ben szerepel', () => {
  assert(!/PERFORM add_log[^\r\n]*'[^'\r\n]{2,}'/.test(helper));
});
const symbols = await fs.readFile(path.join(folder, '2026-10-22_doc-status-textelemek_WIP.tsv'), 'utf8');
for (const id of new Set([...helper.matchAll(/text-(\d+)/gi)].map(m => m[1]))) {
  assert(new RegExp('^' + id + '\t.+', 'm').test(symbols), id);
}

// Run the actual new ABAP SQL predicates against relational fixtures.
// SQLite is not an ABAP parser/type checker. Inject the client restriction
// that Open SQL supplies implicitly in SAP, and normalize ABAP host values.
const toSql = text => text.trim().replace(/\.$/, '')
  .replace(/\bINTO lv_(total|missing)\b/gi, '')
  .replace(/(\w+)~(\w+)/g, '$1.$2')
  .replace(/\b(FROM|JOIN) (zprt_dcqm|zprt_package|zprt_doc_slog) AS (\w+)/gi,
    "$1 (SELECT * FROM $2 WHERE mandt = '100') AS $3")
  .replace(/\biv_stock\b/g, ':stock').replace(/\babap_true\b/g, "'X'")
  .replace(/sy-uname/g, "'BATCH'").replace(/sy-datum/g, "'20261022'")
  .replace(/sy-uzeit/g, "'120000'");
const selects = [...helper.matchAll(/SELECT COUNT\([\s\S]*?\.(?=\r?\n)/g)].map(m => toSql(m[0]));
assert.equal(selects.length, 2);
const update = toSql(/UPDATE zprt_stock[\s\S]*?\.(?=\r?\n)/.exec(helper)[0])
  .replace(/('[^']*')\s+(?=(?:chuser|chdate|chtime)\s*=)/g, '$1, ')
  .replace(/WHERE stock_id/, "WHERE mandt = '100' AND stock_id");
const db = new DatabaseSync(':memory:');
db.exec(`CREATE TABLE zprt_stock (mandt TEXT, stock_id TEXT, status TEXT, closed TEXT,
  chuser TEXT, chdate TEXT, chtime TEXT, cruser TEXT, priority TEXT, PRIMARY KEY(mandt,stock_id));
CREATE TABLE zprt_package (mandt TEXT, package_id TEXT, stock_id TEXT, PRIMARY KEY(mandt,package_id));
CREATE TABLE zprt_dcqm (mandt TEXT, doc_no TEXT, package_id TEXT, block_dc TEXT, block_qm TEXT,
  PRIMARY KEY(mandt,doc_no));
CREATE TABLE zprt_doc_slog (mandt TEXT, exbilldocno TEXT, timestamp TEXT, status TEXT,
  PRIMARY KEY(mandt,exbilldocno,timestamp));
CREATE TABLE zprt_doc_error (mandt TEXT, exbilldocno TEXT, error_code TEXT);`);
const fixture = (docRows, events = [], opts = {}) => {
  for (const table of ['stock', 'package', 'dcqm', 'doc_slog', 'doc_error']) db.exec('DELETE FROM zprt_' + table);
  db.prepare('INSERT INTO zprt_stock VALUES (?,?,?,?,?,?,?,?,?)')
    .run('100', 'S1', opts.status || 'CL', opts.closed ?? 'X', 'OLD', '20000101', '000000', 'CREATOR', '03');
  for (const row of [['100','P1','S1'],['100','P2','S1'],['100','PX','OTHER'],['200','P1','S1']]) {
    db.prepare('INSERT INTO zprt_package VALUES (?,?,?)').run(...row);
  }
  for (const [doc, pkg = 'P1', client = '100', blocked = ''] of docRows) {
    db.prepare('INSERT INTO zprt_dcqm VALUES (?,?,?,?,?)').run(client, doc, pkg, blocked, '');
  }
  let stamp = 0;
  for (const [doc, status = 'D', client = '100'] of events) {
    db.prepare('INSERT INTO zprt_doc_slog VALUES (?,?,?,?)').run(client, doc, String(++stamp), status);
  }
};
const counts = () => selects.map(sql => Number(Object.values(db.prepare(sql).get({stock:'S1'}))[0]));
const updateRows = () => Number(db.prepare(update).run({stock:'S1'}).changes);
const expectCounts = (total, missing) => assert.deepEqual(counts(), [total, missing]);
check('Üres stock: nincs dokumentum', () => {fixture([]); expectCounts(0,0);});
check('Minden dokumentum D, több package: AD és csak CH* auditfrissítés', () => {
  fixture([['A'],['B','P2']], [['A'],['B']]); expectCounts(2,0); assert.equal(updateRows(),1);
  assert.deepEqual({...db.prepare('SELECT status,closed,chuser,chdate,chtime,cruser,priority FROM zprt_stock').get()},
    {status:'AD',closed:'X',chuser:'BATCH',chdate:'20261022',chtime:'120000',cruser:'CREATOR',priority:'03'});
});
check('Részleges D: a másik package dokumentuma is hiányzónak számít', () => {
  fixture([['A'],['B','P2']], [['A']]); expectCounts(2,1);
});
check('Teljesen hiányzó napló is akadály', () => {fixture([['A']]); expectCounts(1,1);});
check('Egyéb státusz nem helyettesíti a D-t', () => {fixture([['A']], [['A','A']]); expectCounts(1,1);});
check('Hibakód D nélkül nem kézbesítés', () => {
  fixture([['A']]); db.exec("INSERT INTO zprt_doc_error VALUES ('100','A','ERR')"); expectCounts(1,1);
});
check('Korábbi D újabb másik eseménnyel is teljesítés', () => {
  fixture([['A']], [['A','D'],['A','E']]); expectCounts(1,0);
});
check('Több D-esemény nem duplázza a dokumentumszámot', () => {
  fixture([['A'],['B']], [['A'],['A']]); expectCounts(2,1);
});
check('Másik stock dokumentuma nem számít bele', () => {
  fixture([['A'],['X','PX']], [['A']]); expectCounts(1,0);
});
check('Másik dokumentum D-je nem fed el hiányt', () => {
  fixture([['A']], [['X']]); expectCounts(1,1);
});
check('Másik mandant D-je nem fed el hiányt', () => {
  fixture([['A']], [['A','D','200']]); expectCounts(1,1);
});
check('Másik mandant dokumentuma nem számít bele', () => {
  fixture([['A'],['B','P1','200']], [['A']]); expectCounts(1,0);
});
check('Az eredeti teljes halmaz érvényes: blokkolt dokumentumhoz is kell D', () => {
  fixture([['A','P1','100','X']]); expectCounts(1,1);
});
check('Időközben más státuszra állt stockot az UPDATE nem ír felül', () => {
  fixture([['A']], [['A']], {status:'QM'}); expectCounts(1,0); assert.equal(updateRows(),0);
});
check('CLOSED nélküli stockot az UPDATE nem ír felül', () => {
  fixture([['A']], [['A']], {closed:''}); assert.equal(updateRows(),0);
});
check('AD stockot az UPDATE nem ír újra', () => {
  fixture([['A']], [['A']], {status:'AD'}); assert.equal(updateRows(),0);
});
check('Későbbi futás: az utolsó D mentése után teljesül az AD feltétele', () => {
  fixture([['A'],['B']], [['A']]); expectCounts(2,1);
  db.exec("INSERT INTO zprt_doc_slog VALUES ('100','B','2','D')"); expectCounts(2,0);
  assert.equal(updateRows(),1);
});
check('Visszagörgetett dokumentummentés nem eredményez AD-t', () => {
  fixture([['A']]); db.exec("BEGIN; INSERT INTO zprt_doc_slog VALUES ('100','A','1','D'); ROLLBACK;");
  expectCounts(1,1);
});
db.close();

const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'doc-status-ad-'));
const patch = path.join(folder, '2026-10-22_doc-status-all-delivered_WIP.diff');
const git = os.platform() === 'win32' ? 'C:/Program Files/Git/cmd/git.exe' : 'git';
const runGit = args => new Promise((resolve, reject) => execFile(git,
  ['-c', 'core.autocrlf=false', ...args], {cwd:temporary,encoding:'utf8'},
  (error, stdout, stderr) => error ? reject(new Error(stderr || error.message)) : resolve(stdout)));
await fs.writeFile(path.join(temporary, 'ZPR_DOC_STATUS.abap'), baseline);
try {
  await runGit(['apply','--check',patch]);
  await runGit(['apply',patch]);
  assert.deepEqual(await fs.readFile(path.join(temporary, 'ZPR_DOC_STATUS.abap')), candidate);
  await runGit(['apply','--reverse','--check',patch]);
  await runGit(['apply','--reverse',patch]);
  assert.deepEqual(await fs.readFile(path.join(temporary, 'ZPR_DOC_STATUS.abap')), baseline);
  checks.push('Diff bájtpontos előre- és visszaalkalmazása');
} finally {
  await fs.unlink(path.join(temporary, 'ZPR_DOC_STATUS.abap'));
  await fs.rmdir(temporary);
}
assert.equal(hash(await fs.readFile(baselinePath)), hash(baseline));
const result = {status:'passed',checkCount:checks.length,checks,
  baselineSHA256:hash(baseline),candidateSHA256:hash(candidate),
  sqlChecks:'Extracted candidate SQL normalized for SQLite, with explicit client emulation.',
  limitations:'No ABAP parser, SAP compilation/type checking, ATC, ABAP Unit, SAP locks/update tasks or Inspire runtime tested. No SAP connection attempted.'};
await fs.writeFile(path.join(folder, 'validation.json'), JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));
