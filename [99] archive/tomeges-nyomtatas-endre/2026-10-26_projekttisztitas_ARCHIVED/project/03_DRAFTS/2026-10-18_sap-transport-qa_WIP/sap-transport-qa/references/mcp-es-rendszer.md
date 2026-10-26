# MCP-képességek és ismert rendszerhelyzet

Állapot: 2026-10-18, WIP. Ez az állapot a sap-abap-main munkaterület tomeges-nyomtatas-endre projektjére vonatkozik. Más rendszerre nem vihető át automatikusan.

## Kapcsolati korlát

A munkaterület gyökér AGENTS.md fájlja a 2026-10-13-i felhasználói utasítás alapján rögzíti: az SAP ADT-kapcsolat első hitelesítési/kapcsolati hibája vagy timeoutja után minden SAP-hozzáférést le kell állítani, a következő körökben és munkamenetekben is. Nem szabad másik SAP-eszközzel, közvetlen HTTP-val vagy közvetett úton újrapróbálkozni. Kizárólag kifejezett egyszeri újrapróbálási kérés enged egy új elérési kísérletet; sikertelen eredmény után ismét leállás következik. Sikeres kísérlet esetén az engedélyezett olvasási feladat folytatható a következő hibáig. A skill meghívása vagy általános adatgyűjtési kérés önmagában nem oldja fel a fennálló leállást.

A legutóbbi tervezett olvasás SELECT component, release, extrelease FROM cvers volt, legfeljebb 80 sorral. Az automatikus jóváhagyási ellenőrzés elutasította az egyértelmű egyszeri újrapróbálási engedély hiánya miatt. Ez nem SAP-válasz és nem új HTTP 401. A felhasználó ezt követően a hozzáférhető anyagokból kérte a skill alapváltozatát; új SAP-kísérlet nem történt. A későbbi használatkor a legújabb felhasználói utasítást és naplót ellenőrizd, ne ezt a dátumozott állapotot tekintsd örök tiltásnak.

## Aktuális MCP-leltár

Az alábbiak az eszközleírásokból ellenőrzött képességek; a tényleges rendszerhozzáférés nincs igazolva. Az elérhető eszközkészlet később változhat.

| Adat / művelet | Eszközcsalád | Korlát |
|---|---|---|
| Saját kérelmek és feladatok listája | ListTransports | Ne válassz önkényesen kérelmet a futtatáshoz; kéréshez kötött olvasásra szűkíts. |
| Kérelem státusza és objektumai | GetTransport | A főkérelem és feladatai objektumkörét is tisztázd. |
| Források | GetProgram, GetClass, GetInclude, GetFunctionGroup, GetProgFullCode | Az aktív/inaktív állapotot és az olvasás időpontját rögzítsd. |
| Komponensverziók | GetSqlQuery vagy GetTableContents a CVERS táblára | Ne kérj kapcsolatparamétert, jelszót, CSRF tokent vagy cookie-t a felhasználótól. |
| Variáns, paraméterek és futási konfiguráció | GetTable, GetSqlQuery, GetTableContents; szükség szerint standard forrásolvasás | Nincs dedikált variánsolvasó. A tárolást előbb definícióval igazold; ne találj ki táblaneveket. Egy bináris/serializált adatmező nem értelmezett variáns. |
| Céges elengedési bővítések | GetEnhancements, GetEnhancementSpot, GetEnhancementImpl | Azonosított kapcsolódási pont kell; a standard beállítás önmagában nem mutat minden céges kaput. |
| Szintaxisellenőrzés | CheckProgram, CheckClass, CheckPackage és a többi Check* | A jelenlegi leírás szerint szintaxisellenőrzés, nem teljes ATC/SCI/Onapsis. |
| Teljes QA-futtatás / QA-eredményolvasás | Külön erre szolgáló eszköz most nincs | Nem helyettesíthető kitalált eszközzel vagy tetszőleges ABAP-kódfuttatással. |

## Felhasználó által átadott variánslista és képernyőrészlet

2026-10-18-án a felhasználó az alábbi neveket és leírásokat adta át. Ez felhasználói bizonyíték az elérhető variánsnevekről; nem friss MCP-olvasás. A képernyőrészlet nem tartalmaz SID-et, mandantot, kiválasztott globális variánst vagy teljes konfigurációt.

| Variáns | Átadott leírás |
|---|---|
| Z_CONTROL_FOR_CODE | Z_CONTROL_FOR_CODE |
| ZABAP_CLEAN_CORE_DEVELOP | Variant for clean core development |
| ZABAP_CLEAN_CORE_DEVELOP_MIN | Variant for clean core development |
| ZABAP_CLOUD_DEVELOPMENT | Default ATC variant for ABAP Cloud Development |
| ZABAP_CLOUD_DEVELOPMENT_MIN | Default ATC variant for ABAP Cloud Development |
| ZCA_CP_NC_CHECKS | ZCA_CP_NC_CHECKS |

A képen a Code Inspector / Behavior on Release mező értéke: **Disable "Code Inspector" as test driver**. Ez a Code Inspector tesztdriver-szerepére vonatkozó beállítás; önmagában nem bizonyítja sem a teljes QA kikapcsolását, sem azt, hogy melyik ATC-/Onapsis-variáns fut. Az SAP ATC-t használó exportellenőrzési dokumentációjában ez kifejezetten megadott beállítás: [SAP – Transport Checks](https://help.sap.com/docs/CloudALM/877c96cf971648b09ee0d0a64f7f4fef/2ae5a1bf1b6f4d46a38b11f6c6792425.html?locale=en-US&version=LATEST). A konkrét rendszerről a képből Cloud ALM-használat sem állapítható meg.

A Z_CONTROL_FOR_CODE megjelenítésére kért következő felhasználói képen a **Control for Code Check → Control for Code by Onapsis** ellenőrzés be van jelölve. A kivágásban a variánsnév és SID nem látható; a Z_CONTROL_FOR_CODE-hoz kapcsolást az előző kérés és a válasz kontextusa adja. Az Onapsis-bekötés így képernyőbizonyítékra támaszkodik, nem puszta névkövetkeztetésre. A kép beállítási állapotot mutat, nem sikeres vizsgálati eredményt.

Az Onapsis gyártói dokumentációja szerint a Control for Code tesztek ATC/SCI-integrációval futtathatók, és a findingok ezekben az eszközökben megjeleníthetők: [Onapsis – Technical Specifications, Integrated Scanner for ATC/SCI](https://onapsis.com/wp-content/uploads/technical-specifications-for-onapsis-products.pdf). A kiválasztott integrációs ellenőrzés nem tárja fel a mögöttes konkrét teszteseteket, prioritásokat, policyt vagy kivételeket. A képből ne állítsd, hogy minden Onapsis-teszt engedélyezett, és ne keverd össze a Control for Code-ot a külön Control for Transports termékkel.

A ZCA_CP_NC_CHECKS tartalma még nem ismert. A többi négy variáns clean-core/cloud célját csak az átadott leírás jelzi; tényleges szabálylistájuk és a MIN-változatok tartalma nincs ellenőrizve. Egyik variáns sincs igazolva elengedéskori alapértelmezésként.

Következő hasznos bizonyíték: Z_CONTROL_FOR_CODE variánssal a megadott kérelemre végrehajtott SCI-vizsgálat teljes eredménye, findingrészletekkel (azonosító, üzenet, prioritás, objektum/include/sor), valamint a tényleges elengedési hozzárendelés. A részletes Onapsis-policy/tesztesetek paraméterezéséhez szükség esetén az Onapsis-felelős exportja kell; a képernyőn látható paraméterkezelést csak megjelenítésben használd, a beállításokat ne módosítsd.

## Mi ismert és mi hiányzik?

Ismert: a fenti hat variáns neve/leírása, a Code Inspector tesztdriver-beállítás és az Onapsis-ellenőrzés kijelölése felhasználói képernyőbizonyítékból; továbbá a helyi ABAP-források és a korábbi felhasználói QA-találatok egy része, oneERP névkonvenció, a workspace QA-ellenőrzőlistája és a kapcsolati szabály.

Nem igazolt: SID/mandant és telepített komponensverziók; célzott transzport száma; ATC ellenőrző rendszer; lokális/központi futtatási mód; az elengedéskor ténylegesen használt variáns és paraméterei; blokkoló prioritások, baseline/kivételezés; céges bővítés; az Onapsis pontos verziója, futóképessége és teljes szabálykészlete; teljes, nyers QA-futási eredmény. A program fejlécében szereplő DHC/S4HANA és egy forráskomment Onapsis-említése nem élő rendszerbizonyíték.

A meglévő anyagok workspace-relatív helyei:

- [01] system/ABAP-QA-CHECKLIST.md
- [02] context/oneERP ABAP Development Guideline_V 22 00 published.pdf
- [03] projects/tomeges-nyomtatas-endre/00_BRIEF.md és _LOG.md
- A projekt 03_DRAFTS/2026-10-18_sap-qa-skill-adatgyujtes_WIP.md leltára.

Ezeket az aktuális workspace-ben keresd. Az abszolút felhasználói útvonalat ne égesd a működésbe. Hiányukban a csomag példái és a felhasználó által adott export alapján folytatható az elemzés.
