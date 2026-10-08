# 04_ASSETS/abap — WIP ABAP export

Ide kerül a **munka közbeni** `.abap` export (osztály, report, függvénymodul,
DDL) — verziózáshoz, diffeléshez.

- Az ABAP objektum **igazi helye a SAP rendszer**; a `.abap` fájl csak másolat.
  Az igazság forrása az ADT / MCP-n olvasott aktív verzió.
- Fájlnév a SAP objektum neve: `ZCL_<PREFIX>_<OBJEKTUM>.abap`. A `<PREFIX>` a
  projekt saját prefixe — lásd `00_BRIEF.md`, Kulcs-konvenciók.
- Ha kész és kiajánlásra vár → tedd át `05_FINAL/`-ba (lásd az ottani README-t
  az ABAP Unit konvencióról).
- Diff a SAP-beli előző verzióhoz: `Get*VersionDiff` MCP tool.

## A DC riport DDIC-előfeltételei

A `ZPR_DCQM_EXCLUDE` a megvalósítási terv L1–L7 objektumait igényli.
`Type "ZPRS_DCQM_REPORT" is unknown` esetén a struktúrát létre kell hozni
vagy aktiválni: [SE11-mezőlista és beállítások](2026-10-08_zprs-dcqm-report-letrehozas_WIP.md).

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

- [SE91-lépések és a 22 új üzenet teljes szövege](2026-10-08_dc-zpr-uzenetek-letrehozasa_WIP.md)
- [Másolható üzenetlista](2026-10-08_dc-zpr-uj-uzenetek_WIP.message)
- [A két program változásai a közvetlenül korábbi helyi kódhoz képest](2026-10-08_dc-zpr-uzenetek-atvezetes_WIP.diff)

A számok szabadságát az aktuális DHC-ban is ellenőrizni kell. SAP-objektumot
ez a helyi átvezetés nem módosított; SAP-szintaxisellenőrzés és ATC nem futott.
