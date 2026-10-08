REPORT zpr_dcqm_exclude MESSAGE-ID zpr.

*&---------------------------------------------------------------------*
*& Report ZPR_MASS_PRINTING
*---------------------------------------------------------------*
* Rövid leírás: Tömeges nyomtatás
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*---------------------------------------------------------------*
* Deklaráció
TABLES: zprt_dcqm.
TYPES: BEGIN OF ts_dcqm,
         selected TYPE abap_bool.
         INCLUDE STRUCTURE  zprt_dcqm.
TYPES: END OF ts_dcqm,
tt_dcqm TYPE TABLE OF ts_dcqm.


DATA gv_stock_size TYPE sytabix.
DATA gt_dcqm TYPE tt_dcqm.

*--- log
DATA go_log TYPE REF TO zcl_pr_log.
DATA gv_obj  TYPE balobj_d VALUE 'ZPR_MASS'.
DATA gv_subobj  TYPE balsubobj VALUE 'STOCK'.

*--- alv
DATA: gr_grid TYPE REF TO cl_gui_alv_grid.
DATA: gr_container TYPE REF TO cl_gui_custom_container.
DATA: gv_okcode TYPE syucomm.


*---------------------------------------------------------------*
* Szelekciós feltételek
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: so_docno  FOR zprt_dcqm-doc_no,
                  so_env    FOR zprt_dcqm-envelope.
*   PARAMETERS p_mass LIKE zprt_doc_log-printer DEFAULT 'MASS' MODIF ID dis.
SELECTION-SCREEN END OF BLOCK b1.

*AT SELECTION-SCREEN OUTPUT.
*  LOOP AT SCREEN.
*    IF screen-group1 = 'DIS'.
*      screen-input = 0.
*      MODIFY SCREEN.
*    ENDIF.
*  ENDLOOP.
*---------------------------------------------------------------*
START-OF-SELECTION.

*---------------------------------------------------------------*
** Napló megnyitása
*  go_log = NEW zcl_pr_log(
*    iv_log_object    = gv_obj
*    iv_log_subobject = gv_subobj ).


* ---- zprt_dcqm szelektálni és egy ALV-be kitenni. nyom

*---------------------------------------------------------------*

*  PERFORM get_stock_size CHANGING gv_stock_size.

  SELECT *
    FROM zprt_dcqm
    INTO CORRESPONDING FIELDS OF TABLE @gt_dcqm
*      PACKAGE SIZE @gv_stock_size
    WHERE  doc_no     IN @so_docno
     AND   envelope   IN @so_env.


START-OF-SELECTION.

  PERFORM display_fullscreen  .

*  go_log->close(  ).
*  IF sy-batch IS INITIAL.
*    go_log->display(  ).
*  ENDIF.

**---------------------------------------------------------------*
**& Form process_package
**---------------------------------------------------------------*
**& XML-ek szelekciója és kiküldése
**---------------------------------------------------------------*
**& -->  p1        text
**& <--  p2        text
**---------------------------------------------------------------*
*FORM process_package USING ut_dcqm TYPE tt_pck.
**---------------------------------------------------------------*
** Deklaráció
*  DATA lv_lines TYPE sytabix.
*  DATA lt_data TYPE TABLE OF zprt_doc_data.
*  DATA ls_data TYPE zprt_doc_data.
*  DATA lv_stock_id TYPE zprd_stock_id.
*  DATA lv_base64  TYPE string.
*  DATA lv_gzip TYPE xstring.
*  DATA lv_logical_port_name TYPE prx_logical_port_name.
*  DATA lv_xml TYPE string.
*  DATA lv_xmlx TYPE xstring.
*  DATA ls_input    TYPE zpr_eon_forms_uploader_reques2.
*  DATA ls_output  TYPE zpr_eon_forms_uploader_respons.
*  DATA ls_xmlfile LIKE LINE OF ls_input-eon_forms-xmlfile.
*  DATA lo_pr TYPE REF TO zpr_co_eon_forms_uploader_port.
*  DATA ls_stock TYPE zprt_stock.
*
*  gr_grid->check_changed_data( ).
**---------------------------------------------------------------*
** Feldolgozandó rekordok száma
*  DESCRIBE TABLE ut_dcqm LINES lv_lines.
**  IF lv_lines IS INITIAL.
**    EXIT.
**  ENDIF.
*
**---------------------------------------------------------------*
** Stock azonosító kinyerése
*  PERFORM get_stock_id CHANGING lv_stock_id.
*
** ---------------------------------------------------------------*
** Logikai port előállítása
*  lv_logical_port_name = zcl_pr_output_management=>get_logical_port_name(  ).
*
** ---------------------------------------------------------------*
** Proxy objektum létrehozása
*  TRY.
*      CREATE OBJECT lo_pr
*        EXPORTING
**         destination       = lo_destination
*          logical_port_name = lv_logical_port_name.
*    CATCH cx_ai_system_fault INTO DATA(lx_system_fault). " Application Integration: Technical Error
*      MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO gv_dummy_message.
*      go_log->add_system_message(  ).
*  ENDTRY.
*
**---------------------------------------------------------------*
** XML adatok összegyűjtése rekordszám függvényében eltérő módon
*  REFRESH lt_data.
**  IF lv_lines LE 50000.
*    SELECT *
*      FROM zprt_doc_data
*      INTO CORRESPONDING FIELDS OF TABLE lt_data
*      FOR ALL ENTRIES IN ut_dcqm
*      WHERE doc_no EQ ut_dcqm-doc_no.
*    ELSE.


*  LOOP AT ut_dcqm INTO DATA(ls_document).
*    SELECT SINGLE *
*    FROM zprt_doc_data
*    INTO CORRESPONDING FIELDS OF ls_data
*    WHERE doc_no EQ ls_document-doc_no.
*    IF sy-subrc = 0.
*      APPEND ls_data TO lt_data.
*    ENDIF.
*  ENDLOOP.

*---------------------------------------------------------------*
* XML adatok feldolgozása
*  CLEAR ls_input.
*  DATA lv_tabix TYPE char1.
*  LOOP AT lt_data INTO ls_data.
*    CLEAR ls_xmlfile.
*
**    lv_base64 = zcl_pr_file_converter=>encode_xtring_to_base64( lv_xmlx ).
*** Fájlnév
*    MOVE sy-tabix TO lv_tabix.
*    CONCATENATE 'Teszt_A_B_C' lv_tabix lv_stock_id INTO ls_xmlfile-file_name SEPARATED BY '_'.
*    CONCATENATE ls_xmlfile-file_name 'xml' INTO ls_xmlfile-file_name SEPARATED BY '.'.
*
*** Fájl konverzió
*    lv_xmlx   = zcl_pr_file_converter=>convert_string_to_xstring( ls_data-data ).
*    lv_gzip = zcl_pr_file_converter=>gzip_xstring( EXPORTING iv_xfile    = lv_xmlx
*                                                             iv_filename = ls_xmlfile-file_name ).
*    lv_base64 = zcl_pr_file_converter=>encode_xtring_to_base64( lv_gzip ).
*
*** Hívás felparaméterezése
*    ls_xmlfile-base64 = 'X'.
*    ls_xmlfile-zipped = 'X'.
*    MOVE: lv_base64    TO ls_xmlfile-file_contents.
*    APPEND ls_xmlfile TO ls_input-eon_forms-xmlfile.
*    IF sy-tabix = 2.
*      EXIT.
*    ENDIF.
*  ENDLOOP.
*
**---------------------------------------------------------------*
**  IF 1 = 2.
**    CLEAR ls_xmlfile.
**    ls_xmlfile-base64 = 'X'.
**    ls_xmlfile-zipped = 'X'.
**    lv_xmlx   = zcl_pr_file_converter=>convert_string_to_xstring( ls_data-data ).
**    lv_base64 = zcl_pr_file_converter=>encode_xtring_to_base64( lv_xmlx ).
***    lv_gzip = zcl_pr_file_converter=>gzip_xstring( lv_xmlx ).
***    lv_base64 = zcl_pr_file_converter=>encode_xtring_to_base64( lv_gzip ).
**    MOVE: lv_base64    TO ls_xmlfile-file_contents,
**    lv_stock_id  TO ls_xmlfile-file_name,
**    'X'          TO ls_xmlfile-zipped,
**    'X'          TO ls_xmlfile-base64.
**    CONCATENATE 'Teszt_A_B_C' ls_xmlfile-file_name INTO ls_xmlfile-file_name SEPARATED BY '_'.
**    APPEND ls_xmlfile TO ls_input-eon_forms-xmlfile.
**  ENDIF.
*
**---------------------------------------------------------------*
** Inspire hívás
*  TRY.
*      lo_pr->eon_forms_uploader(
*        EXPORTING
*          input  = ls_input
*        IMPORTING
*          output = ls_output ).
*
*    CATCH cx_ai_system_fault INTO lx_system_fault.
*      MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO gv_dummy_message.
*      go_log->add_system_message(  ).
*    CATCH cx_ai_application_fault INTO DATA(lx_application_fault).
*      MESSAGE e000 WITH lx_application_fault->get_text(  ) INTO gv_dummy_message.
*      go_log->add_system_message(  ).
*  ENDTRY.
*
**---------------------------------------------------------------*
** Egyéb hiba kezelése
*  IF ls_output-parameters-success NE abap_true.
*    MESSAGE e030 INTO gv_dummy_message WITH lv_stock_id.
*    go_log->add_system_message(  ).
*  ENDIF.
*
**---------------------------------------------------------------*
** Sikeres hívás esetén AB írás
*  IF ls_output-parameters-success EQ abap_true.
*    MESSAGE s031 INTO gv_dummy_message WITH lv_stock_id.
*    go_log->add_system_message(  ).
*    CLEAR ls_stock.
*    ls_stock-stock_id = lv_stock_id.
*    MOVE-CORRESPONDING zcl_pr_admin=>get_create_data(   ) TO ls_stock.
*    INSERT INTO zprt_stock VALUES ls_stock.
*    IF sy-subrc <> 0.
*      MESSAGE e029 INTO gv_dummy_message WITH lv_stock_id.
*      go_log->add_system_message(  ).
*    ENDIF.
**    LOOP AT ut_dcqm INTO ls_document.
**      UPDATE zprt_doc_log
**    SET
***    stock_id = lv_stock_id
**         crdate   = ls_stock-crdate
**         crtime   = ls_stock-crtime
**         cruser   = ls_stock-cruser
**    WHERE doc_no = ls_document-doc_no.
**      DATA lv_text(30).
**      SELECT SINGLE text30
**            INTO lv_text
**            FROM zprc_doc_typet
**            WHERE spras = sy-langu
**            AND doc_type = ls_document-doc_type.
**     MESSAGE s032 INTO gv_dummy_message WITH lv_text ls_document-opbel ls_document-doc_no lv_stock_id.
**      go_log->add_system_message(  ).
**    ENDLOOP.
*
*  ENDIF.
*
*ENDFORM.
*

*&---------------------------------------------------------------------*
*& Form display_fullscreen
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
FORM display_fullscreen .
  CALL SCREEN 0100.
ENDFORM.
*&---------------------------------------------------------------------*
*& Module D0100_PBO OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE d0100_pbo OUTPUT.
  PERFORM d0100_pbo.
ENDMODULE.                 " d0100_pbo  OUTPUT

*&---------------------------------------------------------------------*
*&      Module  d0100_pai  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE d0100_pai INPUT.
  PERFORM d0100_pai.
ENDMODULE.                 " d0100_pai  INPUT

*&---------------------------------------------------------------------*
*&      Form  d0100_pbo
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM d0100_pbo .

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
*       text
*----------------------------------------------------------------------*
FORM d0100_pai .

  CASE gv_okcode.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'EXCLUDE'.
      PERFORM exclude_doc USING gt_dcqm.
    WHEN 'SELECT_ALL'.
      PERFORM select_all.
    WHEN 'DESELECT_ALL'.
      PERFORM deselect_all.
    WHEN OTHERS.
      " do nothing !!!
  ENDCASE.


ENDFORM.                                                    " d0100_pai
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
FORM display_alv .

  DATA: lt_fcat TYPE lvc_t_fcat,
        ls_fcat TYPE lvc_s_fcat,
        ls_layo TYPE lvc_s_layo.
  DATA: lt_fieldcat TYPE  slis_t_fieldcat_alv,
        ls_fieldcat TYPE  slis_fieldcat_alv.


  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = 'ZPRT_PACKAGE'
    CHANGING
      ct_fieldcat            = lt_fcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.

* Field catalog
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'SELECTED'.
  ls_fcat-col_pos   = 1.
  ls_fcat-coltext   = 'Select'.
  ls_fcat-scrtext_l = 'Select'.
  ls_fcat-checkbox  = abap_true.
  ls_fcat-edit      = abap_true.
  ls_fcat-outputlen = 6.
  APPEND ls_fcat TO lt_fcat.

  LOOP AT lt_fcat INTO ls_fcat.
    CASE ls_fcat-fieldname.
      WHEN 'PACKAGE_ID'.
        ls_fcat-coltext   = 'Package'.
        ls_fcat-scrtext_l = 'Package'.
        MODIFY lt_fcat FROM ls_fcat.
    ENDCASE.
  ENDLOOP.

  ls_layo-zebra      = abap_true.
  ls_layo-cwidth_opt = abap_true.

  gr_grid->set_table_for_first_display(
    EXPORTING
      is_layout       = ls_layo
    CHANGING
      it_outtab       = gt_dcqm
      it_fieldcatalog = lt_fcat ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form SELECT_ALL
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
FORM select_all .

  gr_grid->check_changed_data( ).
  LOOP AT gt_dcqm ASSIGNING FIELD-SYMBOL(<ls_data>).
    <ls_data>-selected = abap_true.
  ENDLOOP.
  gr_grid->refresh_table_display( ).

ENDFORM.
*&---------------------------------------------------------------------*
*& Form DESELECT_ALL
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
FORM deselect_all .

  gr_grid->check_changed_data( ).
  LOOP AT gt_dcqm ASSIGNING FIELD-SYMBOL(<ls_data>).
    <ls_data>-selected = abap_false.
  ENDLOOP.
  gr_grid->refresh_table_display( ).

ENDFORM.
*&---------------------------------------------------------------------*
*& Form exclude_doc
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
FORM exclude_doc  USING it_dcqm TYPE tt_dcqm.

  DATA: lt_dcqm_upd TYPE TABLE OF zprt_dcqm.
  FIELD-SYMBOLS: <ls_dcqm> TYPE   zprt_dcqm.

  gr_grid->check_changed_data( ).
  LOOP AT gt_dcqm ASSIGNING FIELD-SYMBOL(<ls_data>)
    WHERE selected = abap_true.

    APPEND INITIAL LINE TO lt_dcqm_upd ASSIGNING  <ls_dcqm> .
    MOVE-CORRESPONDING <ls_data>  TO <ls_dcqm>.
    <ls_dcqm>-block_dc  = '01'. "??????
  ENDLOOP.

* modify values into database (ZPRT_DCQM)
  UPDATE zprt_dcqm  FROM TABLE lt_dcqm_upd.

ENDFORM.