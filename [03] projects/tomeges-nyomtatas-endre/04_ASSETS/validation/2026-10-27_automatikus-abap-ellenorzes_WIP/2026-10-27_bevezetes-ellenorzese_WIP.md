# Automatikus ABAP utóellenőrzés bevezetése

Státusz: **WIP** · Dátum: **2026-10-27**.

A felhasználó pontosítása: elsősorban SAP ABAP-objektumokra legyen automatikus ellenőrzés létrehozás után, előre jelzett sikerfeltételekkel. A menet a további létrehozásra, módosításra és aktiválásra is alkalmazható, mentési csomagonként a teljes érintett objektumkörben.

## Elkészült

- A gyökér AGENTS.md és a RULES.md kötelezővé teszi az automatikus utóellenőrzést az asszisztens munkamenetében.
- A részletes feltételek az [ABAP-AUTO-CHECK.md](../../../../../[01]%20system/ABAP-AUTO-CHECK.md) fájlban vannak. A TESTING-TOOLS.md és a helyi abap-code-review skill egyeztetve; a Check* eszközök szintaxisellenőrzésként, nem ATC-ként szerepelnek.
- A validate_report.py a mentett összesítést és bizonyítékok hash-eit ellenőrzi. Mind a négy vizsgálati lépcső állapotát megjeleníti, és SIKERES, RÉSZLEGES vagy HIBÁS összeredményt ad 0, 2, illetve 1 kilépési kóddal. SAP-tesztet nem indít.

## Ellenőrzés

A [helyi tesztfutás](2026-10-27_helyi-teszteredmeny_WIP.txt) **14 tesztje sikeres**. A tesztek szintetikus, ideiglenes helyi fájlokat használnak. Ellenőrzött esetek: teljes siker; hiányzó lépcső; nulla vagy futó Unit-teszt; még futó QA; eltérő aktív forrás; sérült bizonyíték; régi forráshash; kezeletlen figyelmeztetés; indokolt Unit-mentesség; QA-mentesség elutasítása; üres/ismeretlen hatókör; hibás lépcső elsőbbsége; könyvtáron kívüli bizonyíték elutasítása; CLI-kilépési kódok és mentett jelentés.

A skill csomagolt quick_validate.py segédje a runtime-ból hiányzó PyYAML miatt nem indult el. Helyette a jelenlegi egyszerű frontmatter név/leírás mezőit, névformátumát, kitöltöttségét és belső fájlhivatkozásait Python standard könyvtárral ellenőriztük; rendben. Ez helyi formai ellenőrzés, nem a csomagolt validátor sikeres futása.

Valódi SAP-írás, aktiválás, szintaxis-, Unit- vagy QA-futás ebben a körben nem történt. A teljes ATC/SCI/Onapsis-futtató hiánya az aktuális eszközleírások alapján továbbra is nyitott. Az új menet nem SAP-háttérjob vagy IDE-mentési hook; a felhasználó adott feladathoz tartozó felhatalmazásán belül, az asszisztens hajtja végre automatikusan. Kapcsolati leállást nem old fel.
