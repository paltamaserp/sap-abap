# Playwright — OData / webszerviz e2e tesztek

Automatizált API-tesztek a projekt Gateway/OData végpontjaira (`request` API,
nem böngésző). CI-be tehető, assertion-alapú.

## Váz

```
playwright/
├── playwright.config.ts     → baseURL, auth, reporter
├── tests/*.spec.ts          → egy .spec.ts szerviz-endpointonként (pl. IC_002_accounts.spec.ts)
├── utils/sap.ts             → közös SAP helper: CSRF token, alap auth, headerek
└── package.json             → @playwright/test függőség
```

## Indulás

```
cd 04_ASSETS/playwright
npm install
npx playwright test           # összes teszt
npx playwright test --list     # csak listázás (nincs hálózat)
npx playwright test --ui       # UI mód
npx playwright show-report     # riport
```

## Konvenció

- **SAP hitelesítés / URL soha ne kerüljön verziókövetésbe** — `.env` (a repo gyökér
  `.gitignore` már tiltja). `playwright.config.ts` env-ből olvassa a baseURL-t és
  a credentialt.
- Egy `.spec.ts` egy szerviz vagy egy IC_xxx feladat.
- CSRF token GET-tel lekérve, POST/PUT/DELETE headerbe.

> macOS-en `npx`, Windowson `npx.cmd`. A `.vscode/tasks.json` a Windows-változatot
> használja — macOS alatt terminálból futtasd, vagy igazítsd a taskot.
