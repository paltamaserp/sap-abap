'use strict';
// One user-authorized MCP/SAP access check. Never retries after failure.
const fs=require('node:fs'),path=require('node:path');
const root='C:/Users/T13214/Documents/work/CS HANA/mcp/mcp-abap-adt';
const runtime='C:/Users/T13214/Documents/work/CS HANA/runtimes/node-v22.22.2-win-x64/node.exe';
const {Client}=require(root+'/node_modules/@modelcontextprotocol/sdk/dist/cjs/client/index.js');
const {StdioClientTransport}=require(root+'/node_modules/@modelcontextprotocol/sdk/dist/cjs/client/stdio.js');
const out=path.resolve(__dirname,'../../01_SOURCES/2026-10-28_sap-adt-access-retry-02_WIP');
fs.mkdirSync(out,{recursive:true});
const recordFile=path.join(out,'access-result.json');
if(fs.existsSync(recordFile))throw new Error('ATTEMPT_ALREADY_CONSUMED');
const record={startedAt:new Date().toISOString(),authorization:'ellenőrizd a sap-abap-adt mcp elérést',transport:'MCP stdio',stage:'initialize',events:[],sapRead:false,status:'RUNNING'};
function save(){fs.writeFileSync(recordFile,JSON.stringify(record,null,2)+'\n');}
function event(type,details={}){const e={at:new Date().toISOString(),stage:record.stage,type,...details};record.events.push(e);save();process.stdout.write(JSON.stringify(e)+'\n');}
save();
const transport=new StdioClientTransport({command:runtime,args:['--require',path.join(__dirname,'fail-stop.cjs'),path.join(root,'bin/mcp-abap-adt.js'),'--transport=stdio','--env-path='+path.join(root,'.env')],cwd:path.resolve(__dirname,'../../../..'),stderr:'pipe'});
const client=new Client({name:'user-authorized-access-check',version:'1.0.0'},{capabilities:{}});
let stderr='';let failed=false;
transport.stderr?.on('data',chunk=>{
 stderr+=chunk.toString();const lines=stderr.split(/\r?\n/);stderr=lines.pop();
 for(const line of lines){
  if(line.startsWith('MCP_EXPORT_STOP ')){
   failed=true;record.status='FAILED';record.failure={...JSON.parse(line.slice(16)),stage:record.stage};event('FIRST_FAILURE',record.failure);
  }else{
   const code=line.match(/\b(?:EACCES|EPERM|ENOENT|ENOTFOUND|ECONNREFUSED|ECONNRESET|ETIMEDOUT|MODULE_NOT_FOUND|SyntaxError)\b/)?.[0];
   if(code)event('SERVER_DIAGNOSTIC',{code});
  }
 }
 if(stderr.length>10000)stderr='';
});
async function main(){
 try{
  event('ATTEMPT_STARTED');await client.connect(transport,{timeout:30000});event('INITIALIZED');
  record.stage='list_tools';const inventory=await client.listTools({},{timeout:30000});
  fs.writeFileSync(path.join(out,'tools.json'),JSON.stringify(inventory,null,2)+'\n');event('TOOLS_AVAILABLE',{count:inventory.tools.length});
  if(failed)return;
  const tool=inventory.tools.find(t=>t.name==='GetSqlQuery');if(!tool)throw Object.assign(new Error(),{code:'READ_TOOL_UNAVAILABLE'});
  record.stage='sap_read';const args={sql_query:'SELECT component, release, extrelease FROM cvers',row_number:5};
  event('SAP_READ_STARTED');const result=await client.callTool({name:'GetSqlQuery',arguments:args},undefined,{timeout:45000});
  if(failed)return;
  fs.writeFileSync(path.join(out,'sap-read.json'),JSON.stringify({at:new Date().toISOString(),tool:'GetSqlQuery',args,result},null,2)+'\n');
  if(result.isError){record.status='FAILED';record.failure={kind:'mcp_tool_error',stage:record.stage};event('TOOL_FAILED');return;}
  record.sapRead=true;record.status='SUCCESS';event('SAP_READ_COMPLETED');
 }catch(e){
  if(!failed){record.status='FAILED';record.failure={kind:e.code===-32001?'timeout':'client_error',code:e.code || e.name,stage:record.stage};event('STOPPED',record.failure);}
 }finally{
  record.endedAt=new Date().toISOString();save();
  try{await client.close();}catch{}
  process.stdout.write(JSON.stringify({status:record.status,stage:record.stage,sapRead:record.sapRead})+'\n');
  if(record.status!=='SUCCESS')process.exitCode=1;
 }
}
main();
