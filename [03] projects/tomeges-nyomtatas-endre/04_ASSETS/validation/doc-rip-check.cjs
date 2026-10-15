const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');
const core = require(process.argv[2]);
const project = path.resolve(__dirname, '../..');
const dir = path.join(project, '04_ASSETS/abap');
const main = fs.readFileSync(path.join(dir, 'ZPR_DOC_RIP.abap'), 'utf8');
const names = ['ZPR_DOC_RIP.abap'];
const source = main.replace(/^INCLUDE (zpr_doc_rip\w*)\.$/gmi, (_, name) => {
  const file = name.toUpperCase() + '.abap';
  names.push(file);
  return fs.readFileSync(path.join(dir, file), 'utf8');
});
const config = core.Config.getDefault(core.Version.v754).get();
config.rules = {parser_error: true};
const registry = new core.Registry(new core.Config(JSON.stringify(config)));
registry.addFile(new core.MemoryFile('zpr_doc_rip.prog.abap', source));
registry.parse();
const issues = registry.findIssues().map(i => ({
  file: i.getFilename(), row: i.getStart().getRow(), message: i.getMessage(),
}));
const code = source.split('\n').filter(l => !/^\s*\*/.test(l))
  .map(l => l.replace(/".*$/, '')).join('\n');
const forms = new Set([...code.matchAll(/^FORM\s+(\w+)/gmi)]
  .map(m => m[1].toUpperCase()));
const calls = [...code.matchAll(/\bPERFORM\s+(\w+)/gmi)]
  .map(m => m[1].toUpperCase());
for (const call of calls) assert(forms.has(call), 'Missing FORM: ' + call);
const alv = /BEGIN OF ty_alv,([\s\S]*?)END OF ty_alv/i.exec(source)[1];
const fields = new Set([...alv.matchAll(/^\s*(\w+)\s+TYPE/gmi)]
  .map(m => m[1].toUpperCase()));
const catalog = [...source.matchAll(/PERFORM add_field USING '(\w+)'/g)]
  .map(m => m[1]);
for (const field of catalog) {
  assert(field === 'INSP_OUT_FILE' || fields.has(field), 'Unknown ALV field: ' + field);
}
assert.equal(new Set(catalog).size - 1, fields.size);
assert(!/\bzebf\w*/i.test(code), 'Remaining QU5 dependency');
assert(!/^\s*(UPDATE|MODIFY|DELETE FROM|COMMIT WORK|ROLLBACK WORK)\b/gmi.test(code),
  'Unexpected database modification');
const definitions = [...code.matchAll(/METHODS\s+(\w+)\s+FOR TESTING/gmi)];
assert.equal(definitions.length, 6);
const snapshots = path.join(project, '01_SOURCES/DHC/2026-10-15_doc-rip');
function definitionFields(file) {
  const ddl = fs.readFileSync(path.join(snapshots, file), 'utf8');
  return new Set([...ddl.matchAll(/^\s*(?:key\s+)?(\w+)\s*:/gmi)]
    .map(m => m[1].toLowerCase()));
}
for (const table of ['ZPRT_STOCK', 'ZPRT_DCQM']) {
  const actual = definitionFields(table + '.table');
  for (const m of code.matchAll(new RegExp('\\b' + table + '-(\\w+)', 'gi'))) {
    assert(actual.has(m[1].toLowerCase()), table + ': unknown field ' + m[1]);
  }
}
const doclog = definitionFields('ZPRT_DOC_LOG.table');
const control = definitionFields('ZPRS_CONTROL_DATA.structure');
assert(doclog.has('doc_no') && control.has('channel'));
assert(/ON doclog~doc_no = dcqm~doc_no/i.test(code));
assert(/doclog~channel AS destination/i.test(code));
for (const [variable, file] of [
  ['ls_input', 'ZPR_EON_FORMS_QUERY_PRINTHOUS3.structure'],
  ['ls_output', 'ZPR_EON_FORMS_QUERY_PRINTHOUS2.structure'],
  ['ls_file', 'ZPR_EON_FORMS_QUERY_PRINTHOUS1.structure'],
]) {
  const actual = definitionFields(file);
  const adapter = fs.readFileSync(path.join(dir, 'ZPR_DOC_RIP_PROXY.abap'), 'utf8');
  for (const m of adapter.matchAll(new RegExp('\\b' + variable + '-(\\w+)', 'gi'))) {
    assert(actual.has(m[1].toLowerCase()), file + ': unknown field ' + m[1]);
  }
}
const result = {
  tool: '@abaplint/core', version: core.Registry.abaplintVersion(),
  abapVersion: '7.54', files: names, issues,
  checks: {includeResolution: true, formResolution: true,
    alvCatalogFields: fields.size, noQu5Dependency: true,
    noDatabaseWrite: true, unitTestSources: definitions.length,
    activeDefinitionFieldNames: true},
  limitation: 'Parser and local structural checks only. No SAP type check, ATC, ABAP Unit execution, GUI test or Inspire call.',
};
fs.writeFileSync(path.join(project, '02_NOTES/2026-10-15_doc-rip-helyi-ellenorzes_WIP.json'),
  JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result, null, 2));
process.exitCode = issues.length ? 1 : 0;
