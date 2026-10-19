# Aktív ABAP- és DDIC-export – 2026-10-17

Státusz: **WIP**. A felhasználó kérésére, SAP ADT MCP-ből frissen letöltött pillanatkép. Az objektumkör pontosan a [2026-10-16-i export](<../../../../[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/project/05_FINAL/abap-2026-10-16/README.md>) 24 objektuma. A tegnapi csomag és a helyi fejlesztési WIP-források változatlanok.

**24 objektum, 34 fájl:** 7 főprogram, 9 include, 1 osztály, 4 tábla, 1 struktúra, 2 táblatípus; 8 külön ADT-metaadat XML, README és [SHA256-manifeszt](2026-10-17_export-manifest_WIP.json). A főprogramok/osztály/táblák/struktúra explicit active verzióból olvasva, a táblatípusok metaadata active; az include-ok GetInclude alapértelmezéssel.

Minden mentés karakterpontosan visszaolvasva; az összes mentett forrás és metaadat SHA256-értéke újraszámolva. Mindegyik MCP-olvasás sikeres. A letöltési időablakot a manifeszt UTC-ben tartalmazza; ez egymás utáni olvasások eredménye. A masterSystem az eredeti rendszert jelzi; a kapcsolt SID nincs külön ellenőrizve.

## Objektumok

| Objektum | Típus | Export |
|---|---|---|
| ZPR_DCQM_EXCLUDE_O01 | PROG/I | [Forrás](ZPR_DCQM_EXCLUDE_O01.abap) |
| ZPR_DCQM_EXCLUDE | PROG/P | [Forrás](ZPR_DCQM_EXCLUDE.abap) |
| ZPR_DC_FRAME | PROG/P | [Forrás](ZPR_DC_FRAME.abap) |
| ZPR_MESSAGEQUEUE_QUERY | PROG/P | [Forrás](ZPR_MESSAGEQUEUE_QUERY.abap) |
| ZPR_CLOSE_STOCK | PROG/P | [Forrás](ZPR_CLOSE_STOCK.abap) |
| ZPR_CREATE_STOCK | PROG/P | [Forrás](ZPR_CREATE_STOCK.abap) |
| ZPR_DOC_RIP | PROG/P | [Forrás](ZPR_DOC_RIP.abap) |
| ZPR_DOC_STATUS | PROG/P | [Forrás](ZPR_DOC_STATUS.abap) |
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
| ZPRB_EMAIL_SLOG | TTYP/DA | [Forrás](ZPRB_EMAIL_SLOG.ttyp.json) |
| ZPRB_SLOG_EMAIL | TTYP/DA | [Forrás](ZPRB_SLOG_EMAIL.ttyp.json) |

## Eltérések és exporthatárok

A tegnapi mentéshez képest öt objektum forrása változott: `ZPR_DCQM_EXCLUDE`, `ZPR_DC_FRAME`, `ZPR_CREATE_STOCK`, `ZPR_DOC_RIP`, `ZPR_DOC_STATUS`. A többi 19 forrás/definíció SHA256 szerint azonos. A metaadatok hash-ei külön szerepelnek a manifesztben.

**Hiányzó új függőség:** a mai `ZPR_DCQM_EXCLUDE` hivatkozik a `ZPR_DCQM_EXCLUDE_C01` include-ra. Ez a tegnapi 24 objektum közt nem szerepel, ezért az azonos objektumkör megtartása érdekében nem lett külön letöltve. A mai hét főprogram INCLUDE-hivatkozásainak helyi ellenőrzése ezt az egy hiányt mutatta. A csomag tehát azonos objektumkörű napi export, nem teljes függőségmentés.

A tényleges stocklezáró SAP-név `ZPR_CLOSE_STOCK`, include-jai továbbra is `ZPR_STOCK_REPORT_O01` / `ZPR_STOCK_REPORT_I01`. A cockpit függvénycsoport/include-jai a tegnapi listában sem szerepelnek.

Dynpro-layout és flow logic, GUI-státuszok, textelemek, üzenetosztály-szövegek, keresési segítségek és indexdefiníciók külön exportja nincs a csomagban. SAP-írás, aktiválás, fordítás, QA/ATC és tesztfuttatás nem történt; a csomag helye nem jelent FINAL státuszt.
