const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');
const core = process.argv[2] ? require(process.argv[2]) : null;
const project = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(project, '04_ASSETS/abap/ZPR_DOC_STATUS.abap'), 'utf8');
const original = fs.readFileSync(path.join(project, '01_SOURCES/QU5/ZEBF_PR_DOC_STATUS.abap'), 'utf8');
const active = source.split(/\r?\n/).filter(l => !/^\s*\*/.test(l))
  .map(l => l.replace(/".*$/, '')).join('\n');
let issues = null;
if (core) {
  const config = core.Config.getDefault(core.Version.v754).get();
  config.rules = {parser_error: true};
  const registry = new core.Registry(new core.Config(JSON.stringify(config)));
  registry.addFile(new core.MemoryFile('zpr_doc_status.prog.abap', source));
  registry.parse();
  issues = registry.findIssues().map(i => ({row: i.getStart().getRow(), message: i.getMessage()}));
}
const forms = new Set([...active.matchAll(/^FORM\s+(\w+)/gmi)].map(m => m[1].toLowerCase()));
for (const m of active.matchAll(/\bPERFORM\s+(\w+)/gi)) assert(forms.has(m[1].toLowerCase()), 'Missing FORM: ' + m[1]);
assert(!/^\s*INCLUDE\s+/mi.test(active), 'Unexpected source include');
assert(!/\b(zebf\w*|zxweb\w*|zpr_slog\w*|z_ebi\w*|zebi_push_msg)\b/i.test(active), 'Active legacy dependency');
const normalizeCommentBlock = text => text.split(/\r?\n/)
  .map(line => line.trimEnd()).filter(line => line.trim() !== '*').join('\n');
for (const name of ['upd_eszla', 'upd_bc_stat', 'upd_push_msg']) {
  const match = new RegExp('^FORM\\s+' + name + '\\b[\\s\\S]*?^ENDFORM\\.[^\\r\\n]*', 'mi').exec(original);
  assert(match, 'Missing legacy source: ' + name);
  const commented = match[0].split(/\r?\n/).map(l => '* ' + l).join('\n');
  assert(normalizeCommentBlock(source).includes(normalizeCommentBlock(commented)),
    'Changed/absent commented branch: ' + name);
  assert(!forms.has(name), 'Legacy branch active: ' + name);
}
const schema = path.join(project, '01_SOURCES/DHC/2026-10-15_doc-status');
const previous = path.join(project, '01_SOURCES/DHC/2026-10-15_doc-rip');
function fields(root, file) {
  const ddl = fs.readFileSync(path.join(root, file), 'utf8');
  return new Set([...ddl.matchAll(/^\s*(?:key\s+)?(\w+)\s*:/gmi)].map(m => m[1].toLowerCase()));
}
const tableFields = new Map();
for (const name of ['ZPRT_DOC_SLOG.table', 'ZPRT_DOC_ERROR.table', 'ZPRT_ARCH_LINK.table', 'ZPR_TERTI.table', 'ZISU_F064.table', 'ZPRS_BUSINESS_DATA.structure']) {
  tableFields.set(name.split('.')[0].toLowerCase(), fields(schema, name));
}
for (const name of ['ZPRT_DCQM.table', 'ZPRT_DOC_LOG.table', 'ZPRT_STOCK.table', 'ZPRS_CONTROL_DATA.structure']) {
  tableFields.set(name.split('.')[0].toLowerCase(), fields(previous, name));
}
for (const f of tableFields.get('zprs_control_data')) tableFields.get('zprt_doc_log').add(f);
for (const f of tableFields.get('zprs_business_data')) tableFields.get('zprt_doc_log').add(f);
for (const m of active.matchAll(/\b(zprt_doc_slog|zprt_doc_error|zprt_arch_link|zpr_terti|zisu_f064|zprt_dcqm|zprt_doc_log|zprt_stock|zprs_control_data|zprs_business_data)-(\w+)/gi)) {
  assert(tableFields.get(m[1].toLowerCase()).has(m[2].toLowerCase()), 'Unknown snapshot field: ' + m[0]);
}
// PACKAGE fields are confirmed by the user mapping and local CREATE_STOCK;
// there is no active PACKAGE DDIC export in this workspace.
const aliases = new Map([
  ['dcqm', tableFields.get('zprt_dcqm')],
  ['doclog', tableFields.get('zprt_doc_log')],
  ['package', new Set(['package_id', 'stock_id'])],
]);
for (const m of active.matchAll(/\b(dcqm|doclog|package)~(\w+)/gi)) {
  assert(aliases.get(m[1].toLowerCase()).has(m[2].toLowerCase()), 'Unknown SQL join field: ' + m[0]);
}
const req = fields(schema, 'ZPR_EON_FORMS_QUERY_DOC_DETAI3.structure');
const resp = fields(schema, 'ZPR_EON_FORMS_QUERY_DOC_DETAI2.structure');
for (const [name, known] of [['ls_input', req], ['ls_output', resp]]) {
  for (const m of active.matchAll(new RegExp('\\b' + name + '-(\\w+)', 'gi'))) {
    assert(known.has(m[1].toLowerCase()), 'Unknown proxy field: ' + m[1]);
  }
}
const split = /SPLIT lv_string AT ';' INTO([\s\S]*?)\./i.exec(original)[1];
const oldFields = [...split.matchAll(/ls_response-(\w+)/gi)].map(m => m[1].toLowerCase());
assert.equal(oldFields.length, 18);
const order = oldFields.slice(2, 16).map(s => s.replace('tstmp_', '').toUpperCase()).join('');
assert(source.includes("VALUE '" + order + "'"));
const tests = [...active.matchAll(/METHODS\s+(\w+)\s+FOR TESTING/gi)].length;
assert.equal(tests, 14);
assert(!/\b(?:prdspool|ev_spool|lv_spool|print_refs)\b/i.test(active), 'Legacy spool derivation remains');
assert(/dcqm~package_id/i.test(active), 'Package ID not loaded');
assert(/package_id\s+TYPE\s+zprt_dcqm-package_id/i.test(active), 'Package ID type missing');
assert(!/\bprd_stock_id\b/i.test(active), 'Direct DCQM-stock relationship remains');
assert.equal([...active.matchAll(/INNER JOIN zprt_package AS package/gi)].length, 2);
assert.equal([...active.matchAll(/ON package~package_id = dcqm~package_id/gi)].length, 2);
assert.equal([...active.matchAll(/(?:WHERE|AND) package~stock_id = iv_stock/gi)].length, 3);
assert(/dcqm~package_id = is_document-package_id/i.test(active));
const dcqmUpdates = [...active.matchAll(/UPDATE zprt_dcqm\b[\s\S]*?\./gi)].map(m => m[0]);
assert.equal(dcqmUpdates.length, 1);
assert(/SET prdfile = lv_file/i.test(dcqmUpdates[0]));
assert(/AND package_id = is_document-package_id/i.test(dcqmUpdates[0]));
assert(/AND EXISTS \( SELECT \* FROM zprt_package AS package\s+WHERE package~package_id = is_document-package_id\s+AND package~stock_id = iv_stock \)/i.test(dcqmUpdates[0]));
assert(!/\b(?:package_id|prd_stock_id)\s*=/i.test(dcqmUpdates[0].split(/\bWHERE\b/i)[0]));
const result = {
  tool: core ? '@abaplint/core' : 'local source/schema checks',
  version: core ? core.Registry.abaplintVersion() : null,
  abapVersion: core ? '7.54' : null, parserPerformed: Boolean(core),
  sourceFiles: ['ZPR_DOC_STATUS.abap'], issues,
  checks: {formResolution: true, standaloneSource: true, activeLegacyDependencies: false,
    originalBranchesPreservedAsComments: 3, snapshotFieldNames: true,
    proxyFieldNames: true, originalPayloadColumns: oldFields.length,
    timestampStatusOrder: order, unitTestSources: tests,
    packageIdLoadedAndPreserved: true, packageAssignmentChecked: true,
    stockMembershipThroughPackage: true, updateChecksPackageMembership: true,
    packageFieldEvidence: 'user mapping and local CREATE_STOCK source; no active PACKAGE DDIC snapshot',
    legacySpoolDerivationRemoved: true, printFileUpdatePreserved: true},
  limitations: (core ? 'Parser and local source/schema-name checks only.' : 'Local source/schema-name checks only; ABAP parser unavailable and not run.')
    + ' No SAP type check, ATC, ABAP Unit execution, business DB operations, ArchiveLink or Inspire calls.',
};
fs.writeFileSync(path.join(project, '02_NOTES/2026-10-15_doc-status-helyi-ellenorzes_WIP.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result, null, 2));
process.exitCode = issues && issues.length ? 1 : 0;
