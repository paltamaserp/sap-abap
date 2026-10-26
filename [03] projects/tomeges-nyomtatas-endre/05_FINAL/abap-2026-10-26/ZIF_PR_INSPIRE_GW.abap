"! Az Inspire nyomtatásszolgáltató webszolgáltatásainak vékony burka. Minden
"! hívás szinkron proxyhívás, amely mérten (2026-10-10) implicit COMMIT-ot
"! vált ki: a hívás commitolja a hívás előtti adatbázis-módosításokat.
"! Ezért a hívás előtt nem lehet függő írás, amelyet hiba esetén vissza
"! kellene görgetni.
INTERFACE zif_pr_inspire_gw PUBLIC.

  TYPES tt_string TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
  TYPES tt_envelope TYPE STANDARD TABLE OF zprd_envelope_id WITH DEFAULT KEY.

  "! Egy feltöltendő fájl: a fájlnév és az XML-tartalom (tömörítetlenül).
  TYPES:
    BEGIN OF ts_file,
      file_name TYPE string,
      xml       TYPE string,
    END OF ts_file.
  TYPES tt_file TYPE STANDARD TABLE OF ts_file WITH DEFAULT KEY.

  "! Egy csoport a stock-feladásban: a minta azonosítója (üres a maradék
  "! csoportnál) és a csoport dokumentum-azonosítói.
  TYPES:
    BEGIN OF ts_group,
      sample_id TYPE string,
      id        TYPE tt_string,
    END OF ts_group.
  TYPES tt_group TYPE STANDARD TABLE OF ts_group WITH DEFAULT KEY.

  "! Az Inspire egyszerű válasza.
  TYPES:
    BEGIN OF ts_response,
      success    TYPE abap_bool,
      info       TYPE string,
      error_code TYPE string,
    END OF ts_response.

  "! A minta-PDF válasza: a tartalom már kicsomagolt (bináris) alakban van.
  TYPES:
    BEGIN OF ts_pdf,
      success    TYPE abap_bool,
      content    TYPE xstring,
      info       TYPE string,
      error_code TYPE string,
    END OF ts_pdf.

  "! Feltölti a fájlokat (gzip és base64 kódolással). A hívás commitolja a
  "! hívás előtti adatbázis-módosításokat, ezért hívás előtt nem lehet függő írás.
  "! @parameter it_file | a feltöltendő fájlok
  "! @parameter rv_success | igaz, ha az Inspire elfogadta a feltöltést
  "! @raising zcx_form_message_error | technikai hiba a proxyhívásban
  METHODS upload_files
    IMPORTING
      it_file           TYPE tt_file
    RETURNING
      VALUE(rv_success) TYPE abap_bool
    RAISING
      zcx_form_message_error.

  "! Jelzi az Inspire-nak, hogy a stock fájljai feltöltődtek, és megadja a
  "! mintacsoportokat. A hívás commitolja a hívás előtti adatbázis-módosításokat,
  "! ezért hívás előtt nem lehet függő írás.
  "! @parameter iv_stock_id | a stock azonosítója
  "! @parameter iv_priority | a feldolgozás prioritása
  "! @parameter iv_notest | a stock tesztjelzője (tiszta címkijelzés kényszerítése)
  "! @parameter it_file_name | a feltöltött fájlok nevei
  "! @parameter it_group | a mintacsoportok és a maradék
  "! @parameter rs_response | az Inspire válasza
  "! @raising zcx_form_message_error | technikai hiba a proxyhívásban
  METHODS trigger_stock_completion
    IMPORTING
      iv_stock_id        TYPE zprd_stock_id
      iv_priority        TYPE zprd_priority
      iv_notest          TYPE zprd_notest
      it_file_name       TYPE tt_string
      it_group           TYPE tt_group
    RETURNING
      VALUE(rs_response) TYPE ts_response
    RAISING
      zcx_form_message_error.

  "! Lekéri egy mintakategória minta-PDF-jét. A hívás commitolja a hívás
  "! előtti adatbázis-módosításokat, ezért hívás előtt nem lehet függő írás.
  "! @parameter iv_stock_id | a stock azonosítója
  "! @parameter iv_qm_cat | a mintakategória
  "! @parameter rs_pdf | az Inspire válasza, a PDF kicsomagolva
  "! @raising zcx_form_message_error | technikai hiba a proxyhívásban
  METHODS get_sample_pdf
    IMPORTING
      iv_stock_id   TYPE zprd_stock_id
      iv_qm_cat     TYPE zprd_qm_cat
    RETURNING
      VALUE(rs_pdf) TYPE ts_pdf
    RAISING
      zcx_form_message_error.

  "! Közli az Inspire-ral a stock végső engedélyezését és a kizárt
  "! borítékokat. A hívás commitolja a hívás előtti adatbázis-módosításokat,
  "! ezért hívás előtt nem lehet függő írás.
  "! @parameter iv_stock_id | a stock azonosítója
  "! @parameter iv_priority | a feldolgozás prioritása
  "! @parameter it_envelope | a kizárt dokumentumokat tartalmazó borítékok
  "! @parameter rs_response | az Inspire válasza
  "! @raising zcx_form_message_error | technikai hiba a proxyhívásban
  METHODS dcqm_completed
    IMPORTING
      iv_stock_id        TYPE zprd_stock_id
      iv_priority        TYPE zprd_priority
      it_envelope        TYPE tt_envelope
    RETURNING
      VALUE(rs_response) TYPE ts_response
    RAISING
      zcx_form_message_error.

ENDINTERFACE.