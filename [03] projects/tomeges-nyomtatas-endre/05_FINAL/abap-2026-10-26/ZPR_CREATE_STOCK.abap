REPORT zpr_create_stock MESSAGE-ID zpr.

*&---------------------------------------------------------------------*
*& Report ZPR_CREATE_STOCK
*---------------------------------------------------------------*
* Rövid leírás: Tömeges nyomtatás – a kijelölt csomagokból stockot képez,
*               a dokumentumok XML-jét feltölti az Inspire-be, majd
*               feladja a stockot a mintacsoportokkal
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
* 2026.10.10.   X0086         process_package: mintakategória-képzés és
*                             TRIGGER_STOCK_COMPLETION a DU5-ös
*                             ZEBF_PR_TRIGGER_INSPIRE szerint; a régi
*                             változat process_package_old néven;
*                             napló mentése gombnyomásonként
*---------------------------------------------------------------*
* Deklaráció
TABLES: zprt_package.
TYPES: BEGIN OF ts_pck,
         selected  TYPE abap_bool.
         INCLUDE STRUCTURE  zprt_package.
TYPES:   doc_count TYPE i.
TYPES:   counter   TYPE i.
TYPES: END OF ts_pck,
tt_pck TYPE TABLE OF ts_pck.


DATA gv_stock_size TYPE sytabix.
DATA gt_documents TYPE tt_pck.
DATA gv_dummy_message.
DATA go_log TYPE REF TO zcl_pr_log.
DATA gv_obj  TYPE balobj_d VALUE 'ZPR_MASS'.
DATA gv_subobj  TYPE balsubobj VALUE 'STOCK'.

* A csomaglista ALV-rácsa (CL_GUI_ALV_GRID) és konténere
DATA: gr_grid TYPE REF TO cl_gui_alv_grid.
DATA: gr_container TYPE REF TO cl_gui_custom_container.
*data: gr_events type ref to lcl_handle_events.
DATA: gv_okcode TYPE syucomm.


INITIALIZATION.
  AUTHORITY-CHECK OBJECT 'S_TCODE'
  ID 'TCD' FIELD 'ZPR_CREATE_STOCK'.

  IF sy-subrc <> 0.
    MESSAGE i096 WITH sy-tcode 'tranzakcióhoz!'.
    LEAVE PROGRAM.
  ENDIF.

*---------------------------------------------------------------*
* Szelekciós feltételek
  SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
    SELECT-OPTIONS: so_pckg   FOR zprt_package-package_id,
                    so_user   FOR zprt_package-cruser,
                    so_date   FOR zprt_package-crdate.
*                  so_stat   FOR zprt_package-status.
*   PARAMETERS p_mass LIKE zprt_doc_log-printer DEFAULT 'MASS' MODIF ID dis.
  SELECTION-SCREEN END OF BLOCK b1.

* Stock
  SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
*  PARAMETERS: pa_stock LIKE zprt_doc_log-stock_id.
  SELECTION-SCREEN END OF BLOCK b2.

*SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
*  PARAMETERS: pa_first RADIOBUTTON GROUP g1 DEFAULT 'X'.
*  PARAMETERS: pa_again   RADIOBUTTON GROUP g1.
*SELECTION-SCREEN END OF BLOCK b3.
*---------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF screen-group1 EQ 'DIS'.
      screen-input = 0.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
*---------------------------------------------------------------*
START-OF-SELECTION.

**---------------------------------------------------------------*
** Napló megnyitása
*  go_log = NEW zcl_pr_log(
*    iv_log_object    = gv_obj
*    iv_log_subobject = gv_subobj ).


* A csomagokat a szűrők szerint olvassuk, és ALV-ben jelenítjük meg.

*---------------------------------------------------------------*
* Alapértelmezett futás: a stockba még nem került csomagok listája
*  IF pa_first = abap_true.

*  PERFORM get_stock_size CHANGING gv_stock_size.

  SELECT *
    FROM zprt_package
    INTO CORRESPONDING FIELDS OF TABLE @gt_documents
*      PACKAGE SIZE @gv_stock_size
    WHERE  package_id IN @so_pckg
     AND   cruser     IN @so_user
     AND   crdate     IN @so_date
     AND   stock_id   EQ 0
     AND   status     = 'X'.

  PERFORM get_package_doc_counts.

*    ENDSELECT.
*  ENDIF.

START-OF-SELECTION.

  PERFORM display_fullscreen.


*---------------------------------------------------------------*
*& Form process_package
*---------------------------------------------------------------*
*& Stock képzése a kijelölt csomagokból, mintakategóriákkal
*& (a DU5-ös ZEBF_PR_TRIGGER_INSPIRE menete szerint)
*---------------------------------------------------------------*
*& -->  ut_documents  a listán megjelenített csomagok
*---------------------------------------------------------------*
FORM process_package USING ut_documents TYPE tt_pck.
* A naplót minden gombnyomás után azonnal elmentjük, mert a program
* végi mentés elmarad, ha a felhasználó nem a Vissza gombbal lép ki.
* A mentés commitol, de ekkor már nincs függőben üzleti írás.
  PERFORM create_stock USING ut_documents.
* Napló lezárása
  IF go_log IS BOUND.
    go_log->close(  ).
    FREE go_log.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------*
*& Form create_stock
*---------------------------------------------------------------*
*& A stock-képzés menete (a process_package hívja)
*---------------------------------------------------------------*
*& -->  ut_documents  a listán megjelenített csomagok
*---------------------------------------------------------------*
FORM create_stock USING ut_documents TYPE tt_pck.
*---------------------------------------------------------------*
* A lépések sorrendje a régi rendszerét követi: előbb minden csak
* memóriában készül el (stock-szám, dokumentumok, mintakategóriák),
* aztán jön a feltöltés és a stock feladása az Inspire felé, és csak
* sikeres feladás után írunk adatbázist. Az Inspire-hívás ugyanis
* commitolja a hívás előtti módosításokat, ezért a hívások előtt nem
* maradhat függőben visszagörgetendő írás.
*---------------------------------------------------------------*
* Deklaráció
  " Az Inspire-nek átadott és a stock táblába írt prioritás.
  CONSTANTS lc_priority TYPE zprd_priority VALUE 30.

  DATA lr_package   TYPE RANGE OF zprt_package-package_id.
  DATA lt_package_id TYPE zif_pr_qm_data=>tt_package_id.
  DATA lt_doc_no    TYPE zif_pr_qm_data=>tt_doc_no.
  DATA lt_file      TYPE zif_pr_inspire_gw=>tt_file.
  DATA lt_file_name TYPE zif_pr_inspire_gw=>tt_string.
  DATA lt_group     TYPE zif_pr_inspire_gw=>tt_group.
  DATA ls_sample    TYPE zcl_pr_qm_sampler=>ts_result.
  DATA ls_response  TYPE zif_pr_inspire_gw=>ts_response.
  DATA ls_stock     TYPE zprt_stock.
  DATA lo_data      TYPE REF TO zif_pr_qm_data.
  DATA lo_gateway   TYPE REF TO zif_pr_inspire_gw.
  DATA lv_stock_id  TYPE zprd_stock_id.
  DATA lv_text      TYPE string.
  DATA lv_count     TYPE string.
  DATA lv_count2    TYPE string.
  DATA lv_triggered TYPE abap_bool.
  DATA lv_datum(10).
  DATA lv_uzeit(8).
  DATA: lv_total_doc_no     TYPE sytabix,
        lv_total_package_no TYPE sytabix,
        lv_doc_no           TYPE sytabix.

*---------------------------------------------------------------*
  gr_grid->check_changed_data( ).

*---------------------------------------------------------------*
* Kijelölt csomagok; kijelölés nélkül nem lépünk tovább, mert az
* üres tartomány az egész táblát jelentené
  lr_package = VALUE #( FOR ls_pck IN ut_documents WHERE ( selected EQ abap_true )
                                                         ( sign = 'I' option = 'EQ' low = ls_pck-package_id ) ).
  IF lr_package IS INITIAL.
    MESSAGE s047 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  lt_package_id = VALUE #( FOR ls_range IN lr_package ( ls_range-low ) ).

*---------------------------------------------------------------*
* Írás nélküli ellenőrzés: a kijelölt csomagok mindegyike szabad-e
* még, mert a listát közben más is feldolgozhatta
  SELECT COUNT(*)
    FROM zprt_package
    WHERE package_id IN @lr_package
      AND stock_id   EQ 0
    INTO @DATA(lv_free).
  IF lv_free NE lines( lt_package_id ).
    MESSAGE e001(zpr_func) INTO gv_dummy_message.
*    go_log->add_system_message( ).
*   MESSAGE s001(zpr_func) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*---------------------------------------------------------------*
* Stock-azonosító kérése a számkörből; üres azonosító = sikertelen kérés
  PERFORM get_stock_id CHANGING lv_stock_id.
  IF lv_stock_id IS INITIAL.
    MESSAGE e002(zpr_func). "INTO gv_dummy_message.
*    go_log->add_system_message( ).
*   MESSAGE s002(zpr_func) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*---------------------------------------------------------------*
* Napló megnyitása, stock azonosítóval
  go_log = NEW zcl_pr_log(
    iv_log_object    = gv_obj
    iv_log_subobject = gv_subobj
    iv_ext_id        = lv_stock_id ).

*---------------------------------------------------------------*
* A feltöltendő dokumentumok: csak az kerül a stockba, amelyhez van
* XML, így a fájlok és a feladott azonosítók halmaza azonos
  SELECT dcqm~doc_no, docdata~data
    FROM zprt_dcqm AS dcqm
    INNER JOIN zprt_doc_data AS docdata
      ON docdata~doc_no EQ dcqm~doc_no
    WHERE dcqm~package_id IN @lr_package
    ORDER BY dcqm~doc_no
    INTO TABLE @DATA(lt_xml).
  IF lt_xml IS INITIAL.
    MESSAGE e003(zpr_func) INTO gv_dummy_message.
    go_log->add_system_message( ).
*   MESSAGE s003(zpr_func) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*---------------------------------------------------------------*
* Fájlok: dokumentumonként egy. A név a régi (DU5) mintát követi: rendszer,
* kliens, majd a stock-azonosító és a dokumentumszám (a régi névben ezek
* a spool adatainak helyén álltak), így a nevek nem ütköznek
  LOOP AT lt_xml INTO DATA(ls_xml).
    APPEND VALUE #( file_name = |{ sy-sysid }_{ sy-mandt }_{ lv_stock_id }_{ ls_xml-doc_no }.xml|
                    xml       = ls_xml-data )
      TO lt_file ASSIGNING FIELD-SYMBOL(<ls_file>).
    APPEND <ls_file>-file_name TO lt_file_name.
    APPEND ls_xml-doc_no TO lt_doc_no.
  ENDLOOP.

*---------------------------------------------------------------*
* Átadott XML állományok képzése
  CLEAR lt_file_name[].
  SELECT package_id,
         xml_file_name
      FROM zprt_package
      WHERE package_id IN @lr_package
      ORDER BY package_id
      INTO TABLE @DATA(lt_package_file).

*---------------------------------------------------------------*
* Csomag készítéskor XML állományok és statisztika képzése
  CLEAR lv_total_doc_no.
  CLEAR lv_total_package_no.
  LOOP AT lt_package_file INTO DATA(ls_package_file).
    APPEND ls_package_file-xml_file_name TO lt_file_name.
    CLEAR lv_doc_no.
    SELECT COUNT( * )
      INTO lv_doc_no
      FROM zprt_dcqm
      WHERE package_id = ls_package_file-package_id.
    MESSAGE s020(zpr_func) WITH ls_package_file-package_id
                                lv_doc_no INTO gv_dummy_message.
    go_log->add_system_message( ).
    ADD lv_doc_no TO lv_total_doc_no.
    ADD 1 TO lv_total_package_no.
  ENDLOOP.
  MESSAGE s021(zpr_func) WITH lv_total_package_no INTO gv_dummy_message.
  go_log->add_system_message( ).
  MESSAGE s022(zpr_func) WITH lv_total_doc_no INTO gv_dummy_message.
  go_log->add_system_message( ).

*---------------------------------------------------------------*
* Statisztika a kimaradtakból
  CLEAR lv_total_doc_no.
  CLEAR lv_total_package_no.
  LOOP AT ut_documents INTO DATA(ls_doc)
    WHERE selected EQ space.
    CLEAR lv_doc_no.
    SELECT COUNT( * )
      INTO lv_doc_no
      FROM zprt_dcqm
      WHERE package_id = ls_doc-package_id.
    MESSAGE s023(zpr_func) WITH ls_doc-package_id
                                lv_doc_no INTO gv_dummy_message.
    go_log->add_system_message( ).
    ADD lv_doc_no TO lv_total_doc_no.
    ADD 1 TO lv_total_package_no.
  ENDLOOP.
  MESSAGE s024(zpr_func) WITH lv_total_package_no INTO gv_dummy_message.
  go_log->add_system_message( ).
  MESSAGE s025(zpr_func) WITH lv_total_doc_no INTO gv_dummy_message.
  go_log->add_system_message( ).

*---------------------------------------------------------------*
  TRY.
      lo_data    = NEW zcl_pr_qm_data( ).
      lo_gateway = NEW zcl_pr_inspire_gw( ).

*---------------------------------------------------------------*
* Mintakategóriák képzése (csak memóriában)
      ls_sample = NEW zcl_pr_qm_sampler( io_data   = lo_data
                                         io_random = NEW zcl_pr_qm_random( )
                )->build( iv_stock_id   = lv_stock_id
                          it_package_id = lt_package_id
                          it_doc_no     = lt_doc_no ).

* Kategóriánként egy csoport a mintával, a végén pedig egy üres
* azonosítójú csoport minden többi dokumentummal, ahogy a régi
* rendszer is küldte
      LOOP AT ls_sample-groups INTO DATA(ls_cat_group).
        APPEND VALUE #( sample_id = CONV string( ls_cat_group-qm_cat )
                        id        = VALUE #( FOR lv_id IN ls_cat_group-doc_no
                                      ( CONV string( lv_id ) ) ) )
          TO lt_group.
      ENDLOOP.
      APPEND VALUE #( id = VALUE #( FOR lv_id IN ls_sample-rest
                                    ( CONV string( lv_id ) ) ) )
        TO lt_group.

*---------------------------------------------------------------*
** Ez már az előző lépésben megtörtént
** Fájlok feltöltése; a naplósor mutatja, hogy a hívás elindult
*      lv_count = |{ lines( lt_file ) }|.
*      MESSAGE s006(zpr_func) WITH lv_count lv_stock_id INTO gv_dummy_message.
*      go_log->add_system_message( ).
*      IF lo_gateway->upload_files( lt_file ) EQ abap_false.
*        MESSAGE e030 INTO gv_dummy_message.
*        go_log->add_system_message( ).
*        MESSAGE s030 DISPLAY LIKE 'E'.
*        RETURN.
*      ENDIF.

*---------------------------------------------------------------*
* A stock feladása a mintacsoportokkal
      lv_count2 = |{ lines( lt_group ) }|.
      MESSAGE s007(zpr_func) WITH lv_stock_id lv_count2 INTO gv_dummy_message.
      go_log->add_system_message( ).
      WRITE: sy-datum TO lv_datum USING EDIT MASK '____.__.__'.
      WRITE: sy-uzeit TO lv_uzeit USING EDIT MASK '__:__:__'.
      MESSAGE s018(zpr_func) WITH lv_datum lv_uzeit INTO gv_dummy_message.
      go_log->add_system_message( ).
      ls_response = lo_gateway->trigger_stock_completion( iv_stock_id  = lv_stock_id
                                                          iv_priority  = lc_priority
                                                          iv_notest    = space
                                                          it_file_name = lt_file_name
                                                          it_group     = lt_group ).
      WRITE: sy-datum TO lv_datum USING EDIT MASK '____.__.__'.
      WRITE: sy-uzeit TO lv_uzeit USING EDIT MASK '__:__:__'.
      MESSAGE s019(zpr_func) WITH lv_datum lv_uzeit INTO gv_dummy_message.
      go_log->add_system_message( ).
      IF ls_response-success EQ abap_false.
        MESSAGE e030 INTO gv_dummy_message.
        go_log->add_system_message( ).
        lv_text = |{ ls_response-error_code } { ls_response-info }|.
        PERFORM add_log_text USING lv_text.
        RETURN.
      ENDIF.
      lv_triggered = abap_true.

*---------------------------------------------------------------*
* Adatbázis-írás a sikeres feladás után, egyetlen tranzakcióban
      ls_stock-stock_id = lv_stock_id.
      MOVE-CORRESPONDING zcl_pr_admin=>get_create_data( ) TO ls_stock.
      ls_stock-priority = lc_priority.
      INSERT zprt_stock FROM @ls_stock.
      IF sy-subrc NE 0.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e029(zpr)
          WITH lv_stock_id.
      ENDIF.

* Csak a még szabad csomag kapja meg a stockot; ha nem mindegyik
* frissült, valaki közben elvitte valamelyiket
      UPDATE zprt_package
        SET stock_id = @lv_stock_id,
            crdate   = @ls_stock-crdate,
            crtime   = @ls_stock-crtime,
            cruser   = @ls_stock-cruser
        WHERE package_id IN @lr_package
          AND stock_id   EQ 0.
      IF sy-subrc NE 0 OR sy-dbcnt NE lines( lt_package_id ).
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e004(zpr_func)
          WITH lv_stock_id.
      ENDIF.

      lo_data->update_dcqm_stock( it_doc_no   = lt_doc_no
                                  iv_stock_id = lv_stock_id ).
      IF ls_sample-assignments IS NOT INITIAL.
        lo_data->insert_assignments( ls_sample-assignments ).
      ENDIF.
      IF ls_sample-exclusions IS NOT INITIAL.
        lo_data->insert_exclusion_rows( ls_sample-exclusions ).
      ENDIF.

      COMMIT WORK.
      MESSAGE s031 WITH lv_stock_id INTO gv_dummy_message.
      go_log->add_system_message( ).
      MESSAGE s031 WITH lv_stock_id.

    CATCH zcx_form_message_error INTO DATA(lx_error).
      ROLLBACK WORK.
      lv_text = lx_error->get_text( ).
      PERFORM add_log_text USING lv_text.
* Ha a feladás már megtörtént, az Inspire-nél a stock létezik, SAP-ban
* viszont nem: ezt külön jelezzük, a stock-számmal együtt
      IF lv_triggered EQ abap_true.
        MESSAGE e005(zpr_func) WITH lv_stock_id INTO gv_dummy_message.
        go_log->add_system_message( ).
        MESSAGE s005(zpr_func) DISPLAY LIKE 'E' WITH lv_stock_id.
      ENDIF.
  ENDTRY.

ENDFORM.

FORM process_package_old USING ut_documents TYPE tt_pck.
*---------------------------------------------------------------*
* Deklaráció
  DATA lv_lines TYPE sytabix.
  DATA lt_data TYPE TABLE OF zprt_doc_data.
  DATA ls_data TYPE zprt_doc_data.
  DATA lv_stock_id TYPE zprd_stock_id.
  DATA lv_base64  TYPE string.
  DATA lv_gzip TYPE xstring.
  DATA lv_logical_port_name TYPE prx_logical_port_name.
  DATA lv_xml TYPE string.
  DATA lv_xmlx TYPE xstring.
  DATA ls_input	  TYPE zpr_eon_forms_uploader_reques2.
  DATA ls_output  TYPE zpr_eon_forms_uploader_respons.
  DATA ls_xmlfile LIKE LINE OF ls_input-eon_forms-xmlfile.
  DATA lo_pr TYPE REF TO zpr_co_eon_forms_uploader_port.
  DATA ls_stock TYPE zprt_stock.
  DATA lt_package_upd TYPE TABLE OF zprt_package.
  DATA lt_doc TYPE TABLE OF zprt_dcqm.
  DATA ls_doc TYPE zprt_dcqm.

  gr_grid->check_changed_data( ).
*---------------------------------------------------------------*
* Feldolgozandó rekordok száma
  DESCRIBE TABLE ut_documents LINES lv_lines.
*  IF lv_lines IS INITIAL.
*    EXIT.
*  ENDIF.

*---------------------------------------------------------------*
* Stock azonosító kinyerése
  PERFORM get_stock_id CHANGING lv_stock_id.

* ---------------------------------------------------------------*
* Logikai port előállítása
  lv_logical_port_name = zcl_pr_output_management=>get_logical_port_name(  ).

* ---------------------------------------------------------------*
* Proxy objektum létrehozása
  TRY.
      CREATE OBJECT lo_pr
        EXPORTING
*         destination       = lo_destination
          logical_port_name = lv_logical_port_name.
    CATCH cx_ai_system_fault INTO DATA(lx_system_fault). " Application Integration: Technical Error
*      MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO gv_dummy_message.
      gv_dummy_message = zcl_pr_admin=>get_cx_message( io_cx = lx_system_fault iv_out = abap_false ).
      go_log->add_system_message(  ).
  ENDTRY.

*---------------------------------------------------------------*
* XML adatok összegyűjtése rekordszám függvényében eltérő módon
  REFRESH lt_data.

  LOOP AT ut_documents INTO DATA(ls_package)
    WHERE selected = 'X'.
    ls_package-stock_id = lv_stock_id.
    APPEND ls_package TO lt_package_upd.

    SELECT *
      INTO CORRESPONDING FIELDS OF TABLE lt_doc
      FROM zprt_dcqm
      WHERE package_id = ls_package-package_id.

    LOOP AT lt_doc INTO ls_doc.
      SELECT SINGLE *
      FROM zprt_doc_data
      INTO CORRESPONDING FIELDS OF ls_data
      WHERE doc_no EQ ls_doc-doc_no.
      IF sy-subrc = 0.
        APPEND ls_data TO lt_data.
      ENDIF.
    ENDLOOP.
  ENDLOOP.

*---------------------------------------------------------------*
* XML adatok feldolgozása
  CLEAR ls_input.
  DATA lv_tabix TYPE char1.
  LOOP AT lt_data INTO ls_data.
    CLEAR ls_xmlfile.

*    lv_base64 = zcl_pr_file_converter=>encode_xtring_to_base64( lv_xmlx ).
** Fájlnév
    MOVE sy-tabix TO lv_tabix.
    CONCATENATE 'Teszt_A_B_C' lv_tabix lv_stock_id INTO ls_xmlfile-file_name SEPARATED BY '_'.
    CONCATENATE ls_xmlfile-file_name 'xml' INTO ls_xmlfile-file_name SEPARATED BY '.'.

** Fájl konverzió
    lv_xmlx   = zcl_pr_file_converter=>convert_string_to_xstring( ls_data-data ).
    lv_gzip = zcl_pr_file_converter=>gzip_xstring( EXPORTING iv_xfile    = lv_xmlx
                                                             iv_filename = ls_xmlfile-file_name ).
    lv_base64 = zcl_pr_file_converter=>encode_xtring_to_base64( lv_gzip ).

** Hívás felparaméterezése
    ls_xmlfile-base64 = 'X'.
    ls_xmlfile-zipped = 'X'.
    MOVE: lv_base64    TO ls_xmlfile-file_contents.
    APPEND ls_xmlfile TO ls_input-eon_forms-xmlfile.
*    IF sy-tabix = 2.
*      EXIT.
*    ENDIF.
  ENDLOOP.

*---------------------------------------------------------------*
* Inspire hívás
  TRY.
      lo_pr->eon_forms_uploader(
        EXPORTING
          input  = ls_input
        IMPORTING
          output = ls_output ).

    CATCH cx_ai_system_fault INTO lx_system_fault.
*      MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO gv_dummy_message.
      gv_dummy_message = zcl_pr_admin=>get_cx_message( io_cx = lx_system_fault iv_out = abap_false ).
      go_log->add_system_message(  ).
    CATCH cx_ai_application_fault INTO DATA(lx_application_fault).
*      MESSAGE e000 WITH lx_application_fault->get_text(  ) INTO gv_dummy_message.
      gv_dummy_message = zcl_pr_admin=>get_cx_message( io_cx = lx_application_fault iv_out = abap_false ).
      go_log->add_system_message(  ).
  ENDTRY.

*---------------------------------------------------------------*
* Egyéb hiba kezelése
  IF ls_output-parameters-success NE abap_true.
    MESSAGE e030 INTO gv_dummy_message WITH lv_stock_id.
    go_log->add_system_message(  ).
  ENDIF.

*---------------------------------------------------------------*
* Sikeres hívás esetén AB írás
  IF ls_output-parameters-success EQ abap_true.
    MESSAGE s031 INTO gv_dummy_message WITH lv_stock_id.
    go_log->add_system_message(  ).

    CLEAR ls_stock.
    ls_stock-stock_id = lv_stock_id.
    MOVE-CORRESPONDING zcl_pr_admin=>get_create_data(   ) TO ls_stock.
    INSERT INTO zprt_stock VALUES ls_stock.
    IF sy-subrc <> 0.
      MESSAGE e029 INTO gv_dummy_message WITH lv_stock_id.
      go_log->add_system_message(  ).
    ENDIF.

    LOOP AT lt_package_upd INTO ls_package.
      UPDATE zprt_package
        SET stock_id = lv_stock_id
            crdate   = ls_stock-crdate
            crtime   = ls_stock-crtime
            cruser   = ls_stock-cruser
        WHERE package_id = ls_package-package_id.
      IF sy-subrc NE 0.
        CONTINUE.
      ENDIF.
    ENDLOOP.
  ENDIF.
*    LOOP AT ut_documents INTO ls_document.
*      UPDATE zprt_doc_log
*    SET
**    stock_id = lv_stock_id
*         crdate   = ls_stock-crdate
*         crtime   = ls_stock-crtime
*         cruser   = ls_stock-cruser
*    WHERE doc_no = ls_document-doc_no.
*      DATA lv_text(30).
*      SELECT SINGLE text30
*            INTO lv_text
*            FROM zprc_doc_typet
*            WHERE spras = sy-langu
*            AND doc_type = ls_document-doc_type.
*     MESSAGE s032 INTO gv_dummy_message WITH lv_text ls_document-opbel ls_document-doc_no lv_stock_id.
*      go_log->add_system_message(  ).
*    ENDLOOP.

ENDFORM.

*---------------------------------------------------------------*
*& Form add_log_error
*---------------------------------------------------------------*
*& Hibaszöveg naplózása és kiírása a felhasználónak
*---------------------------------------------------------------*
*& -->  uv_text   a hiba szövege
*---------------------------------------------------------------*
FORM add_log_error USING uv_text TYPE csequence.
* Az általános (000) üzenet négy változóba legfeljebb 200 karaktert
* visz, ezért a szöveget 50 karakteres darabokra vágjuk
  DATA lv_text TYPE c LENGTH 200.

  lv_text = uv_text.
  MESSAGE e000 WITH lv_text(50) lv_text+50(50) lv_text+100(50) lv_text+150(50)
    INTO gv_dummy_message.
  go_log->add_system_message( ).
  MESSAGE s000 WITH lv_text(50) lv_text+50(50) lv_text+100(50) lv_text+150(50)
    DISPLAY LIKE 'E'.
ENDFORM.

*---------------------------------------------------------------*
*& Form add_log_text
*---------------------------------------------------------------*
*& Dinamikus hibaszöveg (kivétel vagy Inspire-válasz) naplózása és
*& kiírása a felhasználónak a 009-es általános üzenettel
*---------------------------------------------------------------*
*& -->  uv_text   a hiba szövege
*---------------------------------------------------------------*
FORM add_log_text USING uv_text TYPE csequence.
* Az általános üzenet négy változóba legfeljebb 200 karaktert visz,
* ezért a szöveget 50 karakteres darabokra vágjuk
  DATA lv_part1 TYPE string.
  DATA lv_part2 TYPE string.
  DATA lv_part3 TYPE string.
  DATA lv_part4 TYPE string.

  PERFORM get_text_part USING uv_text 0 CHANGING lv_part1.
  PERFORM get_text_part USING uv_text 1 CHANGING lv_part2.
  PERFORM get_text_part USING uv_text 2 CHANGING lv_part3.
  PERFORM get_text_part USING uv_text 3 CHANGING lv_part4.
  MESSAGE e009(zpr_func) WITH lv_part1 lv_part2 lv_part3 lv_part4
    INTO gv_dummy_message.
  go_log->add_system_message( ).
  MESSAGE s009(zpr_func) DISPLAY LIKE 'E'
    WITH lv_part1 lv_part2 lv_part3 lv_part4.
ENDFORM.

*---------------------------------------------------------------*
*& Form get_text_part
*---------------------------------------------------------------*
*& A szöveg egy 50 karakteres darabját adja vissza (üres, ha a szöveg
*& már véget ért)
*---------------------------------------------------------------*
*& -->  uv_text   a teljes szöveg
*& -->  uv_part   a darab sorszáma (0-tól)
*& <--  cv_part   az 50 karakteres darab
*---------------------------------------------------------------*
FORM get_text_part USING uv_text TYPE csequence
                         uv_part TYPE i
                   CHANGING cv_part TYPE string.
  CONSTANTS lc_part_len TYPE i VALUE 50.
  DATA lv_off TYPE i.
  DATA lv_len TYPE i.

  CLEAR cv_part.
  lv_off = uv_part * lc_part_len.
  lv_len = strlen( uv_text ).
  IF lv_len GT lv_off.
    cv_part = substring( val = uv_text
                         off = lv_off
                         len = nmin( val1 = lc_part_len
                                     val2 = lv_len - lv_off ) ).
  ENDIF.
ENDFORM.

*---------------------------------------------------------------*
*& Form get_stock_size
*---------------------------------------------------------------*
*& A stock méretét a STOCK_SIZE paraméterből olvassa; ha nincs
*& megadva, az alapérték 1
*---------------------------------------------------------------*
*& <--  cv_stock_size   a stock mérete
*---------------------------------------------------------------*
FORM get_stock_size CHANGING cv_stock_size TYPE sytabix.

  DATA lv_stock_size TYPE sytabix.

  lv_stock_size = zcl_pr_admin=>get_parameter_value( 'STOCK_SIZE' ).
  IF lv_stock_size IS INITIAL.
    lv_stock_size = 1.
  ENDIF.

  cv_stock_size = lv_stock_size.

ENDFORM.

*---------------------------------------------------------------*
*& Form get_stock_id
*---------------------------------------------------------------*
*& Új stock-azonosítót kér a ZSTOCK számkörből (NUMBER_GET_NEXT)
*---------------------------------------------------------------*
*& <--  cv_stock_id   az új azonosító; hiba esetén üres
*---------------------------------------------------------------*
FORM get_stock_id CHANGING cv_stock_id TYPE zprd_stock_id.

  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr             = '01'
      object                  = 'ZSTOCK'
    IMPORTING
      number                  = cv_stock_id
    EXCEPTIONS
      interval_not_found      = 1
      number_range_not_intern = 2
      object_not_found        = 3
      quantity_is_0           = 4
      quantity_is_not_1       = 5
      interval_overflow       = 6
      buffer_overflow         = 7
      OTHERS                  = 8.

  IF sy-subrc NE 0.
    " Az üres azonosítóból a hívó felismeri a sikertelen kérést.
    CLEAR cv_stock_id.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form display_fullscreen
*&---------------------------------------------------------------------*
*& A csomaglista megjelenítése teljes képernyőn (0100-as dynpro)
*&---------------------------------------------------------------------*
FORM display_fullscreen.
  CALL SCREEN 0100.
ENDFORM.
*&---------------------------------------------------------------------*
*& Module D0100_PBO OUTPUT
*&---------------------------------------------------------------------*
*& A 0100-as dynpro megjelenítés előtti modulja; a munkát a d0100_pbo FORM végzi
*&---------------------------------------------------------------------*
MODULE d0100_pbo OUTPUT.
  PERFORM d0100_pbo.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  d0100_pai  INPUT
*&---------------------------------------------------------------------*
*       A 0100-as dynpro felhasználói műveletének modulja; a munkát a
*       d0100_pai FORM végzi
*----------------------------------------------------------------------*
MODULE d0100_pai INPUT.
  PERFORM d0100_pai.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Form  d0100_pbo
*&---------------------------------------------------------------------*
*       Beállítja a GUI-státuszt, és első híváskor létrehozza az ALV-rácsot
*----------------------------------------------------------------------*
FORM d0100_pbo.

  SET PF-STATUS 'D0100'.

*  IF gr_container IS NOT BOUND.
  IF gr_grid IS INITIAL.

    CREATE OBJECT gr_grid
      EXPORTING
        i_parent = cl_gui_container=>default_screen.

    PERFORM display_alv.

  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  d0100_pai
*&---------------------------------------------------------------------*
*       A gombok funkciókódjai szerint kilép, feldolgozza a kijelölt
*       csomagokat, illetve kijelöli vagy törli a kijelölést
*----------------------------------------------------------------------*
FORM d0100_pai.

  CASE gv_okcode.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'PROCESS'.
      PERFORM process_package USING gt_documents.
    WHEN 'SELECT_ALL'.
      PERFORM select_all.
    WHEN 'DESELECT_ALL'.
      PERFORM deselect_all.
    WHEN OTHERS.
      " Más funkciókódra nincs teendő.
  ENDCASE.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& A csomaglista ALV-rácsának felépítése: mezőkatalógus a ZPRT_PACKAGE
*& szerkezetből, kijelölő jelölőnégyzet-oszloppal
*&---------------------------------------------------------------------*
FORM display_alv.

  CONSTANTS lc_structure TYPE tabname VALUE 'ZPRT_PACKAGE' ##NO_TEXT.

  DATA: lt_fcat TYPE lvc_t_fcat,
        ls_fcat TYPE lvc_s_fcat,
        ls_layo TYPE lvc_s_layo.
  DATA: lt_fieldcat TYPE  slis_t_fieldcat_alv,
        ls_fieldcat TYPE  slis_fieldcat_alv.


  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = lc_structure
    CHANGING
      ct_fieldcat            = lt_fcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.
  IF sy-subrc NE 0.
    MESSAGE s008(zpr_func) DISPLAY LIKE 'E' WITH lc_structure.
    RETURN.
  ENDIF.

* A kijelölő jelölőnégyzet-oszlop az első helyre kerül.
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'SELECTED'.
  ls_fcat-col_pos   = 1.
  ls_fcat-coltext   = TEXT-011.
  ls_fcat-scrtext_l = TEXT-011.
  ls_fcat-checkbox  = abap_true.
  ls_fcat-edit      = abap_true.
  ls_fcat-outputlen = 6.
  APPEND ls_fcat TO lt_fcat.

  LOOP AT lt_fcat INTO ls_fcat.
    CASE ls_fcat-fieldname.
      WHEN 'PACKAGE_ID'.
        ls_fcat-coltext   = TEXT-012.
        ls_fcat-scrtext_l = TEXT-012.
        MODIFY lt_fcat FROM ls_fcat.

      WHEN 'STATUS'.
        ls_fcat-no_out = abap_true.
        MODIFY lt_fcat FROM ls_fcat.

    ENDCASE.
  ENDLOOP.

  DATA(lv_status_pos) = ls_fcat-col_pos.
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'DOC_COUNT'.
  ls_fcat-col_pos   = 10.
  ls_fcat-datatype  = 'INT4'.
  ls_fcat-inttype   = 'I'.
  ls_fcat-intlen    = 4.
  ls_fcat-outputlen = 11.
  ls_fcat-coltext   = 'Dokumentumok száma'.
  ls_fcat-scrtext_s = 'Dok. szám'.
  ls_fcat-scrtext_m = 'Dokumentumok száma'.
  ls_fcat-scrtext_l = 'Dokumentumok száma'.
  APPEND ls_fcat TO lt_fcat.

  CLEAR ls_fcat.
  ls_fcat-fieldname = 'COUNTER'.
  ls_fcat-col_pos   = 10.
  ls_fcat-datatype  = 'INT4'.
  ls_fcat-inttype   = 'I'.
  ls_fcat-intlen    = 4.
  ls_fcat-outputlen = 11.
  ls_fcat-coltext   = 'Számláló'.
  ls_fcat-scrtext_s = 'Szám.'.
  ls_fcat-scrtext_m = 'Számláló'.
  ls_fcat-scrtext_l = 'Számláló'.
  APPEND ls_fcat TO lt_fcat.

  ls_layo-zebra      = abap_true.
  ls_layo-cwidth_opt = abap_true.

  gr_grid->set_table_for_first_display(
    EXPORTING
      is_layout       = ls_layo
    CHANGING
      it_outtab       = gt_documents
      it_fieldcatalog = lt_fcat ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form SELECT_ALL
*&---------------------------------------------------------------------*
*& Az összes listázott csomagot kijelöli
*&---------------------------------------------------------------------*
FORM select_all.

  gr_grid->check_changed_data( ).
  LOOP AT gt_documents ASSIGNING FIELD-SYMBOL(<ls_data>).
    <ls_data>-selected = abap_true.
  ENDLOOP.
  gr_grid->refresh_table_display( ).

ENDFORM.
*&---------------------------------------------------------------------*
*& Form DESELECT_ALL
*&---------------------------------------------------------------------*
*& Az összes listázott csomag kijelölését törli
*&---------------------------------------------------------------------*
FORM deselect_all.

  gr_grid->check_changed_data( ).
  LOOP AT gt_documents ASSIGNING FIELD-SYMBOL(<ls_data>).
    <ls_data>-selected = abap_false.
  ENDLOOP.
  gr_grid->refresh_table_display( ).

ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_package_doc_counts
*&---------------------------------------------------------------------*
*& Count all DCQM rows belonging to each displayed package
*&---------------------------------------------------------------------*
FORM get_package_doc_counts .
  DATA lr_package TYPE RANGE OF zprt_package-package_id.

  IF gt_documents IS INITIAL.
    RETURN.
  ENDIF.

  lr_package = VALUE #( FOR ls_package IN gt_documents
                        ( sign = 'I' option = 'EQ'
                          low  = ls_package-package_id ) ).

  SELECT package_id, COUNT(*) AS doc_count
    FROM zprt_dcqm
    WHERE package_id IN @lr_package
    GROUP BY package_id
    INTO TABLE @DATA(lt_doc_counts).

  SORT lt_doc_counts BY package_id.
  LOOP AT gt_documents ASSIGNING FIELD-SYMBOL(<ls_package>).
    CLEAR <ls_package>-doc_count.
    READ TABLE lt_doc_counts INTO DATA(ls_doc_count)
      WITH KEY package_id = <ls_package>-package_id BINARY SEARCH.
    IF sy-subrc EQ 0.
      <ls_package>-doc_count = ls_doc_count-doc_count.
    ENDIF.
    <ls_package>-counter = 1.
  ENDLOOP.
ENDFORM.