# ZPR_CLOSE_STOCK – a hat kérés elemzése és módosítási terve

Státusz: **WIP** · Dátum: **2026-10-17**

**Eredmény:** az 1–5. pont megvalósításához a riport módkezelését, a zár életciklusát, a lezárás osztályhívását és a megjelenítés fejlécét kell összehangolni. A lezárási adatbázis-UPDATE a `ZCL_PR_STOCK=>CLOSE_STOCK` felelőssége legyen. Új kivételkezelést most nem tervezünk.

Ez kizárólag elemzés: ABAP-forrás, DDIC- és képernyőobjektum nem módosult. A korábbi [kérdésenkénti jegyzet](<2026-10-17_close-stock-kerdesek-megoldas_WIP.md>) helyett ez a pontosított terv irányadó; a korábbi dokumentum megmaradt.

## Kiindulópont és bizonyosság

- Elsődleges forrás: [ZPR_CLOSE_STOCK.abap](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap>), 983 soros, október 17-én exportált változat. A lent megadott riportbeli sorszámok erre vonatkoznak.
- A két közös include: [ZPR_STOCK_REPORT_O01.abap](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/05_FINAL/abap-2026-10-17/ZPR_STOCK_REPORT_O01.abap>) és [ZPR_STOCK_REPORT_I01.abap](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/05_FINAL/abap-2026-10-17/ZPR_STOCK_REPORT_I01.abap>).
- Osztályreferencia: [ZCL_PR_STOCK.abap](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/01_SOURCES/DHC/ZCL_PR_STOCK.abap>). **Régebbi helyi másolat, nincs a mai exportban.** Az osztályról leírt hiányok erre a másolatra igazoltak; az aktív SAP-verzió eltérhet.
- Mezőreferencia: [ZPRT_STOCK.table](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/01_SOURCES/DHC/ZPRT_STOCK.table>), szintén korábbi helyi export.
- A korábbi megjelenítés mintája: [QU5 ZEBF_PR_STOCK_REPORT.abap](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/01_SOURCES/QU5/ZEBF_PR_STOCK_REPORT.abap>), különösen az 586–615. sor.
- A kérés „ami lent van” melléklete ebben az üzenetben nem szerepel. Ezért annak pontos látványát nem lehet ellenőrizni; az 5. pontban a darabszámos fejrész értelmezésével dolgozunk.

Új SAP-kapcsolati kísérlet nem történt; a korábban előírt leállási szabályt követtem. A jelenlegi SAP-elérhetőség és aktív állapot nincs ellenőrizve. Új HTTP-hiba vagy automatikus jóváhagyási elutasítás ebben a munkában nem történt. Az elemzéshez a helyi források elegendők.

**Felhasználói pontosítás:** a „CR* mezők” alatt a **lezárási és CH* mezőket** kell érteni. A létrehozási `CRUSER`, `CRDATE`, `CRTIME` nem írandó felül.

## 1. Már lezárt stock: üzenet és megtekintés

**Mi működik most?** A `DETERMINE_MODE` (178–192. sor) már felismeri, ha `CLOSED` nem üres vagy `STATUS = 'CL'`, és `GV_MODIF = ABAP_FALSE` lesz. Emiatt a lezáró ALV-gomb sem kerül ki.

**Mi hiányzik?** A rutin csak a `GV_BLOCK_REASON` szövegét tölti. Induláskor senki nem jeleníti meg üzenetként. A `RELEASE_STOCK` 256–259. sorában van üzenet, de megtekintési módban oda a rejtett gombbal eleve nem lehet eljutni.

**Javasolt módosítás:**

1. A mód megállapítása után, a `CALL SCREEN 0100` előtt egyszer jelenjen meg információs üzenet: **„A stock engedélyezve van, csak megtekintés lehetséges.”**
2. Erre külön `SHOW_MODE_MESSAGE` rutin használható; ne minden PBO-ciklusban jelenjen meg újra.
3. A megtekintési cím és a lezáró gomb hiánya maradjon összhangban a móddal.
4. Ha frissítés közben vált megtekintési módra, az új tiltási ok akkor is váljon láthatóvá; ne csak induláskor kapjon tájékoztatást a felhasználó.

Új üzenethez fordítható ZPR-üzenet vagy szövegelem javasolt. Konkrét szabad SE91-számot a helyi export alapján nem foglalunk le. A hosszú szöveget nem szabad egyetlen, 50 karakteres MESSAGE-helyettesítőbe tenni; rövid részek vagy rendes üzenetszöveg szükséges.

## 2. Nem QM-státusz: tájékoztatás, lezárás nélkül

**Most:** a `DETERMINE_MODE` már tiltja a lezárást, ha `STATUS <> 'QM'`. Itt is az üzenet tényleges megjelenítése hiányzik.

**Javaslat:** ugyanaz a közös üzenetkezelés jelenítse meg: **„Csak QM státuszú stock zárható le. Csak megtekintés lehetséges.”** Mellette megadható a tényleges státusz; az üres státusz megnevezése legyen „Nyitott”.

Az állapotszabály:

| Állapot | Mód | Üzenet | Lezáró gomb / saját zár |
|---|---|---|---|
| `CLOSED` nem üres vagy `STATUS = CL` | Megtekintés | Engedélyezve van, csak megtekintés | Nincs / nincs |
| Nem lezárt, `STATUS <> QM` | Megtekintés | Csak QM zárható le | Nincs / nincs |
| `STATUS = QM`, de meglévő külsőállapot-tiltás él | Megtekintés | A külső állapot ellenőrizendő | Nincs / nincs |
| `STATUS = QM`, nincs tiltás és sikerült zárolni | Lezárás engedélyezett | Nincs tiltó üzenet | Van / van |
| Egyébként lezárható, de más zárolja | Megtekintés | A stockot más felhasználó zárolja | Nincs / nincs saját zár |

A már meglévő `STOCK_STATUS_ER` / `GV_UNCERTAIN` tiltást nem szabad a módkezelés egyszerűsítése közben megkerülni. Ennek új kivételkezelési logikáját most nem dolgozzuk ki.

## 3. Stockzár és lezáró ALV-gomb

**Most:** a `LOCK_STOCK` (417–428. sor) már az `ENQUEUE_EZPRT_STOCK` funkciót használja, de csak a `RELEASE_STOCK` 267. sorában fut le. A 324. sor feloldja. A lista megnyitásától a gombnyomásig tehát nincs saját zár.

Az „AB-zárat” a meglévő SAP enqueue stockzárként értelmezzük. Ezt kell használni; nem a felhasználói gondolkodási időre nyitva tartott SQL-tranzakciót.

**Javasolt életciklus:**

1. Induláskor: stock olvasása → `DETERMINE_MODE` → ha lezárható, enqueue → a stock újraolvasása és a mód újraellenőrzése már saját zár alatt → adatok kiválasztása → képernyő.
2. Saját zár nélkül a lezárás nem engedélyezett. Idegen zár esetén a lista megtekinthető, és jelenjen meg a zárolás oka.
3. A zár és mód összehangolását egy `SYNC_LOCK` rutin végezheti. Ha már a saját zár él, ne kérjen újabb enqueue-t. A mostani `LOCK_STOCK` eleji feltétel nélküli zárjelző-törlést ehhez hozzá kell igazítani.
4. Frissítéskor ismét egyezzen a mód és a zár: lezárhatónál legyen saját zár; megtekintésnél a saját zár szabaduljon fel. A korábban idegen zár miatt megtekintő felhasználó a Frissítéssel újra megkísérelheti a zárolást.
5. Sikeres lezárás után: friss stockadat → megtekintési mód → zár feloldása → ALV-eszköztár frissítése.
6. Kilépéskor, valamint minden olyan korai visszatérésnél, ahol már lehet saját zár, azt fel kell oldani. Különösen: indulás utáni sikertelen adatkiválasztás és frissítési hiba.

A meglévő `_SCOPE = '1'` pár maradhat a dialógus által birtokolt zárhoz. A `GV_LOCKED_STOCK` csak a ténylegesen megszerzett zárat jelezze; a `DEQUEUE` kizárólag erre fusson. A többi stockmódosító út azonos zárhasználatát is ellenőrizni kell, mert az enqueue csak az együttműködő írókat védi.

**A gomb már létezik:** `ON_TOOLBAR` (134–151. sor), funkciókódja `RELEASE`, jelenlegi felirata „Engedélyezés”. Nem kell második gombot készíteni. A felirat legyen **„Lezárás”**, megjelenési feltétele pedig:

- a stock lezárható (`GV_MODIF = ABAP_TRUE`);
- nem folyik lezárás (`GV_BUSY = ABAP_FALSE`);
- a saját zár az adott stockra él (`GV_LOCKED_STOCK = P_STOKID`).

Ugyanezt a gomb eseménykezelője is ellenőrizze. Az eszköztár újraépítéséhez a meglévő `SET_TOOLBAR_INTERACTIVE` használható; a gomb elrejtése önmagában nem üzleti védelem.

## 4. A gomb a ZCL_PR_STOCK lezáró metódusát hívja

### A jelenlegi két út eltérése

| Terület | Riport jelenleg | Régi helyi `ZCL_PR_STOCK=>CLOSE_STOCK` |
|---|---|---|
| Inspire | `SEND_PRIORITY`, 567–633. sor | Saját proxyhívás |
| Prioritás | Saját popup és megerősítés | Újabb saját popup |
| Eredmény | `GV_REMOTE_SUCCESS`, `GV_SAVED` | Nincs visszatérő sikerjelző |
| Stockmentés | `SAVE_RELEASE`, teljes lezárási mezők | `UPDATE_STATUS('CL')`, csak státusz |
| Kizárt borítékok | Átadja az `EXCLUDE_ENVELOPES` listát | Az átadás ki van kommentezve |
| Kizárások ragszámai | `ZPR_TERTI` / `ZISU_F064` kezelés | Nincs megfelelő megvalósítás |

**Következmény:** egy egyszerű metódushíváscsere még nem elegendő. Elveszhetnek a meglévő üzleti műveletek, kétszer jelenhet meg prioritáspopup, és a riport nem tudja biztosan, hogy megtörtént-e a lezárás.

### Javasolt felelősség és interfész

- **Riport:** megjelenítés, saját stockzár kezelése, prioritás és megerősítés, friss állapot/adatok ellenőrzése, metódushívás, eredmény megjelenítése.
- **`CLOSE_STOCK`:** a lezárás üzleti ellenőrzése, az egyetlen Inspire-hívás, siker után a teljes helyi lezárás mentése, eredmény visszaadása.

A metódus kapjon opcionális `IV_PRIORITY TYPE ZPRD_PRIORITY` bemenetet és `EV_SUCCESS TYPE ABAP_BOOL` kimenetet. Az eddigi hívók ettől szintaktikailag megtarthatók. Ha a riport átadta a prioritást, ne jelenjen meg második popup; az átadottság vizsgálata `IS SUPPLIED` legyen, az érték érvényessége külön ellenőrzés. Ha régi hívó nem ad prioritást, a korábbi popup út megmaradhat, de annak alapértékéhez ténylegesen beolvasott stockadat kell.

Az `EV_SUCCESS` kezdetben hamis, és csak az explicit sikeres Inspire-válasz **és a sikeres helyi üzleti mentés** után lehet igaz. A külső siker önmagában nem jelent kész SAP-lezárást. A riport sikerüzenetét és módváltását ez vezérelje.

A metódus a proxyhívás előtt friss adatból is ellenőrizze a lezárhatóságot. A riportnak már birtokolnia kell a stockzárat; a metódus nem oldhatja fel a hívó által megszerzett zárat. A közvetlen egyéb hívók ugyanilyen zárhasználata külön ellenőrizendő.

### Mentendő mezők – a pontosítás alapján

| Mező | Sikeres lezáráskor |
|---|---|
| `STATUS` | `CL` |
| `CLOSED` | `X` |
| `PRIORITY` | A ténylegesen elküldött prioritás |
| `ERDAT_CLO`, `ERNAM_CLO`, `ERTIM_CLO` | Lezárás dátuma, felhasználója, ideje |
| `CHDATE`, `CHUSER`, `CHTIME` | Ugyanezen módosítás dátuma, felhasználója, ideje |
| `CRDATE`, `CRUSER`, `CRTIME` | Megőrzendő létrehozási adatok |

A jelenlegi riport 673–686. sorában ez a mezőlista már lényegében megvan; ezt kell az osztály lezárási útjába átvinni. Az UPDATE feltételeit is meg kell őrizni: az adott stock, `STATUS = QM`, üres `CLOSED` és üres `STOCK_STATUS_ER`. Pontosan egy módosított rekord várható.

A lezárás teljes helyi üzleti mentésének egy tranzakciója és egy felelőse legyen. A `CLOSE_STOCK` lezárási ágában a csak státuszt mentő, önállóan COMMIT-oló `UPDATE_STATUS` nem megfelelő helyettesítő. A más célra is használt `UPDATE_STATUS` általános átírása ehhez nem szükséges. A már működő közvetlen UPDATE elegendő; külön update-task funkció bevezetése nem következik a kérésből.

### Mit kell megőrizni az átálláskor?

1. A riport `SEND_PRIORITY` és `SAVE_RELEASE` hívását egy közös osztályhívás váltsa ki. Egy lezáráskor csak egy proxyhívás és egy stocklezáró mentés történjen.
2. A friss stockellenőrzés, a megjelenített és aktuális adatok összevetése és az üres stock ellenőrzése maradjon meg. Az összevetés előtti rendezés a mai forrás 286. sorában **már szerepel**, ezt nem kell új javításként felvenni.
3. A kizárt borítéklista átadását és a kapcsolódó ragszámkezelést nem szabad észrevétlenül elhagyni. Ha a jelenlegi üzleti működést átvisszük az osztályba, ahhoz típusos paraméter vagy osztálybeli adat-előállítás is szükséges. Ennek részletes kizárási szabályait most nem tervezzük újra.
4. A korábbi „kivételeket most ne kezeljük” kérésből nem vezetünk le új, minden kizárt tételes stockot tiltó szabályt. Az ilyen átmeneti korlátozás külön üzleti döntés lenne.
5. A meglévő sikeres lezárási napló darabszámait meg kell őrizni. Az osztály és a riport naplózását össze kell hangolni, hogy ugyanarra a műveletre ne jelenjen meg két külön naplóablak. A régi osztály `PACKAGE`, a riport `STOCK` alobjektumot használ; ehhez a stocklezárási naplóhoz a riport jelenlegi `STOCK` értéke az irányadó javaslat.
6. A régi helyi [cockpit include](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/01_SOURCES/DHC/LZPR_COCKPITO01.abap>) 99–111. sora a `CLOSE_STOCK` után feltétel nélkül újra `UPDATE_STATUS('CL')`-t hív. **Ha ez az ág még aktív**, a külön státuszírást el kell hagyni: a teljes mentés az osztályé, a cockpit pedig az eredmény alapján frissítsen. Pusztán a sikerjelző bevezetése ezt a régi hívót nem javítja meg.

Ez a rész az átállás szükséges funkcionális határa; nem új kivételkezelési terv.

## 5. Miért nem jelenik meg a RELEASE_STOCK-ban megtalált rész?

**A forrásból biztosan megállapítható ok:** a riport 327–339. sorában a „Nyomtatási sorok száma”, „Kizárt sorok száma” és „Engedélyezett sorok száma” szövegek `ADD_MESSAGE` hívások. Ezek a BAL-naplóba gyűjtenek bejegyzést, és csak `GV_SAVED = ABAP_TRUE`, tehát sikeres lezárás után futnak.

Ezek nem ALV-fejlécet rajzolnak. Megtekintéskor nem indul lezárás, ezért ez a blokk nem fut le. **A megoldás nem a RELEASE_STOCK meghívása megjelenítéskor**, mert az üzleti lezárást és Inspire-hívást is elindítaná.

**Ha a hiányzó melléklet a stockazonosítót és darabszámokat mutató fejrész volt**, a javasolt külön megjelenítési tartalom:

- Stock ID: `P_STOKID` / `GS_STOCK-STOCK_ID`;
- Nyomtatási sorok száma: `GV_TOTAL`;
- Kizárt nyomtatási sorok száma: `GV_EXCLUDED`;
- Engedélyezett sorok száma: `GV_ALLOWED`, amennyiben ezt is várják.

Ezek az értékek már a `SELECT_DATA` végén rendelkezésre állnak (232–233. sor), ezért megtekintési módban is kiírhatók. Az ALV adattáblája jelenleg **csak a kizárt tételeket** tartalmazza (208–209. sor): a `GT_ALV` sorszáma nem az összes nyomtatási sor száma. Kizárás nélküli stocknál ezért az üres ALV és a pozitív összdarabszám helyes kombináció lehet.

### Megjelenítési megoldás

A meglévő [0100 flow/layout útmutató](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/ZPR_STOCK_REPORT_0100_flow.abap>) már javasol csak kiírható fejlécmezőket. Ha ezeket az SE51-képernyőn létrehozták, a legegyszerűbb azokat használni. A mai export nem tartalmazza a teljes képernyőlayoutot, ezért a tényleges jelenlétük nem igazolható.

Ha a QU5-tel azonos nagybetűs/formázott blokk szükséges, a QU5 586–615. sorában meglévő minta alkalmazható: felső `CL_GUI_DOCKING_CONTAINER`, benne `CL_DD_DOCUMENT`. Ehhez külön `BUILD_HEADER` rutin javasolt, amely csak megjelenít:

1. Első képernyőlétrehozáskor a konténer és a dokumentum elkészül.
2. Az adatok kiválasztása után, frissítéskor és lezárás utáni újraolvasáskor a fejléc frissül.
3. A fejléc mindkét módban látszik; nem függ a `GV_SAVED` értékétől.
4. Kilépéskor a hozzáadott vezérlők felszabadulnak.

A két fejlécváltozat közül egyet kell használni, a már meglévő képernyőt és az ügyfél mintáját figyelembe véve. A pontos kinézet a hiányzó melléklet nélkül nyitott; ettől az ok és a szükséges eseményszétválasztás már megállapítható.

## 6. Kivételkezelés: most nincs új feladat

A kérésnek megfelelően új TRY/CATCH-struktúrát, hibakategóriákat, újrapróbálási működést és helyreállítási folyamatot nem dolgozunk ki. A meglévő védelmek eltávolítása sem része a javaslatnak.

Az 1–5. pont minimális sikerszabálya ettől független: **csak az explicit sikeres Inspire-válasz és a sikeres helyi mentés eredményezhet lezárt stockot és sikerjelzést.** A részletes kivételes esetek a Márkkal tervezett külön egyeztetésre maradnak. Bizonytalan külső eredményből most nem vezetünk le automatikus újraküldést.

## Érintett helyek és javasolt átvezetési sorrend

| Objektum / rész | Szükséges változás |
|---|---|
| `ZPR_CLOSE_STOCK`: `START-OF-SELECTION`, `DETERMINE_MODE` | Üzenet megjelenítése, saját zár megszerzése, zár alatti újraellenőrzés |
| `LOCK_STOCK`, `UNLOCK_STOCK`, új `SYNC_LOCK` | A lista teljes használatára összehangolt zár és mód |
| `ON_TOOLBAR`, `RELEASE_STOCK` | „Lezárás” gomb saját zár mellett, osztályhívás, eredményvezérelt frissítés |
| `RELOAD_DISPLAY`, `EXIT_SCREEN`, indulási hibaágak | Mód, eszköztár, fejléc és zár következetes frissítése/felszabadítása |
| `ZCL_PR_STOCK=>CLOSE_STOCK` | Prioritás és eredmény interfész, közös lezárási mentés, meglévő üzleti tartalom megőrzése |
| `CREATE_CONTROLS_0100`, `REFRESH_GRID`, `FREE_CONTROLS` / SE51 0100 | A választott fejlécváltozat bekötése |
| Régi közvetlen cockpit-hívó, ha még aktív | A feltétel nélküli utólagos CL-státuszírás megszüntetése |
| Közös O01/I01 include-ok | Az események már be vannak kötve; új kezelő általában nem szükséges, a hívási láncot ellenőrizni kell |

Az átvezetés előtt az aktuális osztályt, a közvetlen hívókat, a stocktáblát és a 0100-as képernyőt ellenőrizni kell. **Ehhez SAP-elérést csak kifejezett újrapróbálási engedéllyel szabad indítani.** Ezután: osztályinterfész és mentési felelősség → riportbeli mód/zár/gomb → fejléc → szükség esetén cockpit-hívó igazítása → szintaxis/ATC és célzott GUI-próba.

## Későbbi elfogadási ellenőrzés

| Eset | Elvárt eredmény |
|---|---|
| Már lezárt stock | Kért üzenet, megtekintési mód, nincs lezáró gomb és saját zár; fejrész látszik |
| DM vagy nyitott stock | Csak QM zárható le üzenet; megtekintés, nincs lezáró gomb |
| Szabad QM-stock | Saját stockzár már a listán, „Lezárás” gomb látszik |
| Ugyanaz a QM-stock másik munkamenetben | Megtekintés, zárolási tájékoztatás, nincs lezáró gomb |
| Frissítéskor mód- vagy zárváltozás | Megfelelő üzenet, cím, gomb, fejléc és zárállapot |
| Sikeres lezárás | Egy prioritáskérés és egy Inspire-hívás; `CL`, `CLOSED = X`, prioritás, lezárási és CH* mezők mentve; CR* változatlan |
| Siker utáni állapot | Megtekintés, nincs lezáró gomb, saját zár felszabadult |
| Kilépés / zár megszerzése utáni korai visszatérés | Nem marad saját stockzár |
| Megtekintés és ALV-rendezés | Nincs Inspire-hívás; a fejléc összdarabszáma független az ALV kizárássorszámától |
| Kizárt tételeket tartalmazó stock osztályra átállás után | A korábbi borítékátadás és ragszámkezelés nem veszett el |

Ezek végrehajtandó ellenőrzések, nem lefutott tesztek. SAP-fordítás, ATC, ABAP Unit és GUI-teszt ebben az elemzési lépésben nem történt.
