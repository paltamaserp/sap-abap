# ZPR_STOCK_REPORT bemásolása DHC-ba

Státusz: WIP. A kód csak helyi fájlokban készült; SAP-ban nem történt létrehozás, módosítás, fordítás, aktiválás vagy teszt. A kapcsolatot a felhasználói leállási szabály miatt nem használjuk.

## Elfogadott működés

A felhasználó 2026-10-13-i pontosítása szerint a lezárás üzleti feltétele **`STATUS = QM`**. Siker után **`STATUS = CL` és `CLOSED = X`** kerül mentésre, a választott prioritással és a lezárási/módosítási dátum, idő, felhasználó mezőkkel együtt. A `CLOSED = X`, `STATUS = CL` és `STOCK_STATUS_ER = X` állapot tiltja az új lezárást. A DC/QM-jelzők az F4-listában láthatók, a lezárás feltételét a `STATUS` adja.

A ragszámkezelés a felhasználó döntése szerint marad a QU5-ös útvonalon: `ZPR_TERTI` → `ZISU_F064`. A kód a DHC-adatok `DOC_NO` mezőjét a `ZPR_TERTI-EXBILLDOCNO` mezőjéhez illeszti; a boríték kulcsa `ENVELOPE` → `ENVELOPE_ID`.

A riport önálló belépési pont. A meglévő `ZCL_PR_STOCK` és a cockpit kódját nem módosítja. A cockpit régi, közvetlen `UPDATE_STATUS` lezárási ága külön munka marad; a riport ellenőrzéseit egy másik belépési pont puszta státuszmentése nem biztosítja.

### A fájlalapú szelekció helyettesítése

QU5-ben a stockhoz tartozó fájlneveket a `ZEBFT_PR_MSSFILE` táblából olvassa a riport, és ezek `FILENAME` értékével szűri a DCQM-sorokat. Ha nincs fájlregisztráció, a QU5-kód `e051` üzenettel leáll. DHC-ban a helyi `ZPRT_DCQM` export nem tartalmaz `FILENAME` mezőt, viszont tartalmaz `PRD_STOCK_ID`-t; ezért a korábbi DHC-tervnek megfelelően a generált riport közvetlen stockszűrést használ.

Ez a fájl–dokumentum kapcsolat kiváltására épített feltételezés, nem igazolt üzleti egyenértékűség. A DHC-kód a stockazonosítóval már ellátott összes dokumentumot számolja; nem ellenőrzi külön a nyomtatási fájl regisztrációjának meglétét. Igazolni kell, mikor és milyen feltétellel töltődik a `PRD_STOCK_ID`, és egy hiányzó/hiányos fájlregisztráció mellett is lehet-e ilyen sor. Ha a fájl megléte külön lezárási előfeltétel, a DHC megfelelő fájl-/csomagregisztrációs objektuma alapján külön ellenőrzést kell beépíteni. A `PRDFILE` CHAR 4 mező nem tekinthető automatikusan a QU5 CHAR 100 `FILENAME` megfelelőjének.

Ezt a kérdést a felhasználó 2026-10-13-án külön felvetette. A magyarázat alapján kódmódosítás nem történt; a megfelelő DHC regisztrációs objektum és az adatfeltöltési folyamat még nincs megadva.

## Másolandó fájlok

| Helyi fájl | SAP cél |
|---|---|
| [ZPR_STOCK_REPORT.abap](ZPR_STOCK_REPORT.abap) | SE38/ADT: `ZPR_STOCK_REPORT` végrehajtható program |
| [ZPR_STOCK_REPORT_O01.abap](ZPR_STOCK_REPORT_O01.abap) | `ZPR_STOCK_REPORT_O01` include |
| [ZPR_STOCK_REPORT_I01.abap](ZPR_STOCK_REPORT_I01.abap) | `ZPR_STOCK_REPORT_I01` include |
| [ZPR_STOCK_REPORT_0100_flow.abap](ZPR_STOCK_REPORT_0100_flow.abap) | SE51: a főprogram 0100 képernyőjének flow logicja |

Csomag a programokhoz: `ZPR_FUNC`. Az esetleg hiányzó DDIC-objektumok csomagja: `ZPR_DDIC`. A transport a projekt fejlesztési kérelme; a konkrét szám nincs megadva.

## Függőségek

A kód a helyi DHC-exportok típusait használja. Aktiválás előtt ezek aktív megléte szükséges:

- `ZPRT_STOCK`: `STOCK_ID`, `STATUS`, `CLOSED`, `DCCOMPL`, `QMCOMPL`, `PRIORITY`, `NOTEST`, `STOCK_STATUS_ER`, `ERDAT_CLO`, `ERNAM_CLO`, `ERTIM_CLO`, `CHUSER`, `CHDATE`, `CHTIME`.
- `ZPRT_DCQM`: a szelekcióhoz `PRD_STOCK_ID`, `BLOCK_DC`, `BLOCK_QM`; a megjelenítéshez a meglévő üzleti mezők; `DOC_NO`, `ENVELOPE`, `REGMAILNUMBER` a ragszámkapcsolathoz.
- `ZPRT_DCQMLT`: `EXBILLDOCNO`, `BLOCK_DC_TEXT`, `BLOCK_QM_TEXT`. Az `EXBILLDOCNO = DOC_NO` leképezés szándékos.
- `ZPRS_DCQM_REPORT`: a korábbi [39 komponensű mezőlista](2026-10-08_zprs-dcqm-report-letrehozas_WIP.md), a helyes `DOC_NO` és `PRD_STOCK_ID` komponensekkel. A `COUNTER`, `CHANGED`, `HANDLE_STYLE` mező is kell.
- `EZPRT_STOCK` zárobjektum és a generált `ENQUEUE_EZPRT_STOCK` / `DEQUEUE_EZPRT_STOCK`, `STOCK_ID` paraméterrel. A riport `_SCOPE = 1` zárolást és saját zárjelző alapján feloldást használ. A DC/QM/cockpit módosítóknak ugyanazzal a stockzárral kell együttműködniük.
- Proxy: `ZPR_CO_EON_DCQMCOMPLETED_PORT`, metódus: `EON_DCQMCOMPLETED`.
- Proxy-adattípusok: `ZPR_EON_DCQMCOMPLETED_REQUEST2`, `ZPR_EON_DCQMCOMPLETED_RESPONSE`, `ZPR_EON_DCQMCOMPLETED_REQU_TAB`, `ZPR_EON_DCQMCOMPLETED_REQUEST1`. A kérésben `EXCLUDE_ENVELOPES-ENVELOPE`, a sorban `ENVELOPE_ID` szükséges; a válaszban `PARAMETERS-SUCCESS`, `ERROR_CODE`, `INFO`.
- `ZCL_PR_OUTPUT_MANAGEMENT=>GET_LOGICAL_PORT_NAME()`, a fenti proxyhoz beállított DHC logikai porttal. A riport nem kér és nem tárol jelszót.
- `ZCL_PR_LOG` konstruktor: `IV_LOG_OBJECT`, `IV_LOG_SUBOBJECT`; metódusok: `ADD_SYSTEM_MESSAGE()`, `CLOSE()`, `DISPLAY()`. Az osztálytól a helyi DHC-forrásban látott szignatúrát várjuk; a `CLOSE()` mentési viselkedését aktívan nem ellenőriztük.
- SLG0: `ZPR_MASS` naplóobjektum és `STOCK` alobjektum.
- SE91: `ZPR` 000 üzenet, szövege `& & & &`. A riport csak ezt a meglévő általános üzenetet használja; a DC-hez már kiosztott 045–066 számokat nem módosítja.

### Ragszámtáblák

Mindkét tábla transzparens és mandantfüggő legyen. Elvárt mezők:

| Tábla | Mező | Típus / hossz |
|---|---|---|
| `ZPR_TERTI` | `MANDT` | CLNT 3 |
| `ZPR_TERTI` | `ENVELOPE_ID` | CHAR 9 |
| `ZPR_TERTI` | `EXBILLDOCNO` | CHAR 20 |
| `ZPR_TERTI` | `ZISU_RAGSZAM_128` | CHAR 16 |
| `ZISU_F064` | `MANDT` | CLNT 3 |
| `ZISU_F064` | `ZISU_RAGSZAM` | CHAR 16 |

A `ZPR_TERTI` mezői a most rendelkezésre álló QU5-exportból származnak. A `ZISU_F064` mezőhosszát nem kaptuk meg külön exportban; CHAR 16 a TERTI-ragszám alapján ellenőrizendő előfeltétel. Eltérő tényleges típus esetén a cél táblát nem kell vakon átalakítani: a riport lokális típusát és a `CHECK_REGMAIL_TABLES` ellenőrzést kell a jóváhagyott definícióhoz igazítani.

A táblanevek fix programkonstansok. A dinamikus táblahivatkozás miatt a két ragszámtábla hiánya nem okoz statikus függőséget a fordításnál; kizárt sorok esetén a riport **még az Inspire-hívás előtt** megáll, ha a szükséges aktív tábla vagy mező nem megfelelő. A táblák tartalmát a kód nem hozza létre.

Az összes matching TERTI-ragszám összegyűjtésre kerül, majd a törlés boríték + dokumentum + ragszám szerint történik. Üres ragszám nem kerülhet törlési feltételbe. Ha a DCQM-ban van ragszám, de nincs hozzá TERTI-rekord, a lezárás megáll. Hiányzó F064-rekord elfogadott, mert a TERTI-export külön feltöltési jelzőt is tartalmaz; az SQL-hiba viszont rollbacket okoz. A DCQM `REGMAILNUMBER` mezőjét a QU5 főprogramhoz hasonlóan ez a riport nem törli.

## Bemásolási sorrend

1. Ellenőrizd / aktiváld a szükséges DDIC-objektumokat, a zárobjektumot, proxy- és naplófüggőségeket.
2. Hozd létre a két include-ot, és másold be a megfelelő `.abap` fájl teljes tartalmát.
3. Hozd létre a főprogramot `ZPR_STOCK_REPORT` néven, típusa **végrehajtható program**, üzenetosztálya `ZPR`; másold be a főprogram teljes tartalmát.
4. Hozd létre a 0100 képernyőt, a GUI-státuszt és címsorokat az alábbiak szerint.
5. Vedd fel a szövegelemeket és a `ZPR_STOCK` tranzakciót.
6. Futtasd a SAP-szintaxisellenőrzést, aktiválj, majd végezd el a kijelölt tesztstockos funkcionális ellenőrzést. A helyi eredmény nem helyettesíti a SAP-fordítást.

## SE51 0100 képernyő

- Program: `ZPR_STOCK_REPORT`; képernyő: `0100`; típus: **normál**; következő képernyő: `0100`.
- Az OK típusú elem neve pontosan **`GV_OKCODE_0100`** legyen. Ez technikai OK-mező, nem látható beviteli mező.
- Felül output-only mezők és mellettük statikus feliratok:

| Képernyőmező | Felirat |
|---|---|
| `GS_STOCK-STOCK_ID` | Stock azonosító |
| `GS_STOCK-STATUS` | Státusz |
| `GV_TOTAL` | Nyomtatási sorok száma |
| `GV_EXCLUDED` | Kizárt sorok száma |
| `GV_ALLOWED` | Engedélyezett sorok száma |
| `GV_BLOCK_REASON` | Megjelenítő mód oka |

- A mezők legyenek csak megjelenítésre használhatók. A `GV_BLOCK_REASON` legfeljebb 120 karakter.
- A fejléc alatt custom control: **`ALV_CONTAINER_01`**, kitöltve a maradék képernyőt, vízszintesen és függőlegesen átméretezhetően.
- Flow logic: a [képernyőfájl](ZPR_STOCK_REPORT_0100_flow.abap) `PROCESS BEFORE OUTPUT` sorától a végéig.
- A képernyőt és a programot együtt aktiváld.

## SE41 és szövegelemek

GUI-státusz: **`STAT_0100`**.

| Funkciókód | Billentyű | Funkciótípus |
|---|---|---|
| `BACK` | F3 | E |
| `EXIT` | Shift+F3 | E |
| `CANCEL` | F12 | E |
| `REFRESH` | például F5 | normál |

Az **Engedélyezés** gombot a riport az ALV toolbarra teszi; funkciókódja `RELEASE`. Ezt ne vedd fel külön GUI-státuszgombként. A riport az engedélyezés feltételeit a gombkezelőben is ellenőrzi.

Az ALV `I_APPL_EVENTS = X` beállítással készül, a PAI-ban a `USER_COMMAND_0100` rutin `CL_GUI_CFW=>DISPATCH` hívása dolgozza fel az eseményt. Így a művelet után PBO frissíti a képernyő fejlécmezőit is. Az eseményt csak egyszer szabad dispatcholni. Forrás: [SAP ALV eseménykezelés](https://help.sap.com/docs/ABAP_PLATFORM_NEW/70396d7dec4c4f19b9ca3b2e47559d12/4ebd16291041389ee10000000a421937.html), [SAP dispatch dokumentáció](https://help.sap.com/docs/SAP_NETWEAVER_700/12a9d91a6c53101489a69be2cd91f0df/4d70c532a9e24cb2e10000000a42189c.html).

Címsorok:

- `TITLE_0100_MOD`: `Stock engedélyezése és lezárása`
- `TITLE_0100_DISP`: `Stock és kizárt nyomtatási sorok megjelenítése`

Szövegszimbólumok:

- `001`: `Stock kiválasztása`
- `002`: `ALV-elrendezés`

Szelekciós szövegek:

- `P_STOKID`: `Stock azonosító`
- `P_VARI`: `ALV-elrendezés`

A stock F4-et a program saját értéklistával biztosítja, legfeljebb 5000 stockkal, azonosító szerint csökkenő sorrendben. Új stock-keresési segítség nem szükséges ehhez a riporthoz. A megadott ALV-variáns bekerül az `IS_VARIANT-VARIANT` mezőbe; QU5-ben ez a hozzárendelés hiányzott.

## SE93 és jogosultság

Javasolt tranzakció: **`ZPR_STOCK`**, típus: program és szelekciós képernyő, program: `ZPR_STOCK_REPORT`, szelekciós képernyő: `1000`.

A riport `S_TCODE` ellenőrzést végez erre a tranzakcióra indításkor és engedélyezéskor is, így közvetlen SE38-indításnál is ezt várja. Más jóváhagyott tranzakciónév esetén a főprogram `GC_TCODE` konstansát és az SE93-beállítást együtt módosítsd. Projekt-specifikus üzleti jogosultsági objektumot nem kaptunk; szükség esetén annak ellenőrzése is beépítendő.

## Hibakezelés és újrapróbálás

- A `SEND_PRIORITY` belépéskor hibásnak tekinti az eredményt. Csak `PARAMETERS-SUCCESS = X` válasz állítja sikeresre. A logikai port meghatározásának vagy a proxy létrehozásának hibája után nincs ragszámtörlés és stocklezárás.
- A prioritás/igenlő megerősítés után stockzár következik. A stock, a darabszám és a kizárási lista a zár alatt újraolvasásra kerül. Ha a megjelenített lista megváltozott, új jóváhagyás szükséges; az adott kísérlet nem hívja az Inspire-t.
- A stockhoz tartozó üres borítékazonosítóval kizárt dokumentumot a riport nem küldi az interfészre. Ezt az adatot előbb rendezni kell.
- A ragszámok ellenőrzése a külső hívás előtt történik, és a sikeres külső válasz után újra összevetjük őket a törlési listával. Az együttműködő íróknak ugyanazt a stockzárat kell használniuk.
- A ragszámtörlések és a stockmentés közös helyi LUW-ban történnek; hibánál rollback. A `ZCL_PR_STOCK=>UPDATE_STATUS` saját commitja nem kerül a folyamat közepére.
- Ha a külső hívás már elindult, de kivétellel zárult, vagy a külső siker után a helyi mentés elbukott, a stock **`STOCK_STATUS_ER = X`** jelzést kap. Ettől a stock nem lesz lezárt, de a riport tiltja az újraküldést.
- A hibajelzőt csak az Inspire tényleges állapotának tisztázása és a helyi/külső állapot rendezése után szabad feloldani. A riportnak nincs automatikus visszanyitási vagy hibajelző-törlési gombja. Ha a hibajelző mentése is elbukik, az adott riportfutásban a tiltás megmarad, a napló/státusz pedig kéri, hogy a stockot ne küldjék újra ellenőrzés nélkül.
- A SAP rollback a külső rendszer műveletét nem vonja vissza. Külső idempotencia-szerződés vagy állapotlekérdezés nélkül a riport ezt a bizonytalan állapotot megjelöli és leállítja.
- A naplózás a helyi üzleti commit/rollback után történik. Naplóhiba esetén a sikeres stocklezárást nem állítjuk sikertelennek, de külön hibát jelez a státuszsor.
- A `NOTEST` jelző megjelenik a naplóban, a proxykérésben nem képez új mezőt; a teszt/éles útvonalat a tényleges logikai port határozza meg.

## Ellenőrzés

### Ha a 0100 képernyő vagy az ALV nem jelenik meg

Első breakpoint a főprogram `CALL SCREEN 0100` sorára. Ha nem jut el ide, a `START-OF-SELECTION` korai kilépéseit kell vizsgálni: `SY-BATCH`, az `S_TCODE` ellenőrzés `SY-SUBRC` értéke, a `READ_STOCK` és a `SELECT_DATA` utáni `GV_ERROR`. A riport SE38-indításnál is `ZPR_STOCK` tranzakciójogosultságot ellenőriz. Jogosultsági hiba esetén a státuszsor üzenete és az SU53 ellenőrzése szükséges; az ellenőrzést nem kell vakon eltávolítani.

Ha eléri a `CALL SCREEN` sort, breakpoint következzen a `STATUS_0100` és a `CREATE_CONTROLS_0100` PBO-modulra, majd a `CREATE_CONTROLS_0100` FORM-ra. SE51-ben a `ZPR_STOCK_REPORT` saját 0100 képernyője legyen aktív, normál típusú, a fenti PBO-val és `ALV_CONTAINER_01` nevű valódi Custom Control elemmel. A flow logic önmagában nem rajzolja meg a konténer területét; azt a Layoutban létre kell hozni. SE41-ben a `STAT_0100` és a két címsor legyen aktív.

A FORM-ban ellenőrizendő: belépéskor `GO_GRID` kezdeti referencia-e; a konténer létrehozása után `SY-SUBRC = 0` és `GO_CONTAINER IS BOUND`; a mezőkatalógus-függvény után `SY-SUBRC = 0` és `LT_FIELDS` nem üres; a `SET_TABLE_FOR_FIRST_DISPLAY` után `SY-SUBRC = 0`. Dump esetén az ST22 adata adja a konkrét hibát.

Az ALV csak a DC-ben vagy QM-ben kizárt dokumentumokat tartalmazza. Az üres `GT_ALV` ezért lehet helyes eredmény; a helyi kód ettől még meghívja a képernyőt. A stock QM státusza a lezárásgombot szabályozza, nem a képernyő megjelenítését. A futásidejű ok nincs igazolva; csak diagnosztikai útmutatót adtunk, ABAP-kódmódosítás nélkül.

Helyi vizsgálatok és eredményeik a [helyi ellenőrzési jegyzetben](../../02_NOTES/2026-10-13_stock-report-dhc-helyi-ellenorzes_WIP.md) szerepelnek. SAP-szintaxisellenőrzés, ATC, ABAP Unit és funkcionális teszt nem futott. A WIP státuszt az aktív függőségek és a tesztek ellenőrzése után lehet továbbléptetni.

Minimum funkcionális ellenőrzés:

1. Nyitott/DM/CL stock: megjelenítés, engedélyezés tiltva. QM stock: engedélyezés elérhető, ha nem lezárt és nincs hibajelző.
2. F4, kiválasztott ALV-variáns, fejléc és `COUNTER = 1` sorösszegzés.
3. Csak DC-kizárás, csak QM-kizárás, több dokumentum egy borítékban: teljes és duplikációmentes borítéklista.
4. Proxy-létrehozási hiba: nincs külső hívás, ragszámtörlés, stocklezárás vagy bizonytalanállapot-jelző.
5. Külső üzleti elutasítás: nincs helyi lezárás. Hívás közbeni kivétel: nincs helyi lezárás, az újraküldés tiltva.
6. Külső siker és helyi mentési hiba: rollback és `STOCK_STATUS_ER = X`; újraküldés tiltva.
7. Siker: a ragszámrekordok és a stockmezők egyeznek az elvárt eredménnyel; napló az SLG1 `ZPR_MASS / STOCK` alatt.
8. Zárütközés, a megjelenítés óta megváltozott adatok, prioritáspopup megszakítása: nincs külső hívás.
9. Hibás/hiányzó ragszámtábla, üres boríték, ragszám–TERTI eltérés: megállás az Inspire-hívás előtt.
