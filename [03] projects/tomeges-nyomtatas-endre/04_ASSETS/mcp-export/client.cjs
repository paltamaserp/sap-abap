'use strict';
// Read-only bridge to the user's configured stdio MCP server. No SAP HTTP fallback.
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');
const crypto = require('node:crypto');
const serverRoot = 'C:/Users/T13214/Documents/work/CS HANA/mcp/mcp-abap-adt';
const runtime = 'C:/Users/T13214/Documents/work/CS HANA/runtimes/node-v22.22.2-win-x64/node.exe';
const {Client} = require(serverRoot + '/node_modules/@modelcontextprotocol/sdk/dist/cjs/client/index.js');
const {StdioClientTransport} = require(serverRoot + '/node_modules/@modelcontextprotocol/sdk/dist/cjs/client/stdio.js');
const workspace = path.resolve(__dirname, '../../../..');
const output = path.join(workspace, '[03] projects/tomeges-nyomtatas-endre/05_FINAL/abap-2026-10-22');
const control = path.join(output, '_mcp');
fs.mkdirSync(control, {recursive: true});
let stopped = false;
let current = 'initialize';
const manifestFile = path.join(control, 'retrieval-manifest_WIP.json');
const manifest = {status: 'WIP', startedAt: new Date().toISOString(), protocol: 'MCP stdio', server: '@mcp-abap-adt/core', records: []};
function saveManifest() { fs.writeFileSync(manifestFile, JSON.stringify(manifest, null, 2) + '\n'); }
function report(value) { process.stdout.write(JSON.stringify(value) + '\n'); }
const transport = new StdioClientTransport({
  command: runtime,
  args: ['--require', path.join(__dirname, 'fail-stop.cjs'), path.join(serverRoot, 'bin/mcp-abap-adt.js'), '--transport=stdio', '--env-path=' + path.join(serverRoot, '.env')],
  cwd: workspace,
  stderr: 'pipe'
});
const client = new Client({name: 'workspace-readonly-export', version: '1.0.0'}, {capabilities: {}});
let stderrBuffer = '';
transport.stderr?.on('data', chunk => {
  stderrBuffer += chunk.toString();
  const lines = stderrBuffer.split(/\r?\n/);
  stderrBuffer = lines.pop();
  for (const line of lines) {
    if (!line.startsWith('MCP_EXPORT_STOP ')) continue;
    stopped = true;
    const failure = JSON.parse(line.slice('MCP_EXPORT_STOP '.length));
    manifest.failure = {operation: current, at: new Date().toISOString(), ...failure};
    saveManifest();
    report({event: 'STOPPED_FIRST_FAILURE', ...manifest.failure});
  }
  if (stderrBuffer.length > 10000) stderrBuffer = '';
});
function sha256(data) { return crypto.createHash('sha256').update(data).digest('hex'); }
function plan() {
  const baseline = JSON.parse(fs.readFileSync(path.join(workspace, '[03] projects/tomeges-nyomtatas-endre/05_FINAL/abap-2026-10-17/2026-10-17_export-manifest_WIP.json'), 'utf8'));
  const objects = [...baseline.objects];
  for (const [name,type] of [['ZCL_PR_STOCK','CLAS/OC'],['ZCL_PR_LOG','CLAS/OC'],['ZCL_PR_INSPIRE_GW','CLAS/OC'],['ZPR_DCQM_EXCLUDE_C01','PROG/I']]) {
    if (!objects.some(o => o.name === name)) objects.push({name,type});
  }
  const priority = ['ZPR_CREATE_STOCK','ZPR_CLOSE_STOCK','ZPR_DC_FRAME','ZPR_DOC_STATUS','ZCL_PR_STOCK','ZCL_PR_LOG','ZCL_PR_INSPIRE_GW'];
  objects.sort((a,b) => (priority.includes(a.name) ? priority.indexOf(a.name) : 99) - (priority.includes(b.name) ? priority.indexOf(b.name) : 99));
  return objects.map(o => {
    const [tool,key,extension] = o.type === 'PROG/P' ? ['ReadProgram','program_name','.abap'] : o.type === 'PROG/I' ? ['GetInclude','include_name','.abap'] : o.type.startsWith('CLAS') ? ['ReadClass','class_name','.abap'] : o.type === 'TABL/DT' ? ['GetTable','table_name','.table'] : o.type === 'TABL/DS' ? ['GetStructure','structure_name','.structure'] : ['GetTypeInfo','type_name','.ttyp.json'];
    const args = {[key]: o.name};
    if (tool === 'GetTypeInfo') args.include_structure_fallback = false;
    else if (tool !== 'GetInclude') args.version = 'active';
    return {id:o.name, type:o.type, tool, args, extension};
  });
}
function unpack(result) {
  if (result.structuredContent) return result.structuredContent;
  const blocks = (result.content || []).filter(x => x.type === 'text').map(x => x.text);
  for (const block of blocks) { try { return JSON.parse(block); } catch {} }
  return {text: blocks.join('\n')};
}
async function main() {
  saveManifest();
  await client.connect(transport, {timeout: 30000});
  const tools = await client.listTools({}, {timeout: 30000});
  fs.writeFileSync(path.join(control, 'tools.json'), JSON.stringify(tools, null, 2));
  const batch = process.argv.includes('--export');
  report({event: 'READY', tools: tools.tools.length});
  const commands = batch ? plan().map(x => JSON.stringify(x)) : readline.createInterface({input: process.stdin, terminal: false});
  if (batch) { manifest.planned = plan(); saveManifest(); report({event:'PLAN', objects:manifest.planned.length}); }
  for await (const line of commands) {
    if (!line.trim()) continue;
    if (stopped) break;
    const command = JSON.parse(line);
    if (command.action === 'close') break;
    if (!/^[A-Za-z0-9_]+$/.test(command.id)) throw new Error('INVALID_OBJECT_ID');
    const available = tools.tools.find(t => t.name === command.tool);
    if (!available || !/^(GetProgram|ReadProgram|GetClass|ReadClass|GetInclude|GetTable|GetStructure|GetTypeInfo|GetFunctionGroup|GetSystemInformation)$/.test(command.tool)) throw new Error('TOOL_NOT_ALLOWED');
    current = command.tool + ':' + command.id;
    report({event: 'READING', operation: current});
    const result = await client.callTool({name: command.tool, arguments: command.args}, undefined, {timeout: 90000});
    if (stopped) break;
    if (result.isError) {
      manifest.failure = {kind:'mcp_tool_error', operation:current, at:new Date().toISOString()};
      saveManifest(); report({event:'STOPPED_TOOL_ERROR', operation:current}); break;
    }
    const data = unpack(result);
    if (data.success === false) throw new Error('UNSUCCESSFUL_OBJECT_RESPONSE');
    const artifacts = [];
    if (command.extension) {
      let source = data.source_code || data.program_data || data.class_data || data.table_data || data.structure_data || data.text;
      if (command.extension === '.ttyp.json') source = JSON.stringify(data, null, 2) + '\n';
      if (typeof source !== 'string' || !source.trim()) throw new Error('EMPTY_OBJECT_SOURCE');
      const sourceFile = command.id + command.extension;
      fs.writeFileSync(path.join(output,sourceFile), source, {flag:'wx'});
      const reread = fs.readFileSync(path.join(output,sourceFile));
      if (!reread.equals(Buffer.from(source))) throw new Error('SOURCE_VERIFICATION_FAILED');
      artifacts.push({file:sourceFile, bytes:reread.length, sha256:sha256(reread)});
      if (data.metadata && typeof data.metadata === 'string') {
        const metadataFile = command.id + '.metadata.xml';
        fs.writeFileSync(path.join(output,metadataFile), data.metadata, {flag:'wx'});
        artifacts.push({file:metadataFile, bytes:Buffer.byteLength(data.metadata), sha256:sha256(data.metadata)});
      }
      if (command.type === 'PROG/P') {
        const declaration = source.match(/^\s*(?:REPORT|PROGRAM)\s+([\w/]+)/im)?.[1]?.toUpperCase();
        if (declaration !== command.id) manifest.declarationWarnings = [...(manifest.declarationWarnings || []), {id:command.id,declaration}];
      }
    }
    const file = path.join(control, command.id + '.json');
    const serialized = JSON.stringify(data, null, 2) + '\n';
    fs.writeFileSync(file, serialized, {flag: 'wx'});
    manifest.records.push({id:command.id, type:command.type, tool:command.tool, args:command.args, retrievedAt:new Date().toISOString(), file:path.relative(output,file), bytes:Buffer.byteLength(serialized), sha256:sha256(serialized), artifacts});
    saveManifest();
    report({event:'SAVED', id:command.id, keys:Object.keys(data), bytes:Buffer.byteLength(serialized)});
  }
  manifest.endedAt = new Date().toISOString(); manifest.complete = !manifest.failure && manifest.records.length === manifest.planned?.length; saveManifest(); report({event:'FINISHED', downloaded:manifest.records.length, complete:manifest.complete}); await client.close();
}
main().catch(async error => {
  if (!manifest.failure) manifest.failure = {kind:'client_error', operation:current, code:error.code || error.name || 'ERROR', at:new Date().toISOString()};
  saveManifest(); report({event:'CLIENT_STOPPED', ...manifest.failure});
  try { await client.close(); } catch {}
  process.exitCode = 1;
});
