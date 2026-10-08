# DC adatellenőrzés (ZEBF_PR_DC) átvétele DHC-ba — megvalósítási terv

| | |
|---|---|
| **Státusz** | WIP — a ❓ jelölt pontokat a senior még nem hagyta jóvá |
| **Dátum** | 2026-10-08 |
| **Kinek** | Junior ABAP fejlesztő, aki a feladatot megvalósítja |
| **Forrás** | `01_SOURCES/QU5/*` (eredeti kód és DDIC), `01_SOURCES/DHC/*` (mostani állapot), `01_SOURCES/Tömeges tranzakciók.docx` |
| **Rendszer** | DHC (fejlesztői rendszer) |

---

## 0. Hogyan használd ezt a dokumentumot

- **Sorrendben haladj** (L0 → L13). A DDIC-objektumoknak (L1–L7) aktívnak kell lenniük, mielőtt a programhoz nyúlsz (L8–L10), különben nem fordul.
- Jelölések:
  - ⚠️ **ELLENŐRIZD** — a rendszerben nézd meg (SE11/SE24/SE91…), mielőtt továbbmész. Ha nem az van, amit a terv feltételez, **állj meg és szólj**.
  - ❓ **NYITOTT** — még nincs döntés; a terv a zárójelben írt *alapértelmezéssel* számol. Ha a senior mást mond, azt kövesd.
- Minden lépés végén van egy **„Kész, ha:”** sor. Csak akkor lépj tovább, ha teljesül.
- Kódolási szabályok ebben a programban:
  - A meglévő DHC-kód már új Open SQL-t használ (`@` escape) → **minden SELECT/UPDATE ezzel a szintaxissal** készüljön.
  - **Nincs string template** (`|...|`), helyette `CONCATENATE`.
  - **Explicit típusozás**: új kódban ne használj inline deklarációt (`DATA(...)`), deklarálj a FORM/metódus elején.
  - Névkonvenció és kommentek: oneERP ABAP Development Guideline V22 (`[02] context/`).
  - A QU5-kódból **ne másold át** a `zkg_break x0153` makrót (QU5-specifikus breakpoint).

---

## 1. Mi a cél — üzleti háttér röviden

A tömeges nyomtatás során a nyomtatandó dokumentumok **stock**okba (nyomtatási kötegekbe) kerülnek. Mielőtt egy stock a nyomdába megy, az üzlet **adatellenőrzést (DC = Data Control)** végez:

1. Megnézi a stock nyomtatási sorait (`ZPRT_DCQM`).
2. A hibás sorokat **kizárja** a nyomtatásból: egy **DC-kizárási kódot** (`BLOCK_DC`) és egy szöveges indoklást ad meg hozzájuk.
   - Ha egy sort kizárnak, **az ugyanabba a borítékba (`ENVELOPE`) tartozó többi sort is ki kell zárni**, különben hiányos boríték menne ki. Ezek a sorok automatikusan a `ZZ` kódot kapják.
3. Ha végzett, **engedélyezi a stockot** („DC kész”). Ez az engedélyezés visszavonható.

QU5-ben ez a `ZEBF_PR_DC` tranzakció. A feladat: **ugyanez a funkció DHC-ban, az új (`ZPR*`) táblákon**. A megbízó szavaival: *„Egy az egybe, csak más a tábla.”*

Plusz igény: az ALV **utolsó oszlopa egy számláló legyen, minden sorban 1-es értékkel**, hogy az üzlet összegezni tudjon (pl. borítékonként a darabszámot).

---

## 2. Hogyan működik QU5-ben

```
Tranzakció ZEBF_PR_DC
  └─ ZEBF_PR_DC_FRAME (keretprogram, 1000-es képernyő)
       Stock ID: [__________]
       ( ) Nyomtatási sorok kizárása          → SUBMIT ZEBF_PR_DCQM_REPORT  p_modif = 'X'
       ( ) Nyomtatási sorok megtekintése      → SUBMIT ZEBF_PR_DCQM_REPORT  p_modif = ' '
       ( ) DC engedélyezés                    → ZEBFT_PR_STOCK-DCCOMPL = 'X' + napló
       ( ) DC engedélyezés visszavétele       → ZEBFT_PR_STOCK-DCCOMPL = ' ' + napló

Tranzakció ZEBF_PR_DCQM_DISP
  └─ ZEBF_PR_DCQM_REPORT közvetlenül, csak megjelenítés

ZEBF_PR_DCQM_REPORT
  1. Szelekciós képernyő (Stock ID + kb. 40 szűrő + layout-variáns)
  2. Stock ellenőrzése (létezik? lezárt? → ha lezárt, csak megjelenítés)
  3. Módosító módban a stock zárolása (ENQUEUE)
  4. Adatszelekció:
       a) stock fájljai (ZEBFT_PR_MSSFILE) → sorok (ZEBFT_PR_DCQM) a szűrők szerint
       b) borítékbővítés: a talált borítékok összes sora is bekerül
          (ha volt ilyen, tájékoztató üzenet)
       c) hosszú szöveg (ZEBFT_PR_DCQMLT) és COUNTER = 1
  5. ALV (0100-as képernyő, custom container), módosító módban:
       [Kizárás]      → popup (kód + szöveg) → kijelölt sorok + borítéktársak 'ZZ'
       [Kizárás vissza] → kijelölt sorok és borítéktársaik kódja/szövege törlődik
       Cellában is írható a BLOCK_DC és a BLOCK_DC_TEXT (borítéktársakra továbbgyűrűzik)
  6. MENTÉS → ZEBFT_PR_DCQM-BLOCK_DC + ZEBFT_PR_DCQMLT + napló (BAL), COMMIT
```

---

## 3. Mi van ma DHC-ban, és mi a baj vele

A `ZPR_DCQM_EXCLUDE` (Németh Endre, 2026-06-20) egy félkész váz. **Ezt írjuk át**, nem foltozzuk. A hibái (tanulságnak is):

| Sor | Hiba |
|---|---|
| 4 | A fejlécben rossz programnév szerepel (`ZPR_MASS_PRINTING`). |
| 56, 79 | **Két `START-OF-SELECTION`** esemény van; ez félrevezető, a második csak hozzáfűződik az elsőhöz. |
| 60–267 | Kb. 200 sor kiremárkolt kód (Inspire-küldés, `process_package`), aminek **semmi köze a DC-hez**. Törlendő. |
| 356 | A mezőkatalógus egy idegen struktúrából készül (`ZPRT_PACKAGE`), nem az ALV tábla szerkezetéből. |
| 438 | A kizárási kód be van égetve (`'01' "??????`); nincs popup, nincs kódtábla. |
| 442 | `UPDATE` után nincs `COMMIT WORK`, nincs hibakezelés és nincs napló. |
| — | Nincs Stock ID a szelekción, nincs borítékkezelés, nincs megjelenítő mód és nincs „kizárás vissza”. |

---

## 4. Cél-architektúra: objektumlista

| Szerep | QU5 objektum | DHC objektum | Teendő | Csomag |
|---|---|---|---|---|
| Keret-tranzakció | `ZEBF_PR_DC` | `ZPR_DC` ❓ | **új** | mint a riport |
| Keretprogram | `ZEBF_PR_DC_FRAME` | `ZPR_DC_FRAME` ❓ | **új** | mint a riport |
| Kizárás/megjelenítés riport | `ZEBF_PR_DCQM_REPORT` (+`_O01`, `_I01`) | `ZPR_DCQM_EXCLUDE` | **átírás** | ⚠️ a meglévő csomagja |
| Megjelenítő tranzakció | `ZEBF_PR_DCQM_DISP` | `ZPR_DCQM_DISP` ❓ | **új** | mint a riport |
| DC/QM alaptábla | `ZEBFT_PR_DCQM` | `ZPRT_DCQM` | meglévő, **nem módosul** | — |
| Fájl → stock kapcsolat | `ZEBFT_PR_MSSFILE` | — (helyette `ZPRT_DCQM-PRD_STOCK_ID`) | nem kell | — |
| Hosszú szöveg tábla | `ZEBFT_PR_DCQMLT` | `ZPRT_DCQMLT` | **új** | `ZPR_DDIC` |
| DC-kizárási kódok | `ZEBFC_PR_DCCODE` | `ZPRC_DCCODE` | **új** + SM30 + tartalom | `ZPR_DDIC` |
| ALV struktúra | `ZEBFS_PR_DCQM_REPORT` | `ZPRS_DCQM_REPORT` | **új** | `ZPR_DDIC` |
| Stock tábla | `ZEBFT_PR_STOCK` | `ZPRT_STOCK` | ⚠️ mezők ellenőrzése | — |
| Zárobjektum | `EZEBFT_PR_STOCK` | `EZPRT_STOCK` | ⚠️ létezik? | `ZPR_DDIC` |
| Stock keresési segítség | `ZEBFH_PR_STOCK` | ⚠️ létezik? | ha nincs, nem kötelező | `ZPR_DDIC` |
| Üzenetosztály | `ZEBF_PR` | `ZPR` | új üzenetek | meglévő |
| Alkalmazásnapló | `ZEBF_PR` / `Z_DC` (BAL FM-ek) | `ZPR_MASS` / `DC` ❓ (`ZCL_PR_LOG`) | alobjektum ⚠️ | — |

❓ **A `ZPR_STOCK` függvénycsoport** (a doksiban „ÚJ függvénycsoport”) *alapértelmezés szerint nem része ennek a lépésnek*. A stockkezelést a keretprogram végzi, ugyanúgy, mint QU5-ben. Ha a senior azt kéri, hogy a stockfunkciók FM-be kerüljenek (a későbbi `ZPR_COCKPIT` miatt), azt külön lépésként tervezzük meg.

---

## 5. Mezőleképezés QU5 → DHC (a legfontosabb különbségek)

**2026-10-08 stockmező-pontosítás:** a felhasználó által jelzett SAP-mezőnév `PRD_STOCK_ID`. A korábbi `PRDSTOCK` név a helyi DHC-exportokból származott; a terv és a generált riport/keretprogram stockhivatkozásait `PRD_STOCK_ID`-ra javítottuk. A `ZPRS_DCQM_REPORT` azonos nevű komponense szükséges a `CORRESPONDING FIELDS` leképezéshez.

| Téma | QU5 | DHC | Mit jelent a kódban |
|---|---|---|---|
| Dokumentumazonosító | `EXBILLDOCNO` CHAR20 | alaptábla/ALV: `DOC_NO` CHAR20; hosszú szöveg: `EXBILLDOCNO` | Az alaptábla és az ALV hivatkozásai `doc_no`; a már létrehozott `ZPRT_DCQMLT` hivatkozásai `exbilldocno` (L3 pontosítás). |
| Boríték | `ENVELOPE` CHAR20 | `ENVELOPE` CHAR9 (`ZPRD_ENVELOPE_ID`) | más típus; `ty_envelope` DHC-típussal |
| Stock kapcsolat | `ZEBFT_PR_MSSFILE-STOCK_ID` → `FILENAME` | `ZPRT_DCQM-PRD_STOCK_ID` | közvetlen `WHERE prd_stock_id = @p_stokid`, nincs fájl-kerülőút |
| Stock ID típusa | `ZEBFD_PR_STOCK_ID` **CHAR10** | `ZPRD_STOCK_ID` **NUMC10** | a paraméter `TYPE zprd_stock_id`; a vezető nullák levágása a címben marad |
| Bankszámla | `GTBANKA` CHAR80 | `ZPRD_BANKNUM` CHAR35 | csak a típus más |
| Kizárási kód | `ZEBFD_PR_BLOCK_DC` | `ZPRD_PR_BLOCK_DC` | — |
| Számláló | `COUNTER` (`ZEBFD_PR_COUNTER`) | `COUNTER` (`ZPRD_PR_COUNTER`, INT4) | ez lesz az „összegző oszlop” |

**DHC-ban nem létező mezők, ezek kimaradnak** (szelekcióból és ALV-ből is): `VKONT`, `ERDAT`, `ERTIM`, `ERNAM`, `POST_CODE1`, `BUKRS`, `DOC_TYPE`, `OPBEL`, `AMNT_EUR`, `WAERS_EUR`, `DESTINATION`, `COPRI`, `GPART`, `SPARTE`, `FILENAME`, `ENVKEY`, `TCOC`, `MCODE`, `STATUS`, `ERROR_CODE`.

**Csak DHC-ban létező mezők:** `PACKAGE_ID`, `AKTYP`, `LAUFD`, `LAUFI`, `PRD_STOCK_ID`, `PRDSPOOL`, `PRDFILE`, `COKEY`, `OPBUK_PR`, `CHEQNUMBR`. Az ALV-ben mind megjelenik (a struktúrából jönnek), a szelekcióra ❓ csak a `PACKAGE_ID`, `AKTYP`, `LAUFD`, `LAUFI` kerül fel.

---

## 6. Indulás előtt tisztázandó (senior)

| # | Kérdés | Alapértelmezés a tervben |
|---|---|---|
| N1 | Biztosan a `ZPRT_DCQM` a tábla (és nem a `ZPRT_PR_DCQM`)? | `ZPRT_DCQM` |
| N2 | Van a `ZPRT_STOCK`-ban `CLOSED` és `DCCOMPL` mező? Ha nincs, felvehetjük? | Van (⚠️ L5) |
| N3 | Kell a teljes keretprogram (4 funkció)? | Igen |
| N4 | A DC-kódtábla tartalma: a QU5-ös `ZEBFC_PR_DCCODE` SE16-exportja | A senior küldi |
| N5 | Kell a hosszú szöveg (`ZPRT_DCQMLT`)? | Igen |
| N6 | Összegző oszlop: elég a `COUNTER` = 1 utolsó oszlopként? Mi legyen a fejléce? | `COUNTER`, fejléc: „Darab” |
| N7 | Lehet-e üres az `ENVELOPE`? Ha igen, az üres borítékú sorok ne „húzzák magukkal” egymást. | Az üres boríték **nem** csoportosít (eltérés a QU5-től, lásd L8.6) |
| N8 | Tranzakciókódok és a keretprogram neve | `ZPR_DC`, `ZPR_DCQM_DISP`, `ZPR_DC_FRAME` |
| N9 | Transport és csomag | A senior adja meg |
| N10 | Naplóalobjektum a `ZPR_MASS` alatt | `DC` |
| N11 | Kell jogosultság-ellenőrzés (pl. a DC engedélyezésre)? | Nem (QU5-ben sincs) |
| N12 | Van tesztadat DHC-ban (`ZPRT_DCQM` sorok kitöltött `PRD_STOCK_ID`-kal)? Ha nincs, hogyan készítünk? | A senior mondja meg |

---

## 7. Lépések

### L0 — Előkészítés

1. Kérj a seniortól **transportot** (N9), és tudd meg a csomagokat: DDIC → `ZPR_DDIC`; a programok a `ZPR_DCQM_EXCLUDE` jelenlegi csomagjába kerülnek (⚠️ SE80-ban nézd meg, várhatóan `ZPR_FUNC`).
2. Nyisd meg QU5-ben (vagy a `01_SOURCES/QU5` mappában) az eredeti kódot. Ez a **minta**, ebből dolgozol.
3. **Ellenőrző lista DHC-ban** (SE11/SE24/SE91/SLG0). Írd le, mit találtál:

   | Objektum | Mit nézz | Miért |
   |---|---|---|
   | `ZPRT_DCQM` | **Kulcsmezők** (csak `MANDT`+`DOC_NO`?) | Az `UPDATE ... WHERE doc_no = ...` csak akkor pontos, ha a `DOC_NO` egyedi |
   | `ZPRT_DCQM` | Van **index** a `PRD_STOCK_ID`-on? | A fő szelekció erre szűr; ha nincs index és sok a sor, szólj |
   | `ZPRT_STOCK` | Mezők: `STOCK_ID`, `CLOSED`, `DCCOMPL` | N2 |
   | `EZPRT_STOCK` | Létezik? | Zárolás |
   | `ZPRD_PR_BLOCK_DC_TEXT`, `ZPRD_PR_BLOCK_QM_TEXT` | Léteznek? | L1 |
   | `ZCL_PR_LOG` | Konstruktor és metódusok: `add_system_message`, `close`, `display` (szignatúrák!) | Napló |
   | SLG0 `ZPR_MASS` | Alobjektumok listája | L7 |
   | Üzenetosztály `ZPR` | Melyik a **következő szabad szám**? | L6 |
   | Stock keresési segítség (pl. `ZPRH_STOCK*`) | Létezik? | Szelekció F4 |

**Kész, ha:** megvan a transport, és a fenti táblát kitöltve átadtad a seniornak.

---

### L1 — Adatelemek (`ZPR_DDIC`)

Csak azt hozd létre, ami **nem létezik** (L0 alapján):

| Adatelem | Típus | Rövid / közepes / hosszú / fejléc szöveg |
|---|---|---|
| `ZPRD_PR_BLOCK_DC_TEXT` | CHAR 255 | Kizárási DC ok hosszú szöveg / DC ok szöveg |
| `ZPRD_PR_BLOCK_QM_TEXT` | CHAR 255 | Kizárási QM ok hosszú szöveg / QM ok szöveg |

A QU5-ös `ZEBFD_PR_BLOCK_DC_TEXT` / `..._QM_TEXT` adatelemek szövegeit vedd át.

**Kész, ha:** az adatelemek aktívak.

---

### L2 — DC-kizárási kódtábla `ZPRC_DCCODE` (`ZPR_DDIC`)

1. SE11 → új tábla `ZPRC_DCCODE`, leírás: „DC kizárás kódjai”.
   - **Szállítási osztály: C** (customizing), táblakarbantartás: „engedélyezett”.
   - Mezők:

     | Mező | Kulcs | Adatelem |
     |---|---|---|
     | `MANDT` | X | `MANDT` |
     | `BLOCK_DC` | X | `ZPRD_PR_BLOCK_DC` |
     | `DESCR40` | | `TEXT40` |
   - Technikai beállítások: APPL2, méretkategória 0, puffereléssel (teljes pufferelés).
2. **Táblakarbantartás-generátor** (SE11 → Segédprogramok): jogosultsági csoport ❓ (alapértelmezés: `&NC&`), egylépéses, function group `ZPR_DCCODE_MAINT` ❓ a `ZPR_DDIC` csomagban.
3. **Tartalom** (N4): vidd fel SM30-ban a QU5-ös kódokat, **a `ZZ` kóddal együtt** („Borítékban kizárt tétel” vagy a QU5-ös szöveg).
   > **Miért kötelező a `ZZ`?** Mentéskor a program **minden** sor kódját ellenőrzi a kódtáblában (`check_entered_data`). A borítéktársak `ZZ`-t kapnak; ha ez nincs a táblában, a mentés `E` üzenettel elhasal.
4. A tartalmat customizing transportba rögzítsd (SM30 ezt felkínálja).

**Kész, ha:** a tábla aktív, SM30-ban karbantartható, és benne vannak a QU5-ös kódok és a `ZZ`.

---

### L3 — Hosszú szöveg tábla `ZPRT_DCQMLT` (`ZPR_DDIC`)

SE11 → új tábla, leírás: „DC/QM funkciók – hosszú szöveg”, szállítási osztály **A**.

| Mező | Kulcs | Adatelem |
|---|---|---|
| `MANDT` | X | `MANDT` |
| `EXBILLDOCNO` | X | `ZPRD_DOC_NO` |
| `BLOCK_DC_TEXT` | | `ZPRD_PR_BLOCK_DC_TEXT` |
| `BLOCK_QM_TEXT` | | `ZPRD_PR_BLOCK_QM_TEXT` |

**2026-10-08 pontosítás a felhasználó mezőlistája alapján:** a már létrehozott `ZPRT_DCQMLT` dokumentumazonosítója `EXBILLDOCNO`. A kód ezt használja a hosszú szöveg olvasásakor és mentésekor; a `ZPRT_DCQM` és `ZPRS_DCQM_REPORT` mezőneve továbbra is `DOC_NO`. Kapcsolat: `ZPRT_DCQMLT-EXBILLDOCNO = ZPRT_DCQM-DOC_NO`. Az `EXBILLDOCNO` tényleges adatelemét és a tábla kulcsát SE11-ben ellenőrizni kell.

Technikai beállítások: APPL1, pufferelés nélkül. Bővítési kategória: „nem bővíthető” vagy a projektszabvány szerint.

**Kész, ha:** a tábla aktív és létrejött az adatbázisban (SE14 / az aktiválási napló hibamentes).

---

### L4 — ALV struktúra `ZPRS_DCQM_REPORT` (`ZPR_DDIC`)

SE11 → új struktúra, leírás: „DC/QM funkciók ALV struktúra”. **A mezők sorrendje fontos** (ez lesz az ALV oszlopsorrendje):

```
DOC_NO            ZPRD_DOC_NO
BLOCK_DC          ZPRD_PR_BLOCK_DC        ← idegen kulcs: ZPRC_DCCODE (lásd lent)
BLOCK_DC_TEXT     ZPRD_PR_BLOCK_DC_TEXT
BLOCK_QM          ZPRD_PR_BLOCK_QM
BLOCK_QM_TEXT     ZPRD_PR_BLOCK_QM_TEXT
ENVELOPE          ZPRD_ENVELOPE_ID
… a ZPRT_DCQM további üzleti mezői az alábbi felsorolás szerint …
   (PYMET, DOC_CAT, AMNT, WAERS, DUEDATE, BANKACCOUNTNUM, GIRO, NAME1, SYSID, LAND1,
    AB, BIS, TARIFTYP, AKLASSE, ZBIZCAT, MAHNS, MAHNV, FORM, COTYP, PACKAGE_ID, CHEQNUMBR,
    COKEY, REGMAILNUMBER, OPBUK_PR, AKTYP, LAUFD, LAUFI, PRD_STOCK_ID, PRDSPOOL, PRDFILE)
COUNTER           ZPRD_PR_COUNTER         ← az utolsó LÁTHATÓ oszlop
CHANGED           FLAG                    ← technikai, rejtett
HANDLE_STYLE      LVC_T_STYL              ← technikai, cellastílusok
```

**A 2026-10-08-i friss export alapján:** a struktúra továbbra is 39 komponensű. A `MANDT` és a hat adatbázisbeli technikai mező (`CRUSER`, `CRDATE`, `CRTIME`, `CHUSER`, `CHDATE`, `CHTIME`) nem kerül az ALV-ba. A riport a DC-módosítás mentésekor, a keretprogram a stockállapot mentésekor kitölti a saját alaptáblája `CHUSER`, `CHDATE`, `CHTIME` mezőit; a létrehozási adatokat megőrzi.

- **Pénznem-referencia:** `AMNT` → hivatkozó mező `ZPRS_DCQM_REPORT-WAERS` (különben nem aktiválható).
- **Idegen kulcs `BLOCK_DC`-n:** ellenőrző tábla `ZPRC_DCCODE`. Ettől lesz F4 (értéklista) az ALV cellában és a kizárási popupban. A `ZPRT_DCQM` táblát **nem** módosítjuk, csak a saját struktúránkat.

**Kész, ha:** a struktúra aktív, és SE11 → Ellenőrzés nem ad hibát.

---

### L5 — Stock: tábla, zárolás, keresési segítség

1. ⚠️ `ZPRT_STOCK`: ha **nincs** `CLOSED` vagy `DCCOMPL` mező → **állj meg, szólj a seniornak** (N2). Közös táblát nem bővítünk egyeztetés nélkül.
2. ⚠️ Zárobjektum `EZPRT_STOCK`: ha nem létezik, SE11 → zárobjektum `EZPRT_STOCK`, elsődleges tábla `ZPRT_STOCK`, zárolási mód „E”, paraméter `STOCK_ID`. Ez generálja az `ENQUEUE_EZPRT_STOCK` / `DEQUEUE_EZPRT_STOCK` FM-eket.
3. Keresési segítség: ha van (L0), használd a `MATCHCODE OBJECT`-ben. Ha nincs, **hagyd ki**: a `ZPRD_STOCK_ID` adatelem F4-e elég, új keresési segítséget most ne csinálj.

**Kész, ha:** a zárolás FM-jei léteznek, és a stock tábla mezői rendben vannak.

---

### L6 — Üzenetek a `ZPR` osztályban

A QU5-ös `ZEBF_PR` üzeneteket **új, szabad számokra** kell felvenni a `ZPR`-ben. A szövegeket QU5 SE91-ből másold. A lenti „jelentés” oszlop csak a kódból kikövetkeztetett tartalom, ellenőrzésre szolgál.

| QU5 | Típus | Hol használt | Jelentés (QU5-ből másold a pontos szöveget) | DHC szám |
|---|---|---|---|---|
| 020 | E | keret, riport | „A Stock ID nem létezik!” | … |
| 021 | I/E | keret, riport | A stock lezárt, csak megjelenítés lehetséges | … |
| 023 | I | riport | Nincs kijelölt sor | … |
| 024 | S | riport | Mentés sikeres | … |
| 025 | S | riport | Mentés sikertelen | … |
| 026 | I | keret | A DC már engedélyezve van | … |
| 027 | S | keret | DC engedélyezés sikeres | … |
| 028 | S | keret | DC engedélyezés sikertelen | … |
| 029 | S | keret | Engedélyezett sorok száma: &1 | … |
| 030 | S | keret | Kizárt sorok száma: &1 | … |
| 031 | I | keret | A DC még nincs engedélyezve | … |
| 032 | S | keret | Engedélyezés visszavétele sikeres | … |
| 033 | S | keret | Engedélyezés visszavétele sikertelen | … |
| 044 | S | riport | &1 kizárva: &2 &3 | … |
| 045 | S | riport | &1 kizárása visszavonva | … |
| 046 | E | riport | „DC zárolás kód &1 nem létezik.” | … |
| 047 | E | riport | „Ha DC zárolás szöveget ad meg, akkor adjon meg DC zárolás kódot is!” | … |
| 048 | E | keret | DC kész, a stock nem módosítható | … |
| 054 | I | riport | A &1 stockhoz nincs adat | … |
| 056 | I | riport | „A szelekció ki lett bővítve (egy borítékba kerülő nyomtatványok megjelennek)” | … |
| 057 | E | riport | „Ha megadott összeget, akkor adjon meg pénznemet is.” | … |
| 059 | S | riport | „A kizárt rekordok száma: &1.” | … |

- A kitöltött táblát **másold be a `02_NOTES/`-ba** (új fájl: `2026-MM-NN_dc-uzenet-lekepezes_WIP.md`). A kódban minden `MESSAGE` után kommentben szerepeljen az üzenet szövege (ahogy QU5-ben).
- Ha egy üzenet szövege a `ZPR`-ben már szó szerint létezik, használd azt, ne vegyél fel duplikátumot.

**Kész, ha:** az üzenetek léteznek, és a leképező tábla kész.

---

### L7 — Naplóalobjektum

SLG0 → objektum `ZPR_MASS` → alobjektum `DC` ❓ (N10), szöveg: „DC napló bejegyzések”. Ha már van megfelelő alobjektum, azt használd. Az SLG0-bejegyzés transportálható (customizing).

**Kész, ha:** az alobjektum látszik SLG0-ban.

---

### L8 — A `ZPR_DCQM_EXCLUDE` riport átírása

**Módszer:** a QU5-ös `ZEBF_PR_DCQM_REPORT` (+ `_O01`, `_I01`) kódját vedd alapul, és a lenti eltérésekkel ültesd át. A régi DHC-kódból semmit sem kell megtartani a fejlécen kívül.

#### L8.1 Fejléc

A DHC-fejlécformátum marad (lásd a jelenlegi sorok 3–16-ot). Javítsd a programnevet, és vegyél fel egy módosítási sort (dátum, a te felhasználód, leírás: „DC kizárás – QU5 ZEBF_PR_DCQM_REPORT átvétele”).

#### L8.2 Include-ok

A QU5 két include-ot használ (`_O01`, `_I01`). Hozd létre: `ZPR_DCQM_EXCLUDE_O01` (PBO modulok) és `ZPR_DCQM_EXCLUDE_I01` (PAI modulok), a QU5-ös tartalommal. Ha a projektszabvány mást kér (pl. `_TOP`/`_F01`), a senior megmondja.

#### L8.3 Globális deklarációk

A QU5-ös deklarációk, a következő cserékkel:

| QU5 | DHC |
|---|---|
| `TABLES: zebft_pr_dcqm.` | `TABLES: zprt_dcqm.` |
| `zebfs_pr_dcqm_report` | `zprs_dcqm_report` |
| `ty_envelope-envelope TYPE zebfd_pr_envelop` | `TYPE zprd_envelope_id` |
| `RANGES gr_waers FOR ...` + `ls_waers` | `DATA gr_waers TYPE RANGE OF zprt_dcqm-waers.` + `DATA gs_waers LIKE LINE OF gr_waers.` (a `RANGES` elavult) |
| `gv_log_handle TYPE balloghndl` | `DATA go_log TYPE REF TO zcl_pr_log.` |
| `gr_docking_container`, `gr_document`, `gv_line_header`, FORM `add_line` | **elhagyni** (QU5-ben sincs használva) |

#### L8.4 Szelekciós képernyő

```abap
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.
SELECTION-SCREEN SKIP.
PARAMETERS: p_stokid TYPE zprd_stock_id OBLIGATORY,
            p_modif  TYPE flag NO-DISPLAY.
SELECTION-SCREEN SKIP.
SELECT-OPTIONS:
  so_docno FOR zprt_dcqm-doc_no,
  so_envlo FOR zprt_dcqm-envelope,
  so_pymet FOR zprt_dcqm-pymet,
  so_dcat  FOR zprt_dcqm-doc_cat,
  so_amnt  FOR zprt_dcqm-amnt.
PARAMETERS p_waers TYPE waers.
SELECT-OPTIONS:
  so_dued  FOR zprt_dcqm-duedate,
  so_bkacc FOR zprt_dcqm-bankaccountnum,
  so_giro  FOR zprt_dcqm-giro,
  so_name  FOR zprt_dcqm-name1,
  so_sysid FOR zprt_dcqm-sysid,
  so_land1 FOR zprt_dcqm-land1,
  so_ab    FOR zprt_dcqm-ab,
  so_bis   FOR zprt_dcqm-bis,
  so_tarif FOR zprt_dcqm-tariftyp,
  so_aklas FOR zprt_dcqm-aklasse,
  so_mahns FOR zprt_dcqm-mahns,
  so_mahnv FOR zprt_dcqm-mahnv,
  so_zbizc FOR zprt_dcqm-zbizcat,
  so_cotyp FOR zprt_dcqm-cotyp,
  so_form  FOR zprt_dcqm-form,
  so_pckid FOR zprt_dcqm-package_id,
  so_aktyp FOR zprt_dcqm-aktyp,
  so_laufd FOR zprt_dcqm-laufd,
  so_laufi FOR zprt_dcqm-laufi,
  so_blodc FOR zprt_dcqm-block_dc,
  so_bloqm FOR zprt_dcqm-block_qm,
  so_regmn FOR zprt_dcqm-regmailnumber.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE text-002.
PARAMETERS p_vari TYPE slis_vari.
SELECTION-SCREEN END OF BLOCK b02.
```

- **Szövegelemek:** `TEXT-001` = „Szelekció”, `TEXT-002` = „Megjelenítés”. Szelekciós szövegek: mindenhol a „Szótár-hivatkozás” pipa, kivéve `P_VARI` = „Layout”.
- Ha van stock keresési segítség (L5), a `p_stokid` kapja meg: `MATCHCODE OBJECT ...`.
- A QU5 `INITIALIZATION` blokkját (`LOOP AT SCREEN` a `P_STOKID`-ra) **ne hozd át**. `INITIALIZATION`-ben nem hat, és ha hatna, a `ZPR_DCQM_DISP` tranzakcióban nem lehetne stockot megadni.

#### L8.5 Események

- `AT SELECTION-SCREEN`: a QU5-tel azonos (`check_stockid` + az összeg/pénznem ellenőrzés), az új üzenetszámokkal.
- `AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_vari`: azonos (`lcl_layout_f4=>for_salv`).
- `START-OF-SELECTION`: azonos (pénznem-tizedes korrekció, `gr_waers` feltöltése, `gv_modif` meghatározása, `check_lock`, `select_data`), az alábbiakkal:
  - `sy-tcode EQ 'ZEBF_PR_DCQM_MOD'` ág **elhagyandó** (ilyen tranzakció nincs), és `'ZEBF_PR_DCQM_DISP'` → `'ZPR_DCQM_DISP'`.
  - **Miért kell a tizedes-korrekció?** A `CURR` mezőt a SAP mindig 2 tizedessel tárolja; a 0 tizedesű pénznemnél (HUF) a 100 Ft-ot `1.00`-ként. A szelekción beírt összeget ezért osztani kell. A QU5-ös logikát változtatás nélkül vedd át.
- `END-OF-SELECTION`: `PERFORM display_alv.` (→ `CALL SCREEN '0100'`).

#### L8.6 `select_data` — a legtöbb változás itt van

A QU5-ös fájl-kerülőút (`ZEBFT_PR_MSSFILE`, `lt_files`, `lr_filename`) **teljesen kimarad**. A váz:

```abap
FORM select_data.

  DATA: lt_env      TYPE STANDARD TABLE OF zprs_dcqm_report,
        lt_env_plus TYPE STANDARD TABLE OF zprs_dcqm_report,
        ls_env_plus TYPE zprs_dcqm_report,
        lt_plus     TYPE STANDARD TABLE OF zprs_dcqm_report,
        lt_dcqmlt   TYPE STANDARD TABLE OF zprt_dcqmlt,
        ls_dcqmlt   TYPE zprt_dcqmlt,
        lv_plus_lines TYPE i.
  FIELD-SYMBOLS: <ls_alv> TYPE zprs_dcqm_report.

* 1) Rows of the stock according to the selection
  SELECT * FROM zprt_dcqm
    INTO CORRESPONDING FIELDS OF TABLE @gt_0100_alv
    WHERE prd_stock_id      =  @p_stokid
      AND doc_no        IN @so_docno
      AND envelope      IN @so_envlo
      AND pymet         IN @so_pymet
      AND doc_cat       IN @so_dcat
      AND amnt          IN @so_amnt
      AND waers         IN @gr_waers
      AND duedate       IN @so_dued
      AND bankaccountnum IN @so_bkacc
      AND giro          IN @so_giro
      AND name1         IN @so_name
      AND sysid         IN @so_sysid
      AND land1         IN @so_land1
      AND ab            IN @so_ab
      AND bis           IN @so_bis
      AND tariftyp      IN @so_tarif
      AND aklasse       IN @so_aklas
      AND mahns         IN @so_mahns
      AND mahnv         IN @so_mahnv
      AND zbizcat       IN @so_zbizc
      AND cotyp         IN @so_cotyp
      AND form          IN @so_form
      AND package_id    IN @so_pckid
      AND aktyp         IN @so_aktyp
      AND laufd         IN @so_laufd
      AND laufi         IN @so_laufi
      AND block_dc      IN @so_blodc
      AND block_qm      IN @so_bloqm
      AND regmailnumber IN @so_regmn.

  IF gt_0100_alv IS INITIAL.
    MESSAGE i054(zpr) WITH p_stokid.   " <- new ZPR number from L6
*   No data for stock &1
    LEAVE LIST-PROCESSING.             " back to the selection screen
  ENDIF.

* 2) Envelope extension: all rows of the found envelopes (same stock)
  lt_env = gt_0100_alv.
  DELETE lt_env WHERE envelope IS INITIAL.        " N7 - empty envelope does not group
  SORT lt_env BY envelope.
  DELETE ADJACENT DUPLICATES FROM lt_env COMPARING envelope.
  IF lt_env IS NOT INITIAL.
    SELECT * FROM zprt_dcqm
      INTO CORRESPONDING FIELDS OF TABLE @lt_env_plus
      FOR ALL ENTRIES IN @lt_env
      WHERE prd_stock_id = @p_stokid
        AND envelope = @lt_env-envelope.
  ENDIF.

  SORT gt_0100_alv BY doc_no.
  LOOP AT lt_env_plus INTO ls_env_plus.
    READ TABLE gt_0100_alv TRANSPORTING NO FIELDS
      WITH KEY doc_no = ls_env_plus-doc_no BINARY SEARCH.
    IF sy-subrc <> 0.
      APPEND ls_env_plus TO lt_plus.
    ENDIF.
  ENDLOOP.
  lv_plus_lines = lines( lt_plus ).
  APPEND LINES OF lt_plus TO gt_0100_alv.

* 3) Long texts + counter column
  ... (SELECT FROM zprt_dcqmlt FOR ALL ENTRIES ... WHERE exbilldocno = ...-doc_no,
       READ BINARY SEARCH, fill block_dc_text / block_qm_text, <ls_alv>-counter = 1)

* 4) Sort, keep original copy, info message
  SORT gt_0100_alv BY envelope doc_no.
  gt_0100_orig = gt_0100_alv.
  IF lv_plus_lines > 0.
    MESSAGE i056(zpr).                 " <- new ZPR number
  ENDIF.

ENDFORM.
```

Eltérések a QU5-től, **szándékosan**:
- A QU5 akkor jelezte az i054-et, ha a stockhoz nem volt fájl. Nálunk akkor, ha a szűrés üres eredményt ad. Fájl nincs, ezért ez a legközelebbi megfelelő.
- Üres `ENVELOPE` esetén nincs borítékbővítés (N7). **Ugyanezt a feltételt** a kizárásnál (L8.8) és a cellamódosításnál (`handle_data_changed`) is tedd be: `CHECK ... envelope IS NOT INITIAL`, különben egy kizárás az összes üres borítékú sort kizárná.
- ❓ Ha a `FOR ALL ENTRIES` + `IN` select nagyon lassú (nagy stockok), szólj; ilyenkor az indexet (L0) kell megnézni, nem a kódot.

#### L8.7 `check_stockid`, `check_lock`

- `check_stockid`: `SELECT SINGLE closed FROM zprt_stock WHERE stock_id = @p_stokid INTO @lv_closed.` A logika egyébként azonos.
- `check_lock`: `ENQUEUE_EZPRT_STOCK` a `stock_id = p_stokid` paraméterrel. Csak módosító módban (`CHECK gv_modif EQ abap_true.`), ahogy QU5-ben.

#### L8.8 Eseménykezelő osztály (`gcl_alv_grid_01_event_receiver`)

A QU5-ből átveendő: `on_alv_user_command`, `on_alv_toolbar`, `handle_data_changed`, valamint az üres `on_alv_menu_button` és `on_double_click`. A cserék:

- `exbilldocno` → `doc_no` (mindenhol).
- **KIZAR** popup (`POPUP_GET_VALUES_USER_CHECKED`):
  - 1. mező: `tabname = 'ZPRS_DCQM_REPORT'`, `fieldname = 'BLOCK_DC'`. A struktúra idegen kulcsa miatt itt lesz F4. A `comp_tab` = `'ZPRC_DCCODE'`, a `comp_field` = `'BLOCK_DC'`.
  - 2. mező: `tabname = 'ZPRT_DCQMLT'`, `fieldname = 'BLOCK_DC_TEXT'`.
  - `programname = 'ZPR_DCQM_EXCLUDE'`, `formname = 'CHECK_ENTERED_DATA_POPUP'`.
  - Típusok: `lv_block_dc TYPE zprd_pr_block_dc`, `lv_block_dc_text TYPE zprd_pr_block_dc_text`.
- A borítéktársak `'ZZ'` kódja **marad** (ez az üzleti szabály), de üres borítékra ne fusson (L8.6).
- A toolbar gombjai (`KIZAR` = „Kizárás”, `KIZVISSZ` = „Kizárás vissza”) csak módosító módban jelenjenek meg, ahogy QU5-ben.
- `WHEN 'HIST'` és `WHEN 'REFRESH'` üres ágak: **elhagyhatók**.

#### L8.9 Mentés (`user_command_0100`, `SAVE` ág)

QU5 szerint: `check_changed` → napló létrehozása → a módosult sorokra UPDATE + hosszú szöveg + naplóüzenet → COMMIT/ROLLBACK → napló megjelenítése → kilépés. Változások:

```abap
* log
  CREATE OBJECT go_log
    EXPORTING
      iv_log_object    = 'ZPR_MASS'
      iv_log_subobject = 'DC'.          " N10, check ZCL_PR_LOG signature (L0)

  LOOP AT gt_0100_alv INTO gs_0100_alv WHERE changed EQ abap_true.

    UPDATE zprt_dcqm SET block_dc = @gs_0100_alv-block_dc
      WHERE doc_no = @gs_0100_alv-doc_no.   " ⚠️ if DOC_NO is not unique: AND prd_stock_id = @p_stokid
    IF sy-subrc <> 0.
      lv_error = abap_true.
    ENDIF.

    ... long text: see below ...

    ... MESSAGE s044/s045(zpr) ... INTO gv_dummy.
    go_log->add_system_message( ).
  ENDLOOP.

  IF lv_error IS INITIAL.
    COMMIT WORK.
    MESSAGE s024(zpr) INTO gv_dummy.
  ELSE.
    ROLLBACK WORK.
    MESSAGE s025(zpr) INTO gv_dummy.
  ENDIF.
  go_log->add_system_message( ).
  go_log->close( ).                     " ⚠️ check: does close() save the log?
  go_log->display( ).
```

- **Hosszú szöveg**, egy szándékos eltéréssel a QU5-től:
  - Ha van rekord és a DC-szöveg üres → **ne töröld a rekordot**, hanem `UPDATE zprt_dcqmlt SET block_dc_text = @space WHERE exbilldocno = ...`. A QU5 törölte, de akkor elveszne a QM-szöveg; a QM-funkció (`ZEBF_PR_QM`) később ugyanezt a táblát fogja használni.
  - Ha van rekord és a szöveg nem üres → `UPDATE ... SET block_dc_text = ...`.
  - Ha nincs rekord és a szöveg nem üres → `INSERT zprt_dcqmlt FROM @ls_dcqmlt`.
- **Hibakezelés:** a QU5 a `LOOP` utáni `sy-subrc` alapján commitolt. Ez akkor is „sikertelen” üzenetet adott, ha egyszerűen nem volt módosítás. Nálunk az `lv_error` flag dönt.
- A naplóban **minden** módosított sorról legyen bejegyzés (s044 vagy s045), ahogy QU5-ben.

#### L8.10 Kilépés, változásfigyelés, mezőkatalógus, cellastílus

- `exit_command_0100`, `check_changed`, `alv_grid_01_free`: a QU5-tel azonosak, `exbilldocno` → `doc_no` cserével. Figyelmeztető popup kilépéskor, ha van nem mentett módosítás.
- `check_entered_data` és `check_entered_data_popup`: `zebfc_pr_dccode` → `zprc_dccode`; `error-msgid = 'ZPR'`, új üzenetszámokkal.
- `create_controls_0100`: azonos, de `i_structure_name = 'ZPRS_DCQM_REPORT'`. A címsor: „<stock> stock feldolgozása” / „… megjelenítése” (`CONCATENATE`, nem string template!).
- `alv_fieldcat_0100_mod`:
  - `NAME1` → fejléc „Név”; `CHANGED` → `no_out`; `BLOCK_DC`, `BLOCK_QM` → `f4availabl`.
  - `AMNT_EUR`, `WAERS_EUR` ágak **törlendők** (nincs ilyen mező).
  - **`COUNTER`**: `coltext` = „Darab” ❓ (N6). Az összegzést a felhasználó a Σ gombbal kéri, és layout-variánsba menti. Automatikus `do_sum`-ot ne állíts be, csak ha a senior kéri.
- `cell_style_alv_outtab_0100`: a `'BLOCKED'` mező stílusa **elhagyandó** (DHC-ban nincs ilyen mező). Szerkeszthető marad a `BLOCK_DC` és a `BLOCK_DC_TEXT`.
- A `log_create`, `log_add_message`, `log_display` FORM-ok (BAL FM-ek) **nem kellenek**; helyettük `ZCL_PR_LOG`.

#### L8.11 0100-as képernyő és GUI-státuszok

Az ALV már nem a `default_screen`-en, hanem custom containerben fut, ahogy QU5-ben.

- **0100-as képernyő** (SE51), normál képernyő:
  - Elemlista: **OK-kód mező `GV_OKCODE_0100`**, custom control **`ALV_CONTAINER_01`** a teljes képernyőn, átméretezhető (függőleges és vízszintes, min. 10×10).
  - Flow logic:
    ```
    PROCESS BEFORE OUTPUT.
      MODULE status_0100.
      MODULE create_controls_0100.

    PROCESS AFTER INPUT.
      MODULE exit_command_0100 AT EXIT-COMMAND.
      MODULE user_command_0100.
    ```
- **GUI-státuszok** (SE41):

  | Státusz | Funkciók |
  |---|---|
  | `STAT_0100` (módosítás) | `SAVE` (Ctrl+S), `BACK` (F3), `EXIT` (Shift+F3), `CANCEL` (F12) |
  | `STAT_0100_DISP` (megjelenítés) | `BACK`, `EXIT`, `CANCEL` |

  > A `BACK`, `EXIT`, `CANCEL` **funkciótípusa „E” (Exit command)** legyen, különben az `AT EXIT-COMMAND` modul nem fut le.
- **Címsorok:** `TITLE_0100_MOD` = „Nyomtatási sorok kizárása”, `TITLE_0100_DISP` = „Nyomtatási sorok megjelenítése”.
- A régi `D0100` GUI-státusz ezután nem kell. **Ne töröld**, jelezd a seniornak.

**Kész, ha:** a program szintaktikailag hibátlan, aktív (az include-okkal, a képernyővel és a státuszokkal együtt), és a `SE38`-ból indítva egy teszt-stockra megjelenik az ALV.

---

### L9 — Keretprogram `ZPR_DC_FRAME` (új)

Alapja a QU5 `ZEBF_PR_DC_FRAME`. Cserék:

| QU5 | DHC |
|---|---|
| `TABLES: zebft_pr_dcqm.` | elhagyandó (nem kell) |
| `ty_fname`, `gs_stock TYPE zebft_pr_stock` | `gs_stock TYPE zprt_stock` |
| `p_stokid TYPE zebfd_pr_stock_id ... MATCHCODE OBJECT zebfh_pr_stock` | `TYPE zprd_stock_id OBLIGATORY` (+ matchcode, ha van, lásd L5) |
| `ENQUEUE/DEQUEUE_EZEBFT_PR_STOCK` | `ENQUEUE/DEQUEUE_EZPRT_STOCK` |
| `UPDATE zebft_pr_stock SET dccompl ...` | `UPDATE zprt_stock SET dccompl = @abap_true WHERE stock_id = @p_stokid.` |
| `SUBMIT zebf_pr_dcqm_report ...` | `SUBMIT zpr_dcqm_exclude VIA SELECTION-SCREEN WITH p_stokid EQ p_stokid WITH p_modif EQ uv_modif AND RETURN.` |
| BAL FORM-ok (`log_create`, `log_add_message`, `log_display`) | `ZCL_PR_LOG` (mint L8.9) |
| üzenetek `(zebf_pr)` | `(zpr)`, új számokkal |

`get_count` a fájl-kerülőút helyett két egyszerű számlálással:

```abap
  SELECT COUNT(*) FROM zprt_dcqm
    WHERE prd_stock_id = @p_stokid AND block_dc <> @space
    INTO @lv_kizart.
  SELECT COUNT(*) FROM zprt_dcqm
    WHERE prd_stock_id = @p_stokid AND block_dc = @space
    INTO @lv_enged.
```

- **Szövegek** (a QU5 képernyőkép szerint):
  - Programcím: „Data Control(DC): Műveletek”; `TEXT-001` = „Elvégzendő műveletek:”.
  - Szelekciós szövegek: `P_STOKID` = „Stock ID”, `P_MOD` = „Nyomtatási sorok kizárása”, `P_DISP` = „Nyomtatási sorok megtekintése”, `P_ENG` = „DC engedélyezés”, `P_ENGV` = „DC engedélyezés visszavétele”.
- A `check_stockid` logikája azonos:
  - Lezárt stock + kizárás → átvált megjelenítésre, i021.
  - DC kész + kizárás → e048.
  - Lezárt stock + engedélyezés/visszavétel → e021.

**Kész, ha:** a program aktív, és mind a 4 rádiógomb a várt műveletet végzi (L11).

---

### L10 — Tranzakciók (SE93)

| Tranzakció ❓ | Típus | Program | Képernyő | Szöveg |
|---|---|---|---|---|
| `ZPR_DC` | Program és szelekciós képernyő (report transaction) | `ZPR_DC_FRAME` | 1000 | Data Control (DC) |
| `ZPR_DCQM_DISP` | Program és szelekciós képernyő | `ZPR_DCQM_EXCLUDE` | 1000 | DC/QM funkciók megjelenítése |

GUI-támogatás: SAP GUI for Windows (és HTML, ha a projektben szokás).

**Kész, ha:** mindkét tranzakció elindul.

---

### L11 — Tesztelés

Előfeltétel: tesztstock DHC-ban (N12), legalább egy **többsoros borítékkal**, egy **egysoros borítékkal**, és ha lehet, egy üres borítékú sorral. Tölts fel 2–3 kódot `ZPRC_DCCODE`-ba (a `ZZ`-vel együtt).

| # | Lépés | Elvárt eredmény |
|---|---|---|
| T1 | `ZPR_DC`, nem létező Stock ID | e020 hibaüzenet, a képernyő marad |
| T2 | `ZPR_DC`, megtekintés | ALV, **nincs** Kizárás gomb és Mentés |
| T3 | `ZPR_DC`, kizárás, szűrés egy borítékon belüli 1 sorra | Az ALV mind a boríték összes sorát mutatja + i056 |
| T4 | Kizárás egy sorra, kód + szöveg megadása | A sor a megadott kódot kapja, a borítéktársak `ZZ`-t, s059 a darabszámmal |
| T5 | Kizárás popup, nem létező kód | Hibaüzenet a popupban, nem zárul be |
| T6 | Kizárás popup, szöveg kód nélkül | e047 a popupban |
| T7 | Mentés | SE16 `ZPRT_DCQM-BLOCK_DC` és `ZPRT_DCQMLT` frissült; napló sorrekordonként; s024 |
| T8 | Kizárás vissza + mentés | A kód és a szöveg törlődik a sorról és a borítéktársakról; a `ZPRT_DCQMLT` rekord megmarad, a `BLOCK_QM_TEXT` nem sérül |
| T9 | Cellában `BLOCK_DC` átírása | Gyűrűzik a borítéktársakra; mentéskor kódellenőrzés |
| T10 | Kilépés mentés nélkül, módosítás után | Figyelmeztető popup; „Nem” → marad |
| T11 | Üres borítékú sor kizárása | **Csak** az az egy sor záródik ki (N7) |
| T12 | Két felhasználó ugyanarra a stockra kizárás módban | A második zárolási hibát kap (`ENQUEUE`) |
| T13 | `ZPR_DC`, DC engedélyezés | `ZPRT_STOCK-DCCOMPL = 'X'`; napló: s027 + engedélyezett/kizárt darabszám |
| T14 | Engedélyezett stockon kizárás | e048 |
| T15 | DC engedélyezés visszavétele | `DCCOMPL = ' '`; napló s032; ezután újra lehet kizárni |
| T16 | Összeg szűrés HUF-ban (pl. 5000) | Helyes sorok (a tizedes-korrekció működik); összeg pénznem nélkül → e057 |
| T17 | ALV: Σ a `COUNTER` oszlopon, részösszeg `ENVELOPE` szerint | Borítékonkénti darabszám; layout menthető |
| T18 | `ZPR_DCQM_DISP` közvetlenül | Csak megjelenítés |

Az eredményt (OK/hiba, dátum) írd a `02_NOTES/2026-MM-NN_dc-teszt-jegyzokonyv_WIP.md` fájlba.

---

### L12 — Minőségi kapu

1. **Kiterjesztett programellenőrzés** (SLIN) mindkét programra: nincs hiba, a figyelmeztetéseket megindokolod.
2. **ATC** a projekt variánsával ❓ (a senior adja meg): nincs 1-es és 2-es prioritású találat. A 3-asokat vagy javítod, vagy indokolod.
3. **Kódreview** a seniorral (vagy a workspace-ben a `/abap-code-review` paranccsal: ATC + ABAP Unit).
   - Unit tesztet ehhez a dialógusprogramhoz **nem várunk el**, hacsak a senior nem kéri.
4. A forrásokat töltsd le a `04_ASSETS/abap/` mappába (`ZPR_DCQM_EXCLUDE.abap`, `ZPR_DCQM_EXCLUDE_O01.abap`, `ZPR_DCQM_EXCLUDE_I01.abap`, `ZPR_DC_FRAME.abap`).

---

### L13 — Átadás

- A transportot **ne engedd ki** magad; szólj a seniornak, hogy kész.
- Írd be a projekt `_LOG.md`-jébe (mai dátum alá, 2–4 sor): mi készült el, mi tér el a tervtől, és mi maradt nyitva.

---

## 8. „Kész” kritérium

- [ ] Minden DDIC-objektum aktív (L1–L7), a DC-kódtábla tartalma (a `ZZ`-vel) transportban van.
- [ ] `ZPR_DCQM_EXCLUDE` átírva, nincs benne kiremárkolt halott kód, aktív.
- [ ] `ZPR_DC_FRAME` + `ZPR_DC` + `ZPR_DCQM_DISP` működik.
- [ ] Mind a T1–T18 teszteset OK, dokumentálva.
- [ ] Az ALV utolsó látható oszlopa a `COUNTER`, minden sorban 1-gyel, és összegezhető.
- [ ] Az ATC tiszta (nincs prio 1/2), a review lezárva.
- [ ] Minden objektum egy transportban van, a `_LOG.md` frissítve.

---

## 9. Gyakori buktatók

1. **Kimaradó `exbilldocno` → `doc_no` csere.** Fordításkor kiderül, de a `READ TABLE ... WITH KEY` és a `SORT ... BY` sorokban könnyű elnézni. Keress rá a teljes programban.
2. **`BINARY SEARCH` rendezés nélkül.** Minden `READ ... BINARY SEARCH` előtt a táblát **ugyanarra a kulcsra** kell rendezni, különben a program csendben rossz eredményt ad.
3. **`FOR ALL ENTRIES` üres táblával** = az összes sort hozza vissza. Előtte mindig `IF lt_... IS NOT INITIAL`.
4. **Az `APPEND` a rendezett táblába** a borítékbővítésnél: ezért gyűjtünk előbb egy külön `lt_plus` táblába, és csak a ciklus után fűzzük hozzá.
5. **A GUI-státusz funkciótípusa:** ha a `BACK` nem „E” típusú, a kilépés nem a figyelmeztető ágon megy.
6. **Pénznem-referencia** a struktúrában (`AMNT` → `WAERS`): nélküle az ALV rosszul formáz, és a struktúra sem aktiválható.
7. **A `ZZ` kód hiánya** a kódtáblából: minden mentés elhasal.
8. **Közös táblák** (`ZPRT_DCQM`, `ZPRT_STOCK`): szerkezetükhöz egyeztetés nélkül **ne nyúlj**.
