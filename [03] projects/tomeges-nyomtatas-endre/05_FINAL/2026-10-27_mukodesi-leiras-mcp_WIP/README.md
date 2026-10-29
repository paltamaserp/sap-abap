# Tömeges nyomtatás működési és technikai leírása

Státusz: **WIP** · Dátum: **2026-10-27**.

[Word-dokumentum](2026-10-27_tomeges-nyomtatas-mukodesi-technikai-leiras_WIP.docx): 19 fejezet, 16 táblázat, kattintható tartalomjegyzék. Témák: stockképzés, mintavétel, DC, QM, végső engedélyezés, cockpit, dokumentum- és Messenger-státuszok, nyomdai ellenőrzés, adatmodell, integráció, zárolás, naplózás, beállítások, üzemeltetés és ellenőrzési terv.

Forrás: a 2026-10-26-i elsődleges mentés és a [nyolc új MCP-objektum](../../01_SOURCES/2026-10-27_mukodesi-leiras-mcp_WIP/README.md). A `leiras.md` a szerkeszthető szöveg, a `build_doc.py` a dokumentumépítő, a `verify_doc.py` a szerkezeti és forráshash-ellenőrző. A `2026-10-27_felhasznalt-forrasok_WIP.json` a helyi források hash-jegyzéke.

## Ellenőrzés és határok

- A DOCX ZIP/OOXML szerkezete, mind a 19 tartalomjegyzék-hivatkozás, a forrásjelek és a hivatkozott forrásfájlok ellenőrizve. Nyolc új nyers MCP-válasz és nyolc kinyert forrás hash-e egyezik.
- A csomagolt `render_docx.py` natív futása hiányzó LibreOffice miatt nem tudott PDF-et készíteni. A környezet Windows-runtime-ja nem tartalmaz LibreOffice-t; felhasználói LibreOffice nem került használatba.
- A kizárólag ehhez a dokumentumhoz indított rejtett Word COM-export elakadt. A Computer Use alkalmazásindítási engedélye időtúllépéssel zárult. Ez nem automatikus jóváhagyási elutasítás és nem SAP-hiba. A saját Word-/renderelő folyamatokat leállítottuk; meglévő felhasználói dokumentumot nem módosítottunk.
- A `render_fallback.py` a tényleges DOCX támogatott OOXML-elemeiből helyi előnézeti PDF-et készít, majd a csomagolt renderelő PNG-folyamatát használja. A 22 előnézeti oldalt vizuálisan átnéztük; a javított interfésztáblát újrarendereltük és ellenőriztük.
- Ez a helyi előnézet **nem igazolja a Microsoft Word saját oldaltördelését**. A natív Word-vizuális ellenőrzés nyitott maradt; emiatt nincs REVIEW vagy FINAL státuszváltás. Az előnézeti PDF és PNG-k a `qa/` könyvtárban munkaközi ellenőrző anyagok.

SAP-módosítás, fordítás, aktiválás vagy futtatott üzleti teszt nem történt. A leírás a dátumozott forrásállapotot elemzi; a teljes aktív projektforrást nem olvastuk újra.
