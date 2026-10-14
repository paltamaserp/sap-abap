# ZPR_CREATE_STOCK — csomagonkénti DCQM-darabszám

**Státusz:** WIP · **Dátum:** 2026-10-14

A módosított riport: `ZPR_CREATE_STOCK.abap` ugyanebben a könyvtárban. Az eredeti aktív export a `../../01_SOURCES/DHC/` könyvtárban marad.

Az ALV korábbi `STATUS` oszlopának helyén „Dokumentumok száma” látható. A kimeneti struktúrához hozzáadott `DOC_COUNT TYPE i` mező tartalmazza az adott `PACKAGE_ID`-hoz tartozó összes `ZPRT_DCQM` sor darabszámát az aktuális mandantban. Nincs XML-, státusz- vagy kizárásszűrés, és nem DISTINCT dokumentumszámot számolunk. DCQM-sor nélküli csomagnál az érték 0.

A `get_package_doc_counts` FORM a csomaglista betöltése után, egyetlen `COUNT(*) / GROUP BY PACKAGE_ID` lekéréssel számol, kizárólag a listázott csomagokra. Üres lista esetén nem kérdezi le a táblát. A darabszám a lista betöltésekor aktuális; nem frissül automatikusan más folyamat adatváltozásai után.

A mezőkatalógus a `STATUS` bejegyzést `DOC_COUNT` mezőre cseréli, megőrzi az oszloppozícióját, és egész számként jeleníti meg. A korábbi státusz-DDIC referencia és konverzió nem kerül át a számlálóra. A csomag adatbázisbeli `STATUS` értéke nem módosul. A stockképzés kódja változatlan.

SE38-ban a módosított teljes riportforrást kell bemásolni, szintaxisellenőrizni és aktiválni. Ellenőrzéshez egy 0 soros, egy 1 soros és egy többjegyű darabszámú csomag eredményét érdemes az adott `PACKAGE_ID` SE16N-lekérésével összevetni; a külön csomagok sorai nem adódhatnak össze.

Helyi ellenőrzés: az eredeti exporttal összevetve csak a számlálódeklaráció, a betöltés utáni FORM-hívás, az új számlálórutin és a mezőkatalógus változott. Az eredeti export SHA-256 értéke változatlan. SAP-hívás, feltöltés, fordítás, aktiválás és futtatás ebben a módosítási körben nem történt.
