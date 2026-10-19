# Tömeges nyomtatás – történeti archívum

Státusz: **ARCHIVED**, 2026-10-17. A felhasználó kifejezett archiválási kérésére 127 fájl került ide. Minden mozgatott fájl SHA256-értéke az áthelyezés után egyezett az eredetivel. Az archív dokumentumok relatív hivatkozásai később igazítva lettek; az eredeti és az aktuális hash külön szerepel a [manifesztben](2026-10-17_archiv-manifest_ARCHIVED.json).

Az eredeti SAP-objektumnevek és a történeti WIP-fájlnevek megmaradtak; az ARCHIVED státusz erre a teljes gyűjteményre vonatkozik. A korábbi export saját eredeti manifesztje és mind a 34 fájlja változatlan maradt.

**Aktív munkabázis:** [abap-2026-10-17](<../../../[03] projects/tomeges-nyomtatas-endre/05_FINAL/abap-2026-10-17/README.md>). [Aktív projektbrief](<../../../[03] projects/tomeges-nyomtatas-endre/00_BRIEF.md>). A hiányzó cockpit/C01 és nyitott QA-javítás az aktív projektben maradt.

| Csoport | Fájl | Archív hely |
|---|---:|---|
| Tegnapi teljes export | 34 | [README](project/05_FINAL/abap-2026-10-16/README.md) |
| Régi cockpit SAP-/felhasználói mentések | 8 | `project/01_SOURCES/DHC/2026-10-17_cockpit*` |
| Korábbi jegyzetek és ellenőrzési eredmények | 17 | `project/02_NOTES/` |
| Régi tervek, patchek, ALV-próbák és diagnosztika | 13 | `project/03_DRAFTS/` |
| Korábbi munkaprogramok és include-ok | 19 | `project/04_ASSETS/abap/` |
| Ideiglenes ellenőrzési és javítás előtti mentések | 36 | `workspace-tmp/` |

A `project/` az eredeti projekten belüli útvonalakat őrzi. A `workspace-tmp/` alatti könyvtárak korábban a workspace `.tmp/` könyvtárában voltak. Minden fájl eredeti workspace-útvonala a manifeszt `originalPath` mezőjében található; az archív hely az `archivedPath`. Visszaállításkor egyenként egyeztetni kell az esetleges új aktív fájllal.

A régi validátorok az aktív projekt `04_ASSETS/validation/` könyvtárában maradtak, és az itt található régi WIP-forrásokat olvassák. Nem a mai export QA-/ATC-/ABAP Unit eredményei. Az archív `.tmp` scriptek és kimenetek történeti munkamentések; futtatásuk külön egyeztetést igényelhet.

Archiváláskor SAP-elérés, SAP-adatmódosítás, fordítás és SAP-teszt nem történt.
