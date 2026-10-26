# Stock cockpit – helyi munkapéldány

**QM-indítás javítása (2026-10-18):** a 2000-es képernyő saját riport-munkamenetben indul (`SUBMIT ZPR_QM ... AND RETURN`), és a gomb hiányzó TEXT-101 esetén is fordítható alapfeliratot kap. [Háromrészes javító diff és dumpdiagnózis](../2026-10-18_cockpit-qm-dynpro-gomb-javitas_WIP.md). A javítás a helyi riportban és a teljes csomagdiffben is szerepel; aktív SAP-próba még nincs.

**QM minta fül (2026-10-18):** a harmadik fül a `ZPR_QM` új 1100-as selection subscreenjén a meglévő indítóképernyőt mutatja, a cockpit stockjával kitöltve. A QM-műveletet a külön **QM indítása** gomb indítja; reset/kilépés/stockváltás takarítja a beviteli állapotot. Új helyi `ZPR_QM.abap`, három módosított cockpitforrás, `TEXT-101`, célzott diff és részletes leírás: [QM-bekötés](../2026-10-18_cockpit-qm-minta_WIP.md). A QM üzleti vezérlése változatlan, SAP-átvezetés/futtatás nincs.

**QA-javítás (2026-10-17):** az O01 54. sorára jelzett „Hidden OK-Codes” miatt a belső `#STOCK` / `#CANCEL` állapotkódok megszűntek. Helyettük a TOP-ban deklarált `GV_STOCK_CHANGED` és `GV_DM_CLOSE_CANCELLED` logikai jelzők működnek; a `SAVE_OK` csak a képernyő funkciókódját tárolja. A **TOP és O01 együtt** vezetendő át. Célzott diff, másolható részletek és SAP-próbaesetek: [QA-javítás](../2026-10-17_cockpit-hidden-okcodes_WIP.md). A korábbi útmutatók `#CANCEL`-os DM_CLOSE részlete történeti változat; az aktuális rutint ebből a csomagból kell venni. SAP-fordítás és QA/ATC-újrafuttatás még szükséges.

**Felhasználói sikeres megjelenítés és tisztítás (2026-10-17):** a felhasználó jelezte: az ALV megjelent az explicit REPId/DYNNR elhagyása után. A beágyazási javítás eredménye így felhasználói futással igazolt, de a mérőkódok/próba-SET_VISIBLE hívások eltávolítása utáni friss példányt és a teljes üzleti regressziót még ellenőrizni kell. Pontos törlési lista és három tiszta rutin: [mérőkódok tisztítása](<../../../../[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/project/03_DRAFTS/2026-10-17_cockpit-merokod-tisztitas_WIP.md>). A fő WIP már mérésmentes, most a rutinok külön másolható kivonatai készültek; végrehajtható fő WIP-kód nem változott.

**Legújabb korrekció: automatikus frontend-képernyőhozzárendelés (2026-10-17).** A cockpit DM_CONTROLS konténerkonstruktorából a REPId/DYNNR explicit átadása törölve; csak CONTAINER_NAME marad. A 1010 a subscreen száma, és egy közvetlenül egyező, első kézből dokumentált eset szerint explicit kötéskor a frontendkonstruktor a főképernyőt várja. A paraméterek elhagyása automatikus felismerést enged. A korábbi 1010-es GET_LINK_INFO eredmény „helyes kötés” minősítése ezért javítva: a név/program egyezett, a frontend főképernyő-szintjét nem igazoltuk. A felhasználói új kép szerint GUI_IS_RUNNING/ACTIVEX/IS_INIT = X, CFW_MODE = 0, INIT_STATE = 2, SHELLSTYLE = 1342177280 (WS_CHILD + WS_VISIBLE), PARENT O:29; ezek önmagukban nem magyarázzák a rejtést. Az új egyszerűsítés csak helyi, SAP-ban még kipróbálandó. A frissített konténerátadási útmutató tartalmazza a pontos helyet; az önálló riport marad változatlan. [Első kézből dokumentált egyező eset](https://community.sap.com/t5/application-development-and-automation-discussions/alv-grid-in-a-subscreen/m-p/5767584).

**Legújabb állapot, 2026-10-17:** az önálló SE38-as megjelenítő út felhasználói képen működik, négy adatsorral; a cockpitbe ágyazott út továbbra is üres. A helyi csomag új változata a custom containert a cockpit 1010 PBO-jában készíti el, és a kész objektumreferenciát adja a COCKPIT_PBO adapternek. Ez célzott javítási változat, SAP-ban még nem kipróbált megoldás. Másolható lépések: [konténerátadási útmutató](<../../../../[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/project/03_DRAFTS/2026-10-17_cockpit-kontener-atadas_WIP.md>). A korábbi hostprogram-/képernyőszám-átadást leíró részek történeti előzmények; az új COCKPIT_PBO egyetlen konténerreferenciát fogad. A részleges MCP-visszaolvasás utáni auto-review blokkolás fennmarad; új SAP-írás/aktiválás/futtatás nincs.

Státusz: **WIP**, 2026-10-16; kiegészítve: 2026-10-17. Ez előkészített forráscsomag, nem SAP-ban aktivált fejlesztés. A 2026-10-16-i előkészítéskor nem volt hívható SAP ADT repository-eszköz. 2026-10-17-én a riport aktív és inaktív főforrásának ADT-olvasása sikeres volt: az inaktív változatban a C01 include kétszer szerepel, a 308. és az 1628. sorban. A duplázás bizonyított; az adapter teljes aktív állapota, az include belső tartalma, a képernyők és a futás továbbra sem ellenőrzött. SAP-írás, aktiválás, új kapcsolati hiba és automatikus jóváhagyási elutasítás nem történt.

## Mi van már meg a helyi forrásban?

| Elem | Meglévő megoldás | Szükséges kiegészítés |
|---|---|---|
| Indítás | `Z_PR_COCKPIT`, opcionális `IV_STOCK_ID`, `CALL SCREEN 100` | Új belépéskor az előző globális fejléc törlése; hibás átadott stocknál visszatérés |
| Stockellenőrzés | `ZCL_PR_STOCK=>GET_STOCK_HEADER`: kulcs szerinti olvasás, hiánynál `ZCX_FORM_MESSAGE_ERROR` | Meghívás a képernyő PAI eseményében is |
| Fülek | 1010 / 1020 / 1030 / 1040 / 1050 kiosztás | Az 1010 jelenleg üres váz |
| 0100 flow logic | PBO subscreen-hívás | A PAI `CALL SUBSCREEN` ki van kommentezve |
| Stockmező | `ZPRS_COCKPIT-STOCK_ID` | Sikeres azonosításig bevihető, utána zárolt; feloldás a RESET menüponttal. A fejléc többi HDR mezője csak megjelenítés. |
| Riport | `ZPR_DCQM_EXCLUDE`, saját 0100, ALV, zárolás, kizárás, mentés | A cockpit 1010-es subscreenjén lévő custom control használata |

A megadott `ZPR_DC_EXCLUDE` a riport helyi forrásában **tranzakciókódként** jelenik meg (`INITIALIZATION`); a megtalált riport neve `ZPR_DCQM_EXCLUDE`. Ez alapján erre készült az adapter. Az aktív SE93-hozzárendelést nem ellenőriztük.

## Elkészített működés

**Kezdőállapot:** stock megadása előtt a „DM tétel ell.” fül üres. A 2026-10-17-i felhasználói képernyőkép ezt az állapotot mutatja, a felhasználó megerősítése szerint Enteres stockazonosítás előtt készült. A betöltési feltétel a `DM_OPEN` elején: `CHECK gv_stock_id IS NOT INITIAL`. A cockpit felső mezőjében megadott stock elfogadása után a riport ALV-listája jelenik meg a fülön; az induló üres kép önmagában nem igazol betöltési hibát. Érvényes stock és Enter utáni tényleges GUI-megjelenítés még nincs igazolva.

Az ezt követő ADT-visszaolvasás szerint az aktív ZPR_DCQM_EXCLUDE főprogramban a C01 include egyszer szerepel (308. sor), a hostváltozók és a konténer explicit hostprogram-paraméterei megvannak. A C01 adapter és a cockpit O01 include is visszaolvasható; `DM_OPEN` a stockfeltétel után hívja a `COCKPIT_OPEN` rutint, `DM_CONTROLS` pedig csak `GV_DM_READY = abap_true` esetén hívja a riport PBO adapterét. A képernyő-geometria, az aktív 1010 flow logic és az ALV_CONTAINER_01 layoutbeli megléte nem lett közvetlenül visszaolvasva. SAP-írás/aktiválás/futtatás nem történt.

**Későbbi képernyőkép: stock után is üres fül.** A 2026-10-17-i második képen `0000000033` és „DM jóváhagyás megtörtént” látszik, tehát a stockfejléc beolvasása sikeres; az első fül továbbra is üres. A felhasználó megerősítette, hogy a 1010 flow logic PBO-jában szerepel a `MODULE dm_controls.` sor. Az `ALV_CONTAINER_01` elem 1010-es layoutbeli meglétének/típusának ellenőrzése a következő lépés. A dinamikus stockazonosítás sikeréből az ALV-konténer létrejötte még nem következik.

A 1010 flow logic SAP-beli olvasásához megkísérelt `GetSqlQuery` / `SELECT * FROM D022S WHERE PROG = 'SAPLZPR_COCKPIT' AND DNUM = '1010'` HTTP 400 hibával sikertelen. Ez a képernyő tartalmát nem igazolta, nem HTTP 401 és nem automatikus jóváhagyási elutasítás. A SAP-eszközhasználatot leállítottuk; új SAP-elérés csak új, kifejezett felhasználói újrapróbálási kérésre történhet. A további forráselemzés helyi/korábban sikeresen beolvasott anyagból történik.

Ha az elem is megvan, a célzott debug sorrendje: `DM_CONTROLS` session breakpoint → `GV_DM_READY` értéke → a riport `COCKPIT_PBO` hívása → `GV_HOST_REPID = SAPLZPR_COCKPIT`, `GV_HOST_DYNNR = 1010` → `CREATE_CONTROLS_0100`-ban a custom container `CREATE OBJECT` utáni `SY-SUBRC` és a két objektumreferencia. A jelenlegi riport több kontroll-létrehozási hibánál csak `EXIT`-et hajt végre, így hibaüzenet nélkül is maradhat üres terület; a pontos hibát a visszatérési kód igazolhatja. A hiányzó vagy hibás nevű custom control lehetséges ok, még nem igazolt tény.

**A felhasználó által debuggerből igazolt további adatok (2026-10-17):** DM_CONTROLS megáll, GV_DM_READY = X; a hostadatok SAPLZPR_COCKPIT / 1010; mind a custom container, mind az ALV Grid CREATE OBJECT után SY-SUBRC = 0; a SET_TABLE_FOR_FIRST_DISPLAY után is 0, LT_FIELDCAT = 38 sor, GT_0100_ALV = 4 sor. A korábban kért adatokat ezért nem kell újra vizsgálni. Következő lépés: F8-cal a PBO végét és a normál cockpitképernyőt elérve ellenőrizni, megjelenik-e a lista. A debuggerben a PBO közepén látható üres területből még nem következik végleges megjelenítési hiba.

A Control Framework a vezérlőhívásokat az Automation Queue-ban pufferelheti; a PBO végén automatikus szinkronizálás történik. Emiatt nem tekintjük igazolt javításnak egy extra FLUSH vakon történő hozzáadását. Ha F8 után is üres a fül, a következő célzott vizsgálat a debugger **Automation Controller: Always process requests synchronously** beállítása, friss cockpitindítással; ennek segítségével a frontend-hiba a konkrét vezérlőhívásnál azonosítható. Szükség esetén csak átmeneti diagnosztikaként kezelendő külön FLUSH és visszatérési kódja. [SAP: Automation Queue](https://help.sap.com/saphelp_autoid2007/helpdata/en/9b/d080ba9fc111d2bd68080009b4534c/content.htm?no_cache=true), [SAP: FLUSH](https://help.sap.com/docs/SAP_NETWEAVER_731_BW_ABAP/70396d7dec4c4f19b9ca3b2e47559d12/4d70cfeda9e24cb2e10000000a42189c.html?version=7.31.22), [SAP: Using Controls in a WAN](https://help.sap.com/docs/sap_s4hana_on-premise/70396d7dec4c4f19b9ca3b2e47559d12/4a3f6449444b47feb2196c788722c842.html). A frontend végleges állapota és a gyökérok továbbra sincs igazolva; új forrásmódosítás és SAP-hívás nincs.

Enterkor a cockpit beolvassa a stockfejlécet. Üres vagy nem létező stocknál nem indul funkció. Új, érvényes stock elfogadásakor a fejléc lesz a közös kontextus, a stockmező csak olvashatóvá válik, és az első fül megnyílik; az ugyanakkor érkezett régi funkciókód nem fut le az új stockra. Másik stock megadásához a RESET menüponttal kell alaphelyzetbe állítani a cockpitot. Az opcionális FM-paraméterrel indítás meglévő, státusz szerinti kezdőfülválasztása megmaradt; az így azonosított stock mezője is lezárul.

A beazonosítás előtt a `CONVERSION_EXIT_ALPHA_INPUT` explicit belső formátumra alakítja a stockazonosítót a képernyőből és az opcionális FM-paraméterből is. A helyi `ZPRT_STOCK` definíció szerint ez NUMC(10): `123` → `0000000123`. A képernyős út üres bemenetet már a konverzió előtt elutasít. [SAP: ALPHA-konverzió](https://help.sap.com/docs/ABAP_PLATFORM_NEW/9c91640bf34c49d8bad6bc560bedd707/cfb789f931a24016999eabd80aa4ea6f.html?locale=en-US&state=PRODUCTION&version=202110.002).

Az első fül a meglévő riport adatlekérését és ALV-kezelését használja. A riport `COCKPIT_OPEN`, `COCKPIT_PBO`, `COCKPIT_SAVE`, `COCKPIT_CLOSE` FORM-jait a cockpit hívja. Nincs `SUBMIT`, új tranzakció vagy külön riportképernyő. A custom containert a cockpit saját DM_CONTROLS PBO-ja hozza létre a 1010-en, a COCKPIT_PBO pedig a kész konténerreferenciát kapja. Sikeres bezáráskor a riport felszabadítja a kontrollokat, a cockpit pedig saját referenciáját is elengedi; megszakított bezáráskor mindkettő megmarad. Az önálló riport továbbra is saját konténert készít.

A riport beágyazott mentése a fülön marad; a napló mentése megmarad, automatikus naplóablak-nyitás ebben a módban nincs. Az önálló riportút megtartja a meglévő képernyő- és kilépési működést. A módosító belépés ellenőrzi a `ZPR_DC_EXCLUDE` tranzakcióhoz tartozó `S_TCODE` jogosultságot; a meglévő stockzárat és lezárt/DC-kész stocknál a megjelenítő módot is használja.

RESET, másik fülre váltás, státuszművelet és kilépés előtt a függő cellabevitel bekerül az ellenőrzésbe. Mentetlen vagy hibás cellabevitelnél a meglévő megerősítő ablak jelenik meg. Elutasításkor marad a régi stock, fül, adat és zár. Jóváhagyott eldobáskor a kontroll és a saját stockzár felszabadul. Visszatérve a DM-fül újraolvas. A többi fül a meglévő közös `ZPRS_COCKPIT` fejlécből kapja a stockot; további riportintegráció nem készült.

## SAP-ban átvezetendő objektumok

1. `SAPLZPR_COCKPIT` függvénycsoport: a mellékelt `LZPR_COCKPITTOP`, `LZPR_COCKPITO01` include és a `Z_PR_COCKPIT` függvény törzse. Az FM importparamétere változatlan. Az UXX/include-hálózat meglévő állapotát meg kell őrizni.
2. A cockpit 0100 és 1010 flow logic: a két `.flow.abap` fájl szerint. A többi subscreen és modul meglévő tartalmát nem szabad felülírni a régi exporttal.
3. `ZPR_DCQM_EXCLUDE`: a mellékelt főprogram és az **új** `ZPR_DCQM_EXCLUDE_C01` include. Az O01/I01 fájlok a kiinduló export változatlan másolatai, összevetéshez. Az aktuális rendszerforráshoz az `ABAP-valtozasok_WIP.diff` változásait kell illeszteni, nem ellenőrizetlenül teljes forrást cserélni.
4. A `SAPLZPR_COCKPIT` szövegkészletében a `101` szövegszimbólum: **Adja meg a stock azonosítóját.** Az új `102`: **A DM lista képernyőkonténere nem hozható létre.** A magyar szövegek és a célrendszer szükséges fordításai külön transzportálandók; másolható lista: `2026-10-17_cockpit-textelemek_WIP.tsv`. A riport meglévő W01/W02/W03 textelemét az adapter is használja.

### COCKPIT_OPEN hiányzik – a riportoldali adapter bekötése

**2026-10-17-i új hiba: „A FORM already exists with the name COCKPIT_OPEN”.** Az ADT-n visszaolvasott inaktív főprogramban a `INCLUDE zpr_dcqm_exclude_c01.` sor a 308. sorban és a fájl végén, az 1628. sorban is szerepel. Csak a fájl végén lévő második include-sort kell eltávolítani. A C01-ben lévő FORM-ok és a 308. sori INCLUDE maradjanak meg. Ezután a főprogram és az include közös szintaxisellenőrzése/aktiválása szükséges. A jelenlegi aktív főprogram még nem tartalmazza a C01-et; a hibát az inaktív változat duplázása okozza. Az olvasott források a projekt `01_SOURCES/DHC/2026-10-17_cockpit/` almappájában vannak, a célzott egysoros javítás a `03_DRAFTS/2026-10-17_cockpit-dupla-include_WIP.diff`. SAP-ban nem módosítottunk.

A felhasználó által 2026-10-16-án megadott ST22 szerint a `SAPLZPR_COCKPIT` `DM_OPEN` rutinja eléri a `ZPR_DCQM_EXCLUDE` programot, de abban a futáskor betöltött változatban nincs `COCKPIT_OPEN` FORM (`CX_SY_DYN_CALL_ILLEGAL_FORM`). Ez a szükséges riportoldali adapter hiányát vagy inaktív/betöltött régi változatát igazolja, nem új SAP-kapcsolati hibát. A pontos repository-állapotot nem olvastuk vissza.

Az átvezetés együtt szükséges elemei:

1. SE38/SE80-ban hozd létre a **ZPR_DCQM_EXCLUDE_C01** programot **Include program** típussal, ha még nem létezik. A teljes tartalma az azonos nevű mellékelt `.abap` fájl. Az include négy FORM-ot tartalmaz: `COCKPIT_OPEN`, `COCKPIT_PBO`, `COCKPIT_SAVE`, `COCKPIT_CLOSE`.
2. A **ZPR_DCQM_EXCLUDE főprogramban**, a meglévő O01/I01 include-ok mellett legyen az új include-hívás:

```abap
  INCLUDE zpr_dcqm_exclude_o01.
  INCLUDE zpr_dcqm_exclude_i01.
  INCLUDE zpr_dcqm_exclude_c01.
```

3. A főprogram globális deklarációi közé kerüljenek a hostadatok:

```abap
DATA: gv_embedded     TYPE abap_bool,
      gv_embed_failed TYPE abap_bool,
      gv_host_repid   TYPE syrepid,
      gv_host_dynnr   TYPE sydynnr.
```

4. A főprogram további cockpit-módosításait is illeszd az aktuális SAP-forrásba a mellékelt `ABAP-valtozasok_WIP.diff` **ZPR_DCQM_EXCLUDE.abap** szakasza alapján: `LOCK_AND_CHECK_STOCK` beágyazott hiba-visszatérés, `DISPLAY_ALV` önálló hostadatok, `CREATE_CONTROLS_0100` explicit hostprogram/képernyő, `SAVE_DATA` helyben maradás és `LOG_WRITE` beágyazott megjelenítés kezelése. A mellékelt teljes főprogram összehasonlítási alap; az azóta SAP-ban javított forrásrészeket meg kell őrizni.
5. A **főprogramot és a C01 include-ot együtt** ellenőrizd és aktiváld. Az include önálló szintaxisellenőrzésekor a főprogramot kell környező programként választani, mert az adapter annak globális adatait és FORM-jait használja.
6. Lépj ki a cockpitból, az adott belső munkamenetet is lezárva, majd indítsd újra. Szükség esetén új SAP GUI-móduszban próbáld, hogy friss programváltozat töltődjön be. Session breakpointtal a `FORM cockpit_open` első végrehajtható sorában ellenőrizhető, hogy a riportoldali belépés megtörténik.

Az új include a **ZPR_DCQM_EXCLUDE** része legyen; a cockpit függvénycsoportjába helyezve a riportbeli FORM továbbra sem lesz elérhető. A FORM és az include neve nem felcserélhető: a `PERFORM cockpit_open IN PROGRAM zpr_dcqm_exclude` hívás helyes névpárost használ. Az Enter-feldolgozás ehhez a dumphoz már eljutott; a további javítás a riportoldali bekötés és az aktív változat egyezősége.

### SE51: teljes rendelkezésre álló szélesség

A helyi `.screen` fájl csak flow logicot tartalmaz; a tényleges geometria és resizing attribútumok hiányoznak. Ezek a forrásfájl bemásolásával nem változnak meg.

| Objektum | Beállítás |
|---|---|
| `SAPLZPR_COCKPIT` / 0100 | Normál képernyő, következő 0100; a hívás marad `CALL SCREEN 100`, ablakkoordináták nélkül. A stockmező felül, a tabstrip alatta a munkaterület jobb széléig érjen. |
| `T_TABSTRIP` | Vízszintes és függőleges resizing bekapcsolva; használható minimális mérettel. |
| `T_SUB_SC` | A tabstrip belső tartományát töltse ki, mindkét irányú resizing bekapcsolva. |
| Mind az öt fül | Referencia `T_SUB_SC`; szerveroldali fülváltás: a meglévő `T_DM_ITEM` stb. funkciókódok típusa normál, ne P legyen. |
| `SAPLZPR_COCKPIT` / 1010 | **Subscreen** típus, statikus következő képernyő 1010; a mérete illeszkedjen a `T_SUB_SC` területhez. |
| 1010 / `ALV_CONTAINER_01` | Új custom control; töltse ki az 1010-et, vízszintes és függőleges resizing bekapcsolva. |
| 0100 / OK-mező | `OK_CODE`; a subscreennek ne legyen saját OK-mezője. |

A másik négy fül meglévő geometriai beállítását az új közös szélességhez kell ellenőrizni. A rendelkezésre álló SAP GUI munkaterület kitöltése a cél; a kliens operációsrendszerbeli ablakméretét a kód nem módosítja.

**2026-10-17-i felhasználói 1010-attribútumkép:** Custom control, név `ALV_CONTAINER_01`, sor/oszlop 1/1, hossz/magasság 170/35. Mindkét resizing jelölő üres, minimum sor/oszlop 35/170. A típus és technikai név így képről megerősített, a korábbi hiányzó képernyőelem-feltételezést ez nem támogatja. A teljes szélesség/ablakméret követéséhez mindkét resizing bekapcsolandó, és használható minimum állítandó, javaslat: 5 sor / 10 oszlop. Ezek tervezési értékek, nem SAP által előírt konstansok. A fő 0100-on a `T_TABSTRIP` és `T_SUB_SC` kétirányú resizing beállítása is szükséges. Átvétel, mentés és az érintett képernyők aktiválása után új cockpitindítással ellenőrizendő a megjelenés, majd kisebb/nagyobb ablakban a méretkövetés. A kikapcsolt resizing az átméretezési igénnyel igazolt eltérés, **nem az üres ALV bizonyított oka**; pozitív 1366×424 konténerméretet már mértek. Új ABAP-próbakód nincs. [SAP: Custom Container Attributes](https://help.sap.com/docs/SAP_NETWEAVER_AS_ABAP_752/bd833c8355f34e96a6e83096b38bf192/7f485382045211d294ed00a0c94260a5.html?version=7.52.11).

### SE41: funkciók

A cockpit meglévő `0100` GUI-státuszában legyen `SAVE` (Ctrl+S), Enterhez `ENTER`, valamint a meglévő vissza/kilépés/megszakítás funkciók E típussal. A `SAVE` a DM-fül adapterét hívja. Az Enter explicit funkciókódja különíti el az üres kezdeti képernyő átméretezésekor érkező üres PAI eseményt a tényleges elfogadástól. A címsor meglévő azonosítóját SE41-ben ellenőrizni kell; a csomag nem hoz létre új címsorazonosítót.

### 2026-10-17: stockmező lezárása és RESET menüpont

A `SCREEN_ATTRIBUTES` PBO modul csak addig ad `SCREEN-INPUT = 1` értéket a `ZPRS_COCKPIT-STOCK_ID` mezőnek, amíg `GV_STOCK_ID` üres. A változó sikeres fejlécbeolvasás után kap értéket, ezért hibás stocknál a mező bevihető marad. A `ACCEPT_STOCK` megőrzi a már elfogadott stockot; közvetlen átírással nem váltható stock.

A `PREPARE_COMMAND` a `RESET` kódot a létezésvizsgálat és a subscreen PAI-ja előtt kezeli. A `RESET_COCKPIT` először a meglévő `DM_CLOSE` rutint hívja. Ha a mentetlen változások eldobását elutasítod, sem a mezőzár, sem a kontextus nem változik. Sikeres bezárás után a `QM_CLOSE` a QM-indítólap állapotát is törli, majd törlődik a fejléc (stock, ikon, szöveg), az elfogadott stockazonosító, a ready/edit jelzők, hibareferencia, ideiglenes üzenet és funkciókódok; a tabstrip az első, 1010-es DM-fülre áll vissza. A DM-riport kontrolljait, betöltött adattábláit és saját stockzárját a meglévő adapterbezárás takarítja. Új stock elfogadásakor a riport szelekciói is újraépülnek.

SE41-ben a **SAPLZPR_COCKPIT / 0100** GUI-státuszba vegyél fel egy menüpontot, például **Stock → Új stock / alaphelyzet** néven:

| Beállítás | Érték |
|---|---|
| Function code | `RESET` |
| Function text / menüfelirat | `Új stock / alaphelyzet` |
| Function type | üres / normál (ne E vagy P) |

A menüpont kezdetben is használható, ilyenkor az üres kezdőállapotra áll vissza. Mentsd/aktiváld a GUI-státuszt és a módosított `LZPR_COCKPITO01` include-ot/függvénycsoportot. A 0100 flow logic változatlanul `CANCEL → PREPARE_COMMAND → CALL SUBSCREEN → USER_COMMAND`; a RESET utáni `LEAVE TO SCREEN 100` megakadályozza, hogy a régi subscreen PAI-ja a már törölt kontextusra fusson. A DM-riport és a 2026-10-18-án beépített QM-indítólap takarítása ezt a központi resetfolyamatot használja.

A SAP-ból ebben a körben visszaolvasott include-hoz képest célzott diff: `../2026-10-17_cockpit-input-lock-reset_WIP.diff`. A változás helyi WIP; SAP-ba nem írtuk és nem aktiváltuk.

Ellenőrzendő SAP-ban: üres/hibás stocknál bevihető mező; érvényes stock és FM-paraméteres indítás után zárolt mező; ismételt Enter ugyanazon stockot tartja; RESET az első/másik fülről; mentetlen és hibás cellabevitel eldobásának elutasítása és jóváhagyása; elutasításkor teljes állapotmegőrzés, jóváhagyáskor üres fejléc/ALV, első fül és feloldott stockzár; RESET üres állapotból; az új stock adatainak elkülönülése az előzőtől.

### Stockmező, állapotikon és opcionális beazonosítógomb

**Enter nem indít beazonosítást – igazolt bekötési hiány (2026-10-16):** a felhasználó visszajelzése szerint az SAP-ban aktív 0100 PAI részéből hiányzik a `MODULE prepare_command.` sor. Az új include-ban a stockazonosítást ez a modul indítja; a modul definíciójának bemásolása önmagában nem köti be a képernyőbe. SE51-ben a `SAPLZPR_COCKPIT` / 0100 folyamatlogikájának PAI része:

```abap
PROCESS AFTER INPUT.
  MODULE cancel AT EXIT-COMMAND.
  MODULE prepare_command.
  CALL SUBSCREEN t_sub_sc.
  MODULE user_command.
```

A `PREPARE_COMMAND` a `CALL SUBSCREEN` előtt ellenőrzi a stockot; a `USER_COMMAND` utána kezeli a funkciókat. Mentsd és aktiváld a 0100-as képernyőt, továbbá az új `PREPARE_COMMAND` és `ACCEPT_STOCK` definíciókat tartalmazó `LZPR_COCKPITO01` include-ot/függvénycsoportot is. A cockpitból lépj vissza, majd indítsd újra, és próbálj ki egy érvényes stockot Enterrel.

Az Enter kitöltött mező mellett akkor is PAI-t vált ki, ha nincs hozzá funkciókód rendelve. Az `ENTER` hozzárendelés az explicit kód és a közös gombkezelés miatt javasolt; a stock feldolgozásához a fenti PAI-modulhívás szükséges. [SAP: The ENTER Key](https://help.sap.com/saphelp_em92/helpdata/en/4a/44b52897311cd4e10000000a421937/content.htm?no_cache=true). A teljes új flow logic külön fájlban: `ZPR_COCKPIT_0100.flow.abap`.

Az Enter önmagában elegendő a beazonosításhoz. SE41-ben a `SAPLZPR_COCKPIT` program `0100` státuszának standard eszköztárában az Enter/zöld pipa funkciójához `ENTER` kódot kell rendelni, normál (üres) funkciótípussal, majd aktiválni. A képernyő `OK_CODE` mezőjét a `PREPARE_COMMAND` modul olvassa; a nullafeltöltés és létezésvizsgálat a `ACCEPT_STOCK` rutinban történik.

A felhasználó 2026-10-17-i pontosítása: a megadott stockazonosító **mindig teljes, 10 jegyű formában, vezető nullákkal jelenjen meg**. Példa: `123` → `0000000123`. Ez az azonosítás utáni lezárt mezőre, fülváltás utáni visszatérésre és az FM-paraméterrel indításra is érvényes.

A stockmező neve SE51-ben továbbra is `ZPRS_COCKPIT-STOCK_ID`, DDIC-ből átvett NUMC(10) stocktípussal. A mező **Program attributes / With leading zeros** jelölője **kötelezően bekapcsolandó**, megjelenítési hossza 10. SE51 → `SAPLZPR_COCKPIT` / 0100 → Layout → stockmező → Attributes → Program → With leading zeros, majd a képernyő aktiválása. A belső, kereséshez használt érték és a képernyő megjelenítési formátuma külön beállítás; a már meglévő ALPHA_INPUT hívás a belső formátumot biztosítja. [SAP: Program Attributes](https://help.sap.com/saphelp_gbt10/helpdata/en/d1/801c54454211d189710000e8322d00/content.htm?no_cache=true).

A `ZPR_DCQM_EXCLUDE` helyi változatának ALV-címéből a `SHIFT lv_stokid LEFT DELETING LEADING '0'.` sor eltávolítva; a cím is a teljes azonosítót kapja. Ez kizárólag megjelenítési változás. A képernyő SE51-attribútuma nem módosítható az ebben a munkamenetben elérhető ADT-eszközökkel, ezért annak SAP-beli bekapcsolása/aktiválása még szükséges. A helyi riportmódosítást sem írtuk SAP-ba.

A meglévő `GET_STOCK_HEADER` az `ICON` és `TEXT` fejlécmezőt is tölti. A helyi forrás szerinti értékek:

| Stock STATUS | Állapotikon | Jelentés |
|---|---|---|
| üres | `ICON_OPEN_FOLDER` | Nyitott |
| DM | `ICON_CHECKED` | DM-jóváhagyás megtörtént |
| QM | `ICON_RELEASE` | QM-jóváhagyás megtörtént |
| CL | `ICON_CLOSED_FOLDER` | Lezárva |

Ez megjelenített állapotikon. A 0100 layoutban a hozzá tartozó kimeneti mező neve `ZPRS_COCKPIT-ICON` legyen, **With icon** jelölővel; a státuszszövegé `ZPRS_COCKPIT-TEXT`. Mindkettő kimeneti mező, ne legyen bevihető; az ikont ne helyettesítse a beazonosítógomb. A módosított kód továbbra is a teljes visszaadott fejlécet veszi át. Ha az ikon hiányzik, az aktív képernyőn a mezőnevet és az ikonmegjelenítést kell ellenőrizni; a tényleges layout nincs exportálva.

Opcionális kattintható gombhoz SE51 → `SAPLZPR_COCKPIT` / 0100 → Layout:

1. Helyezz el egy **Pushbutton** elemet a stockmező mellett, az állapotikonnak külön helyet hagyva.
2. Az attribútumai legyenek az alábbiak. Az ikon nevét az ikonválasztóval is kiválaszthatod.

| Attribútum | Érték |
|---|---|
| Name | `BTN_STOCK_CHECK` (új képernyőelem) |
| Text | `Beazonosítás` |
| Icon name | `ICON_OKAY` |
| Function code | `ENTER` |
| Function type | üres / normál; ne E legyen |
| Quickinfo | `Stock beazonosítása` |

3. Mentsd és aktiváld a képernyőt és a GUI-státuszt. A feliratot és quickinfót a képernyő szövegeivel együtt fordítsd/transzportáld.

A gombhoz nem kell külön ABAP eseménykezelő: a `ENTER` kód ugyanarra a PAI-útra kerül, mint a billentyű. [SAP: Using GUI Statuses](https://help.sap.com/saphelp_em92/helpdata/en/4a/44b52897311cd4e10000000a421937/content.htm?no_cache=true), [SAP: Using Icons](https://help.sap.com/saphelp_aii710/helpdata/en/d1/801bf9454211d189710000e8322d00/content.htm?no_cache=true).

A subscreen PBO-ja nem állíthat GUI-státuszt/címsort és nem válthat képernyőt; ezt a főképernyő kezeli. [SAP: Subscreens](https://help.sap.com/saphelp_gbt10/helpdata/EN/4a/44b362954c0453e10000000a421937/content.htm?no_cache=true). A tabstrip és subscreen-terület külön resizing attribútumot kap. [SAP: Tabstrip Controls](https://help.sap.com/saphelp_gbt10/helpdata/EN/4a/44b861954c0453e10000000a421937/content.htm?no_cache=true).

## Nyitott, tényleges forrástalálatok

- A riport kiinduló exportjában az első szelekció `PACKAGE-STOCK_ID` szerint kapcsol, a borítékbővítés és a mentési UPDATE viszont `DCQM-PRD_STOCK_ID`-t használ. Ezt a cockpit-adapter nem írja át. A két kapcsolat egyezését igazolni vagy külön javítani kell; eltéréskor kimaradhatnak sorok, illetve a mentés hibát adhat.
- A cockpit meglévő `CLOSE` ága közvetlenül `UPDATE_STATUS('CL')`-t hív. A lezárási riport/Inspire-művelet összehangolása külön feladat, itt nem módosult.
- Az aktív DDIC, a 0100/1010 layout, a GUI-státusz, a szövegkészlet, a report/tranzakció-hozzárendelés és a jelenlegi include-tartalmak visszaolvasása még szükséges. Az előkészített forrás nem minősül élesítésre késznek.

## Ellenőrzés és célzott SAP-próba

A helyi ellenőrzés eredménye a `HELYI-ELLENORZES_WIP.json` fájlban van. Az ABAP-szerkezeti, hívás-/paraméterszám-, modul-/include- és diffellenőrzés nem helyettesíti az SAP-fordítást, ATC-t és működési próbát.

SAP-ban ellenőrizendő: indítás paraméter nélkül/érvényes/hibás stockkal; Enter és üres input; A→B stockváltás; mentetlen és hibás cellabevitel megtartása/eldobása; mentés után maradás az első fülön; fülváltás és visszatérés; lezárt/DC-kész stock; más felhasználó stockzárja; jogosulatlan belépés; kilépés utáni zárfeloldás; keskeny/széles SAP GUI; önálló riportút. Ezután fordítás és QA/ATC szükséges.

A nullafeltöltéshez és az ikonhoz külön próba: `123` és `0000000123` ugyanazt a stockot azonosítsa; ugyanannak a stocknak eltérő írásmódja ne indítson stockváltást; a 10 jegyű érték változatlan maradjon; üres/0 bemenet és nem létező stock ne induljon; Enter és a gomb azonos eredményt adjon; a négy stockállapothoz megfelelő ikon/szöveg jelenjen meg. A kötelező `With leading zeros` beállítás után a képernyőn és a DM-lista címében is `0000000123` legyen látható, lezárt inputnál, fülváltás után és FM-paraméteres indításkor is. RESET után ne maradjon elfogadott stock; a numerikus mező kezdeti értéke akkor sem tekinthető stockazonosításnak, ha az SE51-formázás nullákkal jeleníti meg.
