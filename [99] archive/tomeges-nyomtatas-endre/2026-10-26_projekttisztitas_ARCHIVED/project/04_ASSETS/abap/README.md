# 04_ASSETS/abap — WIP ABAP export

**Aktuális állapot, 2026-10-17:** a fejlesztési kiindulópont a [mai MCP-export](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/05_FINAL/abap-2026-10-17/README.md>). A korábbi 19 munkaforrás a [történeti archívumba](<../../../../2026-10-17_torteneti-anyagok_ARCHIVED/README.md>) került. Itt a képernyő-flow logic, textelemek, üzenetlista, tesztforrások, opcionális MQ-regisztráció és útmutatók maradtak. Az alábbi ismertető az archivált WIP-változatok történeti leírása; a hivatkozások az új helyekre mutatnak.

Ide kerül a **munka közbeni** `.abap` export (osztály, report, függvénymodul,
DDL) — verziózáshoz, diffeléshez.

Az ABAP Unit-tesztinclude-ok a `test/` almappában találhatók:
[ZPR_MQ_TESTS](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/test/ZPR_MQ_TESTS.abap>) és [ZPR_DOC_RIP_TESTS](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/test/ZPR_DOC_RIP_TESTS.abap>).

- Az ABAP objektum **igazi helye a SAP rendszer**; a `.abap` fájl csak másolat.
  Az igazság forrása az ADT / MCP-n olvasott aktív verzió.
- Fájlnév a SAP objektum neve: `ZCL_<PREFIX>_<OBJEKTUM>.abap`. A `<PREFIX>` a
  projekt saját prefixe — lásd `00_BRIEF.md`, Kulcs-konvenciók.
- Ha kész és kiajánlásra vár → tedd át `05_FINAL/`-ba (lásd az ottani README-t
  az ABAP Unit konvencióról).
- Diff a SAP-beli előző verzióhoz: `Get*VersionDiff` MCP tool.

## Messenger e-mailstátusz-lekérdezés

A `ZPR_MESSAGEQUEUE_QUERY` a QU5 `ZBC_PRN_MESSAGEQUEUE_QUERY` alapján készült helyi WIP DHC-változat. A meglévő `ZPR_SLOG_EMAIL` transzparens táblát és a felhasználó által létrehozott `ZPRB_SLOG_EMAIL` táblatípust használja. A zárolási hívások `EZPR_SLOG_EMAIL`-re épülnek, CHAR 14 időmezőkezeléssel és CHAR255 hibaüzenettel. Proxyillesztő, ALV-include, 0100 flow logic, opcionális e-mailküldő regisztrációs include és kilenc ABAP Unit-teszt tartozik hozzá. A korábbi új táblaspecifikáció kivezetve.

[Bemásolási és integrációs útmutató](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/info.md/2026-10-13_messagequeue-dhc-bemasolas_WIP.md>). A valódi Inspire WSDL-ből generált proxy/típusok és a logikai port előfeltételek; a tervezett proxynevek az illesztőben egyeztetendők. SAP-fordítás és teszt nem történt, az aktív DHC-állapot nincs ellenőrizve.

## Stocklezárási riport

A `ZPR_STOCK_REPORT` teljes helyi WIP forrása a két include-dal és a 0100 flow logicjával itt található. A felhasználó által választott állapotmodell: `STATUS = QM` → `STATUS = CL`, `CLOSED = X`; ragszámkezelés: `ZPR_TERTI` és `ZISU_F064`.

[Bemásolási útmutató és függőségek](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/info.md/2026-10-13_stock-report-dhc-bemasolas_WIP.md>). Helyi szerkezeti/mezőellenőrzés történt, SAP-fordítás és teszt nem; az SAP-kapcsolatot nem használtuk.

## Nyomdai ellenőrző riport

A `ZPR_DOC_RIP` a QU5 `ZEBF_PR_DOC_RIP` helyi WIP DHC-változata: stockonként és PR/IN csatornánként hasonlítja össze a SAP dokumentum-/borítékszámokat az Inspire fájladataival, részletes ALV-listával. A hat include, a 0100 flow logic és hat Unit-teszt forrása itt található. Az aktív proxy és a szükséges táblák/struktúrák MCP-vel csak olvasva ellenőrizve; SAP-objektum létrehozása/módosítása és tesztfuttatás nem történt.

[Bemásolás, adatleképezés, logikai port és ellenőrzések](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/info.md/2026-10-15_doc-rip-dhc-bemasolas_WIP.md>).

## Dokumentumstátuszok lekérése

A `ZPR_DOC_STATUS.abap` a QU5 `ZEBF_PR_DOC_STATUS` helyi WIP DHC-megfelelője, egyetlen ABAP-forrásban, beágyazott tiszta Unit-tesztekkel. A státusz-/hibamentés, ArchiveLink-kezelés és ragszámtörlés DHC-táblákra épül. A felhasználó kérésére az e-számla-, számlahitelesítési és push-ágak teljes eredeti forrása jelölve, kikommentezve megmaradt. A DOC_SLOG időbélyegkulcsának ütközése hibát ad, nem ír felül másik státuszt.

[Bemásolás, kikapcsolt ágak, adatmodell és ellenőrzések](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/info.md/2026-10-15_doc-status-dhc-bemasolas_WIP.md>). MCP-vel csak olvasás történt; a helyi parser hibamentes, SAP-fordítás és tesztfuttatás nincs.

## A DC riport DDIC-előfeltételei

A `ZPR_DCQM_EXCLUDE` a megvalósítási terv L1–L7 objektumait igényli.
`Type "ZPRS_DCQM_REPORT" is unknown` esetén a struktúrát létre kell hozni
vagy aktiválni: [Mai struktúradefiníció](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/info.md/2026-10-08_zprs-dcqm-report-letrehozas_WIP.md>).

A felhasználó által létrehozott `ZPRT_DCQMLT` dokumentumazonosítója
`EXBILLDOCNO`; a riport hosszú szöveghez kapcsolódó hivatkozásai ezt használják.
A `ZPRT_DCQM` és az ALV dokumentumazonosítója továbbra is `DOC_NO`.

A `ZPRT_DCQM` stockmezőjének SAP-ban jelzett neve `PRD_STOCK_ID`.
A riport, a keretprogram és az ALV-mezőlista ehhez igazítva. A korábbi
`PRDSTOCK` név a helyi `01_SOURCES/DHC/ZPRT_DCQM.table` exportból származott;
ez az export ennél a mezőnél eltér a felhasználó által jelzett SAP-definíciótól.

2026-10-08: a frissített `ZPRT_DCQM.table` export már `PRD_STOCK_ID`-t és
a hat létrehozási/módosítási mezőt tartalmazza. A riport és a keretprogram
mentése frissíti a saját alaptáblájának `CHUSER`, `CHDATE`, `CHTIME` mezőit.
Az ALV-specifikációban a `BOCK_DC_TEXT`/`DOC_CATL` elírások javítva;
a helyes komponensnevek `BLOCK_DC_TEXT`/`DOC_CAT`. Az ALV 39 komponensű marad.

## DC-üzenetek a ZPR osztályban

A két program DC-üzenetei a megadott DHC-exportban szabad **045–066**
számokra vannak átvezetve. Ezeket a programok használata előtt SE91-ben
fel kell venni a meglévő `ZPR` osztályba. A `000–044` meglévő üzenetek megmaradnak.

- [SE91-lépések és a 22 új üzenet teljes szövege](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/info.md/2026-10-08_dc-zpr-uzenetek-letrehozasa_WIP.md>)
- [Másolható üzenetlista](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/2026-10-08_dc-zpr-uj-uzenetek_WIP.message>)
- [A két program változásai a közvetlenül korábbi helyi kódhoz képest](<../../../../../../%5B03%5D%20projects/tomeges-nyomtatas-endre/04_ASSETS/abap/info.diff/2026-10-08_dc-zpr-uzenetek-atvezetes_WIP.diff>)

A számok szabadságát az aktuális DHC-ban is ellenőrizni kell. SAP-objektumot
ez a helyi átvezetés nem módosított; SAP-szintaxisellenőrzés és ATC nem futott.
