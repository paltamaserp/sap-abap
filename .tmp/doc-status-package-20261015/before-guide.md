# ZPR_DOC_STATUS – DHC dokumentumstátuszok

Státusz: **WIP**. A QU5 `ZEBF_PR_DOC_STATUS` alapján készült DHC-változat. **Egyetlen másolandó ABAP-forrás: `ZPR_DOC_STATUS.abap`.** Nincs külön include, dynpro vagy GUI-státusz. A tizenhárom tiszta ABAP Unit-teszt helyi tesztosztályként ugyanebben a fájlban szerepel.

SAP-ban objektumot nem hoztunk létre, nem módosítottunk és nem aktiváltunk. A riportot, a teszteket és az Inspire-/ArchiveLink-hívásokat nem futtattuk; a kód által leírt adatbázis-műveletek nem történtek meg.

## Megőrzött működés

- Kizárólag `ZPRT_STOCK-CLOSED = X` stockok dokumentumai kerülnek feldolgozásra.
- `SO_STOCK`: stockszűrés; `P_DET`: részletes alkalmazási napló; `P_STAT`: a már `D` státuszú dokumentumok ismételt lekérése. Utóbbihoz kötelező stockszűrést megadni. Korábban mentett, nem üres dokumentumhibakód esetén a dokumentum a QU5-höz hasonlóan nem kerül újra lekérdezésre, `P_STAT` mellett sem.
- Stockonként egy Inspire-lekérdezés, a kért dokumentumazonosítókkal. A válasz a régi 18 oszlopos, pontosvesszős szerződést követi: dokumentum, fájlnév, `R C B Q O X P L G S A D E V` időbélyegek, hibakód, hibaszöveg. A hibaszöveg további pontosvesszőit megőrizzük.
- Új státuszok mentése `ZPRT_DOC_SLOG`-ba, hibakód és hibaszöveg mentése `ZPRT_DOC_ERROR`-ba. Az azonos státusz/azonos időbélyeg ismételt mentése nem hoz létre új sort.
- Új `A` eseménynél az átmeneti `ZPRT_ARCH_LINK` feldolgozása. Hiba nélküli válasznál `ARCHIV_CONNECTION_INSERT`, majd `DOC_LOG-ARCHIVED = X`; hibakódnál a régi működésnek megfelelően csak az átmeneti link törlődik. Hiányzó átmeneti linknél nincs új kapcsolat létrehozva.
- Dokumentumhibánál a hozzá tartozó `ZPR_TERTI` sorok törlése. Minden érintett ragszámra külön megvizsgáljuk, maradt-e másik TERTI-hivatkozás; `ZISU_F064` csak hivatkozás nélkül törlődik. A már hiányzó F064-sor megengedett.
- PR/IN nyomtatási hivatkozások a `ZPRT_DCQM-PRDSPOOL`/`PRDFILE` mezőkbe; a logikai `PRD_STOCK_ID` nem cserélődik le a fájlnévből olvasott fizikai nyomtatási stockra. A fájlnévbontás a QU5 sorrendjét követi: PR esetén stock/queue/file a 6/7/8., IN esetén stock/queue a 8/9. tag. Hatodik tag nélküli fájlnévnél a meglévő nyomtatási hivatkozás megmarad. Az éles DHC/Inspire fájlnévkonvenció nincs futó válasszal igazolva.
- Alkalmazási napló: `ZPR_MASS` / `STOCK`, SLG1; párbeszédben a végén megjelenik, háttérben csak mentődik.

## A felhasználó kérésére kommentben megtartott ágak

Az alábbi három QU5-rutin **teljes eredeti forrása és eredeti hívási feltétele** a fájl végén szerepel `DHC DISABLED` jelöléssel, minden sora kikommentezve:

| Rutin | Régi függőség | Aktív DHC-működés |
|---|---|---|
| `UPD_ESZLA` | `ZXWEBT_ESZLA_LOG` és a zárja | Kikapcsolva |
| `UPD_BC_STAT` | `Z_EBI_BILL_CERT_SAVE_STAT` | Kikapcsolva |
| `UPD_PUSH_MSG` | `ZEBI_PUSH_MSG` | Kikapcsolva |

A konkrét nevekre és a kapcsolódó `CERT*STAT`, `PUSH`, `ESZLA` mintákra végzett repository-keresések nem találták meg a régi függőségeket vagy azonosítható megfelelőiket. Ez nem bizonyítja, hogy más néven nincs DHC-szolgáltatás. A felhasználó döntése: „Maradjanak és legyenek megjelölve, kiremárkolva.” Ezért e három művelet nem fut, és hiányuk önmagában nem akadályozza a többi státusz mentését. A forrás a teljes QU5 üzleti működését e pontokon még nem valósítja meg; visszakapcsolásukhoz a DHC-megfelelőket külön kell illeszteni.

## DHC-adatmodell és eltérések

| QU5 | DHC-megfelelő |
|---|---|
| `MSSFILE → FILENAME → DCQM` | `ZPRT_DCQM-PRD_STOCK_ID` |
| Kódolt EXBILLDOCNO → régi SLOG-kulcs | Közvetlen `DOC_NO`; DCQM és DOC_LOG közös `GUID` + egyező `DOC_NO` |
| `DCQM-DESTINATION` | `ZPRT_DOC_LOG-CHANNEL`, a `ZPRS_CONTROL_DATA` include-ból |
| Régi SLOG2 széles időbélyegmezői | `ZPRT_DOC_SLOG`: egy esemény/sor |
| Régi SLOG2 hibamezői | `ZPRT_DOC_ERROR` |
| `ZEBF_PR_ARCHLINK` | `ZPRT_ARCH_LINK` |
| `EZEBFT_PR_STOCK` | Létező `EZPRT_STOCK` |
| Proxyosztály | `ZPR_CO_EON_FORMS_QUERY_DOC_DET` |
| Metódus | `EON_FORMS_QUERY_DOC_DETAILS` |
| Request / response | `ZPR_EON_FORMS_QUERY_DOC_DETAI3` / `ZPR_EON_FORMS_QUERY_DOC_DETAI2` |
| Dokumentumlista / válaszlista | `INPUT-DOCS-I` / `OUTPUT-DOCS-D`, mindkettő `ZPR_STRING_TAB` |

Az aktív proxy csak `CX_AI_SYSTEM_FAULT` kivételt deklarál; a riport ezt kezeli. `SUCCESS <> X` esetén nincs dokumentummentés. Nem kért vagy ismétlődő válaszazonosítónál, hibás időbélyegnél és túl hosszú hibakódnál/szövegnél az adott stock válaszának mentése elmarad. Hiányzó válaszsorok nyitva maradnak, a meglévő érvényes sorok feldolgozhatók. A többszörös DCQM-dokumentumazonosítót vagy hibás GUID/DOC_LOG kapcsolatot a riport nem oldja fel önkényes első sor választásával.

Az aktív DHC stockstátusz-domén értékei: üres, `DM`, `QM`, `CL`. Nincs külön QU5-féle `STOCK_STATUS = D` mező/érték, ezért a riport **nem ír `D`-t a `STATUS` mezőbe**, és a lezárási adatokat megőrzi. A feldolgozottságot a dokumentumok mentett `D` eseménye/hibakódja alapján vezeti le, ezért az alapfutás a már végállapotú dokumentumokra nem hívja az Inspire-t. A régi külön `TSTMP_TRIGGER` mező sem létezik itt: jogosult jelöltet a lezárt stock és az ahhoz tartozó érvényes DCQM/DOC_LOG kapcsolat jelent.

**A DOC_SLOG kulcsa lényeges korlát:** az aktív definícióban `MANDT + EXBILLDOCNO + TIMESTAMP`, a `STATUS` nem kulcsmező. Az Excel-terv ezzel szemben `MANDT + EXBILLDOCNO + STATUS` kulcsot mutatott. Két külön státusz azonos időbélyeggel nem tárolható veszteség nélkül. Ilyenkor a riport hibát ad; nincs felülírás és nincs mesterséges időbélyeg-eltolás. A teljes eseménykészlethez a `STATUS` kulcsba vételét külön DDIC-döntéssel kell rendezni. Ebben a feladatban táblamódosítás nem történt.

## Zárolás és mentés

A riport a meglévő stockzárat `_SCOPE = 1` beállítással tartja. Dokumentumonként `E_TABLE` együttműködő zárat használ a `ZPRT_DOC_SLOG` mandant+dokumentum kulcsára. Hibás dokumentum ragszámkezelése alatt ugyanezen protokoll szerint mandantszintű `ZPR_TERTI` zár is van. A saját dokumentumműveletek végén történik commit; addig jelzett hiba/kivétel esetén rollback. A részletes naplóban szereplő események az Inspire által visszaadott adatok, a mentés eredménye külön naplóbejegyzés.

A saját követő rutinok nem tartalmaznak köztes commitot. Az ArchiveLink standard függvény aktív implementációját és az egyéb íróprogramok zár-/commitprotokollját nem olvastuk végig. Az `E_TABLE` nem kényszerít ki adatbázis-szintű zárolást minden más program számára: a többi író együttműködése és a párhuzamos működés SAP-tesztet igényel. `COMMIT WORK AND WAIT` update-hibájánál SM13-ellenőrzést kérő hiba kerül a naplóba; egy már lezajlott commit utólagos visszavonását a riport nem állítja.

## Kézi beillesztés

1. SE38/ADT: `ZPR_DOC_STATUS`, végrehajtható program, a fájl teljes tartalmával. A projekt alapján jelölt csomag `ZPR_FUNC`; transzport nincs kiválasztva.
2. Szövegelemek: `001 = Dokumentumstátuszok lekérése`, valamint a 101–104 üzenetszövegek a [QA-textelemfájlból](2026-10-15_doc-status-qa-textelemek_WIP.tsv). Ezeket SE38/ADT szövegszimbólumként kell karbantartani és a forrással együtt transzportálni; a `.abap` másolása önmagában nem hozza létre őket. Szelekciós szövegek: `SO_STOCK = Stock azonosító`, `P_DET = Részletes napló`, `P_STAT = Befejezett dokumentumok újralekérése`, `P_LPORT = Dokumentumstátusz logikai portja`.
3. A `P_LPORT` kötelező, alapérték nélküli mezőbe **ehhez a consumerhez** karbantartott SOAMANAGER-portot kell adni. A port konfigurációja nincs visszaolvasva; Messenger/uploader portnév nincs feltételezve.
4. SE93: a tervezett `ZPR_DOC_STATUS` riporttranzakció és jogosultságai szükségesek. A program megőrzi a QU5 `S_TCODE` ellenőrzését az új tranzakciónévvel. A tranzakciót ez a munka nem hozta létre. Külön dynpro, GUI-státusz, DDIC-struktúra és üzenetosztály nem szükséges.
5. SAP-szintaxisellenőrzés, aktiválás, ATC és a beágyazott tesztosztály ABAP Unit-futtatása. A tesztek nem nyúlnak adatbázishoz, proxyhoz vagy naplóhoz.
6. Kijelölt tesztstockkal és tesztporttal: részleges/teljes/missing válasz, `P_STAT`, régi hibakód, duplikált dokumentum, azonos időbélyegű külön státuszok, hosszú hibakód, PR/IN fájlnév, zárütközés, ArchiveLink-hiba és több TERTI-ragszám. Hibánál ne legyen sikerként jelölt mentés, és a stockzár szabaduljon fel.

## Sorvégi üres mező javítása (2026-10-15)

A felhasználó SAP Unit-futtatásakor a `VALID_STATUSES` teszt a csonka, 18 mezőnél rövidebb válasz hibájával állt le. Az ok a parserben volt: a `SPLIT ... INTO TABLE` a legutolsó elválasztó utáni üres mezőt nem teszi a táblába, így a teljes, 18 mezős, üres hibaszöveggel végződő sor 17 eleműnek látszott. A `parse` a sorvégi pontosvessző esetén egyetlen üres mezőt állít vissza a mezőszám ellenőrzése előtt. A ténylegesen 17 mezős, szintén pontosvesszőre végződő sor továbbra is hibát ad. A végén pontosvesszőt tartalmazó hibaszöveg is megmarad.

Három regressziós teszt került ugyanabba a fájlba: `TRAILING_EMPTY_FIELDS`, `TRUNCATED_WITH_EMPTY_TAIL`, `SEMICOLON_ERROR_TAIL`. A korábbi hibásdátum-, kulcsütközés-, hosszúazonosító- és csonkasor-tesztek a konkrét várt hibaüzenetet is ellenőrzik, így más parserhiba nem számít sikeres negatív tesztnek. A tesztadat-előállító `FIXTURE` nem változott. A javított forrás SAP-beli újrafuttatása még szükséges; a korábbi helyi parserellenőrzés ezt a futásidejű hibát nem mutatta ki.

## QA-javítások (2026-10-15)

A négy közvetlen MESSAGE-literál `text-101`–`text-104` hivatkozásra cserélődött; a szövegek a külön TSV-ben találhatók. A `BAL_T_LOGH` táblába APPEND helyett `INSERT ... INTO TABLE` történik. A hibás dokumentum már beolvasott TERTI-sorait a program `DELETE zpr_terti FROM TABLE lt_terti` művelettel, teljes kulcsukkal törli. A ragszámok és EXTNU-változatok kiválasztása, az üres tábla ellenőrzése, a hibakezelés és a zárolási protokoll megmaradt.

A TERTI SELECT `ENVELOPE_ID + EXBILLDOCNO` feltételének QA-indexjelzésén **az index segített a felhasználó 2026-10-15-i visszajelzése szerint**. Az egyeztetett javaslat nem egyedi `MANDT + ENVELOPE_ID + EXBILLDOCNO` index volt; a tényleges indexnevet és definíciót külön nem erősítette meg. A ragszámfeltétel üzleti szűkítést okozna, ezért a javítás nem erre épül. Az asszisztens SAP-indexellenőrzést és DDIC-módosítást nem végzett. A részletes találatlista és a későbbi fejlesztésekre vonatkozó szabályok: [ABAP QA ellenőrzőlista](<../../../../[01] system/ABAP-QA-CHECKLIST.md>).

A javítások két diffben tekinthetők át, a QA előtti helyi forráshoz viszonyítva: [üzenetek](2026-10-15_doc-status-qa-uzenetek_WIP.diff), [táblaműveletek](2026-10-15_doc-status-qa-tablamuveletek_WIP.diff). A forrás ezeket már tartalmazza. A négy textelem SAP-karbantartása, a SAP-szintaxisellenőrzés és az új QA/ATC-futtatás még szükséges.

## Ellenőrzési bizonyíték

A helyi `@abaplint/core 2.120.60`, ABAP 7.54 parser hibát nem talált. A helyi ellenőrzés igazolta a FORM-hívások feloldását, az egyfájlos szerkezetet, az aktív QU5-függőségek hiányát, az aktív exportok mezőneveit és proxymezőit, az eredeti 18 mező és 14 státusz sorrendjét, valamint mindhárom kikommentezett rutin teljes eredeti tartalmának megőrzését. A tizenhárom Unit-teszt forrása válaszparszolást, sorvégi üres mezőt, csonka sort, hibás dátumot, kulcsütközést, hosszú dokumentumot, pontosvesszős hibaszöveget és PR/IN fájlnévbontást fed le. A felhasználó az előző verzió `VALID_STATUSES` futásának hibáját jelezte; **a javított tesztek SAP-ban még nem futottak**, helyi ABAP-runtime nem áll rendelkezésre.

Jegyzőkönyv: `../../02_NOTES/2026-10-15_doc-status-helyi-ellenorzes_WIP.json`. Ez parser- és névellenőrzés, nem SAP-fordítás vagy teljes DDIC-típusellenőrzés. Az új aktív forrás-/DDIC-exportok és a repository-keresések: `../../01_SOURCES/DHC/2026-10-15_doc-status/`. A közös DCQM/DOC_LOG/STOCK/control-definíciók az aznapi korábbi `2026-10-15_doc-rip/` exportból származnak. Az ADT-metaadat szerinti eredeti rendszer DHC; a célrendszert a felhasználó adta meg, a kapcsolt SID külön nem ellenőrzött.

Az első keresést az automatikus jóváhagyási ellenőrzés elutasította. A felhasználó kifejezett új engedélye után a proxy- és státusztábla-olvasások sikerültek. A where-used eszköz `Unsupported object type for where-used: TABL` hibája után a következő olvasást az automatikus ellenőrzés ismét blokkolta. Ez nem új HTTP 401. Újabb kifejezett engedély után a közvetlen struktúra-/tábla-/doménolvasások és repository-keresések sikerültek; a `ZPR_STATUS_REPORT_C02` include olvasása `success=true`, de `source_code=null` eredményt adott, ezért azt nem használtuk forrásként. SAP-írás és újabb elérési hiba nem történt.
