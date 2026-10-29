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

### SAP-kapcsolati hiba utáni leállás

A felhasználó kifejezett utasítása (2026-10-13): az SAP ADT-kapcsolat első sikertelen elérése után **ne használd tovább az érintett kapcsolatot**, csak jelezd, hogy nem érhető el. HTTP 401, más hitelesítési/kapcsolati hiba vagy elérési timeout után nincs automatikus újrapróbálás, más SAP-eszközre váltás vagy közvetett kerülőút. A leállás a későbbi körökre és munkamenetekre is érvényes.

Új elérési kísérlet csak a felhasználó kifejezett újrapróbálási kérésére történhet, egy alkalommal; sikertelenség esetén ismét le kell állni. Helyi exportból folytatható az engedélyezett munka, az aktív SAP-állapot ellenőrizetlenségének jelzésével. Az automatikus jóváhagyási ellenőrzés elutasítása nem friss SAP-válasz; ezt külön, pontosan kell jelezni.

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

## Kódolási munkamódszer

### Gondolkodj kódolás előtt
19. **Ne feltételezz. Ne rejtsd el a zavart. Tárd fel a kompromisszumokat.** Megvalósítás előtt:
    - Fogalmazd meg explicit módon a feltételezéseidet; ha bizonytalan vagy, kérdezz rá.
    - Ha több értelmezés létezik, mutasd be őket.
    - Ha van egyszerűbb megközelítés, jelezd.
    - Ha valami nem világos, állj meg, nevezd meg mi zavaró, kérdezz rá.

### Egyszerűség mindenekelőtt
20. A probléma megoldásához szükséges **minimális kód**, semmi spekuláció:
    - Semmi nem kért funkció; semmi absztrakció egyszer használatos kódhoz.
    - Semmi nem igényelt „rugalmasság" / „konfigurálhatóság".
    - Semmi hibakezelés lehetetlen forgatókönyvekre.
    - Ha 200 sort írsz, de megoldható 50-ből, írd újra. Kérdezd: „Egy senior mérnök azt mondaná, túl van bonyolítva?" Ha igen, egyszerűsíts.

### Sebészi pontosságú változtatások
21. Csak ahhoz nyúlj, amihez muszáj; csak a saját szemetedet takarítsd el:
    - Ne „javíts" szomszédos kódon, kommenten, formázáson.
    - Ne refaktorálj olyat, ami nincs elromolva.
    - Igazodj a meglévő stílushoz, akkor is ha te másképp csinálnád.
    - Halott/nem idetartozó kódot **jelezz, de ne törölj** (hacsak nem kérték külön).
    - Csak a TE változtatásod által árvává tett import/változó/függvény távolítható el.

### Célvezérelt végrehajtás
22. Határozd meg a siker kritériumát, ismételj az ellenőrzésig. Alakítsd a feladatot ellenőrizhető céllá:
    - „Validáció hozzáadása" → „Írj tesztet érvénytelen bemenetre, majd érd el hogy átmenjen."
    - „Bug javítása" → „Írj tesztet ami reprodukálja a hibát, majd érd el hogy átmenjen."
    - „X refaktorálása" → „Biztosítsd hogy a tesztek előtte és utána is lefutnak."
    - Több lépéses feladatnál előbb rövid terv.

### ABAP QA-tanulságok
23. ABAP-forrás készítése és módosítása előtt olvasd el és alkalmazd az [ABAP-QA-CHECKLIST.md](ABAP-QA-CHECKLIST.md) szabályait: fordítható MESSAGE-szövegek, táblatípushoz illő beszúrás és a kiválasztás üzleti hatókörét megőrző index-/adatbázis-kezelés. A nyitott QA-találatokat és az SAP-ban még nem ellenőrzött javításokat külön jelezd.

### Automatikus ABAP-utóellenőrzés
24. ABAP-objektum létrehozása, módosítása vagy aktiválása után automatikusan kövesd az [ABAP-AUTO-CHECK.md](ABAP-AUTO-CHECK.md) menetét. A munka elején közöld az alkalmazható sikerfeltételeket, a végén objektumonként a tényleges ellenőrzést, a még nem futott lépést és az eredményfájl helyét. Helyi mentéshez helyi ellenőrzés tartozik; SAP-írást vagy aktiválást az ellenőrzési szabály önmagában nem engedélyez.
25. Csak az összes kötelező feltétel igazolt teljesülése jelent sikeres ellenőrzést. A részleges vagy hibás eredményt ne jelentsd sikernek; az ellenőrzési eredmény nem automatikus WIP/REVIEW/FINAL státuszváltás. A `Check*` eredményt szintaxisellenőrzésnek nevezd; ATC/SCI/Onapsis-eredményt csak valódi, azonosított QA-futás alapján jelents.
26. A felhasználó 2026-10-28-i kérése alapján **MCP-vel létrehozott ABAP-objektumok után egységtesztet (ABAP Unit) is futtass automatikusan**, és az eredményt objektumonként jelentsd és mentsd. A tesztkód megléte nem futási eredmény; a hiányzó vagy akadályozott teszt „nem futott”, az önálló futtatható logika nélküli objektum mentessége konkrét indokkal rögzítendő az ABAP-AUTO-CHECK.md szerint. A kapcsolati leállás továbbra is elsőbbséget élvez.
