# _TEMPLATE — így indíts új projektet

Ez a mappa a **váz**, nem projekt. Ne szerkeszd — másold.

---

## Checklist

**1. Másolás** — a generált mappák nélkül (az új projektben friss `npm install`
kell, és nem akarunk idegen rendszer teszt-riportjával indulni):

```
cd "[03] projects"
rsync -a \
  --exclude node_modules \
  --exclude playwright-report \
  --exclude test-results \
  --exclude .DS_Store \
  _TEMPLATE/ <projekt-nev>/
```

A `<projekt-nev>` kebab-case, ékezet nélkül. (`cp -R` is jó, de utána töröld a
fenti mappákat — a `npm test` / `npm run test:list` újragenerálja őket a
`_TEMPLATE`-ben is.)

**2. `00_BRIEF.md` kitöltése** — cél, miért, „kész" kritérium, érintett SAP
objektumok, és a Kulcs-konvenciók táblázat (**rendszer: ECC vagy CRM**, csomag,
transport, ATC variant).

**3. `_LOG.md` első bejegyzés** — a „Jelen állás" blokk kitöltése. Innentől ez a
projekt egyetlen állapot-forrása; minden döntés a „Döntés:" szóval ide kerül.

**4. Playwright env** (ha lesz OData teszt):

```
cd "<projekt-nev>/04_ASSETS/playwright"
cp .env.example .env      # majd töltsd ki
npm install
```

**5. REST Client env** (ha még nincs) — a **repo gyökerében**:

```
cp .env.example .env
```

> A két `.env` szándékosan külön: a Playwright projektenként más
> rendszert/mandantot célozhat, a REST Client ad-hoc kézi hívás. Mindkettő
> gitignore-olt.

**6. Smoke** — hálózat nélkül futtatható, azt ellenőrzi, hogy a váz ép:

```
npm run typecheck      # tsc --noEmit
npm run test:list      # a specek betöltődnek, nincs SAP-hívás
```

**7. ABAP objektum módosítása után:** `/abap-code-review` (ATC + ABAP Unit kapu).
Az eredmény a `_LOG.md` „Teszt / Review" blokkjába kerül.

---

## Mi hova megy

| Mappa | Mit |
|---|---|
| `01_SOURCES/` | bemenetek: dump, ADT export, dokumentáció |
| `02_NOTES/` | munkajegyzetek |
| `03_DRAFTS/` | WIP verziók, iterációk |
| `04_ASSETS/abap/` | **WIP** `.abap` export (verziózáshoz) |
| `04_ASSETS/playwright/` | automatizált OData API-tesztek |
| `04_ASSETS/rest-client/` | kézi, verziózott `.http` hívások |
| `05_FINAL/` | **kész** ABAP objektum, kiajánlás előtt |
| `_LOG.md` | döntésnapló — ezt olvasd a folytatáshoz |

Kész munka útja: `04_ASSETS/abap/` → `05_FINAL/` → jóváhagyás után `[04] outputs/`.

Fájlnév-konvenció, státuszok: `[01] system/NAMING.md`, `[01] system/STATUS.md`.
Teszt- és review-eszközök: `[01] system/TESTING-TOOLS.md`.
