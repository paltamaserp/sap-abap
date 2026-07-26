# REST Client — kézi / verziózott OData hívások

VSCode **REST Client** extension (`humao.rest-client`). Verziózható `.http`
fájlok a Gateway/OData végpontok kézi teszteléséhez — gyorsabb, mint a Playwright,
ismételhető, mint a Postman, de a repóban él.

## Váz

```
rest-client/
├── IC_000_minta.http        → kiindulási minta (másold át, ne ezt szerkeszd)
└── IC_00x_<szerviz>.http    → egy .http feladatonként/szervizenként
```

A titkokat a **repo gyökerében** lévő `.env` adja (`.env.example` a minta) —
a `.http` fájlok `{{$dotenv SAP_URL}}` formában hivatkoznak rá.

## Használat

1. Telepítsd a `humao.rest-client` extensiont.
2. A repo gyökerében: `cp .env.example .env`, majd töltsd ki.
3. Másold az `IC_000_minta.http`-t a saját feladatod nevére, írd át a `@srv` értéket.
4. Nyisd a `.http` fájlt → minden kérés fölött **"Send Request"** link.

## Mit tartalmaz a minta

| Blokk | Mire jó |
|---|---|
| 1) service document | él-e a szerviz, jó-e az auth |
| 2) `$metadata` | entitások, property-k, kulcs-formátum ellenőrzése |
| 3) CSRF fetch | `# @name csrf` — a token/cookie forrása az íráshoz |
| 4–6) GET | EntitySet, kulcsos olvasás, `$filter` / `$orderby` / `$top` |
| 7) POST | létrehozás — a 3) blokkot **előbb** kell elküldeni |
| 8) MERGE | OData V2 részleges update |
| 9) function import | GET vagy POST a `$metadata` `m:HttpMethod` szerint |

## Konvenció

- **Host / user / jelszó SOHA a `.http`-be** — csak `{{$dotenv ...}}` hivatkozás.
  A `.env` gitignore-olt, csak a `.env.example` verziózódik placeholderekkel.
- Egy `.http` egy szerviz vagy egy IC_xxx feladat.
- Író hívás előtt mindig futtasd a CSRF blokkot — nélküle **403 CSRF token validation failed**.
