# Stocklezárás – helyi WIP forráscsomag

Dátum: **2026-10-17** · Státusz: **WIP**

**Frissítés, 2026-10-18:** a riport négy globális objektumreferenciája az oneERP szerinti `GR_` előtagot kapta: `GR_CONTAINER`, `GR_GRID`, `GR_HEADER_CONTAINER`, `GR_HEADER`. Mind a 37 deklaráció/hivatkozás átvezetve, egyéb forrásváltozás nélkül. A kapcsolódó diffek és a SHA256-manifeszt frissültek; a 15 helyi forrásellenőrzés és a csomagdiff kétirányú bájtpontos ellenőrzése újra sikeres. Új ABAP-parser- vagy SAP-futtatás ehhez az átnevezéshez nem történt; a parsereredmény a korábbi futásé.

Az új riport a hatpontos kérés alapján készült, a [mai export](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap>) külön másolataként. Az eredeti exportok és az aktív SAP-objektumok nem módosultak.

## Fájlok

| Fájl | Szerep |
|---|---|
| [ZPR_CLOSE_STOCK.abap](<ZPR_CLOSE_STOCK.abap>) | Teljes módosított riport, hét helyi ABAP Unit teszt forrásával |
| [ZCL_PR_STOCK.abap](<ZCL_PR_STOCK.abap>) | A lezáró metódus bővítése és az átvitt üzleti segédmetódusok; a többi eredeti metódus változatlan |
| [ZPR_STOCK_REPORT_O01.abap](<ZPR_STOCK_REPORT_O01.abap>), [ZPR_STOCK_REPORT_I01.abap](<ZPR_STOCK_REPORT_I01.abap>) | A napi export változatlan include-jai, a csomag teljességéhez |
| [Riportszövegek](<ZPR_CLOSE_STOCK.texts.tsv>) | 101–140 szövegszimbólum a riport saját szövegkészletéhez |
| [Osztályszövegek](<ZCL_PR_STOCK.texts.tsv>) | 101–133 szövegszimbólum az osztály saját szövegkészletéhez |
| [changes.diff](<changes.diff>), [diff-check.json](<diff-check.json>) | A riport és az osztály eltérése a helyi kiinduló forrástól; külön másolaton előre és vissza alkalmazva bájtra pontosan ellenőrizve |
| [parser-check.json](<parser-check.json>), [source-check.json](<source-check.json>) | Helyi ellenőrzési eredmények, SAP-futtatás nélkül |
| [check.cjs](<check.cjs>) | Újrafuttatható forrás-/integrációs ellenőrzés; nem üzleti futtatási teszt |
| [manifest.json](<manifest.json>) | A csomag fájljainak SHA256-jegyzéke |

## Megvalósított működés

1. Már lezárt stock esetén információs üzenet: **„A stock engedélyezve van, csak megtekintés lehetséges.”**
2. Nem QM-státusz esetén információs üzenet: **„Csak QM státuszú stock zárható le. Csak megtekintés lehetséges.”** A meglévő külsőállapot-tiltás is megmaradt.
3. Lezárható stock esetén a riport már a képernyő megnyitása előtt megszerzi az `EZPRT_STOCK` zárat, `_SCOPE = 1` értékkel. Zár után újraolvassa az állapotot. Idegen zárnál csak megtekintés és zárolási tájékoztatás van. A meglévő `RELEASE` gomb felirata **Lezárás**, és csak saját zár mellett látható.
4. A gomb az új `ZCL_PR_STOCK=>CLOSE_STOCK` metódust hívja. A prioritást a riport egyszer kéri be, majd átadja. A metódus küldi az Inspire-kérést, és explicit siker után menti a teljes helyi lezárást. A stock `CL`, `CLOSED = X`, prioritás, `ERDAT_CLO/ERNAM_CLO/ERTIM_CLO`, `CHDATE/CHUSER/CHTIME` értékei töltődnek. A CR* mezők megmaradnak, a felhasználói pontosításnak megfelelően.
5. Külön felső dokumentumfejléc jelenik meg stockazonosítóval, összes/kizárt/engedélyezett darabszámmal; megtekintési módban a tiltási ok is látszik. Induláskor, frissítéskor és a lezárás után is frissül. Nem hív üzleti lezárást. Az ALV továbbra is a kizárt tételeket listázza, ezért a lista elemszáma nem az összes nyomtatási sor száma.
6. Új kivételkezelési működés nem készült: a mai riport meglévő proxy-/SQL-hibakezelése és bizonytalan eredményhez tartozó tiltása az üzleti kóddal együtt átkerült az osztályba. Részletes áttervezésük a Márkkal tervezett egyeztetésre marad.

A kizárt borítékok `EXCLUDE_ENVELOPES` átadása és a kapcsolódó `ZPR_TERTI`/`ZISU_F064` kezelés megmaradt. Ezek hiányoztak a régi helyi osztálymásolatból. Új, általános kizárás miatti lezárási tiltást nem vezettem be, és a meglévő ragszámszelekció üzleti hatókörét nem változtattam meg.

## Az osztály új szerződése

| Paraméter | Jelentés |
|---|---|
| `IV_STOCK` | Stockazonosító, meglévő kötelező bemenet |
| `IV_PRIORITY` | Opcionális; ha átadták, nem lesz második prioritáspopup. Az átadottságot `IS SUPPLIED` ellenőrzi. |
| `IV_LOCK_HELD` | Alapból hamis. Igaz esetén a hívó már birtokolja az adott stock dialóguszárát és ő felel a feloldásért. A riport csak a ténylegesen megszerzett saját zár mellett ad igazat. |
| `IV_DISPLAY_LOG` | Alapból igaz a korábbi közvetlen hívókhoz. A riport hamisat ad, majd a visszakapott üzenetekből egyetlen naplót jelenít meg. |
| `EV_SUCCESS` | Csak explicit sikeres Inspire-válasz és sikeres üzleti COMMIT után igaz |
| `EV_UNCERTAIN` | A meglévő bizonytalaneredmény-állapot; a riport módját is tiltja |
| `ET_MESSAGES` | A lezárás összegyűjtött BAL-üzenetei |

Közvetlen hívásnál, ha `IV_LOCK_HELD` nincs átadva, az osztály maga kér és old fel stockzárat. A riport által átadott zárat az osztály nem oldja fel. A státuszt és a lezárhatóságot a metódus a proxyhívás előtt friss stockadatból is ellenőrzi.

A lezárási üzleti COMMIT az osztályban van. A riportban maradt COMMIT/ROLLBACK a saját naplókezeléséhez tartozik; nincs benne második stocklezáró UPDATE. Az általános `UPDATE_STATUS` változatlan maradt a többi státuszváltáshoz.

## Átvezetés SAP-ba

**Ez a csomag helyi WIP.** A `ZCL_PR_STOCK` alapja korábbi helyi másolat; az aktív osztály újabb módosításait az átvezetés előtt össze kell vetni vele. A teljes régi osztályt ezért nem szabad ellenőrzés nélkül felülírni. SAP-kapcsolatot ebben a munkában nem használtam; a fennálló leállási szabály szerint új kísérlethez kifejezett felhasználói újrapróbálási kérés kell.

1. Az aktuális osztály, stock-DDIC, a lezárás közvetlen hívói és a 0100-as képernyő összevetése a helyi csomaggal. A riport függ az új osztályinterfésztől; önmagában a riport forrásának másolása nem elég.
2. Az osztály definíciójának és lezárási implementációjának összevezetése, majd a saját 101–133 szövegszimbólumok karbantartása az osztály szövegkészletében. A két TSV külön objektumhoz tartozik, a számaik szándékosan átfednek. Ha az aktív objektumban valamelyik szám már foglalt, a forráshivatkozást és a TSV-t együtt kell átszámozni.
3. A riport átvezetése, a saját 101–140 szövegszimbólumok karbantartása. A meglévő 001/002 blokkcímek és szelekciós szövegek megőrzendők. A `.abap` fájlok másolása önmagában nem hozza létre a szövegkészletet. A magyar szövegeket és szükséges fordításaikat is transzportálni kell.
4. A közös O01/I01 include-ok kódja nem változott. A 0100 képernyőnek továbbra is kell az `ALV_CONTAINER_01`, a `GV_OKCODE_0100` OK-mező és a két PBO/PAI modul. Referencia: [meglévő flow/layout útmutató](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/ZPR_STOCK_REPORT_0100_flow.abap>). A jelen csomag saját dokkolt fejlécet használ: az útmutatóban javasolt statikus darabszámfejléc nem szükséges hozzá. Ha ilyen már van a layoutban, a dupla megjelenést a képernyőn rendezni kell. A GUI státusz és címek továbbra is a meglévő `STAT_0100`, `TITLE_0100_MOD`, `TITLE_0100_DISP` objektumok.
5. A régi helyi `LZPR_COCKPITO01` close ága a `CLOSE_STOCK` után feltétel nélkül `UPDATE_STATUS('CL')`-t hív. Ha ez az ág még aktív, a külön státuszírást el kell hagyni, és az eredményt `EV_SUCCESS` alapján kell megjeleníteni/frissíteni. Ez a csomag az ismeretlen aktív cockpit forrását nem írja át. A szükséges hívásminta:

   ```abap
   "Declare LV_CLOSE_SUCCESS with the caller's local variables.
   DATA lv_close_success TYPE abap_bool.

   zcl_pr_stock=>close_stock(
     EXPORTING iv_stock = zprs_cockpit-stock_id
     IMPORTING ev_success = lv_close_success ).
   "Do not call UPDATE_STATUS( 'CL' ) after this method.
   "Use LV_CLOSE_SUCCESS when reporting the result.
   ```

   A minta alapértelmezetten önállóan zárol. Ha a tényleges cockpit már tart saját stockzárat, azt az ellenőrzött hívó `IV_LOCK_HELD = ABAP_TRUE` átadásával jelezze, és továbbra is maga oldja fel.
6. Együttes szintaxisellenőrzés/aktiválás, majd ATC és ABAP Unit. A `/abap-code-review` kapu a SAP-elérés újbóli engedélyezése után használható. Végül a lenti GUI-próbák szükségesek.

## Ellenőrzések és fennmaradó korlátok

- **Lefutott:** `@abaplint/core 2.120.60`, ABAP 7.54 parser, a két include-dal kibontott riport és az osztály; nincs parserhiba. Ez nem SAP-fordítás vagy DDIC-/proxyinterfész-ellenőrzés.
- **Lefutott:** 15 helyi forrás-/integrációs ellenőrzés: forrásmegőrzés, rutinok és metódusok feloldása, a kizárólagos osztálybeli proxyhívás/üzleti mentés, zárfeltételek, auditmezők, kizárási út, szöveghivatkozások és tesztforrások jelenléte. A `check.cjs` Node.js-sel újrafuttatható.
- A parser újrafuttatásához a `check.cjs` opcionális első argumentuma a telepített `@abaplint/core` modul könyvtára vagy belépőfájlja: `node check.cjs <core-eleresi-ut>`. Argumentum nélkül csak a helyi forrásellenőrzések futnak. A `changes.diff` `before/after` útvonalakkal készült (`-p2`); referencia és összehasonlítás, nem ellenőrzés nélküli aktív SAP-import.
- **Előkészítve, SAP-ban nem futott:** hét ártalmatlan ABAP Unit módteszt: QM engedélyezett; lezárásjelző, CL, DM, nyitott, külső hiba és bizonytalan eredmény tiltott. A tesztek a globális képernyőállapotot elmentik és visszaállítják; nincs bennük SQL, enqueue vagy Inspire-hívás.
- **Még szükséges:** aktív SAP-fordítás, ATC, Unit-futtatás, kétmunkamenetes zárpróba, sikeres Inspire-válasz utáni mezőellenőrzés és GUI-fejlécpróba. A teljes DDIC-index-/kulcs- és proxyellenőrzéshez nem áll rendelkezésre friss aktív export.
- Az 5. ponthoz említett ügyfélmelléklet továbbra sem érkezett meg. A fejléc tartalma a forrásokból ismert darabszámokra épül, a pontos látvány nincs jóváhagyva.
- A ragszámkezelés és a meglévő hibavédelmek átvitele nem jelent teljes QA-minősítést; a korábban meglévő, most át nem tervezett működés külön egyeztetése továbbra is szükséges lehet.

GUI-próbák: lezárt stock és nem QM-stock üzenete; QM-stock saját zárja; ugyanaz a stock második munkamenetben; Frissítés utáni mód- és gombváltás; prioritáspopup megszakítása; sikeres lezárás után CL/CLOSED/lezárási/CH* mezők és változatlan CR*; zár felszabadulása lezáráskor és kilépéskor; fejléc frissülése és a meglévő kizárási/ragszámkezelés megmaradása.
