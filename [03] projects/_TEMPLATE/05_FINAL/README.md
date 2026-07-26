# 05_FINAL — kész ABAP objektumok + ABAP Unit

Ide kerül a kész, kiajánlás előtti eredmény: ABAP osztályok, struktúrák,
provider osztályok `.abap` exportként (verziózáshoz).

## ABAP Unit tesztek

Az ABAP Unit teszt **a SAP rendszerben él**, nem a lemezen fut. A repóban lévő
`.abap` fájl csak export/verziózás — a futtatás ADT-ben (`Run As → ABAP Unit`)
vagy az ADT MCP-n keresztül történik.

Két konvenció, projektfüggő:

1. **Beágyazott (SAP natív, ajánlott)** — a teszt-osztály a tesztelt osztály
   *Local Test Classes* include-jában (`CLASS ..._TEST DEFINITION FOR TESTING`).
   Egy objektum, egy transzport. Export: a tesztelt osztály `.abap` végén
   jelenik meg.

2. **Külön export-fájl** — ha a teszt láthatóságát külön akarod verziózni:
   `ZCL_<PREFIX>_<OBJEKTUM>_TEST.abap` a tesztelt osztály mellett.

A `<PREFIX>` a projekt saját prefixe — lásd `00_BRIEF.md`, Kulcs-konvenciók.

### Minta beágyazott teszt

```abap
CLASS ltc_<objektum> DEFINITION FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_<prefix>_<objektum>.  " code under test
    METHODS setup.
    METHODS <mit_vizsgal> FOR TESTING.
ENDCLASS.

CLASS ltc_<objektum> IMPLEMENTATION.
  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.
  METHOD <mit_vizsgal>.
    " GIVEN / WHEN / THEN
    cl_abap_unit_assert=>assert_not_initial( act = ... msg = '...' ).
  ENDMETHOD.
ENDCLASS.
```

- DB/hívás izoláláshoz **Test Seam** vagy interfész-mock. Ha a tesztelt osztály
  interfész mögött van, a mock azon keresztül adható be (konstruktor-injektálás).
- `DURATION SHORT`, `RISK LEVEL HARMLESS` alapból; DB-t érintő tesztnél emeld.
- ATC (statikus ellenőrzés) az oneERP guideline szerint kötelező quality gate a
  kiajánlás előtt — az AUnit mellé, nem helyette.
