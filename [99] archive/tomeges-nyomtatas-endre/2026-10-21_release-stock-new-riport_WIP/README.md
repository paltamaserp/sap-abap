# RELEASE_STOCK_NEW – kizárólag riportmódosítás

Státusz: **WIP**, 2026-10-21.

Közvetlen kiindulás: [05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap](../../05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap). A kiinduló riport és a `ZCL_PR_STOCK` osztály változatlan. Ebben a csomagban nincs osztálymódosítás és nincs módosított osztálymásolat. Ez a felhasználó legújabb kérésének megfelelő, a korábbi osztálybővítési megoldást felváltó változat.

A Lezárás gomb `RELEASE` parancsa az új `FORM release_stock_new` rutint hívja. Az eredeti `release_stock` és minden más meglévő rutin megmarad. Az új rutin megőrzi a jogosultság-, foglaltság-, stockzár-, QM-állapot-, listaváltozás- és üresstock-ellenőrzést, majd egyszer hívja a meglévő, változatlan interfészt:

```abap
zcl_pr_stock=>close_stock( iv_stock = p_stokid ).
```

Az osztály a saját prioritáspopupját és naplóját használja. A riport ezért nem nyit második prioritáspopupot. A régi riportbeli proxyhívás nem fut le az új gombútvonalon.

## Sikerellenőrzés és mentés

A helyi osztályforrásban a `CLOSE_STOCK` csak `IV_STOCK` bemenetet fogad. Nincs sikerjelző kimenete; a hibák egy részét belül kezeli, és megszakított popupnál is normálisan visszatérhet. A normál visszatérés és a `SY-SUBRC` ezért nem használható Inspire-sikerjelzőként.

A helyi implementáció csak sikeres Inspire-válasz után hívja az `UPDATE_STATUS( 'CL' )` eljárást, amely commitolja a státuszt. E meglévő működésre alapozva az új rutin a saját dialogzár alatt ellenőrzött kezdeti QM állapot után, az osztályhívást követően `BYPASSING BUFFER` lekérdezéssel olvassa vissza a stockot. A sikerre a QM → CL állapotváltásból következtet; ez közvetett jelzés, nem visszaadott proxyválasz.

Csak visszaolvasott CL státusznál fut a riport UPDATE-je:

```abap
UPDATE zprt_stock
  SET status = gc_status_closed
      chuser = sy-uname
      chdate = sy-datum
      chtime = sy-uzeit
  WHERE stock_id = p_stokid
    AND status = gc_status_closed
    AND closed = space
    AND stock_status_er = space.
```

A mentés előtt `GET TIME` frissíti a rendszeridőt. Egyetlen módosított sort követelünk meg; sikertelen UPDATE-nél rollback és a meglévő bizonytalanság-/hibajelző-kezelés következik. A CR* mezők megmaradnak. A kérés szerinti UPDATE csak a STATUS és CHUSER/CHDATE/CHTIME értékeit állítja.

Az osztály saját commitja megelőzi a CH* mentést, ezért a két művelet nem egyetlen visszagörgethető tranzakció. Ha a riport mentése hibás, az osztály által már commitolt CL státusz megmaradhat; a meglévő `MARK_UNCERTAIN_STATE` kezeli az ellenőrzendő állapotot. A riport által el nem kapott, az osztályban belül kezelt technikai hibát és a popup megszakítását ez az interfész nem különbözteti meg: CL hiányában nincs sikeres mentés, az osztálynapló ellenőrzendő.

A prioritás, CLOSED jelző és lezárási időbélyegek írása nem része ennek a szűk UPDATE-nek. A régi `SAVE_RELEASE`/ragszámtörlés nem fut le az új ágban. A változatlan osztály helyi forrásában a kizárt borítékok átadása kommentelt; az új riport nem tud kizárási listát átadni az egyetlen IV_STOCK paraméteren. Ezek az osztály módosítása nélküli megoldás határai, nem teljes egyenértékűség a régi riportlezárással.

## Átadott fájlok és ellenőrzés

- [ZPR_CLOSE_STOCK.abap](ZPR_CLOSE_STOCK.abap): teljes helyi riportmunkamásolat.
- [2026-10-21_release-stock-new-riport_WIP.diff](2026-10-21_release-stock-new-riport_WIP.diff): kizárólag a megadott 05_FINAL riporthoz viszonyított diff; gombbekötés és egy új rutin.
- [ZPR_CLOSE_STOCK.texts.tsv](ZPR_CLOSE_STOCK.texts.tsv): új 201–209 HU szövegszimbólumok, a riport SE38/ADT szövegkarbantartásában külön átvezetendők és szükség szerint fordítandók. A `.abap` másolása nem hozza létre a szövegkészletet. Aktív ID-ütközésnél a kóddal együtt átszámozandók.
- [source-check.json](source-check.json): hat sikeres helyi forrásellenőrzés, az alap- és osztályforrás hash-e és a diff bájtpontos oda-vissza próbájának eredménye. [Előállítás](build.cjs), [ellenőrzés](check.cjs).

A meglévő riportinclude-ok és textelemek szükségesek. Helyi ABAP-parser, SAP-fordítás, ATC, ABAP Unit és GUI/Inspire-próba nem futott. SAP-kapcsolatot nem használtunk; az aktív SAP-állapot nincs ellenőrizve. SAP-ban a sikeres QM → CL út, megszakítás/elutasítás/technikai hiba, sikertelen CH* mentés és a zár megmaradása ellenőrizendő.
