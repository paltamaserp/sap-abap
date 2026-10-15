*********************************************************************
* Report: ZEBF_PR_DOC_RIP
* Leírás: Nyomdai ellenőrző riport
*
*--------------------------------------------------------------------
* Modulfelelos: <XY>
* Tanácsadó:
* Programozó:   Molnár Gábor
* Dátum, kérelem: 2022.02.08,
* --------------------------------------------------------------------
* Módosítások:
* <dátum>, <programozó>, <kérelem>, <comment azonosító>
*          <rövid leírás>
***********************************************************************
REPORT  zebf_pr_doc_rip.

*----------------------------------------------------------------------*
* Esemény kezelő
*----------------------------------------------------------------------*
* ALV Grid 01 esemény kezelő
* Screen 0100 - Rendelések
CLASS gcl_alv_grid_01_event_receiver DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      on_alv_toolbar
                    FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,
      on_alv_menu_button
                    FOR EVENT menu_button OF cl_gui_alv_grid
        IMPORTING e_object e_ucomm,
      on_alv_user_command
                    FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm,
      on_double_click
                    FOR EVENT double_click OF cl_gui_alv_grid
        IMPORTING es_row_no e_column,
      handle_data_changed
                    FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING e_ucomm
                    er_data_changed.

ENDCLASS.                    "gcl_alv_grid_01_event_receiver DEFINITION

TABLES: zebft_pr_stock.

TYPES: BEGIN OF ty_dest,
        destination TYPE  zebfd_pr_destination,
       END OF ty_dest.

DATA gv_error.
DATA gv_priority TYPE zebfd_pr_priority.
DATA:
* Képernyő OK-kódok
  gv_okcode_0100      TYPE syucomm,
* Képernyő adatmezők
  gv_nyomsor TYPE i,
  gv_kizsor  TYPE i.
DATA:
* 01 - Screen 0100
* Custom container-ek ALV Grid-ekhez
  go_alv_grid_cont_01 TYPE REF TO cl_gui_custom_container,
* ALV Grid control-ok
  go_alv_grid_01      TYPE REF TO cl_gui_alv_grid,
* Esemény kezelők ALV Grid-ekhez
  go_event_rec_alv_01 TYPE REF TO gcl_alv_grid_01_event_receiver.
DATA:
* ALV Grid nyomógombok
  gs_toolbar  TYPE stb_button,
* ALV struktúrák
  gs_0100_alv TYPE zebfs_pr_docrip_alv.
DATA:
  gt_0100_alv TYPE STANDARD TABLE OF zebfs_pr_docrip_alv,
  gt_alv_detail TYPE STANDARD TABLE OF zebfs_pr_docrip_alv_detail,
  gt_destination TYPE STANDARD TABLE OF ty_dest.
* LOG
DATA: gv_log_handle TYPE balloghndl.   "Application Log: Log Handle

* Inspire adatok
DATA: gt_insp_file_details TYPE  zebf_pr_eon_forms_query_pr_tab.

DATA: gt_pr_stock TYPE STANDARD TABLE OF zebft_pr_stock.

DATA: gv_line_header TYPE sdydo_text_element.

*----------------------------------------------------------------------*
* SELECTION-SCREEN - for demonstration purposes only                   *
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.
SELECTION-SCREEN SKIP.
SELECT-OPTIONS: so_stock FOR zebft_pr_stock-stock_id
                         MATCHCODE OBJECT zebfh_pr_stock_closed,
                so_erdat FOR zebft_pr_stock-erdat_clo.
SELECTION-SCREEN SKIP.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE text-002.
PARAMETERS:
  p_vari TYPE slis_vari. "LAYOUT
SELECTION-SCREEN END OF BLOCK b02.
*----------------------------------------------------------------------*
* AT SELECTION-SCREEN                                                  *
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.

*  IF NOT p_stokid IS INITIAL.
*    PERFORM check_stockid.
*  ENDIF.

*----------------------------------------------------------------------*
* START-OF-SELECTION                                                   *
*----------------------------------------------------------------------*
START-OF-SELECTION.

* Select data
  PERFORM select_data.

*----------------------------------------------------------------------*
* END-OF-SELECTION                                                     *
*----------------------------------------------------------------------*
END-OF-SELECTION.

* ALV megjelenítés
  PERFORM display_alv.


*&---------------------------------------------------------------------*
*&      Form  SELECT_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM select_data .

  TYPES: BEGIN OF ty_fname,
          file TYPE zebfd_pr_filename,
         END OF ty_fname.
  TYPES: BEGIN OF ty_envid,
          envelope TYPE zebfd_pr_envelop,
          exbilldocno TYPE zebfd_pr_exbilldocno,
         END OF ty_envid.

  DATA: lv_db    TYPE i,
        lv_hiba  TYPE flag,
        lv_tmpst TYPE char14,
        lv_tmpst_max TYPE char14.
  DATA: ls_files TYPE ty_fname.
  DATA: lt_files TYPE STANDARD TABLE OF ty_fname.
  DATA: lt_envelope     TYPE STANDARD TABLE OF ty_envid,
        lt_envelope_kiz TYPE STANDARD TABLE OF ty_envid,
        ls_pr_stock TYPE zebft_pr_stock.
  DATA: lt_dcqm TYPE TABLE OF zebft_pr_dcqm,
        ls_dcqm TYPE zebft_pr_dcqm.
  DATA: ls_file_details TYPE zebf_pr_eon_forms_query_print1.
  DATA: ls_docrip TYPE zebfs_pr_docrip_alv,
        ls_dest TYPE ty_dest.

  REFRESH gt_0100_alv.

* két nyoomtatás a releváns
  REFRESH gt_destination.
  ls_dest-destination = 'PR'.
  APPEND ls_dest TO gt_destination.
  ls_dest-destination = 'IN'.
  APPEND ls_dest TO gt_destination.

  REFRESH gt_pr_stock.
  SELECT * INTO TABLE gt_pr_stock
    FROM zebft_pr_stock
   WHERE stock_id IN so_stock
     AND erdat    IN so_erdat.

  IF sy-subrc NE 0.
    MESSAGE e051(zebf_pr).
    EXIT.
  ENDIF.

* Get data from Inspire
  PERFORM get_data.


  LOOP AT gt_pr_stock INTO ls_pr_stock.

    LOOP AT gt_destination INTO ls_dest.


      CLEAR ls_docrip.
      MOVE-CORRESPONDING ls_pr_stock TO ls_docrip.

      ls_docrip-sapsysid = sy-sysid.
      ls_docrip-sapmandt = sy-mandt.

      ls_docrip-destination = ls_dest-destination.
      ls_docrip-status = 'NOK'.

      CLEAR lv_hiba.
      REFRESH lt_files.
      SELECT filename INTO TABLE lt_files
        FROM zebft_pr_mssfile
       WHERE stock_id EQ ls_docrip-stock_id.
      IF sy-subrc EQ 0.
        REFRESH lt_envelope.
        SELECT envelope exbilldocno FROM zebft_pr_dcqm
          INTO TABLE lt_envelope
           FOR ALL ENTRIES IN lt_files
         WHERE filename    EQ lt_files-file
           AND destination EQ ls_docrip-destination.

        REFRESH lt_envelope_kiz.
        SELECT envelope exbilldocno FROM zebft_pr_dcqm
          INTO TABLE lt_envelope_kiz
           FOR ALL ENTRIES IN lt_files
         WHERE filename    EQ lt_files-file
           AND destination EQ ls_docrip-destination
           AND ( block_dc NE space OR
                 block_qm NE space ).
      ENDIF.

*   ha nem volt egyik destination irány sem
      IF lt_envelope[]     IS INITIAL AND
         lt_envelope_kiz[] IS INITIAL.
        CONTINUE.
      ENDIF.
*   nyomtatási sorok
      DESCRIBE TABLE lt_envelope LINES lv_db.
      ADD lv_db TO ls_docrip-sap_doc_no.

      DESCRIBE TABLE lt_envelope_kiz LINES lv_db.
      ADD lv_db TO ls_docrip-excl_doc_no.

*   borítékok
      SORT lt_envelope.
      DELETE ADJACENT DUPLICATES FROM lt_envelope COMPARING envelope.
      DESCRIBE TABLE lt_envelope LINES lv_db.
      ADD lv_db TO ls_docrip-sap_env_no.

      SORT lt_envelope_kiz.
      DELETE ADJACENT DUPLICATES FROM lt_envelope_kiz COMPARING envelope.
      DESCRIBE TABLE lt_envelope_kiz LINES lv_db.
      ADD lv_db TO ls_docrip-excl_env_no.

      LOOP AT gt_insp_file_details INTO ls_file_details
        WHERE stock_id    EQ ls_docrip-stock_id
          AND destination EQ ls_dest-destination.

        IF NOT ls_file_details-status_ok IS INITIAL.
          ls_docrip-status = 'OK'.
        ENDIF.
        IF ls_file_details-send_datetime IS NOT INITIAL.
          lv_tmpst = ls_file_details-send_datetime.
        ENDIF.
        IF lv_tmpst GT lv_tmpst_max .
          lv_tmpst_max = lv_tmpst.
        ENDIF.

        ADD ls_file_details-doc_no TO ls_docrip-insp_doc_no.
        ADD ls_file_details-env_no TO ls_docrip-insp_env_no.
        ADD ls_file_details-sheet_no TO ls_docrip-insp_sheet_no.
        ADD ls_file_details-page_no TO  ls_docrip-insp_page_no.
        ADD ls_file_details-mark_no1 TO ls_docrip-insp_mark_no1.
        ADD ls_file_details-mark_no2 TO ls_docrip-insp_mark_no2.
        ADD ls_file_details-mark_no3 TO ls_docrip-insp_mark_no3.
        ADD ls_file_details-mark_no4 TO ls_docrip-insp_mark_no4.

      ENDLOOP.

      ls_docrip-insp_send_date = lv_tmpst_max(8).
      ls_docrip-insp_send_time = lv_tmpst_max+8(6).

      ls_docrip-diff_doc = ls_docrip-sap_doc_no - ls_docrip-excl_doc_no - ls_docrip-insp_doc_no.
      ls_docrip-diff_env = ls_docrip-sap_env_no - ls_docrip-excl_env_no - ls_docrip-insp_env_no.

      APPEND ls_docrip TO gt_0100_alv.

    ENDLOOP. "LOOP AT gt_destination INTO ls_dest.

  ENDLOOP. "LOOP AT lt_pr_stock INTO ls_pr_stock.


ENDFORM.                    " SELECT_DATA
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM display_alv .

  CALL SCREEN '0100'.

ENDFORM.                    " DISPLAY_ALV
*&---------------------------------------------------------------------*
*&      Form  CHECK_STOCKID
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM check_stockid .

*  SELECT SINGLE * INTO gs_stock
*    FROM zebft_pr_stock
*   WHERE stock_id EQ p_stokid.
*
*  IF sy-subrc NE 0.
*    MESSAGE e020(zebf_pr).
*  ENDIF.
*
*  IF gs_stock-closed EQ abap_true.
*    gv_modif = abap_false.
*    MESSAGE i021(zebf_pr).
*  ENDIF.
*  IF gs_stock-dccompl EQ abap_false.
*    gv_modif = abap_false.
*    MESSAGE i031(zebf_pr).
*  ENDIF.
*  IF gs_stock-qmcompl EQ abap_false.
*    gv_modif = abap_false.
*    MESSAGE i037(zebf_pr).
*  ENDIF.

ENDFORM.                    " CHECK_STOCKID



INCLUDE zebf_pr_doc_rip_o01.

INCLUDE zebf_pr_doc_rip_i01.


*----------------------------------------------------------------------*
*       CLASS gcl_alv_grid_01_event_receiver IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS gcl_alv_grid_01_event_receiver IMPLEMENTATION.

  METHOD on_alv_user_command.

    DATA: lv_error  TYPE flag,
          lv_lines  TYPE i,
          lv_ret    TYPE char1,
          lv_hiba   TYPE flag,
          lv_dummy  TYPE string.
    DATA: ls_edit   TYPE lvc_s_styl,
          ls_stable TYPE lvc_s_stbl.
    DATA: lt_rows TYPE lvc_t_row,
          ls_rows LIKE LINE OF lt_rows.
    DATA: ls_sval  TYPE sval.
    DATA: lt_sval  TYPE STANDARD TABLE OF sval.
    DATA: ls_insp_details TYPE zebf_pr_eon_forms_query_print1,
          ls_alv_detail TYPE zebfs_pr_docrip_alv_detail.

    CALL METHOD go_alv_grid_01->get_selected_rows
      IMPORTING
        et_index_rows = lt_rows.

    DESCRIBE TABLE lt_rows LINES lv_lines.


    CASE e_ucomm.
      WHEN 'DETAIL'.

        IF lv_lines EQ 0.
          MESSAGE i023(zebf_pr).
          EXIT.
        ENDIF.

        REFRESH gt_alv_detail.

        LOOP AT lt_rows INTO ls_rows.
          READ TABLE gt_0100_alv INTO gs_0100_alv INDEX ls_rows-index.

          LOOP AT gt_insp_file_details INTO ls_insp_details
            WHERE stock_id    EQ gs_0100_alv-stock_id
              AND destination EQ gs_0100_alv-destination.

            CLEAR ls_alv_detail.
            MOVE-CORRESPONDING gs_0100_alv TO ls_alv_detail.

            ls_alv_detail-sapsysid = ls_insp_details-sap_system.
            ls_alv_detail-sapmandt = ls_insp_details-sap_mandant.
            ls_alv_detail-insp_send_date = ls_insp_details-send_datetime(8).
            ls_alv_detail-insp_send_time = ls_insp_details-send_datetime+8(6).
            ls_alv_detail-insp_out_file = ls_insp_details-out_file.
            ls_alv_detail-insp_doc_no   = ls_insp_details-doc_no.
            ls_alv_detail-insp_env_no   = ls_insp_details-env_no.
            ls_alv_detail-insp_sheet_no = ls_insp_details-sheet_no.
            ls_alv_detail-insp_page_no  = ls_insp_details-page_no.
            ls_alv_detail-insp_mark_no1  = ls_insp_details-mark_no1.
            ls_alv_detail-insp_mark_no2  = ls_insp_details-mark_no2.
            ls_alv_detail-insp_mark_no3  = ls_insp_details-mark_no3.
            ls_alv_detail-insp_mark_no4  = ls_insp_details-mark_no4.

            IF ls_insp_details-status_ok EQ abap_true.
              ls_alv_detail-status = 'OK'.
            ELSE.
              ls_alv_detail-status = 'NOK'.
            ENDIF.

            APPEND ls_alv_detail TO gt_alv_detail.
          ENDLOOP.

        ENDLOOP.

        PERFORM display_details.


      WHEN OTHERS.

    ENDCASE.


  ENDMETHOD.                    "on_user_command

  METHOD on_alv_toolbar.

*   Standard gombok letiltása
*    LOOP AT e_object->mt_toolbar INTO gs_toolbar.
*      IF gs_toolbar-function = cl_gui_alv_grid=>mc_mb_view           OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_detail         OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_append_row OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_copy_row   OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_delete_row OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_insert_row OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_graph          OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_info           OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_refresh        OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_undo       OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_copy       OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_cut        OR
*         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_paste      .
*        DELETE e_object->mt_toolbar.
*      ENDIF.
*    ENDLOOP.

*   Szeparátor
    CLEAR gs_toolbar.
    MOVE 3 TO gs_toolbar-butn_type.
    APPEND gs_toolbar TO e_object->mt_toolbar.

    CLEAR gs_toolbar.
    gs_toolbar-function   = 'DETAIL'.
    gs_toolbar-icon       = icon_select_detail.
    gs_toolbar-quickinfo  = 'Részletes lista'.
    gs_toolbar-text       = ' Részletek'.
    APPEND gs_toolbar TO e_object->mt_toolbar.

  ENDMETHOD.                    "on_toolbar

  METHOD on_alv_menu_button.
*
  ENDMETHOD.                    "on_alv_menu_button

  METHOD on_double_click.

    DATA: ls_insp_details TYPE zebf_pr_eon_forms_query_print1,
          ls_alv_detail TYPE zebfs_pr_docrip_alv_detail.

    CLEAR gs_0100_alv.
    READ TABLE gt_0100_alv INTO gs_0100_alv INDEX es_row_no-row_id.

    REFRESH gt_alv_detail.

    LOOP AT gt_insp_file_details INTO ls_insp_details
      WHERE stock_id    EQ gs_0100_alv-stock_id
        AND destination EQ gs_0100_alv-destination.

      CLEAR ls_alv_detail.
      MOVE-CORRESPONDING gs_0100_alv TO ls_alv_detail.

      ls_alv_detail-sapsysid = ls_insp_details-sap_system.
      ls_alv_detail-sapmandt = ls_insp_details-sap_mandant.
      ls_alv_detail-insp_send_date = ls_insp_details-send_datetime(8).
      ls_alv_detail-insp_send_time = ls_insp_details-send_datetime+8(6).
      ls_alv_detail-insp_out_file = ls_insp_details-out_file.
      ls_alv_detail-insp_doc_no   = ls_insp_details-doc_no.
      ls_alv_detail-insp_env_no   = ls_insp_details-env_no.
      ls_alv_detail-insp_sheet_no = ls_insp_details-sheet_no.
      ls_alv_detail-insp_page_no  = ls_insp_details-page_no.
      ls_alv_detail-insp_mark_no1  = ls_insp_details-mark_no1.
      ls_alv_detail-insp_mark_no2  = ls_insp_details-mark_no2.
      ls_alv_detail-insp_mark_no3  = ls_insp_details-mark_no3.
      ls_alv_detail-insp_mark_no4  = ls_insp_details-mark_no4.

      IF ls_insp_details-status_ok EQ abap_true.
        ls_alv_detail-status = 'OK'.
      ELSE.
        ls_alv_detail-status = 'NOK'.
      ENDIF.

      APPEND ls_alv_detail TO gt_alv_detail.
    ENDLOOP.

    PERFORM display_details.

  ENDMETHOD.                    "on_double_click

  METHOD handle_data_changed.
  ENDMETHOD.                    "handle_data_changed


ENDCLASS.                    "gcl_alv_grid_01_event_receiver IMPLEMENTATION

*&---------------------------------------------------------------------*
*&      Form  ALV_GRID_01_FREE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM alv_grid_01_free .

* Calendar control törlés
  IF NOT go_alv_grid_01 IS INITIAL.
    CALL METHOD go_alv_grid_01->free.
    FREE go_alv_grid_01.
  ENDIF.
* Custom container törlés
  IF NOT go_alv_grid_cont_01 IS INITIAL.
    CALL METHOD go_alv_grid_cont_01->free.
    FREE go_alv_grid_cont_01.
  ENDIF.

ENDFORM.                    " ALV_GRID_01_FREE

*&---------------------------------------------------------------------*
*&      Form  USER_COMMAND_0100
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM user_command_0100 .

  CLEAR gv_okcode_0100.
*  CASE lv_okcode.
*    WHEN 'SAVE'.
*  ENDCASE.

ENDFORM.                    " USER_COMMAND_0100
*&---------------------------------------------------------------------*
*&      Form  EXIT_COMMAND_0100
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM exit_command_0100 .

  DATA: lv_okcode TYPE syucomm,
        lv_valasz TYPE char1.

  lv_okcode = gv_okcode_0100.
  CASE lv_okcode.
    WHEN 'BACK'
      OR 'EXIT'
      OR 'CANCEL'.
      LEAVE TO SCREEN  0.
  ENDCASE.

ENDFORM.                    " EXIT_COMMAND_0100
*&---------------------------------------------------------------------*
*&      Form  CREATE_CONTROLS_0100
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM create_controls_0100 .

  DATA:
    lv_view_style TYPE i,
    lv_sel_style  TYPE i,
    lv_shellstyle TYPE i.
  DATA:
    ls_layout   TYPE lvc_s_layo,
    ls_variant  TYPE disvariant,
    ls_fieldcat TYPE lvc_s_fcat,
    lt_fieldcat TYPE lvc_t_fcat.
  DATA lv_text TYPE sdydo_text_element.
  DATA lv_nyomsor_c(20) TYPE c.
  DATA lv_kizsor_c(20) TYPE c.

*    ls_event      TYPE cntl_simple_event,
*    lt_events     TYPE cntl_simple_events.
*
* Csak ha még nem létezik a konténer és az ALV Grid objektum
  CHECK go_alv_grid_cont_01 IS INITIAL.
  CHECK go_alv_grid_01      IS INITIAL.

* Custom container control létrehozás
  CREATE OBJECT go_alv_grid_cont_01
    EXPORTING
      container_name              = 'ALV_CONTAINER_01'
    EXCEPTIONS
      cntl_error                  = 1
      cntl_system_error           = 2
      create_error                = 3
      lifetime_error              = 4
      lifetime_dynpro_dynpro_link = 5.
  IF NOT sy-subrc IS INITIAL.
    EXIT.
  ENDIF.
*
* ALV Grid control létrehozás
*  lv_shellstyle = ws_visible +
*                  ws_thickframe.
  CREATE OBJECT go_alv_grid_01
    EXPORTING
      i_shellstyle      = lv_view_style
      i_lifetime        = go_alv_grid_01->lifetime_default
      i_parent          = go_alv_grid_cont_01
      i_appl_events     = space
    EXCEPTIONS
      error_cntl_create = 1
      error_cntl_init   = 2
      error_cntl_link   = 3
      error_dp_create   = 4.
  IF NOT sy-subrc IS INITIAL.
    EXIT.
  ENDIF.
*

***HEADER
*  CLEAR lv_text.
*  lv_nyomsor_c = gv_nyomsor.
*  CONDENSE lv_nyomsor_c.
*  CONCATENATE 'Stock ID:' p_stokid INTO lv_text SEPARATED BY space.
*  PERFORM add_line USING lv_text.
*  CLEAR lv_text.
*  lv_nyomsor_c = gv_nyomsor.
*  CONDENSE lv_nyomsor_c.
*  CONCATENATE 'Nyomtatási sorok száma:' lv_nyomsor_c INTO lv_text SEPARATED BY space.
*  PERFORM add_line USING lv_text.
*  CLEAR lv_text.
*  lv_kizsor_c = gv_kizsor.
*  CONDENSE lv_kizsor_c.
*  CONCATENATE 'Kizárt nyomtatási sorok száma: ' lv_kizsor_c INTO lv_text SEPARATED BY space.
*  PERFORM add_line USING lv_text.

* ALV Grid cellák módosíthatósága
  PERFORM cell_style_alv_outtab_0100.

*
* Alv Grid layout beállítás
  CLEAR ls_layout.
  ls_layout-zebra      = 'X'.
  ls_layout-cwidth_opt = 'X'.
  ls_layout-sel_mode   = 'A'.
  ls_layout-smalltitle = 'X'.
  ls_layout-stylefname = 'HANDLE_STYLE'.
*
* Mezőkatalógus generálás
  REFRESH lt_fieldcat.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = 'ZEBFS_PR_DOCRIP_ALV'
    CHANGING
      ct_fieldcat            = lt_fieldcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2.
  IF NOT sy-subrc IS INITIAL.
    REFRESH lt_fieldcat.
  ENDIF.

* Mezőkatalógus módosítás
  PERFORM alv_fieldcat_0100_mod  CHANGING lt_fieldcat.

** set substate of editable cells to deactivated
*  CALL METHOD go_alv_grid_01->set_ready_for_input
*    EXPORTING
*      i_ready_for_input = 1.
*
*  CALL METHOD go_alv_grid_01->register_edit_event
*    EXPORTING
*      i_event_id = cl_gui_alv_grid=>mc_evt_modified
*    EXCEPTIONS
*      error      = 1
*      OTHERS     = 2.

*  DATA: lr_aggregations TYPE REF TO cl_salv_aggregations.
*
*  lr_aggregations = go_alv_grid_01->get_aggregations( ).
*  lr_aggregations->set_numerical_aggregation( abap_true ).

  CLEAR ls_variant.
  ls_variant-handle   = '1'.
  ls_variant-report   = sy-repid.
  ls_variant-username = sy-uname.

* ALV Grid megjelenítés
  CALL METHOD go_alv_grid_01->set_table_for_first_display
    EXPORTING
      is_variant                    = ls_variant
      i_save                        = 'A'
      i_default                     = abap_true
      is_layout                     = ls_layout
    CHANGING
      it_outtab                     = gt_0100_alv
      it_fieldcatalog               = lt_fieldcat
    EXCEPTIONS
      invalid_parameter_combination = 1
      program_error                 = 2
      too_many_lines                = 3.
  IF NOT sy-subrc IS INITIAL.
    EXIT.
  ENDIF.
*
* Esemény kezelő regisztrálás
  SET HANDLER
    gcl_alv_grid_01_event_receiver=>on_alv_user_command
    gcl_alv_grid_01_event_receiver=>handle_data_changed
    gcl_alv_grid_01_event_receiver=>on_alv_menu_button
    gcl_alv_grid_01_event_receiver=>on_alv_toolbar
    gcl_alv_grid_01_event_receiver=>on_double_click FOR go_alv_grid_01.
*
* Toolbar esemény kiváltás, hogy a gombok megjelenjenek a toolbaron
  CALL METHOD go_alv_grid_01->set_toolbar_interactive.


ENDFORM.                    " CREATE_CONTROLS_0100
*&---------------------------------------------------------------------*
*&      Form  ALV_FIELDCAT_0100_MOD
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM alv_fieldcat_0100_mod  CHANGING ct_fieldcat TYPE lvc_t_fcat.

  FIELD-SYMBOLS: <fs> TYPE lvc_s_fcat.

  LOOP AT ct_fieldcat ASSIGNING <fs>.
    CASE <fs>-fieldname.
      WHEN 'SAPMANDT'.
        "<fs>-coltext  = 'Név'.
        <fs>-col_opt  = abap_true.
        <fs>-tech     = abap_false.
      WHEN 'ERDAT'.
        <fs>-coltext  = 'Stock létr. dátuma'.
        <fs>-col_opt  = abap_true.
      WHEN 'ERTIM'.
        <fs>-coltext  = 'Stock létr. ideje'.
        <fs>-col_opt  = abap_true.
      WHEN 'SAP_DOC_NO'.
        <fs>-coltext  = 'Dok. száma '.
        <fs>-col_opt  = abap_true.
      WHEN 'SAP_ENV_NO'.
        <fs>-coltext  = 'Boríték. száma '.
        <fs>-col_opt  = abap_true.
      WHEN 'EXCL_DOC_NO'.
        <fs>-coltext  = 'Kizárt/hibás sorok'.
        <fs>-col_opt  = abap_true.
      WHEN 'EXCL_ENV_NO'.
        <fs>-coltext  = 'Kizárt/hibás boríték'.
        <fs>-col_opt  = abap_true.
      WHEN 'STATUS'.
        <fs>-coltext  = 'Státusz'.
        <fs>-col_opt  = abap_true.
      WHEN 'INSP_SEND_DATE'.
        <fs>-coltext  = 'Küldés dátuma'.
        <fs>-col_opt  = abap_true.
      WHEN 'INSP_SEND_TIME'.
        <fs>-coltext  = 'Küldés ideje'.
        <fs>-col_opt  = abap_true.
      WHEN 'INSP_DOC_NO'.
        <fs>-coltext  = 'Insp.dok.szám'.
        <fs>-col_opt  = abap_true.
      WHEN 'INSP_ENV_NO'.
        <fs>-coltext  = 'Insp.bor szám'.
        <fs>-col_opt  = abap_true.
      WHEN 'INSP_SHEET_NO'.
        <fs>-coltext  = 'Insp.lap szám'.
        <fs>-col_opt  = abap_true.
      WHEN 'INSP_PAGE_NO'.
        <fs>-coltext  = 'Insp.oldal szám'.
        <fs>-col_opt  = abap_true.
      WHEN 'INSP_MARK_NO1'.
        <fs>-coltext  = 'Insp.marketing m.'.
        <fs>-col_opt  = abap_true.
      WHEN 'INSP_MARK_NO2'.
        <fs>-coltext  = 'Insp.marketing m.'.
        <fs>-col_opt  = abap_true.
      WHEN 'INSP_MARK_NO3'.
        <fs>-coltext  = 'Insp.marketing m.'.
        <fs>-col_opt  = abap_true.
      WHEN 'INSP_MARK_NO4'.
        <fs>-coltext  = 'Insp.marketing m.'.
        <fs>-col_opt  = abap_true.
      WHEN 'DIFF_DOC'.
        <fs>-coltext  = 'Dok. eltérés'.
        <fs>-col_opt  = abap_true.
      WHEN 'DIFF_ENV'.
        <fs>-coltext  = 'Bor. eltérés'.
        <fs>-col_opt  = abap_true.
      WHEN OTHERS.
        <fs>-col_opt = abap_true.
    ENDCASE.
  ENDLOOP.


ENDFORM.                    " ALV_FIELDCAT_0100_MOD
*&---------------------------------------------------------------------*
*&      Form  CELL_STYLE_ALV_OUTTAB_0100
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM cell_style_alv_outtab_0100 .

ENDFORM.                    " CELL_STYLE_ALV_OUTTAB_0100

*&---------------------------------------------------------------------*
*&      Form  LOG_CREATE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM log_create .

*  DATA: ls_log        TYPE bal_s_log.    "Log header data
** DEFINE SOME HEADER DATA OF THIS LOG
*  ls_log-extnumber  = p_stokid.
*  ls_log-object     = 'ZEBF_PR'.
*  ls_log-subobject  = 'Z_STOCK'.
*  ls_log-aldate     = sy-datum.
*  ls_log-altime     = sy-uzeit.
*  ls_log-aluser     = sy-uname.
*  ls_log-alprog     = sy-repid.
*  CALL FUNCTION 'BAL_LOG_CREATE'
*    EXPORTING
*      i_s_log                 = ls_log
*    IMPORTING
*      e_log_handle            = gv_log_handle
*    EXCEPTIONS
*      log_header_inconsistent = 1
*      OTHERS                  = 2.
*  IF sy-subrc <> 0.
*    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*  ENDIF.

ENDFORM.                    "log_create
*&---------------------------------------------------------------------*
*&      Form  LOG_ADD_MESSAGE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM log_add_message .

  DATA: ls_msg TYPE bal_s_msg.

*DEFINE DATA OF MESSAGE FOR APPLICATION LOG
  ls_msg-msgty     = sy-msgty.
  ls_msg-msgid     = sy-msgid.
  ls_msg-msgno     = sy-msgno.
  ls_msg-msgv1     = sy-msgv1.
  ls_msg-msgv2     = sy-msgv2.
  ls_msg-msgv3     = sy-msgv3.
  ls_msg-msgv4     = sy-msgv4.
  CALL FUNCTION 'BAL_LOG_MSG_ADD'
    EXPORTING
      i_log_handle     = gv_log_handle
      i_s_msg          = ls_msg
    EXCEPTIONS
      log_not_found    = 1
      msg_inconsistent = 2
      log_is_full      = 3
      OTHERS           = 4.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
         WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.


ENDFORM.                    "log_add_message
*&---------------------------------------------------------------------*
*&      Form  LOG_DISPLAY
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM log_display .

  DATA: lt_log_handle TYPE bal_t_logh.

  APPEND gv_log_handle TO lt_log_handle.

  CALL FUNCTION 'BAL_DB_SAVE'
   EXPORTING
*     I_CLIENT               = SY-MANDT
*     I_IN_UPDATE_TASK       = ' '
*     I_SAVE_ALL             = ' '
     i_t_log_handle         = lt_log_handle
*   IMPORTING
*     E_NEW_LOGNUMBERS       =
   EXCEPTIONS
     log_not_found          = 1
     save_not_allowed       = 2
     numbering_error        = 3
     OTHERS                 = 4
            .
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  CALL FUNCTION 'BAL_DSP_LOG_DISPLAY'
    EXPORTING
      i_t_log_handle       = lt_log_handle
    EXCEPTIONS
      profile_inconsistent = 1
      internal_error       = 2
      no_data_available    = 3
      no_authority         = 4
      OTHERS               = 5.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
       WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.


ENDFORM.                    "log_display
*&---------------------------------------------------------------------*
*&      Form  SEND_PRIORITY
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM get_data .

  DATA: lv_dummy  TYPE string.
  DATA: ls_input  TYPE zebf_pr_eon_forms_query_print3,
        ls_output TYPE zebf_pr_eon_forms_query_print2.
  DATA: ls_stock TYPE string,
        ls_pr_stock TYPE zebft_pr_stock.
  DATA: lo_query TYPE REF TO zebf_pr_co_eon_forms_query_pri.
  DATA: lv_ex_txt TYPE string.
  DATA: lr_sys_fail TYPE REF TO cx_ai_system_fault,
        lr_app_fail TYPE REF TO cx_ai_application_fault.


  ls_input-sap_mandant = sy-mandt.
  ls_input-sap_system  = sy-sysid.

  LOOP AT gt_pr_stock INTO ls_pr_stock.
    ls_stock = ls_pr_stock-stock_id.
    APPEND ls_stock TO ls_input-stocks-stock_id.
  ENDLOOP.


  TRY.

      CREATE OBJECT lo_query.

    CATCH cx_ai_system_fault INTO lr_sys_fail.
      lv_ex_txt = lr_sys_fail->get_text( ).
*      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*                              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_dummy.
      EXIT.

  ENDTRY.


  TRY.

      CALL METHOD lo_query->eon_forms_query_printhouse_out
        EXPORTING
          input  = ls_input
        IMPORTING
          output = ls_output.

      IF ls_output-success = abap_true.

      ELSE.
**Webservice hiba:
        MESSAGE ID 'ZEBF_PR_TRIGGER' TYPE 'E' NUMBER '000'
                WITH ls_output-error_code ':' ls_output-info.
        EXIT.
      ENDIF.

    CATCH cx_ai_system_fault  INTO lr_sys_fail.
      lv_ex_txt = lr_sys_fail->get_text( ).

    CATCH cx_ai_application_fault INTO lr_app_fail.
      lv_ex_txt = lr_app_fail->get_text( ).

  ENDTRY.

  gt_insp_file_details[] = ls_output-out_file_details[].

  IF lv_ex_txt IS NOT INITIAL.
    MESSAGE ID 'ZEBF_PR' TYPE 'E' NUMBER '052'
       WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.


ENDFORM.                    " SEND_PRIORITY
*&---------------------------------------------------------------------*
*&      Form  ADD_LINE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_1012   text
*      -->P_SY_DATUM  text
*----------------------------------------------------------------------*
FORM add_line USING p_line_header TYPE sdydo_text_element.

*  CALL METHOD gr_document->add_text
*    EXPORTING
*      text         = p_line_header
*      sap_fontsize = cl_dd_document=>large
*      sap_emphasis = cl_dd_document=>strong.
*
*  CALL METHOD gr_document->new_line.

ENDFORM.                    " ADD_LINE
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_DETAILS
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM display_details .

  DATA: lr_table   TYPE REF TO cl_salv_table.
  DATA: lr_functions TYPE REF TO cl_salv_functions_list.
  DATA: lr_columns TYPE REF TO cl_salv_columns.
  DATA: lr_aggregations TYPE REF TO cl_salv_aggregations.
  DATA: lr_layout TYPE REF TO cl_salv_layout.
  DATA: ls_key TYPE salv_s_layout_key.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lr_table
        CHANGING
          t_table      = gt_alv_detail ).
    CATCH cx_salv_msg.                                  "#EC NO_HANDLER
  ENDTRY.

  lr_functions = lr_table->get_functions( ).
  lr_functions->set_all( abap_true ).

  lr_aggregations = lr_table->get_aggregations( ).
  lr_aggregations->set_numerical_aggregation( abap_true ).

  lr_layout = lr_table->get_layout( ).
  ls_key-report = sy-repid.
  ls_key-handle = '2'.
  lr_layout->set_key( ls_key ).
  lr_layout->set_save_restriction( if_salv_c_layout=>restrict_none ).

  lr_columns = lr_table->get_columns( ).
  lr_columns->set_optimize( abap_true ).

  PERFORM set_columns_technical USING lr_columns.

  lr_table->display( ).

ENDFORM.                    " DISPLAY_DETAILS
*&---------------------------------------------------------------------*
*&      Form  SET_COLUMNS_TECHNICAL
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LR_COLUMNS  text
*----------------------------------------------------------------------*
FORM set_columns_technical  USING ir_columns TYPE REF TO cl_salv_columns.

  DATA: "lr_column TYPE REF TO cl_salv_column,
    lr_column           TYPE REF TO cl_salv_column_table,
    lt_column_table     TYPE salv_t_column_ref,
    lv_text_s           TYPE scrtext_s,
    lv_text_m           TYPE scrtext_m,
    lv_text_l           TYPE scrtext_l,
    lv_text             TYPE char100.
  FIELD-SYMBOLS:
    <column_table>      TYPE salv_s_column_ref.


  lt_column_table[] = ir_columns->get( ).
  LOOP AT lt_column_table ASSIGNING <column_table>.
    lr_column ?= ir_columns->get_column( <column_table>-columnname ).

    CASE <column_table>-columnname.
      WHEN 'ERDAT'.
        lv_text = 'Stock létr.dátuma'.
      WHEN 'ERTIM'.
        lv_text = 'Stock létr.ideje'.
      WHEN 'SAP_DOC_NO'.
        lv_text = 'Dok.száma'.
      WHEN 'SAP_ENV_NO'.
        lv_text = 'Boríték.száma'.
      WHEN 'INSP_SEND_DATE'.
        lv_text = 'Küldés dátuma'.
      WHEN 'INSP_SEND_TIME'.
        lv_text = 'Küldés ideje'.
      WHEN 'EXCL_DOC_NO'.
        lv_text = 'Kizárt/hibás sorok'.
      WHEN 'EXCL_ENV_NO'.
        lv_text = 'Kizárt/hibás boríték'.
      WHEN 'INSP_OUT_FILE'.
        lv_text = 'Nyomdai állomány'.
      WHEN 'INSP_DOC_NO'.
        lv_text = 'Insp.dok.szám'.
      WHEN 'INSP_ENV_NO'.
        lv_text = 'Insp.bor szám'.
      WHEN 'INSP_SHEET_NO'.
        lv_text = 'Insp.lap szám'.
      WHEN 'INSP_PAGE_NO'.
        lv_text = 'Insp.oldal szám'.
      WHEN 'INSP_MARK_NO1'.
        lv_text = 'Marketing.m.1'.
      WHEN 'INSP_MARK_NO2'.
        lv_text = 'Marketing.m.1'.
      WHEN 'INSP_MARK_NO3'.
        lv_text = 'Marketing.m.1'.
      WHEN 'INSP_MARK_NO4'.
        lv_text = 'Marketing.m.1'.
      WHEN 'STATUS'.
        lv_text = 'Státusz'.
      WHEN OTHERS.
        CONTINUE.
    ENDCASE.

    lv_text_s = lv_text.   lr_column->set_short_text( lv_text_s ).
    lv_text_m = lv_text.   lr_column->set_medium_text( lv_text_m ).
    lv_text_l = lv_text.   lr_column->set_long_text( lv_text_l ).

  ENDLOOP.


ENDFORM.                    " SET_COLUMNS_TECHNICAL