---
name: abap-code-review
description: ABAP minőségi kapu (ATC + ABAP Unit) SAP objektumokra ECC/CRM rendszeren. Használd, amikor ABAP objektum (osztály, report, függvénymodul, CDS, tábla) írása vagy módosítása után ellenőrizni kell a kódot, vagy amikor a felhasználó review-t, ATC-t, unit tesztet, "kész van?"-t vagy kiajánlás előtti ellenőrzést kér.
---

# ABAP Code Review — ATC + ABAP Unit kapu

Kétlépcsős minőségi kapu SAP objektumokra. **Statikus ellenőrzés (ATC), majd unit teszt (AUnit).**
Mindkettő a SAP rendszerben fut, ADT MCP-n keresztül — nem a lemezen.

## Mikor fut

- ABAP objektum írása / módosítása / aktiválása után.
- Ha a felhasználó ezt kéri: "review", "ATC", "unit teszt", "ellenőrizd", "kész van?".
- `05_FINAL/`-ba kerülés vagy kiajánlás előtt.

Nem ez a skill dolga: Playwright / REST Client OData tesztek (azok a projekt
`04_ASSETS/` mappájában élnek, lásd az ottani README-ket).

## Melyik rendszer

**IMPORTANT: jelzés nélkül minden MCP hívás ECC-be megy** (`mcp__sap-ecc-dev__*`).
CRM-be csak akkor, ha a felhasználó kimondja ("CRM"). Alias: "portál" / "prod" /
"IS-U" = ECC. Ha a review tárgya CRM objektum, a **teljes** láncot CRM-en futtasd
(`mcp__sap-crm-dev__*`) — ne keverd a két rendszert egy futáson belül.

Auth hiba esetén **állj meg és szólj** — ne próbálkozz újra.

---

## 1. lépcső — ATC (statikus ellenőrzés)

Az oneERP guideline szerint kötelező quality gate. Objektumtípusonként külön tool:

| Objektum | Tool |
|---|---|
| Osztály | `CheckClass` |
| Interfész | `CheckInterface` |
| Report / program | `CheckProgram` |
| Függvénymodul | `CheckFunctionModule` |
| Függvénycsoport | `CheckFunctionGroup` |
| CDS / DDL | `CheckDdl` |
| Tábla | `CheckTable` |
| Struktúra | `CheckStructure` |
| Data element / domain | `CheckDataElement` / `CheckDomain` |
| Egész csomag | `CheckPackage` |

**Menet:**

1. Futtasd a tárgyobjektum megfelelő `Check*` tool-ját.
2. Ha az objektum aktiválatlan → előbb `Activate*`, mert az ATC az aktív verziót nézi.
3. Ha több objektumot érintett a munka, mindegyikre futtasd — vagy `CheckPackage` a
   csomag egészére.

**Kiegészítő elemzés**, ha a Check eredménye nem elég beszédes vagy nagyobb átalakítás történt:

- `GetAbapSemanticAnalysis` — szemantikai problémák.
- `GetWhereUsed` — a módosított metódus/objektum hívói; regressziós kockázat.
- `Get*VersionDiff` — mi változott az előző aktív verzióhoz képest.

**Eredmény kezelése:**

- Error → **javítsd**, majd futtasd újra. Ne menj tovább a 2. lépcsőre.
- Warning → értékeld egyenként. Ami a guideline-t sérti, javítsd. Amit tudatosan
  hagysz benne, azt írd meg a felhasználónak indoklással.
- Ne hallgass el találatot, és ne minősítsd "lényegtelennek" ellenőrzés nélkül.

---

## 2. lépcső — ABAP Unit

Az AUnit teszt a SAP rendszerben él. A repóban lévő `.abap` fájl csak export/verziózás.

**Menet:**

1. `GetLocalTestClass` — van-e már beágyazott teszt-osztály a tárgyobjektumon.
2. Ha nincs és a logika érdemi (nem puszta getter/DTO): írj egyet
   `UpdateLocalTestClass`-szal. Konvenció a `_TEMPLATE/05_FINAL/README.md`-ben:
   `CLASS ltc_<nev> DEFINITION FOR TESTING DURATION SHORT RISK LEVEL HARMLESS`.
3. `RunUnitTest` → `GetUnitTestStatus` → `GetUnitTestResult`.
   **A futás aszinkron** — a státuszt kérdezd le, ne feltételezd hogy kész.
4. CDS-nél: `CreateCdsUnitTest` / `GetCdsUnitTestResult`.

**Ha nincs értelmes teszt** (pl. tisztán DDIC-változás, vagy a logika nem izolálható
DB nélkül), azt **mondd ki nyíltan** — ne generálj látszat-tesztet, ami mindig zöld.

**Eredmény kezelése:**

- Bukó teszt → először értsd meg, a teszt rossz vagy a kód. Ne a tesztet igazítsd
  a hibás kódhoz.
- DB-t érintő teszt: emeld a `RISK LEVEL`-t, és jelezd, hogy adatot érint.

---

## Riport a felhasználónak

Rövid, magyarul, tényszerűen:

```
ATC:    <objektum> — X error, Y warning   [+ a konkrét találatok]
AUnit:  N teszt, M bukott                 [+ mi bukott és miért]
Állás:  kész / javítás kell / <mi hiányzik>
```

Ha bármelyik lépcső nem futott le (nincs teszt, auth hiba, aktiválatlan objektum),
azt **külön írd le** — ne látszódjon zöldnek az, ami el sem indult.

## Ami NEM ennek a skillnek a dolga

- `/code-review ultra` — billed, kizárólag a felhasználó indítja. Ne hívd, ne is
  próbáld Bash-ből.
- `/security-review`, `/simplify` — külön slash command, a felhasználó indítja.
  Kiajánlás előtt javasolhatod, de ez a kapu ATC + AUnit, semmi több.

## Napló

Ha a review érdemi döntést hoz (pl. warning tudatosan bent marad, teszt kimarad),
írd be a projekt `_LOG.md`-jébe a „Döntés:" szóval, és frissítsd a „Jelen állás" blokkot.
