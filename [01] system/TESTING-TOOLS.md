# TESZT- ÉS REVIEW-ESZKÖZÖK

Mi áll rendelkezésre ebben a munkaterületben teszteléshez és kódellenőrzéshez.
Három réteg: **ABAP objektum-teszt**, **HTTP/OData hívás**, **code review**.

---

## 1. ABAP objektum-teszt (ABAP Unit)

Az ABAP Unit teszt **a SAP rendszerben él**, nem a lemezen fut. A repóban lévő
`.abap` fájl csak export/verziózás.

### MCP tool-ok

Mindkét rendszeren elérhető (`mcp__sap-ecc-dev__*`, `mcp__sap-crm-dev__*`):

| Tool | Mire |
|---|---|
| `CreateUnitTest` / `GetUnitTest` / `UpdateUnitTest` / `DeleteUnitTest` | teszt-objektum kezelés |
| `RunUnitTest` → `GetUnitTestStatus` → `GetUnitTestResult` | futtatás (**aszinkron** — a státuszt le kell kérdezni) |
| `CreateCdsUnitTest` / `GetCdsUnitTestResult` | CDS view tesztek |
| `GetLocalTestClass` / `UpdateLocalTestClass` | beágyazott teszt-osztály a *Local Test Classes* include-ban |
| `RuntimeRunClass` / `RuntimeRunProgram` | ad-hoc futtatás (`...WithProfiling` változat is van) |

### Workflow új osztálynál

```
CreateClass → UpdateClass → CheckClass → ActivateClass
            → UpdateLocalTestClass → RunUnitTest
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

`humao.rest-client` VSCode extension. Minta: `04_ASSETS/rest-client/IC_000_minta.http`

9 blokk: service document, `$metadata`, CSRF fetch, GET (set / kulcsos / `$filter`),
POST, MERGE, function import.

Titok: a repo gyökerében lévő `.env`-ből, `{{$dotenv SAP_URL}}` hivatkozással.
A `.env` gitignore-olt, csak a `.env.example` verziózódik.

### Playwright — automatizált API-tesztek

`request` API, nem böngésző. CI-be tehető. Mappa: `04_ASSETS/playwright/`

```
playwright.config.ts   → baseURL a .env-ből, TLS, reporter
tests/*.spec.ts        → egy .spec.ts szerviz / IC_xxx feladatonként
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

VSCode-ból: **Terminal → Run Task…** — a task rákérdez a projekt mappanevére.
Cross-platform (macOS/Linux `npm`, Windowson portable Node 22 a PATH-ra).

Élő böngészőhöz külön: `mcp__plugin_playwright_playwright__*` MCP tool-ok.

---

## 3. Code review eszközök

| Eszköz | Mi | Ki indítja |
|---|---|---|
| **`/abap-code-review`** | **ATC + ABAP Unit kapu** — a projekt saját skillje | én felajánlom, te vagy én futtatom |
| **ATC** (`CheckClass`, `CheckProgram`, `CheckPackage`, `CheckDdl`…) | SAP statikus ellenőrzés; az oneERP guideline szerint **kötelező** quality gate kiajánlás előtt | MCP hívás |
| `/code-review` | helyi branch-diff review | te |
| `/code-review ultra` | multi-agent cloud review (branch v. PR#) | **kizárólag te — billed, én nem hívhatom** |
| `/security-review` | biztonsági review a branch változásain | te |
| `/simplify` | egyszerűsítés / reuse cleanup (nem bug-vadászat) | te |
| `/caveman-review` | tömörített PR-komment stílus | te |
| `GetAbapSemanticAnalysis`, `GetAbapAST`, `GetWhereUsed` | ABAP statikus elemzés, impact-check | MCP |
| `Get*VersionDiff` | verzió-diff a SAP-ban (osztály, program, DDL, tábla…) | MCP |

### A projekt kapuja: `/abap-code-review`

Skill: `.claude/skills/abap-code-review/SKILL.md` (session-újraindítás után aktív).

Két lépcső, tudatosan **csak ez a kettő**:

1. **ATC** — objektumtípus szerinti `Check*`. Aktiválatlan objektum előbb `Activate*`
   (az ATC az aktív verziót nézi). Error → javítás, és csak utána 2. lépcső.
2. **ABAP Unit** — `GetLocalTestClass` → ha nincs és a logika érdemi, írj egyet →
   `RunUnitTest` → státusz → eredmény.

A `/security-review` és `/simplify` **nem része** a kapunak — külön, igény szerint.

Rendszerválasztás: alapból **ECC**, CRM csak kimondásra. Egy futáson belül a két
rendszert nem keverjük. Auth hibánál: **stop és jelzés**, nem retry.

**Trigger: még nyitott.** Egyelőre manuális hívás. Az első éles próba után dől el,
legyen-e automatikus (minden aktiválás után vs. csak `05_FINAL/`-ba kerüléskor).

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
