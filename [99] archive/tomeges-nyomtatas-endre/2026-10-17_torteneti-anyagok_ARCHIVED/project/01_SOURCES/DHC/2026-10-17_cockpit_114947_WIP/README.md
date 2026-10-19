# Cockpit MCP-visszaolvasás

Státusz: WIP. Lekérés 2026-10-17, kb. 11:49 UTC / 13:49 Europe/Budapest.

A felhasználó kifejezetten kérte az MCP-adatok lekérését. A `GetProgram(ZPR_DCQM_EXCLUDE, active)` sikeres, HTTP 200 / OK; a teljes visszakapott `program_data` a `ZPR_DCQM_EXCLUDE.abap` fájlban mentve, LF sortörésekkel. A korábbi forrásmentések és a fő WIP-csomag nem lettek felülírva.

A mentett fájl SHA256: `7888EDD050780F7ECD759941B8A77D2CDA3B0467C60D0A72E223F4376AF598FB`. A fő WIP-riporthoz képest a `git diff --no-index` szerint csak whitespace, a három diagnosztikai blokk és az aktív forrásban még megmaradt nullalevágó SHIFT tér el; a két CREATE OBJECT bekötése azonos. A diff 1-es kilépési kódja a különbségek megtalálását jelenti.

Igazolt az aktív forrásból:

- `ZPR_DCQM_EXCLUDE_C01` egyszer szerepel INCLUDE-ként. Az include mostani tartalma ebből nem ellenőrzött.
- A custom container neve `ALV_CONTAINER_01`; REPId/DYNNR paraméterei a két hostváltozó. Ezek futásidejű értékeit ez a repository-olvasás nem méri.
- A Grid `I_PARENT = GO_ALV_GRID_CONT_01` paramétert kap.
- OFFLINE-, SET_ALIGNMENT- és GET_WIDTH/GET_HEIGHT + FLUSH-diagnosztika aktív; a felhasználó által megadott runtime eredmények továbbra is felhasználói mérésből származnak.
- A rutinban nincs explicit SET_VISIBLE, és nem látszik elrejtő hívás. A SET_VISIBLE hiánya önmagában nem igazolt hiba.
- A vezető nullákat levágó `SHIFT lv_stokid LEFT DELETING LEADING '0'.` még aktív. Ez az ALV-cím formázásának eltérése a helyi WIP-től, nem az üres fül igazolt oka.

A következő `GetInclude(LZPR_COCKPITO01)` hívást az automatikus jóváhagyási ellenőrzés elutasította. Indok: az egyszeri újrapróbálási engedély nem jogosít további ADT-lekérésre. Ez nem SAP-válasz, nem HTTP 401 és nem újabb HTTP 400. A hívás elutasítása után nincs további SAP-eszközhasználat, kerülőút vagy módosítás. A felhasználó új, kifejezett engedélye szükséges a további include-/képernyőadat-olvasáshoz.

Nem ellenőrzött ebben a körben: cockpit O01/C01 aktuális include-tartalma, a cockpit 1010 aktív layout/flow logic és láthatósági lánc, a standard Grid méretmetódusainak implementációja, a GUI tényleges állapota. A hibát ez a részleges olvasás még nem azonosította. SAP-írás/aktiválás/futtatás nem történt.

## Későbbi explicit engedély és ismételt auto-review elutasítás

A felhasználó kifejezetten engedélyezte az include-/képernyőmetaadat-/standard ALV-forrás olvasási sorozatát az első tényleges SAP-hibáig. Az ezután kezdeményezett egyetlen `GetInclude(LZPR_COCKPITO01)` hívást az automatikus jóváhagyási ellenőrzés ismét elutasította. Indokának lényege: „Bár a felhasználó kifejezetten engedélyezte a sorozatot”, az AGENTS.md egyszeri próbálkozást enged, és a GetProgram már sikeres volt.

Ez nem SAP-elérési hiba, nem HTTP-válasz. További hívás és megkerülés nincs; a felhasználói engedély léte rögzített, újra ugyanazt kérni nem oldja fel az eszközkorlátozást. A további elemzéshez az automatikus korlátozás rendezése vagy a hiányzó include-/képernyőadatok kézi exportja szükséges. A mostani forrásmentés változatlan, új SAP-adat nem érkezett.
