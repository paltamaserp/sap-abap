'use strict';
// Enforce the user's one-attempt rule before the configured MCP client's retries.
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const auditFile = path.join(__dirname, 'connection-audit.jsonl');
let stopped = false;
let responses = 0;
function audit(entry) {
  fs.appendFileSync(auditFile, JSON.stringify({utc: new Date().toISOString(), ...entry}) + '\n');
}
function stop(reason) {
  if (stopped) return;
  stopped = true;
  audit({event: 'connection_stopped', reason});
  // No URL, request headers, credentials, cookies or response body are logged.
  process.stderr.write('SAP_CONNECTION_STOP ' + reason + '\n');
  process.exit(70);
}
const originalEmit = http.ClientRequest.prototype.emit;
http.ClientRequest.prototype.emit = function(event, ...args) {
  if (event === 'response') {
    const status = args[0]?.statusCode;
    responses += 1;
    audit({event: 'http_response', number: responses, status});
    if (status === 401 || status === 403 || status >= 500) stop('HTTP_' + status);
  } else if (event === 'error' || event === 'timeout') {
    const code = args[0]?.code;
    const safeCode = typeof code === 'string' && /^[A-Z0-9_]+$/.test(code) ? code : event.toUpperCase();
    stop(safeCode);
  }
  return originalEmit.call(this, event, ...args);
};
audit({event: 'guard_loaded', targetSystem: 'DHC', client: '100', stopAfterFirstFailure: true});
