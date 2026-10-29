# TESZT- ÉS REVIEW-ESZKÖZÖK

Mi áll rendelkezésre ebben a munkaterületben teszteléshez és kódellenőrzéshez.
Három réteg: **ABAP objektum-teszt**, **HTTP/OData hívás**, **code review**.

---

## 1. ABAP objektum-teszt (ABAP Unit)

Az ABAP Unit teszt **a SAP rendszerben él**, nem a lemezen fut. A repóban lévő
`.abap` fájl csak export/verziózás.

### MCP tool-ok

A jelenlegi csatlakoztatott eszközcsalád `sap-abap-adt`. A célrendszert és a pontos paramétereket az aktuális eszközleírásból és projektállapotból kell azonosítani; a régi ECC/CRM eszköznevek nem igazolnak külön kapcsolatot.

| Tool | Mire |
|---|---|
| `CreateUnitTest` / `RunUnitTest` | tesztfutás indítása az aktuális eszközszerződés szerint; nem repository-tesztobjektum CRUD |
| `RunUnitTest` → `GetUnitTestStatus` → `GetUnitTestResult` | futtatás (**aszinkron** — a státuszt le kell kérdezni) |
| `CreateCdsUnitTest` | CDS-tesztosztály létrehozása, csak engedélyezett SAP-írás részeként; a futtatási eszközt külön ellenőrizd |
| `GetLocalTestClass` / `UpdateLocalTestClass` | beágyazott teszt-osztály a *Local Test Classes* include-ban |
| `RuntimeRunClass` / `RuntimeRunProgram` | ad-hoc futtatás (`...WithProfiling` változat is van) |

### Workflow új osztálynál

```
Engedélyezett létrehozás/módosítás → szintaxisellenőrzés
    → engedélyezett aktiválás → aktív visszaolvasás
    → releváns ABAP Unit befejezett eredménye → valódi QA-eredmény
```

### Konvenció

Részletek: `[03] projects/_TEMPLATE/05_FINAL/README.md`.

- **Beágyazott teszt az ajánlott** — a teszt-osztály a tesztelt objektum Local Test
  Classes include-jában. Egy objektum, egy transzport.
- `DURATION SHORT RISK LEVEL HARMLESS` alapból; DB-t érintő tesztnél emeld.
- DB-izoláláshoz Test Seam vagy interfész-mock.

---

## 2. HTTP hívás / OData tesztek

Két eszköz, minden projekt `04_ASSETS/` mappájában (a `_TEMPLATE`-ből öröklődik).

### REST Client — kézi, verziózott hívások

`humao.rest-client` VSCode extension. Minta: `04_ASSETS/rest-client/_TEMPLATE.http`

9 blokk: service document, `$metadata`, CSRF fetch, GET (set / kulcsos / `$filter`),
POST, MERGE, function import.

Titok: a repo gyökerében lévő `.env`-ből, `{{$dotenv SAP_URL}}` hivatkozással.
A `.env` gitignore-olt, csak a `.env.example` verziózódik.

Az auth egy közös `@auth` változóban (`Basic {{user}} {{pass}}`, **szóközzel** —
a `user:pass` forma változó-behelyettesítés után nem megbízható). Az író
blokkokba **nem írunk `Cookie:` sort**: a REST Client közös cookie jar-t tart.

### Playwright — automatizált API-tesztek

`request` API, nem böngésző. CI-be tehető. Mappa: `04_ASSETS/playwright/`

```
playwright.config.ts   → baseURL a .env-ből, TLS, reporter
tests/_TEMPLATE.spec.ts → minta; egy .spec.ts szerviz / feladatonként
utils/sap.ts           → auth, sap-client, CSRF, OData V2 unwrap
```

Futtatás:

```
cp .env.example .env      # majd töltsd ki
npm install
npm run test:list         # csak listázás, nincs hálózat
npm test                  # éles hívás
npm run typecheck         # tsc --noEmit
```

> **Két `.env` van, szándékosan:** a Playwright a saját
> `04_ASSETS/playwright/.env`-jét olvassa (projektenként más rendszer/mandant),
> a REST Client a repo gyökerében lévőt (ad-hoc kézi hívás).

VSCode-ból: **Terminal → Run Task…** — a task rákérdez a projekt mappanevére.
macOS/Linux alatt a rendszer `npm`-je fut. Windowson portable Node-hoz állítsd be
a **`SAP_NODE_PATH`** környezeti változót; ha nincs, a rendszer `npm`-je fut.

Élő böngészőhöz külön: `mcp__plugin_playwright_playwright__*` MCP tool-ok.

---

## 3. Code review eszközök

| Eszköz | Mi | Ki indítja |
|---|---|---|
| **`/abap-code-review`** | Automatikus utóellenőrzés és bizonyítékhoz kötött eredmény — a projekt saját skillje | létrehozás/módosítás/aktiválás után automatikusan |
| **Szintaxis** (`CheckClass`, `CheckProgram`, `CheckPackage`…) | SAP-szintaxisellenőrzés; **nem teljes ATC** | MCP hívás |
| **ATC / SCI / Onapsis** | A tényleges rendszerrel, variánssal és objektumkörrel igazolandó QA-kapu | dedikált futtató, ha elérhető; különben azonosítható átadott futáseredmény |
| `/code-review` | helyi branch-diff review | te |
| `/code-review ultra` | multi-agent cloud review (branch v. PR#) | **kizárólag te — billed, én nem hívhatom** |
| `/security-review` | biztonsági review a branch változásain | te |
| `/simplify` | egyszerűsítés / reuse cleanup (nem bug-vadászat) | te |
| `/caveman-review` | tömörített PR-komment stílus | te |
| `GetAbapSemanticAnalysis`, `GetAbapAST`, `GetWhereUsed` | ABAP statikus elemzés, impact-check | MCP |
| `Get*VersionDiff` | verzió-diff a SAP-ban (osztály, program, DDL, tábla…) | MCP |

### A projekt kapuja: `/abap-code-review`

Skill: `.claude/skills/abap-code-review/SKILL.md`, a gyökér AGENTS.md utasítása alapján közvetlenül olvasandó.

Sikerfeltételek és hatókör: [ABAP-AUTO-CHECK.md](ABAP-AUTO-CHECK.md). A menet szintaxisellenőrzésből, engedélyezett aktiválás utáni visszaolvasásból, releváns Unit-eredményből és külön QA-eredményből áll. A `Check*` lépés nem ATC. Új tesztkód írása SAP-ba és aktiválás csak az adott feladat felhatalmazásával történhet.

A `/security-review` és `/simplify` **nem része** a kapunak — külön, igény szerint.

Rendszerválasztás: a felhasználó és az aktuális projekt alapján; hiányzó SID-et vagy mandantot nem találgatunk. Egy futáson belül rendszereket nem keverünk. Az első hitelesítési/kapcsolati hiba vagy timeout után **stop és jelzés**, nincs automatikus retry.

**Trigger: automatikus**, a felhasználó 2026-10-27-i kérése szerint. Az asszisztens minden engedélyezett ABAP-létrehozás/-módosítás/-aktiválás után, mentési csomagonként végrehajtja a menetet és összesíti az eredményt. Ez nem SAP-háttérjob és nem általános IDE-mentési hook. A teljes QA-futtató jelenleg nem része az MCP-eszközkészletnek; hiányában az összeredmény RÉSZLEGES, nem teljes siker.

---

## Gyors döntési segédlet

| Mit akarsz | Eszköz |
|---|---|
| ABAP logika helyes-e | ABAP Unit (`/abap-code-review`) |
| Kód megfelel-e a guideline-nak | ATC (`/abap-code-review`) |
| Él-e a szerviz, jó-e az auth | REST Client `.http`, 1–2. blokk |
| OData végpont regressziómentes-e | Playwright `npm test` |
| Egy hívást gyorsan kipróbálni | REST Client |
| Mi változott az előző verzióhoz | `Get*VersionDiff` |
| Kit érint a módosításom | `GetWhereUsed` |
