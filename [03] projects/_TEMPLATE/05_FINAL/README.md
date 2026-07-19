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
   Egy objektum, egy transzport. Export: a DAO `.abap` végén jelenik meg.

2. **Külön export-fájl** — ha a teszt láthatóságát külön akarod verziózni:
   `ZCL_EPT_<xxx>_DAO_TEST.abap` a DAO mellett.

### Minta beágyazott teszt (Test Double-lel)

```abap
CLASS ltc_account_dao DEFINITION FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_ept_account_dao.  " code under test
    METHODS setup.
    METHODS get_account_returns_data FOR TESTING.
ENDCLASS.

CLASS ltc_account_dao IMPLEMENTATION.
  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.
  METHOD get_account_returns_data.
    " GIVEN / WHEN / THEN
    cl_abap_unit_assert=>assert_not_initial( act = ... msg = '...' ).
  ENDMETHOD.
ENDCLASS.
```

- DB/hívás izoláláshoz **Test Seam** vagy interfész-mock (a DAO már interfész mögött van:
  `ZCL_IF_DAO`).
- `DURATION SHORT`, `RISK LEVEL HARMLESS` alapból; DB-t érintő tesztnél emeld.
- ATC (statikus ellenőrzés) az oneERP guideline szerint kötelező quality gate a
  kiajánlás előtt — az AUnit mellé, nem helyette.
