'use strict';
// Offline verification and inventory of the actual MCP responses; never calls SAP.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const workspace = path.resolve(__dirname, '../../../..');
const project = path.join(workspace, '[03] projects/tomeges-nyomtatas-endre');
const output = path.join(project, '05_FINAL/abap-2026-10-22');
const retrievalPath = path.join(output, '_mcp/retrieval-manifest_WIP.json');
const retrieval = JSON.parse(fs.readFileSync(retrievalPath, 'utf8'));
const digest = data => crypto.createHash('sha256').update(data).digest('hex');
const failures = [];
const verified = [];
for (const record of retrieval.records) {
  for (const expected of [{file:record.file, bytes:record.bytes, sha256:record.sha256}, ...record.artifacts]) {
    const data = fs.readFileSync(path.join(output, expected.file));
    if (digest(data) !== expected.sha256 || data.length !== expected.bytes) failures.push(expected.file);
    verified.push({...expected, verified:true});
  }
}
if (failures.length) throw new Error('HASH_MISMATCH:' + failures.join(','));
const missing = retrieval.planned.filter(p => !retrieval.records.some(r => r.id === p.id)).map(p => ({name:p.id, type:p.type, state:retrieval.failure?.operation.endsWith(':' + p.id) ? 'request_failed' : 'not_requested_after_stop'}));
const missingIncludes = new Set();
const changes = [];
for (const record of retrieval.records) {
  const source = record.artifacts[0];
  if (!source) continue;
  const data = fs.readFileSync(path.join(output,source.file), 'utf8');
  if (source.file.endsWith('.abap')) {
    for (const line of data.split(/\r?\n/)) {
      if (/^\s*\*/.test(line)) continue;
      const include = line.match(/^\s*INCLUDE\s+(z[\w/]+)\s*\./i)?.[1]?.toUpperCase();
      if (include && !retrieval.records.some(r => r.id === include)) missingIncludes.add(include);
    }
  }
  const alternatives = [source.file, record.id + '.class.abap'];
  const previous = alternatives.map(f => path.join(project,'05_FINAL/abap-2026-10-17',f)).find(f => fs.existsSync(f));
  changes.push({name:record.id, relationToPreviousLocalFile:previous ? (digest(fs.readFileSync(previous)) === source.sha256 ? 'same' : 'different') : 'new_in_snapshot'});
}
const groups = Object.fromEntries([...new Set(retrieval.records.map(r=>r.type))].map(type=>[type,retrieval.records.filter(r=>r.type===type).length]));
const result = {date:'2026-10-22', timezone:'Europe/Budapest', status:'WIP', complete:false, plannedObjectCount:retrieval.planned.length, downloadedObjectCount:retrieval.records.length, startedAt:retrieval.startedAt, stoppedAt:retrieval.failure?.at, connectionStop:retrieval.failure, groups, objects:retrieval.records, missing, missingIncludes:[...missingIncludes], changes, verifiedFiles:verified, validation:{allSavedHashesMatch:true, verifiedFileCount:verified.length, declarationWarnings:retrieval.declarationWarnings || []}, limitations:['Partial export; first HTTP 404 caused immediate process termination without retry.','Program/class/table/structure calls explicitly requested active. Include calls use GetInclude default version.','Metadata masterSystem is not independent proof of the connected SID/client.','No dynpro, GUI status, text pool, message class, index or complete dependency export.','No SAP writes, activation, compilation, ATC or runtime tests.']};
fs.writeFileSync(path.join(output,'2026-10-22_export-manifest_WIP.json'), JSON.stringify(result,null,2)+'\n');
const rows = retrieval.records.map(r=>`| ${r.id} | ${r.type} | [Forrás](${r.artifacts[0].file}) |`).join('\n');
const readme = `# MCP ABAP- és DDIC-export – 2026-10-22\n\nStátusz: **WIP, részleges export**. A felhasználó kérésére a helyileg konfigurált \`@mcp-abap-adt/core\` 6.4.1 szerverrel, MCP stdio protokollon lekért új pillanatkép. A korábbi exportok változatlanok.\n\n**25 / 28 objektum mentve:** 7 főprogram, 9 include, 4 osztály, 4 tábla, 1 struktúra. A korábbi 24 objektumos kör négy kiegészítése: ZCL_PR_STOCK, ZCL_PR_LOG, ZCL_PR_INSPIRE_GW, ZPR_DCQM_EXCLUDE_C01. Az utolsó include-ra már nem indult lekérés.\n\nAz explicit active lekérések eredményéből 25 forrás/definíció és 11 ADT-metaadat XML készült; az include-ok a GetInclude alapértelmezett verzióját használják. A nyers objektumválaszok és a lekérési napló az \`_mcp/\` alkönyvtárban vannak. A [manifeszt](2026-10-22_export-manifest_WIP.json) objektumonként tartalmazza a hívást, időpontot, fájlméretet és SHA256 értéket. Mind a ${verified.length} nyers válasz-/forrás-/metaadatfájl visszaolvasása és hash-ellenőrzése sikeres.\n\n## Leállás és hiányok\n\nA \`GetTypeInfo(ZPRB_EMAIL_SLOG)\` hívás HTTP **404** választ adott, ${retrieval.failure.at} időpontban. Az első hibánál a kliens leállította az MCP-folyamatot, az automatikus újrapróbálások előtt. Ez nem HTTP 401 és nem automatikus jóváhagyási elutasítás. A 404 a használt típuslekérési végpont eredménye; önmagában nem bizonyítja az objektum hiányát.\n\n${missing.map(m=>`- **${m.name}** (${m.type}): ${m.state === 'request_failed' ? 'lekérése HTTP 404-gyel sikertelen.' : 'a leállás miatt nem lett lekérve.'}`).join('\n')}\n\nÚjabb SAP-hívás csak kifejezett felhasználói újrapróbálási kérésre indulhat. A hiányzó forrásokat nem másoltuk át korábbi mentésből. A helyi INCLUDE-vizsgálat további hiányai: ${[...missingIncludes].join(', ') || 'nincs'}.\n\n## Mentett objektumok\n\n| Objektum | Típus | Export |\n|---|---|---|\n${rows}\n\n## Lényeges megállapítások és határok\n\n- A friss ZPR_CREATE_STOCK helyes deklarációja \`REPORT zpr_create_stock\`; a korábbi helyi fájlnév/programnév eltérése ebben a mentésben nem áll fenn.\n- A ZCL_PR_LOG aktív szignatúrájában elérhető az opcionális \`IV_EXT_ID\` konstruktorparaméter; a korábbi helyi ellenőrzéskor ez az osztályforrás még hiányzott.\n- A korábbi naplózási állapotjelentés történeti forrásból készült. A friss CREATE_STOCK XML-feltöltési blokkja kommentelt; a jelentés részleges teljesítésre vonatkozó állításait a mai forrás alapján külön újra kell értékelni. Ebben a körben csak export és helyi ellenőrzés történt.\n- A metaadatokban szereplő DHC masterSystem az objektum eredeti rendszerét jelöli; a kapcsolt SID/mandant nem kapott külön rendszerazonosító ellenőrzést.\n- A csomag nem teljes cockpit-, UI- vagy függőségmentés. Dynpro, GUI-státusz, szövegkészlet, üzenetosztály, index és zárobjektum nincs külön exportálva.\n- SAP-írás, aktiválás, fordítás, ATC és futtatott teszt nem történt. A 25 mentett objektum állapota a lekérés időpontjában igazolt; a teljes tervezett kör hiányos.\n`;
fs.writeFileSync(path.join(output,'README.md'),readme);
console.log(JSON.stringify({downloaded:retrieval.records.length, planned:retrieval.planned.length, verifiedFiles:verified.length, missing, groups, missingIncludes:[...missingIncludes], declarationWarnings:result.validation.declarationWarnings}));
