# RULES.md — kötelező viselkedési szabályok

> Ezt a `_START-HERE.md` után olvasd. Ezek a szabályok **felülírják** az alapértelmezett
> viselkedést. Ha valamiben ütközés van, kérdezz, ne találgass.

---

## Nyelv

1. Minden interakció és dokumentáció **magyarul**.
2. A kérést a feldolgozás elején fordítsd le **angolra**, úgy dolgozz, majd a választ fordítsd **vissza magyarra**.
3. Kód-kommentek a kódbázis konvenciója szerint (production ABAP-nál angolul — lásd `NAMING.md` / oneERP guideline).

## SAP munkamenet (ABAP ADT MCP)

4. SAP repository olvasáshoz/íráshoz/aktiváláshoz a **`sap-abap-adt` MCP** szervert használd (`fr0ster/mcp-abap-adt`).
5. SAP objektum módosítása után **olvasd vissza** / igazold az aktív állapotot, ha lehetséges.
6. A lokális `.abap` másolatokat tartsd szinkronban az aktív SAP objektummal, ha a workspace tartalmaz ilyet.
7. **Konzervatív, SAP-kompatibilis** ABAP-mintákat használj, hacsak nem kérek újabb szintaxist vagy konkrét release-célt.
8. SAP-ból tükrözött objektumnevek (`ZCL_…`, `ZXWEB_…`, `ZEPTS_…`, `ZIFC_…`) **nem nevezhetők át** — egyezniük kell az ADT-objektummal.

## Biztonság

9. **Soha** ne tárolj SAP jelszót, tokent vagy más titkot markdown-ban vagy repository-forrásban.
10. Külső/felhasználói inputnál használj whitelistet vagy reguláris kifejezést, ahol praktikus.

## Státusz és napló (lásd `STATUS.md`)

11. Új fájl alapból **WIP**, hacsak nem mondom, hogy kész.
12. Státuszt **csak akkor** léptess, ha kimondom, vagy a `00_BRIEF.md` „kész" kritériuma teljesül.
13. **FINAL** fájlt soha ne írj felül csendben — kérdezz, vagy nyiss új verziót új dátummal.
14. Minden döntést a projekt `_LOG.md`-jébe írj a **`Döntés:`** szóval — ne csak fejben tartsd.
15. Session végén frissítsd a `_LOG.md` „Jelen állás" részét és írj 2–4 sort a mai dátum alá.

## Workspace-integritás

16. Ha bármit átszervezel a workspace-ben, **frissítsd a `_START-HERE.md`-t** (térkép + „Jelenleg aktív projektek" tábla) — lásd `SYSTEM-RULES.md`.
17. Minden új projekt a `[03] projects/_TEMPLATE/` másolatával induljon (egységes váz).
18. Nyers, rendezetlen anyag a `[00] inbox/`-ba kerül; **semmi nem marad ott tartósan**.
