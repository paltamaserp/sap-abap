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
