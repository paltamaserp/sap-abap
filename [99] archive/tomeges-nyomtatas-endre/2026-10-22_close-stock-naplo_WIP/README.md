# ZPR_CLOSE_STOCK – összesítő és Inspire-eseménynapló

Dátum: 2026-10-22 · Státusz: WIP · Kizárólag a meglévő **ZPR_CLOSE_STOCK riport** helyi munkamásolata.

Kiindulás: a felhasználó által megjelölt [FINAL/ZPR_CLOSE_STOCK.abap](../../05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap), SHA256: `bb5c6e1fd26f395a981d8ab0a3ac84a93c2f12888a04cd377766119c5911339e`.

## Mit kell megnézni?

- [Teljes új riport](ZPR_CLOSE_STOCK.abap).
- [Diff az eredetihez képest](ZPR_CLOSE_STOCK_naplo_WIP.diff).
- [Új riporttextelemek](ZPR_CLOSE_STOCK.texts.tsv): 301–307, 310–316, 318–323. Ezek ugyanazon riport szövegkészletéhez tartoznak; új T100-üzenetszám nincs.
- [Ellenőrzési eredmény](validation.json). A `build-check.cjs` újra előállítja és helyileg ellenőrzi a forrást/diffet.

## Naplóadatok és értelmezésük

| Adat / esemény | Forrás / jelentés |
|---|---|
| Egyedi package-ek száma | A teljes stock ZPRT_DCQM soraiban előforduló különböző, nem kezdeti PACKAGE_ID értékek |
| Egyedi dokumentumok száma | Ugyanezen sorok különböző, nem kezdeti DOC_NO értékei |
| Nyomtatási rekordok száma | Az összes stockhoz tartozó ZPRT_DCQM rekord, duplikált DOC_NO esetén is minden fizikai rekord számít |
| Hiányzó azonosítók | Külön figyelmeztető darabszám a PACKAGE_ID vagy DOC_NO nélküli sorokra |
| Lezárási folyamat eleje/vége | A felhasználó megerősítése után kezdődik; a végén a GV_SAVED szerinti siker/sikertelenség |
| Inspire-hívás eleje | Közvetlenül a DCQMCompleted proxyhívás előtt, stockkal és logikai porttal |
| Inspire-hívás vége | Válasz, alkalmazási kivétel vagy technikai kivétel után; UTC-befejezés és másodpercben mért időtartam |
| Inspire-eredmény | Explicit siker, elutasítás, bizonytalan eredmény vagy el sem indult hívás külön eseménnyel |
| SAP-lezárási mentés eleje/vége | A sikeres Inspire-válasz utáni SAVE_RELEASE körül, külön eredménnyel |

**Döntés:** a számolás a teljes stockból történik `PRD_STOCK_ID = P_STOKID` feltétellel, a hívás előtt. A megjelenített GT_ALV csak a kizárt sorokat tartalmazza, ezért abból nem számolunk teljes stockot. A lekérdezés nem kapcsol be új táblát, így join miatti sorfelszorzás sincs. A számok naplózási pillanatképet jelentenek; a proxy stockazonosítót/prioritást/kizárt borítékokat kap, a darabszámokat nem adjuk új bemeneti paraméterként át.

**DOC_NO / EXBILLDOCNO:** a megadott riport a nyomtatási azonosítót ZPRT_DCQM-DOC_NO mezőből használja (a meglévő TY_REGMAIL-EXBILLDOCNO típusa is ez). Külön EXBILLDOCNO mező nincs a helyi DCQM-definícióban. Ezért két egyértelmű mérőszám szerepel: egyedi DOC_NO-k és DCQM-rekordok száma. Nem feltételeztünk új, egy-a-többhöz dokumentumkapcsolatot. Nem számolunk TERTI-ragszámváltozatokat vagy ismételt DOC_SLOG-státuszeseményeket nyomtatási sorként.

## Változtatási határ

A megadott alapban a gomb a RELEASE_STOCK → SEND_PRIORITY → közvetlen DCQMCompleted proxyhívás útvonalon működik. Ezt az utat naplózzuk. A korábbi, külön RELEASE_STOCK_NEW/osztályhívási WIP-patch nincs ebbe a munkamásolatba összefésülve.

A meglévő ZCL_PR_LOG, ADD_MESSAGE és LOG_WRITE rutin használata megmarad. Az eredeti ZPR_CLOSE_STOCK és minden más meglévő fájl változatlan; új fájlok kizárólag ebben a csomagmappában készültek. Osztály/include/DDIC/proxy/T100/GUI-objektum nem módosul. A kérés szűk hatóköre miatt a projekt egyéb nyilvántartásait sem írtuk át; a döntések ebben az új leírásban szerepelnek.

A meglévő payload, hibajelzők, állapot-/CH*-mentés, CR*-megőrzés, ragszámkezelés, enqueue/dequeue, képernyő és háromsoros fejléc változatlan. A darabszámnaplózás olvasási hibája W-bejegyzést ad, nem írja át a meglévő GV_ERROR/GV_SAVED/GV_UNCERTAIN jelzőket és nem állítja le az addig engedélyezett üzleti műveletet.

Az időtartam számítása CL_ABAP_TSTMP=>SUBTRACT-tal történik, hosszú UTC-időbélyegekből; nem a YYYYMMDDHHMMSS számok egyszerű kivonásával. Ennek mintája az [SAP időbélyeg-dokumentáció](https://help.sap.com/doc/abapdocu_751_index_htm/7.51/de-DE/abentime_stamp_oview.htm). Az időtartam 3 tizedes másodpercre formázott; az időbélyeg formátuma ISO és UTC-jelölést kap.

## Átvezetés és korlátok

1. A diffet a fent azonosított alaphoz hasonlítsd; a teljes új forrás ugyanannak a ZPR_CLOSE_STOCK objektumnak a munkamásolata, a REPORT-neve változatlan.
2. A TSV szerinti 20 szövegszimbólumot a **ZPR_CLOSE_STOCK saját szövegkészletében** kell felvenni/ellenőrizni, a megfelelő nyelveken. Ha valamelyik azonosító a cél aktív szövegkészletében foglalt, a meglévőt ne írd felül; a kóddal együtt szabad számra kell igazítani. A `.abap` vagy a `.diff` önmagában a szövegkészletet nem hozza létre.
3. A célban SAP-szintaxisellenőrzés, ATC/SCI és elkülönített stockkal GUI-próba szükséges. Próbák: siker, SUCCESS=false, alkalmazási kivétel, technikai kivétel/timeout, hiányzó port; továbbá ismétlődő/hiányzó package-/dokumentumazonosító és több DCQM-rekord ugyanazzal a DOC_NO-val.

**Nincs új COMMIT vagy ROLLBACK.** Az események a GT_MESSAGES táblában gyűlnek, és a meglévő, művelet végi LOG_WRITE menti őket. A kezdési időbélyeg a tényleges kezdet ideje, de a kezdési bejegyzés nem válik azonnal tartóssá: munkamenet-megszakadás vagy kezeletlen dump esetén a puffer elveszhet. A tartós, hívás előtti mentés külön LUW-tervezést igényelne, ezért nem került ebbe a kizárólag naplózási módosításba.

Az explicit sikertelen SAP-mentést és az Inspire elutasítását külön naplózzuk. A technikai hívási hiba bizonytalan eredmény marad, a meglévő védelemmel; automatikus újrahívás nem került be. A ZCL_PR_LOG implementációja és az aktív SAP-állapot nincs ellenőrizve. SAP-kapcsolati kísérlet, aktiválás, fordítás, ATC vagy futtatott teszt nem történt.

A helyi ellenőrzés a változtatási határt, az eredeti üzleti rutinokat/payloadot/LUW-utasításokat, a helyi DDIC-mezőket, a hívás körüli eseményágakat, a szövegreferenciákat és a diff bájtpontos előre/vissza alkalmazását vizsgálja. Ez nem ABAP-fordítás vagy funkcionális SAP-teszt. Helyi ABAP-parser alapból nem áll rendelkezésre; ha megadható @abaplint/core modulútvonal, a script első argumentumaként átadható.

Újragenerálás Node.js-szel: `node build-check.cjs`. A jelen Windows sandboxban a futtatáshoz a `--preserve-symlinks-main --preserve-symlinks` kapcsolókat használtuk. A script az eredeti forrás SHA256-egyezését kötelezően ellenőrzi.
