---
name: abap-code-review
description: SAP ABAP objektum létrehozása, módosítása vagy aktiválása utáni ellenőrzés és eredményjelentés. Használd szintaxisellenőrzéshez, aktív forrás visszaolvasásához, ABAP Unit és ATC SCI Onapsis eredmények értékeléséhez; helyi forrásnál külön jelezd a még nem ellenőrzött SAP-állapotot.
---

# ABAP objektumok ellenőrzése

A munkatérben az utóellenőrzés **automatikus** a 2026-10-27-i felhasználói kérés alapján. Létrehozás, módosítás vagy aktiválás után, az összetartozó mentési csomag végén ellenőrizd a teljes módosított objektumkört. Kérésre meglévő objektum is ellenőrizhető. Puszta olvasás vagy változatlan forrásexport nem indít automatikus SAP-tesztet.

A sikerfeltételek és kötelező visszajelzés a [munkatér szabályában](../../../[01]%20system/ABAP-AUTO-CHECK.md) szerepelnek. A munka elején nevezd meg őket, és az adott feladat felhatalmazásán belül ellenőrizz. A felhasználói kapcsolati leállás minden lépcsőn érvényes; új session sem oldja fel.

## Cél és jogosultság

Azonosítsd az objektumot, típust, szülőprogramot/osztályt, rendszert, mandantot és vizsgálandó verziót. A projekt friss briefje/naplója és a felhasználó választása az irányadó; a forrás fejlécéből vagy régi ECC/CRM-eszköznévből ne találj ki kapcsolatot. Az aktuális sap-abap-adt eszközleírásokat használd.

A helyi diffkérés nem jogosít SAP-írásra vagy aktiválásra. A vizsgálat kedvéért ne aktiváld mások függő objektumait, ne írj automatikusan új tesztet SAP-ba, és ne futtass üzleti riportot. Meglévő SHORT/HARMLESS, izolált és releváns Unit-tesztek az engedélyezett SAP-fejlesztés ellenőrzéseként indíthatók. Adatot érintő vagy nagyobb kockázatú teszthez külön felhatalmazás szükséges, ha az adott kérésből nem következik.

## Végrehajtás

1. **Szintaxis:** a megfelelő Check* eszközt futtasd a módosított verzióra. A CheckClass/CheckFunctionModule/CheckTable/CheckStructure/CheckView verzióparaméterét explicit állítsd, ha támogatott. A CheckProgram nem kínál verzióparamétert: a megvizsgált állapotot az eszköz/SAP-válasz alapján igazold; bizonyíték nélkül ne jelentsd, hogy az új aktív vagy inaktív változat hibamentes. Include-ot a releváns főprogrammal, osztály-include-ot a szülőosztállyal együtt vizsgálj.
2. **Hibakezelés:** szintaktikai hibánál az engedélyezett változtatási körben javíts, majd ellenőrizz újra. Ne indíts Unit-tesztet hibás szintaxisra. A figyelmeztetéseket egyenként értékeld és indokold; kezeletlen figyelmeztetésnél az eredmény nem teljes siker.
3. **Aktív visszaolvasás:** ha a munka engedi a telepítést, a szintaxis után aktiváld az érintett objektumokat, olvasd vissza az aktív forrást/definíciót, és hasonlítsd össze a szándékolt végső változattal. Ha az író eszköz már aktivált, ne aktiválj újra fölöslegesen; a visszaolvasás akkor is kell. Helyi kérés vagy hiányzó felhatalmazás esetén az aktív állapot maradjon nem ellenőrzött.
4. **ABAP Unit:** azonosítsd a releváns tesztosztályokat. A jelenlegi RunUnitTest container_class és test_class párokat vár; ne találj ki programnév-paramétert vagy nem támogatott riportteszt-hívást. RunUnitTest → GetUnitTestStatus → GetUnitTestResult, befejezett futásig, run ID-val. Nulla teszt, futó/hibás futás vagy eredményhiány nem siker. Nem támogatott riportteszt vagy hiányzó érdemi teszt külön nyitott feltétel. Tiszta DDIC-nél indokolt nem alkalmazható jelzés adható.
5. **QA:** a Check* eszközök szintaxisellenőrzések, **nem ATC**. ATC/SCI/Onapsis-vizsgálatot csak az arra szolgáló, elérhető futtatóval és azonosított variánssal indíts. Jelenleg nincs ilyen dedikált MCP-eszköz; ezt a pillanatnyi leltárral ellenőrizd, hiányában jelentsd: QA nem futott. Elfogadható a felhasználó által átadott, azonosítható teljes eredmény is, eredetének feltüntetésével. Ne indíts helyettesítő távoli riportot, HTTP-kerülőutat vagy transzportelengedést.

Helyi forrásnál a meglévő parser/diff/include-ellenőrzés futtatható, de egyik SAP-lépcsőt sem igazolja. Minden új SAP-elérési hiba után azonnali leállás; a helyi ellenőrzés és a hiányok dokumentálása folytatható.

## Mentés és összesítés

A releváns MCP-válaszokat, forrásokat és futásadatokat a projekt 04_ASSETS/validation/<dátum>_<téma>_WIP/ mappájába mentsd, hitelesítési adatok nélkül. Minden objektumra külön rögzítsd a syntax, active_readback, unit és qa ellenőrzést. Részletek és jelentésforma: [references/report.md](references/report.md).

Az összesítés után automatikusan futtasd a [scripts/validate_report.py](scripts/validate_report.py) segédet az elérhető Python futtatóval és a jelentés.json argumentummal.

Az eredmény SIKERES, RÉSZLEGES vagy HIBÁS, 0, 2, illetve 1 kilépési kóddal. A 2-es kód hiányos ellenőrzés, nem siker és nem ok SAP-kerülőútra. Hibás bemenet is 1-es kódú. A segéd **nem SAP-futtató**: a kapott eredmények és bizonyítékok összesítését ellenőrzi.

A végén minden objektum eredményét, sikerfeltételeit, hiányait és bizonyítékait jelentsd, majd frissítsd a projekt _LOG.md fájlját. A SIKERES vizsgálat nem automatikus FINAL státusz. Az általános státuszszabályok megmaradnak.
