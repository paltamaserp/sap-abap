# SAP QA-skill: adatgyűjtés és MCP-lehetőségek

Státusz: **WIP**, 2026-10-18. A felhasználó a skillhez szükséges információk MCP-s összegyűjtését kérte. Új aktív SAP-adatot nem sikerült beszerezni; az alábbi eszközlehetőségek a rendelkezésre álló MCP-eszközleírásokból származnak.

## Elérhető MCP-képességek

| Szükséges adat | Elérhető eszköz / mód | Igazoltság |
|---|---|---|
| Telepített SAP-komponensek és verziók | GetSqlQuery: SELECT component, release, extrelease FROM cvers | A lekérdezés jóváhagyási ellenőrzésen elutasítva, nincs SAP-válasz. A komponensverzió önmagában nem bizonyítja a központi ATC-konfigurációt. |
| Saját kérelmek, feladatok és objektumok | ListTransports, GetTransport | Eszköz elérhető; SAP-hívás nem történt. Konkrét vizsgálandó kérelem még nincs megadva/kiválasztva. |
| Aktív vagy inaktív programok, osztályok, include-ok | GetProgram, GetClass, GetInclude és kapcsolódó olvasó eszközök | Eszköz elérhető; ebben az adatgyűjtésben nem hívtuk. |
| ATC/SCI-beállítások, variánsok, paraméterek | GetTable, GetSqlQuery, GetTableContents, szükség esetén az érintett standard forrás olvasása | Feltételes: a tényleges tárolás, elérhetőség és jogosultság még felderítendő. Nincs külön variánslekérő eszköz a jelenlegi eszközkészletben. |
| Elengedési bővítések és céges bekötés | GetEnhancements, GetEnhancementSpot, GetEnhancementImpl, forrásolvasás | Feltételes: előbb az érintett objektumokat kell azonosítani; a szabványos beállítások olvasása nem bizonyítja az összes egyedi kaput. |
| Korábbi ATC/SCI/Onapsis eredmény teljes tartalma | Nincs külön ATC/SCI/Onapsis eredményolvasó az elérhető eszközök között | Elérhető tárolás vagy export nélkül nem ígérhető automatikus beszerzés. |
| Teljes ATC/SCI/Onapsis futtatás | Nincs külön futtató az elérhető eszközök között | A CheckProgram/CheckClass/CheckPackage leírása szintaxisellenőrzésről szól; nem azonos a teljes QA-variáns futtatásával. |

## Helyben már rendelkezésre álló adatok

- [Projektbrief](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/00_BRIEF.md>): az ATC-variáns mező kitöltetlen. Az aktív variáns neve nem ismert.
- [ABAP QA-ellenőrzőlista](<../../../../../%5B01%5D%20system/ABAP-QA-CHECKLIST.md>): a felhasználó korábbi ZPR_DOC_STATUS QA-találatai, az üzenetliterálok, a rendezett tábla beszúrása és a TERTI index-/törlési kérdés helyi kezelése. Ezek valódi korábbi visszajelzésekből készült összefoglalók, nem teljes nyers ATC-exportok.
- [Hidden OK-Codes javítás](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/03_DRAFTS/2026-10-17_cockpit-hidden-okcodes_WIP.md>): konkrét cockpit-példa és helyi javító diff; az ellenőrzés azonosítója/variánsa a dokumentum szerint nem volt megadva.
- [ZPR_QM munkaforrás](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/03_DRAFTS/2026-10-16_cockpit_WIP/ZPR_QM.abap>): a megőrzött megjegyzés Onapsis 2182 / FINAL ellenőrzést említ. Ez a megjegyzés nem igazolja az aktív Onapsis-telepítést, verziót vagy variánst.
- oneERP névkonvenció és a munkaterület QA-szabályai rendelkezésre állnak; az aktuális rendszer által ténylegesen futtatott szabálykészletet nem helyettesítik.

## Elutasított kapcsolati kísérlet

Tervezett, kizárólag olvasó hívás: GetSqlQuery, legfeljebb 80 sor, SELECT component, release, extrelease FROM cvers.

Az automatikus jóváhagyási ellenőrzés elutasításának indoka:

> Az SAP-kapcsolat korábbi sikertelensége után az AGENTS.md kifejezetten tiltja az újrapróbálást, kivéve a felhasználó egyértelmű egyszeri újrapróbálási engedélyét; a tervezett SAP SQL-lekérdezés ezt megsérti.

Ez nem SAP-válasz és nem új HTTP 401. Másik SAP-eszközzel, közvetlen HTTP-val vagy közvetett úton nem próbáltuk megkerülni. A [gyökér AGENTS.md](<../../../../../AGENTS.md>) rögzíti: „Egy új kapcsolati ellenőrzést kizárólag a felhasználó kifejezett újrapróbálási kérése engedélyez; ez egyetlen új kísérletre szól.”

## Folytatás kifejezett egyszeri újrapróbálási engedély után

Elsőként a fenti CVERS-olvasás ellenőrzi a hozzáférést, és siker esetén már hasznos verzióadatot ad. Kapcsolati/hitelesítési hiba vagy timeout után minden SAP-hozzáférés ismét leáll. Sikeres hozzáférés esetén a csak olvasó adatgyűjtés folytatható: transzportok azonosítása, ATC/SCI konfiguráció és variáns tárolásának felderítése, az elérhető definíciók és paraméterek mentése, valamint a nyitott hiányok pontos felsorolása.

Nincs felhatalmazás SAP-objektumok létrehozására, módosítására, aktiválására vagy transzport elengedésére. Az adatgyűjtésből készülő skill nem fogja a szintaxisellenőrzést teljes ATC/Onapsis eredményként jelenteni.

## Elkészült skill-alapváltozat

A felhasználó további kérésére az elérhető helyi anyagokból elkészült és a személyes skillmappába települt a [sap-transport-qa](<2026-10-18_sap-transport-qa_WIP/sap-transport-qa/SKILL.md>) WIP-alapváltozata. A [hiányzó adatok beszerzési útmutatója](<2026-10-18_sap-transport-qa_WIP/sap-transport-qa/references/adatok-beszerzese.md>) konkrét képernyőket és átadandó adatokat sorol fel. Új SAP-kísérlet vagy élő konfigurációolvasás nem történt.
