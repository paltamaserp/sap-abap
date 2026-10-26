# DC keretprogram – helyi átviteli csomag

Dátum: **2026-10-22** · Státusz: **WIP** · Célobjektum: **ZPR_DC_FRAME**, végrehajtható riport.

A kért QU5 `ZEBF_PR_DC_FRAME` négy műveletét a helyi DHC objektumokra illesztettük. A közvetlen munkabázis a projektben kijelölt [2026-10-17-i ZPR_DC_FRAME](../../05_FINAL/abap-2026-10-17/ZPR_DC_FRAME.abap); ez már tartalmazza a DHC név-/üzenet-/adatmodell-átvezetést és a zár utáni állapotellenőrzést. Az [eredeti QU5 forrás](../../01_SOURCES/QU5/ZEBF_PR_DC_FRAME.abap) és a mentett DHC-forrás változatlan. A célobjektum nevét a meglévő DHC-megfelelő adja; az eredeti tükrözött objektumot nem neveztük át.

Ez kézzel átvezethető **forráscsomag**, nem SAP-ból exportált CTS-transzport vagy automatikus importfájl. Minden munka helyben történt; SAP-objektumot, tranzakciót és konfigurációt nem módosítottunk.

## Fájlok

| Fájl | Tartalom |
|---|---|
| [ZPR_DC_FRAME.abap](ZPR_DC_FRAME.abap) | Teljes, önálló keretprogram-forrás |
| [ZPR_DC_FRAME.texts.tsv](ZPR_DC_FRAME.texts.tsv) | Riportcím, három szövegszimbólum és öt szelekciós szöveg kézi karbantartásához |
| [ZPR.messages.tsv](ZPR.messages.tsv) | A keret által használt 12 ZPR T100-üzenet |
| [DHC-valtozasok_WIP.diff](DHC-valtozasok_WIP.diff) | Eltérés a kijelölt DHC-forráshoz képest |
| [QU5-DHC-atultetes_WIP.diff](QU5-DHC-atultetes_WIP.diff) | Teljes eltérés az eredeti QU5-forráshoz képest |
| [validation.json](validation.json) | A tényleges helyi ellenőrzés eredménye és korlátai |
| [manifest.json](manifest.json) | Bemeneti és csomagfájlok SHA256-jegyzéke |

A diffek alternatív kiindulásokhoz tartoznak, nem egymás után alkalmazandók. Mindkettő `ZPR_DC_FRAME.abap` munkafájlt céloz. A QU5-diffhez az eredeti QU5-tartalom külön munkamásolatát kell e néven előkészíteni; a megőrzött QU5-forrásra helyben ne alkalmazd.

## Működés

| Választás | Eredmény |
|---|---|
| Nyomtatási sorok kizárása | `SUBMIT ZPR_DCQM_EXCLUDE`, a stockkal és `P_MODIF = X` értékkel, szelekciós képernyőn keresztül |
| Nyomtatási sorok megtekintése | Ugyanez `P_MODIF = space` értékkel |
| DC engedélyezés | Saját stockzár, friss visszaolvasás, `DCCOMPL = X`, `CHUSER/CHDATE/CHTIME` frissítés |
| DC engedélyezés visszavétele | Ugyanez `DCCOMPL = space` értékkel |

A már megfelelő DCCOMPL állapotnál nincs ismételt UPDATE. Lezárt stocknál csak megtekintés engedett; kész DC esetén a módosító mód tiltott. A zár `_SCOPE = '1'` értékkel a dialógusé, az üzleti COMMIT után explicit felszabadítás történik, a naplóablak előtt. Az UPDATE eredménye és az egy módosított rekord ellenőrzött. A `CRUSER/CRDATE/CRTIME` létrehozási adatok megmaradnak.

A keret az eredeti DC-jelzőt kezeli: **a STATUS mezőt nem állítja DC-re vagy más státuszra**, QMCOMPL/CLOSED/prioritás/lezárási bélyegző változtatása és Inspire-hívás sincs benne. A cockpit STATUS-alapú munkafolyamata külön mechanizmus; a két modell összehangolása nem része ennek az átültetésnek.

## Átvezetés és helyi módosítások

| QU5-függőség | DHC-megfelelő / megoldás |
|---|---|
| ZEBFT_PR_STOCK / ZEBFD_PR_STOCK_ID | ZPRT_STOCK / ZPRD_STOCK_ID |
| ZEBF_PR_DCQM_REPORT | ZPR_DCQM_EXCLUDE, azonos P_STOKID/P_MODIF bemenetekkel |
| ENQUEUE/DEQUEUE_EZEBFT_PR_STOCK | ENQUEUE/DEQUEUE_EZPRT_STOCK |
| ZEBF_PR üzenetosztály régi DC-számai | ZPR 045/046/050–057/062, és a meglévő 000 |
| ZEBFT_PR_MSSFILE → FILENAME → ZEBFT_PR_DCQM | Közvetlen ZPRT_DCQM-olvasás PRD_STOCK_ID szerint, két COUNT a BLOCK_DC állapotára |
| Stock keresési segítség | Saját F4 a ZPRT_STOCK táblából, azonosító szerint csökkenő sorrendben, legfeljebb 5000 sorral |
| ZEBF_PR / Z_DC naplóobjektum | A DHC-alap szerinti ZPR_MASS / DC |

A naplózás a felhasználó által kijelölt [FINAL/ZPR_CREATE_STOCK.abap LOG_WRITE rutinját](../../05_FINAL/abap-2026-10-17/ZPR_CREATE_STOCK.abap:758) követi: `ZCL_PR_LOG` konstruktor `IV_LOG_OBJECT`/`IV_LOG_SUBOBJECT` paraméterrel → `ADD_SYSTEM_MESSAGE` → `CLOSE` → `COMMIT WORK` → `DISPLAY`. A generáló script ebből a rutinból indul, csak a keret FORM-paramétereit, a helyi változóneveket, a DC-alkonstans nevét és a fordítható 102-es hibaszöveget illeszti. A `CX_ROOT` kivételkezelés és a naplózási hibajelző is megmarad. A naplózási hibát a záró sikerüzenet nem írja felül. A BAL-üzenettáblák feltöltése `INSERT ... INTO TABLE` utasítással történik.

A kijelölt referenciában a fájlnév és a programdeklaráció eltér: `ZPR_CREATE_STOCK.abap` első sora `REPORT ZPR_CLOSE_STOCK`. A fájlt változatlanul hagytuk, és kizárólag a LOG_WRITE mintát használtuk fel. A referenciában nincs stock-EXTNUMBER átadás; ilyet a DC-keret sem feltételez. A naplóosztály implementációja és az aktív SAP-szignatúra nincs visszaolvasva; a hívás a kijelölt helyi FINAL-mintával egyezik.

A stock-F4-hez nincs szükség külön `ZPRH_STOCK` keresési segítségre. A cím szövegszimbólumban van. Az eredeti kép feliratait a mellékelt szöveglista tartalmazza.

## Szükséges célrendszeri objektumok

- **ZPRT_STOCK**: STOCK_ID, STATUS, CLOSED, DCCOMPL, QMCOMPL, CHUSER, CHDATE, CHTIME; a ZPRD_STOCK_ID adatelem és a tábla saját DDIC-függőségei. A helyi definícióban a kulcs MANDT + STOCK_ID.
- **ZPRT_DCQM**: PRD_STOCK_ID és BLOCK_DC; a helyi újabb definíció kulcsa MANDT + GUID. A stock szerinti COUNT hozzáférés indexét/SQL-tervét a célrendszerben kell ellenőrizni. Az adatokat nem szűkítettük további üzleti feltétellel.
- **EZPRT_STOCK** zár és a generált ENQUEUE/DEQUEUE moduljai, STOCK_ID paraméterrel.
- **ZPR_DCQM_EXCLUDE** működő riport a saját DDIC-, include-, GUI- és képernyőfüggőségeivel. [Helyi forrás](../../05_FINAL/abap-2026-10-17/ZPR_DCQM_EXCLUDE.abap). Ezeket a meglévő objektumokat ez a csomag nem másolja vagy módosítja. A keretnek saját 0100 dynproja és SE41 státusza nincs; az 1000-es szelekciós képernyő generált.
- **ZPR** üzenetosztály a TSV szerinti szövegekkel. A helyi régi ZPR.message csak 000–044-et tartalmaz; a 045 feletti DC-üzenetek megléte nincs élőben igazolva. Meglévő eltérő szöveget ne írj felül: előbb össze kell hangolni a sorszámot és a kódkonstanst.
- **SLG0: ZPR_MASS / DC** alkalmazásnapló-objektum/alosztály és a használatához szükséges célrendszeri beállítások.
- **ZCL_PR_LOG** meglévő naplóosztály a kijelölt FINAL-minta szerinti konstruktorral és ADD_SYSTEM_MESSAGE/CLOSE/DISPLAY metódusokkal. Az osztályt ez a csomag nem hozza létre vagy módosítja.

## Kézi átvezetési sorrend

1. Hasonlítsd össze a cél aktív `ZPR_DC_FRAME` forrását a DHC-alappal és a diffünkkel; a cél saját újabb módosításait őrizd meg.
2. Ellenőrizd a fenti DDIC-, zár-, alriport-, ZCL_PR_LOG- és SLG0-függőségeket. A keret a meglévő naplóosztályt használja; külön stock-keresési segítségre nincs szükség.
3. SE38/ADT alatt a meglévő `ZPR_DC_FRAME` objektumba vezesd át a forrást. Új objektum esetén végrehajtható riport, Standard ABAP, a projekt célcsomagja szükséges; a mentett DHC-metaadat csomagja `ZPR_FUNC`.
4. A szöveg-TSV alapján kézzel vedd fel/ellenőrizd a riportcímet, a 001/101/102 szövegszimbólumot és a P_* szelekciós szövegeket, magyar nyelven. A TSV nem automatikus SAP-import.
5. SE91-ben ellenőrizd/egészítsd ki a mellékelt üzeneteket. A keret listája nem tartalmazza az alriport összes további üzenetét; ahhoz a meglévő 045–066-os DC-üzenetcsomag szükséges lehet.
6. Futtass SAP-szintaxisellenőrzést és a cél szerinti ATC/SCI-t. Ha külön indítótranzakció szükséges, SE93-ban riporttranzakcióként a `ZPR_DC_FRAME` / 1000 célra kell kötni, a meglévő névhasználat ellenőrzésével. E csomag tranzakciót nem hoz létre.
7. A riportot, szövegkészletét és a ténylegesen új/módosított előfeltételeket a megfelelő transportba vedd fel, függőségi sorrendben.

## Ellenőrzés és hátralévő célrendszeri próba

Az ellenőrzés a két eredeti fájl változatlanságát, a függőség- és mezőillesztést, a DCCOMPL/CH* UPDATE hatókörét, a négy művelet megmaradását, a T100-/szövegreferenciákat, a zárolást és mindkét diff bájtpontos előre/vissza alkalmazását vizsgálja. Az eredmény a validation.json fájlban szerepel. Új ABAP Unit-teszt nem készült; az adatbázis- és GUI-működés helyi futtatókörnyezet nélkül nem igazolható.

SAP-fordítás, ATC/SCI és GUI-próba nem futott; az aktív célrendszeri állapot nincs ellenőrizve. A célban ellenőrizendő: mind a négy választás és visszalépés; ismeretlen/lezárt/kész DC stock; más felhasználó zárja; az F4 kiválasztása és megszakítása; sikeres engedélyezés/visszavétel után DCCOMPL és CH* változása, CR* megőrzése; a napló megjelenítése és a ZPR_MASS/DC napló mentése helyes darabszámokkal. A módosító próbákhoz elkülönített tesztstock szükséges.

Az üzleti mentés és a naplómentés külön COMMIT. Naplózási vagy megjelenítési hiba **nem vonja vissza a már sikeres DCCOMPL-mentést**; ilyen esetben az állapotot és az SLG1-naplót ellenőrizni kell. A darabszámok a zár feloldása utáni állapotot mutatják, a DHC-alap működésével egyezően. A riport dialoghasználatra készült.

Újragenerálás és ellenőrzés Node.js-szel a csomagmappában: `node build.cjs`, majd `node check.cjs`. Windows sandboxban a Node indításához szükség lehet a `--preserve-symlinks-main --preserve-symlinks` kapcsolókra. Helyi ABAP-parser opcionálisan a `check.cjs` első argumentumaként adható meg; alapból a forrás-/DDIC-/diffellenőrzések futnak.
