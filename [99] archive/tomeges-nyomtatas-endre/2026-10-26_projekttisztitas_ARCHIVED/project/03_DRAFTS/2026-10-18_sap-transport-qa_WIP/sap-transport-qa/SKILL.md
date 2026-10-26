---
name: sap-transport-qa
description: "SAP transzportkérelmek QA-előkészítése, ATC/SCI/Onapsis-találatok értelmezése és célzott ABAP-javítások készítése. Használd kérelem elengedése előtti ellenőrzésnél, QA-hibalistánál vagy a futtatott variáns és szabályok felderítésénél."
---

# SAP transzport QA

Státusz: WIP alapváltozat. Magyarul dolgozz; az új ABAP-kommentek angolul készüljenek. A felhasználó konkrét kérése és az aktuális munkaterület utasításai határozzák meg a feladatot. Az ismert projektpéldákat ne kezeld univerzális SAP-szabályként.

## Kiindulás és bizonyíték

Azonosítsd a vizsgált kérelmet vagy objektumot, a célrendszert, a forrás állapotát és az elvárt kimenetet: magyarázat, ellenőrzés, külön diff vagy engedélyezett javítás. A már megadott adatokat ne kérd újra. Olvasd a munkaterület AGENTS.md, _START-HERE.md és RULES.md utasításait, valamint az érintett projekt briefjét/naplóját, ha rendelkezésre állnak.

Minden megállapításnál különböztesd meg a friss SAP-olvasást/futtatást, a felhasználó által adott eredményt, a helyi exportot és a saját következtetést. A FINAL mappanév vagy egy parser sikeres futása nem igazolja az aktív SAP-állapotot. A teljes riporthoz tartozó include-okat és a szükséges DDIC-típusokat is vizsgáld; hiányukban szűkítsd az állítást.

## Adatgyűjtés

A kapcsolat használata előtt és a skillhez ismert munkaterületi helyzet tisztázására olvasd a [kapcsolat- és MCP-referenciát](<references/mcp-es-rendszer.md>). A leltár képességeket ír le, nem igazol sikeres SAP-hozzáférést. Az eszközök aktuális leírását mindig ellenőrizd; a nevükből ne következtess ATC-képességre.

Ha elérhető és engedélyezett a kapcsolat, gyűjtsd a kéréshez szükséges adatokat: rendszerverzió, kérelem/feladat objektumai, ellenőrző rendszer, tényleges variáns és paraméterek, teljes találatlista, valamint az érintett források. Válaszd külön a fejlesztő rendszer alapértelmezett variánsát a központi vagy elengedéskori beállítástól. A DEFAULT nevet csak bizonyíték alapján használd.

Kapcsolat vagy adat hiányában folytasd a rendelkezésre álló anyagokkal. A [beszerzési útmutató](<references/adatok-beszerzese.md>) megadja, honnan kérhető a pontos variáns, a futás eredménye és az egyedi elengedési bekötés. Csak a következő érdemi lépéshez szükséges hiányzó adatot kérd; a helyi elemzést ne állítsd le a teljes profil hiánya miatt.

## QA-találat feldolgozása

1. Rögzítsd a találat szabályazonosítóját, üzenetét, prioritását, objektumát és forráshelyét; ami nincs megadva, maradjon ismeretlen. A magyarázatot, sorszámot és prioritást ne találd ki.
2. Vizsgáld a tényleges típust, hívási utat és üzleti hatókört. Kövesd az include-okat, a hívott eljárásokat és a releváns DDIC-definíciókat. Egy rossz sorszámhoz képest a kódkörnyezet azonosítja a hibát.
3. Magyarázd el a kiváltó mintát és annak hatását. Válaszd külön a szabálysértést a bizonyított működési hibától. A [korábbi QA-példákat](<references/qa-peldak.md>) csak az illeszkedő típus/hívási út megerősítése után alkalmazd.
4. A legkisebb, az üzleti működést megőrző javítást készítsd a felhasználó által engedélyezett formában. Külön diff kérésekor a forrás maradjon változatlan; helyi javítási kérés nem engedély SAP-írásra vagy aktiválásra. Ne fojts el találatot automatikusan pragma/pseudo comment hozzáadásával.
5. A módosítás hatásának megfelelő ellenőrzést végezd el. Ha diffet adsz át, külön másolaton ellenőrizd az alkalmazhatóságát. A parser csak a nyelvi szerkezetet vizsgálja; a rendszerfüggő szintaxisellenőrzést, QA-futtatást és működési próbát külön nevezd meg.

## Futtatás és lezárás

ATC/SCI/Onapsis-futást csak valóban erre szolgáló, elérhető eszközzel és a kért hatókörrel indíts. A CheckProgram, CheckClass és CheckPackage jelenlegi MCP-leírása szintaxisellenőrzés: ezeket ne jelentsd teljes QA-futtatásként. Ha nincs megfelelő futtató, adj konkrét kézi lépéseket a beszerzési útmutató alapján; ne készíts helyette új távoli ABAP-riportot vagy közvetlen HTTP-kerülőutat.

Összehasonlítható újrafuttatáshoz azonosítsd a tényleges ellenőrző rendszert, variánst/paramétereket és objektumkört; a baseline, kivételezés és szűrők is befolyásolhatják a látható eredményt. Egy eltérő helyi SCI-futás nem igazolja a központi ATC/Onapsis-kapu teljesítését.

A végén röviden add meg a megállapítást/javítást, a ténylegesen elvégzett ellenőrzéseket és a még nyitott kérdést. Több találatnál használható táblázat: objektum, szabály, hiba oka, javítás, igazolás/nyitott állapot. A kérelem megfelelőségét csak az ismert tényleges QA-futtatásra vonatkozó bizonyítékkal állítsd; elengedést és konfigurációmódosítást ne végezz az elemzési feladat részeként.
