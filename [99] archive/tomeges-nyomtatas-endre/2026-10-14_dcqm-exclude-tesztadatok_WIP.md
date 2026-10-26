# ZPR_DCQM_EXCLUDE: tesztadatok

Státusz: WIP. Helyi fájlok: SAP-ban még nincs létrehozva, és nem is futott.
A tesztadat a [ZPR_DCQM_EXCLUDE](<../../../../[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/project/04_ASSETS/abap/ZPR_DCQM_EXCLUDE.abap>) riporthoz és a [ZPR_DC_FRAME](<../../../../[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/project/04_ASSETS/abap/ZPR_DC_FRAME.abap>) keretprogramhoz készült. Lefedi a megvalósítási terv L11 fejezetének T1–T18 tesztesetét, valamint további E1–E9 eseteket.

## Fájlok

| Fájl | Tartalom |
|---|---|
| `ZPR_DCQM_TESTDATA.abap` | Feltöltő riport (SE38). Ez a **hiteles forrás**: feltölti, alaphelyzetbe állítja és törli a tesztadatot. |
| `2026-10-14_dcqm-exclude-zprt-dcqm-tesztsorok_WIP.tsv` | A 23 `ZPRT_DCQM` sor minden mezővel, Excelben vagy SE16N-ben kézi felvitelhez. |
| ez a leírás | Adatok, tesztesetek és elvárt eredmények. |

A riport `ZPRT_DCQM` sorai, a TSV és az alábbi sortábla ugyanabból a forrásból generálódtak. Ha valamelyiket módosítod, a másik kettőt is frissíteni kell.

## Biztonsági szabályok

- **Csak nem éles mandantban fut.** Ha `T000-CCCATEGORY = 'P'`, a riport leáll.
- **A tesztrekordok jelölése:** a Stock ID-k `9900000001`–`9900000005`, a `DOC_NO` mind `TESZT-DC-` kezdetű, a `CRUSER` értéke `ZPR_TESZT` (`ZPRT_STOCK`, `ZPRT_DCQM`). A T1/T2 DC-kódok szövege `TESZT:` kezdetű.
- **Idegen rekordhoz nem nyúl.** Ha egy tesztkulcson vagy teszt-stockban jelölés nélküli rekord van, a riport adatbázis-módosítás nélkül leáll, és kiírja az ütköző kulcsot.
- **A `ZZ` kódot soha nem törli.** Ha hiányzik, felveszi, mert a riport mentése nélküle elhasal. A T1/T2 kódot csak akkor törli, ha `TESZT:` jelölésű, és már egyetlen `ZPRT_DCQM` sor sem hivatkozik rá.
- **Zárol.** Futás közben az `EZPRT_STOCK` zárat tartja mind az öt teszt-stockon. Ha valaki éppen tesztel (nyitott ALV kizárás módban), a feltöltő leáll.
- **Nincs transzport-rögzítés.** A `ZPRC_DCCODE`-ba ABAP-ból írt kódok nem kerülnek transzportba. A valós kódtartalmat (a `ZZ`-vel együtt) továbbra is SM30-ban, transzporttal kell felvinni (terv L2).
- **Egy LUW.** Bármely adatbázishiba esetén teljes ROLLBACK történik.

## Futtatás

1. SE38: hozd létre a `ZPR_DCQM_TESTDATA` riportot a `.abap` tartalmával. A csomagot lásd a „Nyitott kérdések” résznél.
2. Szövegelemek: a `TEXT-001` legyen „Művelet”, a `TEXT-002` „Futtatás”. A többi szövegszimbólumot a „Szövegelemek → Összehasonlítás” veszi fel. Szelekciós szövegek: `P_LOAD` Feltöltés, `P_RESET` Alaphelyzet (törlés + feltöltés), `P_DEL` Törlés, `P_TEST` Tesztfutás.
3. Futtasd először **Tesztfutás** bejelöléssel (ez az alapérték). A lista mutatja a felveendő és törlendő darabszámokat, a figyelmeztetéseket és a sorokat pénznem szerint formázott összeggel.
4. Futtasd **Tesztfutás nélkül**: először **Feltöltés**, minden további tesztkör előtt **Alaphelyzet**.
5. A tesztelés végén futtasd a **Törlés** módot.

Az alaphelyzet a teszt közben mentett módosításokat is visszaállítja. A riport mentése által létrehozott `ZPRT_DCQMLT` rekordokat az előtag alapján törli, a keretprogram `DCCOMPL`-módosítását pedig a stock újrafelvételével állítja vissza.

## Stockok (`ZPRT_STOCK`)

| Stock ID | Szerep | STATUS | CLOSED | DCCOMPL | QMCOMPL | Sorok |
|---|---|---|---|---|---|---|
| `9900000001` (S1) | Nyitott; a kizárási tesztek fő stockja | (üres) | | | | 15 |
| `9900000002` (S2) | Lezárt, csak megjelenítés | `CL` | X | X | X | 2 |
| `9900000003` (S3) | DC kész, nem módosítható | `DM` | | X | | 2 |
| `9900000004` (S4) | Nyitott, sor nélkül („nincs adat”) | (üres) | | | | 0 |
| `9900000005` (S5) | Nyitott; DC engedélyezés és visszavétel | (üres) | | | | 4 |
| `9900000099` | **Nem létezhet**: a „nem létező stock” teszt | – | – | – | – | – |

A létrehozási mezők (`CRUSER`/`ERNAM` = `ZPR_TESZT`, dátum, idő) a futás pillanatát kapják. Az S2 lezárási mezői (`ERDAT_CLO`, `ERNAM_CLO`, `ERTIM_CLO`) és a `PRIORITY = 05` is ki vannak töltve.

## DC-kódok (`ZPRC_DCCODE`)

| Kód | Szöveg | Kezelés |
|---|---|---|
| `ZZ` | Borítékban kizárt tétel | Csak akkor kerül be, ha hiányzik. Soha nem törlődik. |
| `T1` | TESZT: hibás cím | Csak akkor kerül be, ha hiányzik. Jelölés esetén törlődik. |
| `T2` | TESZT: vitatott összeg | Ugyanígy. |
| `XX` | – | **Nem létezhet**: a hibás kód teszteléséhez. Ha létezik, a feltöltő figyelmeztet. |

Ha a DHC-ban `T1` vagy `T2` már valós kódként létezik, a feltöltő változatlanul hagyja és használja.

## `ZPRT_DCQM` sorok

Az összegek **külső (megjelenített)** formában szerepelnek. A feltöltő a riport `BUILD_RANGES` logikájával (TCURX) alakítja őket belső formára: 5 000 HUF belső értéke `50.00`, az 500 000 HUF-é `5000.00`, az 5 000 EUR-é `5000.00`. A `—` üres borítékot jelöl.

| DOC_NO | Stock | Boríték | Név | Összeg | Pénznem | DC | QM | Szerep |
|---|---|---|---|---:|---|---|---|---|
| `TESZT-DC-S1-01` | S1 | `TDCENV001` | Teszt Elek | 12 500 | HUF |  |  | Háromsoros boríték (1/3): kizárás, ZZ-társak, visszavonás |
| `TESZT-DC-S1-02` | S1 | `TDCENV001` | Teszt Elek | 8 900 | HUF |  |  | Háromsoros boríték (2/3): erre szűrve 3 sorra bővül |
| `TESZT-DC-S1-03` | S1 | `TDCENV001` | Teszt Elek | 3 100 | HUF |  |  | Háromsoros boríték (3/3): felszólítás |
| `TESZT-DC-S1-04` | S1 | `TDCENV002` | Minta Anna | 5 000 | HUF |  |  | Egysoros boríték; HUF 5 000 = az összegszűrés egyetlen HUF-találata |
| `TESZT-DC-S1-05` | S1 | — | Próba Péter | 7 800 | HUF |  |  | Üres boríték: a kizárás csak ezt a sort érinti |
| `TESZT-DC-S1-06` | S1 | — | Kísérleti Kft. | 500 000 | HUF |  |  | Üres boríték; HUF 500 000 = belső 5000.00 (tizedes-korrekció csapda) |
| `TESZT-DC-S1-07` | S1 | `TDCENV003` | Gipsz Jakab | 15 000 | HUF | `T1` |  | Előre kizárt boríték: saját kód T1 + szöveg |
| `TESZT-DC-S1-08` | S1 | `TDCENV003` | Gipsz Jakab | 2 200 | HUF | `ZZ` |  | Előre kizárt boríték: ZZ-társ |
| `TESZT-DC-S1-09` | S1 | `TDCENV003` | Gipsz Jakab | 4 600 | HUF | `ZZ` |  | Előre kizárt boríték: ZZ-társ |
| `TESZT-DC-S1-10` | S1 | `TDCENV004` | Példa Piroska | 21 000 | HUF | `T2` |  | Vegyes boríték: saját T2 ok, ZZ nem írhatja felül |
| `TESZT-DC-S1-11` | S1 | `TDCENV004` | Példa Piroska | 9 990 | HUF |  |  | Vegyes boríték: nyitott, ezt zárjuk ki T1-gyel |
| `TESZT-DC-S1-12` | S1 | `TDCENV004` | Példa Piroska | 1 250 | HUF |  |  | Vegyes boríték: nyitott, ZZ-t kap |
| `TESZT-DC-S1-13` | S1 | `TDCENV005` | Minta Anna | 5 000,00 | EUR |  | `Q1` | EUR 5 000; QM-kód + QM-szöveg (QM-szöveg védelme) |
| `TESZT-DC-S1-14` | S1 | `TDCENV006` | Teszt Ödön | 33 000 | HUF |  |  | Kétsoros boríték, 2. szintű felszólítás: cellás szerkesztés |
| `TESZT-DC-S1-15` | S1 | `TDCENV006` | Teszt Ödön | 640 | HUF |  |  | Kétsoros boríték, külföldi cím (AT) |
| `TESZT-DC-S2-01` | S2 | `TDCENV101` | Lezárt Lajos | 4 100 | HUF | `ZZ` |  | Lezárt stock: ZZ-társ |
| `TESZT-DC-S2-02` | S2 | `TDCENV101` | Lezárt Lajos | 2 900 | HUF | `T1` |  | Lezárt stock: saját T1 |
| `TESZT-DC-S3-01` | S3 | `TDCENV201` | Kész Klára | 6 600 | HUF |  |  | DC kész stock: nyitott sor |
| `TESZT-DC-S3-02` | S3 | `TDCENV202` | Kész Klára | 1 800 | HUF | `T2` |  | DC kész stock: kizárt sor (T2) |
| `TESZT-DC-S5-01` | S5 | `TDCENV001` | Másik Márton | 4 000 | HUF |  |  | Ugyanaz a borítékazonosító, mint S1-ben: nem kerülhet be az S1 bővítésébe |
| `TESZT-DC-S5-02` | S5 | `TDCENV501` | Engedély Endre | 7 300 | HUF | `T1` |  | DC engedélyezés: kizárt (T1) |
| `TESZT-DC-S5-03` | S5 | `TDCENV501` | Engedély Endre | 2 700 | HUF | `ZZ` |  | DC engedélyezés: ZZ-társ |
| `TESZT-DC-S5-04` | S5 | — | Engedély Endre | 990 | HUF |  |  | DC engedélyezés: nyitott, üres boríték |

Közös alapértékek: `PYMET = C`, `DOC_CAT = S`, `DUEDATE = 20261031`, `SYSID = DHC`, `LAND1 = HU`, `AB–BIS = 20260901–20260930`, `TARIFTYP = TESZT_A1`, `AKLASSE = LAK`, `ZBIZCAT = SZLA`, `FORM = ZPR_TESZT_SZAMLA`, `COTYP = ZPR1`, `AKTYP = ZPRT`, `LAUFD = 20261014`, `LAUFI = TDC01`, `COUNTER = 1`. Származtatott mezők: `COKEY = DOC_NO`, `PRDSPOOL = 'Q1' + Stock ID`. Az eltéréseket (felszólítás, ragszám, külföldi cím, más fizetési mód) a TSV mutatja.

Borítékméretek S1-ben: `TDCENV001` 3, `TDCENV002` 1, `TDCENV003` 3, `TDCENV004` 3, `TDCENV005` 1, `TDCENV006` 2, üres boríték 2, összesen 15.

## Hosszú szövegek (`ZPRT_DCQMLT`)

| EXBILLDOCNO | BLOCK_DC_TEXT | BLOCK_QM_TEXT |
|---|---|---|
| `TESZT-DC-S1-07` | TESZT: hibás levelezési cím | |
| `TESZT-DC-S1-08` | TESZT: hibás levelezési cím | |
| `TESZT-DC-S1-09` | TESZT: hibás levelezési cím | |
| `TESZT-DC-S1-10` | TESZT: vitatott összeg, ügyfélpanasz folyamatban | |
| `TESZT-DC-S1-13` | | TESZT QM: nyomdai minőségi eltérés |
| `TESZT-DC-S2-01` | TESZT: lezárt stock kizárt borítékja | |
| `TESZT-DC-S2-02` | TESZT: lezárt stock kizárt borítékja | |
| `TESZT-DC-S3-02` | TESZT: DC kész stock kizárt sora | |
| `TESZT-DC-S5-02` | TESZT: szerződés megszűnt | |
| `TESZT-DC-S5-03` | TESZT: szerződés megszűnt | |

## Tesztesetek és elvárt eredmények

Az üzenetszámok az új ZPR 045–066 számozást követik. A terv L11 táblája még a régi számokat tartalmazza. Minden tesztkör előtt futtass **Alaphelyzetet**. Ahol egy eset egy előző esetre épül, ezt jelöltük.

A `ZPR_DC` a Kizárás és a Megtekintés módban a riport szelekciós képernyőjére visz (`SUBMIT … VIA SELECTION-SCREEN`). A szűrőket (Dokumentum, Boríték, Összeg, Pénznem stb.) ott kell megadni. Az „S1, Összeg = …” jelölés ezt jelenti.

### Terv szerinti esetek (T1–T18)

| # | Adat / lépés | Elvárt eredmény |
|---|---|---|
| T1 | `ZPR_DC`, Stock `9900000099` | E 045 „A Stock ID nem létezik!”, a képernyő marad |
| T2 | `ZPR_DC`, S1, Megtekintés | ALV 15 sorral, cím: „9900000001 stock megjelenítése”. Nincs Kizárás és Kizárás vissza gomb, a cellák nem szerkeszthetők. |
| T3 | `ZPR_DC`, S1, Kizárás, Dokumentum = `TESZT-DC-S1-02` | ALV 3 sorral (S1-01…03), I 064. **A `TESZT-DC-S5-01` nem jelenik meg** (azonos `TDCENV001`, de más stock). |
| T4a | T3 után: S1-02 kijelölése → Kizárás, `T1` + „TESZT: T4” | S1-02 kódja `T1`; S1-01 és S1-03 kódja `ZZ`, ugyanazzal a szöveggel. S 066: 3. |
| T4b | S1 teljes lista: S1-11 kijelölése → Kizárás, `T1` | S1-11 kódja `T1`, S1-12 kódja `ZZ`. **S1-10 marad `T2`**, a saját szövegével. S 066: 2. |
| T5 | Kizárás popup, kód `XX` | E 060 a popupban, a popup nem zárul be |
| T6 | S1-05 (kód nélkül): szöveg a `BLOCK_DC_TEXT` cellába → Mentés | S 061 (E-ként), nincs mentés. A popupban a kód kötelező, ezért ez az ág csak cellás bevitellel érhető el. |
| T7 | T4a után Mentés | `ZPRT_DCQM`: S1-01…03 `BLOCK_DC` = `ZZ`/`T1`/`ZZ`, a `CHUSER`/`CHDATE`/`CHTIME` kitöltve. `ZPRT_DCQMLT`: 3 új rekord. SLG1 `ZPR_MASS`/`DC`: 3× 058 és 048. Az ALV bezárul. |
| T8a | T7 után: S1-01 kijelölése → Kizárás vissza → Mentés | Az S1-01…03 sorokról a kód és a szöveg is törlődik. A 3 `ZPRT_DCQMLT` rekord megmarad, üres DC-szöveggel. Napló: 3× 059. |
| T8b | S1-13: Kizárás `T1` + szöveg → Mentés, majd Kizárás vissza → Mentés | Az első mentés után a DC-szöveg beíródik, a `BLOCK_QM_TEXT` változatlan. A második után a DC-szöveg üres, de **a rekord és a QM-szöveg megmarad**. |
| T9a | S1-14 `BLOCK_DC` cellájába `XX` | 060-as hibaprotokoll; az érték nem kerül át, S1-15 változatlan |
| T9b | S1-14 `BLOCK_DC` = `T2`, majd a `BLOCK_DC_TEXT` = „TESZT: cellás” | S1-15 kódja `ZZ` lesz, a szövege követi az S1-14 szövegét |
| T9c | S1-08 (`ZZ`) kódjának törlése a cellában | A teljes `TDCENV003` boríték visszavonódik, **az S1-07 `T1` kódja is**; a szövegek törlődnek |
| T9d | S1-07 szövegének átírása a cellában | Az S1-08 és S1-09 (`ZZ`) szövege követi |
| T10 | Bármely módosítás után Vissza | Figyelmeztető popup. „Nem”: az ALV marad. „Igen”: kilép, az adatbázis változatlan. |
| T11 | S1-05 kijelölése → Kizárás `T1` | Csak S1-05 kap kódot, S1-06 változatlan. S 066: 1. |
| T12 | A felhasználó: `ZPR_DC` S1 Kizárás (ALV nyitva); B felhasználó ugyanezt indítja | B zárolási üzenetet kap (I, E-ként). Megtekintés módban beléphet. A feltöltő Alaphelyzet módja ekkor „Stock zárolása sikertelen” üzenettel, módosítás nélkül leáll. |
| T13 | `ZPR_DC`, S5, DC engedélyezés | `ZPRT_STOCK-DCCOMPL = X`. Napló: 051, 053 „Engedélyezett sorok száma: 2”, 054 „Kizárt sorok száma: 2”. |
| T14 | T13 után `ZPR_DC`, S5, Kizárás (vagy S3, Kizárás) | E 062 „DC kész, a stock nem módosítható” a szelekciós képernyőn |
| T15 | T13 után `ZPR_DC`, S5, Engedélyezés visszavétele | `DCCOMPL` üres, 056; utána a Kizárás mód újra indul |
| T16 | S1, Összeg = 5000, Pénznem = HUF | **Csak S1-04.** Ha S1-06 jelenik meg (belső 5000.00), hibás a tizedes-korrekció. Pénznem = EUR: csak S1-13. Összeg pénznem nélkül: E 065. |
| T17 | S1, Megtekintés: Σ a `COUNTER` oszlopon, részösszeg `ENVELOPE` szerint | 3 / 1 / 3 / 3 / 1 / 2 és üres boríték: 2; végösszeg 15. A layout menthető. |
| T18 | `ZPR_DCQM_DISP` közvetlenül, S1 (és S2) | Csak megjelenítés, kizárási gombok nélkül |

### További esetek (E1–E9)

| # | Adat / lépés | Elvárt eredmény |
|---|---|---|
| E1 | `ZPR_DC`, S2, Kizárás | I 046, a mód Megtekintésre vált. Az ALV 2 sort mutat (`ZZ`, illetve `T1` szöveggel). |
| E2 | `ZPR_DC`, S2, DC engedélyezés | E 046 |
| E3 | `ZPR_DC`, S4, Kizárás | I 063 „A 9900000004 stockhoz nincs adat”. A zár feloldódik, más felhasználó azonnal beléphet. |
| E4 | S1, Boríték = `TDCENV001` | 3 sor, **nincs** I 064 (a szelekció nem bővült), S5-01 nincs benne |
| E5 | S1, Kizárási DC ok = `ZZ` | S1-08 és S1-09, a bővítés miatt S1-07 is (3 sor), I 064 |
| E6 | S1, Kizárási QM ok = `Q1` | 1 sor (S1-13); a `BLOCK_QM_TEXT` oszlopban a QM-szöveg látszik |
| E7 | S1, Felszólítási szint = `02` (vagy Ország = `AT`) | S1-14 és S1-15, I 064 |
| E8 | S1, Kizárás mód, módosítás nélkül Mentés | S 000 „Nincs mentendő módosítás.” |
| E9 | `ZPR_DC`, S1, Engedélyezés visszavétele (nincs engedélyezve) | I 055; S5-ön a T13 után ismételt engedélyezés: I 050 |

Az eredményeket (OK/hiba, dátum) a terv L11 szerint a `02_NOTES/ÉÉÉÉ-HH-NN_dc-teszt-jegyzokonyv_WIP.md` fájlba írd.

## Feltételezések, ellenőrizendők

- **A `ZPRC_DCCODE` szövegmezője:** a feltöltő `DESCR40`-et feltételez (QU5 alapján), és dinamikusan tölti. Ha a mező neve eltér, a kódok szöveg nélkül kerülnek be, és a T1/T2 törlése elmarad. Ilyenkor a `GC_DCCODE_TEXT` konstanst kell javítani.
- **Szemléltető értékek:** a `PYMET` (C/D/U), a `DOC_CAT` (S/F), a `ZBIZCAT`, `COTYP`, `AKTYP`, `FORM`, `TARIFTYP`, `AKLASSE` és a `Q1` QM-kód értéke szemléltető. A DC riport ezeket csak szűri, nem ellenőrzi. Ha más program ellenőrző táblát használ rájuk, a DHC customizing szerint kell őket igazítani.
- **`ZPRT_DCQM` kulcs:** a riporthoz hasonlóan a `DOC_NO` egyediségét feltételezzük. A tesztkulcsok globálisan egyediek, így bármely kulcsdefiníció mellett működnek.
- **A 9900000001–9900000005 tartomány** szabadsága nem igazolt. A feltöltő ellenőrzi, és ütközésnél leáll.
- **Függőségek:** a teszteléshez a riport függőségei is kellenek (`ZPRS_DCQM_REPORT`, `ZPRT_DCQMLT`, `ZPRC_DCCODE`, `EZPRT_STOCK`, a ZPR 045–066 üzenetek, `ZCL_PR_LOG`, GUI-státuszok, tranzakciók).

## Nyitott kérdések

- **Csomag:** ha a feltöltő csak DHC-ban kell, javasolt a `$TMP`. Ha QHC-ban is tesztelünk, transzportálható csomag kell. Ezt a senior dönti el.
- **N12:** ha a DHC-ban van valós tesztstock, a valós adatokon is érdemes lefuttatni a T3, T16 és T17 esetet. A szintetikus adat nem pótolja a valós borítékeloszlást.
