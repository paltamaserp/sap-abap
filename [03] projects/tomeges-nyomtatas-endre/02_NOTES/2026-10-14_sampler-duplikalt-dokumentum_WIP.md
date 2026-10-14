# ZCL_PR_QM_SAMPLER BUILD — duplikált dokumentum miatti dump

**Dátum:** 2026-10-14 · **Státusz:** WIP

## Igazolt hiba és adatok

A felhasználó ST22-részlete az `LT_UPLOAD` belső tábla `PRIMARY_KEY` kulcsán ismételt beszúrást jelez a `ZCL_PR_QM_SAMPLER=>BUILD` metódusban. Az érintett dokumentum: `PV100130000007003100`.

Az aktív sampler MCP-visszaolvasása sikeres. Az érintett deklaráció és utasítás:

```abap
DATA lt_upload TYPE SORTED TABLE OF zprd_doc_no WITH UNIQUE KEY table_line.
INSERT LINES OF it_doc_no INTO TABLE lt_upload.
```

A szintén visszaolvasott aktív `ZIF_PR_QM_DATA` szerint a bemeneti `TT_DOC_NO` STANDARD TABLE, ezért tartalmazhat ismétlődő azonosítókat. A jelenlegi aktív `ZPR_CREATE_STOCK` a `ZPRT_DCQM` és `ZPRT_DOC_DATA` táblát csak DOC_NO szerint kapcsolja össze, és minden eredménysor dokumentumszámát hozzáfűzi az LT_DOC_NO-hoz. Ez az aktív riport már eltér a korábbi helyi riportexporttól; a diagnózisban a most visszaolvasott SELECT/APPEND ág szerepel.

Az MCP olvasási lekérdezések az adott dokumentumra:

| Forrás | PACKAGE_ID | Sorok |
|---|---|---:|
| ZPRT_DCQM | 1000000014 | 1 |
| ZPRT_DCQM | 1000000015 | 1 |
| ZPRT_DOC_DATA | — | 3 |
| A riport DCQM × DOC_DATA JOIN-ja | 1000000014 | 3 |
| A riport DCQM × DOC_DATA JOIN-ja | 1000000015 | 3 |

A visszaolvasott aktív ZPRT_DOC_DATA DDIC-kulcsa MANDT + GUID; a DOC_NO nem egyedi. A három adatrekord FILE_TYPE és STRUC_NAME szerinti csoportosítása egyetlen, üres mezőértékű csoportot adott. Így e két mező önmagában nem választja ki az egyetlen feltöltendő XML-t. Az XML-tartalmakat nem olvastuk le és nem hasonlítottuk össze; a három rekord tartalmi egyezősége vagy verziós viszonya nincs igazolva.

## Helyi samplerjavítás

Aktív forrás: `../01_SOURCES/DHC/ZCL_PR_QM_SAMPLER.abap`; interfész: `../01_SOURCES/DHC/ZIF_PR_QM_DATA.abap`. Javított WIP-osztály: `../04_ASSETS/abap/ZCL_PR_QM_SAMPLER.abap`.

A tömeges beszúrás helyett a BUILD az egyedi dokumentumhalmazt egyedi beszúrásokkal építi:

```abap
LOOP AT it_doc_no INTO DATA(lv_upload_doc).
  INSERT lv_upload_doc INTO TABLE lt_upload.
ENDLOOP.
```

Az egyedi elsődleges kulcs ismétlésekor az egyenkénti INSERT nem vesz fel új sort; az egyedi kulcs megmarad. A sampler későbbi maradéklista-képzése már külön LT_SEEN táblával kiszűri az ismétlődéseket. Más feldolgozási ág nem módosult.

A javítás a sampler dokumentumhalmazának képzését kezeli. A riport fájllistáját nem deduplikálja: azonos dokumentumszám esetén továbbra is több bejegyzés keletkezhet azonos fájlnévvel. A teljes folyamat javításához előbb meg kell határozni, hogy a több GUID-os adatrekordból melyik XML az érvényes. Eltérő XML-eket nem szabad pusztán DOC_NO alapján tetszőlegesen eldobni. Adatbázisbeli rekordtörlés és XML-kiválasztás nem történt.

## Ellenőrzés és jóváhagyási állapot

Helyi forrásösszevetés: kizárólag az LT_UPLOAD feltöltő utasítása változott; az exportok karakterre egyeznek az MCP-válaszokkal. ABAP Unit- és funkcionális teszt nem futott. A duplikált bemenetű regressziós próba elvárt eredménye: azonos dokumentumszám ismétlésekor a BUILD nem dumpol, és minta nélkül a REST listában egyszer szerepel a dokumentum.

A módosított teljes osztályforrás `CheckClass` szintaxisellenőrzését az automatikus jóváhagyási ellenőrzés elutasította: az érzékeny forrás továbbítására kifejezett engedély hiányzott. Ez nem SAP-válasz, nem új HTTP-hiba, és nem igazolja a módosított kód szintaxisát. A felhasználó az ezt követő engedélykérésre azt válaszolta: „Nem, maradjon helyi javítás”. Újraküldés nem történt. SAP-objektum módosítása, aktiválás és riportfuttatás nem történt.
