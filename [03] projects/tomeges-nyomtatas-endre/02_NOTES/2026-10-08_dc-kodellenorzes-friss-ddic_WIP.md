# DC-kódellenőrzés a frissített DDIC-export alapján

**Dátum:** 2026-10-08  
**Státusz:** WIP  
**Rendszer:** DHC; helyi exportok és kódtervezet ellenőrzése

A frissített `../01_SOURCES/DHC/ZPRT_DCQM.table` 42 mezőt tartalmaz, az include-ok mezőit külön számolva. A stock azonosítója `PRD_STOCK_ID`. Új technikai mezők: `CRUSER`, `CRDATE`, `CRTIME`, `CHUSER`, `CHDATE`, `CHTIME`.

Az ellenőrzés tárgya a `../04_ASSETS/abap/` mappában található `ZPR_DCQM_EXCLUDE.abap`, két include-ja, a 0100 flow logic, a `ZPR_DC_FRAME.abap` és a `ZPRS_DCQM_REPORT` létrehozási specifikációja. A további táblamezőket a helyi exportokkal, a `ZPRT_DCQMLT` mezőit a felhasználó által megadott négymezős definícióval vetettük össze.

## Eredmény és javítások

- A riport három és a keretprogram két stockfeltétele `PRD_STOCK_ID`-ra hivatkozik; a régi `PRDSTOCK` nincs a két ABAP-programban.
- A DC-mentés a `ZPRT_DCQM`, a stockállapot mentése a `ZPRT_STOCK` `CHUSER`, `CHDATE`, `CHTIME` mezőit is kitölti, ugyanabban az UPDATE-utasításban. A létrehozási adatok megmaradnak.
- Az ALV-specifikációban két elírást javítottunk: `BOCK_DC_TEXT` → `BLOCK_DC_TEXT`, `DOC_CATL` → `DOC_CAT`. Ha a SAP-ban is a hibás komponensnév szerepel, átnevezés és aktiválás szükséges.
- Az ALV továbbra is **39 komponensű**: 35 üzleti mező + két hosszú szöveg + `CHANGED` + `HANDLE_STYLE`. A `MANDT` és a hat létrehozási/módosítási mező nem szükséges az ALV megjelenítéséhez. Az `INTO CORRESPONDING FIELDS` a közös, azonos nevű mezőket tölti.
- A hosszú szöveges tábla kulcshivatkozása továbbra is `EXBILLDOCNO`; az alaptábla és az ALV dokumentummezője `DOC_NO`.

## Helyi ellenőrzés

| Ellenőrzés | Eredmény |
|---|---|
| Egyedi táblák 14 SELECT/UPDATE utasításának WHERE/SET mezőnevei | A megfelelő tábladefinícióban szerepelnek |
| 28 különböző `ZPRT_DCQM`-ra típusozott mezőhivatkozás | A friss exportban szerepelnek |
| Az ALV 39 komponense és a közös 35 mező adatelemei | Egyeznek a specifikációval és az exporttal |
| A kód explicit ALV-komponenshivatkozásai | Megvannak a specifikációban |
| 23 különböző PERFORM-cél | A hozzájuk tartozó FORM megvan |
| A 0100 képernyő négy MODULE-hivatkozása | A megfelelő INPUT/OUTPUT modul megvan |

Ez mezőnév- és hivatkozásellenőrzés, nem SAP-fordítás. Az aktív SAP-objektumok, a táblák kulcsai, a zárobjektumok és a `ZCL_PR_LOG` szignatúrája továbbra is ellenőrizendők. SAP-szintaxisellenőrzés, ATC és funkcionális teszt nem futott; a korábbi ADT-lekéréseket HTTP 401 hitelesítési hiba akadályozta.
