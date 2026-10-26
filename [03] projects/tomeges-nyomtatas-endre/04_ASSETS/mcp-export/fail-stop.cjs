'use strict';
// Stop the configured MCP server before its internal HTTP retry handlers run.
let stopped = false;
function stop(details) {
  if (stopped) return;
  stopped = true;
  process.stderr.write('MCP_EXPORT_STOP ' + JSON.stringify(details) + '\n');
  process.exit(81);
}
for (const scheme of ['http', 'https']) {
  const transport = require(scheme);
  const original = transport.request;
  transport.request = function (...args) {
    const request = original.apply(this, args);
    request.prependOnceListener('response', response => {
      if (response.statusCode >= 400) stop({kind: 'http', status: response.statusCode});
    });
    request.prependOnceListener('error', error => stop({kind: 'network', code: error.code || 'NETWORK_ERROR'}));
    request.prependOnceListener('timeout', () => stop({kind: 'timeout'}));
    return request;
  };
}
