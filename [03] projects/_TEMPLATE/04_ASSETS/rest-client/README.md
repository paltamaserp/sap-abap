# REST Client — kézi / verziózott OData hívások

VSCode **REST Client** extension (`humao.rest-client`). Verziózható `.http`
fájlok a Gateway/OData végpontok kézi teszteléséhez — gyorsabb, mint a Playwright,
ismételhető, mint a Postman, de a repóban él.

## Váz

```
rest-client/
├── IC_00x_<szerviz>.http     → egy .http feladatonként/szervizenként
└── http-client.env.json       → környezetek (dev/qa), de titok NÉLKÜL
```

## Használat

1. Telepítsd a `humao.rest-client` extensiont.
2. Nyisd a `.http` fájlt → minden kérés fölött **"Send Request"** link.
3. Környezet váltás: jobb alul a REST Client env-választó.

## Minta `.http`

```http
@baseUrl = https://{{host}}/sap/opu/odata/sap/ZEPT_..._SRV
@auth = Basic {{user}} {{pass}}

### CSRF token lekérés (GET)
GET {{baseUrl}}/
Authorization: {{auth}}
X-CSRF-Token: Fetch

### Entity olvasás
GET {{baseUrl}}/AccountSet?$top=5&$format=json
Authorization: {{auth}}

### Létrehozás (POST) — token az elozo valaszbol
POST {{baseUrl}}/AccountSet
Authorization: {{auth}}
X-CSRF-Token: {{csrfToken}}
Content-Type: application/json

{ "Field": "value" }
```

## Konvenció

- **Host / user / jelszó SOHA a `.http`-be** — `http-client.env.json`-ba vagy env-be,
  és az kimarad a gitből. Csak placeholder (`{{host}}`, `{{user}}`) verziózódik.
- Egy `.http` egy szerviz vagy egy IC_xxx feladat.
