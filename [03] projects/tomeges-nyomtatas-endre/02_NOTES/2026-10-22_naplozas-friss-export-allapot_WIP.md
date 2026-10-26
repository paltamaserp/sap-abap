# Naplózási feladat – friss export szerinti állapot

> Történeti elemzés a 2026-10-22-i forrásról. A munkabázis 2026-10-26-tól a [mai MCP-export](../05_FINAL/abap-2026-10-26/README.md); az alábbi megállapítások nem kerültek újra tartalmilag ellenőrzésre.

Dátum: 2026-10-22. Státusz: **WIP, nincs kész**. Alap: `05_FINAL/abap-2026-10-22/`. Kizárólag helyi felülvizsgálat; forrásmódosítás és új SAP-hívás nélkül.

A felhasználó a package-ek, összes DOC_NO és EXBILLDOCNO/nyomtatási sorok számát, az Inspire-hívás kezdetét és végét, valamint STOCK_ID külső naplóazonosítót kérte számon. A stockképző, stocklezáró és az előző körben vizsgált dokumentumstátusz-riport külön útvonal; a részleges megvalósítások nem jelentenek teljesítést mindegyikben.

## Követelményenként

| Kért naplóadat | Friss forrás szerinti állapot |
|---|---|
| PACKAGE_ID darabszám és összes DOC_NO darabszám | **Hiányzik a teljes naplóösszesítés.** CREATE_STOCK: a GET_PACKAGE_DOC_COUNTS (856–881) a csomagonkénti DOC_COUNT ALV-mezőt tölti, nem naplóz. CLOSE_STOCK: nincs LOG_STOCK_TOTALS és az ehhez tartozó új naplóhívás. DOC_STATUS: hiányzó D esetén összes dokumentum/hiányzó D darabszám van (430–435), package-darabszám nincs. |
| EXBILLDOCNO / nyomtatási sorok száma | **Nincs külön, teljes összesítő naplósor.** CREATE_STOCK: a korábbi S006/LINES(LT_FILE) napló is kommentelt (279–289). Az XML-es lista INNER JOIN alapján áll elő (201–207), ezért önmagában nem bizonyítja a teljes dokumentumhalmazt. A friss DCQM definícióban a nyomtatási dokumentumazonosító DOC_NO; a SLOG EXBILLDOCNO mezője erre kapcsolódik, a SLOG eseménysorok száma nem nyomtatási darabszám. |
| Inspire-hívás kezdete | **Részben megvan.** CREATE_STOCK: S007 közvetlenül a TRIGGER_STOCK_COMPLETION előtt (293–300), paraméterei stock és csoportszám. CLOSE_STOCK gombút: RELEASE_STOCK_NEW → ZCL_PR_STOCK=>CLOSE_STOCK; az osztályban közvetlenül a proxy előtt UTC-időbélyeges TEXT-901 naplóhívás van (173–176). DOC_STATUS: a proxyhívás (347–348) körül nincs külön kezdő/záró napló. |
| Inspire-hívás vége és időtartama | **Nem teljesült. Konkrét akadály a friss osztályban:** a ZCL_PR_STOCK 201. sora `CLEAR: lv_call_start, lv_call_end.`; utána a 202. sor mindkét időbélyeg nem üres voltát várja. Emiatt a 203–219 közötti vég- és időtartam-napló kimarad. A CREATE_STOCK üzleti sikerüzenete csak az adatbázismentés/COMMIT után keletkezik (346–349), nem a távoli hívás pontos végén. |
| STOCK_ID mint külső naplóazonosító | **Nincs bekötve a vizsgált hívási helyeken.** A friss ZCL_PR_LOG opcionális IV_EXT_ID paramétert támogat (9–13), és ezt EXTNUMBER-be teszi (93–96). CREATE_STOCK (80–82), CLOSE_STOCK (1001–1004), ZCL_PR_STOCK (140–142) nem adja át. A DOC_STATUS saját BAL-fejlécében dátum/idő a külső azonosító (735), nem STOCK_ID. Az üzenetben szereplő stockszám nem helyettesíti a fejléc külső azonosítóját. |

## Korábbi javaslat és a friss export különbsége

Van helyi naplózási javaslat a `03_DRAFTS/2026-10-22_close-stock-naplo_WIP/sap-atvezetes-2026-10-22/` könyvtárban: stockösszesítés és folyamatnapló a riporthoz, pontos Inspire-időmérés az osztályhoz. Ez nem tekinthető teljesen átvezetett megoldásnak: a friss riportból hiányoznak az új összesítő rutinok, az osztályban pedig a fenti CLEAR kikapcsolja a befejező naplózást. Az IV_EXT_ID a jelölt riport-/osztályhívásokban sincs átadva.

**Pontosítás a korábbi jegyzetekhez:** a friss osztályban a kezdő időbélyeges naplóhívás már benne van. A korábbi, teljes időmérési kód hiányáról szóló állítás ezért nem alkalmazható változtatás nélkül a mai exporthoz. A befejező rész jelen van, de az időbélyegek törlése miatt nem fut.

A korábbi átvezetési feljegyzés az első szövegzárolási műveletnél HTTP 500 miatti leállást dokumentál, szöveg-PUT/forrásírás/aktiválás nélkül. Azóta a frissebb export a ténylegesen mentett források bizonyítéka; abból nem következtetünk arra, ki vagy mikor végezte az osztály részleges módosítását. Ebben a körben nincs új SAP-hívás vagy automatikus jóváhagyási elutasítás.

## Ellenőrzés és fennmaradó munka

A hat felhasznált forrás (ZPR_CREATE_STOCK, ZPR_CLOSE_STOCK, ZPR_DOC_STATUS, ZCL_PR_STOCK, ZCL_PR_LOG, ZCL_PR_INSPIRE_GW) SHA256 értéke egyezik a friss exportmanifesztével. A gateway implementációjában nem találtunk olyan naplózást, amely a riportból hiányzó négy követelményt pótolná.

A teljesítéshez a ténylegesen használt folyamatban kell bekötni a darabszámnaplót, a hívás utáni/híbahoz tartozó végbejegyzéseket és a STOCK_ID fejlécazonosítót. A CREATE_STOCK esetén a stockazonosító csak a napló létrehozása után keletkezik, és egy futásban több művelet lehet: a napló stockonkénti életciklusát is ehhez kell igazítani. A DOC_STATUS jelenleg egy naplóban több stockot dolgozhat fel; stockonkénti külső azonosítóhoz ott is külön stocknapló szükséges.

SAP-fordítás, ATC, szövegkészlet-ellenőrzés és futási naplópróba nem történt. Az aktív SAP-állapot ebben a körben nincs ellenőrizve.
