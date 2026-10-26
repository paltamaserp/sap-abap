# ZPR_DOC_STATUS – a 2026-10-22-i export követelményellenőrzése

> Történeti elemzés a 2026-10-22-i forrásról. A munkabázis 2026-10-26-tól a [mai MCP-export](../05_FINAL/abap-2026-10-26/README.md); az alábbi megállapítások nem kerültek újra tartalmilag ellenőrzésre.

Státusz: **WIP**. Dátum: 2026-10-22. Kizárólag helyi ellenőrzés; ABAP-módosítás és új SAP-hívás nélkül.

## Eredmény

**A D → AD alaplogika már szerepel a friss exportban, de a teljes kérés még nem igazolható teljesítettnek.** Hiányzik a D nélküli dokumentumok egységes, azonosítós és aktuális státuszos kimutatása. A tárolt hibakóddal rendelkező, D nélküli dokumentumokat a riport nem kérdezi újra. Az automatikus job, az aktív AD doménérték és a szövegkészlet nincs benne az exportált bizonyítékokban.

A felhasználói leírás eleje D dokumentumeseményt kér, b) pontja DM-et említ. A jelenlegi implementáció **D dokumentumesemény → AD stockstátusz** szerint működik; DM a megadott értéklista szerint stockszintű jóváhagyás. Ha b) szó szerint DM dokumentumstátuszt kíván, a kód ezt nem valósítja meg. A felülvizsgálat ezt az eltérést jelzi, nem módosítja a feltételt.

## Ellenőrzött alap

- Forrás: `../05_FINAL/abap-2026-10-22/ZPR_DOC_STATUS.abap`.
- MCP-mentés időpontja: **2026-10-22 17:06:21.921, Europe/Budapest** (`2026-10-22T15:06:21.921Z`).
- SHA256: `24aab1c6fd440818776c43a4e40267e4765af8efeaf4ec685d2bcef91dc13131`.
- A forrás hash-e egyezik az új exportmanifesztével; a nyers MCP-válasz hash-e is egyezik, és annak aktív `source_code` tartalma azonos a vizsgált fájllal a soremelések normalizálása után.
- Az export forrásokat és definíciókat tartalmaz, **nem üzleti táblasorokat**. Emiatt nem állapítható meg belőle, hogy a tényleges összes EXBILLDOCNO megkapta-e már a D-t. Azt ellenőriztük, hogyan vizsgálja ezt a program.

## Követelmények és forráshelyek

Minden sorszám a fenti friss ZPR_DOC_STATUS forrásra vonatkozik.

| Követelmény | Minősítés | Bizonyíték / korlát |
|---|---|---|
| A STOCK szűrés nem kötelező | Megfelel normál futásban | 65–71: nincs OBLIGATORY. 102–104: `P_STAT = X` esetén viszont kötelező stockot megadni. |
| STOCK → PACKAGE → DCQM kapcsolat | Megfelel | 302–311, 410–429: `ZPRT_PACKAGE-STOCK_ID`, közös `PACKAGE_ID`, `ZPRT_DCQM-DOC_NO`. A kérésben szereplő `ZRPT_DCQM` helyett a tényleges objektum `ZPRT_DCQM`. |
| EXBILLDOCNO ↔ DOC_NO | Megfelel | 427–429: `ZPRT_DOC_SLOG-EXBILLDOCNO = ZPRT_DCQM-DOC_NO`, és `STATUS = 'D'`. |
| A riport írja a dokumentumstátusz-naplót | Megfelel | 605–619: az új események beszúrása a `ZPRT_DOC_SLOG` táblába, EXBILLDOCNO, időbélyeg és státusz megadásával. |
| A stock csak minden dokumentum D-je után legyen AD | Megfelel a D értelmezésnek | 403–456: teljes package–dokumentum halmaz; üres halmazból nincs AD; hiányzó SLOG-sor is hiányzó D. Célzott `STATUS = AD` és CH* mentés csak aktuálisan CL és CLOSED=X stockra. Egy korábban kapott D elegendő, nem a legutolsó eseménynek kell D-nek lennie. |
| Az összesítés a SLOG-írás után fusson | Megfelel | 395–399: a dokumentumfeldolgozási ciklus után; 514–524: a dokumentum mentése commitol. 337–341: új lekérés nélkül, korábban mentett eseményekből is összesít. A stockzár a hívásokat körülveszi (248–274). |
| D hiányában legyen státuszjelzés | Részleges | 430–436: CL marad és W szintű, hiányzó/összes darabszámos napló keletkezik. Nincs egységes EXBILLDOCNO + aktuális státusz lista. `P_DET = X` mellett a visszakapott események státusz/időbélyeg adatai megjelennek (631–645), de ez nem fedi le az összes kimaradó/hiányzó dokumentumot. |
| Csak a D nélküli dokumentumok újralekérése | Feltételesen megfelel | 330–335, 458–476: normál módban a D-vel rendelkezők kimaradnak. `P_STAT = X` ezt felülbírálja. **A nem üres tárolt hibakód D nélkül is végállapotnak számít**, és a dokumentum P_STAT mellett sem kerül újra a kérésbe. |
| Automatikus futás | Nem igazolt | A riport háttérfutást kezel (803), de a periodikus job és a variáns nincs exportálva. A korábbi WIP README csak beállítási útmutató, nem ütemezési bizonyíték. |
| AD doménérték, új naplószövegek | A friss exportból nem igazolható | A felhasználó szerint AD felvéve; a mai csomag nem tartalmazza a `ZPRD_STOCK_STATUS` domént. A 201–206 szöveghivatkozás benne van, de a szövegkészlet nem exportált. A korábbi WIP TSV a kívánt szövegek referenciája. |

## Lényeges működési példa

Egy stockban két dokumentum van: az elsőhöz D tartozik, a másodikhoz csak nem üres tárolt hibakód. A második dokumentum az `IS_TERMINAL` miatt nem kerül újra az Inspire-kérésbe, miközben az összesítő továbbra is hiányzó D-nek számolja. Így a stock CL marad; a periodikus újrafuttatás önmagában ezt a helyzetet nem oldja fel.

Normál automatikus futásra a forrás alapján `SO_STOCK` üres és `P_STAT` üres beállítás illeszkedik. Ez minden CL jelöltet kiválaszt; a zár alatt CLOSED=X is szükséges (223–224, 294–299). Az AD stockok a következő normál kiválasztásból kimaradnak. Ezzel a felülvizsgálattal jobütemezés nem történt.

## Helyi ellenőrzés

**17 ellenőrzés sikeres**, ebből 10 szintetikus SQL-eset. A vizsgált friss forrás tényleges COUNT/NOT EXISTS/UPDATE utasításait normalizáltuk SQLite-ra, az Open SQL implicit mandantszűrését kifejezetten hozzáadva. Esetek: minden D több package-ben; hiányzó napló; más esemény; DM nem helyettesíti a D-t; üres stock; más stock és más mandant kizárása; korábbi D utáni más esemény; nem CL és nem lezárt stock védelme. A DM eset összehasonlítási próba, nem DDIC-típusellenőrzés.

A további ellenőrzések a forrásazonosságot, az opcionális stockszűrést, a P_STAT feltételét és az összesítés két bekötési pontját ellenőrizték. Részletes gépi eredmény és normalizált SQL: [ellenőrzési jegyzék](2026-10-22_doc-status-friss-export-ellenorzes_WIP.json).

Ez nem SAP-fordítás, ATC, ABAP Unit, zárolási/párhuzamossági teszt vagy tényleges adatsor-ellenőrzés. Az aktív SAP-állapotot ebben a körben nem ellenőriztük. A korábbi kapcsolati leállás érvényes; új SAP-kísérlet és automatikus jóváhagyási elutasítás sem történt.
