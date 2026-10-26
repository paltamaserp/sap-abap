# MCP-forrásmentés – 2026-10-26

Státusz: **WIP**. **Elsődleges munkabázis a felhasználó 2026-10-26-i döntése szerint.** A további elemzések és javítások ebből a dátumozott mentésből indulnak; új változtatás külön munkamásolatba kerül.

**39/39 kijelölt objektum mentve**, a SAP ADT MCP eszközeivel. A 28 korábbi objektum mellett a cockpit, ZPR_QM és a mintaképzés további forrásai is bekerültek. A korábban hiányzó C01 és mindkét táblatípus most elérhető volt.

Összetétel: 8 főprogram, 14 include, 6 osztály, 3 interfész, 1 függvénymodul, 4 tábla, 1 struktúra és 2 táblatípus.

[Objektumjegyzék, lekérési időpontok és SHA256](2026-10-26_export-manifest_WIP.json) · [Draftok szöveges összevetése](2026-10-26_draft-osszevetes_WIP.json) · [Projektállapot](../../_LOG.md).

## Ellenőrzés

- 90 nyers válasz-/forrás-/metaadatfájl mérete és SHA256-értéke egyezik a visszaolvasáskor.
- A kinyert forrás/definíció minden objektumnál megegyezik a mentett MCP-válasszal.
- A mentett forrásokban hivatkozott helyi Z/LZPR include-ok mind szerepelnek.
- A 2026-10-22-i csomaghoz képest 11 meglévő forrás/definíció eltér, 14 azonos; 14 objektum új ebben a mentési körben.
- A programok, osztályok, interfészek, függvénymodulok, táblák és struktúra explicit active kéréssel érkeztek. Az include-ok a GetInclude alapértelmezett verzióját használják. A két táblatípus metaadata active.
- A mentés során SAP-írás, aktiválás, fordítás, ATC és üzleti futtatás nem történt.

## A draftok szerepe

A régi draftok összehasonlítási referenciák. Nem a mai munkabázis részei, és a korábbi patchek nem alkalmazhatók automatikusan az új exportra. A bennük talált eltérés önmagában nem bizonyít hiányzó követelményt.

A 18 ABAP draft közül 3 a sorvégek és a fájlvégi whitespace figyelmen kívül hagyásával egyezik, 9 eltér a mai azonos nevű exporttól, 6 külön nevű javaslat/korábbi mentés vagy nem exportált flow logic. Ezeket nem tekintjük új feladatnak vagy jóváhagyott módosításnak.

## Határok

A 39 objektumos kijelölt forráskör teljes; a csomag nem teljes rendszer- vagy függőségmentés. Dynpro-layout/flow logic, GUI-státusz, szövegkészlet, üzenetosztály, zárobjektum és minden DDIC/proxyfüggőség külön mentése nem része ennek az exportnak. A régi UI-/szövegkiegészítők ezért továbbra is referenciák. A metaadat DHC masterSystem értéke eredeti rendszert jelöl, nem a kapcsolt SID/mandant külön ellenőrzése.

Egy nagy helyi mentési hívást az automatikus jóváhagyási ellenőrzés 64 KB-os korlát miatt elutasított. A már megkapott válasz kisebb helyi részekben mentve lett, új SAP-lekérés nélkül. SAP-elérési hiba ebben a körben nem történt.

## Objektumok

| Objektum | Típus | Mentés |
|---|---|---|
| ZPR_CREATE_STOCK | PROG/P | [Forrás/definíció](ZPR_CREATE_STOCK.abap) |
| ZPR_CLOSE_STOCK | PROG/P | [Forrás/definíció](ZPR_CLOSE_STOCK.abap) |
| ZPR_DC_FRAME | PROG/P | [Forrás/definíció](ZPR_DC_FRAME.abap) |
| ZPR_DOC_STATUS | PROG/P | [Forrás/definíció](ZPR_DOC_STATUS.abap) |
| ZCL_PR_STOCK | CLAS/OC | [Forrás/definíció](ZCL_PR_STOCK.abap) |
| ZCL_PR_LOG | CLAS/OC | [Forrás/definíció](ZCL_PR_LOG.abap) |
| ZCL_PR_INSPIRE_GW | CLAS/OC | [Forrás/definíció](ZCL_PR_INSPIRE_GW.abap) |
| ZPR_DCQM_EXCLUDE_O01 | PROG/I | [Forrás/definíció](ZPR_DCQM_EXCLUDE_O01.abap) |
| ZPR_DCQM_EXCLUDE | PROG/P | [Forrás/definíció](ZPR_DCQM_EXCLUDE.abap) |
| ZPR_MESSAGEQUEUE_QUERY | PROG/P | [Forrás/definíció](ZPR_MESSAGEQUEUE_QUERY.abap) |
| ZPR_DOC_RIP | PROG/P | [Forrás/definíció](ZPR_DOC_RIP.abap) |
| ZCL_PR_QM_SAMPLER | CLAS/OC | [Forrás/definíció](ZCL_PR_QM_SAMPLER.abap) |
| ZPR_DCQM_EXCLUDE_I01 | PROG/I | [Forrás/definíció](ZPR_DCQM_EXCLUDE_I01.abap) |
| ZPR_MQ_PROXY | PROG/I | [Forrás/definíció](ZPR_MQ_PROXY.abap) |
| ZPR_MQ_DISPLAY | PROG/I | [Forrás/definíció](ZPR_MQ_DISPLAY.abap) |
| ZPR_MQ_TESTS | PROG/I | [Forrás/definíció](ZPR_MQ_TESTS.abap) |
| ZPR_STOCK_REPORT_O01 | PROG/I | [Forrás/definíció](ZPR_STOCK_REPORT_O01.abap) |
| ZPR_STOCK_REPORT_I01 | PROG/I | [Forrás/definíció](ZPR_STOCK_REPORT_I01.abap) |
| ZPR_DOC_RIP_O01 | PROG/I | [Forrás/definíció](ZPR_DOC_RIP_O01.abap) |
| ZPR_DOC_RIP_I01 | PROG/I | [Forrás/definíció](ZPR_DOC_RIP_I01.abap) |
| ZPRT_DCQMLT | TABL/DT | [Forrás/definíció](ZPRT_DCQMLT.table) |
| ZPRT_DCQM | TABL/DT | [Forrás/definíció](ZPRT_DCQM.table) |
| ZPRT_EMAIL_SLOG | TABL/DT | [Forrás/definíció](ZPRT_EMAIL_SLOG.table) |
| ZPRC_DCCODE | TABL/DT | [Forrás/definíció](ZPRC_DCCODE.table) |
| ZPRS_DCQM_REPORT | TABL/DS | [Forrás/definíció](ZPRS_DCQM_REPORT.structure) |
| ZPR_DCQM_EXCLUDE_C01 | PROG/I | [Forrás/definíció](ZPR_DCQM_EXCLUDE_C01.abap) |
| ZPR_QM | PROG/P | [Forrás/definíció](ZPR_QM.abap) |
| LZPR_COCKPITTOP | PROG/I | [Forrás/definíció](LZPR_COCKPITTOP.abap) |
| LZPR_COCKPITO01 | PROG/I | [Forrás/definíció](LZPR_COCKPITO01.abap) |
| LZPR_COCKPITUXX | PROG/I | [Forrás/definíció](LZPR_COCKPITUXX.abap) |
| Z_PR_COCKPIT | FUNC | [Forrás/definíció](Z_PR_COCKPIT.abap) |
| ZCL_PR_QM_DATA | CLAS/OC | [Forrás/definíció](ZCL_PR_QM_DATA.abap) |
| ZCL_PR_QM_RANDOM | CLAS/OC | [Forrás/definíció](ZCL_PR_QM_RANDOM.abap) |
| ZIF_PR_QM_DATA | INTF/OI | [Forrás/definíció](ZIF_PR_QM_DATA.abap) |
| ZIF_PR_QM_RANDOM | INTF/OI | [Forrás/definíció](ZIF_PR_QM_RANDOM.abap) |
| ZIF_PR_INSPIRE_GW | INTF/OI | [Forrás/definíció](ZIF_PR_INSPIRE_GW.abap) |
| LZPR_COCKPITU01 | PROG/I | [Forrás/definíció](LZPR_COCKPITU01.abap) |
| ZPRB_EMAIL_SLOG | TTYP/DA | [Forrás/definíció](ZPRB_EMAIL_SLOG.ttyp.json) |
| ZPRB_SLOG_EMAIL | TTYP/DA | [Forrás/definíció](ZPRB_SLOG_EMAIL.ttyp.json) |
