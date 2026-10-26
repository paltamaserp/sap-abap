# ZPR_DOC_RIP – DHC nyomdai ellenőrző riport

Státusz: **WIP**. A QU5 `ZEBF_PR_DOC_RIP` DHC-változata, kizárólag helyi fájlokban. SAP-objektum létrehozása/módosítása, aktiválás, riportfuttatás és Inspire-hívás nem történt.

## Másolandó források

| Fájl | SAP-beli szerep |
|---|---|
| `ZPR_DOC_RIP.abap` | Végrehajtható riport |
| `ZPR_DOC_RIP_DATA.abap` | Szelekció és PR/IN összesítés; include |
| `ZPR_DOC_RIP_PROXY.abap` | Típusos Inspire-lekérdezés; include |
| `ZPR_DOC_RIP_DISPLAY.abap` | ALV, részletek és vezérlőfelszabadítás; include |
| `ZPR_DOC_RIP_O01.abap` | 0100 PBO; include |
| `ZPR_DOC_RIP_I01.abap` | 0100 PAI; include |
| `test/ZPR_DOC_RIP_TESTS.abap` | Hat tiszta ABAP Unit-teszt; include |
| `ZPR_DOC_RIP_0100_flow.abap` | SE51-be másolandó flow logic; nem programinclude |

A meglévő projekt csomagfelosztása szerint a riport és include-jai jelölt csomagja `ZPR_FUNC`; transzport nincs kiválasztva. Új DDIC- vagy proxyobjektumot ez a forráscsomag nem igényel: az ALV-típusok lokálisak, a függőségek már létező objektumok.

## Igazolt adatleképezés

A 2026-10-15-i sikeres, kizárólag olvasó MCP-hívások aktív definíciói: `../../01_SOURCES/DHC/2026-10-15_doc-rip/`. A proxyosztály aktív forrása és ADT-metaadata a szülő `DHC/` mappában található. A metaadat eredeti rendszere `DHC`; a kapcsolt rendszer SID-jét külön nem kérdeztük le, a célrendszert a felhasználó adta meg.

| QU5 | DHC |
|---|---|
| `ZEBFT_PR_STOCK` | `ZPRT_STOCK` |
| `MSSFILE → FILENAME → DCQM` stockkapcsolat | `ZPRT_DCQM-PRD_STOCK_ID = ZPRT_STOCK-STOCK_ID` |
| `ZEBFT_PR_DCQM-EXBILLDOCNO` | `ZPRT_DCQM-DOC_NO` |
| `ZEBFT_PR_DCQM-DESTINATION` | `ZPRT_DOC_LOG-CHANNEL`, kapcsolás `DOC_LOG-DOC_NO = DCQM-DOC_NO` |
| QU5 nyomdai consumer | `ZPR_CO_EON_FORMS_QUERY_PRINTHO` |
| Metódus | `EON_FORMS_QUERY_PRINTHOUSE_OUT` |
| Request | `ZPR_EON_FORMS_QUERY_PRINTHOUS3` |
| Request stocklista | `STOCKS-STOCK_ID`, `ZPR_STRING_TAB` |
| Response | `ZPR_EON_FORMS_QUERY_PRINTHOUS2` |
| Fájlrészlet | `ZPR_EON_FORMS_QUERY_PRINTHOUS1` |

Az aktív `ZPRT_DOC_LOG` kulcsa `MANDT + GUID`; a `DOC_NO` és a `ZPRS_CONTROL_DATA-CHANNEL` tényleges mezők. Az Excel-terv `EXBILLDOCNO`/`DESTINATION` nevei ezen a ponton eltérnek az aktív SAP-tól, ezért a kód az aktív neveket használja. A csatorna-customizing olvasott sorai között `PR` és `IN` egyaránt `PRINTING_TYPE = P` értékű. A `GetTableContents` válasz `total_rows = 0` mezője mellett ténylegesen 12 sor szerepelt a `rows` tömbben; a megállapítás a sorokból származik.

A DHC stockképző már közvetlen dokumentum–stock kapcsolatot használ. A QU5 külön fájlregisztráció-megléti szűrése ezért nem része a DHC-szelekciónak; a régi és új teljes dokumentumhalmaz azonossága futó adatokkal még nem igazolt.

## Működés és megőrzött szabályok

- Stock- és engedélyezésidátum-szelekció, PR/IN irányonként egy összesítő sor.
- Egyedi dokumentumok és borítékok száma; DC **vagy** QM kizárás esetén egy dokumentum egyszer számít kizártnak. A `COUNTER` mező nem szorzó.
- Azonos dokumentum/irány/boríték/kizárás többszörös technikai sora nem növeli a darabszámot. Az ugyanahhoz a dokumentumhoz tartozó eltérő stock-, csatorna-, boríték- vagy kizárásadat hibát ad; nincs önkényes „legutóbbi GUID” választás. Hiányzó dokumentumazonosító vagy csatorna szintén hibát ad.
- A QU5-höz hasonlóan az üres borítékazonosító is egy külön érték. Részlegesen kizárt borítéknál a képlet a régi szabályt követi: az összes és a kizárt borítékok külön egyedi halmazok.
- Az Inspire dokumentum-, boríték-, lap-, oldal- és négy marketingdarabszáma összegezve jelenik meg.
- `DIFF_DOC = SAP_DOC_NO − EXCL_DOC_NO − INSP_DOC_NO`; a borítékeltérés ugyanígy számolódik. Negatív érték megengedett és látható.
- `STATUS = OK`, ha legalább egy fájlnál `STATUS_OK = X`, különben `NOK`. Ez az Inspire fájlstátusza: az eltérésmentességet a két eltérésoszlop mutatja.
- Részletes lista a kijelölt sorokra, illetve dupla kattintással; külön ALV-elrendezés a fő- és részletlistához.

A QU5-höz képest javítva: a `SO_ERDAT` ténylegesen `ERDAT_CLO` szerint szűr; a legutóbbi küldési időbélyeg stockonként és irányonként újrakezdődik; csak az Inspire-oldalon létező PR/IN eredmény is látszik, SAP-oldali 0 és negatív eltérés mellett. Nincs adatbázis- vagy alkalmazásnapló-mentés, zárolás vagy saját commit.

## Proxy és logikai port

A `P_LPORT` mező kötelező, alapérték nélkül. A nyomdai lekérdező consumerhez karbantartott SOAMANAGER-port nevét kell megadni. A Messenger QMS-portjai és a stockfeltöltő portja nem igazolt megfelelői ennek a consumernek, ezért nem kerültek alapértékbe. A nyomdai port konfigurációját és végpontját ebben a munkában nem olvastuk vissza.

A request a futó rendszer `SY-SYSID`/`SY-MANDT` értékét és a kiválasztott stockokat tartalmazza. A proxy aktív metódusa csak `CX_AI_SYSTEM_FAULT` kivételt deklarál; az adapter ezt kezeli a létrehozás és a lekérdezés körül. `SUCCESS <> X` és hibás válasz esetén nincs részleges összehasonlítás. A visszaadott rendszer/mandant, stock, időbélyeg és nemnegatív darabszám ellenőrzött. A 14 számjegyes időbélyeg változatlanul jelenik meg; a naptári ellenőrzés UTC szerint történik, megjelenítési időzóna-konverzió nincs.

## Kézi beillesztés DHC-ban

1. SE38/ADT: a főprogram és a hat include felvétele a fájlok teljes tartalmával. A Unit-include-t a főprogram már hivatkozza.
2. SE51: `ZPR_DOC_RIP`, `0100`, normál képernyő, következő képernyő `0100`; vízszintesen és függőlegesen méretezhető `ALV_CONTAINER_01` custom control. Az OK típusú mező neve pontosan `GV_OKCODE_0100` legyen. A flow logic a mellékelt fájlból másolható.
3. SE41: `STAT_0100`, `BACK`, `EXIT`, `CANCEL` funkciókódok **E** funkciótípussal. `TITLE_0100_DISP` címsor: „Nyomdai ellenőrző riport”. A Részletes lista gombot az ALV hozza létre.
4. Szövegelemek: `001 = Stock kiválasztása`, `002 = Inspire és elrendezés`. Szelekciós szövegek: `SO_STOCK = Stock azonosító`, `SO_ERDAT = Engedélyezés dátuma`, `P_LPORT = Nyomdai lekérdezés logikai portja`, `P_VARI = ALV-elrendezés`.
5. Közös szintaxisellenőrzés/aktiválás, ATC, majd a riport ABAP Unit-tesztjei. A stockmező az adatelemhez rendelt meglévő értéksegítséget örökli; külön, igazolatlan stockkeresési segítség nincs a forrásban.
6. Funkcionális próba kijelölt tesztporttal: PR és IN, több fájl, kizárások, eltérő darabszám, hiányzó Inspire-fájl, csak Inspire-oldali adat, proxyhiba, elrendezés mentése, több kijelölt sor és visszalépés. A valódi Inspire-lekérdezést a helyi ellenőrzések nem indították el.

## Ellenőrzés és korlátok

A helyi ellenőrzés jegyzőkönyve: `../../02_NOTES/2026-10-15_doc-rip-helyi-ellenorzes_WIP.json`. Az **@abaplint/core 2.120.60, ABAP 7.54 parser hibát nem talált** az include-okkal kibontott forrásban. Emellett a rutinok feloldása, a 24 ALV-mező, az aktív exportokhoz tartozó tábla-/proxymezőnevek, a QU5-függőségek hiánya és az adatbázisírás hiánya is ellenőrzött. A hat Unit-teszt forrása a dokumentum-/borítékszámlálást, csatorna- és időbélyeg-elhatárolást, vegyes fájlstátuszt, csak Inspire-oldali és csak SAP-oldali adatot fedi le; **futtatásuk nem történt meg**.

SAP-fordítás, típusellenőrzés, ATC, GUI-próba és végpontteszt nem történt. A `CheckProgram` eszköz meglévő SAP-programot ellenőriz, hipotetikus helyi forrást nem fogad; SAP-objektum létrehozására nem volt felhatalmazás.

Az első repository-keresést az automatikus jóváhagyási ellenőrzés elutasította a korábbi kapcsolati leállásra hivatkozva; ez nem SAP-válasz és nem új HTTP 401. A felhasználó kifejezett új engedélye után a keresés és a proxyolvasás sikerült. Egy DDIC SQL-metaadat-lekérdezés HTTP 400 hibája után ismét leálltunk; a felhasználó újabb kifejezett engedélyével a közvetlen struktúra-/táblaolvasások és a csatorna-customizing lekérése sikeres volt. Azóta új sikertelen SAP-hívás nem történt. MCP-vel kizárólag olvasás történt.
