# ZCL_PR_ADDRESS – ellenőrzési jelentés

2026-10-28 · Státusz: WIP · Ellenőrzés: **RÉSZLEGES** · Tartalmi review: **4 javítandó találat**.

## Hatókör és sikerfeltételek

A felhasználó meglévő osztály ellenőrzését kérte. Aktív SAP-forrás és metaadat, aktív szintaxisvizsgálat, tesztinclude és a címforrás CDS-definíció vizsgálata történt. SAP-objektum nem változott, aktiválás és üzleti adatfuttatás nem történt.

Sikerhez: azonosított aktív változat; nulla szintaxishiba és kezeletlen figyelmeztetés; releváns, befejezett ABAP Unit-futás; azonosított QA-variánssal igazolt ATC/SCI/Onapsis-kapu. A tartalmi találatokat a szintaxis sikere nem zárja le.

Az MCP az aktuálisan konfigurált SAP-kapcsolatot használta. A metaadat eredeti rendszere DHC, csomag ZPR_FUNC, utolsó módosítás 2026-10-23T10:22:20Z. Az eredeti rendszer nem a ténylegesen kiszolgáló SID bizonyítéka; a kapcsolt SID és mandant nincs külön igazolva, ezért a normalizált jelentésben null. Aktív verziót a ReadClass és CheckClass válasza explicit igazol.

## Javítandó találatok

### 1. [P2] Az eltérő fizető nem alapértelmezett címe nem található meg

Hely: [ZCL_PR_ADDRESS.abap](ZCL_PR_ADDRESS.abap), CREATE_PAYER_ADDR, 342–350. sor; függőség: [CDS](ZPRT_I_DEFAULT_BP_ADDRESS.asddls), 12. sor.

A kód a FKKVKP-ADRRE-ben kijelölt címazonosítót a ZPRT_I_DEFAULT_BP_ADDRESS nézetben keresi. A frissen olvasott CDS az I_BusinessPartnerDefaultAddr nézetre épül, így kizárólag alapértelmezett BP-címeket szolgáltat. Ha ADRRE egy érvényes, de nem alapértelmezett fizetőcímet jelöl, a kiválasztás üres lehet, és ZCX_FORM_MESSAGE_ERROR kivétel szakítja meg a feldolgozást.

Javaslat: a kijelölt címet olyan címforrásból kell lekérni, amely az alternatív címet is tartalmazza; a partnerkapcsolatot és érvényességet az üzleti szabály szerint kell ellenőrizni. Az alapértelmezett partnernév és a kijelölt cím kezelése váljon egyértelművé. Regresszió: ABWRE alapértelmezett címe A, ADRRE érvényes másodlagos címe B; az eredmény B címe legyen, kivétel nélkül. Ez forrásból levezetett eset, nem SAP-ban végrehajtott teszt.

### 2. [P2] A külföldi város és irányítószám összetapad

Hely: FORMAT_ADDRLINES, 423. és 439. sor.

Mind az utcás, mind a postafiókos külföldi ág elválasztó nélkül fűzi össze a city és post_code mezőt. Példa: Berlin + 10115 → Berlin10115. A CONCATENATE nem tartja meg az operandusok végi kitöltő szóközöket.

Javaslat: legalább SEPARATED BY space használata, az ország szerinti sorrend külön üzleti szabály. Regresszió: külföldi utcás és postafiókos címen külön ellenőrizni a címsor elválasztását.

### 3. [P2] Az egysoros vevőcím elveszíti a postafiókot

Hely: GET_ONLY_CUSTOMER_ADDR, 693–707. sor; összevetés: GET_CUSTOMER_ADDR 145–149. sor és FORMAT_ADDRLINES 414–442. sor.

A címolvasás postafiók esetén a postafiók irányítószámát teszi post_code-ba. A többsoros formázó a postafiókot jeleníti meg, az egysoros metódus viszont mindig a street_and_hnum és hnum_extension mezőt fűzi össze, a po_box mezőt egyáltalán nem olvassa. Így az eredményből kimarad a postafiók, és az utcacím a postafiók irányítószámával keveredhet.

Javaslat: az egysoros formázóban is legyen postafiókos ág, a közös formázási szabályokkal összhangban. Regresszió: po_box=123 és eltérő utcai/postafiókos irányítószám; az egysoros cím tartalmazza a postafiókot és annak irányítószámát.

### 4. [P3] Téves mező kerül az eltérő fizető címének hibaüzenetébe

Hely: CREATE_PAYER_ADDR, 347–350. sor.

A SELECT az ADRRE címet keresi, de sikertelenség esetén a MESSAGE az ADRRA értékét adja át. Ha eltérnek vagy ADRRA üres, a diagnózis más címet vagy üres értéket mutat.

Javaslat: az üzenetben a ténylegesen keresett ADRRE szerepeljen. Az e008 üzenet üzleti szövegét külön ellenőrizni kell; ezt ebben a körben nem olvastuk ki.

## Tisztázandó üzleti szabály

GET_FORMED_CUSTOMER_ADDR 475. sor és GET_ONLY_CUSTOMER_ADDR 693. sor a vevő címét a postázási cím országa szerint rendezi. Ha a vevő HU, de a postázási cím DE vagy még nincs kitöltve, a vevőcím a külföldi ágra kerül. A forrás kommentje kifejezetten ezt a postázási ország-alapú döntést írja elő, ezért a szándékosságot üzleti megerősítés nélkül nem minősítjük biztos hibának. Ha a vevőcím saját országának kell irányadónak lennie, GS_CUSTOMER_ADDRESS-COUNTRY alapján kell dönteni. A külföldi címből hiányzó ország megjelenítése és az országfüggő sorrend szintén követelményegyeztetést igényel.

A konstruktor csak a bemeneteket másolja; a publikus címattribútumok feltöltését a hívóktól várhatja. Hívóelemzés nélkül ezt nem minősítjük inicializálási hibának.

## Objektumonkénti ellenőrzés

| Objektum | Vizsgálat | Eredmény |
|---|---|---|
| ZCL_PR_ADDRESS | Aktív forrás | Sikeresen kiolvasva; a mentett forrás e válasz LF-sortörésre normalizált másolata. |
| ZCL_PR_ADDRESS | CheckClass, active | 0 hiba, 0 figyelmeztetés, 0 információ; feldolgozás befejezett. Ez szintaxis, nem ATC. |
| ZCL_PR_ADDRESS | ABAP Unit | **Nem futott**: a metaadat hasTests=false; az aktív testclasses include csak sablonkommentet tartalmaz. Tesztpárt nem találtunk; érdemi üzleti logika miatt nem adható mentesség. Külső tesztosztályok teljes keresése nem történt. |
| ZCL_PR_ADDRESS | ATC/SCI/Onapsis | **Nem futott**: a mostani 175 SAP-eszköz között nincs dedikált QA-futtató; az adott osztályra vonatkozó variáns és QA-eredmény nem áll rendelkezésre. |
| ZPRT_I_DEFAULT_BP_ADDRESS | Függőségi forrásolvasás | Aktív CDS-definíció sikeresen kiolvasva; önálló syntax/Unit/QA nem futott, nem volt módosított célobjektum. |

Az összesítés RÉSZLEGES a hiányzó Unit-/QA-eredmény és a nem igazolt rendszer/mandant miatt. A négy tartalmi találat külön nyitott javítási pont. Teljes siker nem állítható.

## Bizonyítékok

- read-class.json: teljes ReadClass-válasz, aktív főforrás és metaadat.
- check-class.json: teljes CheckClass-válasz.
- read-tests.json és testclasses.abap: az aktív tesztinclude.
- read-address-view.json és ZPRT_I_DEFAULT_BP_ADDRESS.asddls: az aktív címnézet.
- tool-inventory.json: az ellenőrzéshez rendelkezésre álló SAP-eszközök.
- jelentés.json: gépi összesítés forrás- és bizonyítékhash-ekkel.
- local-validation.json: a helyi jelentésellenőrző futtatásának tényleges eredménye.

A helyi integritásellenőrzés 11 fájl hash-egyezését és a mentett osztályforrás MCP-válasszal való azonosságát igazolta. A kötelező validate_report.py futtatását megkíséreltük, de a python.exe a környezetben nem hozzáférhető, ezért a Python-összesítő **nem futott**; nem állítunk tőle sikeres ellenőrzést. A kézi összesítés RÉSZLEGES eredménye megmarad, automatikus összesítőeredmény nincs.

A példák statikus levezetések, nem futtatott ABAP Unit-tesztek. SAP-kapcsolati hiba és automatikus jóváhagyási elutasítás ebben a körben nem történt.

