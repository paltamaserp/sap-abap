# 00_BRIEF — TomegesNyomtatasEndre (tömeges nyomtatás)

> Ezt olvasd elsőként minden session elején. (Új projekt indítása: lásd a
> `_TEMPLATE/README.md` checklistjét.)

---

## Cél

<Mit építünk / oldunk meg? 1–3 mondat.>

## Miért

<Üzleti / technikai indok. Honnan jön az igény? ClickUp-kód, ha van.>

## „Kész" kritérium

- <Mérhető feltétel 1>
- <Mérhető feltétel 2>

## Érintett objektumok

- <SAP objektumok, táblák, szervizek>

## Kulcs-konvenciók

| Elem | Érték |
|---|---|
| Rendszer | ECC / CRM (**válaszd ki** — a CLAUDE.md alapértéke ECC) |
| Csomag / transport | <…> |
| ATC variant | <…> |
| Guideline | oneERP ABAP Development Guideline V22 (`[02] context/`) |

## Tartalom-térkép

**Elsődleges munkabázis (felhasználói döntés, 2026-10-17):** `05_FINAL/abap-2026-10-17/`. A további elemzések és javítások ebből a mentett aktív SAP-forrásból indulnak. A külön cockpit-/QA-tervezetek és szükséges kiegészítők megmaradtak. A felhasználó kérésére 127 korábbi fájl az [archívumba](<../../[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/README.md>) került, eredeti útvonal- és hash-jegyzékkel. [Tisztítási elemzés](02_NOTES/2026-10-17_fajltisztitas-elemzes_WIP.md).

- `01_SOURCES/` — bemenetek (dump-ok, ADT export, dokumentáció).
- `02_NOTES/` — aktuális munkajegyzetek; a korábbi 17 jegyzet/ellenőrzési eredmény archiválva.
- `03_DRAFTS/` — WIP verziók, iterációk.
- `03_DRAFTS/2026-10-21_release-stock-new-riport_WIP/` — **aktuális, kizárólag riportmódosítás** a megadott 05_FINAL alapból: Lezárás → új `release_stock_new` → változatlan `ZCL_PR_STOCK=>CLOSE_STOCK( iv_stock )` → visszaolvasott QM → CL váltás alapján STATUS/CH* UPDATE, CR* megőrzéssel. Az osztály nincs módosítva. Az eredeti `release_stock` és a többi meglévő rutin változatlan; külön riportmunkamásolat, diff, textelemek és hat helyi ellenőrzés. Az osztály sikerjelzőjének hiánya és saját commitja miatti korlátok a [leírásban](03_DRAFTS/2026-10-21_release-stock-new-riport_WIP/README.md). A korábbi osztálybővítési irányt ez váltja fel.
- `03_DRAFTS/2026-10-18_sap-transport-qa_WIP/` — a `sap-transport-qa` skill telepített WIP-alapváltozatának helyi másolata és ellenőrzési jegyzőkönyve. [Skill](03_DRAFTS/2026-10-18_sap-transport-qa_WIP/sap-transport-qa/SKILL.md), [hiányzó adatok beszerzése](03_DRAFTS/2026-10-18_sap-transport-qa_WIP/sap-transport-qa/references/adatok-beszerzese.md). Személyes telepítés: `~/.codex/skills/sap-transport-qa`; aktuális SAP-variáns és élő QA-futás még nem ismert.
- `03_DRAFTS/2026-10-17_close-stock_WIP/` — a ZPR_CLOSE_STOCK hatpontos kérésének helyi megvalósítása: külön riport- és osztályváltozat, fordítható szövegek, változatlan include-ok, diff, ellenőrzési eredmények és átvezetési útmutató. Aktív SAP-átvezetés és futtatott SAP-teszt nélkül.
- `03_DRAFTS/2026-10-16_cockpit_WIP/` — a stock cockpit Enter-validációja, az első DM-fül riportadaptere és a QM minta fül stockkal előtöltött ZPR_QM-indítóképernyője (2026-10-18); külön forráscsomag, visszafordítható diff és átvezetési útmutató. Helyileg ellenőrzött WIP, aktív SAP-visszaolvasás és teszt nélkül. [QM-bekötés](03_DRAFTS/2026-10-18_cockpit-qm-minta_WIP.md). [QM-indítás és gombfelirat javítása](03_DRAFTS/2026-10-18_cockpit-qm-dynpro-gomb-javitas_WIP.md), a felhasználó ST22-részlete a cockpit környezetében futó `CALL SELECTION-SCREEN 2000` hívást megerősítette; a javított változat SAP-próbája még szükséges.
- `04_ASSETS/abap/` — megőrzött flow logic, üzenet-/textelemek és opcionális regisztráció; a korábbi 19 munkaforrás archiválva.
- `04_ASSETS/abap/test/` — WIP ABAP Unit-tesztinclude-ok.
- `04_ASSETS/playwright/` — automatizált OData API-tesztek.
- `04_ASSETS/rest-client/` — kézi `.http` hívások.
- `05_FINAL/` — kész eredmény (mielőtt `[04] outputs/`-ba kerül).
- `[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/` — a tegnapi 34 fájlos export, régi munkaprogramok, diagnosztika, jegyzetek és ideiglenes munkamentések. A `project/` almappa az eredeti projektútvonalakat, a `workspace-tmp/` az ideiglenes mentéseket őrzi; a konténer státusza ARCHIVED, az eredeti fájlnevek megmaradtak.
- `05_FINAL/abap-2026-10-17/` — ugyanazon 24 objektum új napi MCP-exportja, 34 fájl, WIP; minden mentés és SHA256 ellenőrizve. A mai `ZPR_DCQM_EXCLUDE_C01` új include-függőség a kért tegnapi objektumkörön kívül esik, ezért nincs benne. Egyik napi csomag sem teljes UI-/függőségmentés; a határokat a README-k/manifesztek rögzítik.
- `_LOG.md` — döntésnapló (ezt olvasd a folytatáshoz).
