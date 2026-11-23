# CLAUDE.md — SAP ABAP workspace (ECC + CRM, on-premise, E.ON)

Magyar nyelven dolgozunk: válaszok és dokumentáció magyarul; kód-komment a kódbázis konvenciója szerint
(production ABAP-ban angolul, oneERP guideline).

Ez **nem build-elhető kódbázis**, hanem dokumentum- és forrásmentés-alapú munkaterület: az ABAP-objektumok
a SAP-rendszerben élnek, a repóban csak exportok, draftok, bizonyítékok és naplók vannak. Nincs gyökérszintű
build vagy lint; tesztek csak a projekt-asset szinten (Playwright) és a review-skill segédjénél vannak.

## Session indulásakor
1. Olvasd be a `_START-HERE.md`-t (térkép + olvasási sorrend + aktív projektek táblája).
2. Ha konkrét projekten dolgozunk, ELŐSZÖR olvasd be annak `00_BRIEF.md` és `_LOG.md`
   fájlját, és onnan folytasd.
   **IMPORTANT: a projekt állását soha ne találgasd — a `_LOG.md` az egyetlen forrás.**
3. A részletes konvenciókat csak akkor töltsd be, amikor kellenek:
   `[01] system/RULES.md` (viselkedés), `NAMING.md`, `STATUS.md`, `SYSTEM-RULES.md` (struktúra-karbantartás),
   `ABAP-QA-CHECKLIST.md` (ABAP-forrás írása előtt kötelező), `ABAP-AUTO-CHECK.md`, `TESTING-TOOLS.md`.
4. Az `AGENTS.md` (gyökér) a SAP-kapcsolat és az utóellenőrzés szabályait rögzíti — ugyanúgy kötelező.

## Mindig érvényes szabályok
- **Fájlnév:** `ÉÉÉÉ-HH-NN_téma_STÁTUSZ.kiterjesztés`; a téma kötőjeles, ékezet nélkül.
  Kivétel: SAP-ból tükrözött forrás a SAP-objektumnevet viseli (`ZCL_….abap`), és nem nevezhető át.
- **Státusz kizárólag:** `WIP` · `REVIEW` · `FINAL` · `ARCHIVED`. Új fájl alapból `WIP`.
  Státuszt csak kifejezett kérésre vagy a brief „kész” kritériumának teljesülésekor léptess.
- **YOU MUST: `FINAL` fájlt soha ne írj felül csendben** — kérdezz rá, vagy nyiss új
  verziót új dátummal, a régit pedig told `ARCHIVED`-be.
- Döntés született? Írd be a projekt `_LOG.md`-jébe (a „Döntés:” szóval), és frissítsd
  a napló tetején a „Jelen állás” blokkot.
- Kész munka: `05_FINAL/` → jóváhagyás után `[04] outputs/`.
  Nyers/rendezetlen fájl a `[00] inbox/`-ba kerül, és nem marad ott.
- Átszervezés (mappa létrehozás/törlés/átnevezés) után frissítsd a `_START-HERE.md`-t.
  Új projekt mindig a `[03] projects/_TEMPLATE/` másolatával indul. Elavult anyag `[99] archive/`-ba
  kerül, nem törlődik.
- Titok (SAP jelszó, token) soha nem kerül markdownba vagy verziókövetésbe; `.env*` gitignore-olt,
  csak a `.env.example` követett.

## SAP-kapcsolat (kritikus)
- **Elsődleges eszköz (2026-10-29-i döntés):** az **ABAP Development Tools for VS Code**
  (`SAPSE.adt-vscode`) bővítmény saját ADT MCP Servere (`.vscode/settings.json`:
  `adt.mcpServer.enabled = true`). A korábbi `sap-abap-adt` MCP (`fr0ster/mcp-abap-adt`) a
  `.codex/config.toml`-ban `enabled = false` — csak kifejezett kérésre engedélyezhető újra.
- **Fail-stop szabály (2026-10-13):** az első sikertelen SAP-elérés (HTTP 401, kapcsolati hiba,
  timeout) után az érintett kapcsolatot **ne használd tovább**: nincs automatikus retry, másik
  SAP-eszköz vagy kerülőút; ez a következő sessionökre is érvényes. Új próba csak a felhasználó
  kifejezett kérésére, egyszer. Helyi exportból folytatható a munka, az ellenőrizetlen aktív
  SAP-állapot jelzésével. Az aktuális kapcsolati állapotot a projekt `_LOG.md`-je rögzíti.
- Automatikus jóváhagyás elutasítása nem SAP-válasz — külön, pontosan jelezd.
- SAP-írás vagy aktiválás csak az adott feladatban kapott felhatalmazással; módosítás után az aktív
  állapotot olvasd vissza, és a lokális `.abap` másolatot tartsd szinkronban.
- A gyökér `.mcp.json` (`sap-crm-dev`, `sap-ecc-dev`) régi macOS-útvonalakra mutat, ezen a
  Windows-gépen nem indul — nem érvényes SAP-hozzáférési út.

## ABAP környezet
- ECC/CRM-kompatibilis kód: **nincs template string**, explicit típusozás, régebbi
  runtime — mindig a meglévő kódbázis stílusát kövesd.
- Meglévő funkció bővítésénél inkább bővítsd a logikát, mint átírd (kisebb regressziós
  kockázat). Sebészi változtatás: szomszédos kódot ne „javíts”, halott kódot jelezz, ne törölj.
- ABAP-forrás írása előtt alkalmazd az `[01] system/ABAP-QA-CHECKLIST.md`-t (fordítható MESSAGE-szöveg
  textelemben/T100-ban, SORTED/HASHED táblához `INSERT … INTO TABLE`, indexhez illő WHERE a kiválasztás
  üzleti hatókörének szűkítése nélkül).
- Mérvadó guideline: `[02] context/oneERP ABAP Development Guideline_V 22 00 published.pdf`
  (névkonvenció, kódolási szabvány, architektúra).

## ABAP: új osztályhoz mindig lokális unit teszt
- Ha új globális osztályt hozol létre (ZCL_*), ugyanabban a lépésben hozd létre
  a lokális tesztosztályt is az osztály teszt-includjában (ADT: „Test Classes” fül,
  SE24: Local Test Classes / CCAU). A teszt **egybe kerül az osztállyal** (ugyanaz
  az objektum, együtt aktiválódik és transzportálódik) — ne hozz létre külön globális
  tesztosztályt (pl. `ZCL_*_TEST`).
- Forma: `CLASS ltc_<téma> DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS
  DURATION SHORT.` — a vizsgált osztály `mo_cut` példányként, `setup` metódusban jön létre.
- Minden publikus metódusra legalább egy teszt: normál eset + legalább egy hibaág /
  szélsőérték. Ellenőrzés `cl_abap_unit_assert=>assert_equals` / `assert_bound` /
  `fail` hívással, érthető `msg`-gel.
- Nincs DB-írás, COMMIT vagy külső hívás a tesztben; a függőségeket interfészen
  keresztül add át, és a tesztben test double-lel helyettesítsd.
- ECC/CRM-kompatibilis szintaxis (nincs template string, explicit típusozás),
  a meglévő kódbázis stílusában.
- Meglévő osztály módosításakor a meglévő tesztosztályt bővítsd, ne írd újra.
- Létrehozás után futtasd az ABAP Unitot (MCP-n / `/abap-code-review`), és jelezd
  az eredményt; piros teszttel ne jelentsd késznek.
- Kézi futtatás: ADT-ben `Ctrl+Shift+F10` (coverage-dzsel `Ctrl+Shift+F11`),
  SAP GUI SE24/SE80-ban `Ctrl+Shift+F10`.

## Automatikus ABAP-utóellenőrzés
ABAP-objektum létrehozása/módosítása/aktiválása után, külön kérés nélkül, mentési csomagonként egyszer:
szintaxis (`Check*`) → aktív visszaolvasás → ABAP Unit (`RunUnitTest` → `GetUnitTestStatus` →
`GetUnitTestResult`, aszinkron) → QA (ATC/SCI/Onapsis). Részletek: `[01] system/ABAP-AUTO-CHECK.md`,
`.claude/skills/abap-code-review/SKILL.md`.
- A sikerfeltételeket a munka **elején** nevezd meg; az eredmény objektumonként `SIKERES` / `RÉSZLEGES`
  / `HIBÁS` (ez vizsgálati eredmény, nem projektstátusz).
- `Check*` = szintaxisellenőrzés, **nem ATC**. Dedikált QA-futtató jelenleg nincs → QA „nem futott”,
  így az összesítés legfeljebb RÉSZLEGES. Nem futott lépés nem siker; tesztkód megléte nem futási eredmény.
- Bizonyíték: projekt `04_ASSETS/validation/<dátum>_<téma>_WIP/` (MCP-válaszok, források, `jelentés.json`),
  hitelesítési adat nélkül; az eredmény a `_LOG.md`-be is bekerül.

## Parancsok
- **Összesítés-ellenőrző (nem SAP-futtató):**
  `python .claude/skills/abap-code-review/scripts/validate_report.py <jelentés.json>` — kilépési kód
  0 = SIKERES, 2 = RÉSZLEGES, 1 = HIBÁS/hibás bemenet.
  Saját tesztjei: `python -m unittest test_validate_report` a `scripts/` mappából.
  Figyelem: ezen a gépen a `python.exe` a WindowsApps stub, és korábban nem volt futtatható —
  ha nem indul, „nem futott”-ként rögzítsd.
- **Playwright OData API-tesztek** (projektenként, `04_ASSETS/playwright/`; saját `.env` a mappában):
  `npm install` · `npm run typecheck` · `npm run test:list` (hálózat nélkül) · `npm test` (éles hívás) ·
  egy spec: `npx playwright test tests/<név>.spec.ts`.
- **REST Client** (`humao.rest-client`): `04_ASSETS/rest-client/*.http`, a repo gyökerében lévő `.env`
  (`SAP_URL`, `SAP_CLIENT`, `SAP_USERNAME`, `SAP_PASSWORD`) alapján.
- **Shell-csapda:** a `[NN] …` mappanevekben a szögletes zárójel PowerShellben wildcard — használj
  `-LiteralPath`-ot (vagy Bash-t idézőjelezett útvonallal).

## Térkép (rövid)
`[00] inbox` · `[01] system` · `[02] context` · `[03] projects` · `[04] outputs` · `[99] archive`
Projektváz: `00_BRIEF.md` · `01_SOURCES/` · `02_NOTES/` · `03_DRAFTS/` · `04_ASSETS/`
(`abap/`, `playwright/`, `rest-client/`, `validation/`) · `05_FINAL/` · `_LOG.md`.
Egyéb: `.history/` (VS Code Local History), `.tmp/`, `tmp/` — munkaanyag, nem forrás.
Részletek és olvasási sorrend: `_START-HERE.md`.

Aktív projektek (állapotuk a saját `_LOG.md`-jükben):
- `tomeges-nyomtatas-endre` — tömeges nyomtatás (ZPR_* cockpit, DOC_STATUS, DC/QM); munkabázis:
  `05_FINAL/abap-2026-10-26/` (39 objektum MCP-mentése), régebbi exportok `[99] archive/`-ban.
- `zcl-pr-address-review` — a meglévő `ZCL_PR_ADDRESS` osztály (ZPR_FUNC) ellenőrzése.


## A projekt áttekintése
Ez a munkaterület a **CS HANA ICP** projekt számára készült — ez egy SAP HANA-alapú ügyfélszolgálati / ICP-kezdeményezés,
amely ABAP-fejlesztést alkalmaz. Feladatkövetés: ClickUp.

ABAP-kód írásakor vagy ellenőrzésekor a névkonvenciók, kódolási szabványok és architektúra-minták
tekintetében olvasd el a `[02] context/oneERP ABAP Development Guideline_V 22 00 published.pdf` dokumentumot.

## Skillek
A `.claude/skills/` alatt élnek (session-újraindítás után aktiválódnak); nem keverendők a `[NN]` tartalmi fával:
- `saphana-abap-hana-guidelines` — általános ABAP / HANA / ADT munka, az oneERP guideline-nal.
- `sap-developer-skillset` — SAP Gateway / OData, CRM / IS-U kompetenciák és a portál-projekt konvenciói.
- `sap-abap`, `sap-abap-cds` — általános ABAP-, illetve CDS-referencia.
- `abap-code-review` — minőségi kapu ABAP objektumokra: **szintaxis + aktív visszaolvasás + ABAP Unit
  + QA**, MCP-n futtatva. Hívás: `/abap-code-review`. ABAP objektum módosítása után automatikusan fut.
  (`/code-review ultra` billed és kizárólag a felhasználó indítja — soha ne hívd.)
