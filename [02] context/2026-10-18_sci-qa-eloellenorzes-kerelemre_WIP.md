# QA-előellenőrzés transzportkérelemre — SCI (Code Inspector)

Státusz: **WIP**. Rögzítve: 2026-10-18, a felhasználó képernyőképes leírása alapján, SAP Help és SAP Community forrásokkal pontosítva.
A képernyőnevek a magyar bejelentkezési nyelv szerintiek, zárójelben az angol megfelelő.

## Mire jó

Elengedés előtt saját magunk lefuttatjuk a céges ellenőrzési variánst (`Z_CONTROL_FOR_CODE`, benne a *Control for Code by Onapsis* ág) a transzportkérelem összes objektumára, és a találatokat még elengedés előtt javítjuk.

> **Korlát:** nincs igazolva, hogy az elengedéskor futó kapu ugyanezt a variánst, ugyanezekkel a paraméterekkel és ugyanabban a rendszerben futtatja (lásd `[03] projects/tomeges-nyomtatas-endre/_LOG.md`, 2026-10-18). Ez a futás ezért **előellenőrzés**: jó jelzés, de nem garancia arra, hogy az elengedés nem akad meg.

## Előfeltételek

- Minden objektum **aktív** a kérelemben (SE80 / ADT aktiválás). Az ellenőrzés az aktív verziót nézi; az aktiválatlan módosítás nem kerül bele.
- Ismert a kérelem száma (SE09/SE10). Főkérelem vagy feladat is megadható.
- A `Z_CONTROL_FOR_CODE` ellenőrzési variáns elérhető. Ha a névre „nem létezik” üzenet jön, a név melletti **Helyi/Globális** kapcsológombbal válts nézetet.

## Lépések

### 1. Kezdőkép — `SCI`

| Mező | Érték | Megjegyzés |
|---|---|---|
| Felelős (Person Responsible) | saját felhasználó (pl. `X0134`) | automatikusan kitöltődik |
| Inspekció → Név | `Z_QA_ELOELLENORZES` | a név előtti gomb: helyi (csak saját) vagy globális ellenőrzés; globálishoz külön jogosultság kell |
| Inspekció → Verz. | üresen hagyható | a rendszer adja ki (lásd 2. lépés) |
| Objektumhalmaz (Object Set) | **üres** | kérelemre futtatunk, nem kell objektumhalmaz |
| Ell.változat (Check Variant) | `Z_CONTROL_FOR_CODE` | itt is megadható, a következő képen is |

Az *Inspekció* blokkban: **Létrehozás** (Create — üres lap ikon).

### 2. Vizsgálat létrehozása (Create Inspection)

- **Verzió:** a rendszer automatikusan ad verziószámot. Ha a `Z_QA_ELOELLENORZES` már létezik, a következő szabad szám jön (a képen `001` létezett, ezért `002` lett). Így ugyanaz az ellenőrzésnév minden futáshoz újrahasználható; a régi verziók eredményei megmaradnak.
- **Törlés dátuma:** a rendszer javasolja (a képen 2026-10-18 + 50 nap = 2026.12.07). Ezután az ellenőrzés és az eredménye törlődik; ha tovább kell, írd át.
- **Leírás:** automatikusan `<név>__<verzió>`; nyugodtan átírható, pl. a kérelem számára és a témára.
- **Objektum kiválasztása:** válaszd a **Kérelem/feladat** (Request/Task) rádiógombot, és add meg a számot, pl. `DHCK906030`.
- **Ell.változat:** `Z_CONTROL_FOR_CODE` (ha az 1. lépésben megadtad, már ki van töltve).
- **Mentés** (Ctrl+S).

### 3. Végrehajtás

A vizsgálat fejlécében a státuszjelző eleinte **piros** (nincs lefuttatva / ütemezve).

- **Végrehajtás** (Execute, F8) — azonnal, a saját munkamenetben fut. Egy kérelemnél ez a szokásos választás.
- **Végrehajtás…** (Execute… — a „…” jelű ikon) — párhuzamosan egy szervercsoporton, választhatóan **háttérben**. Nagy kérelemnél vagy időtúllépésnél használd. Ilyenkor a futás végéig frissíteni kell a képet (Megjelenítés ↔ Módosítás); később a *Név* mező F4-súgójával is visszakereshető.

A státusz lehet: **ütemezve/nem futott**, **végrehajtva** (zöld), vagy **megszakítva** (a futás hibára futott, nincs eredmény).

### 4. Eredmények

Végrehajtott állapotban: **Eredmények** (Results — tekercs ikon, Shift+F6).

Az eredményfa felépítése: *Ellenőrzések listája → Control for Code Check → Control for Code by Onapsis → Figyelm. (Warnings) → jelentéskódok*. A jobb oldali oszlopok: **Hiba** (Error) · **Figyelmeztetés** (Warning) · **Információ**. A fa ágait kibontva elérhetők az egyes találatok:

- **duplakattintás** a találat sorára → a forráskód érintett sorára ugrik;
- az **i** (Információ) ikon → a szabály hosszú leírása, javítási útmutatóval.

Példa a 2026-10-18-i futásból (`DHCK906030`, verzió 002): **0 hiba · 209 figyelmeztetés · 141 információ**. A leggyakoribb jelentéskódok:

| Kód | Szabály | Figyelm. |
|---|---|---|
| 0317 | Modification of Global Variables in Subroutine | 128 |
| 0245 | Hard-Coded Text in MESSAGE … WITH | 19 |
| 0068 | Incomplete CASE | 8 |
| 0089 | Usage of LOOP AT itab INTO | 7 |
| 0079 | Low Performance Table Access on 'Standard' Tables (pl. `ZPR_CLOSE_STOCK`, `READ TABLE lt_fields INTO ls_field`) | 6 |

A javításhoz a teljes listát (kód, objektum, include, sor) érdemes exportálni vagy átadni; az összesített szám önmagában kevés. Hogy melyik prioritás akasztja meg az elengedést, még nincs megerősítve.

### 5. Ismételt futtatás javítás után

Az 1. lépés kezdőképén ugyanazzal a névvel **Létrehozás** → új verzió készül (vagy a vizsgálatban: *Új verzió létrehozása* / Create New Version). Ugyanazt a kérelmet és variánst kell megadni, majd **Végrehajtás** → **Eredmények**. A két verzió eredménye összevethető.

## Eltérések az eredeti leíráshoz képest

1. A **Végrehajtás** a *Vizsgálat létrehozása* képernyőn van, mentés után; az eredményeket utána, külön gombbal kell megnyitni.
2. A verziót nem kell kézzel átírni: a kezdőképen látott `001` helyett a rendszer magától adta a `002`-t, mert a `001` már létezett.
3. Az Objektumhalmaz üresen maradhat; a kérelem a *Kérelem/feladat* választóval adható meg.
4. Előtte minden objektumot aktiválni kell, különben az ellenőrzés a régi, aktív verziót nézi.
5. A törlés dátuma után az eredmény eltűnik; ha bizonyítéknak kell, előtte exportáld.

## Források

- SAP Help — Creating Code Inspections: https://help.sap.com/saphelp_em92/helpdata/en/49/26dff4c93016b8e10000000a42189d/content.htm
- SAP Help — reusable code inspection (Execute / Execute…, státusz, Create New Version): https://help.sap.com/saphelp_em92/helpdata/en/68/9c9e5a73624b40913a9c9de829bbfc/content.htm
- SAP Community — SAP Code Inspector (SCI), eredmények Shift+F6, verzióléptetés: https://community.sap.com/t5/additional-blog-posts-by-members/sap-code-inspector-sci/ba-p/12831723
- Kapcsolódó belső anyag: `[01] system/ABAP-QA-CHECKLIST.md`, `[01] system/TESTING-TOOLS.md`, `[03] projects/tomeges-nyomtatas-endre/03_DRAFTS/2026-10-18_sap-transport-qa_WIP/sap-transport-qa/references/adatok-beszerzese.md`
