# Transzportkérelem QA-ellenőrzése – fejlesztői szabályleírás

**Dátum:** 2026-10-28 · **Státusz:** WIP · **Példakérelem:** DHCK906030.

A leírás a helyben megőrzött SCI/Onapsis-eredményösszesítés alapján segít megelőzni és javítani a jelzett kódmintákat. A felhasználó a DHCK906030 kérelmet példaként elfogadta. A kérelem tényleges elengedésekor lefutott ellenőrzés teljes konfigurációja és eredménye jelenleg nincs lekérve.

## 1. Az ellenőrzés azonosítása és a bizonyíték határa

| Adat | Rendelkezésre álló információ | Bizonyíték |
|---|---|---|
| Példakérelem | DHCK906030 | Korábbi helyi SCI-leírás; a felhasználó most példaként elfogadta |
| Korábbi előellenőrzés | 2026-10-18, inspekcióverzió 002 | Felhasználói képernyőkből készült helyi összefoglaló [F1] |
| Ellenőrzési variáns | Z_CONTROL_FOR_CODE | Ugyanennek az előellenőrzésnek a dokumentációja [F1] |
| Ellenőrzési ág | Control for Code Check → Control for Code by Onapsis | Megőrzött képernyőleírás [F2]; a kivágáson a variánsnév/SID nem látszott |
| Eredményösszesítés | 0 hiba, 209 figyelmeztetés, 141 információ | Korábbi előellenőrzés helyi összefoglalója [F1] |
| Elengedéskori hozzárendelés | Nem ismert | Az előellenőrzés és az elengedési kapu azonossága nincs igazolva |
| Ellenőrző rendszer, mandant, Onapsis-verzió/policy | Nincs friss igazolás | A kérelemszám előtagja önmagában nem rendszerazonosítás |
| Blokkoló prioritások, baseline, kivételek | Nem ismert | A 0 hiba nem bizonyítja az elengedhetőséget |

A 2026-10-28-i MCP stdio-eszközleltár sikeresen lekérhető volt. A QA-táblák felderítését célzó **első rendszeradat-olvasás** `GetSqlQuery` művelete 13:49:43-kor (Europe/Budapest; 12:49:43 UTC) `network / EACCES` hibával megszakadt. Nem érkezett értelmezhető SAP-adatválasz; HTTP 401-et nem észleltünk, és ebben a körben automatikus jóváhagyási elutasítás sem érkezett. A hiba nem bizonyítja, hogy maga az SAP-rendszer áll. Az érintett kapcsolat további használata leállt, új kísérlet nem történt. Bizonyíték: [MCP-gyűjtési jegyzék](../01_SOURCES/2026-10-28_elengedesi-qa-mcp_WIP/README.md).

**Olvasási szabály:** a következő öt kód és angol megnevezés a korábbi eredményösszesítésből származik. A magyar javítási útmutató fejlesztői értelmezés; nem a teljes Onapsis-szabályszöveg fordítása. A pontos detektálási feltételek és paraméterek hiányoznak.

## 2. Az ismert öt szabály áttekintése

| Jelentéskód | Megőrzött szabálynév | Korábbi figyelmeztetésszám | Fejlesztői teendő |
|---|---|---:|---|
| 0317 | Modification of Global Variables in Subroutine | 128 | A rutin állapotváltoztatása jelenjen meg az interfészében |
| 0245 | Hard-Coded Text in MESSAGE … WITH | 19 | Az állandó, felhasználói szöveg legyen fordítható |
| 0068 | Incomplete CASE | 8 | Az ismeretlen/nem kezelt értéknek legyen tudatos kezelése |
| 0089 | Usage of LOOP AT itab INTO | 7 | Vizsgáld felül a sorok másolását és a módosítási szemantikát |
| 0079 | Low Performance Table Access on 'Standard' Tables | 6 | A keresési mintához illő kulcsot és hozzáférést válassz |

Az öt sor összesen **168** figyelmeztetést fed le a korábbi 209-ből. További **41 figyelmeztetés** és **141 információ** szabályonkénti részletezése nincs megőrizve ebben az összesítésben. Nem állítjuk, hogy a variáns csak ezt az öt szabályt tartalmazza. A kategóriákhoz nem rendelünk kitalált numerikus prioritást vagy elengedést blokkoló hatást.

## 3. 0317 – Globális változók módosítása alprogramban

**Mit jelez?** A szabály megnevezése alapján egy alprogram globális állapotot módosít. A hívó számára ez rejtett kimenet: a rutin hatása nem olvasható ki pusztán a paraméterlistából. Az egyes érintett sorok és a pontos kivételek a teljes findinglista nélkül nem azonosíthatók.

**Javítási elv:** az adatfüggőséget tedd láthatóvá. A csak olvasott adat bemenet, a módosított adat kimenet vagy kifejezett változó paraméter legyen. Meglévő FORM-rutinnál célzott USING/CHANGING paraméterezés is megfelelő irány lehet; pusztán e találat miatt nem indokolt az egész program átírása osztályokra. A lokális munkaváltozó ne ugyanannak a globális mellékhatásnak az elfedése legyen.

**Review és ellenőrzés:** keresd meg az összes hívót, és vesd össze a korábbi/új állapotváltozásokat. Vizsgáld a többszöri hívást, az üres bemenetet és a hibás visszatérést. A képernyőállapothoz vagy vezérlőkhöz kötött szükséges globális adatot a konkrét finding és a program működése alapján kezeld; ne végezz vak tömeges paraméterezést.

## 4. 0245 – Beégetett szöveg a MESSAGE … WITH utasításban

**Mit jelez?** A MESSAGE paraméterei között felhasználónak megjelenő állandó szöveg szerepel. A projekt korábbi QA-jelzései önálló MESSAGE-szövegliterálokat is érintettek [F3]; ezek szabályazonosítóját nem azonosítjuk automatikusan a 0245-tel.

**Javítási elv:** az állandó természetes nyelvi szöveg meglévő vagy egyeztetetten létrehozott T100-üzenetbe, illetve szövegszimbólumba kerüljön. Egy azonosító, dokumentumszám vagy más dinamikus üzleti adat maradjon paraméter. A szöveg literálból változóba másolása nem teszi azt fordíthatóvá.

**Review és ellenőrzés:** a szövegkarbantartás és a szükséges fordítás is kerüljön a szállításba. Őrizd meg az üzenet típusát, a DISPLAY LIKE viselkedést, a paraméterek sorrendjét és az üzenet utáni vezérlést. Ellenőrizd a tényleges megjelenést a használt nyelven. A forráskód önmagában nem hozza létre a text poolt vagy a T100-bejegyzést.

## 5. 0068 – Hiányosan kezelt CASE

**Mit jelez?** A CASE nem kezeli a szabály által elvárt összes esetet. A pontosan elvárt ágak a finding hosszú szövegéből és a vizsgált mező üzleti értékkészletéből állapíthatók meg.

**Javítási elv:** határozd meg az elfogadott értékeket, és az azokon kívüli bemenet üzleti kezelését. Szükség szerint adj érdemi WHEN OTHERS ágat: visszajelzést, dokumentált kihagyást vagy a feldolgozás megfelelő megszakítását. Egy üres alapértelmezett ág nem helyettesíti a döntést. Az ismeretlen állapotot ne kezeld automatikusan sikeresként.

**Review és ellenőrzés:** próbáld ki az összes ismert értéket, az inicializált/üres értéket és egy ismeretlen értéket. Nézd meg, hogy hibánál nem marad-e az előző feldolgozásból vissza eredmény vagy állapot. Új hibakezelés bevezetésekor a hívó és a tranzakció viselkedése is ellenőrizendő.

## 6. 0089 – LOOP AT itab INTO használata

**Mit jelez?** A megőrzött cím az INTO használatára mutat. Az INTO a sor tartalmát munkaterületre adja át, míg az ASSIGNING a sorhoz rendel mezőszimbólumot. Ez eltérő módosítási szemantika, ezért a csere működési ellenőrzést igényel. [SAP ABAP – LOOP eredménykezelése](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/ABAPLOOP_AT_ITAB_RESULT.html).

**Javítási elv:** nézd meg, kell-e a sormásolat. Ha nincs rá szükség, az ASSIGNING csökkentheti a másolást. Ha a kód szándékosan a táblától független munkapéldányt módosít, a közvetlen sorhozzáférésre váltás megváltoztatná a működést. A pontos policy és a kivételezés ismerete nélkül nincs általános INTO-tilalom.

**Review és ellenőrzés:** keress CLEAR-t, mezőértékadást, további hívásnak átadott változó paramétert, törlést és explicit MODIFY-t a ciklusban. ASSIGNING esetén a mezőértékadás az eredeti sort érintheti. Ellenőrizd a tábla ciklus előtti/utáni tartalmát, a védett kulcsmezőket és a ciklus utáni változóhasználatot. A korábbi munkaterület ciklus utáni értékére építő kódot is számba kell venni.

## 7. 0079 – Lassú hozzáférés STANDARD belső táblához

**Mit jelez?** A keresés a táblatípussal és a használt kulccsal együtt kedvezőtlen hozzáférést eredményezhet. A korábbi összesítés példája a ZPR_CLOSE_STOCK programban a `READ TABLE lt_fields INTO ls_field` környezete [F1]. Az aktuális forráshely nincs újra ellenőrizve.

**Javítási elv:** először a keresési feltételt, gyakoriságot, sorszámot és sorrendigényt tisztázd. Ismételt kulcskereséshez megfelelő SORTED/HASHED elsődleges vagy másodlagos kulcs mérlegelhető. A másodlagos kulcsot a hozzáférésben kifejezetten ki kell választani; deklarálása önmagában nem kapcsolja át az olvasást. A kulcs karbantartásának memória- és módosítási költsége is van. [SAP ABAP – Másodlagos táblakulcsok](https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/ABENITAB_KEY_SECONDARY.html).

**Review és ellenőrzés:** a kulcs egyedisége feleljen meg az adatoknak; a sorrend és a duplikátumok kezelése maradjon helyes. Ha BINARY SEARCH a választott megoldás, igazolni kell az ahhoz illő rendezést és annak fennmaradását. Az optimalizálás nem változtathatja meg, több találatból melyik sor kerül kiválasztásra. Vizsgáld a hiányzó találat kezelését és reális adatmennyiségen a futásidőt. Egyetlen kis tábla miatt ne vezess be indokolatlan adattípuscserét.

## 8. További projektbeli QA-tanulságok

Az alábbiak más korábbi projektjelzésekből származnak [F3]. Nem bizonyított, hogy a fenti 002-es futásban vagy az elengedési kapuban is szerepeltek; szabályazonosítójuk itt nem ismert.

| Terület | Fejlesztői szabály | Ellenőrzés |
|---|---|---|
| Rendezett/hashed belső tábla | Általános beszúráshoz INSERT … INTO TABLE; a tényleges DDIC-típust és az egyedi kulcsot vizsgáld | Sorrend, duplikált kulcs, visszatérési eredmény; ne cserélj minden APPEND-et típusvizsgálat nélkül |
| SELECT és adatbázisindex | A kiválasztást a tényleges indexekkel és az üzleti hatókörrel együtt vizsgáld | Ne adj hozzá üzletileg helytelen szűrést csak a jelzés eltüntetésére |
| Törlés teljes kulccsal | Ha a szükséges teljes kulcsú sorok már rendelkezésre állnak, mérlegelhető a DELETE dbtab FROM TABLE itab | Üres bemenet, teljes kulcs, zárolás, eredmény és tranzakcióhatár |

A ZPR_TERTI korábbi esetében a boríték/dokumentum összes ragszámhoz és EXTNU-hoz tartozó sorára szükség volt. Egy új ragszámfeltétel hibásan szűkítette volna a feldolgozást. A felhasználó 2026-10-15-én visszajelezte, hogy az index segített. Az aktív index neve és mezőlistája azonban nincs visszaolvasva; az egykori indexjavaslatot nem tekintjük ellenőrzött mai konfigurációnak [F3].

## 9. Fejlesztői ellenőrzési menet

1. Azonosítsd a kérelmet/feladatokat, az érintett objektumokat és a vizsgálandó forrásverziót. Vedd figyelembe az include-okat, DDIC-típusokat és a szövegobjektumokat.
2. Mentsd a finding kódját, teljes szövegét, kategóriáját/prioritását, objektumát, include-ját és sorát. A hiányzó mező maradjon ismeretlen.
3. A konkrét kódkörnyezet alapján készíts célzott javítást, és őrizd meg a kiválasztott rekordhalmazt, az állapotváltozásokat és a hibakezelés szerződését. Találatot ne nyomj el automatikusan.
4. Végezd el a változásnak megfelelő szintaxis-, Unit- és működési ellenőrzést. A helyi parser, az SAP-szintaxis és az ATC/SCI/Onapsis külön eredmény.
5. Igazolt elengedési variánssal, paraméterekkel, ellenőrző rendszerrel és objektumkörrel kérj összehasonlítható QA-újrafuttatást. A baseline, szűrés és kivételezés is egyezzen vagy legyen dokumentálva.
6. Dokumentáld a megmaradt találatokat és a jóváhagyott kivételeket. A teljesülést a tényleges blokkolási szabályok alapján értékeld.

A [korábbi SCI-lépésleírás](<../../../[02] context/2026-10-18_sci-qa-eloellenorzes-kerelemre_WIP.md>) bemutatja a kérelemre készített előellenőrzést. Eltérő helyi SCI-futás nem bizonyítja a központi vagy egyedi elengedési kapu teljesítését. A dokumentum nem ad felhatalmazást kérelemelengedésre, SAP-módosításra vagy aktiválásra.

## 10. Mi kell a rendszerből igazolt változathoz?

| Hiányzó bizonyíték | Mire ad választ? |
|---|---|
| Az adott elengedéshez tartozó futásazonosító/időpont és teljes eredmény | Mi futott le ténylegesen, és mely objektumokon? |
| Az elengedéskori konfiguráció, esetleges céges bővítés és központi hozzárendelés | Mi indította a futást, melyik rendszerben? |
| A tényleges variáns/policy teljes exportja és paraméterei | Mely szabályok voltak engedélyezve, milyen feltételekkel? |
| Blokkolási küszöb, baseline és jóváhagyott kivételek | Mely találat akadályozza az elengedést? |
| A történeti konfiguráció vagy változásnapló, ha azóta módosult | A mai beállítás megegyezik-e az akkori futáséval? |

A 2026-10-28-i MCP-leltár nem tartalmazott dedikált ATC/SCI/Onapsis-eredményolvasót vagy teljes QA-futtatót. Voltak általános, olvasási célú repository-, táblalekérdező és transzport-eszközök. Ezekkel a felderítés elkezdődött, de az első adatolvasási hiba miatt eredményadat nem érkezett. Új SAP-kísérlethez a munkaterületi szabály szerinti kifejezett egyszeri újrapróbálási kérés szükséges.

## 11. Források és elkészültség

- **[F1]** [SCI-előellenőrzés és a 2026-10-18-i összesítés](<../../../[02] context/2026-10-18_sci-qa-eloellenorzes-kerelemre_WIP.md>): a kérelem, variáns, verzió, számlálók és az öt jelentéskód forrása. Helyi másodlagos összefoglaló; nem teljes nyers findingexport.
- **[F2]** [A kijelölt Onapsis-ág megőrzött leírása](../01_SOURCES/2026-10-18_sci-onapsis-kijeloles_WIP.md): felhasználói képernyőbizonyíték leírása.
- **[F3]** [Projektbeli ABAP QA-ellenőrzőlista](<../../../[01] system/ABAP-QA-CHECKLIST.md>): korábbi MESSAGE-, táblatípus- és adatbázis-hozzáférési jelzések.
- **[F4]** [A mostani MCP-felderítés jegyzéke és leállása](../01_SOURCES/2026-10-28_elengedesi-qa-mcp_WIP/README.md): tényleges eszközleltár, tervezett SELECT és EACCES-hiba.
- **[F5]** SAP ABAP nyelvi dokumentáció, a 6–7. fejezetben közvetlenül hivatkozva; SAP Docs MCP-n keresztül olvasott dokumentáció, nem az érintett rendszer konfigurációja.

**Elkészült:** az öt ismert szabály fejlesztői értelmezése, javítási és review-szempontjai; további projektbeli tanulságok; forrás- és hiányjegyzék. A számlálók és helyi hivatkozások ellenőrizve.

**Hiányzik:** a tényleges elengedési ellenőrzés rendszerből lekért konfigurációja és teljes eredménye. Az aktív SAP-állapot nincs ellenőrizve. SAP-objektum létrehozása, módosítása, aktiválása és QA-futtatás nem történt; automatikus ABAP-utóellenőrzésnek nincs módosított objektumköre. A dokumentum WIP marad.
