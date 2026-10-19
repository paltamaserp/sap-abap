# DHC stockriport helyi ellenőrzése

Státusz: WIP. Dátum: 2026-10-13.

A teljes DHC-riport és a két include, valamint a 0100 flow logic helyi forrása elkészült. A kód a felhasználó által választott `STATUS = QM` lezárási feltételt és `STATUS = CL`, `CLOSED = X` sikeres mentést használja. A ragszámtörlés a felhasználó döntése szerint a `ZPR_TERTI` és `ZISU_F064` táblákon marad.

## Elvégzett helyi ellenőrzések

- A főprogram és include-ok `CLASS`, `METHOD`, `FORM`, `MODULE`, `IF`, `LOOP`, `TRY`, `CASE` blokkjainak nyitása/zárása párosítva, szerkezeti eltérés nélkül. Ez célzott szöveges vizsgálat, nem teljes ABAP-parser.
- A 24 FORM és a hivatkozott PERFORM-ok között nincs hiányzó célrutin.
- A főprogram két include-ja létező fájlra mutat. A flow logic négy MODULE-hívásának megfelelő moduljai a két include-ban megvannak.
- A `ZPRT_STOCK`-ra típusozott és a `GS_STOCK`-on használt komponensek szerepelnek a helyi DHC-táblaexportban. A két stock-UPDATE SET/WHERE mezői is egyeznek az exporttal.
- A `ZPRT_DCQM`-ra típusozott komponensek és az ALV `DOC_NO`, `ENVELOPE`, hosszúszöveg-, `COUNTER`, `CHANGED`, `HANDLE_STYLE` hivatkozásai egyeznek a helyi exporttal / a korábbi ALV-specifikációval.
- Nincs QU5 `ZEBF_` típus-/objektumhivatkozás, fejlesztői `ZKG_BREAK`, illetve köztes `ZCL_PR_STOCK=>UPDATE_STATUS` hívás a generált riportban.
- A fájlok UTF-8-ként olvashatók, nincs helyettesítő karakter vagy sorvégi whitespace. A meglévő fájlmódosításokon a `git diff --check` rendben.

## Kézi vezérlésifolyamat-ellenőrzés

| Ág | A kódban megfigyelt útvonal |
|---|---|
| Logikai port / proxy létrehozása hibás | A `SEND_PRIORITY` hibás eredménnyel tér vissza, nincs `SAVE_RELEASE`; a hívás-elindult jelző még üres |
| Külső válasz `SUCCESS` nem X | Hibás eredmény, nincs ragszámtörlés vagy stocklezárás |
| Külső application fault | Külön `CX_AI_APPLICATION_FAULT` ág: hibás eredmény, hívás- és külsősiker-jelző törlése, naplózás és visszatérés; nincs helyi lezárás/ragszámtörlés vagy új tartós tiltás |
| Külső hívás közben más kivétel | Hibás eredmény és bizonytalanállapot-jelző; újraküldés tiltása |
| Külső siker | Kizárólag itt lesz `GV_REMOTE_SUCCESS = X` és sikeres az eredmény |
| Helyi ragszám-/stockmentés hibás | Rollback, bizonytalanállapot-jelző; a stock nincs sikeresnek jelölve |
| Helyi mentés sikeres | Közös commit után lesz `GV_SAVED = X`; a naplóhiba külön eredmény |
| Stock nincs QM státuszban, lezárt vagy hibajelzős | Megjelenítő mód, a gombkezelőben és zár alatti friss ellenőrzésnél is tiltás |
| A megjelenített adatok változtak | Az adott kísérlet leáll a külső hívás előtt; friss lista jelenik meg |

A táblázat forrásvizsgálat eredménye; egyik ág sem futott SAP-ban.

A 2026-10-13-i application fault módosítás célzott helyi ellenőrzése: a külön CATCH ág a `CX_ROOT` elé került, a hívásjelzők a naplózás előtt törlődnek, és a RETURN megakadályozza a sikerág elérését. A forrás összevetése alapján kizárólag ez az ág került a riportba; a korábbi üresboríték-módosítás és a többi hibakezelés megmaradt. SAP-szintaxisellenőrzés és futó teszt nem történt.

## Az ellenőrzés korlátai

Az offline `@abaplint/core` telepítését megkíséreltük a Windows temp könyvtárában. A csomagletöltés hálózati/hozzáférési `EACCES` hibával meghiúsult, ezért **ABAP-parseres szintaxisellenőrzés nem futott**. Nem telepítettünk függőséget a projektbe.

Az SAP ADT-kapcsolatot a felhasználó leállási szabálya szerint nem használtuk. SAP-fordítás, ATC, ABAP Unit, proxyhívás, adatbázismentés és funkcionális teszt nem történt. Az aktív DDIC-, proxy-, logikaiport- és naplóosztály-szignatúrák nem igazoltak.

A DHC `ZISU_F064` teljes exportja még nem áll rendelkezésre: a CHAR 16 ragszámmező futásidejű ellenőrzésének megfelelőségét aktív definícióval kell összevetni. A ragszámtáblák és az összes stockmódosító közös zárolási rendjét is SAP-ban kell ellenőrizni.

Részletes másolási és tesztelési útmutató: [DHC bemásolás](<../../../../../[03] projects/tomeges-nyomtatas-endre/04_ASSETS/abap/info.md/2026-10-13_stock-report-dhc-bemasolas_WIP.md>).
