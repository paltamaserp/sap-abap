# 1 A megoldás célja és fogalmai

A tömeges nyomtatási megoldás a már elkészített dokumentumcsomagokat közös feldolgozási egységbe rendezi, ellenőrzésre előkészíti, majd az Inspire felé engedélyezi. Az SAP őrzi a dokumentumok, csomagok, ellenőrzések és státuszesemények kapcsolatát. Az Inspire szolgáltatja a nyomtatási feldolgozást, a minták PDF-jét és a feldolgozásról visszaolvasható információkat.

A dokumentum az üzleti folyamatot és az azt megvalósító ABAP-objektumokat együtt mutatja be. A működési fejezetek a kezelőknek és a folyamatszervezőknek, az adatmodellről, interfészekről és tranzakciókezelésről szóló fejezetek a fejlesztőknek és üzemeltetőknek szólnak.

## A feldolgozás alapegységei

| Fogalom | Jelentés és szerep |
| Dokumentum | A DOC_NO azonosítja. A nyomtatási adatsort a ZPRT_DCQM, az XML-t a ZPRT_DOC_DATA, az üzleti és csatornaadatokat a ZPRT_DOC_LOG adja. |
| Csomag | A PACKAGE_ID azonosítja. Dokumentumokat és egy korábban előállított XML-fájl nevét kapcsolja össze. Egy csomag egy stockhoz rendelhető. |
| Stock | Közösen kezelt csomagok feldolgozási egysége. Saját azonosítója, állapota, prioritása és ellenőrzési jelzői vannak. |
| Boríték | Az ENVELOPE azonosítóval összefogott dokumentumok kézbesítési egysége. Egy dokumentum kizárása a társaira is kihat. |
| DC | Data Control, az adatok ellenőrzése és dokumentumok kizárása. Az engedélyezés lezárja a DC-szerkesztést. |
| QM | Mintakategóriákon végzett minőségellenőrzés. A kizárás a kategória valamennyi tagjára kiterjed. |
| Minta | Egy kategória ellenőrzésre kiválasztott részhalmaza. Az IN_SAMPLE jelző különbözteti meg a többi kategóriatagtól. |

## A folyamat áttekintése

1. A kezelő a feldolgozható csomagokat kijelöli, és stockot képez.
2. A program kialakítja a QM-kategóriákat és mintákat, majd feladja a stockot az Inspire felé.
3. A DC-kezelő ellenőrzi az adatokat, szükség esetén kizár dokumentumokat, majd engedélyezi a DC-t.
4. A QM-kezelő a minták alapján dönt a kategóriák kizárásáról, majd engedélyezi a QM-et.
5. A végső lezárás közli a prioritást és a kizárt borítékokat az Inspire-rel.
6. A státuszriport visszaolvassa a dokumentumok eseményeit. Az összes dokumentum kézbesítése után a stock AD állapotba kerülhet.

A Messenger e-mailstátuszainak lekérdezése és a nyomdai ellenőrző riport kiegészítő felügyeleti folyamat. A Messenger küldési státusza, a dokumentum feldolgozási eseménye és a stock státusza külön adatok.

Források: [F01], [F02], [F03], [F04], [F05], [F06], [F07], [F08].

# 2 A stock életciklusa

A stock állapotváltásának központi megvalósítása a ZCL_PR_STOCK. A CHANGE_STATUS először a CHECK_STATUS ellenőrzését, majd az UPDATE_STATUS írását hívja. Az ellenőrzés az engedélyezett átmenet mellett azt is vizsgálja, hogy az adatbázisban a stock valóban az elvárt kiinduló állapotban van-e.

| Állapot | Jelentés | DCCOMPL | QMCOMPL | CLOSED |
| Üres | Nyitott stock | üres | üres | üres |
| DC | DC engedélyezve | X | üres | üres |
| QM | DC és QM engedélyezve | X | X | üres |
| CL | Lezárt stock | X | X | X |
| AD | Minden dokumentum kézbesítve | X | X | a lezárásból megőrizve |

## Megengedett átmenetek

Nyitott ↔ DC ↔ QM → CL → AD

A DC visszavétele DC állapotból nyitottra, a QM visszavétele QM állapotból DC-re léptet. A központi osztály a CL → QM visszanyitást nem engedi. Tiltott átmenet vagy váratlan tényleges állapot esetén ZCX_FORM_MESSAGE_ERROR keletkezik, ZPR 044 üzenettel; hiányzó stocknál ZPR 045 az ok.

Az UPDATE_STATUS az új állapotból számítja az ellenőrzési jelzőket. Visszalépésnél ezért a későbbi fázishoz tartozó jelző kiürül. CL esetén rögzíti a lezáró felhasználót, dátumot és időt is. AD esetén ezeket a lezárási adatokat és a CLOSED mezőt változatlanul veszi át. A módosítás felhasználója, dátuma és ideje minden állapotírásnál frissül.

## Prioritás és hibajelző

A prioritás csak akkor módosul a státuszírásban, ha a hívó megadja az IV_PRIORITY paramétert. A stock létrehozási útja 30 értékkel dolgozik; a végső lezárás külön értékbekérő ablakot használ.

A STOCK_STATUS_ER mező a lezáró riportban a bizonytalan kimenetel jelzője. Kitöltött értéknél a riport letiltja az újabb lezárást. Ez a mező nem önálló életciklusállapot, és nem helyettesíti a STATUS vagy CLOSED mezőt.

Az állapotváltás COMMIT WORK utasítással zárul. A metódus nem kér saját stockzárat, ezért a hívási út felel a párhuzamos módosítások kizárásáért. A cockpit és a külön üzleti riportok eltérő védelmeket alkalmaznak; ezek részleteit a későbbi fejezetek tartalmazzák.

Források: [F02], [F07], [F09], [M02].

# 3 Alkalmazásfelépítés és felelősségek

A megoldás klasszikus SAP GUI-riportokra, dynprókra és ALV-rácsokra épül. A QM-rész különválasztja az üzleti műveleteket, az adatbázis-hozzáférést, a mintavételt és az Inspire-proxyk kezelését. A DC-rész főként riporton belüli rutinokat és eseménykezelőket használ.

| Réteg | Fő objektumok | Feladat |
| Kezelői belépés | ZPR_CREATE_STOCK, ZPR_DC_FRAME, ZPR_QM, ZPR_CLOSE_STOCK | Kijelölés, üzemmód, ellenőrzések, műveletindítás és eredménymegjelenítés. |
| Közös kezelőfelület | Z_PR_COCKPIT és LZPR_COCKPIT include-ok | Közös stockkontextus, lapváltás, beágyazott DC és QM-indító. |
| DC-szerkesztő | ZPR_DCQM_EXCLUDE és O01, I01, C01 include-ok | Szűrés, borítékbővítés, DC-kód és indok szerkesztése, mentés. |
| Állapotkezelés | ZCL_PR_STOCK | Átmenetek, fejlécadatok, státusz- és jelzőírás, külön lezárási művelet. |
| QM üzleti műveletek | ZCL_PR_QM_EXCLUSION | Kategóriakizárás, visszavétel, QM-engedélyezés és külön COMPLETE_STOCK szolgáltatás. |
| QM adat- és mintavételi réteg | ZCL_PR_QM_DATA, ZCL_PR_QM_SAMPLER, ZCL_PR_QM_RANDOM | Olvasások és írások, kategorizálás, véletlen minta. |
| Külső szolgáltatások | ZCL_PR_INSPIRE_GW és generált consumer proxyk | Fájlátadás, stockfeladás, minta-PDF és végső engedélyezés. |
| Felügyelet | ZPR_DOC_STATUS, ZPR_MESSAGEQUEUE_QUERY, ZPR_DOC_RIP | Dokumentumesemények, e-mailstátuszok és nyomdai egyeztetés. |
| Naplózás | ZCL_PR_LOG | SAP alkalmazásnapló létrehozása, üzenetek és hosszú hibaszövegek mentése. |

## A fő adatút

A stockképző a csomag- és dokumentumadatokból állítja össze a külső kérést. A mintavétel a ZIF_PR_QM_DATA és ZIF_PR_QM_RANDOM interfészeken keresztül kap adatokat, így az algoritmus adatbázis és valódi véletlengenerátor nélkül is vizsgálható. A gateway a ZIF_PR_INSPIRE_GW szerződését valósítja meg.

A külső stockfeladás után kerül sor a stock, a csomagkapcsolatok és a mintavételi adatok SAP-mentésére. A későbbi ellenőrzések ezeket a hozzárendeléseket használják. A végső engedélyezés és az események visszaolvasása külön szolgáltatáshívások.

## Eltérő lezárási útvonalak

A ZPR_CLOSE_STOCK a ZCL_PR_STOCK=>CLOSE_STOCK metódust hívja; ez közvetlenül használja a DCQMCompleted proxyt. A ZCL_PR_QM_EXCLUSION=>COMPLETE_STOCK szintén kínál külső engedélyezési műveletet, de a vizsgált külön lezáró riport nem ezt hívja. A cockpit lezárógombja a mentett forrásban közvetlen állapotváltást indít. A három út viselkedése ezért nem cserélhető fel automatikusan.

Források: [F01]–[F09], [F13], [M01].

# 4 Csomagokból stock létrehozása

A ZPR_CREATE_STOCK a csomagazonosító, létrehozó és létrehozási dátum alapján keres. Csak a még stockhoz nem rendelt, STOCK_ID = 0 és STATUS = X csomagokat jeleníti meg. A kezelő az ALV-listán jelöli ki a feldolgozandó csomagokat. Az induláskori S_TCODE ellenőrzés a ZPR_CREATE_STOCK tranzakcióra vonatkozik.

## A végrehajtás sorrendje

1. A rács függő módosításait átveszi, és a kijelölt csomagokból tartományt képez. Üres kijelöléssel visszatér.
2. Megszámolja, hogy a kijelölt csomagok mindegyike szabad-e még. Ha a szám eltér a kijelöléstől, nem folytatja.
3. A ZSTOCK számkör 01 intervallumából NUMBER_GET_NEXT hívással új azonosítót kér, majd stockazonosítós alkalmazásnaplót nyit.
4. A ZPRT_DCQM és ZPRT_DOC_DATA összekapcsolásával beolvassa az XML-lel rendelkező dokumentumokat. Üres találatnál naplóz és megáll.
5. Elkészíti a QM-kategóriák tagságát, mintáit és a maradék dokumentumok listáját.
6. Meghívja a TriggerStockCompletion szolgáltatást a csomagok XML-fájlneveivel, prioritással és mintacsoportokkal.
7. Csak sikeres válasz után írja a ZPRT_STOCK, ZPRT_PACKAGE, ZPRT_DCQM, ZPRT_QMSAMPLE és ZPRT_QMEXCL adatokat, majd commitol.

## A fájlátadás tényleges működése

A rutin előállít dokumentumonkénti fájlneveket és XML-munkatáblát is, de az UPLOAD_FILES hívása ki van kommentezve. A továbbküldött fájlnévlistát a program újraépíti a ZPRT_PACKAGE-XML_FILE_NAME mezőiből. A működés tehát a csomagkészítéskor már elkészült és átadott fájlokra támaszkodik. A dokumentumonként generált fájlnév önmagában nem bizonyítja új fájl feltöltését.

A mintacsoportok kategóriaazonosítót és a kisorsolt dokumentumazonosítókat tartalmazzák. A lista végén egy üres mintaazonosítójú csoport szerepel minden olyan dokumentummal, amely nem került mintába. A prioritás 30, az IV_NOTEST paraméter üres.

## Hiba és párhuzamosság

A csomagok hozzárendelése csak STOCK_ID = 0 feltétellel történik, és a módosított rekordok számának egyeznie kell a kijelölt csomagok számával. A stockfeladás előtti ellenőrzés és a későbbi feltételes írás között azonban a külső hívás már megtörténhet. Ha az Inspire elfogadta a stockot, de az SAP-mentés elbukik, a program visszagörgeti az SAP-írásokat és külön figyelmeztet a stockazonosítóval. Ilyenkor egyeztetés szükséges a két rendszer között.

A GET_STOCK_SIZE rutin létezik, de a vizsgált főágban a meghívása ki van kapcsolva. A STOCK_SIZE paraméter ezért ezen az útvonalon nem valósít meg automatikus stockdarabolást. A PROCESS_PACKAGE_OLD korábbi implementáció; az aktív gombút a CREATE_STOCK rutint használja.

Forrás: [F01], különösen CREATE_STOCK és GET_STOCK_ID.

# 5 QM kategóriák és véletlen mintavétel

A ZCL_PR_QM_SAMPLER tisztán memóriában dolgozik. A kategóriafejeket és szűrőket a ZCL_PR_QM_DATA adatrétegtől, a véletlen számokat a ZIF_PR_QM_RANDOM megvalósításától kapja. A kategóriák és a minták a stock létrehozásakor rögzülnek.

## Tagság és kategóriasorrend

A jelöltek a kiválasztott csomagok DCQM- és DOC_LOG-adatainak összekapcsolásából származnak. A már DC-kizárt dokumentum nem jelölt. A sampler a jelölteket az XML-lel rendelkező, ténylegesen feladandó dokumentumhalmazra is szűkíti. A bemeneti ismétlődéseket kiszűri.

Csak az ACTIVE = X kategóriák vesznek részt. A sorrend növekvő PRIO, azon belül QM_CAT. Egy dokumentum legfeljebb egy kategóriába kerülhet: az első illeszkedő kategória lefoglalja, a későbbiek már nem kapják meg.

## Szűrőszabályok

| Elem | Megvalósított szabály |
| Mezők | Engedélyezett mezőlista, például DOC_TYPE, CHANNEL, DOC_CAT, BUKRS, SPARTE, AMNT, WAERS, DUEDATE, TARIFTYP. |
| Műveletek | EQ, NE, LT, LE, GT, GE, BT, NB, CP és NP. A SIGN csak I vagy E lehet. |
| Logikai kapcsolat | Az azonos mezőre adott sorok ABAP tartományt alkotnak, I és E szemantikával. A különböző mezők feltételei ÉS kapcsolatban állnak. |
| Típuskezelés | A szöveges LOW és HIGH értékek a célmező típusára alakulnak. Hossz, számformátum és naptári dátum ellenőrzése történik. |
| Konverzió | ALPHA támogatott a nem mintás karakteres értékekhez. CP és NP csak karakteres mezőre használható. |
| Hibás beállítás | Üres szűrőlista, tiltott mező vagy hibás érték leállítja a teljes mintaképzést; a hiba megnevezi a kategóriát és tételt. |

A kategória SAMPLE_SIZE mezője abszolút darabszámot jelent. Nulla vagy negatív méretnél nincs mintatag; ha a tagság a kért méretnél kisebb vagy egyenlő, minden tag mintába kerül. Egyébként részleges Fisher–Yates keverés választ ismétlés nélkül.

## Eredmény és példa

Az ASSIGNMENTS minden kategóriatagot tartalmaz, IN_SAMPLE jelzővel. Az EXCLUSIONS kategóriánként üres kizárási sort készít. A GROUPS csak a minták dokumentumait adja át az Inspire felé. A REST a teljes feladandó halmazból a minták nélküli maradék.

Példa: egy 100 tagú kategória 5 elemű mintájából 5 dokumentum megy a kategória mintacsoportjába, 95 a maradékba. A QM-kizárás később mind a 100 kategóriatagra vonatkozik. Ez a példa az algoritmust szemlélteti, nem tényleges üzleti beállítás.

Források: [F03], [F04], [F05], [M04], [M05], [M06], [M07].

# 6 DC ellenőrzés és borítékszintű kizárás

A ZPR_DC_FRAME négy üzemmódot kínál: módosítás, megjelenítés, DC-engedélyezés és az engedélyezés visszavétele. Módosításhoz vagy megtekintéshez a ZPR_DCQM_EXCLUDE riportot indítja. Engedélyezéskor a nyitott → DC, visszavételkor a DC → nyitott átmenetet kéri a központi állapotkezelőtől.

## Adatszelekció és lista

A stock megadása kötelező. Szűrhető többek között a dokumentum, boríték, fizetési mód, dokumentumkategória, összeg és pénznem, esedékesség, bankszámla, név, ország, időszak, tarifa, csomag, futás és kizárási kód. Megadott összegtartományhoz pénznem is szükséges. A BUILD_RANGES a DDIC és a TCURX tizedeskezelése alapján korrigálja az összeghatárok belső értékét.

A kezdeti találat a csomag stockkapcsolatán keresztül áll elő. A program ezután az azonos stockban lévő, nem üres borítékazonosítóhoz tartozó többi dokumentummal kibővíti a listát. A bővítő lekérdezés PRD_STOCK_ID mezőt használ. Emiatt olyan sor is megjelenhet, amely az eredeti részletszűrőnek nem felelt meg. A Darab oszlop minden sorban 1, ALV-összegzésre használható.

## Kizárási szabályok

| Művelet | Hatás |
| Kiválasztott sor kizárása | A dokumentum megkapja a megadott DC-kódot és indokot. A kódnak szerepelnie kell a ZPRC_DCCODE táblában. |
| Borítéktársak kizárása | Az ugyanazon borítékba tartozó, még nem kizárt sorok ZZ kódot és az indokot kapják. A már meglévő saját ok megmarad. |
| Kizárás visszavonása | A teljes érintett boríték DC-kódja és DC-szövege kiürül. Több sor együttes cellamódosításakor a megtartandó sorokat is kezeli az eseménylogika. |
| Szöveg módosítása | A saját, nem ZZ kódú sor indoka továbböröklődik a boríték ZZ soraira. |
| Üres borítékazonosító | A sor önállóan változik; az üres érték nem fog össze külön dokumentumokat. |

A cellás és a gombbal indított módosítás közös borítékszabályokat alkalmaz. A szerkeszthető üzleti mezők a BLOCK_DC és BLOCK_DC_TEXT; a QM-mezők megjelennek, de ezen az úton nem szerkeszthetők. Szöveg kód nélkül nem menthető.

## Mentés és engedélyezés

Módosításkor a program dialógushatókörű stockzárat kér, majd frissen beolvassa a fejlécet. Lezárt vagy már DC-engedélyezett stock megtekintő módba kerül. A mentés minden változott sort egy SAP-tranzakcióban ír; bármely hiba az összes írást visszagörgeti. A DC-szöveg frissítése megőrzi a QM-szöveget. Kilépéskor a nem mentett változásokról figyelmeztetés jelenik meg.

Források: [F06], [F10], [F11].

# 7 QM ellenőrzés és kategóriakizárás

A ZPR_QM stockazonosítóval és négy móddal indul: kategóriák szerkesztése, megtekintés, QM-engedélyezés és visszavétel. A lista kategóriánként mutatja a leírást, a teljes tagság darabszámát, a minta elemszámát, a kizárási kódot és az indokot. A szabad kategória zöld jelzést, a kizárt kategória lakatot kap.

## Szerkesztési előfeltételek

A program a módosításhoz stockzárat kér. A ZCL_PR_QM_EXCLUSION friss stockadatokon ellenőrzi, hogy a stock létezik, nincs CLOSED jelölése, nincs QMCOMPL jelölése és nem CL állapotú. Sikertelen ellenőrzésnél a riport tájékoztat és megtekintő módra vált. A megvalósítás nem követeli meg külön a DC állapotot a kategória szerkesztéséhez; a DC → QM átmenet viszont csak megfelelő státuszból engedélyezhető.

## Kategória kizárása és visszavétele

A BLOCK_CATEGORY a kategória valamennyi dokumentumának BLOCK_QM mezőjét módosítja, nem csak a kisorsolt mintáét. A kódnak a ZPRC_PR_QMCODE táblában léteznie kell. A hosszú indok a ZPRT_DCQMLT táblába kerül; a kategória saját állapotát és indokát a ZPRT_QMEXCL is őrzi.

Visszavételkor a kategória dokumentumainak QM-kódja és QM-szövege ürül. A meglévő szövegsor és a DC-szöveg megmarad. Ha valamely kategória kizárási sora hiányzik, az adatréteg hibát ad; nem hoz létre észrevétlenül új kategóriakapcsolatot.

A rács mentése egyetlen logikai munkaegység. Ha bármely módosított kategória hibát okoz, az összes módosítás visszagördül. A sikeresnek szánt, de visszagörgetett sorok helyett új napló csak a hibát rögzíti. Siker után a program az adatbázisból újraolvassa az áttekintést.

## Minták megtekintése és letöltése

A PDF az Inspire GetSamplePDF szolgáltatásából érkezik, a stock és a kategória azonosítójával. A gateway Base64-ből bináris tartalommá alakítja; a riport HTML-konténerben jeleníti meg. A kijelölt kategóriák PDF-je a választott könyvtárba stock_kategória.pdf néven menthető. Minden letöltés új lekérést végez, nincs PDF-gyorsítótár. A mintadarabszám nélküli kategóriát a letöltő ág kihagyja.

A QM-engedélyezés DC → QM, a visszavétel QM → DC státuszváltás. A központi osztály commitolja a váltást. Az engedélyezés után a QM-kizárások szerkesztése lezárul; módosításhoz előbb visszavétel szükséges.

Források: [F04], [F05], [M01], különösen BLOCK_CATEGORY, UNBLOCK_CATEGORY, RELEASE és RELEASE_BACK.

# 8 Végső engedélyezés és stocklezárás

A ZPR_CLOSE_STOCK a stockazonosító és egy választható ALV-elrendezés megadásával indul. Háttérfutást nem enged. Az S_TCODE ellenőrzés a ZPR_CLOSE_STOCK tranzakcióra vonatkozik. A lista a PRD_STOCK_ID alapján a teljes stock darabszámát és a DC vagy QM miatt kizárt dokumentumokat mutatja, a hosszú indokokkal együtt.

## Lezárás előtti ellenőrzések

Módosítás csak QM státuszú, nem lezárt, hibajelző nélküli stocknál engedélyezett. A riport stockzárat kér _SCOPE = 1 értékkel, majd újraolvassa a fejlécet. A megnyitás és a lezárás között változott adatok kiszűrésére a RELEASE_EXECUTE ismét lekéri a listát és a teljes darabszámot. Ha ezek eltérnek a megjelenített állapottól, vagy a stock üres, nem folytatja a lezárást.

A kezelő az engedélyezési művelettel a ZCL_PR_STOCK=>CLOSE_STOCK metódust indítja. A prioritást ez a metódus kéri be felugró ablakban, 30 alapértékkel. Az ablak megszakítása nem jelent sikeres lezárást.

## Külső kérés és SAP állapot

1. A metódus a stock csomagkapcsolatain keresztül összegyűjti a DCQM-dokumentumokat.
2. A BLOCK_DC vagy BLOCK_QM értékkel rendelkező dokumentumok borítékazonosítóiból rendezett, ismétlésmentes listát képez.
3. A logikai portot a ZCL_PR_OUTPUT_MANAGEMENT szolgáltatja. A DCQMCompleted kérés megkapja az SAP-rendszert, mandantot, stockot, prioritást és a kizárt borítékokat.
4. A hívás kezdetét, végét és időtartamát naplózza. Technikai kivételnél vagy üzleti sikertelenségnél nem indít státuszváltást.
5. Sikeres külső válasz után a CHANGE_STATUS QM → CL átmenettel menti a státuszt és prioritást.
6. A riport visszaolvassa az SAP-fejlécet. Csak a tényleges CL állapot alapján jelöl sikeres lezárást.

## Bizonytalan kimenetel és megvalósítási különbségek

A riport bizonyos kivételeknél, illetve a lezárási hívás utáni sikertelen visszaolvasásnál STOCK_STATUS_ER jelzőt ment, hogy megakadályozza az ismételt küldést. Ez célzott védelem: nem minden nem CL visszatérés eredményez automatikusan bizonytalan jelölést. A belső CLOSE_STOCK a státuszváltás saját kivételét naplózza; ilyen esetben a külső siker és az SAP-állapot külön egyeztetendő.

A külön QM COMPLETE_STOCK szolgáltatás kiszűri az üres borítékazonosítót is. A ZCL_PR_STOCK=>CLOSE_STOCK gyűjtése csak rendez és ismétlést töröl; üres borítékot nem szűr ki kifejezetten. A tényleges lezáró út ezért saját ellenőrzést igényel hiányos borítékadatnál.

Források: [F02], [F07], [M01].

# 9 A cockpit működése

A Z_PR_COCKPIT függvény és az LZPR_COCKPIT include-ok közös stockkontextust és füles kezelőfelületet adnak. A lapok a DC-tételek, a DC-jóváhagyás, a QM-ellenőrzés, a QM-jóváhagyás és a lezárás területeit fogják össze. A forrás a DC egyes elemeire DM elnevezést használ; az üzleti állapotkód továbbra is DC.

## Stock elfogadása és környezetváltás

A megadott azonosító ALPHA-normalizálás után a GET_STOCK_HEADER segítségével ellenőrződik. Az elfogadott stock mezője zárolt a képernyőn; másik stockra a RESET művelettel lehet áttérni. A fejléc minden megjelenítési ciklusban frissül.

A RESET és a lapváltás először lezárja a DC-szerkesztési környezetet. Ha a kezelő a nem mentett változások eldobását nem erősíti meg, a környezet megmarad. A host csak sikeres kilépés után engedi el a közösen használt konténer referenciáját és a stockkontextust.

## DC és QM beágyazás

A DC-adapter a ZPR_DCQM_EXCLUDE C01 include-jában van. A COCKPIT_OPEN közvetlen külső PERFORM hívásból indul, ezért maga ellenőrzi a ZPR_DC_EXCLUDE jogosultságot, törli a korábbi szelekciós szűrőket, és kéri a stockzárat. A host saját konténerét a COCKPIT_PBO adja át. A SAVE a meglévő DC-mentési logikát használja.

A QM-lap a ZPR_QM 1100-as szelekciós alképernyőjét jeleníti meg. Megnyitáskor még nem indul QM üzleti munka. Az indítógomb külön SUBMIT ZPR_QM AND RETURN futást indít, hogy a 2000-es képernyő a megfelelő riporthoz tartozzon. A stockazonosító a host értékéhez rögzített; a ZPR_QM jogosultság ellenőrzése az adapterben történik.

## A lezárási gomb lényeges eltérése

A vizsgált cockpitben a lezárógomb közvetlenül a CHANGE_STATUS QM → CL átmenetet kéri. Nem hívja meg a ZPR_CLOSE_STOCK riportot és a CLOSE_STOCK külső engedélyezési folyamatát sem. A visszanyitógomb CL → QM kérést küld, amelyet a központi CHECK_STATUS jelenleg tilt.

Ez forrásból igazolható működési eltérés. A cockpitben elért CL állapot önmagában nem igazolja, hogy ezen az útvonalon DCQMCompleted kérés ment az Inspire felé. A végső engedélyezés dokumentált, külső hívást is tartalmazó útja a külön ZPR_CLOSE_STOCK riport. A cockpit lezárási funkciójának üzleti használata előtt az elvárt folyamattal való egyezést ellenőrizni kell.

Források: [F09], [F11], [F05], [F02].

# 10 Dokumentumesemények és kézbesítési állapot

A ZPR_DOC_STATUS a lezárt, CL állapotú stockok dokumentumainak eseményeit olvassa vissza az Inspire-ból. A SO_STOCK szűrővel korlátozható a stockkör. A P_DET részletes naplózást kapcsol; a P_STAT a már D eseménnyel rendelkező dokumentumok ismételt lekérdezését is engedi. P_STAT esetén stockkijelölés kötelező.

## Kérés és válaszellenőrzés

A program stockonként dialógushatókörű zárat tart. A csomagkapcsolatból képzett dokumentumlistát a DOC_LOG-adatokkal egészíti ki. Hiányzó dokumentumazonosító, eltérő naplóazonosító, hiányzó csatorna vagy ismétlődő dokumentum esetén az érintett stock feldolgozása leáll.

A QueryDocDetails kérés csak a nem terminálisnak ítélt dokumentumokat tartalmazza. Terminális az a dokumentum, amelynek nem üres hibakódja van a ZPRT_DOC_ERROR táblában; P_STAT nélkül egy már létező D esemény is elegendő a kihagyáshoz.

A válasz dokumentumonként pontosvesszővel tagolt szöveg. Az első mező a dokumentumazonosító, a második a fájlnév, a következő tizennégy a R, C, B, Q, O, X, P, L, G, S, A, D, E és V esemény időbélyege. A 17. mező a hibakód, a 18. és az utána álló részek együtt a hibaszöveg. Az eseménykódok megnevezését nem a parser adja; a program az A értéket archiválási, a D értéket kézbesítési feltételként használja.

A parser ellenőrzi a minimális mezőszámot, a dokumentumazonosító hosszát, a 14 számjegyű UTC-időbélyegeket és a hibamezők hosszát. Nem kért dokumentum vagy ismétlődő válasz esetén a teljes válaszkört elutasítja. Hiányzó válasznál figyelmeztet, a beérkezett érvényes dokumentumok feldolgozhatók.

## Dokumentumonkénti mentés

A ZPRT_DOC_SLOG táblába csak az új időbélyeg és státusz párok kerülnek. A kulcs része mindkét érték, ezért azonos időpontban eltérő státuszok is tárolhatók. Dokumentumonként külön COMMIT WORK AND WAIT történik; egy másik dokumentum hibája a korábban mentetteket nem görgeti vissza.

PR csatornán a fájlnévből PRDFILE állhat elő; a meglévő PACKAGE_ID és spoolkapcsolat megmarad. Új A eseménynél a program a ZPRT_ARCH_LINK alapján ArchiveLink-kapcsolatot készíthet és archiváltnak jelölheti a DOC_LOG sort. Hibaválasznál a kapcsolódó ZPR_TERTI sorokat törli, és a már másutt nem hivatkozott ragszám ZISU_F064 sorát is eltávolíthatja. Ezek üzleti adatváltozások, ezért a státuszriport futtatása nem puszta lekérdezés.

## A CL állapot AD állapotba lépése

A teljes stock dokumentumhalmazát vizsgálja, a napló nélküli dokumentumokkal együtt. Minden dokumentumnál léteznie kell D eseménynek a legnagyobb tárolt időbélyegen. Üres stock nem válik AD állapotúvá. Ha a feltétel teljesül, CHANGE_STATUS CL → AD és commit következik. Azonos legnagyobb időbélyegen más esemény mellett jelen lévő D is teljesíti a megvalósított SQL-feltételt.

A korábbi UPD_ESZLA, UPD_BC_STAT és UPD_PUSH_MSG lépések a mentett DHC-ágban ki vannak kapcsolva.

Források: [F08], [M08].

# 11 Messenger e-mailstátuszok követése

A ZPR_MESSAGEQUEUE_QUERY a ZPRT_EMAIL_SLOG azon rekordjait dolgozza fel, amelyek SENDING_STATUS mezője még üres. Az engedélyellenőrzés a ZPR_MQ_QUERY tranzakcióra vonatkozik. A riport az Inspire QueryMessengerStatus szolgáltatásán keresztül kér állapotot a dokumentumazonosítókra.

## Státuszképzés

Ha a válasz nem üres küldési státuszt tartalmaz, a program átveszi a státuszt, annak időbélyegét, a tényleges e-mailküldés időbélyegét és a hibaszöveget. A már meglévő üzleti mezők, például az OPBEL és az e-mailcím az eredeti rekordból maradnak meg.

Ha nem érkezik használható státusz, a program a TSTMP_PRINT értékét vizsgálja. A hét napos határ elérésekor N státuszt és a „Hét napon belül nem érkezett státusz a Messengertől.” szöveget állítja be. A határ UTC-ben, a pontos időpont alapján értendő; az egyenlőség már lejártnak számít. Érvénytelen vagy hiányzó időbélyegből nem képez automatikusan lejárati státuszt.

A hét napon belüli, válasz nélküli sor nem kerül a menthető eredménylistába. Sikertelen teljes szolgáltatáslekérdezés esetén a riport nem állítja elő a lejárati eredményeket sem; előbb a szolgáltatás hibáját kell rendezni.

## Válasz és mentés

A proxyfeldolgozás ellenőrzi a dokumentumazonosító, státusz és hibaszöveg hosszát, valamint a visszaadott időbélyegeket. A nem kért dokumentumot kihagyja. Egy dokumentum többszöri előfordulásánál a válaszlistában később érkező sor felülírja a korábbit; ez sorrendi szabály, nem időbélyeg szerinti maximumkeresés.

Párbeszédes futásban az eredmény SALV-listán jelenik meg, és mentési művelet szükséges. Háttérfutásban a SAVE_RESULT automatikusan lefut. A program minden rekordra külön ENQUEUE_EZPRT_EMAIL_SLOG zárat kér, újraolvassa a teljes eredeti sort, és csak változatlan bemenetnél frissít. A feltétel továbbra is üres SENDING_STATUS és változatlan TSTMP_PRINT.

| Mentési állapot | Jelentés |
| S | Sikeresen mentve és commitolva. |
| C | Időközben változott vagy törölt rekord, illetve nem egyértelmű frissítési darabszám; új lekérdezés kell. |
| E | Zárolási, adatbázis- vagy commitprobléma; a sor nem kezelhető biztos sikernek. |

A mentés soronként önálló tranzakció. A futás végén mentett, kihagyott és hibás darabszám készül. A riport szöveges futásnaplót ír a listára; ez eltér a ZCL_PR_LOG által használt alkalmazásnaplótól.

Források: [F12], [F14], [F15], [F16].

# 12 Nyomdai ellenőrző riport

A ZPR_DOC_RIP az SAP szerinti és az Inspire által visszaadott nyomdai darabszámok összevetésére szolgál. Stocktartomány és dátumtartomány alapján választ, majd a QueryPrinthouseOut szolgáltatásból kéri a fájlok részleteit. Az eredményt PR és IN destination értékekre bontva építi fel.

## Megjelenített adatok

A riport a stockhoz tartozó csomagokból és a ZPRV_DOC nézetből számolja az SAP-oldali dokumentumokat és kizárásokat. Az Inspire-oldali sorokból összeadja a dokumentum-, boríték-, ív-, oldal- és jelölésszámokat, valamint megjeleníti a küldési időt és az OK vagy NOK visszajelzést.

A számított eltérések képlete: SAP mennyiség mínusz kizárt mennyiség mínusz Inspire mennyiség. A Részletek gomb és a dupla kattintás a stock és destination szerint szűrt fájlszintű információt nyitja meg. A vizsgált aktív eseményágak ezen a felületen részletezést végeznek; a listán szereplő státusz nem stockállapot-váltás.

## Az eredmények értelmezését befolyásoló részletek

| Terület | Forrásból látható működés és következmény |
| Jogosultság | A riporton belüli S_TCODE és S_APPL_LOG ellenőrzés ki van kommentezve. A tényleges indítási jogosultságot az SAP-környezetben külön ellenőrizni kell. |
| Dátumszűrés | A SO_ERDAT mező a lezárási dátum típusából indul, a SELECT azonban az ERDAT mezőt szűri. A lista dátumjelentését ennek megfelelően kell tisztázni. |
| Borítékszám | A SAP_ENV_NO és EXCL_ENV_NO a dokumentumsorokat tartalmazó táblák sorszámából készül. Nincs külön borítékazonosító szerinti egyedivé tétel. |
| Küldési maximum | A küldési idő maximumát tartó változó nincs kifejezetten törölve minden stock és destination elején. Több egységes futásnál az időpontot célzottan ellenőrizni kell. |
| OK visszajelzés | Egy stock és destination során már egy nem üres STATUS_OK érték is OK-ra állítja az összesítő sort; ez nem minden részfájl sikerének teljes körű igazolása. |

Ezek a megfigyelések a jelenlegi forrás viselkedését írják le. A riportból származó borítékeltérést ezért csak a dokumentumonkénti és fájlonkénti részletekkel együtt célszerű üzleti eltérésként értékelni. A korábbi DOC_RIP jogosultsági patch a projektben történeti javaslatként szerepel; nem tekinthető automatikusan beépült javításnak.

Forrás: [F17], különösen SELECT_DATA és GET_DATA.

# 13 Adatmodell és kulcskapcsolatok

A stock és csomag kapcsolatát a ZPRT_PACKAGE-STOCK_ID tárolja. A dokumentum a ZPRT_DCQM-PACKAGE_ID mezőn kapcsolódik a csomaghoz, és a PRD_STOCK_ID közvetlen stockazonosítót is tartalmazza. A kétféle stockhivatkozás összhangja alapvető, mert a riportok nem mindenhol ugyanazt az elérési utat használják.

| Tábla | Üzleti kulcs a mandanton belül | Tartalom és kapcsolat |
| ZPRT_STOCK | STOCK_ID | STATUS, CLOSED, DCCOMPL, QMCOMPL, PRIORITY, STOCK_STATUS_ER, lezárási és adminisztrációs adatok. |
| ZPRT_PACKAGE | PACKAGE_ID | STOCK_ID, XML_FILE_NAME, STATUS és adminisztrációs mezők. |
| ZPRT_DCQM | DOC_NO | PACKAGE_ID, PRD_STOCK_ID, ENVELOPE, pénzügyi és nyomtatási adatok, BLOCK_DC, BLOCK_QM, PRDFILE, PRDSPOOL. |
| ZPRT_DCQMLT | EXBILLDOCNO | Egy dokumentum DC- és QM-kizárási indoka külön mezőben. |
| ZPRT_QMSAMPLE | STOCK_ID, QM_CAT, DOC_NO | A teljes kategóriatagság és az IN_SAMPLE jelző. |
| ZPRT_QMEXCL | STOCK_ID, QM_CAT | Kategóriaszintű QM-kód és indok. |
| ZPRC_QMCAT | QM_CAT | Kategóriafej, sorrend, mintaméret, aktív jelző, leírás. |
| ZPRC_QMCAT_FLT | QM_CAT, ITEM | Mezőnév, SIGN, OPTI, LOW, HIGH; kapcsolat a kategóriafejhez. |
| ZPRT_DOC_SLOG | EXBILLDOCNO, TIMESTAMP, STATUS | Dokumentumesemények. Egy időpontban több eltérő státusz megengedett. |
| ZPRT_EMAIL_SLOG | EXBILLDOCNO | E-mailcím, számlaazonosító, nyomtatási és küldési időbélyegek, Messenger-státusz és hiba. |

## Kiegészítő táblák és megjelenítési típusok

A ZPRT_DOC_DATA XML-adatot, a ZPRT_DOC_LOG a dokumentum üzleti és csatornaadatait biztosítja. A ZPRT_DOC_ERROR a dokumentumhibát, a ZPRT_ARCH_LINK a feldolgozandó ArchiveLink-adatot tárolja. A ZPR_TERTI és a ZISU_F064 a ragszámok státuszfeldolgozásban érintett adatai. E táblák szerepe a programhivatkozásokból következik; teljes definíciójuk nem része a mellékelt mezőjegyzéknek.

A ZPRS_DCQM_REPORT a DCQM-sorokat kizárási szövegekkel, módosításjelzővel, cellastílusokkal és számlálóval egészíti ki. A ZPRB_EMAIL_SLOG és ZPRB_SLOG_EMAIL táblatípusok e-mailstátusz-adatok átadását szolgálják; nem önálló adatbázistáblák.

## Adatinvariánsok

Egy dokumentum DOC_NO azonosítója a DCQM és DOC_LOG között egyezik. A csomag STOCK_ID és a dokumentum PRD_STOCK_ID ugyanazt a feldolgozási egységet jelöli. A kategória mintatagjai a kategória teljes tagságának részhalmazai. A DC- és QM-szöveg egymástól függetlenül módosítható; egyik oldal törlése nem törölheti a másik indokát. Ezeket a kapcsolatokat migráció, javítás és hibaelemzés során is ellenőrizni kell.

Források: [F04], [F08], [F18], [F19], [F20], [F21], [M02]–[M08].

# 14 Inspire interfészek

A ZCL_PR_INSPIRE_GW vékony burkot ad négy szolgáltatáshoz. Más szolgáltatásokat a riportok közvetlenül a generált proxykon keresztül érnek el. A logikai port nevét normál esetben a ZCL_PR_OUTPUT_MANAGEMENT=>GET_LOGICAL_PORT_NAME biztosítja; a rendszer és mandant a bejelentkezési környezet SY-SYSID és SY-MANDT értéke.

| Szolgáltatás | Kérés lényegi adatai | Válasz és használat |
| FormsUploader | Fájlnév és XML fájlonként, ZIP és Base64 jelzőkkel. | Sikerjelző. A gateway megvalósítja; a jelenlegi stockképző újrafeltöltése ki van kapcsolva. |
| TriggerStockCompletion | Stock, prioritás, NOTEST, csomagfájlnevek, mintacsoportok és dokumentumazonosítók. | Success, error_code, info. Siker után indul az SAP-oldali stockmentés. |
| GetSamplePDF | Stock és mintakategória. | Siker, hibaadatok és Base64 PDF; a gateway XSTRING tartalmat ad vissza. |
| DCQMCompleted | Stock, prioritás, kizárt borítékok. | Végső engedélyezési válasz. Közvetlen stockmetódus és gateway út is létezik. |
| QueryDocDetails | Stock és dokumentumazonosítók. | Dokumentumonként tagolt esemény- és hibainformáció. |
| QueryMessengerStatus | Dokumentumazonosítók. | Küldési státuszok és időbélyegek. |
| QueryPrinthouseOut | Stockazonosítók. | Nyomdai fájlok részletei és darabszámai. |

## Kódolás és hibaszerződés

Az UPLOAD_FILES megvalósítása az XML-t XSTRING-re alakítja, fájlonként CL_ABAP_ZIP archívumba csomagolja, majd Base64-kódolja. Az archívumbejegyzés neve az átadott fájlnév. Az interfész egyik kommentje gzipet említ, de a megvalósítás ZIP-et használ; a technikai értelmezésnél a kód az irányadó.

A gateway a CX_AI_SYSTEM_FAULT és CX_AI_APPLICATION_FAULT kivételeket ZCX_FORM_MESSAGE_ERROR kivétellé alakítja a teljes szöveggel. Az üzleti sikertelenséget a SUCCESS érték és az ERROR_CODE, INFO mezők közlik. A hívónak mindkét hibautat kezelnie kell.

## Tranzakciós következmény

A gateway és interfész forráskommentjei a szinkron proxyhívások korábban mért implicit commitjára figyelmeztetnek. A megvalósított sorrend ezért a külső hívások előtt nem hagy visszagörgetendő SAP-írást. A dokumentum PDF-jének puszta megnyitása is proxyhívás; a rácsmódosítások ekkor csak memóriában vannak.

A külső rendszer üzleti művelete SAP ROLLBACK WORK utasítással nem vonható vissza. A stockfeladás és végső engedélyezés hibakezelésekor ezért a külső és a helyi eredményt külön kell igazolni. Az ismételt végrehajtás biztonságát a mentett gateway nem garantálja önálló idempotenciakulccsal.

Források: [F13], [F22], [F01], [F02], [F08], [F14], [F17].

# 15 Zárolás tranzakciók és naplózás

A megoldás több különálló SAP logikai munkaegységet használ. A COMMIT nem csak technikai lezárás: eldönti, hogy egy kezelői vagy háttérművelet mely adatai válnak tartóssá. A külső proxyhívások és a napló mentése szintén befolyásolják ezt a határt.

| Művelet | Zár és tranzakcióhatár |
| Stock létrehozása | Előzetes szabadcsomag-ellenőrzés, majd feltételes UPDATE és darabszámellenőrzés. A külső siker után egy közös SAP-commit. |
| DC-szerkesztés | Stockzár _SCOPE = 1 értékkel. Minden módosított sor közös commit vagy rollback. |
| QM-szerkesztés | Stockzár az adatrétegen át. Minden módosított kategória közös commit vagy rollback. |
| Állapotváltás | A ZCL_PR_STOCK commitol. Saját enqueue nincs; a hívó felel a megfelelő védelemért. |
| Végső lezárás | A riport stockzárat tart a külső hívás és a visszaolvasás alatt. A központi állapotváltás véglegesít. |
| Dokumentumesemények | Stockzár, továbbá dokumentumonként E_TABLE zár. Külön commit dokumentumonként; hibafeldolgozásnál ZPR_TERTI zár is lehet. |
| Messenger | Dokumentumonként e-mailnaplózár és eredeti sorral való összevetés. Külön commit minden mentett sorra. |

Az _SCOPE = 1 dialógushoz kötött zárat jelent; a kód erre támaszkodik, hogy a commit és a PDF-lekérés ne oldja fel idő előtt. A saját, sikeresen megszerzett zárat explicit feloldás követi. A zárhibát nem szabad üres találatnak vagy sikeres megtekintésnek tekinteni.

## Alkalmazásnapló

A ZCL_PR_LOG a BAL_LOG_CREATE, BAL_LOG_MSG_ADD, BAL_LOG_MSG_ADD_FREE_TEXT, BAL_DB_SAVE és BAL_DSP_LOG_DISPLAY szolgáltatásokat használja. A fő objektum ZPR_MASS; a vizsgált útvonalak STOCK, DC, DOC és PACKAGE alobjektumokat használnak. A QM-riport is a STOCK alobjektumba naplóz. A külső azonosító lehet stockazonosító vagy futási időpont, a hívástól függően.

Az ADD_TEXT a hosszú szöveget 200 karakteres részekre bontja, így a teljes hibaleírás több naplósorban maradhat meg. Az ADD_EXCEPTION ezt használja. Az ADD_LONG_MESSAGE régebbi megoldása a négy üzenetváltozó kapacitásához kötött, ezért a két metódus nem egyenértékű hosszú hibák kezelésére.

A CLOSE update taskkal kéri a BAL_DB_SAVE mentést, majd COMMIT WORK utasítást ad. A visszatérő igaz érték a mentési kérelem elfogadását és a nyilvántartott teljességet jelzi; nem önálló szinkron adatbázis-visszaolvasás. Az ADD_SYSTEM_MESSAGE hibája jelenleg nem állítja a hiányosságjelzőt, ezért a CLOSE eredménye nem minden üzenetvesztést fed le.

Források: [F02], [F04], [F05], [F07], [F08], [F10], [F12], [F23].

# 16 Beállítások és jogosultságok

A programforrás mellett a helyes működéshez DDIC-objektumok, képernyők, tranzakciók, üzenetek, számkörök, naplóobjektumok és webszolgáltatás-beállítások szükségesek. A repository-forrás önmagában nem hozza létre a teljes futási környezetet.

## Működéshez szükséges beállítások

| Terület | Követelmény vagy ellenőrzés |
| Számkör | ZSTOCK objektum, 01 belső intervallum, elegendő szabad tartomány. |
| DC-okok | ZPRC_DCCODE karbantartott értékei, különösen az automatikus borítéktárs-kizárás ZZ kódja. |
| QM-okok | ZPRC_PR_QMCODE értékei. A riport a kódot mentés előtt ellenőrzi. |
| Mintakategóriák | ZPRC_QMCAT aktív jelző, prioritás és mintaméret; ZPRC_QMCAT_FLT érvényes mezők és típushelyes szűrők. |
| Proxykapcsolat | Generált proxyk és egyező kérés-válasz típusok, elérhető logikai port és Inspire-végpont. |
| Alkalmazásnapló | ZPR_MASS és a STOCK, DC, DOC, PACKAGE alobjektumok; megfelelő megtekintési jogosultság. |
| UI és szövegek | Dynprók, konténerek, PBO és PAI flow logic, PF-STATUS, titlebar, szövegelemek, ZPR és ZPR_QM üzenetek. |
| Keresési súgók | A forrásban hivatkozott ZPRH_STOCK és ZPR_STOCK objektumok; ALV-layoutok. |
| Zárak | EZPRT_STOCK, EZPRT_EMAIL_SLOG és az E_TABLE alapú kulcsképzés használhatósága. |

## A forrásban látható engedélyellenőrzések

A stockképző a ZPR_CREATE_STOCK, a külön lezáró riport a ZPR_CLOSE_STOCK, a dokumentumstátusz-riport a ZPR_DOC_STATUS, a Messenger-riport a ZPR_MQ_QUERY tranzakcióra végez S_TCODE ellenőrzést. A cockpit DC-adaptere a ZPR_DC_EXCLUDE, a QM-adapter a ZPR_QM jogosultságot ellenőrzi.

A külön ZPR_DC_FRAME, a DC-főriport és a ZPR_QM önálló főágának bemutatott belépése nem minden esetben tartalmaz ugyanilyen explicit ellenőrzést. Az SAP tranzakcióindítási védelme és a közvetlen riportindítás lehetősége külön vizsgálandó. A DOC_RIP saját ellenőrzése ki van kapcsolva. Ebből nem következik, hogy a teljes rendszerben nincs jogosultságvédelem; az következik, hogy az objektumok védelme belépési útvonalanként ellenőrizendő.

A használatba vétel előtt az üzleti szerepköröket a stockképzés, DC, QM, végső engedélyezés, háttérfeldolgozás és naplómegtekintés műveleteihez kell hozzárendelni. A szerepek konkrét neve és felhasználói hozzárendelése szervezeti beállítás.

Források: [F01], [F05]–[F12], [F17], [F23], [M01], [M06], [M07].

# 17 Üzemeltetési eljárások

## Egy stock végigvezetése

1. Ellenőrizni kell, hogy a kiválasztott csomagok elkészültek, még nem tartoznak stockhoz, és az XML_FILE_NAME értékeik a feldolgozható állományokra mutatnak.
2. A stockképzőben ki kell jelölni a csomagokat, majd a kapott stockazonosítót és a napló eredményét meg kell őrizni.
3. A DC-ben a szűrés után megjelenő borítéktársakat is ellenőrizni kell. A kizárások mentése után történhet a DC-engedélyezés.
4. A QM-ben meg kell tekinteni a minták PDF-jét, és a kategória teljes tagságára érvényes döntést kell menteni. Ezután következik a QM-engedélyezés.
5. A ZPR_CLOSE_STOCK riportban ellenőrizni kell a teljes és kizárt darabszámot, majd a prioritás megadásával indítható a végső engedélyezés. A siker feltétele a visszaolvasott CL állapot.
6. A dokumentumstátusz-feldolgozás követi az eseményeket és az AD feltételt. Az e-mail- és nyomdai ellenőrzés külön felügyeleti lépés.

## Rendszeres háttérfutások

A ZPR_DOC_STATUS CL stockokra időzíthető; a futás utáni napló és a feldolgozatlan dokumentumok áttekintése szükséges. A P_STAT speciális újraolvasási módot csak célzott stocktartománnyal célszerű használni. A meglévő hibakód ettől a kapcsolótól függetlenül terminálisnak számít.

A ZPR_MESSAGEQUEUE_QUERY háttérfutásban automatikusan menti a még üres e-mailstátuszok változásait. Figyelni kell az N eredményeket, a kihagyott sorokat és a lekérdezés technikai hibáit. A ZPR_CLOSE_STOCK interaktív riport; háttérjobként nem használható. A DC-, QM- és DOC_RIP-felületek GUI-komponenseket használnak.

## Hibaelhárítási támpontok

| Jelenség | Célzott ellenőrzés és következő lépés |
| A stock nem szerkeszthető | STATUS, CLOSED, DCCOMPL, QMCOMPL, STOCK_STATUS_ER és a fennálló stockzár ellenőrzése. |
| Stockfeladás után nincs SAP-stock | A stockképző naplójában a külső siker és az SAP-rollback szétválasztása; Inspire-oldali egyeztetés ugyanazzal az azonosítóval. |
| Nincs minta-PDF | Mintadarabszám, stock és kategória, szolgáltatási válasz és bináris tartalom vizsgálata. |
| Lezárás után nem CL | Külön ellenőrizendő az Inspire-válasz és a státuszmentés naplója. Az újraküldést az eredmény tisztázásáig kerülni kell. |
| CL nem lép AD-re | Teljes csomag-dokumentum halmaz, hiányzó naplók és dokumentumonként a legutolsó esemény vizsgálata. |
| Messenger nem ment | Zárhiba, eredeti rekord változása, üres vagy hibás időbélyeg, illetve teljes szolgáltatáshiba keresése. |
| Nyomdai eltérés | Dokumentumszámok és egyedi borítékok külön számolása; destination és fájlszintű részletek összevetése. |

A naplóban stockazonosítóra, futási időre, dokumentumra és teljes hibaszövegre érdemes keresni. Az újrafuttatás nem általános hibajavítás: külső üzleti hívás után előbb mindkét rendszer eredményét kell tisztázni.

Források: [F01], [F05], [F07], [F08], [F12], [F17], [F23].

# 18 Ellenőrzési terv és ismert eltérések

A következő ellenőrzések a működés átvételéhez ajánlott esetek. A forrásban létező tesztkód és egy végrehajtott, sikeres tesztfutás eltérő bizonyíték. A mentett ZPR_DOC_STATUS parserteszteket, a ZPR_MQ_TESTS időhatár- és rekordmegőrzési teszteket tartalmaz; ezek a vizsgált dokumentumkészítés során nem futottak SAP-ban.

| Terület | Vizsgálandó eset és elvárt eredmény |
| Stockképzés | Üres kijelölés, időközben elvitt csomag, hiányzó XML, üzleti proxyhiba, külső siker utáni SAP-hiba. Hibánál ne maradjon részleges SAP-hozzárendelés. |
| Mintavétel | Átfedő kategóriák, azonos prioritás, hibás szűrő, nulla vagy túl nagy minta, ismétlődő dokumentumok. Egy dokumentum egy kategória tagja legyen, a mintában ne ismétlődjön. |
| DC | Borítéktárs bővítés, ZZ kód hiánya, üres boríték, saját kód megőrzése, visszavétel és QM-szöveg megőrzése. |
| QM | Teljes kategória kizárása, nem csak a minta; több kategória közös rollbackje; nem mentett adatok melletti PDF-lekérés. |
| Állapotok | Minden engedélyezett és tiltott átmenet; jelzők és lezárási adatok egyezése. CL → QM elutasítása. |
| Lezárás | Prioritásablak megszakítása, megváltozott lista, proxyhiba, külső siker utáni státuszhiba, bizonytalan jelzés és ismételt indítás. |
| Státuszparser | Hiányos sor, érvénytelen UTC, azonos időpont több státusszal, hibaszövegben pontosvessző, hiányzó és duplikált dokumentumválasz. |
| AD feltétel | Napló nélküli dokumentum, korábbi D utáni újabb más esemény, mindenkinél legutolsó D, valamint azonos maximumon D és más esemény. |
| Messenger | Pontosan hét napos határ, hónapváltás, hibás időbélyeg, visszaadott státusz, eredeti sor változása és üzleti mezők megőrzése. |
| Cockpit és RIP | Stockváltás nem mentett adatokkal; lezárógomb külső hívásának ellenőrzése; nyomdai egyedi borítékszám és dátumszűrés. |

## Kiemelt forráseltérések

A cockpit közvetlen QM → CL váltása megkerüli a külön lezáró riport Inspire-hívását. A cockpit CL → QM gombkérése nem engedélyezett a központi állapotgépben. Ezeket a kezelői folyamat elfogadásakor elsőként kell tisztázni.

A stockképző kommentjei feltöltést is említenek, de az aktív ág a korábban elkészített csomagfájlokra hivatkozik. A dokumentumhalmaz XML-jelenléttel szűrt, a csomaghozzárendelés viszont a teljes kijelölésre vonatkozik. Hiányos XML-adatnál a kétféle stockhivatkozás és a későbbi darabszámok eltérhetnek.

A külön lezáró metódus és a QM COMPLETE_STOCK üresboríték-kezelése eltér. A DOC_RIP jogosultsági, dátum-, borítékszám- és időpontkezelése célzott ellenőrzést igényel. A dokumentumstátusz D esemény miatti lekérdezési kihagyása és az AD-hez használt legutolsóesemény-feltétel sem azonos szabály.

Ezek a tételek statikus forrásmegfigyelések és ellenőrzési javaslatok. A dokumentum elkészítéséhez nem történt ABAP-módosítás, aktiválás vagy üzleti tesztadat változtatása.

Források: [F01], [F02], [F08], [F09], [F16], [F17].

# 19 Forrásjegyzék és objektumleltár

A dokumentum a 2026. október 26-i, 39 objektumos projektmentésből, valamint a 2026. október 27-én külön beolvasott nyolc objektumból készült. A hét új tábladefiníció és az új QM-osztály explicit active verzióval érkezett. A korábbi mentés include-jai a GetInclude alapértelmezett verziójából származnak; a mentési jegyzék rögzíti az egyes fájlok eredetét.

A 2026. október 26-i export gyökere: 05_FINAL/abap-2026-10-26. Az alábbi F hivatkozások ehhez a projektbeli könyvtárhoz viszonyított fájlokat jelölnek. A hivatkozott metódus- és rutinnevek közvetlen keresést tesznek lehetővé a forrásban.

| Jel | Forrásfájl és lényegi hely |
| F01 | ZPR_CREATE_STOCK.abap – CREATE_STOCK, PROCESS_PACKAGE, GET_STOCK_ID, GET_STOCK_SIZE. |
| F02 | ZCL_PR_STOCK.abap – CHANGE_STATUS, CHECK_STATUS, UPDATE_STATUS, GET_STOCK_HEADER, CLOSE_STOCK. |
| F03 | ZCL_PR_QM_SAMPLER.abap – BUILD, PICK_SAMPLE, BUILD_CONDITIONS, CONVERT_VALUE, MATCHES. |
| F04 | ZCL_PR_QM_DATA.abap – GET_CANDIDATES, GET_OVERVIEW, SET_BLOCK_QM, szöveg- és stockfrissítések. |
| F05 | ZPR_QM.abap – START, OPEN_EDITOR, SAVE, CHANGE_RELEASE, SHOW_PDF, DOWNLOAD, cockpitadapterek. |
| F06 | ZPR_DC_FRAME.abap – RUN_REPORT, CHANGE_DC_STATUS, LOCK_STOCK. |
| F07 | ZPR_CLOSE_STOCK.abap – LCL_STOCK és LCL_VIEW, RELEASE_EXECUTE, MARK_UNCERTAIN. |
| F08 | ZPR_DOC_STATUS.abap – LCL_RESPONSE, PROCESS_LOCKED_STOCK, SAVE_DOCUMENT, UPDATE_STOCK_DELIVERY. |
| F09 | LZPR_COCKPITO01.abap, LZPR_COCKPITTOP.abap, LZPR_COCKPITU01.abap, LZPR_COCKPITUXX.abap, Z_PR_COCKPIT.abap. |
| F10 | ZPR_DCQM_EXCLUDE.abap – SELECT_DATA, eseménykezelők, SAVE_DATA, SAVE_ROW. |
| F11 | ZPR_DCQM_EXCLUDE_C01.abap, ZPR_DCQM_EXCLUDE_O01.abap, ZPR_DCQM_EXCLUDE_I01.abap. |
| F12 | ZPR_MESSAGEQUEUE_QUERY.abap – RUN, PREPARE_RESULT, SAVE_RESULT, LCL_AGE. |
| F13 | ZCL_PR_INSPIRE_GW.abap – a négy gateway-szolgáltatás és RAISE_PROXY_ERROR. |
| F14 | ZPR_MQ_PROXY.abap – QUERY_MESSENGER. |
| F15 | ZPR_MQ_DISPLAY.abap – SALV-megjelenítés és mentési parancs. |
| F16 | ZPR_MQ_TESTS.abap – időhatár-, válasz- és adatmegőrzési tesztek. |
| F17 | ZPR_DOC_RIP.abap, ZPR_DOC_RIP_O01.abap, ZPR_DOC_RIP_I01.abap. |
| F18 | ZPRT_DCQM.table. |
| F19 | ZPRT_DCQMLT.table. |
| F20 | ZPRT_EMAIL_SLOG.table. |
| F21 | ZPRS_DCQM_REPORT.structure, ZPRB_EMAIL_SLOG.ttyp.json, ZPRB_SLOG_EMAIL.ttyp.json. |
| F22 | ZIF_PR_INSPIRE_GW.abap, ZIF_PR_QM_DATA.abap, ZIF_PR_QM_RANDOM.abap. |
| F23 | ZCL_PR_LOG.abap. |
| F24 | ZPRC_DCCODE.table. |

## A kiegészítő MCP mentés

A következő objektumok nyers MCP-válasza és kinyert tartalma a projekt 01_SOURCES/2026-10-27_mukodesi-leiras-mcp_WIP könyvtárában található. A manifest fájl a lekérési paramétert, időpontot, fájlnevet és SHA256-értéket tartalmazza. Táblaüzleti adatok és személyes dokumentumok lekérése nem történt; a kiegészítés repository-forrást és definíciót tartalmaz.

| Jel | Objektum | Kinyert fájl |
| M01 | ZCL_PR_QM_EXCLUSION | ZCL_PR_QM_EXCLUSION.abap |
| M02 | ZPRT_STOCK | ZPRT_STOCK.table |
| M03 | ZPRT_PACKAGE | ZPRT_PACKAGE.table |
| M04 | ZPRT_QMSAMPLE | ZPRT_QMSAMPLE.table |
| M05 | ZPRT_QMEXCL | ZPRT_QMEXCL.table |
| M06 | ZPRC_QMCAT | ZPRC_QMCAT.table |
| M07 | ZPRC_QMCAT_FLT | ZPRC_QMCAT_FLT.table |
| M08 | ZPRT_DOC_SLOG | ZPRT_DOC_SLOG.table |

## Lefedettség

Az elsődleges mentés 8 főprogramot, 14 include-ot, 6 osztályt, 3 interfészt, 1 függvénymodult, 4 táblát, 1 struktúrát és 2 táblatípust tartalmaz. A teljes eredeti leltár a 2026-10-26_export-manifest_WIP.json fájlban szerepel. A ZPR_STOCK_REPORT_O01 és ZPR_STOCK_REPORT_I01 a külön lezáró riport PBO és PAI include-jai; a ZCL_PR_QM_RANDOM a véletlenszám-szolgáltató.

A generált proxyk, valamennyi DDIC-függőség, dynpro és GUI-státusz teljes mentése nem része ennek a forráscsomagnak. A régi QU5- és DHC-jegyzetek migrációs előzmények, a korábbi draftok és patchek összehasonlítási anyagok. A működési állításoknál a hivatkozott megvalósítás és a dátumozott kiegészítés az irányadó.
