# ZEBF_PR_STOCK_REPORT átültetése QU5-ről DHC-ra

Dátum: 2026-10-13. Státusz: WIP. Ez elemzés és megvalósítási javaslat; ABAP- és SAP-objektummódosítás nem történt.

## Következtetés

A riport DHC-ra átültethető. Az adatlekérés és a megjelenítés leképezése nagyrészt megállapítható a helyi exportokból. A lezárás üzleti működéséhez még tisztázni kell a stockállapotok összhangját, a kizárt borítékok Inspire-átadását és a ragszámkezelés DHC-megfelelőjét. A meglévő `ZCL_PR_STOCK=>CLOSE_STOCK` jelenlegi helyi exportja nem valósítja meg a QU5-riport teljes működését.

Az aktív SAP-forrás olvasását az elérhető ADT-kapcsolaton megkíséreltük (`GetProgram`, `ZEBF_PR_STOCK_REPORT`); HTTP 401 miatt sikertelen volt. A megállapítások helyi statikus elemzésből származnak; az aktív QU5/DHC objektumállapot, a konfigurált célrendszer és a fordíthatóság nincs igazolva.

## Források és bizonyosság

- [QU5 főprogram](../01_SOURCES/QU5/ZEBF_PR_STOCK_REPORT.abap): 999 sor. A hivatkozott `_O01` és `_I01` include nincs a projekt helyi fájljai között.
- [DHC stockosztály](../01_SOURCES/DHC/ZCL_PR_STOCK.abap): `CLOSE_STOCK`, `CHECK_STATUS`, `GET_STOCK_HEADER`, `UPDATE_STATUS`.
- [DHC stocktábla](../01_SOURCES/DHC/ZPRT_STOCK.table), [DHC dokumentumtábla](../01_SOURCES/DHC/ZPRT_DCQM.table), [QU5 stocktábla](../01_SOURCES/QU5/ZEBFT_PR_STOCK.table), [QU5 fájltábla](../01_SOURCES/QU5/ZEBFT_PR_MSSFILE.table), [QU5 ALV-struktúra](../01_SOURCES/QU5/ZEBFS_PR_DCQM_REPORT.sructure).
- [DHC cockpit eseménykezelése](../01_SOURCES/DHC/ZPR_COCKPIT/LZPR_COCKPITO01.abap), a cockpit főfüggvénye és TOP include-ja.
- A projekt `_LOG.md`, a korábbi DC-terv és a `ZPRS_DCQM_REPORT` létrehozási specifikációja: korábbi munkához készült helyi tervek, nem az aktív SAP-állapot igazolásai.
- `01_SOURCES/Tömeges tranzakciók.docx`: OOXML-ből kiolvasott követelmények. Már rögzített cél a `ZPR_MASS / STOCK` napló és a `ZCL_PR_LOG`; a kódhoz/DDIC-hez megadott csomagok `ZPR_FUNC` és `ZPR_DDIC`. Ezeket nem kell újra megkérdezni. A dokumentum szerint a `CLOSE_STOCK` a későbbi stocklezárási funkció jelöltje.

A táblaexportok mezőlisták; a teljes kulcsot, indexeket, doménértékeket, keresési segítségeket és aktív állapotot nem igazolják. Az oneERP PDF teljes szövegét az elérhető helyi eszközökkel nem sikerült kiolvasni; ez az elemzés nem teljes guideline-megfelelőségi audit.

## A QU5-riport működése

1. Kötelező stockazonosítót és opcionális ALV-variánst kér (`P_STOKID`, `P_VARI`, 84–93. sor).
2. Beolvassa a `ZEBFT_PR_STOCK` rekordot. Nem létező stock hibát ad; lezárt, DC-ben vagy QM-ben még nem engedélyezett stocknál megjelenítő módra vált (205–228. sor).
3. Módosító módban stockzárat kér (`ENQUEUE_EZEBFT_PR_STOCK`, 234–258. sor).
4. A stockhoz tartozó fájlokat a `ZEBFT_PR_MSSFILE` táblából gyűjti. Az ALV-be csak a DC-ben **vagy** QM-ben kizárt dokumentumok kerülnek; külön számolja az összes nyomtatási sort. A hosszú okokat a `ZEBFT_PR_DCQMLT` táblából tölti (127–189. sor).
5. A 0100 képernyőn megjeleníti a kizárt sorokat és az összes/kizárt darabszámot. A toolbar `RELEASE` gombja csak módosító módban jelenik meg (421–427. sor).
6. Engedélyezéskor prioritást kér a felhasználótól (287–329. sor).
7. Az `EON_DCQMCompleted` proxyval elküldi a mandantot, rendszert, stockazonosítót, prioritást és a kizárt sorokból képzett, duplikációmentes borítéklistát (839–951. sor).
8. Sikeresnek tekintett hívás után a kizárt dokumentumokhoz ragszámrekordokat töröl a `ZPR_TERTI` és `ZISU_F064` táblákból (976–999. sor).
9. Ment: `CLOSED = X`, `PRIORITY`, `ERDAT_CLO`, `ERNAM_CLO`, `ERTIM_CLO`; majd commit és naplózás következik (335–379. sor).
10. A naplót menti/megjeleníti, és kilép az ALV-ből (382–386., 793–833. sor).

Ez a végső nyomdai engedélyezés/stocklezárás. A korábbi `ZPR_DC_FRAME` DC-jóváhagyása önmagában nem helyettesíti.

## DHC-leképezés

| QU5 elem | DHC cél / javaslat | Állapot |
|---|---|---|
| `ZEBF_PR_STOCK_REPORT` | Önálló riportként például `ZPR_STOCK_REPORT`, közös lezárási szolgáltatásra építve | Célnév és belépési pont egyeztetendő |
| `ZEBFT_PR_STOCK` | `ZPRT_STOCK` | A QU5-ben használt stockmezők a helyi exportban megvannak |
| `ZEBFD_PR_STOCK_ID`, CHAR10 | `ZPRD_STOCK_ID`, NUMC10 | Vezető nullák és a külső rendszer stockformátuma ellenőrizendő |
| `MSSFILE → FILENAME → DCQM` | Közvetlen `ZPRT_DCQM-PRD_STOCK_ID` szűrés | Mező rendelkezésre áll; adatfeltöltés/teljesség ellenőrzendő |
| `ZEBFT_PR_DCQM-EXBILLDOCNO` | `ZPRT_DCQM-DOC_NO` | Tudatos mezőleképezés kell |
| `ZEBFS_PR_DCQM_REPORT` | `ZPRS_DCQM_REPORT` | Helyi specifikáció van; aktív definíció nincs ellenőrizve |
| `ZEBFT_PR_DCQMLT` | `ZPRT_DCQMLT`, kulcshivatkozás: `EXBILLDOCNO = DOC_NO` | Korábbi felhasználói pontosítás; aktív export kell |
| `EZEBFT_PR_STOCK` | DHC meglévő stockzár; korábbi javaslat `EZPRT_STOCK` | Régi DHC-jegyzet szerint nem létezett; mai állapot ismeretlen |
| Régi proxy és request/response | `ZPR_CO_EON_DCQMCOMPLETED_PORT` és a `ZCL_PR_STOCK` által használt ZPR-típusok | Referenciák vannak; proxy és teljes típusdefiníció nincs exportálva |
| Implicit alapértelmezett port | `ZCL_PR_OUTPUT_MANAGEMENT=>GET_LOGICAL_PORT_NAME()` | A DHC-osztály már használja; szignatúra és proxyhoz illő port ellenőrizendő |
| `ZPR_TERTI`, `ZISU_F064` törlés | DHC ragszámkezelő táblák vagy szolgáltatás | Nincs igazolt DHC-megfelelő |
| `ZEBF_PR / Z_STOCK`, BAL függvények | `ZCL_PR_LOG`, `ZPR_MASS / STOCK` | Követelmény ismert; osztályszignatúra és mentési viselkedés ellenőrizendő |
| `ZEBF_PR` és `ZEBF_PR_TRIGGER` üzenetek | `ZPR` megfelelő szövegekkel | Nem mechanikus számegyezés; aktuális üzenetlista kell |
| Prioritáskonstans, `ZIF_EBF_PR_CONST` | DHC meglévő konstans vagy egyeztetett alapérték | Helyi DHC-osztályban `30` szerepel; megengedett értékek ellenőrizendők |
| 0100 dynpro, include-ok, GUI-státusz, szövegelemek | DHC képernyőobjektumok | Teljes QU5 UI-export hiányzik |
| Stock memóriaazonosító és F4 | DHC adatelemhez kötött segítség / meglévő stocksegítség | A memóriaazonosító nem bizonyít F4-hozzárendelést |

A kiválasztás DHC-ban a következő logikát követheti: stock = `PRD_STOCK_ID`, kizárt = `BLOCK_DC` vagy `BLOCK_QM` nem üres, összes sor = az adott stock dokumentumtáblabeli sorainak száma. A fájlonkénti `FOR ALL ENTRIES` útvonalra így nincs szükség. A darabszám dokumentumsorokat jelent, nem különböző borítékokat; a borítéklista külön deduplikálandó. A `COUNTER` megjelenítési értékét az egyeztetett összegzési szabály szerint kell biztosítani.

## A meglévő DHC stockosztály eltérései

| Megállapítás | Következmény |
|---|---|
| A `CLOSE_STOCK` borítékgyűjtése és `EXCLUDE_ENVELOPES` feltöltése ki van kommentelve (128–135. sor) | A helyi export nem küldi el a QU5 szerinti kizárási listát |
| A metódus nem olvassa be a helyi `GS_STOCK` változót, mégis ebből tölti a popup prioritását (89. sor) | A stockban tárolt prioritás nem kerül a popup alapértékébe; a lokális `30` alapérték sem ezt a mezőt tölti |
| A metódusban nincs stocklétezés-, `CLOSED`/DC/QM-ellenőrzés és zárolás | A metódus önmagában nem biztosítja a QU5 előfeltételeit |
| Siker esetén csak `UPDATE_STATUS(... 'CL')` hívás van (209–213. sor) | Nem menti a QU5 szerinti `CLOSED`, prioritás- és lezárási auditmezőket; ragszámtörlés sincs |
| Az `UPDATE_STATUS` csak a `STATUS` mezőt írja, és maga commitol/rollbackel (329–340. sor) | Közvetlen használata lezárja a hívó aktuális LUW-ját is; összetett lezáráshoz nem elegendő |
| A `CLOSE_STOCK` nem ad vissza sikert és nem deklarál üzleti eredményt | A hívó nem kap egyértelmű lezárási eredményt az adatbázismentésről |
| `MESSAGE i040(zebf_pr)` maradt (116. sor), a 071/072 üzenet a régi `ZPR` 000–044 exportban nincs | Az aktív üzenetosztály és szövegek ellenőrizendők |
| A napló alobjektuma `PACKAGE` (75. sor) | A követelményben szereplő `STOCK`-hoz igazítandó |
| A prioritásbekérés GUI-popupot használ | A későbbi batch használathoz a prioritást paraméterként kell kezelni; a `SY-BATCH` csak a napló megjelenítését védi |

A `CHECK_STATUS` a felsorolt átmenetek egy részét ellenőrzi, de nem teljes állapotgép: például előre irányban a régi `CL`, az ismeretlen státusz vagy az ismeretlen irány nem kap teljes tiltást. Nem helyettesíti az aktuális stock zárolás alatti beolvasását és a lezárás összes előfeltételét.

### A cockpit kapcsolata különösen fontos

A helyi `LZPR_COCKPITO01` `CLOSE` ága `CHECK_STATUS` után közvetlenül `UPDATE_STATUS(... 'CL')` hívást végez. Nem hívja a `CLOSE_STOCK` metódust, tehát ebben az útvonalban nincs Inspire-átadás. A `REOPEN` ág közvetlenül `QM`-re állítja a státuszt; külső nyomdai visszavonás sincs a látható ágban.

Ebből nem következik, hogy az aktív DHC is ugyanígy működik, de a helyi forrásban ez igazolt. Ha a cockpit továbbra is elérhető belépési pont, ugyanazt a lezárási műveletet kell használnia, mint az új riportnak. A puszta státuszállítás és a külső nyomdai lezárás összhangját meg kell határozni.

## A QU5-ből nem átveendő hibák és kockázatok

1. **Proxy-létrehozási hiba után lezárás történhet.** A `CREATE OBJECT` `CATCH` ága kilép a `SEND_PRIORITY` rutinból, de nem állítja hibára a `GV_ERROR` változót (878–883. sor). A hívó a kezdetben üres hibajelző miatt folytathatja a ragszámtörlést és a stocklezárást. A DHC-metódus ebben a konkrét ágban már beállítja saját hibajelzőjét.
2. **Módosíthatóság újraszámítása hiányzik.** A `CHECK_STOCKID` csak hamisra állítja a `GV_MODIF` jelzőt; új stock vagy ismételt szelekció ellenőrzésekor nem inicializálja újra. Korábban tiltott stock után az engedélyezhető stock is tiltva maradhat.
3. **Előfeltételek ellenőrzése a zár előtt történik.** A stockállapotot sikeres zár után és a lezárási művelet előtt is újra kell olvasni. A toolbar elrejtése önmagában nem üzleti védelem.
4. **Ragszámtörlés eredménye nincs ellenőrizve.** A két törlés `SY-SUBRC`/érintett sorainak vizsgálata hiányzik. A nem létező rekord és a valódi adatkezelési hiba kezelését meg kell különböztetni.
5. **Külső siker és helyi mentési hiba kezelése nincs megoldva.** A proxyhívás megelőzi az adatbázismentést. A helyi rollback nem bizonyítja a külső rendszer műveletének visszavonását. Ehhez Inspire-oldali újrahívási/idempotencia- vagy visszavonási szabály szükséges.
6. **Hiba után az ALV is bezáródik.** Ez nehezíti az ellenőrzést és újrapróbálást; javasolt a hibát megjeleníteni és a képernyőt nyitva tartani.
7. **Stockmentési hiba nem kerül a látható naplóba.** Az `s025` üzenet `INTO` változóba készül, de az ágon nincs `LOG_ADD_MESSAGE` (372–376. sor).
8. **A proxyhívás kivételeinek részletes naplózása ki van kommentelve.** A generikus hiba helyett a tényleges exception és a külső hibaválasz megőrzése kell.
9. **Üres boríték is kerülhet a kizárási listába.** A QU5-kód nem szűri ki; DHC-ban a 9 karakteres borítékazonosító és az üres érték interfészszabálya tisztázandó.
10. **Explicit feloldás nem látható a főprogramban.** Az include-ok hiányoznak; a teljes záréletciklus ezek nélkül nem bizonyított. Minden kilépési és hibautat ellenőrizni kell.
11. **QU5-fejlesztői függőség maradt.** A `ZKG_BREAK X0153` aktív sor (150.) DHC-ban nem másolandó át ellenőrzés nélkül.
12. **A `P_VARI` nincs felhasználva a megjelenítéshez.** Az ALV-variáns riportját és felhasználóját beállítja a kód, a kiválasztott variáns nevét nem. A paraméter látszólagos működését érdemes javítani az átültetésben.
13. **A `NOTEST` a látható főprogramban csak naplóüzenetre hat.** Nincs ilyen request-hozzárendelés. A teszt/éles útvonalra gyakorolt tényleges hatást nem szabad feltételezni.

A `COMMIT WORK` a teljes aktuális SAP LUW-t zárja; emiatt a saját commitot végző általános státuszmetódus nem építhető be ellenőrzés nélkül a több táblát érintő lezárás közepére. Forrás: [SAP ABAP COMMIT WORK dokumentáció](https://help.sap.com/doc/abapdocu_752_index_htm/7.52/en-US/abapcommit.htm).

## Milyen információ szükséges még

### A lezárás megvalósítását meghatározó kérdések

| Azonosító | Szükséges információ / döntés | Miért szükséges |
|---|---|---|
| S1 | DHC-ban a `STATUS` az elsődleges, vagy a `CLOSED/DCCOMPL/QMCOMPL` jelzők? Milyen együttállás engedi a lezárást, és siker után pontosan mely mezőket kell menteni? | A cockpit és a korábbi DC-riport más mezőket ír; következetes jogosultság és előfeltétel kell |
| S2 | A `CLOSE_STOCK` közös lezárási műveletté bővítendő, vagy a riport más meglévő szolgáltatást hív? A cockpit lezárásgombja is ezt hívja majd? | Egy stockhoz ne legyen eltérő működésű lezárási útvonal |
| S3 | DHC-ban hol tároljuk/kezeljük a kizárt dokumentumok ragszámát? Létezik-e `ZPR_TERTI`, `ZISU_F064`, vagy van más szolgáltatás? Szükséges-e fizikai törlés és `REGMAILNUMBER` módosítása? | A QU5 két táblát töröl; DHC-megfelelő nélkül ezt nem lehet biztonságosan leképezni |
| S4 | Az `EON_DCQMCompleted` aktuális request/response/proxy definíciója, a hozzá tartozó logikai port és tesztvégpont. Milyen stock- és borítékformátumot vár, mi legyen üres borítéknál? | A DHC proxyhivatkozásokból nem igazolható a teljes szerződés és konfiguráció |
| S5 | Mi történjen külső siker, helyi DB-hiba vagy timeout után? Ugyanaz a stock újraküldhető? Van külső állapotlekérdezés/visszavonás? | A kétszeri engedélyezés és az eltérő helyi/külső állapot megelőzéséhez |

### A forráscsomag és rendszerellenőrzés hiányai

- QU5: `ZEBF_PR_STOCK_REPORT_O01`, `ZEBF_PR_STOCK_REPORT_I01`, 0100 dynpro layout + flow logic, GUI-státusz/címek, szövegelemek, a `ZEBF_PR_STOCK` tranzakció hozzárendelése. A 001–056 és egyéb használt régi üzenetek teljes szövege is hiányzik a helyi részleges `ZEBF_PR.message` exportból.
- DHC: aktuális `ZCL_PR_STOCK`, `ZCL_PR_LOG`, `ZCL_PR_OUTPUT_MANAGEMENT` szignatúrái és implementációi; proxy és request/response/boríték-táblatípusok; a napló mentésének és commitjának viselkedése.
- Aktív `ZPRT_STOCK`, `ZPRT_DCQM`, `ZPRT_DCQMLT`, `ZPRS_DCQM_REPORT` teljes definíciója; kulcsok és a stockhoz tartozó dokumentumok teljessége; `PRIORITY` és `STATUS` doménértékek. A mezők létezését a helyi export alapján nem kell ismét bekérni, az aktív verziót viszont ellenőrizni kell.
- A közösen használt stockzár neve és hatóköre; a DC/QM/cockpit ugyanazt a zárat használja-e. A régi „nem létezik” jegyzet óta létrejöhetett.
- Aktuális `ZPR` üzenetlista. A DC-munkához a 045–066 tartomány már terv szerint foglalt; új stocküzenetet nem szabad erre vakon ráírni. A 071/072 aktív megléte is ellenőrizendő.
- A riport/cockpit belépési pont, végleges objektum- és tranzakciónév, transport, jogosultsági objektum és elvárt ATC-variant. A csomagok már meg vannak adva: `ZPR_FUNC`, `ZPR_DDIC`.
- DHC tesztstock: több dokumentum egy borítékban, csak DC-kizárás, csak QM-kizárás, kizárás nélküli stock, ragszámos kizárás, üres boríték; továbbá zárütközés és hibaágak ellenőrizhetősége. A `NOTEST` tesztútvonalát külön igazolni kell.

## Javasolt megvalósítási sorrend

1. S1–S5 tisztázása és az aktív DHC-objektumok beolvasása.
2. A QU5 UI-csomag kiegészítése. Önálló riport esetén a DHC-adatlekérés és ALV létrehozása a meglévő `ZPRS_DCQM_REPORT` struktúrára; a kizárt sorok csak megjelenítésre szolgáljanak.
3. Közös lezárási művelet kialakítása a meglévő stockkezeléshez illesztve: jogosultság, zár, aktuális stock és kizárások újraolvasása, állapotellenőrzés, prioritás és proxyrequest összeállítása, külső válasz értékelése, ragszámkezelés és minden szükséges stockmező mentése.
4. Egyértelmű eredmény/kivétel a hívónak; napló a `ZPR_MASS / STOCK` alatt; minden kilépési úton zárfeloldás. A GUI-popup és az ALV a riporthoz tartozzon; a közös üzleti művelet kapjon paramétereket.
5. A cockpit lezárási útvonalának összekötése ugyanazzal a művelettel, ha része a jóváhagyott terjedelemnek. A visszanyitás szabályát az Inspire-oldali állapottal együtt kell rögzíteni.
6. SAP-szintaxisellenőrzés, ATC, célzott tesztek és QU5/DHC eredményösszevetés. A külső hívást csak a kijelölt tesztvégponton, tesztstockkal szabad a funkcionális ellenőrzés részeként végrehajtani.

Minimum ellenőrzés: érvényes/tiltott/lezárt stock, hiányzó stock, zárütközés, prioritásbekérés megszakítása, egyedi kizárt borítékok és üres boríték, külső üzleti/technikai hiba, külső siker utáni DB-hiba, ismételt hívás, lezárási auditmezők, ragszámtáblák és napló; továbbá a riport és a cockpit eredményének egyezése.

Az adatlekérés és képernyőterv készíthető a már meglévő adatokból. Éles működésű lezárási kódot S1–S5 és a szükséges aktív interfészek ismerete nélkül még nem lehet véglegesíteni.
