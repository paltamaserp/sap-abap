'use strict';
// Read-only QA evidence collection over the configured MCP stdio server.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = 'C:/Users/T13214/Documents/work/CS HANA/mcp/mcp-abap-adt';
const runtime = 'C:/Users/T13214/Documents/work/CS HANA/runtimes/node-v22.22.2-win-x64/node.exe';
const {Client} = require(root + '/node_modules/@modelcontextprotocol/sdk/dist/cjs/client/index.js');
const {StdioClientTransport} = require(root + '/node_modules/@modelcontextprotocol/sdk/dist/cjs/client/stdio.js');
const retryAuthorized = process.argv.includes('--explicit-retry-2026-10-28');
const liveEvidence = process.argv.includes('--program-evidence');
if (liveEvidence) {
  const access = JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../01_SOURCES/2026-10-28_sap-adt-access-retry-02_WIP/access-result.json'),'utf8'));
  if (access.status !== 'SUCCESS' || !access.sapRead) throw new Error('ACCESS_NOT_RESTORED');
}
const out = path.resolve(__dirname, liveEvidence
  ? '../../01_SOURCES/2026-10-28_elengedesi-qa-program-live_WIP'
  : retryAuthorized
  ? '../../01_SOURCES/2026-10-28_elengedesi-qa-program-retry-01_WIP'
  : '../../01_SOURCES/2026-10-28_elengedesi-qa-mcp_WIP');
fs.mkdirSync(out, {recursive:true});
const stopFile = path.join(out, 'STOP.json');
if (fs.existsSync(stopFile)) throw new Error('STOP_REQUIRES_EXPLICIT_USER_RETRY');
const inputFile = process.argv[2];
const command = inputFile ? JSON.parse(fs.readFileSync(inputFile,'utf8').replace(/^\uFEFF/,'')) : null;
const allowed = /^(GetSystemInformation|GetTransport|ListTransports|GetTable|GetTableContents|GetSqlQuery|SearchObject|SearchObjects|GetClass|ReadClass|GetInclude|GetProgram|ReadProgram|GetEnhancements|GetEnhancementSpot|GetEnhancementImpl)$/;
if (command && (!allowed.test(command.tool) || !/^[a-zA-Z0-9_-]+$/.test(command.id))) throw new Error('READ_ONLY_ALLOWLIST');
if (command?.tool === 'GetSqlQuery' && !/^SELECT\s/i.test(command.args.query || command.args.sql_query || '')) throw new Error('SELECT_ONLY');
const client = new Client({name:'qa-readonly-evidence',version:'1.0.0'},{capabilities:{}});
const transport = new StdioClientTransport({command:runtime,args:['--require',path.join(__dirname,'fail-stop.cjs'),path.join(root,'bin/mcp-abap-adt.js'),'--transport=stdio','--env-path='+path.join(root,'.env')],cwd:path.resolve(__dirname,'../../../..'),stderr:'pipe'});
let buffer = '';
transport.stderr?.on('data', chunk => {
  buffer += chunk.toString();
  const lines = buffer.split(/\r?\n/); buffer = lines.pop();
  for (const line of lines) if (line.startsWith('MCP_EXPORT_STOP ')) {
    const failure = {at:new Date().toISOString(),operation:command?.tool || 'initialize',...JSON.parse(line.slice(16))};
    fs.writeFileSync(stopFile,JSON.stringify(failure,null,2)+'\n');
    process.stdout.write(JSON.stringify({event:'STOPPED_FIRST_FAILURE',...failure})+'\n');
  }
  if (buffer.length>10000) buffer='';
});
async function main() {
  await client.connect(transport,{timeout:30000});
  const inventory = await client.listTools({}, {timeout:30000});
  fs.writeFileSync(path.join(out,'tools.json'),JSON.stringify(inventory,null,2)+'\n');
  if (!command) {
    const relevant = inventory.tools.filter(t=>/sql|table|transport|search|system|atc|inspection|variant|enhance/i.test(t.name));
    process.stdout.write(JSON.stringify(relevant)+'\n');
  } else {
    if (!inventory.tools.some(t=>t.name===command.tool)) throw new Error('TOOL_UNAVAILABLE');
    const result = await client.callTool({name:command.tool,arguments:command.args},undefined,{timeout:60000});
    const evidence = {at:new Date().toISOString(),protocol:'MCP stdio',tool:command.tool,args:command.args,result};
    const data = JSON.stringify(evidence,null,2)+'\n';
    fs.writeFileSync(path.join(out,command.id+'.json'),data,{flag:'wx'});
    if (result.isError) fs.writeFileSync(stopFile,JSON.stringify({at:new Date().toISOString(),operation:command.tool,kind:'mcp_tool_error'},null,2)+'\n');
    let parsed=result.structuredContent;
    if (!parsed) for (const block of result.content || []) if (block.type==='text') { try {parsed=JSON.parse(block.text);break;}catch{} }
    const source=parsed?.source_code || parsed?.class_data || parsed?.program_data || parsed?.include_data;
    if (typeof source==='string') fs.writeFileSync(path.join(out,command.id+'.source.txt'),source,{flag:'wx'});
    process.stdout.write(JSON.stringify({id:command.id,isError:result.isError || false,bytes:Buffer.byteLength(data),sha256:crypto.createHash('sha256').update(data).digest('hex'),data:typeof source==='string'?{source_bytes:Buffer.byteLength(source),keys:Object.keys(parsed)}:parsed || result})+'\n');
  }
  await client.close();
}
main().catch(async e=>{
  if (!fs.existsSync(stopFile)) fs.writeFileSync(stopFile,JSON.stringify({at:new Date().toISOString(),operation:command?.tool || 'initialize',kind:'client_error',code:e.code || e.name},null,2)+'\n');
  process.stdout.write(JSON.stringify({event:'CLIENT_STOPPED',code:e.code || e.name})+'\n');
  try { await client.close(); } catch {}
  process.exitCode=1;
});
