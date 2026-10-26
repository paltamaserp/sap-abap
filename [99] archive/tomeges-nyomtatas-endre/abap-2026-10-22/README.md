# MCP ABAP- és DDIC-export – 2026-10-22

Státusz: **WIP, részleges export**. A felhasználó kérésére a helyileg konfigurált `@mcp-abap-adt/core` 6.4.1 szerverrel, MCP stdio protokollon lekért új pillanatkép. A korábbi exportok változatlanok.

**25 / 28 objektum mentve:** 7 főprogram, 9 include, 4 osztály, 4 tábla, 1 struktúra. A korábbi 24 objektumos kör négy kiegészítése: ZCL_PR_STOCK, ZCL_PR_LOG, ZCL_PR_INSPIRE_GW, ZPR_DCQM_EXCLUDE_C01. Az utolsó include-ra már nem indult lekérés.

Az explicit active lekérések eredményéből 25 forrás/definíció és 11 ADT-metaadat XML készült; az include-ok a GetInclude alapértelmezett verzióját használják. A nyers objektumválaszok és a lekérési napló az `_mcp/` alkönyvtárban vannak. A [manifeszt](2026-10-22_export-manifest_WIP.json) objektumonként tartalmazza a hívást, időpontot, fájlméretet és SHA256 értéket. Mind a 61 nyers válasz-/forrás-/metaadatfájl visszaolvasása és hash-ellenőrzése sikeres.

## Leállás és hiányok

A `GetTypeInfo(ZPRB_EMAIL_SLOG)` hívás HTTP **404** választ adott, 2026-10-22T15:06:28.457Z időpontban. Az első hibánál a kliens leállította az MCP-folyamatot, az automatikus újrapróbálások előtt. Ez nem HTTP 401 és nem automatikus jóváhagyási elutasítás. A 404 a használt típuslekérési végpont eredménye; önmagában nem bizonyítja az objektum hiányát.

- **ZPRB_EMAIL_SLOG** (TTYP/DA): lekérése HTTP 404-gyel sikertelen.
- **ZPRB_SLOG_EMAIL** (TTYP/DA): a leállás miatt nem lett lekérve.
- **ZPR_DCQM_EXCLUDE_C01** (PROG/I): a leállás miatt nem lett lekérve.

Újabb SAP-hívás csak kifejezett felhasználói újrapróbálási kérésre indulhat. A hiányzó forrásokat nem másoltuk át korábbi mentésből. A helyi INCLUDE-vizsgálat további hiányai: ZPR_DCQM_EXCLUDE_C01.

## Mentett objektumok

| Objektum | Típus | Export |
|---|---|---|
| ZPR_CREATE_STOCK | PROG/P | [Forrás](ZPR_CREATE_STOCK.abap) |
| ZPR_CLOSE_STOCK | PROG/P | [Forrás](ZPR_CLOSE_STOCK.abap) |
| ZPR_DC_FRAME | PROG/P | [Forrás](ZPR_DC_FRAME.abap) |
| ZPR_DOC_STATUS | PROG/P | [Forrás](ZPR_DOC_STATUS.abap) |
| ZCL_PR_STOCK | CLAS/OC | [Forrás](ZCL_PR_STOCK.abap) |
| ZCL_PR_LOG | CLAS/OC | [Forrás](ZCL_PR_LOG.abap) |
| ZCL_PR_INSPIRE_GW | CLAS/OC | [Forrás](ZCL_PR_INSPIRE_GW.abap) |
| ZPR_DCQM_EXCLUDE_O01 | PROG/I | [Forrás](ZPR_DCQM_EXCLUDE_O01.abap) |
| ZPR_DCQM_EXCLUDE | PROG/P | [Forrás](ZPR_DCQM_EXCLUDE.abap) |
| ZPR_MESSAGEQUEUE_QUERY | PROG/P | [Forrás](ZPR_MESSAGEQUEUE_QUERY.abap) |
| ZPR_DOC_RIP | PROG/P | [Forrás](ZPR_DOC_RIP.abap) |
| ZCL_PR_QM_SAMPLER | CLAS/OC | [Forrás](ZCL_PR_QM_SAMPLER.abap) |
| ZPR_DCQM_EXCLUDE_I01 | PROG/I | [Forrás](ZPR_DCQM_EXCLUDE_I01.abap) |
| ZPR_MQ_PROXY | PROG/I | [Forrás](ZPR_MQ_PROXY.abap) |
| ZPR_MQ_DISPLAY | PROG/I | [Forrás](ZPR_MQ_DISPLAY.abap) |
| ZPR_MQ_TESTS | PROG/I | [Forrás](ZPR_MQ_TESTS.abap) |
| ZPR_STOCK_REPORT_O01 | PROG/I | [Forrás](ZPR_STOCK_REPORT_O01.abap) |
| ZPR_STOCK_REPORT_I01 | PROG/I | [Forrás](ZPR_STOCK_REPORT_I01.abap) |
| ZPR_DOC_RIP_O01 | PROG/I | [Forrás](ZPR_DOC_RIP_O01.abap) |
| ZPR_DOC_RIP_I01 | PROG/I | [Forrás](ZPR_DOC_RIP_I01.abap) |
| ZPRT_DCQMLT | TABL/DT | [Forrás](ZPRT_DCQMLT.table) |
| ZPRT_DCQM | TABL/DT | [Forrás](ZPRT_DCQM.table) |
| ZPRT_EMAIL_SLOG | TABL/DT | [Forrás](ZPRT_EMAIL_SLOG.table) |
| ZPRC_DCCODE | TABL/DT | [Forrás](ZPRC_DCCODE.table) |
| ZPRS_DCQM_REPORT | TABL/DS | [Forrás](ZPRS_DCQM_REPORT.structure) |

## Lényeges megállapítások és határok

- A friss ZPR_CREATE_STOCK helyes deklarációja `REPORT zpr_create_stock`; a korábbi helyi fájlnév/programnév eltérése ebben a mentésben nem áll fenn.
- A ZCL_PR_LOG aktív szignatúrájában elérhető az opcionális `IV_EXT_ID` konstruktorparaméter; a korábbi helyi ellenőrzéskor ez az osztályforrás még hiányzott.
- A korábbi naplózási állapotjelentés történeti forrásból készült. A friss CREATE_STOCK XML-feltöltési blokkja kommentelt; a jelentés részleges teljesítésre vonatkozó állításait a mai forrás alapján külön újra kell értékelni. Ebben a körben csak export és helyi ellenőrzés történt.
- A metaadatokban szereplő DHC masterSystem az objektum eredeti rendszerét jelöli; a kapcsolt SID/mandant nem kapott külön rendszerazonosító ellenőrzést.
- A csomag nem teljes cockpit-, UI- vagy függőségmentés. Dynpro, GUI-státusz, szövegkészlet, üzenetosztály, index és zárobjektum nincs külön exportálva.
- SAP-írás, aktiválás, fordítás, ATC és futtatott teszt nem történt. A 25 mentett objektum állapota a lekérés időpontjában igazolt; a teljes tervezett kör hiányos.
