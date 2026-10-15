# ABAP QA – visszatérő hibák és ellenőrzési szabályok

Státusz: **WIP**. Rögzítve: 2026-10-15, a felhasználó ZPR_DOC_STATUS QA-találatai alapján. ABAP-forrás készítésekor és módosításakor ezt az ellenőrzőlistát is alkalmazni kell.

## Következő fejlesztéseknél

1. **MESSAGE-szöveg:** a felhasználónak szánt állandó szöveg textelemben vagy meglévő T100-üzenetben legyen. Példa: `MESSAGE text-101 TYPE 'I'.` A kapcsolódó szövegkarbantartást és fordítást is dokumentálni kell. A literál változóba helyezése önmagában nem oldja meg a fordíthatóságot. A dinamikus hibaüzenet külön eset; a naplóban és visszatérési értékben szereplő állandó szövegeket is vizsgálni kell fordíthatóság szempontjából.
2. **Belső tábla:** beszúrás előtt ellenőrizni kell a tényleges táblatípust, a DDIC-típusokat is beleértve. SORTED/HASHED táblához `INSERT ... INTO TABLE` használatos; az APPEND sorrendi feltételeire nem szabad építeni. Egyedi kulcsnál az esetleges duplikáció kezelését az üzleti működés alapján kell megadni.
3. **Adatbázis-hozzáférés:** a WHERE-feltételt a teljes elsődleges kulccsal és a meglévő másodlagos indexek vezető mezőivel is össze kell vetni. A szokásos Open SQL mandantkezelés automatikus; a hiányzó üzleti kulcsmezőt nem helyettesíti egy explicit MANDT-feltétel.
4. **Kiválasztási feltételek:** QA-találat miatt tilos önkényesen szűkíteni a feldolgozandó rekordhalmazt. Hiányzó vezető kulcsmezőnél előbb tisztázni kell az üzleti hatókört, majd megfelelő indexet keresni vagy javasolni. Ne legyen ál-feltétel, teljes táblás köztes lekérés vagy indokolatlan ellenőrzéskikapcsolás.
5. **Törlés:** ha a szükséges rekordok teljes kulccsal már rendelkezésre állnak, használható a `DELETE dbtab FROM TABLE itab`. Ellenőrizni kell az üres táblát, a kulcsok teljességét, a `sy-subrc` eredményét, a zárolást és a tranzakcióhatárt. A megengedett „nincs rekord” esetet külön kell kezelni. A kiválasztás és törlés közötti konkurens módosítást az együttműködő zár önmagában nem zárja ki minden más program számára.
6. **Igazolás:** készüljön áttekinthető diff, és legyen külön megnevezve a helyileg javított, az SAP-ban még ellenőrizendő és a nyitott találat. A helyi parserellenőrzés nem SAP-fordítás, ABAP Unit vagy QA/ATC-futtatás.

## ZPR_DOC_STATUS – a bejelentett hét találat

A sorszámok a felhasználó QA-listájából származnak; a módosított forrásban eltolódhatnak.

| QA-sor | Találat | Helyi kezelés |
|---|---|---|
| 92 | Jogosultsági MESSAGE literál | `text-101`, szöveg külön TSV-ben |
| 757 | Hiányos naplóról szóló MESSAGE literál | `text-104`, S típus és E megjelenítés megmarad |
| 109 | Ismételt lekérdezés stockfeltételének MESSAGE literálja | `text-102`, E típus megmarad |
| 255 | Nincs megfelelő lezárt stock MESSAGE literálja | `text-103`, S típus megmarad |
| 733 | APPEND a BAL_T_LOGH rendezett táblára | `INSERT gv_log_handle INTO TABLE lt_handles` |
| 634–636 | ZPR_TERTI DELETE hiányos indexfeltétellel | `DELETE zpr_terti FROM TABLE lt_terti`, a már beolvasott teljes kulcsokkal |
| 625–627 | ZPR_TERTI SELECT hiányos indexfeltétellel | **Az index segített, a felhasználó visszaigazolása szerint (2026-10-15)**; a megoldás nem igényel új ragszámfeltételt |

Hat találat helyi kódjavítása elkészült. A hetedik, olvasási indexjelzésnél a felhasználó 2026-10-15-én visszajelezte: „Az index segített”. Az indexmegoldás eredményességét e visszajelzés alapján rögzítjük; ez nem a teljes QA-futtatás vagy a textelemek karbantartásának igazolása. Az asszisztens SAP-hívást és SAP-módosítást nem végzett; az aktív indexdefiníció nincs visszaolvasva.

### Textelemek

A program SE38/ADT szövegszimbólumaihoz a 101–104 azonosítókat a [TSV-fájlból](<../[03] projects/tomeges-nyomtatas-endre/04_ASSETS/abap/2026-10-15_doc-status-qa-textelemek_WIP.tsv>) kell karbantartani a megfelelő nyelven és transzportálni. A `.abap` forrás másolása nem hozza létre a szövegkészletet; az új hivatkozások a szövegek nélkül nem adnak teljes üzenetet. A már meglévő 001 cím és a szelekciós szövegek megmaradnak. Új T100-üzenetszámot nem foglaltunk.

### TERTI-index – a felhasználó által visszaigazolt megoldás

**Eredmény (2026-10-15):** a felhasználó szerint az index segített a ZPR_TERTI SELECT QA-indexjelzésén. Tanulság a későbbi fejlesztésekhez: ha a kiválasztás üzletileg helyes, de hiányzik a megfelelő index, megfelelő másodlagos indexszel kell rendezni a hozzáférést; nem szabad látszólagos feltételt hozzáadni vagy önkényesen egy ragszámra szűkíteni. A tényleges indexazonosítót és mezőlistát külön nem erősítette meg; az alábbiak az egyeztetett javaslatot tartalmazzák.

A helyi DHC-definíció elsődleges kulcsa: `MANDT + ZISU_RAGSZAM_128 + ENVELOPE_ID + EXBILLDOCNO + EXTNU`. A lekérdezés az adott boríték és dokumentum **összes ragszámához és EXTNU értékéhez** tartozó sort igényli. A `ZISU_RAGSZAM_128 = ...` feltétel hozzáadása ezt leszűkítené.

Az egyeztetett **nem egyedi** indexjavaslat mezősorrendje: `MANDT + ENVELOPE_ID + EXBILLDOCNO`. A két üzleti mező nem egyedi, mert több ragszám/EXTNU is létezhet. Hasonló esetben előbb ellenőrizni kell a meglévő másodlagos indexeket; új index szükségességét és céladatbázisra érvényes kialakítását a tényleges indexek és ST05/SQL-terv, valamint a használati gyakoriság és írási költség alapján kell eldönteni. Az asszisztens DDIC-indexet nem hozott létre.

Javasolt SE11 indexazonosító: `Z01`, ha a ZPR_TERTI táblán még szabad és nincs már megfelelő index. Rövid szöveg: `Boríték és dokumentum szerinti keresés`. Nem egyedi index, a fenti három mezővel. Az ABAP SELECT-ben nem kell indexnevet megadni; a programok kódját az index hozzáadása miatt nem kell módosítani. Az adatbázis az indexeket automatikusan karbantartja; az új index az írások költségét és a tárhelyigényt növelheti. A transzport megtörténtét és a teljes QA-eredményt a felhasználó visszajelzése nem részletezi.

### Diffek és ellenőrzés

A diffek kizárólag e QA-javítás előtti helyi állapothoz viszonyítanak; a korábbi parserjavítás és a felhasználó meglévő módosításai már a kiindulás részei.

1. [Üzenetek és a négy textelem](<../[03] projects/tomeges-nyomtatas-endre/04_ASSETS/abap/2026-10-15_doc-status-qa-uzenetek_WIP.diff>).
2. [TERTI-törlés és naplóhandle beszúrása](<../[03] projects/tomeges-nyomtatas-endre/04_ASSETS/abap/2026-10-15_doc-status-qa-tablamuveletek_WIP.diff>).

A patch-ek alkalmazási sorrendje 1 → 2. A forrásban a javítások már szerepelnek; ugyanarra a példányra nem kell újra alkalmazni őket. A nem módosított SELECT nem szerepel javításként a diffben. A helyi ABAP 7.54 parser- és forrásszerkezeti ellenőrzés hibamentes; a két patch külön másolaton oda-vissza alkalmazva bájtra pontosan visszaadta a célállapotot és az eredeti forrást. [QA-ellenőrzési jegyzőkönyv](<../[03] projects/tomeges-nyomtatas-endre/02_NOTES/2026-10-15_doc-status-qa-ellenorzes_WIP.json>). SAP-ban fordítás, QA/ATC, ABAP Unit és célzott működési próba szükséges.
