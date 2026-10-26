'use strict';
// Narrow in-memory extensions to the ORIGINAL configured MCP server.
// No installed server file or connection configuration is modified.
const path = require('node:path');
const {createRequire} = require('node:module');
const assert = require('node:assert/strict');
const serverRoot = process.env.CODEX_ADT_SERVER_ROOT;
assert(serverRoot);
const req = createRequire(path.join(serverRoot, 'package.json'));
const {z} = req('zod');
const {XMLParser} = req('fast-xml-parser');
const {BaseMcpServer} = req('./dist/server/BaseMcpServer.js');
const {createAdtClient} = req('./dist/lib/clients.js');
const names = {program: 'ZPR_CLOSE_STOCK', class: 'ZCL_PR_STOCK'};
const textCT = 'application/vnd.sap.adt.textelements.symbols.v1';
const objUri = kind => kind === 'program' ? '/sap/bc/adt/programs/programs/zpr_close_stock' : '/sap/bc/adt/oo/classes/zcl_pr_stock';
const textUri = kind => '/sap/bc/adt/textelements/' + (kind === 'program' ? 'programs/zpr_close_stock' : 'classes/zcl_pr_stock');
const oldRegister = BaseMcpServer.prototype.registerHandlers;
BaseMcpServer.prototype.registerHandlers = function(registry) {
  oldRegister.call(this, registry);
  const add = (name, schema, handler) => this.registerTool(name, {description: 'Authorized DHC/100 deployment; only ZPR_CLOSE_STOCK and ZCL_PR_STOCK.', inputSchema: schema}, async args => {
    try {
      const connection = await this.getConnection();
      const result = await handler(connection, args);
      return {content: [{type: 'text', text: JSON.stringify(result)}]};
    } catch (e) {
      return {isError: true, content: [{type: 'text', text: e.response?.data || e.message || 'Scoped ADT operation failed'}]};
    }
  });
  const kind = z.enum(['program', 'class']);
  add('ScopedReadTextSymbols', {kind}, async (c, a) => {
    const r = await c.makeAdtRequest({url: textUri(a.kind) + '/source/symbols?sap-language=HU', method: 'GET', headers: {Accept: textCT}});
    return {object: names[a.kind], language: 'HU', status: r.status, data: r.data};
  });
  add('ScopedReadObjectState', {kind, textPool: z.boolean().optional()}, async (c, a) => {
    const r = await c.makeAdtRequest({url: (a.textPool ? textUri(a.kind) : objUri(a.kind)) + '?version=inactive', method: 'GET', headers: {Accept: 'application/xml'}});
    return {object: names[a.kind], textPool: a.textPool || false, status: r.status, data: r.data};
  });
  add('ScopedCheckSource', {kind, version: z.enum(['active','inactive']), source_code: z.string().optional()}, async (c, a) => {
    const client = createAdtClient(c, this.logger);
    const object = a.kind === 'program' ? client.getProgram() : client.getClass();
    const config = a.kind === 'program' ? {programName: names[a.kind]} : {className: names[a.kind]};
    if (a.source_code !== undefined) config.sourceCode = a.source_code;
    const result = await object.check(config, a.version);
    return {object: names[a.kind], version: a.version, hypothetical: a.source_code !== undefined,
      data: result.checkResult?.data, status: result.checkResult?.status};
  });
  add('ScopedActivateAuthorizedObject', {kind, textPool: z.boolean()}, async (c, a) => {
    c.setSessionType('stateful');
    const uri = a.textPool ? textUri(a.kind) : objUri(a.kind);
    const body = '<?xml version="1.0" encoding="UTF-8"?>' +
      '<adtcore:objectReferences xmlns:adtcore="http://www.sap.com/adt/core">' +
      '<adtcore:objectReference adtcore:uri="' + uri + '" adtcore:name="' + names[a.kind] + '"/>' +
      '</adtcore:objectReferences>';
    const r = await c.makeAdtRequest({url:'/sap/bc/adt/activation?method=activate&preauditRequested=false',
      method:'POST', data:body, headers:{'Content-Type':'application/vnd.sap.adt.activation+xml', Accept:'application/xml'}});
    return {object:names[a.kind], textPool:a.textPool, status:r.status, data:r.data};
  });
  add('ScopedWriteTextSymbols', {kind, source: z.string(), expected_before: z.string(), transport: z.literal('DHCK906298')}, async (c, a) => {
    c.setSessionType('stateful');
    const object = textUri(a.kind);
    const headers = {Accept: textCT, 'Content-Type': textCT};
    const lock = await c.makeAdtRequest({url: object + '?_action=LOCK&accessMode=MODIFY', method: 'POST', data: null,
      headers: {Accept: 'application/vnd.sap.as+xml;charset=UTF-8;dataname=com.sap.adt.lock.result;q=0.8, application/vnd.sap.as+xml;charset=UTF-8;dataname=com.sap.adt.lock.result2;q=0.9'}});
    const xml = new XMLParser({ignoreAttributes: false});
    const parsed = xml.parse(lock.data);
    const handle = parsed?.['asx:abap']?.['asx:values']?.DATA?.LOCK_HANDLE;
    assert(handle, 'No text-pool lock handle returned');
    let written = false;
    try {
      const before = await c.makeAdtRequest({url: object + '/source/symbols?sap-language=HU', method: 'GET', headers: {Accept: textCT}});
      assert.equal(before.data, a.expected_before, 'Text symbols changed since the reviewed snapshot; no write performed');
      const r = await c.makeAdtRequest({url: object + '/source/symbols?sap-language=HU&lockHandle=' + encodeURIComponent(handle) + '&corrNr=' + encodeURIComponent(a.transport),
        method: 'PUT', data: a.source, headers});
      written = true;
      const after = await c.makeAdtRequest({url: object + '/source/symbols?sap-language=HU', method: 'GET', headers: {Accept: textCT}});
      return {object: names[a.kind], language:'HU', written:true, status:r.status, data:after.data};
    } catch (e) {
      e.message = (written ? 'Text symbols saved; verification pending: ' : 'Text symbols not written: ') + e.message;
      throw e;
    } finally {
      await c.makeAdtRequest({url: object + '?_action=UNLOCK&lockHandle=' + encodeURIComponent(handle), method:'POST', data:null});
    }
  });
};
