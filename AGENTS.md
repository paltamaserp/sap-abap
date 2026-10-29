# SAP ADT kapcsolat használata

A felhasználó 2026-10-13-án rögzített utasítása:

- Az SAP ADT-kapcsolat első sikertelen elérési kísérlete után ne használd tovább az érintett kapcsolatot. Hitelesítési hiba (például HTTP 401), kapcsolati hiba vagy elérési timeout után ne próbálkozz automatikusan újra, más SAP-eszközzel vagy közvetett kerülőúton sem.
- A felhasználónak jelezd, hogy a kapcsolat nem érhető el. Ha a feladat helyi forrásokból folytatható, ezekből dolgozz, és egyértelműen jelezd, hogy az aktív SAP-állapot nincs ellenőrizve.
- Ez a leállás a következő körökre és munkamenetekre is érvényes. Egy új kapcsolati ellenőrzést kizárólag a felhasználó kifejezett újrapróbálási kérése engedélyez; ez egyetlen új kísérletre szól. Ha az is sikertelen, ismét állj le.
- Az automatikus jóváhagyási ellenőrzés elutasítását külön jelezd. Az elutasított eszközhívás nem friss SAP-válasz, ezért nem állítható róla, hogy ismét HTTP 401 érkezett.

A munkaterület további szabályai: `_START-HERE.md` és `[01] system/RULES.md`. Projektmunka folytatásakor olvasd a projekt `00_BRIEF.md` és `_LOG.md` fájlját.

## ABAP objektumok automatikus utóellenőrzése

A felhasználó 2026-10-28-i kérése: **MCP segítségével létrehozott ABAP-objektumok után külön kérés nélkül futtass egységtesztet (ABAP Unit), és az eredményt objektumonként jelentsd és mentsd.** A tesztkód létrehozása önmagában nem tesztfuttatás. Hiányzó teszt vagy akadályozott futtatás esetén ezt „nem futott” eredményként, az okával együtt rögzítsd; sikeres tesztet ne állíts. Önálló futtatható logika nélküli objektumnál a nem alkalmazhatóságot konkrétan indokold az alábbi menet szerint. A kapcsolati leállási szabály változatlanul érvényes.

A felhasználó 2026-10-27-i kérése alapján minden itt végzett ABAP-létrehozás, -módosítás és -aktiválás után, külön kérés nélkül hajtsd végre az [automatikus ellenőrzési menetet](<[01] system/ABAP-AUTO-CHECK.md>). Olvasd a [helyi review-skillt](.claude/skills/abap-code-review/SKILL.md), és a végleges módosított objektumkörre ellenőrizz; összetartozó mentési csomagonként egy futás elég.

A sikerfeltételeket a munka elején nevezd meg, az eredményeket és hiányokat objektumonként jelentsd és mentsd. A `Check*` szintaxisellenőrzés nem ATC. A nem futott vizsgálat nem siker. Helyi forráskérés nem engedély SAP-írásra vagy aktiválásra; az ellenőrzés nem oldja fel a fenti kapcsolati leállást. Ez az asszisztens munkamenetében végrehajtott menet, nem telepített SAP-háttérjob vagy minden szerkesztőre érvényes fájlfigyelő.
