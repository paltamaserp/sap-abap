# DC megvalósítási terv — ellenőrzési megállapítások

- Dátum: 2026-10-08
- Státusz: WIP; technikai review, üzleti döntést és SAP-tesztet nem helyettesít.
- Vizsgált terv: [2026-10-08_dc-adatellenorzes-dhc-megvalositasi-terv_WIP.md](../03_DRAFTS/2026-10-08_dc-adatellenorzes-dhc-megvalositasi-terv_WIP.md).
- Alap: a projekt QU5- és DHC-forrásai, `01_SOURCES/DHC/info.md`, a tömeges tranzakciókat leíró DOCX és a projekt döntésnaplója.

**Értékelés:** a felépítés és az átvétel fő iránya megfelelő, de a terv jelen formájában még nem adható ki önálló junior megvalósításra. Az alábbi hibákat és hiányzó működési szabályokat előbb pontosítani kell. A QU5-ből átvett viselkedés nem minden esetben hibamentes.

Az ellenőrzés statikus volt. Az aktív `ZCL_PR_LOG` lekérése ADT-n bejelentkezési hibával meghiúsult. Nem futott SAP szintaxisellenőrzés, ATC vagy funkcionális teszt; az aktív DDIC-kulcsok, indexek és naplómetódusok működése nincs igazolva.

## Megvalósítás előtt javítandó

### R1 — P1: a riport önállóan nem tiltja a DC kész stock módosítását

**Hely:** terv L8.5 és L8.7, 386–494. sor; QU5 `ZEBF_PR_DCQM_REPORT.abap`, `check_stockid`, 419–439. sor; keretprogram `check_stockid`.

A terv a riportban csak a `CLOSED` mezőt olvassa, a `DCCOMPL` ellenőrzését a keretprogramban hagyja. A keretprogram ellenőrzése után a riport szelekciós képernyőjén a Stock ID átírható. Így az A stockhoz indított módosító riport B stockra is átállítható, amelynek már kész a DC-je. A közvetlen `SUBMIT ... WITH p_modif = 'X'` út is megkerüli a keret ellenőrzését. A T14 jelenlegi tesztje ezt nem fedi le.

**Javaslat:** a riport saját maga olvassa és ellenőrizze a `CLOSED` és `DCCOMPL` mezőt. Az effektív mód meghatározása után, sikeres zárolást követően ismét olvassa a stock aktuális állapotát; csak utána kezdődhet a módosító feldolgozás. Az engedélyezés/visszavétel keretművelete is friss állapotot használjon a zárolás után, ha ezek az első kör részei lesznek.

### R2 — P1: a mentés teljes hibakezelése és naplózási tranzakciója nincs meghatározva

**Hely:** terv L8.9, 510–552. sor; QU5 `user_command_0100`, 930–998. sor.

Az új `lv_error` javítja a QU5 hibás, ciklus utáni `sy-subrc` ellenőrzését, de a váz csak az alaptábla `UPDATE` eredményét vizsgálja. A hosszú szöveg `UPDATE`/`INSERT` hibája esetén a kizárási kód és az indoklás eltérő állapotban maradhat, ha a fejlesztő a leírt vázat követi. Az SQL-kivételek kezelése sincs megadva.

A `COMMIT WORK` után hívott `go_log->close( )` működését nem ismerjük. Nem elegendő csak azt tisztázni, hogy ment-e naplót: azt is tudni kell, végez-e commitot, használ-e update taskot, milyen kivételt ad, és mi biztosítja a napló tartós mentését. Rollback esetén a ciklusban már összegyűjtött s044/s045 bejegyzések önmagukban nem tekinthetők sikeresen végrehajtott módosításnak.

**Javaslat:** minden adatbázis-írás eredményét ellenőrizni kell, az elvárt egyetlen sor módosítását is. Bármely mentési hiba esetén a teljes üzleti módosítás rollbackeljen. Az SQL-kivételeknek legyen kezelt hibakimenetük. A napló és az üzleti commit sorrendjét a `ZCL_PR_LOG` tényleges működése alapján rögzíteni kell, a stockazonosítóval kereshető naplófejléccel. Sikertelen mentés után az ALV maradjon nyitva az adatokkal, javításra/újrapróbálásra; ne másoljuk át feltétel nélkül a QU5 kilépését.

### R3 — P1: a cellás szerkesztés felülírja a már megadott kizárási okot

**Hely:** terv L8.8, 498–506. sor; QU5 `handle_data_changed`, 859–881. sor, összevetve a toolbar kizárásával, 691–700. sor.

Toolbar kizáráskor a QU5 csak az üres kódú borítéktársakra ír `ZZ`-t. A cellás módosítás ezzel szemben feltétel nélkül `ZZ`-re írja át a társak kódját. Példa: egy boríték A sora már `01` kóddal kizárt; B sor kódjának cellás megadása A okát `ZZ`-re cseréli. A szöveg cellás módosítása a társak saját szövegét is felülírja. Több cella együttes módosításakor a végeredmény a feldolgozási sorrendtől függhet.

**Javaslat:** legyen közös, pontos szabály a popupos és cellás kizárásra. Javasolt alap: a kifejezetten megadott kizárási okokat megőrizzük, az automatikus `ZZ` csak az addig nem kizárt társakat érinti. A szövegátadás és a teljes borítékra vonatkozó visszavétel külön legyen kimondva. Hibás cellaértékből ne keletkezzen tartós mellékhatás a társakon. A `check_changed_data` visszaadott `e_valid` értékét ellenőrizni kell a mentés előtt; a QU5 PAI include ezt jelenleg figyelmen kívül hagyja.

### R4 — P1, feltételes: a dokumentumkulcs bizonytalanságát nem oldja meg egy stockfeltétel

**Hely:** terv L0, L3 és L8.9, különösen 162., 219. és 524. sor.

A terv a `DOC_NO` egyediségét nyitott kérdésként kezeli, de közben a hosszú szöveg tábláját `MANDT + DOC_NO` kulccsal tervezi, és a borítékbővítés, a változásfigyelés is kizárólag `DOC_NO` alapján azonosít. Ha a valódi alaptáblakulcs összetett, az `UPDATE`-hez hozzáadott `PRDSTOCK` önmagában nem feltétlenül elég, és a szövegek összekeveredése továbbra is megmarad.

**Javaslat:** az aktív SE11-kulcs igazolása legyen az L3 előfeltétele. Ha mandanton belül a `DOC_NO` egyedi, ezt tényként rögzítsük. Egyébként a teljes dokumentumkulcsot végig kell vezetni a hosszú szöveg táblán, a belső táblák keresésein, az összehasonlításon és az íráson. Stockszűkítést a mentésnél egyedi `DOC_NO` mellett is célszerű megadni, hogy az időközben más stockhoz rendelt dokumentumot ne módosítsuk észrevétlenül.

### R5 — P1: a zárolás feloldása és az érintett programok együttműködése hiányzik

**Hely:** terv L5, L8.7 és L8.10.

Az ENQUEUE létrehozása szerepel, de a riport lezárásához nincs kifejezett DEQUEUE-terv. A QU5 riportban sincs ilyen hívás. A sikertelen mentés, a találat nélküli szelekció, a visszalépés és az új stockra indítás zárolási viselkedése ezért nincs egyértelműen megadva. A stockzár csak azokat az egyéb módosító/lezáró folyamatokat zárja ki, amelyek ugyanazt a zárprotokollt követik.

**Javaslat:** rögzítsük a zár tulajdonosát és `_SCOPE` értékét, saját sikeres zárolást jelző flaggel. Módosítás közben és újrapróbálható mentési hibánál maradjon a zár; elhagyáskor, illetve feldolgozandó adat nélküli visszatéréskor oldjuk fel. Ellenőrizzük, hogy a stockengedélyezés és a stocklezárás ugyanazt a zárat használja. A zárolás után frissen ellenőrzött stockállapot R1 része.

Az SAP dokumentációja szerint a `_SCOPE` választása meghatározza, hogy a zár feloldása a dialógushoz, az update feldolgozáshoz vagy mindkettőhöz kapcsolódik; pusztán egy `COMMIT WORK`-ból nem következtethetünk minden esetben a zár megszűnésére. [SAP: _SCOPE Parameters](https://help.sap.com/saphelp_snc700_ehp01/helpdata/en/47/daadf638793c85e10000000a42189c/content.htm?no_cache=true).

## További szükséges pontosítások

### R6 — P2: az első megvalósítás terjedelme ellentmondásos

**Hely:** terv N3 és L9–L10; `01_SOURCES/DHC/info.md`, 3. pont; DOCX „ÚJ függvénycsoport: ZPR_STOCK”; `_LOG.md`.

A DHC-jegyzet elsőre csak kizárást kér. A terv alapértelmezésként négy keretműveletet, új keretprogramot és két tranzakciót ír elő. A DOCX új `ZPR_STOCK` függvénycsoportot nevez meg, ezt a terv későbbre halasztja. A döntésnapló szerint ezek még javaslatok, nem jóváhagyott döntések.

**Javaslat:** a senior az első kör és a későbbi kör objektumait/funkcióit külön rögzítse. Ha elsőre csak kizárás készül, annak működő tranzakciós belépési útját és a módosító mód beállítását is meg kell tervezni; a teljes keret elhagyásával a mostani riport alapértelmezésben megjelenítő maradna. A `ZPR_STOCK` sorsát ne tekintsük eldöntöttnek.

A helyi stockexportban a `CLOSED` és `DCCOMPL` már szerepel. A DHC-jegyzet szerint `EZPRT_STOCK` még nincs. Ezeket ismert exportállapotként érdemes feltüntetni, aktív rendszerellenőrzéssel, általános feltételezés helyett.

### R7 — P2: ismételt futtatáskor hibás lehet az összeg- és pénznemszűrés

**Hely:** terv L8.5, 386–390. sor; QU5 `START-OF-SELECTION`, 214–235. sor.

A QU5 a felhasználói `so_amnt` tartományt közvetlenül osztja át, és a `gr_waers` táblához törlés nélkül fűz hozzá. A szelekcióra visszalépve és újrafuttatva az összeg újra konvertálódhat, a korábbi pénznemszűrés pedig megmaradhat/összegyűlhet. A terv ezt változtatás nélkül venné át.

**Javaslat:** minden futtatáskor a felhasználói összegtartomány másolatán végezzük a belső formátumra alakítást, a szelekciós mezőket hagyjuk érintetlenül. A pénznemtartományt minden futás elején ürítsük és építsük újra. A helyi `AMNT` két tizedesű, de a „CURR mindig két tizedesű” állítás általánosan túl erős; a konverzió a tényleges DDIC-típus és a rendszer pénznembeállításai alapján készüljön.

### R8 — P2: a hosszú szöveg munkaterületét és a változásjelzőket ne vegyük át változtatás nélkül

**Hely:** terv L8.9–L8.10; QU5 mentés 952–967. sor, `check_changed` 1257–1273. sor.

A QU5 mentésnél a `ls_dcqmlt` nincs ürítve minden sor elején. Egy meglévő szövegrekord után egy hiányzó rekord olvasásakor a munkaterületben az előző rekord QM-szövege maradhat. Új DC-szöveg beszúrásakor ezt más dokumentumhoz is átviheti a szó szerinti átvétel.

A QU5 `check_changed` a helyi munkaterületben törli a `CHANGED` jelzőt, de egyező sor esetén nem írja vissza ezt a belső táblába. Módosítás, majd az eredeti érték visszaállítása után maradhat korábbi módosításjelző, ami felesleges mentést és félrevezető sornaplót okozhat.

**Javaslat:** szövegrekord olvasása/új rekord felépítése előtt ürítsük a munkaterületet; új dokumentum QM-szövege csak saját rekordból származhat. A változásvizsgálat minden sorban számítsa újra és írja vissza a jelzőt, az üzleti mezőket összehasonlítva és a cellastílusokat megőrizve. Módosítás nélküli mentéshez legyen világos visszajelzés, felesleges adatírás nélkül.

### R9 — P2: az üres boríték kezeléséből a visszavétel sem maradhat ki

**Hely:** terv L8.6, 488. sor; QU5 `KIZVISSZ`, 733–739. sor.

A terv külön megnevezi a kizárást és a cellamódosítást, de a visszavételi ág is üres boríték szerint csoportosít a QU5-ben. A T11 csak kizárást tesztel. Az üres boríték szabályát mindkét irányban érvényesíteni kell.

**Javaslat:** a nem üres boríték feltétele kizárólag a társak keresését védje. A kiválasztott üres borítékú dokumentum közvetlen módosítása/visszavétele továbbra is fusson. A `CHECK` pontos helyét meg kell mutatni a juniornak; ne lehessen az egész eseménykezelőből vagy a kijelölt sor kezeléséből idő előtt kilépni.

## Kisebb dokumentációs pontosítások

- L2 és a kész kritérium között transportellentmondás van: a kódtartalomhoz customizing kérelmet ír elő, végül minden objektumot egyetlen transportba kér. A szükséges Workbench/Customizing kérelmeket és importálási sorrendjüket külön soroljuk fel.
- A `COUNTER = 1` és az összegzési lehetőség megfelelő. A „mindig utolsó látható oszlop” feltételt pontosítani kell: az alapértelmezett mezőkatalógus sorrendjére vonatkozik-e, mert a mentett layout és a felhasználói átrendezés ezen változtathat.
- Az L4 szöveges mezőlistájában a kizárandó, már előre felvett mezők közé `DOC_NO` és `ENVELOPE` is tartozik. A zárójeles konkrét lista helyes, az általános utasítás viszont kettős mezőfelvételre félreérthető.
- L8.6: a lassú szelekció vizsgálatát ne kizárólag indexre korlátozzuk. Reális stockmérettel mért lekérdezés, memóriaigény és az eseménykezelő egymásba ágyazott ciklusainak költsége is ellenőrizendő.
- A „nincs jogosultságellenőrzés, mert QU5-ben sincs” legyen üzletileg jóváhagyott döntés. A terv N11-et már nyitottnak jelöli; az ellenőrzés nem állapított meg új jogosultsági követelményt.

## A tesztterv kiegészítése

| Teszt | Lépés | Elvárt eredmény |
|---|---|---|
| T19 | Módosító riportban a stockot egy DC kész stockra átírni; illetve közvetlen módosító SUBMIT | A riport maga tiltja a módosítást. |
| T20 | Két munkamenet: a szelekcióellenőrzés után a másik engedélyezi vagy lezárja a stockot | Zárolás utáni állapotellenőrzés megakadályozza a tiltott műveletet. |
| T21 | Kontrollált mentési hiba az alaptábla után, a szöveg írásakor | Egyetlen üzleti változás sem marad mentve; nincs félreérthető sikernapló; az ALV újrapróbálható. |
| T22 | Meglévő saját kódú borítéktárs mellé új kizárás popupból és cellából | A saját okok a jóváhagyott szabály szerint megmaradnak; a két belépési út következetes. |
| T23 | Ugyanazon boríték több cellájának egyidejű átírása; hibás kód | Meghatározott, sorrendtől független eredmény; érvénytelen érték nem menthető és nem hagy társakon mellékhatást. |
| T24 | Legalább két üres borítékú sor közül egy kizárásának visszavétele, popupos és cellás úton | Csak a választott dokumentum változik. |
| T25 | HUF összegszűrés, visszalépés, újrafuttatás; majd más pénznem/pénznem nélküli futás | Az összeg nem konvertálódik ismételten, korábbi pénznemszűrés nem marad vissza. |
| T26 | Két dokumentum mentése: elsőnek van QM-szövege, másodiknak még nincs szövegrekordja | A második rekord nem kapja meg az első QM-szövegét. |
| T27 | Módosítás, majd eredeti érték visszaállítása; mentés változtatás nélkül | Nincs téves módosításjelző és felesleges sormentés/napló. |
| T28 | Üres találat, kilépés mentés nélkül, sikeres mentés; ellenőrzés második munkamenetből | A zár csak a tényleges módosító munkamenet idején marad meg. |
| T29 | Sikeres és rollbackelt mentés naplójának keresése új munkamenet SLG1-ben | A napló tartós, stock szerint kereshető, és a végső eredmény egyértelmű. |
| T30 | Valós nagy stock, borítékszűkítés és mentett layout betöltése | Elfogadható futásidő/memória; a Darab oszlop láthatósága/sorrendje a pontosított követelménynek megfelel. |

## A javított terv kiadhatósága

Az R1–R5 technikai hiányai legyenek lezárva; R6-ban az első kör terjedelme legyen eldöntve; R7–R9 javításai kerüljenek be a lépésekbe és tesztekbe. Ezután a terv megfelelő alap lesz a megvalósításhoz. A végleges megfelelőséget az aktív DHC-objektumok ellenőrzése és a kibővített tesztek igazolják.
