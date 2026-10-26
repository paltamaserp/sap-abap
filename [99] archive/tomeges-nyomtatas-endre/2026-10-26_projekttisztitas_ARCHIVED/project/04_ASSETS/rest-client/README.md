# REST Client — kézi / verziózott OData hívások

VSCode **REST Client** extension (`humao.rest-client`). Verziózható `.http`
fájlok a Gateway/OData végpontok kézi teszteléséhez — gyorsabb, mint a Playwright,
ismételhető, mint a Postman, de a repóban él.

## Váz

```
rest-client/
├── _TEMPLATE.http                 → kiindulási minta (másold át, ne ezt szerkeszd)
└── <feladatkód>_<szerviz>.http    → egy .http feladatonként/szervizenként
```

A titkokat a **repo gyökerében** lévő `.env` adja (`.env.example` a minta) —
a `.http` fájlok `{{$dotenv SAP_URL}}` formában hivatkoznak rá.

> **Két `.env` van, szándékosan.** A REST Client a **repo gyökerében** lévőt
> olvassa (kézi, ad-hoc hívás — jellemzően ugyanaz a rendszer minden projekten),
> a Playwright a saját `04_ASSETS/playwright/.env`-jét (projektenként más
> rendszert/mandantot célozhat). Mindkettő gitignore-olt.

## Használat

1. Telepítsd a `humao.rest-client` extensiont.
2. A repo gyökerében: `cp .env.example .env`, majd töltsd ki.
3. Másold a `_TEMPLATE.http`-t a saját feladatod nevére.
4. Küldd el a 2) `$metadata` blokkot, és abból töltsd ki a fájl tetején lévő
   `@srv` / `@entity` / `@key` értékeket és a lenti `<Mezo>` placeholdereket.
5. Nyisd a `.http` fájlt → minden kérés fölött **"Send Request"** link.

## Mit tartalmaz a minta

| Blokk | Mire jó |
|---|---|
| 1) service document | él-e a szerviz, jó-e az auth |
| 2) `$metadata` | entitások, property-k, kulcs-formátum ellenőrzése |
| 3) CSRF fetch | `# @name csrf` — a token forrása az íráshoz |
| 4–6) GET | EntitySet, kulcsos olvasás, `$filter` / `$orderby` / `$top` |
| 7) POST | létrehozás — a 3) blokkot **előbb** kell elküldeni |
| 8) MERGE | OData V2 részleges update |
| 9) function import | GET vagy POST a `$metadata` `m:HttpMethod` szerint |

## Konvenció

- **Host / user / jelszó SOHA a `.http`-be** — csak `{{$dotenv ...}}` hivatkozás.
  A `.env` gitignore-olt, csak a `.env.example` verziózódik placeholderekkel.
- Az auth egy közös `@auth` változóban van (`Basic {{user}} {{pass}}`, **szóközzel**
  elválasztva — a `user:pass` forma változó-behelyettesítés után nem megbízható).
- Egy `.http` egy szerviz vagy egy `<feladatkód>` feladat. A feladatkód
  formátumát a projekt `00_BRIEF.md`-je adja meg.
- A `_TEMPLATE.http` csupa `<…>` placeholdert tartalmaz — **másolás után
  mindet ki kell tölteni**, addig a kérések nem futnak le. Ez szándékos.
- Író hívás előtt mindig futtasd a CSRF blokkot — nélküle **403 CSRF token validation failed**.
- **`Cookie:` sort nem írunk** az író blokkokba: a REST Client közös cookie jar-t
  tart, a session cookie automatikusan megy. (Ha a jar ki van kapcsolva, a válasz
  `Set-Cookie` fejlécéből csak a `név=érték` részt másold — az attribútumokat nem.)
