# ZPR_CREATE_STOCK – naplózási igény állapota

Dátum: 2026-10-22. Státusz: **WIP**. Helyi, statikus forrásellenőrzés; SAP-elérés és kódmódosítás nélkül.

**Későbbi frissítés, 2026-10-22:** a felhasználó új MCP-letöltési kérésére időközben valódi aktív forrás került a `05_FINAL/abap-2026-10-22/` könyvtárba. A friss ZPR_CREATE_STOCK deklarációja helyes; a ZCL_PR_LOG forrása is rendelkezésre áll, opcionális IV_EXT_ID konstruktorparaméterrel. A mai CREATE_STOCK XML-feltöltési blokkja kommentelt, ezért az alábbi, történeti forrásból levont részleges teljesítési megállapításokat újra kell értékelni. Ez a jelentés az eredeti helyi ellenőrzés bizonyítékát őrzi. A friss export 25 / 28 objektum után, a ZPRB_EMAIL_SLOG típuslekérés HTTP 404 hibájánál leállt; két táblatípus és C01 hiányzik. [Friss leltár](<../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/05_FINAL/abap-2026-10-22/README.md>).

## Eredmény

A négy kért naplózási pont összességében **még nincs kész**. A valódi stockképző forrásban meglévő naplózás csak részben fedi az igényt. Az aktív SAP-állapot nincs ellenőrizve; tényleges futási darabszámokat ebből nem lehet megadni.

## Források és korlátok

- Elsődlegesen ellenőrzött fájl: `05_FINAL/abap-2026-10-17/ZPR_CREATE_STOCK.abap`. A fájlnévvel és a hozzá tartozó XML-metaadattal ellentétben a deklarációja `REPORT ZPR_CLOSE_STOCK` (1. sor), és lezárási logikát tartalmaz. Ebből a stockképzés állapota nem igazolható.
- A jelenlegi fájl SHA256 értéke `99c57aa7a2703d2b094adef600359b72ea45bb3064f630c36cfbff8ac2a06e5e`; a 2026-10-17-i exportmanifesztben szereplő érték `31a042c2de93141b3eb8da187728355a041759d7321bf55bd389b42936e32d84`. A jelenlegi példány tehát nem egyezik az eredetileg jegyzékbe vett exporttal. A változás oka és időpontja nem igazolt.
- A valódi stockképző logika ellenőrzési alapja a megőrzött `[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/project/05_FINAL/abap-2026-10-16/ZPR_CREATE_STOCK.abap` (workspace-gyökérhez viszonyított útvonal). SHA256: `7432bf4cd1b9b520a627688c8395143b5ae7c65b8926c4aaad27c7452328162c`. Az alábbi sorszámok erre vonatkoznak. Ez történeti referencia, nem a mai aktív állapot igazolása.
- Kiegészítő ellenőrzés: `01_SOURCES/DHC/ZPR_CREATE_STOCK.abap`; ebben is ugyanaz a fő stockképzési naplózási minta látható, a későbbi ALV DOC_COUNT kiegészítés nélkül.
- A `ZCL_PR_LOG` és `ZCL_PR_INSPIRE_GW` implementációja, illetve a `ZPR_FUNC` 006/007 üzenetek szövege nem állt rendelkezésre az ellenőrzött helyi forrásokban. Az osztályokon belüli esetleges további naplózás és időbélyegzés nem igazolható.

## Követelményenként

| Kért adat | Helyi állapot | Forrásbizonyíték / hiány |
|---|---|---|
| Kijelölt PACKAGE_ID-k száma és a hozzájuk tartozó összes DOC_NO darabszáma | **Hiányzik a naplóból.** | A kiválasztott csomaglista elkészül (174–180), és a szabad csomagok száma ellenőrzött (185–190), de nincs róluk összesítő naplósor. A `GET_PACKAGE_DOC_COUNTS` (835–861) csomagonként az összes DCQM-sort számolja, de kizárólag az ALV DOC_COUNT mezőjét tölti; ez nem naplóbejegyzés. |
| EXBILLDOCNO / nyomtatási sorok száma | **Részben megvan.** | A `ZPR_FUNC` 006 üzenet `LINES( lt_file )` és stockazonosító paraméterrel kerül naplóba (263–265). Ez a feltöltésre előkészített XML-fájlok száma. A dokumentumlista DCQM–DOC_DATA INNER JOIN-ból jön (200–206), ezért az XML nélküli dokumentumokat nem számolja; DISTINCT sincs. Nem tekinthető automatikusan az összes nyomtatási sor vagy egyedi DOC_NO számának. |
| Inspire-hívás eleje és vége | **Részben megvan.** | Az `UPLOAD_FILES` előtt 006 (263–266), a `TRIGGER_STOCK_COMPLETION` előtt 007 (275–282) naplósor van. Nincs hívásonkénti, közvetlenül a visszatéréshez kapcsolt sikeres befejező sor és explicit kezdő/záró időadat. A 031 sikerüzenet csak az üzleti adatmentés és COMMIT után kerül naplóba (328–330), ezért nem a távoli hívás pontos befejezését jelöli. Hibaágak léteznek (267–270, 283–288, 333–342). |
| STOCK_ID mint külső naplóazonosító | **A riportban nincs bekötve.** | A napló még a stockazonosító képzése előtt jön létre (80–82), csak objektum/alobjektum átadással. A stockazonosító a 216. sorban készül; később üzenetparaméterként és Inspire-paraméterként szerepel, de külső naplóazonosítóként nincs átadva vagy beállítva. A naplóosztály támogatott interfészét külön ellenőrizni kell. |

## Következő szükséges lépések

1. A helyes, aktuális ZPR_CREATE_STOCK forrás azonosítása; a FINAL fájlnév/programnév és hash-eltérés rendezése az eredeti példány megőrzésével.
2. A kijelölt csomagokra futáskori összesítő napló: csomagszám és teljes DCQM-dokumentumszám. Az összes dokumentum, az egyedi DOC_NO és az XML-lel rendelkező feltöltési sorok eltérő mennyiségek lehetnek; a kért nyomtatási sorszám definícióját ennek megfelelően kell rögzíteni. Ha az „összes docno” tételes azonosítólistát jelent, ilyen naplózás sincs az aktív CREATE_STOCK ágban.
3. Mindkét Inspire-hívás elé és után külön naplósor kezdő/záró idővel és eredménnyel, a hibaágakat is lefedve.
4. A naplóosztály tényleges interfésze alapján a generált STOCK_ID beállítása a napló külső azonosítójába; figyelembe véve, hogy ugyanabban a riportfutásban több PROCESS művelet is történhet.

**Döntés:** ez a kör állapotellenőrzés és dokumentálás; ABAP-forrás, FINAL-export és SAP-objektum nem változik. A korábbi SAP-kapcsolati leállás érvényes. Új SAP-kísérlet, fordítás, ATC és futtatott teszt nem történt; automatikus jóváhagyási elutasítás ebben a körben nem volt.
