# Új helyi SAP-letöltés ellenőrzése – WIP

A felhasználó által újra letöltött `05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap` a vizsgálat alapja. Új SAP-kapcsolat, forrásmódosítás és aktiválás nem történt.

## Forrásazonosság

A riport bájtpontosan egyezik a korábbi `ZPR_CLOSE_STOCK-active-before.abap` mentéssel. Mindkettő SHA256 értéke: `2ba1e7dcda704b5a2a7c9474508f5af06a74b4464c8da3dcb7785e9a923e06e8`.

A Lezárás gomb a 177. sorban a RELEASE_STOCK_NEW rutint hívja. A rutin a 297. sorban kezdődik, az osztályhívás a 357. sorban van. A régi SEND_PRIORITY közvetlen Inspire-hívása nem ennek a gombnak a futási útja. A meglévő LOG_WRITE a 992. sorban indul; az új darabszám- és időbélyeg-naplózás nincs benne.

A `ZPR_CLOSE_STOCK-DHC100-javaslat.abap` és diffje továbbra is ehhez az alaphoz készült. A különbség 87 hozzáadott és 1 törölt sor, az utolsó üres sor rendezésével együtt. Hiányzó elemek: LOG_STOCK_TOTALS, LOG_NOW, LOG_AT, valamint a folyamat/osztályhívás/auditmentés naplóhívásai.

## Szövegelemek pontosítása

A letöltött riport nem hivatkozik sem 3xx, sem 9xx szövegszimbólumra. A meglévő RELEASE_STOCK_NEW ág TEXT-201–209 elemeket használ. A `.abap` forrás nem tartalmazza magát a szövegkészletet: az elemek SAP-beli megléte és értéke ebből nem állapítható meg.

Az előkészített riportmódosítás ténylegesen 15 új szövegszimbólumot használ: **301–307, 310–314, 321–323**. A korábban átadott 20 elem közül **315, 316, 318, 319, 320 nincs használatban ebben a változatban**. Ezek nem szükségesek e riportjelölt működéséhez; a korábbi csomagot most nem módosítottuk.

A **901–904** szövegszimbólumok a külön `ZCL_PR_STOCK-inspire-javaslat.abap` osztályjelölthöz tartoznak, nem a riporthoz és nem SE91 T100-üzenetszámok. Az osztályjelölt a meglévő ZPR 000 üzeneten keresztül naplóz.

A helyi FINAL/ZCL_PR_STOCK.class.abap fájlt is összevetettük a korábbi aktív osztálymentéssel: csak négy generált SIGNATURE-kommentblokk az eltérés. Az Inspire-időmérés és a TEXT-901–904 hivatkozások ebben a helyi osztályban sincsenek benne. Az osztályfájl friss SAP-letöltését a felhasználó külön nem állította; ez helyi összevetés.

## További megállapítás és korlát

A riport fejlécépítése megvan: CREATE_CONTROLS_0100 (1051. sor), felső docking konténer (1059. sor, EXTENSION = 110), BUILD_HEADER (1276. sor), DISPLAY_DOCUMENT (1309. sor). A fejléc futásidejű megjelenését a helyi forrás nem igazolja.

**Döntés:** az új letöltés alapján nem szükséges új alapra átdolgozni a korábbi DHC100 riportjavaslatot. A ténylegesen használt új szövegelemek száma 15 riport + 4 osztály, összesen 19. Kódot és szövegkészletet nem módosítottunk. Friss SAP-szintaxisellenőrzés, aktiválás, ATC/SCI és funkcionális teszt nem futott; az aktív SAP-állapotot ebben a körben nem olvastuk vissza.
