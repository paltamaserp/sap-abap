'use strict';
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const readline = require('node:readline');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../../../..');
const configPath = path.join(root, '.codex/config.toml');
let inside = false;
const lines = [];
for (const line of fs.readFileSync(configPath, 'utf8').split(/\r?\n/)) {
  if (line.startsWith('[')) { inside = line === '[mcp_servers.sap-abap-adt]'; continue; }
  if (inside) lines.push(line);
}
const section = lines.join('\n');
const command = section.match(/^command\s*=\s*'([^']+)'/m)?.[1];
const argsText = section.match(/^args\s*=\s*\[([\s\S]*?)\]/m)?.[1] || '';
const configuredArgs = [...argsText.matchAll(/'([^']*)'|"([^"\n]*)"/g)].map(m => m[1] ?? m[2]);
assert(command && fs.existsSync(command));
assert(configuredArgs.some(a => a.endsWith('mcp-abap-adt.js')));
const envFile = configuredArgs.find(a => a.startsWith('--env-path='))?.slice('--env-path='.length);
assert(envFile && fs.existsSync(envFile));
const envLines = fs.readFileSync(envFile, 'utf8');
const configuredClient = envLines.match(/^SAP_CLIENT\s*=\s*['"]?(\d+)/m)?.[1];
const configuredUrl = envLines.match(/^SAP_URL\s*=\s*['"]?([^\s'"]+)/m)?.[1];
assert.equal(configuredClient, '100');
assert.equal(new URL(configuredUrl).hostname.toLowerCase(), 'dhc.apps.eon.com');
const child = cp.spawn(command, ['--preserve-symlinks', '--preserve-symlinks-main', '--require',
  path.join(__dirname, 'stop-on-connection-failure.cjs'), '--require',
  path.join(__dirname, 'scoped-adt-extensions.cjs'), ...configuredArgs], {
  cwd: root, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'],
  env: {...process.env, CODEX_ADT_SERVER_ROOT: path.resolve(path.dirname(configuredArgs[0]), '..'), SAP_MASTER_SYSTEM: 'DHC', DEBUG_AUTH_LOG: 'false',
    DEBUG_AUTH_BROKER: 'false', DEBUG_CONNECTORS: 'false', DEBUG_HANDLERS: 'false', HANDLER_LOG_SILENT: 'true'}
});
let id = 0;
let exited = false;
const pending = new Map();
const output = readline.createInterface({input: child.stdout});
output.on('line', line => {
  let message;
  try { message = JSON.parse(line); } catch { return; }
  const waiting = pending.get(message.id);
  if (!waiting) return;
  pending.delete(message.id);
  clearTimeout(waiting.timer);
  if (message.error) waiting.resolve({isError:true, content:[{type:'text', text:message.error.message || ('MCP_ERROR_' + message.error.code)}]});
  else waiting.resolve(message.result);
});
let stopReason;
child.stderr.on('data', data => {
  // The server's diagnostics can contain connection details. Emit only our guard marker.
  const match = data.toString().match(/SAP_CONNECTION_STOP ([A-Z0-9_]+)/);
  if (match) { stopReason = match[1]; console.log(JSON.stringify({event: 'sap_connection_stopped', reason: stopReason})); }
});
child.on('exit', code => {
  exited = true;
  console.log(JSON.stringify({event: 'configured_adt_server_exited', code, reason: stopReason || 'No SAP response exposed'}));
  for (const w of pending.values()) { clearTimeout(w.timer); w.reject(new Error(stopReason || 'ADT_SERVER_EXIT_' + code)); }
  pending.clear();
  process.exitCode = code || 0;
});
function rpc(method, params) {
  if (exited) return Promise.reject(new Error('ADT_SESSION_CLOSED_NO_RETRY'));
  return new Promise((resolve, reject) => {
    const requestId = ++id;
    const timer = setTimeout(() => {
      pending.delete(requestId);
      child.kill();
      reject(new Error('ADT_MCP_TIMEOUT_NO_RETRY'));
    }, 55000);
    pending.set(requestId, {resolve, reject, timer});
    child.stdin.write(JSON.stringify({jsonrpc: '2.0', id: requestId, method, params}) + '\n');
  });
}
async function start() {
  await rpc('initialize', {protocolVersion: '2024-11-05', capabilities: {},
    clientInfo: {name: 'authorized-DHC100-report-deployment', version: '1.0.0'}});
  child.stdin.write(JSON.stringify({jsonrpc: '2.0', method: 'notifications/initialized'}) + '\n');
  const listed = await rpc('tools/list', {});
  fs.writeFileSync(path.join(__dirname, 'adt-tools.json'), JSON.stringify(listed, null, 2));
  console.log(JSON.stringify({event: 'adt_ready', target: 'DHC/100', toolCount: listed.tools?.length,
    scopedTools: listed.tools?.filter(t => t.name.startsWith('Scoped')).map(t => t.name)}));
  const input = readline.createInterface({input: process.stdin});
  for await (const line of input) {
    if (!line.trim()) continue;
    const action = JSON.parse(line);
    if (action.close) { child.stdin.end(); child.kill(); input.close(); return; }
    const tool = listed.tools?.find(t => t.name === action.name);
    assert(tool, 'Unknown MCP tool');
    let argumentsObject = action.arguments || {};
    if (action.argumentsFile) {
      assert(/^[A-Za-z0-9_.-]+$/.test(action.argumentsFile));
      argumentsObject = JSON.parse(fs.readFileSync(path.join(__dirname, action.argumentsFile), 'utf8'));
    }
    const result = await rpc('tools/call', {name: action.name, arguments: argumentsObject});
    const filename = String(action.saveAs || ('result-' + id + '.json'));
    assert(/^[A-Za-z0-9_.-]+$/.test(filename));
    function scrub(value) {
      if (Array.isArray(value)) return value.map(scrub);
      if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value)
        .map(([k,v]) => [k, /cookie|csrf|authorization|access.?token|refresh.?token|password|session_state/i.test(k) ? '[REDACTED]' : scrub(v)]));
      if (typeof value === 'string') { try { return JSON.stringify(scrub(JSON.parse(value))); } catch { return value; } }
      return value;
    }
    fs.writeFileSync(path.join(__dirname, filename), JSON.stringify(scrub(result), null, 2));
    fs.appendFileSync(path.join(__dirname, 'operations.jsonl'), JSON.stringify({utc:new Date().toISOString(), tool:action.name, file:filename, isError:!!result.isError}) + '\n');
    console.log(JSON.stringify({event: 'tool_completed', name: action.name, saved: filename,
      isError: result.isError || false, contentTypes: result.content?.map(c => c.type)}));
    // Compiler/object errors do not authorize a retry of failed connections.
    // Network/authentication errors still terminate the CHILD immediately via the guard.
    if (exited) { input.close(); return; }
  }
  child.kill();
}
start().catch(error => {
  console.log(JSON.stringify({event: 'deployment_session_stopped', reason: error.message,
    note:'Consult operations.jsonl and read-backs for confirmed write state.'}));
  child.kill();
  process.exitCode = 1;
});
