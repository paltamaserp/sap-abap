# SAP ADT kapcsolat használata

A felhasználó 2026-10-13-án rögzített utasítása:

- Az SAP ADT-kapcsolat első sikertelen elérési kísérlete után ne használd tovább az érintett kapcsolatot. Hitelesítési hiba (például HTTP 401), kapcsolati hiba vagy elérési timeout után ne próbálkozz automatikusan újra, más SAP-eszközzel vagy közvetett kerülőúton sem.
- A felhasználónak jelezd, hogy a kapcsolat nem érhető el. Ha a feladat helyi forrásokból folytatható, ezekből dolgozz, és egyértelműen jelezd, hogy az aktív SAP-állapot nincs ellenőrizve.
- Ez a leállás a következő körökre és munkamenetekre is érvényes. Egy új kapcsolati ellenőrzést kizárólag a felhasználó kifejezett újrapróbálási kérése engedélyez; ez egyetlen új kísérletre szól. Ha az is sikertelen, ismét állj le.
- Az automatikus jóváhagyási ellenőrzés elutasítását külön jelezd. Az elutasított eszközhívás nem friss SAP-válasz, ezért nem állítható róla, hogy ismét HTTP 401 érkezett.

A munkaterület további szabályai: `_START-HERE.md` és `[01] system/RULES.md`. Projektmunka folytatásakor olvasd a projekt `00_BRIEF.md` és `_LOG.md` fájlját.
