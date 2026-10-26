'use strict';
// Offline export verification. Does not connect to SAP or change source files.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

module.exports = function verify(output) {
  const manifest = JSON.parse(fs.readFileSync(path.join(output, '2026-10-26_export-manifest_WIP.json'), 'utf8'));
  const digest = value => crypto.createHash('sha256').update(value).digest('hex');
  const failures = [];
  let verifiedFiles = 0;
  for (const record of manifest.records) {
    for (const file of [record.raw, ...record.artifacts]) {
      const bytes = fs.readFileSync(path.join(output, file.file));
      if (bytes.length !== file.bytes || digest(bytes) !== file.sha256) failures.push(file.file);
      verifiedFiles++;
    }
    const raw = JSON.parse(fs.readFileSync(path.join(output, record.raw.file), 'utf8'));
    let object = raw.structuredContent || null;
    for (const content of raw.content || []) {
      if (!object && content.type === 'text') {
        try { object = JSON.parse(content.text); } catch (_) { /* Plain include source. */ }
      }
    }
    const artifact = record.artifacts[0];
    const expected = object
      ? (artifact.responseKey ? object[artifact.responseKey] : JSON.stringify(object, null, 2) + '\n')
      : raw.content.filter(content => content.type === 'text').map(content => content.text).join('\n');
    const source = fs.readFileSync(path.join(output, artifact.file), 'utf8');
    if (source !== expected) failures.push('response mismatch: ' + record.id);
    if (artifact.file.endsWith('.json')) JSON.parse(source);
  }
  if (manifest.failure || manifest.records.length !== manifest.planned.length) failures.push('incomplete export');
  if (new Set(manifest.records.map(record => record.id)).size !== manifest.records.length) failures.push('duplicate object');
  if (failures.length) throw new Error(failures.join('\n'));
  return { objects: manifest.records.length, planned: manifest.planned.length, verifiedFiles, failures };
};
