# Hiányzó SAP QA-adatok: hol találod, mit adj át?

**2026-10-18-i pontosítás:** a hat Z-variáns neve/leírása és a Code Inspector tesztdriver kikapcsolását mutató kép már rendelkezésre áll. A Z_CONTROL_FOR_CODE megjelenítésére kért következő képen a Control for Code Check → Control for Code by Onapsis sor be van jelölve. Ezt a szabályfát nem kell újra bekérni. Következőként az e variánssal a kérelemre végzett SCI-vizsgálat teljes eredménye és findingrészletei hasznosak. A tényleges elengedéskori hozzárendelés és a részletes Onapsis-policy továbbra nincs igazolva.


A skill alapváltozata már működő munkautasítás a helyi elemzéshez. A következő adatok az elengedéskor ténylegesen futó céges ellenőrzés pontos reprodukálásához hiányoznak. A menüpontok neve és elrendezése SAP-verziótól és bejelentkezési nyelvtől függhet; minden alábbi beállítást megjelenítésben nézz meg.

Első körben elég az elengedéskor használt variáns pontos neve és egy teljes QA-találat a kérelemszámmal. Ha ezek nem hozzáférhetők, az alábbi képernyőképek vagy exportok is megfelelőek. A fájlokat csatolhatod a beszélgetéshez vagy elhelyezheted a projekt 01_SOURCES mappájában, majd megadhatod a pontos fájlútvonalat. A többi adat fokozatosan is pótolható.

## 1. A tényleges ellenőrzési variáns és futtatási hely

Nyisd meg az ATC tranzakciót, azon belül ATC Administration / Administration → Setup → Basic Settings. Add át a Code Inspector / Global Check Variant és a referencia-/ellenőrző rendszer látható értékeit. Ha rendszer-szerep beállítás is rendelkezésre áll, annak megjelenítése segít megkülönböztetni a központi ellenőrzést a helyi módtól.

A fejlesztő rendszer alapértelmezett variánsa nem feltétlenül az összes céges elengedési kapu variánsa. Ha proxy-/referenciavariáns vagy egyedi ellenőrzés van, az ATC-felelőstől kérd az elengedéskor ténylegesen használt központi variáns nevét, a központi rendszer azonosítóját és a proxy hozzárendelést. Elég a név és a beállítási képernyő, hálózati belépési adatok nem szükségesek.

Forrás: [SAP – Configuring the Checked System](https://help.sap.com/docs/ABAP_PLATFORM_NEW/ba879a6e2ea04d9bb94c7ccd7cdac446/17eb1a1d504442b3ad438451197b937b.html), [SAP – Configuring the ATC on the Master System](https://help.sap.com/docs/ABAP_PLATFORM_NEW/ba879a6e2ea04d9bb94c7ccd7cdac446/e4dd736d540b439b8d320e6dbddaf94c.html).

## 2. A variáns teljes szabálylistája és paraméterei

Az SCI tranzakció kezdőképernyőjén a Check Variant / Ellenőrzési variáns részben írd be a pontos nevet. Válaszd a megfelelő globális/helyi nézetet, és nyisd meg megjelenítésre. Nyisd ki a kiválasztott ellenőrzések ágait, és a paraméterezett ellenőrzéseknél a paramétereket is mutasd meg. Proxyvariáns esetén a teljes tényleges szabálylista a központi rendszerből kérendő.

Átadható: a variáns exportja, ha a rendszer támogatja, vagy több képernyőkép a kijelölt szabályokról és a paramétereikről. A kezdőképernyő a variáns nevével önmagában nem tartalmazza a teljes szabálykészletet.

Forrás: [SAP – Check Variant](https://help.sap.com/saphelp_gbt10/helpdata/en/49/243ddf855616b6e10000000a42189d/content.htm?no_cache=true).

## 3. Egy teljes QA-futás eredménye

SCI esetén a megfelelő Inspection / Ellenőrzés bejegyzés Results / Eredmények nézetét add át. ATC esetén a rendelkezésre álló ATC Result Browser / eredménykezelés nézetből, vagy ADT-ben az ATC Problems nézetből származó eredmény alkalmas. Az elengedéskor megjelenő hibalistát és a találat hosszú szövegét is használhatjuk.

Szükséges tartalom: futás dátuma/azonosítója, variáns és ellenőrző rendszer, kérelem vagy objektumkör, a találat szabályazonosítója/tesztneve, üzenete, prioritása, objektuma, include-ja és sora. Ha valamelyik adat nincs a nézeten, ne találj hozzá értéket; jelöld hiányzóként. A puszta összesített hibaszám kevés a javításhoz. Ha exportálható, add át a teljes listát; különben a találat részletképe és az érintett kódrészlet is elég a kezdéshez.

Jelezd, ha az eredményt szűrték, baseline vagy jóváhagyott kivételezés érinti. Így az elengedéskori és a külön futtatott eredmény eltérése értelmezhető.

Forrás: [SAP – Creating Code Inspections](https://help.sap.com/docs/ABAP_PLATFORM_NEW/ba879a6e2ea04d9bb94c7ccd7cdac446/4926dff4c93016b8e10000000a42189d.html), [SAP – Launching ATC Check Run Explicitly](https://help.sap.com/docs/ABAP_PLATFORM_NEW/c238d694b825421f940829321ffa326a/4ec5a60b6e391014adc9fffe4e204223.html?locale=en-US&state=PRODUCTION&version=202310.002).

## 4. Kérelemszám és objektumlista

SE09 / SE10 tranzakcióban nyisd meg a vizsgált kérelmet és a feladatait. Add meg a főkérelem számát és az ellenőrizendő feladatok számát, valamint az objektumlistát. Ha csak egy feladat ellenőrzése szükséges, azt nevezd meg. A programhoz tartozó include-ok és az érintett osztályok neve is legyen látható.

A kérelemszám a későbbi engedélyezett MCP GetTransport olvasáshoz is elég kiindulásként; önmagában nem jogosít elengedésre vagy módosításra.

## 5. Rendszerverzió

SAP GUI: System / Rendszer → Status / Státus → SAP System Data / SAP-rendszeradatok → Component Information / Komponensinformáció, illetve a verziótól függő termékverzió-részletek. A SID, mandant, SAP_BASIS verzió és támogatási csomagszint hasznos; S/4-rendszernél az S4CORE megfelelő sora is. Ha nem férsz hozzá, a Basis-csapat meg tudja adni.

Átadható a releváns komponenssorok másolata vagy képe; a hostnév, telepítési szám és belépési adatok nem szükségesek ehhez a feladathoz.

Forrás: [SAP – SAP_BASIS verzió megtekintése a System Status alatt](https://help.sap.com/docs/SUPPORT_CONTENT/wdabap/3362186814.html), [SAP – Installed Software Component Versions](https://help.sap.com/docs/SAP_SUCCESSFACTORS_EC_S4_HCM_INTEGRATION/ff6b495d894a4685accf7e4bfa75da1b/4c97d126441f42b6b1040daa145610ca.html).

## 6. Elengedéskori szabályok és egyedi Onapsis-bekötés

SE03 → Administration → Global Customizing (Transport Organizer): a Check Objects when Request Released rész megmutatja a standard elengedési ellenőrzés engedélyezését. ATC → Administration → Setup → Basic Settings: a Transport Tool Integration / Behavior on Release rész mutatja a standard kapu viselkedését, verziótól függő elnevezéssel. Kérd az elengedést blokkoló prioritásokat és az esetleges baseline/kivételezési eljárást is.

A külön céges bővítés vagy Onapsis-integráció nem feltétlenül látszik itt. A belső ATC/QA/Onapsis-felelőstől kérendő: termék/verzió, szabálycsomag vagy policy neve, elengedéskori bekötés és futásindítás módja, valamint egy exportált eredmény részletes szabályazonosítóval. A konkrét céges tranzakció nevét nem ismerjük; ezt nem helyettesítjük kitalált tranzakcióval.

Forrás: [SAP – Setting Up ATC Transport Checking](https://help.sap.com/docs/SAP_NETWEAVER_AS_ABAP_751_IP/ba879a6e2ea04d9bb94c7ccd7cdac446/40c14df0a883467bb90ef5a70cee7cc2.html?version=7.51.16).

## Külön próba elengedés nélkül

ADT / Eclipse: Transport Organizer → kérelem vagy feladat jobb gomb → Run As → ABAP Test Cockpit With… → az igazolt variáns kiválasztása. Az eredmény az ATC Problems nézetbe kerül.

SAP GUI / SCI: hozz létre saját helyi Inspection bejegyzést, objektumkiválasztásként add meg a transzportkérelmet, majd az igazolt Check Variantot. Execute után Results. Ezt csak akkor kezeld az elengedési kapuval egyenértékű futásként, ha a tényleges eszköz, variáns, paraméterek és futtatási rendszer is megfelelnek; egy központi ATC/Onapsis-futás külön reprodukálást igényelhet. A fenti SAP futtatási útmutatók írják le a lépéseket.

## Minimális visszaküldhető adatlap

Másold ki, és azt töltsd ki, amit jelenleg tudsz. A többi maradhat ismeretlen.

~~~text
Rendszer / mandant: ismeretlen
SAP_BASIS / S4CORE és SP-szint: ismeretlen
Főkérelem / vizsgált feladat: ismeretlen
Ellenőrző eszköz és rendszer: ismeretlen
Elengedéskor használt variáns / policy: ismeretlen
Szabálylista és paraméterek fájlja vagy képei: nincs még átadva
QA-eredmény fájlja vagy teljes találatszöveg: nincs még átadva
Kívánt kimenet: magyarázat / külön diff / engedélyezett helyi javítás
~~~

SAP-kapcsolat esetleges újrapróbálása külön felhasználói kérés; a kézi export átadása nem oldja fel a munkaterület kapcsolati leállását. Jelszót, tokent vagy session cookie-t ne küldj.
