*********************************************************************
* Report: ZEBF_PR_DCQM_REPORT
* Leírás:
*
*--------------------------------------------------------------------
* Modulfelelos: <XY>
* --------------------------------------------------------------------
* Módosítások:
* <dátum>, <programozó>, <kérelem>, <comment azonosító>
*          <rövid leírás>
***********************************************************************
REPORT  zebf_pr_dcqm_report.

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

*----------------------------------------------------------------------*
*       CLASS lcl_layout_f4 DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_layout_f4 DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      for_salv
        CHANGING cv_layout TYPE disvariant-variant.
ENDCLASS.                    "lcl_layout_f4 DEFINITION
*----------------------------------------------------------------------*
*       CLASS lcl_layout_f4 IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_layout_f4 IMPLEMENTATION.
  METHOD for_salv.

    DATA: ls_layout TYPE salv_s_layout_info,
          ls_key    TYPE salv_s_layout_key.

    ls_key-report = sy-repid.

    ls_layout = cl_salv_layout_service=>f4_layouts(
                  s_key    = ls_key
                  restrict = if_salv_c_layout=>restrict_none  ).

    cv_layout = ls_layout-layout.


  ENDMETHOD.                    "for_salv

ENDCLASS.                    "lcl_layout_f4 IMPLEMENTATION


TYPES: BEGIN OF ty_envelope,
         envelope	TYPE zebfd_pr_envelop,
       END OF ty_envelope.

DATA:
* Képernyő OK-kódok
  gv_okcode_0100      TYPE syucomm.
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
  gs_0100_alv TYPE zebfs_pr_dcqm_report,
  gs_0100_orig TYPE zebfs_pr_dcqm_report.
DATA:
  gt_0100_alv    TYPE STANDARD TABLE OF zebfs_pr_dcqm_report,
  gt_0100_alv_plus    TYPE STANDARD TABLE OF zebfs_pr_dcqm_report,
  gt_0100_orig   TYPE STANDARD TABLE OF zebfs_pr_dcqm_report.

DATA: gv_modif   TYPE flag,
      gv_changed TYPE flag.
* LOG
DATA: gv_log_handle TYPE balloghndl.   "Application Log: Log Handle

DATA: gr_docking_container TYPE REF TO cl_gui_docking_container.
DATA: gr_document TYPE REF TO cl_dd_document.
DATA: gv_line_header TYPE sdydo_text_element.

RANGES gr_waers FOR zebft_pr_dcqm-waers.
DATA ls_waers LIKE LINE OF gr_waers.
*----------------------------------------------------------------------*
* SELECTION-SCREEN - for demonstration purposes only                   *
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.
SELECTION-SCREEN SKIP.
PARAMETERS: p_stokid TYPE zebfd_pr_stock_id
                     MATCHCODE OBJECT zebfh_pr_stockid OBLIGATORY,
            p_modif  TYPE flag NO-DISPLAY.
SELECTION-SCREEN SKIP.
SELECT-OPTIONS:
  so_docno FOR zebft_pr_dcqm-exbilldocno,
  so_envlo FOR zebft_pr_dcqm-envelope,
  so_vkont FOR zebft_pr_dcqm-vkont,
  so_pymet FOR zebft_pr_dcqm-pymet,
  so_erdat FOR zebft_pr_dcqm-erdat,
  so_ertim FOR zebft_pr_dcqm-ertim,
  so_ernam FOR zebft_pr_dcqm-ernam,
  so_postc FOR zebft_pr_dcqm-post_code1,
  so_bukrs FOR zebft_pr_dcqm-bukrs,
  so_docty FOR zebft_pr_dcqm-doc_type,
  so_opbel FOR zebft_pr_dcqm-opbel,
  so_amnt  FOR zebft_pr_dcqm-amnt.
PARAMETERS p_waers TYPE waers.
*SELECT-OPTIONS
* so_amnte FOR zebft_pr_dcqm-amnt_eur.
*PARAMETERS p_waere TYPE waers.
SELECT-OPTIONS:
  so_dest  FOR zebft_pr_dcqm-destination,
  so_copri FOR zebft_pr_dcqm-copri,
  so_gpart FOR zebft_pr_dcqm-gpart,
  so_dued FOR zebft_pr_dcqm-duedate,
  so_bkacc FOR zebft_pr_dcqm-bankaccountnum,
  so_giro  FOR zebft_pr_dcqm-giro,
  so_name  FOR zebft_pr_dcqm-name1,
  so_sysid FOR zebft_pr_dcqm-sysid,
  so_land1 FOR zebft_pr_dcqm-land1,
*  so_stat  FOR zebft_pr_dcqm-status,
*  so_error FOR zebft_pr_dcqm-error_code,
  so_ab    FOR zebft_pr_dcqm-ab,
  so_bis   FOR zebft_pr_dcqm-bis,
  so_tarif FOR zebft_pr_dcqm-tariftyp,
  so_aklas FOR zebft_pr_dcqm-aklasse,
  so_spart FOR zebft_pr_dcqm-sparte,
  so_mahns FOR zebft_pr_dcqm-mahns,
  so_mahnv FOR zebft_pr_dcqm-mahnv,
  so_zbizc FOR zebft_pr_dcqm-zbizcat,
  so_cotyp FOR zebft_pr_dcqm-cotyp,
  so_form  FOR zebft_pr_dcqm-form,
  so_fname FOR zebft_pr_dcqm-filename,
*  so_block FOR zebft_pr_dcqm-blocked,
  so_blodc FOR zebft_pr_dcqm-block_dc,
  so_bloqm FOR zebft_pr_dcqm-block_qm,
  so_regmn FOR zebft_pr_dcqm-regmailnumber.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE text-002.
PARAMETERS:
  p_vari TYPE slis_vari. "LAYOUT
SELECTION-SCREEN END OF BLOCK b02.

*----------------------------------------------------------------------*
* INITIALIZATION                                                  *
*----------------------------------------------------------------------*
INITIALIZATION.

  LOOP AT SCREEN.
    IF  screen-name EQ 'P_STOKID'.
      screen-input = '0'.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

*----------------------------------------------------------------------*
* AT SELECTION-SCREEN                                                  *
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.

  IF NOT p_stokid IS INITIAL.
    PERFORM check_stockid.
  ENDIF.

  IF NOT ( so_amnt-option EQ 'EQ' AND so_amnt-low EQ 0 AND so_amnt-high EQ 0 ).
    IF so_amnt[] IS NOT INITIAL
       AND p_waers IS INITIAL.
      MESSAGE e057(zebf_pr).
*   Ha megadott összeget, akkor adjon meg pénznemet is.
    ENDIF.
  ENDIF.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_vari.
  lcl_layout_f4=>for_salv( CHANGING cv_layout = p_vari ).


*----------------------------------------------------------------------*
* START-OF-SELECTION                                                   *
*----------------------------------------------------------------------*
START-OF-SELECTION.

*Pénznem szelekció. Tizedejegy korrekció
  DATA lv_faktor TYPE i.
  DATA ls_tcurx TYPE tcurx.
  SELECT SINGLE * FROM tcurx INTO ls_tcurx
    WHERE currkey EQ p_waers.
  IF sy-subrc NE 0.
    ls_tcurx-currdec = 2.
  ENDIF.
  lv_faktor = 2 - ls_tcurx-currdec.
  zkg_break x0153.
  LOOP AT so_amnt.
    so_amnt-low = so_amnt-low / ( 10 ** lv_faktor ).
    so_amnt-high = so_amnt-high / ( 10 ** lv_faktor ).
    MODIFY so_amnt.
  ENDLOOP.
  IF p_waers IS NOT INITIAL.
    CLEAR ls_waers.
    ls_waers-sign = 'I'.
    ls_waers-option = 'EQ'.
    ls_waers-low = p_waers.
    APPEND ls_waers TO gr_waers.
  ENDIF.

  CLEAR gv_modif.
  IF sy-tcode EQ 'ZEBF_PR_DCQM_MOD'.
    gv_modif = abap_true.
  ELSEIF sy-tcode EQ 'ZEBF_PR_DCQM_DISP'.
    gv_modif = abap_false.
  ELSE.
    gv_modif = p_modif.
  ENDIF.

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
  FIELD-SYMBOLS: <fs> TYPE zebfs_pr_dcqm_report.

  DATA lt_dcqm_env TYPE STANDARD TABLE OF zebfs_pr_dcqm_report.
  DATA lt_dcqm_env_plus TYPE STANDARD TABLE OF zebfs_pr_dcqm_report.
  DATA ls_dcqm_env_plus TYPE zebfs_pr_dcqm_report.
  DATA ls_dcqmlt TYPE zebft_pr_dcqmlt.
  DATA lt_dcqmlt TYPE TABLE OF zebft_pr_dcqmlt.
  DATA lr_filename TYPE RANGE OF zebft_pr_dcqm-filename.
  DATA lsr_filename LIKE LINE OF lr_filename.
  DATA: lv_plus_lines TYPE i,
        lv_lines TYPE i.

  SELECT filename INTO TABLE lt_files
    FROM zebft_pr_mssfile
   WHERE filename IN so_fname
     AND stock_id EQ p_stokid.

  lsr_filename-sign = 'I'.
  lsr_filename-option = 'EQ'.
  LOOP AT lt_files INTO ls_files.
    lsr_filename-low = ls_files-file.
    APPEND lsr_filename TO lr_filename.
  ENDLOOP.

  IF lt_files[] IS NOT INITIAL.
    SELECT * FROM zebft_pr_dcqm
      INTO CORRESPONDING FIELDS OF TABLE gt_0100_alv
      FOR ALL ENTRIES IN lt_files
     WHERE exbilldocno IN so_docno
        AND envelope   IN so_envlo
        AND vkont IN so_vkont
        AND pymet IN so_pymet
        AND erdat IN so_erdat
        AND ertim IN so_ertim
        AND ernam IN so_ernam
        AND post_code1 IN so_postc
        AND bukrs IN so_bukrs
        AND doc_type IN so_docty
        AND opbel IN so_opbel
        AND amnt  IN so_amnt
        AND waers IN gr_waers
*        AND amnt_eur IN so_amnte
*        AND waers_eur IN so_waere
        AND destination IN so_dest
        AND copri IN so_copri
        AND gpart IN so_gpart
        AND duedate IN so_dued
        AND bankaccountnum IN so_bkacc
        AND giro  IN so_giro
        AND name1 IN so_name
        AND sysid IN so_sysid
        AND land1 IN so_land1
*      AND status IN so_stat
*      AND error_code IN so_error
        AND ab  IN so_ab
        AND bis IN so_bis
        AND tariftyp IN so_tarif
        AND aklasse IN so_aklas
        AND sparte  IN so_spart
        AND mahns   IN so_mahns
        AND mahnv   IN so_mahnv
        AND zbizcat IN so_zbizc
        AND cotyp   IN so_cotyp
        AND form    IN so_form
        AND filename EQ lt_files-file
*      AND blocked  IN so_block
        AND block_dc IN so_blodc
        AND block_qm IN so_bloqm
        AND regmailnumber IN so_regmn.
  ELSE.
    MESSAGE i054(zebf_pr) WITH p_stokid.
    LEAVE TO SCREEN 1000.
  ENDIF.

  lt_dcqm_env[] = gt_0100_alv[].
  SORT lt_dcqm_env BY envelope.
  DELETE ADJACENT DUPLICATES FROM lt_dcqm_env COMPARING envelope.
  IF lt_dcqm_env[] IS NOT INITIAL.
    SELECT * FROM zebft_pr_dcqm
      INTO CORRESPONDING FIELDS OF TABLE lt_dcqm_env_plus
      FOR ALL ENTRIES IN lt_dcqm_env
      WHERE envelope EQ lt_dcqm_env-envelope.
  ENDIF.
  DELETE lt_dcqm_env_plus
    WHERE NOT filename IN lr_filename.

  SORT gt_0100_alv BY exbilldocno.
  LOOP AT lt_dcqm_env_plus INTO ls_dcqm_env_plus.
    READ TABLE gt_0100_alv TRANSPORTING NO FIELDS
      WITH KEY exbilldocno = ls_dcqm_env_plus-exbilldocno
      BINARY SEARCH.
    IF sy-subrc NE 0.
      APPEND ls_dcqm_env_plus TO gt_0100_alv_plus.
    ENDIF.
  ENDLOOP.
  DESCRIBE TABLE gt_0100_alv_plus LINES lv_plus_lines.
  APPEND LINES OF gt_0100_alv_plus TO gt_0100_alv.

  IF NOT gt_0100_alv[] IS INITIAL.
    SELECT * FROM zebft_pr_dcqmlt
      INTO TABLE lt_dcqmlt
      FOR ALL ENTRIES IN gt_0100_alv
      WHERE exbilldocno = gt_0100_alv-exbilldocno.
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
    <fs>-counter = 1.
  ENDLOOP.

  SORT gt_0100_alv BY envelope exbilldocno.
  gt_0100_orig[] = gt_0100_alv[].

  IF lv_plus_lines GT 0.
    MESSAGE i056(zebf_pr).
*   A szelekció ki lett bővítve(Egy borítékba kerülő nyomtatv. megjelennek)
  ENDIF.

*  DESCRIBE TABLE gt_0100_alv LINES lv_lines.
*  IF lv_lines GT 10000.
*    MESSAGE e063(zebf_pr).
*  ENDIF.

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

  DATA: lv_closed TYPE zebfd_pr_closed.

  SELECT SINGLE closed INTO lv_closed
    FROM zebft_pr_stock
   WHERE stock_id EQ p_stokid.

  IF sy-subrc NE 0.
    MESSAGE e020(zebf_pr).
  ENDIF.

  IF p_modif NE space.
    IF lv_closed EQ abap_true.
      CLEAR p_modif.
      gv_modif = abap_false.
      MESSAGE i021(zebf_pr).
    ENDIF.
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


INCLUDE zebf_pr_dcqm_report_o01.

INCLUDE zebf_pr_dcqm_report_i01.

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
  ls_log-subobject  = 'Z_DC'.
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
*----------------------------------------------------------------------*
*       CLASS gcl_alv_grid_01_event_receiver IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS gcl_alv_grid_01_event_receiver IMPLEMENTATION.

  METHOD on_alv_user_command.

    DATA: lv_error  TYPE flag,
          lv_lines  TYPE i,
          lv_ret    TYPE char1,
          lv_hiba   TYPE flag,
          lv_dummy  TYPE string,
          lv_block_dc TYPE zebfd_pr_block_dc,
          lv_block_dc_text TYPE zebfd_pr_block_dc_text.
    DATA: ls_edit   TYPE lvc_s_styl,
          ls_stable TYPE lvc_s_stbl.
    DATA: lt_rows TYPE lvc_t_row,
          ls_rows LIKE LINE OF lt_rows.
    DATA: ls_sval  TYPE sval.
    DATA: lt_sval  TYPE STANDARD TABLE OF sval.
    DATA: lt_0100_alv_env TYPE TABLE OF ty_envelope,
          ls_0100_alv_env TYPE ty_envelope.
    DATA lv_kizart TYPE i.

    ls_stable-col = abap_true.
    ls_stable-row = abap_true.

    CALL METHOD go_alv_grid_01->get_selected_rows
      IMPORTING
        et_index_rows = lt_rows.

    DESCRIBE TABLE lt_rows LINES lv_lines.

    CASE e_ucomm.
      WHEN 'HIST'.


      WHEN 'KIZAR'.

        IF lv_lines EQ 0.
          MESSAGE i023(zebf_pr).
          EXIT.
        ENDIF.

        REFRESH lt_sval.
        ls_sval-tabname   = 'ZEBFT_PR_DCQM'.
        ls_sval-fieldname = 'BLOCK_DC'.
        ls_sval-fieldtext = 'Hibakód: '.
        ls_sval-comp_tab  = 'ZEBFC_PR_DCCODE'.
        ls_sval-comp_field = 'BLOCK_DC'.
        APPEND ls_sval TO lt_sval.
        CLEAR ls_sval.
        ls_sval-tabname   = 'ZEBFT_PR_DCQMLT'.
        ls_sval-fieldname = 'BLOCK_DC_TEXT'.
        ls_sval-fieldtext = 'Leírás: '.
        APPEND ls_sval TO lt_sval.

        CALL FUNCTION 'POPUP_GET_VALUES_USER_CHECKED'
          EXPORTING
            formname        = 'CHECK_ENTERED_DATA_POPUP'
            programname     = 'ZEBF_PR_DCQM_REPORT'
            popup_title     = 'Kérem, adja meg a kizárás paramétereit:'
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
              WHEN 'BLOCK_DC'.
                lv_block_dc = ls_sval-value.
              WHEN 'BLOCK_DC_TEXT'.
                lv_block_dc_text = ls_sval-value.
            ENDCASE.
          ENDLOOP.
        ENDIF.

        LOOP AT lt_rows INTO ls_rows.

          READ TABLE gt_0100_alv INTO gs_0100_alv INDEX ls_rows-index.
          gs_0100_alv-block_dc = lv_block_dc.
          gs_0100_alv-block_dc_text = lv_block_dc_text.
          gs_0100_alv-changed = abap_true.
          MODIFY gt_0100_alv FROM gs_0100_alv INDEX ls_rows-index.

          ls_0100_alv_env-envelope = gs_0100_alv-envelope.
          APPEND ls_0100_alv_env TO lt_0100_alv_env.

          ADD 1 TO lv_kizart.
        ENDLOOP.

        SORT lt_0100_alv_env.
        DELETE ADJACENT DUPLICATES FROM lt_0100_alv_env.

        LOOP AT lt_0100_alv_env INTO ls_0100_alv_env.
          LOOP AT gt_0100_alv INTO gs_0100_alv
            WHERE envelope EQ ls_0100_alv_env-envelope.
            IF gs_0100_alv-block_dc IS INITIAL.
              gs_0100_alv-block_dc = 'ZZ'.
              gs_0100_alv-block_dc_text = lv_block_dc_text.
              gs_0100_alv-changed = abap_true.
              MODIFY gt_0100_alv FROM gs_0100_alv INDEX sy-tabix.
              ADD 1 TO lv_kizart.
            ENDIF.
          ENDLOOP.
        ENDLOOP.

        MESSAGE s059(zebf_pr) WITH lv_kizart." DISPLAY LIKE 'W'.
*   A kizárt rekordok száma: &1.

        CALL METHOD go_alv_grid_01->refresh_table_display
          EXCEPTIONS
            finished = 1
            OTHERS   = 2.

      WHEN 'KIZVISSZ'.

        IF lv_lines EQ 0.
          MESSAGE i023(zebf_pr).
          EXIT.
        ENDIF.

        LOOP AT lt_rows INTO ls_rows.
          READ TABLE gt_0100_alv INTO gs_0100_alv INDEX ls_rows-index.
          CLEAR: gs_0100_alv-block_dc,
                 gs_0100_alv-block_dc_text.
          gs_0100_alv-changed = abap_true.
          MODIFY gt_0100_alv FROM gs_0100_alv INDEX ls_rows-index.

          ls_0100_alv_env-envelope = gs_0100_alv-envelope.
          APPEND ls_0100_alv_env TO lt_0100_alv_env.
        ENDLOOP.

        SORT lt_0100_alv_env.
        DELETE ADJACENT DUPLICATES FROM lt_0100_alv_env.

        LOOP AT lt_0100_alv_env INTO ls_0100_alv_env.
          LOOP AT gt_0100_alv INTO gs_0100_alv
            WHERE envelope EQ ls_0100_alv_env-envelope.
            CLEAR: gs_0100_alv-block_dc,
                   gs_0100_alv-block_dc_text.
            gs_0100_alv-changed = abap_true.
            MODIFY gt_0100_alv FROM gs_0100_alv INDEX sy-tabix.
          ENDLOOP.
        ENDLOOP.

        CALL METHOD go_alv_grid_01->refresh_table_display
          EXCEPTIONS
            finished = 1
            OTHERS   = 2.

      WHEN 'REFRESH'.

*        REFRESH gt_0100_alv.
**        PERFORM select.
*        CALL METHOD go_alv_grid_01->refresh_table_display
**          EXPORTING
**            is_stable = ls_stable
*          EXCEPTIONS
*            finished = 1
*            OTHERS   = 2.

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
      gs_toolbar-function   = 'KIZAR'.
      gs_toolbar-icon       = icon_locked.
      gs_toolbar-quickinfo  = 'Kizárás'.
      gs_toolbar-text       = ' Kizárás'.
      APPEND gs_toolbar TO e_object->mt_toolbar.

      CLEAR gs_toolbar.
      gs_toolbar-function   = 'KIZVISSZ'.
      gs_toolbar-icon       = icon_unlocked.
      gs_toolbar-quickinfo  = 'Kizárás visszavétele'.
      gs_toolbar-text       = ' Kizárás vissza'.
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


    ENDIF.


  ENDMETHOD.                    "on_double_click

  METHOD handle_data_changed.

    DATA: lv_value TYPE string,
          lv_row   TYPE i,
          lv_van   TYPE flag.
    DATA: ls_mod_cells TYPE lvc_s_modi,
          ls_col_id    TYPE lvc_s_col,
          ls_stable    TYPE lvc_s_stbl.
    DATA: lt_0100_alv_env TYPE TABLE OF zebfs_pr_dcqm_report,
          ls_0100_alv_env TYPE zebfs_pr_dcqm_report.

    ls_stable-col = abap_true.
    ls_stable-row = abap_true.

    LOOP AT er_data_changed->mt_mod_cells INTO ls_mod_cells.

      CLEAR gs_0100_alv.
      READ TABLE gt_0100_alv INTO gs_0100_alv INDEX ls_mod_cells-row_id.

      CALL METHOD er_data_changed->get_cell_value
        EXPORTING
          i_row_id    = ls_mod_cells-row_id
          i_tabix     = ls_mod_cells-tabix
          i_fieldname = ls_mod_cells-fieldname
        IMPORTING
          e_value     = lv_value.

      REFRESH lt_0100_alv_env.

      APPEND gs_0100_alv TO lt_0100_alv_env.

      LOOP AT lt_0100_alv_env INTO ls_0100_alv_env.
        LOOP AT gt_0100_alv INTO gs_0100_alv
          WHERE envelope EQ ls_0100_alv_env-envelope
            AND exbilldocno NE ls_0100_alv_env-exbilldocno.
          IF ls_mod_cells-fieldname EQ 'BLOCK_DC'.
            IF lv_value IS NOT INITIAL AND lv_value NE space.
              gs_0100_alv-block_dc = 'ZZ'.
              gs_0100_alv-changed = abap_true.
            ELSE.
              CLEAR: gs_0100_alv-block_dc,
                     gs_0100_alv-block_dc_text.
              gs_0100_alv-changed = abap_true.
            ENDIF.
          ENDIF.
          IF ls_mod_cells-fieldname EQ 'BLOCK_DC_TEXT'.
            IF lv_value IS NOT INITIAL AND lv_value NE space.
              gs_0100_alv-block_dc_text = lv_value.
              gs_0100_alv-changed = abap_true.
            ELSE.
              CLEAR: gs_0100_alv-block_dc_text.
              gs_0100_alv-changed = abap_true.
            ENDIF.
          ENDIF.
          MODIFY gt_0100_alv FROM gs_0100_alv INDEX sy-tabix.
        ENDLOOP.
      ENDLOOP.


      CALL METHOD go_alv_grid_01->refresh_table_display
        EXPORTING
          is_stable = ls_stable
        EXCEPTIONS
          finished  = 1
          OTHERS    = 2.

      gv_changed = abap_true.

    ENDLOOP. "LOOP AT er_data_changed->mt_mod_cells INTO ls_mod_cells.



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

  DATA: lv_okcode TYPE syucomm,
        lv_hiba   TYPE flag,
        lv_dummy  TYPE string.
  DATA: ls_dcqmlt TYPE zebft_pr_dcqmlt.

  lv_okcode = gv_okcode_0100.
  CLEAR gv_okcode_0100.
  CASE lv_okcode.
    WHEN 'SAVE'.

      PERFORM check_changed.

      PERFORM log_create.

      LOOP AT gt_0100_alv INTO gs_0100_alv
        WHERE changed EQ abap_true.

        UPDATE zebft_pr_dcqm SET block_dc = gs_0100_alv-block_dc
          WHERE exbilldocno EQ gs_0100_alv-exbilldocno.

        SELECT SINGLE * FROM zebft_pr_dcqmlt
          INTO ls_dcqmlt
         WHERE exbilldocno EQ gs_0100_alv-exbilldocno.
        IF sy-subrc EQ 0.
          IF gs_0100_alv-block_dc_text IS INITIAL.
            DELETE FROM zebft_pr_dcqmlt
             WHERE exbilldocno EQ gs_0100_alv-exbilldocno.
          ELSE.
            UPDATE zebft_pr_dcqmlt SET block_dc_text = gs_0100_alv-block_dc_text
              WHERE exbilldocno EQ gs_0100_alv-exbilldocno.
          ENDIF.
        ELSE.
          IF gs_0100_alv-block_dc_text IS NOT INITIAL.
            ls_dcqmlt-exbilldocno = gs_0100_alv-exbilldocno.
            ls_dcqmlt-block_dc_text = gs_0100_alv-block_dc_text.
            MODIFY zebft_pr_dcqmlt FROM ls_dcqmlt.
          ENDIF.
        ENDIF.

        IF gs_0100_alv-block_dc IS INITIAL.
          MESSAGE s045(zebf_pr) WITH gs_0100_alv-exbilldocno INTO lv_dummy.
        ELSE.
          MESSAGE s044(zebf_pr)
             WITH gs_0100_alv-exbilldocno gs_0100_alv-block_dc
                  gs_0100_alv-block_dc_text
             INTO lv_dummy.
        ENDIF.
        PERFORM log_add_message.

      ENDLOOP.

      IF sy-subrc EQ 0.
        COMMIT WORK.
        MESSAGE s024(zebf_pr) INTO lv_dummy.
        PERFORM log_add_message.
      ELSE.
        ROLLBACK WORK.
        MESSAGE s025(zebf_pr) INTO lv_dummy.
        PERFORM log_add_message.
      ENDIF.

      PERFORM log_display.

      PERFORM alv_grid_01_free.
      SET SCREEN 0.
      LEAVE SCREEN.

  ENDCASE.

ENDFORM.                    " USER_COMMAND_0100
*&---------------------------------------------------------------------*
*&      Form  EXIT_COMMAND_0100
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM exit_command_0100 .

  DATA: lv_okcode TYPE syucomm,
        lv_valasz TYPE char1.

  PERFORM check_changed.

  lv_okcode = gv_okcode_0100.
  CASE lv_okcode.
    WHEN 'BACK'
      OR 'EXIT'
      OR 'CANCEL'.
      IF gv_changed EQ abap_true.
        "figyelmeztetés
        CALL FUNCTION 'POPUP_TO_CONFIRM_WITH_MESSAGE'
          EXPORTING
            defaultoption  = 'N'
            diagnosetext1  = 'Történtek módosítások, nem mentett adatok elvesznek!'
            textline1      = 'Biztosan kilép?'
            titel          = ' FIGYELMEZTETÉS'
            start_column   = 35
            start_row      = 11
            cancel_display = space
          IMPORTING
            answer         = lv_valasz.
        IF lv_valasz EQ 'J'.
          PERFORM alv_grid_01_free.
          SET SCREEN 0.
          LEAVE SCREEN.
        ENDIF.
      ELSE.
        PERFORM alv_grid_01_free.
        SET SCREEN 0.
        LEAVE SCREEN.
      ENDIF.

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
  DATA lv_stokid(10).

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

* ALV Grid cellák módosíthatósága
  IF gv_modif EQ abap_true.
    PERFORM cell_style_alv_outtab_0100.
  ENDIF.
*
* Alv Grid layout beállítás
  CLEAR ls_layout.
  ls_layout-zebra      = 'X'.
  ls_layout-cwidth_opt = 'X'.
  lv_stokid = p_stokid.
  SHIFT lv_stokid LEFT DELETING LEADING '0'.
  IF p_modif EQ 'X'.
    CONCATENATE lv_stokid 'stock feldolgozása'
           INTO ls_layout-grid_title SEPARATED BY space.
  ELSE.
    CONCATENATE lv_stokid 'stock megjelenítése'
           INTO ls_layout-grid_title SEPARATED BY space.
  ENDIF.
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
  ls_variant-variant  = p_vari.

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
      WHEN 'CHANGED'.
        <fs>-no_out  = abap_true.
      WHEN 'BLOCK_DC'.
        <fs>-f4availabl = 'X'.
      WHEN 'BLOCK_QM'.
        <fs>-f4availabl = 'X'.
      WHEN 'AMNT_EUR'.
        <fs>-no_out = 'X'.
      WHEN 'WAERS_EUR'.
        <fs>-no_out = 'X'.
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

  DATA: ls_edit TYPE lvc_s_styl.

  FIELD-SYMBOLS: <fs> TYPE zebfs_pr_dcqm_report.

  LOOP AT gt_0100_alv ASSIGNING <fs>.

    REFRESH <fs>-handle_style.

    CLEAR ls_edit.
    ls_edit-fieldname = 'BLOCKED'.
    ls_edit-style  = cl_gui_alv_grid=>mc_style_enabled.
    INSERT ls_edit INTO TABLE <fs>-handle_style.
    CLEAR ls_edit.
    ls_edit-fieldname = 'BLOCK_DC'.
    ls_edit-style  = cl_gui_alv_grid=>mc_style_enabled.
    INSERT ls_edit INTO TABLE <fs>-handle_style.
    CLEAR ls_edit.
    ls_edit-fieldname = 'BLOCK_DC_TEXT'.
    ls_edit-style  = cl_gui_alv_grid=>mc_style_enabled.
    INSERT ls_edit INTO TABLE <fs>-handle_style.

  ENDLOOP.


ENDFORM.                    " CELL_STYLE_ALV_OUTTAB_0100
*&---------------------------------------------------------------------*
*&      Form  CHECK_CHANGED
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM check_changed .

  SORT gt_0100_orig BY exbilldocno.

  CLEAR gv_changed.

  LOOP AT gt_0100_alv INTO gs_0100_alv.
    CLEAR: gs_0100_alv-changed, gs_0100_alv-handle_style.
    READ TABLE gt_0100_orig INTO gs_0100_orig
      WITH KEY exbilldocno = gs_0100_alv-exbilldocno
      BINARY SEARCH.
    IF gs_0100_alv NE gs_0100_orig.
      gs_0100_alv-changed = 'X'.
      MODIFY gt_0100_alv FROM gs_0100_alv.
      gv_changed = 'X'.
    ENDIF.
  ENDLOOP.

ENDFORM.                    " CHECK_CHANGED
*&---------------------------------------------------------------------*
*&      Form  CHECK_ENTERED_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM check_entered_data .
  DATA ls_dccode TYPE zebfc_pr_dccode.

  LOOP AT gt_0100_alv INTO gs_0100_alv.
    IF gs_0100_alv-block_dc IS NOT INITIAL.
      SELECT SINGLE * FROM zebfc_pr_dccode
        INTO ls_dccode
        WHERE block_dc = gs_0100_alv-block_dc.
      IF sy-subrc NE 0.
        MESSAGE e046(zebf_pr) WITH gs_0100_alv-block_dc.
*   DC zárolás kód &1 nem létezik.
      ENDIF.
    ELSE.
      IF gs_0100_alv-block_dc_text IS NOT INITIAL.
        MESSAGE e047(zebf_pr).
*   Ha DC zárolás szöveget ad meg, akkor adjon meg DC zárolás kódot is!
      ENDIF.
    ENDIF.
  ENDLOOP.


ENDFORM.                    " CHECK_ENTERED_DATA
*&---------------------------------------------------------------------*
*&      Form  CHECK_ENTERED_DATA_POPUP
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM check_entered_data_popup TABLES p_fields STRUCTURE sval
                              USING error STRUCTURE svale.

  DATA ls_dccode TYPE zebfc_pr_dccode.
  DATA lv_block_dc TYPE zebfd_pr_block_dc.
  DATA lv_block_dc_text TYPE zebfd_pr_block_dc_text.
  DATA ls_fields TYPE sval.


  LOOP AT p_fields INTO ls_fields.
    CASE ls_fields-fieldname.
      WHEN 'BLOCK_DC'.
        lv_block_dc = ls_fields-value.
      WHEN 'BLOCK_DC_TEXT'.
        lv_block_dc_text = ls_fields-value.
    ENDCASE.
  ENDLOOP.

  IF lv_block_dc IS NOT INITIAL.
    SELECT SINGLE * FROM zebfc_pr_dccode
      INTO ls_dccode
      WHERE block_dc = lv_block_dc.
    IF sy-subrc NE 0.
      CLEAR error.
      error-msgid = 'ZEBF_PR'.
      error-msgty = 'E'.
      error-msgno = '046'.
      error-msgv1 = lv_block_dc.
*   DC zárolás kód &1 nem létezik.
      EXIT.
    ENDIF.
  ELSE.
    IF lv_block_dc_text IS NOT INITIAL.
      CLEAR error.
      error-msgid = 'ZEBF_PR'.
      error-msgty = 'E'.
      error-msgno = '047'.
*   Ha DC zárolás szöveget ad meg, akkor adjon meg DC zárolás kódot is!
      EXIT.
    ENDIF.
  ENDIF.


ENDFORM.                    " CHECK_ENTERED_DATA
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