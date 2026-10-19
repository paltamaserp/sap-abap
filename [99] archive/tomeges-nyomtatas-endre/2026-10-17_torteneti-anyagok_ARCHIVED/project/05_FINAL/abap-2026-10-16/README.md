# Aktív ABAP- és DDIC-export – 2026-10-16

Státusz: **WIP**. A felhasználó kérésére a módosított projektobjektumok és kapcsolódó DDIC-definícióik az SAP ADT MCP-ből, változtatás nélkül kerültek ide. A könyvtár neve nem jelent véglegesítést vagy sikeres SAP-tesztet.

**24 objektum:** 7 főprogram, 9 include, 1 osztály, 4 tábla, 1 struktúra és 2 táblatípus. A hét főprogram összes hivatkozott include-ja mentve. A főprogramok/osztály eredeti ADT-metaadata külön .metadata.xml fájlban szerepel.

A főprogramok, osztály, táblák és struktúra explicit aktív verzióból olvasva; a táblatípusok válaszában version=active. Az include-ok a GetInclude verzióparaméter nélküli válaszai. Minden mentés karakterpontosan ellenőrizve; a [manifeszt](2026-10-16_export-manifest_WIP.json) SHA256-értékeit külön újraszámoltuk.

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

A tényleges stocklezáró SAP-név **ZPR_CLOSE_STOCK**, korábbi helyi neve ZPR_STOCK_REPORT; az aktív include-nevek változatlanok. A helyi, külön DOC_RIP DATA/PROXY/DISPLAY/TESTS tervezetek nem szerepelnek az aktív főprogram INCLUDE utasításaiban, ezért nem másoltuk őket aktív rendszerexportként.

Az ADT-metaadatok masterSystem=DHC értéke az eredeti rendszert jelöli; a kapcsolt rendszer SID-jét külön nem ellenőriztük.

## Határok

A dynprók (layout és flow logic), GUI-státuszok, textelemek, üzenetosztály-szövegek, keresési segítségek és indexdefiníciók külön tartalma nincs exportálva. A csomag a felsorolt források pillanatképe; nem teljes rendszer-/függőségmentés. SAP-írás, aktiválás, fordítás, ATC és tesztfuttatás nem történt.

Az új olvasásokat a felhasználó kifejezett egyszeri újrapróbálási engedélye indította újra. Az első GetInclude és minden ezt követő olvasás sikeres; új kapcsolati hiba vagy jóváhagyási elutasítás nem volt.
