const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');
const {DatabaseSync} = require('node:sqlite');
const project = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(project, '04_ASSETS/abap/ZPR_DOC_STATUS.abap'), 'utf8');
const read = /SELECT dcqm~guid dcqm~doc_no dcqm~package_id[\s\S]*?WHERE package~stock_id = iv_stock\./i.exec(source);
const check = /SELECT SINGLE dcqm~guid FROM zprt_dcqm AS dcqm[\s\S]*?AND package~stock_id = iv_stock\./i.exec(source);
const update = /UPDATE zprt_dcqm SET prdfile = lv_file[\s\S]*?AND package~stock_id = iv_stock \)\./i.exec(source);
assert(read && check && update, 'Missing package-based SQL operations');
function sql(text) {
  return text.replace(/\.$/, '').replace(/~/g, '.')
    .replace(/is_document-guid/g, ':guid')
    .replace(/is_document-doc_no/g, ':doc_no')
    .replace(/is_document-package_id/g, ':package_id')
    .replace(/\biv_stock\b/g, ':stock_id');
}
// Execute the actual FROM/WHERE clauses; SQLite is a single-client SQL model,
// not an ABAP runtime or a DDIC/Open SQL syntax check.
const readSql = 'SELECT dcqm.guid, dcqm.doc_no, dcqm.package_id '
  + sql(read[0].slice(read[0].indexOf('FROM '))
    .replace(/INTO CORRESPONDING FIELDS OF TABLE lt_document\s*/i, ''));
const checkSql = sql(check[0].replace(/SELECT SINGLE/i, 'SELECT').replace(/INTO lv_guid\s*/i, ''));
const updateSql = 'UPDATE zprt_dcqm SET prdfile = :file '
  + sql(update[0].slice(update[0].indexOf('WHERE ')));
const db = new DatabaseSync(':memory:');
try {
  db.exec(`CREATE TABLE zprt_package(package_id TEXT PRIMARY KEY, stock_id TEXT);
    CREATE TABLE zprt_dcqm(guid TEXT PRIMARY KEY, doc_no TEXT, package_id TEXT,
      prd_stock_id TEXT, prdfile TEXT);
    CREATE TABLE zprt_doc_log(guid TEXT PRIMARY KEY, doc_no TEXT);
    INSERT INTO zprt_package VALUES ('0000000001','S1'),('0000000002','S1'),
      ('0000000003','S2'),('0000000004','');
    INSERT INTO zprt_dcqm VALUES ('G1','D1','0000000001','','OLD'),
      ('G2','D2','0000000002','WRONG','OLD'),
      ('G3','D3','0000000003','S1','OLD'),
      ('G4','D4','MISSING','S1','OLD'),
      ('G5','D5','0000000004','S1','OLD');
    INSERT INTO zprt_doc_log SELECT guid,doc_no FROM zprt_dcqm;`);
  const list = db.prepare(readSql);
  const current = db.prepare(checkSql);
  const save = db.prepare(updateSql);
  const p = {guid: 'G1', doc_no: 'D1', package_id: '0000000001', stock_id: 'S1'};
  assert.deepEqual(list.all({stock_id: 'S1'}).map(r => r.doc_no).sort(), ['D1','D2']);
  assert.equal(list.all({stock_id: 'EMPTY'}).length, 0);
  assert.equal(current.all(p).length, 1);
  assert.equal(save.run({...p, file: 'A_02'}).changes, 1);
  assert.equal(db.prepare('SELECT package_id FROM zprt_dcqm WHERE guid=?').get('G1').package_id, p.package_id);
  assert.equal(current.all({...p, stock_id: 'S2'}).length, 0);
  assert.equal(save.run({...p, stock_id: 'S2', file: 'BAD'}).changes, 0);
  db.prepare('UPDATE zprt_package SET stock_id=? WHERE package_id=?').run('S2', p.package_id);
  assert.equal(current.all(p).length, 0);
  assert.equal(save.run({...p, file: 'BAD'}).changes, 0);
  db.prepare('UPDATE zprt_package SET stock_id=? WHERE package_id=?').run('S1', p.package_id);
  db.prepare('UPDATE zprt_dcqm SET package_id=? WHERE guid=?').run('0000000002', p.guid);
  assert.equal(current.all(p).length, 0);
  assert.equal(save.run({...p, file: 'BAD'}).changes, 0);
  assert.equal(db.prepare('SELECT prdfile FROM zprt_dcqm WHERE guid=?').get('G1').prdfile, 'A_02');
  const result = {tool: 'node:sqlite', clauses: 'FROM/WHERE clauses extracted from current ABAP source',
    checks: {multiplePackagesInStock: true, ignoresDcqmPrdStockId: true,
      excludesOtherStockMissingAndUnassignedPackages: true, emptyStock: true,
      validAssignmentUpdatesFileAndPreservesPackage: true, wrongStockBlocked: true,
      reassignedPackageBlocked: true, changedDocumentPackageBlocked: true},
    limitations: 'Single-client relational SQL model only. No ABAP parser, DDIC type check, SAP execution, ABAP Unit or lock/concurrency simulation.'};
  fs.writeFileSync(path.join(project, '02_NOTES/2026-10-15_doc-status-stock-package-sql-ellenorzes_WIP.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result, null, 2));
} finally { db.close(); }
