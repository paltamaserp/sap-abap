# ZPR_DOC_STATUS – automatikus CL → AD

Státusz: **WIP**, 2026-10-22. Kizárólag a riport új munkamásolata; az eredeti export és a ZCL_PR_STOCK változatlan.

## Alap és fájlok

Alap: `../../05_FINAL/abap-2026-10-17/ZPR_DOC_STATUS.abap`.
SHA256: `b3b55a72a772a4fd3a65567f29e5c82006ed37df86156bbcbd5d2a486afd5b06`.

- `ZPR_DOC_STATUS.abap`: a teljes módosított riport, változatlan SAP-objektumnévvel.
- `2026-10-22_doc-status-all-delivered_WIP.diff`: kizárólag az alaphoz tartozó forrásdiff. A patch célneve `ZPR_DOC_STATUS.abap`, ezért az alapot tartalmazó mappából alkalmazható. A teljes új forrás bemásolása és a patch két alternatív átvezetési mód; ugyanarra a már módosított forrásra ne alkalmazzuk ismét a diffet.
- `2026-10-22_doc-status-textelemek_WIP.tsv`: az új 201–206 szövegszimbólumok.
- `check.mjs`, `validation.json`: helyi ellenőrzés és eredménye.
- `manifest.json`: az alap és a csomag fájljainak SHA256-jegyzéke.

## Működés

1. A `SO_STOCK` nem kötelező. Üres szűrésnél minden `STATUS = CL` stock jelölt, kitöltött szűrésnél csak a megadottak. A meglevő `P_STAT = X` + üres stockszűrés tiltása megmarad; a kényszerített ismétléshez továbbra is meg kell adni a stockot.
2. A meglevő stockzár alatt újraolvasott rekordnak továbbra is `CLOSED = X` értékkel kell rendelkeznie; most a `STATUS = CL` értéket is ellenőrizzük. Más státuszú vagy nem lezárt stock nem dolgozható fel.
3. A meglevő dokumentumfeldolgozás és dokumentumonkénti commit változatlan. Utána az új `UPDATE_STOCK_DELIVERY` rutin a frissen tárolt adatokat összesíti. Ugyanez az ellenőrzés lefut akkor is, amikor a tárolt végállapotok miatt már nincs újra lekérendő dokumentum.
4. A teljes halmaz: `ZPRT_PACKAGE-STOCK_ID → PACKAGE_ID → ZPRT_DCQM-PACKAGE_ID → DOC_NO`. Az egyedi dokumentumok összeszámlálása és a D nélküli dokumentumok számlálása e kapcsolaton történik. A hiányzó SLOG-sor is hiánynak számít; más dokumentum vagy más stock D-je nem helyettesíti. Az Open SQL implicit mandantkezelése megmarad.
5. Legalább egy dokumentum és nulla hiányzó D esetén `STATUS = AD`; a `CHUSER/CHDATE/CHTIME` frissül. A célzott UPDATE feltétele a stockazonosító, az aktuális `CL` és a `CLOSED = X`. A CR*, CLOSED, prioritás és lezárási adatok nem változnak. A rutin még a meglévő stockzár feloldása előtt commitol, és ellenőrzi a mentési eredményt.
6. Üres halmazból nincs AD. Hiányzó D esetén a stock CL marad, és a napló kiírja a hiányzó D-k számát és az összes dokumentumszámot. A már AD stockok a következő normál futás kiválasztásából kimaradnak.

A kézbesítési feltétel az eredeti feladat szerint a **D dokumentumesemény**, a stock célállapota **AD**. A DM jelentése nem változik. Egy korábbi D elegendő; a rutin nem a legutolsó esemény státuszát vizsgálja.

Az eredeti „stock összes dokumentuma” feltételt megtartottuk: új DC/QM-kizárási szűrés nem került be. A stockhoz package-en keresztül kapcsolódó blokkolt dokumentumhoz is kell D. Ha a tényleges üzleti igény kizárólag az átadott, nem blokkolt dokumentumokra vonatkozik, az külön követelménypontosítás és mindkét dokumentumhalmaz összehangolt módosítása.

## SAP-átvezetés és automatikus futás

1. Az aktív riportot össze kell vetni a megadott alappal, majd a forrást vagy a diffet átvezetni. Ez a csomag nem tartalmaz SAP-írást vagy aktiválást.
2. A felhasználó által már felvett `ZPRD_STOCK_STATUS = AD` értéknek a célrendszerben aktívnak kell lennie. Ezt a helyi régi doménmentés nem igazolja.
3. SE38/ADT alatt a riport szövegszimbólumaihoz karban kell tartani a TSV 201–206 elemeit, és a forrással együtt transzportálni. Az alap 001 és 101–104 elemei megmaradnak. Az új szövegazonosítók foglaltsága a célrendszerben ellenőrizendő; a `.abap` másolása önmagában nem hozza létre a szövegeket.
4. SAP-fordítás, QA/ATC és célzott próba szükséges. Próba: üres stock; részleges D; minden D; korábbról minden D; több package; hibás dokumentum D nélkül; mentési hiba; másik folyamat által megváltoztatott stock.
5. Automatikus futáshoz SM36-ban periodikus háttérjob és riportvariáns szükséges. Példavariáns: `SO_STOCK` üres, `P_STAT` üres, `P_DET` igény szerint. A periódus az üzemeltetési igényhez igazítható, például 10 perc. A futtató felhasználó meglévő riport-/napló-/proxyjogosultságai szükségesek; a riport `S_TCODE = ZPR_DOC_STATUS` ellenőrzése megmaradt.
6. A napló SLG1-ben a meglévő `ZPR_MASS` / `DOC` objektum-alobjektum alatt kereshető. Hibakódos dokumentumot a korábbi `IS_TERMINAL` továbbra sem kérdez újra automatikusan; D nélkül a stock CL marad. A meglévő proxy-inicializálás és kapcsolati hibakezelés változatlan.

A háttérjob nincs létrehozva vagy ütemezve e helyi csomag készítésekor. A cockpit AD-felirata és a közös státuszváltási szabályok külön feladat; a ZCL_PR_STOCK nem része ennek a módosításnak.

## Ellenőrzés és határok

25 helyi ellenőrzés sikeres. A teszt a jelölt forrás tényleges két új SELECT-jét és védett UPDATE-jét normalizálja és SQLite relációs tesztadatokon futtatja; az implicit SAP-mandantkezelést külön modellezi. Vizsgálja többek között a teljesen hiányzó naplót, több package-et, többszörös és történeti D-eseményt, idegen stockot/mandantot, a státusz-/CLOSED-védelmet, az auditmezők megőrzését és a rollbackelt dokumentummentést. A vezérlési bekötést külön forrásellenőrzés vizsgálja. A diff előre és vissza alkalmazása bájtpontos; az alap hash-e változatlan.

Futtatás SQLite-ot támogató Node.js környezetben: `node check.mjs`.

Nincs helyi ABAP-parser, SAP-fordítás/típusellenőrzés, ATC, SAP-ban futtatott ABAP Unit, proxy-, zárolási vagy update-task próba. A meglevő SLOG-beszúrás, archív-, ragszám-, hibakezelési, parser- és proxykód változatlan. A korábban leállított SAP-kapcsolatot nem használtuk; az aktív SAP-állapot és a package DDIC/indexek nincsenek újraellenőrizve. A stockzár az azt tiszteletben tartó párhuzamos programokkal hangolja össze a feldolgozást.
