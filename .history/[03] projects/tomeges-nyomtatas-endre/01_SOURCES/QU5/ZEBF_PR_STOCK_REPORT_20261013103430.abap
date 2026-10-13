*********************************************************************
* Report: ZEBF_PR_STOCK_REPORT
* Leírás: STOCK Engedélyezés / Lezárás
*
*--------------------------------------------------------------------
* Modulfelelos: <XY>
* Tanácsadó:    Kovács Gábor
* Programozó:   Molnár Gábor
* Dátum, kérelem: 2021.07.23,
* --------------------------------------------------------------------
* Módosítások:
* <dátum>, <programozó>, <kérelem>, <comment azonosító>
*          <rövid leírás>
***********************************************************************
REPORT  zebf_pr_stock_report.

TABLES: zebft_pr_dcqm.


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

DATA gv_error.
DATA gv_priority TYPE zebfd_pr_priority VALUE zif_ebf_pr_const=>gc_priority-_30.
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
  gs_0100_alv TYPE zebfs_pr_dcqm_report.
DATA:
  gt_0100_alv    TYPE STANDARD TABLE OF zebfs_pr_dcqm_report.
* LOG
DATA: gv_log_handle TYPE balloghndl.   "Application Log: Log Handle

DATA: gv_modif   TYPE flag VALUE 'X',
      gv_changed TYPE flag.
DATA: gs_stock TYPE zebft_pr_stock.

DATA: gr_docking_container TYPE REF TO cl_gui_docking_container.
DATA: gr_document TYPE REF TO cl_dd_document.
DATA: gv_line_header TYPE sdydo_text_element.

*----------------------------------------------------------------------*
* SELECTION-SCREEN - for demonstration purposes only                   *
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.
SELECTION-SCREEN SKIP.
PARAMETERS: p_stokid TYPE zebfd_pr_stock_id OBLIGATORY MEMORY ID zebfh_pr_stock.
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

  IF NOT p_stokid IS INITIAL.
    PERFORM check_stockid.
  ENDIF.

*----------------------------------------------------------------------*
* START-OF-SELECTION                                                   *
*----------------------------------------------------------------------*
START-OF-SELECTION.

* Stock ID zár ellenőrzése
  PERFORM check_lock.

* Select data
  PERFORM select_data.

*----------------------------------------------------------------------*
* END-OF-SELECTION                                                     *
*----------------------------------------------------------------------*
END-OF-SELECTION.

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

  DATA: ls_files TYPE ty_fname.
  DATA: lt_files TYPE STANDARD TABLE OF ty_fname.
  DATA lt_dcqmlt TYPE TABLE OF zebft_pr_dcqmlt.
  DATA ls_dcqmlt TYPE zebft_pr_dcqmlt.
  FIELD-SYMBOLS: <fs> TYPE zebfs_pr_dcqm_report.

  SELECT filename INTO TABLE lt_files
    FROM zebft_pr_mssfile
   WHERE stock_id EQ p_stokid.

  IF sy-subrc NE 0.
    MESSAGE e051(zebf_pr).
    EXIT.
  ENDIF.

  CLEAR: gv_nyomsor, gv_kizsor.

  zkg_break x0153.

  IF lt_files[] IS NOT INITIAL.

    SELECT * FROM zebft_pr_dcqm
      INTO CORRESPONDING FIELDS OF TABLE gt_0100_alv
       FOR ALL ENTRIES IN lt_files
     WHERE filename EQ lt_files-file
       AND ( block_dc NE space OR
             block_qm NE space ).

    SELECT COUNT(*) FROM zebft_pr_dcqm
      INTO gv_nyomsor
       FOR ALL ENTRIES IN lt_files
     WHERE filename EQ lt_files-file.

  ENDIF.

  DESCRIBE TABLE gt_0100_alv LINES gv_kizsor.

  IF gt_0100_alv[] IS NOT INITIAL.
    SELECT * FROM zebft_pr_dcqmlt
      INTO TABLE lt_dcqmlt
      FOR ALL ENTRIES IN gt_0100_alv
      WHERE exbilldocno EQ gt_0100_alv-exbilldocno.
  ENDIF.
  SORT lt_dcqmlt BY exbilldocno.

  LOOP AT gt_0100_alv ASSIGNING <fs>.
    READ TABLE lt_dcqmlt INTO ls_dcqmlt
      WITH KEY exbilldocno = <fs>-exbilldocno
      BINARY SEARCH.
    IF sy-subrc EQ 0.
      <fs>-block_dc_text = ls_dcqmlt-block_dc_text.
      <fs>-block_qm_text = ls_dcqmlt-block_qm_text.
    ENDIF.
  ENDLOOP.


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

  SELECT SINGLE * INTO gs_stock
    FROM zebft_pr_stock
   WHERE stock_id EQ p_stokid.

  IF sy-subrc NE 0.
    MESSAGE e020(zebf_pr).
  ENDIF.

  IF gs_stock-closed EQ abap_true.
    gv_modif = abap_false.
    MESSAGE i021(zebf_pr).
  ENDIF.
  IF gs_stock-dccompl EQ abap_false.
    gv_modif = abap_false.
    MESSAGE i031(zebf_pr).
  ENDIF.
  IF gs_stock-qmcompl EQ abap_false.
    gv_modif = abap_false.
    MESSAGE i037(zebf_pr).
  ENDIF.

ENDFORM.                    " CHECK_STOCKID
*&---------------------------------------------------------------------*
*&      Form  CHECK_LOCK
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM check_lock .

  CHECK gv_modif EQ abap_true.

  CALL FUNCTION 'ENQUEUE_EZEBFT_PR_STOCK'
    EXPORTING
*      MODE_ZEBFT_PR_STOCK       = 'E'
*      MANDT                     = SY-MANDT
      stock_id                  = p_stokid
*      X_STOCK_ID                = ' '
*      _SCOPE                    = '2'
*      _WAIT                     = ' '
*      _COLLECT                  = ' '
    EXCEPTIONS
      foreign_lock              = 1
      system_failure            = 2
      OTHERS                    = 3
            .
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.


ENDFORM.                    " CHECK_LOCK


INCLUDE zebf_pr_stock_report_o01.

INCLUDE zebf_pr_stock_report_i01.


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


    CASE e_ucomm.
      WHEN 'RELEASE'.

        REFRESH lt_sval.
        ls_sval-tabname   = 'ZEBFT_PR_STOCK'.
        ls_sval-fieldname = 'PRIORITY'.
        ls_sval-value     = gs_stock-priority.
        APPEND ls_sval TO lt_sval.

        CALL FUNCTION 'POPUP_GET_VALUES'
          EXPORTING
            popup_title     = 'Engedélyezés, kérem adja meg a prioritást:'
            start_column    = '12'
            start_row       = '8'
          IMPORTING
            returncode      = lv_ret
          TABLES
            fields          = lt_sval
          EXCEPTIONS
            error_in_fields = 1
            OTHERS          = 2.
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                  WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
          EXIT.
        ELSE.
          IF lv_ret EQ 'A'. "Abort
            EXIT.
          ENDIF.
          LOOP AT lt_sval INTO ls_sval.
            CASE ls_sval-fieldname.
              WHEN 'PRIORITY'.
                IF ls_sval-value IS INITIAL .
                  MESSAGE i040(zebf_pr).
                  lv_hiba = abap_true.
                  EXIT.
                ENDIF.
                gv_priority = ls_sval-value.
            ENDCASE.
          ENDLOOP.
          IF lv_hiba EQ abap_true.
            EXIT.
          ENDIF.
        ENDIF.

        PERFORM log_create.

        PERFORM send_priority. "Call Webservice

        IF gv_error EQ space.

*         Kizártak - ragszám törlése
          PERFORM del_terti.

          UPDATE zebft_pr_stock
             SET closed    = abap_true
                 priority  = gv_priority
                 erdat_clo = sy-datum
                 ernam_clo = sy-uname
                 ertim_clo = sy-uzeit
           WHERE stock_id EQ p_stokid.

          IF sy-subrc EQ 0.
            COMMIT WORK.

            MESSAGE s041(zebf_pr) WITH p_stokid INTO lv_dummy.
            PERFORM log_add_message.

            MESSAGE s042(zebf_pr) WITH gv_priority INTO lv_dummy.
            PERFORM log_add_message.

            IF gs_stock-notest EQ abap_true.
              MESSAGE s053(zebf_pr) INTO lv_dummy.
              PERFORM log_add_message.
            ENDIF.

            MESSAGE s029(zebf_pr) WITH gv_nyomsor INTO lv_dummy.
            PERFORM log_add_message.

            MESSAGE s030(zebf_pr) WITH gv_kizsor INTO lv_dummy.
            PERFORM log_add_message.

            lv_lines = gv_nyomsor - gv_kizsor.
            MESSAGE s062(zebf_pr) WITH lv_lines INTO lv_dummy.
            PERFORM log_add_message.

          ELSE.

            ROLLBACK WORK.
            MESSAGE s025(zebf_pr) INTO lv_dummy.

          ENDIF.

        ENDIF.


        PERFORM log_display.

        PERFORM alv_grid_01_free.
        SET SCREEN 0.
        LEAVE SCREEN.

      WHEN OTHERS.

    ENDCASE.


  ENDMETHOD.                    "on_user_command

  METHOD on_alv_toolbar.

*   Standard gombok letiltása
    LOOP AT e_object->mt_toolbar INTO gs_toolbar.
      IF gs_toolbar-function = cl_gui_alv_grid=>mc_mb_view           OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_detail         OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_append_row OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_copy_row   OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_delete_row OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_insert_row OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_graph          OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_info           OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_refresh        OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_undo       OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_copy       OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_cut        OR
         gs_toolbar-function = cl_gui_alv_grid=>mc_fc_loc_paste      .
        DELETE e_object->mt_toolbar.
      ENDIF.
    ENDLOOP.

*   Szeparátor
    CLEAR gs_toolbar.
    MOVE 3 TO gs_toolbar-butn_type.
    APPEND gs_toolbar TO e_object->mt_toolbar.

    IF gv_modif EQ abap_true.
      CLEAR gs_toolbar.
      gs_toolbar-function   = 'RELEASE'.
      gs_toolbar-icon       = icon_release.
      gs_toolbar-quickinfo  = 'STOCK engedélyezése'.
      gs_toolbar-text       = ' Engedélyezés'.
      APPEND gs_toolbar TO e_object->mt_toolbar.
    ENDIF.

  ENDMETHOD.                    "on_toolbar

  METHOD on_alv_menu_button.
*
  ENDMETHOD.                    "on_alv_menu_button

  METHOD on_double_click.

    IF e_column-fieldname EQ ''.

*      CLEAR gs_0100_alv.
*      READ TABLE gt_0100_alv INTO gs_0100_alv INDEX es_row_no-row_id.
*
*      SET PARAMETER ID 'AUN' FIELD gs_0100_alv-vbeln.
*      CALL TRANSACTION 'VA02' AND SKIP FIRST SCREEN.

    ENDIF.

    IF e_column-fieldname EQ ''.

*      CLEAR gs_0100_alv.
*      READ TABLE gt_0100_alv INTO gs_0100_alv INDEX es_row_no-row_id.
*
*
*      MODIFY gt_0100_alv FROM gs_0100_alv INDEX es_row_no-row_id.
*
*      CALL METHOD go_alv_grid_01->refresh_table_display
*        EXCEPTIONS
*          finished = 1
*          OTHERS   = 2.

    ENDIF.

  ENDMETHOD.                    "on_double_click

  METHOD handle_data_changed.

    gv_changed = abap_true.

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

  CREATE OBJECT gr_docking_container
    EXPORTING
      repid = sy-repid
      dynnr = '0100'
      ratio = 10
      side  = gr_docking_container->dock_at_top.

  CREATE OBJECT gr_document.

  CLEAR lv_text.
  lv_nyomsor_c = gv_nyomsor.
  CONDENSE lv_nyomsor_c.
  CONCATENATE 'Stock ID:' p_stokid INTO lv_text SEPARATED BY space.
  PERFORM add_line USING lv_text.
  CLEAR lv_text.
  lv_nyomsor_c = gv_nyomsor.
  CONDENSE lv_nyomsor_c.
  CONCATENATE 'Nyomtatási sorok száma:' lv_nyomsor_c INTO lv_text SEPARATED BY space.
  PERFORM add_line USING lv_text.
  CLEAR lv_text.
  lv_kizsor_c = gv_kizsor.
  CONDENSE lv_kizsor_c.
  CONCATENATE 'Kizárt nyomtatási sorok száma: ' lv_kizsor_c INTO lv_text SEPARATED BY space.
  PERFORM add_line USING lv_text.

  CALL METHOD gr_document->display_document
    EXPORTING
      parent = gr_docking_container.
***

* ALV Grid cellák módosíthatósága
  IF gv_modif EQ abap_true.
    PERFORM cell_style_alv_outtab_0100.
  ENDIF.
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
      i_structure_name       = 'ZEBFS_PR_DCQM_REPORT'
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


* set substate of editable cells to deactivated
  CALL METHOD go_alv_grid_01->set_ready_for_input
    EXPORTING
      i_ready_for_input = 1.

  CALL METHOD go_alv_grid_01->register_edit_event
    EXPORTING
      i_event_id = cl_gui_alv_grid=>mc_evt_modified
    EXCEPTIONS
      error      = 1
      OTHERS     = 2.

  CLEAR ls_variant.
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
    gcl_alv_grid_01_event_receiver=>on_alv_toolbar "FOR go_alv_grid_01
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
      WHEN 'NAME1'.
        <fs>-coltext  = 'Név'.
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

  DATA: ls_log        TYPE bal_s_log.    "Log header data
* DEFINE SOME HEADER DATA OF THIS LOG
  ls_log-extnumber  = p_stokid.
  ls_log-object     = 'ZEBF_PR'.
  ls_log-subobject  = 'Z_STOCK'.
  ls_log-aldate     = sy-datum.
  ls_log-altime     = sy-uzeit.
  ls_log-aluser     = sy-uname.
  ls_log-alprog     = sy-repid.
  CALL FUNCTION 'BAL_LOG_CREATE'
    EXPORTING
      i_s_log                 = ls_log
    IMPORTING
      e_log_handle            = gv_log_handle
    EXCEPTIONS
      log_header_inconsistent = 1
      OTHERS                  = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

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
FORM send_priority .

  DATA: lv_dummy  TYPE string.
  DATA: ls_input  TYPE zebf_pr_eon_dcqmcompleted_req1,
        ls_output	TYPE zebf_pr_eon_dcqmcompleted_res2.

  DATA: lo_dcqm TYPE REF TO zebf_pr_co_eon_dcqmcompleted_p.
  DATA: lv_ex_txt TYPE string.
  DATA: lr_sys_fail TYPE REF TO cx_ai_system_fault,
        lr_app_fail TYPE REF TO cx_ai_application_fault.

  DATA: lt_env_tab TYPE zebf_pr_eon_dcqmcompleted__tab,
        ls_env_tab TYPE zebf_pr_eon_dcqmcompleted_req2.
  DATA lt_exc_env TYPE zebf_pr_string_tab.
  DATA ls_exc_env TYPE string.


  DATA ls_0100_alv TYPE zebfs_pr_dcqm_report.

*  zkg_break x0153.

  ls_input-sap_mandant = sy-mandt.
  ls_input-sap_system = sy-sysid.
  ls_input-stock_id = p_stokid.
  ls_input-priority = gv_priority.

  LOOP AT gt_0100_alv INTO ls_0100_alv.
*    ls_exc_env = ls_0100_alv-envelope.
    ls_env_tab-envelope_id = ls_0100_alv-envelope.
    APPEND ls_env_tab TO lt_env_tab.
  ENDLOOP.
  SORT lt_env_tab.
  DELETE ADJACENT DUPLICATES FROM lt_env_tab.
  ls_input-exclude_envelopes-envelope[] = lt_env_tab[].

  TRY.

      CREATE OBJECT lo_dcqm.

    CATCH cx_ai_system_fault INTO lr_sys_fail.
      lv_ex_txt = lr_sys_fail->get_text( ).
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_dummy.
      PERFORM log_add_message.
      EXIT.

  ENDTRY.


  TRY.

      CALL METHOD lo_dcqm->eon_dcqmcompleted
        EXPORTING
          input  = ls_input
        IMPORTING
          output = ls_output.

      IF ls_output-parameters-success = abap_true.

        MESSAGE s043(zebf_pr) INTO lv_dummy.
        PERFORM log_add_message.

      ELSE.
*Webservice hiba:
        gv_error = 'X'.
        MESSAGE ID 'ZEBF_PR_TRIGGER' TYPE 'E' NUMBER '000'
                WITH ls_output-parameters-error_code ':' ls_output-parameters-info INTO lv_dummy.
        PERFORM log_add_message.
        EXIT.

      ENDIF.

    CATCH cx_ai_system_fault  INTO lr_sys_fail.

      gv_error = 'X'.
*      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*                              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_dummy.
*      PERFORM log_add_message.
*      lv_ex_txt = lr_sys_fail->get_text( ).
*      sy-msgv1 = lv_ex_txt(50).
*      sy-msgv2 = lv_ex_txt+50(50).
*      sy-msgv3 = lv_ex_txt+100(50).
*      sy-msgv4 = lv_ex_txt+150(50).
*      MESSAGE ID 'ZEBF_PR' TYPE 'E' NUMBER '000'
*                              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_dummy.
*      PERFORM log_add_message.

    CATCH cx_ai_application_fault INTO lr_app_fail.

      gv_error = 'X'.
*      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*                              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_dummy.
*      PERFORM log_add_message.
*      lv_ex_txt = lr_app_fail->get_text( ).
*      sy-msgv1 = lv_ex_txt(50).
*      sy-msgv2 = lv_ex_txt+50(50).
*      sy-msgv3 = lv_ex_txt+100(50).
*      sy-msgv4 = lv_ex_txt+150(50).
*      MESSAGE ID 'ZEBF_PR' TYPE 'E' NUMBER '000'
*                              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_dummy.
*      PERFORM log_add_message.

  ENDTRY.

  IF gv_error EQ 'X'.
    MESSAGE ID 'ZEBF_PR' TYPE 'E' NUMBER '052'
                            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_dummy.
    PERFORM log_add_message.
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

  CALL METHOD gr_document->add_text
    EXPORTING
      text         = p_line_header
      sap_fontsize = cl_dd_document=>large
      sap_emphasis = cl_dd_document=>strong.

  CALL METHOD gr_document->new_line.

ENDFORM.                    " ADD_LINE
*&---------------------------------------------------------------------*
*&      Form  DEL_TERTI
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM del_terti .

  DATA:
    ls_0100_alv TYPE zebfs_pr_dcqm_report,
    ls_pr_terti TYPE zpr_terti.

  LOOP AT gt_0100_alv INTO ls_0100_alv.

    CLEAR ls_pr_terti.
    SELECT SINGLE * FROM zpr_terti
      INTO ls_pr_terti
     WHERE envelope_id EQ ls_0100_alv-envelope
       AND exbilldocno EQ ls_0100_alv-exbilldocno.
    IF sy-subrc EQ 0.
      DELETE FROM zpr_terti
       WHERE envelope_id EQ ls_pr_terti-envelope_id
         AND exbilldocno EQ ls_pr_terti-exbilldocno.
      DELETE FROM zisu_f064
       WHERE zisu_ragszam EQ ls_pr_terti-zisu_ragszam_128.
    ENDIF.

  ENDLOOP.

ENDFORM.                    " DEL_TERTI
