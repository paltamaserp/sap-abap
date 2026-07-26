# Playwright — OData / webszerviz e2e tesztek

Automatizált API-tesztek a projekt Gateway/OData végpontjaira (`request` API,
nem böngésző). CI-be tehető, assertion-alapú.

## Váz

```
playwright/
├── playwright.config.ts        → baseURL a .env-ből, TLS, reporter, timeout
├── tsconfig.json               → strict TS a tesztekhez
├── package.json                → @playwright/test + dotenv, npm scriptek
├── .env.example                → minta env (titok NÉLKÜL) → másold .env-re
├── tests/IC_000_minta.spec.ts  → minta spec; egy .spec.ts szerviz/IC_xxx feladatonként
└── utils/sap.ts                → SAP helper: auth, sap-client, CSRF, OData unwrap
```

## Indulás

```
cd "[03] projects/<projekt>/04_ASSETS/playwright"
cp .env.example .env           # majd töltsd ki (host, user, jelszó, szerviz)
npm install
npm run test:list              # csak listázás (nincs hálózat)
npm test                       # összes teszt
npm run test:ui                # UI mód
npm run report                 # riport
```

VSCode-ból: **Terminal → Run Task…** → a task rákérdez a projekt mappanevére
(alap: `_TEMPLATE`). A `.vscode/tasks.json` cross-platform — macOS/Linux alatt a
rendszer `npm`-je fut, Windowson a portable Node 22 kerül a PATH-ra.

## Helper API (`utils/sap.ts`)

| Függvény | Mit ad |
|---|---|
| `sapEnv()` | `.env` beolvasás + hiányzó kulcs esetén beszédes hiba |
| `createSapContext()` | Basic auth + baseURL-re előkonfigurált `APIRequestContext` |
| `withClient(path)` | `sap-client` + `$format=json` rátoltése egy relatív path-ra |
| `fetchCsrf(ctx)` | CSRF token + session cookie (íráshoz kötelező) |
| `writeHeaders(csrf)` | POST/MERGE/DELETE headerek egy helyen |
| `odataResults(body)` | OData **V2** `{ d: { results } }` kicsomagolás |

> `odataResults` V2-re való. OData V4-nél a `value` kulcsot használd helyette.

## Konvenció

- **SAP hitelesítés / URL soha ne kerüljön verziókövetésbe** — `.env` (a helyi
  `.gitignore` tiltja, csak a `.env.example` verziózódik placeholderekkel).
- Egy `.spec.ts` egy szerviz vagy egy IC_xxx feladat.
- CSRF token GET-tel lekérve, POST/PUT/DELETE headerbe.
- **Író tesztek alapból `describe.skip`** — csak dedikált teszt-mandanton kapcsold be.
- `SAP_TLS_VERIFY=0` csak dev/qa önaláírt tanúsítványhoz, prod ellen soha.
