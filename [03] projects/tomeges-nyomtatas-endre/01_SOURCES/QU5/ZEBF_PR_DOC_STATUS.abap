*********************************************************************
* Report: ZEBF_PR_DOC_STATUS
* Leírás: Dokumentum státuszok lekérése INSPIRE oldalról
*
*--------------------------------------------------------------------
* Modulfelelos: <XY>
* Tanácsadó:
* Programozó:   Molnár Gábor
* Dátum, kérelem: 2022.04.11,
* --------------------------------------------------------------------
* Módosítások:
* 2022/07/15, X0107, https://jira.eon.com/browse/EHUINSP-2026
* 2022.09.21, G4216, INC2313585 - ZEBF_PR_DOC_STATUS elakadás
* 2023.04.27. G1271, INC2735509 - PU5 SD Message gueue table
***********************************************************************
REPORT  zebf_pr_doc_status MESSAGE-ID zebf_pr_status.



*----------------------------------------------------------------------*
* TABLE
*----------------------------------------------------------------------*
TABLES: zebft_pr_dcqm, zebft_pr_stock.                      "#EC NEEDED

*----------------------------------------------------------------------*
* TYPES
*----------------------------------------------------------------------*
TYPE-POOLS: abap.

TYPES: BEGIN OF ty_stock,
         stock_id    TYPE zebfd_pr_stock_id,
       END OF ty_stock.
TYPES: BEGIN OF ty_exbilldoc,
        stock_id    TYPE zebfd_pr_stock_id,
        exbilldocno	TYPE zebfd_pr_exbilldocno,
        envelope    TYPE zebfd_pr_envelop,
        destination	TYPE zebfd_pr_destination,
        bukrs TYPE bukrs,
        doc_type TYPE zbcd_docty,
        doc_cat	TYPE zebfd_pr_doccat,
        sparte TYPE sparte,
        form TYPE zebfd_pr_formname,
        opbel	TYPE e_printdoc,
        fccnu	TYPE sww_retcnt,
        extnu TYPE sww_retcnt,
        tstmp_trigger	TYPE zebfd_pr_tmstmp_trigger,
        tstmp_r	TYPE zebfd_pr_tstmp_r,
        tstmp_c	TYPE zebfd_pr_tstmp_c,
        tstmp_b TYPE zebfd_pr_tstmp_b,
        tstmp_q	TYPE zebfd_pr_tstmp_q,
        tstmp_o	TYPE zebfd_pr_tstmp_o,
        tstmp_x	TYPE zebfd_pr_tstmp_x,
        tstmp_p	TYPE zebfd_pr_tstmp_p,
        tstmp_l	TYPE zebfd_pr_tstmp_l,
        tstmp_g	TYPE zebfd_pr_tstmp_g,
        tstmp_s	TYPE zebfd_pr_tstmp_s,
        tstmp_a	TYPE zebfd_pr_tstmp_a,
        tstmp_d	TYPE zebfd_pr_tstmp_d,
        tstmp_e	TYPE zebfd_pr_tstmp_e,
        tstmp_v	TYPE zebfd_pr_tstmp_v,
        tstmp_error	TYPE zebfd_pr_tstmp_error,
        error_code  TYPE zebfd_pr_error_code,
        error_text  TYPE zebfd_pr_error_text.
TYPES: END OF ty_exbilldoc.
TYPES: tty_exbilldoc TYPE STANDARD TABLE OF ty_exbilldoc.

TYPES: BEGIN OF ty_response,
        exbilldocno	TYPE zebfd_pr_exbilldocno,
        filename    TYPE string,
        tstmp_r TYPE zebfd_pr_tstmp_r,
        tstmp_c	TYPE zebfd_pr_tstmp_c,
        tstmp_b TYPE zebfd_pr_tstmp_b,
        tstmp_q	TYPE zebfd_pr_tstmp_q,
        tstmp_o	TYPE zebfd_pr_tstmp_o,
        tstmp_x	TYPE zebfd_pr_tstmp_x,
        tstmp_p	TYPE zebfd_pr_tstmp_p,
        tstmp_l	TYPE zebfd_pr_tstmp_l,
        tstmp_g	TYPE zebfd_pr_tstmp_g,
        tstmp_s	TYPE zebfd_pr_tstmp_s,
        tstmp_a	TYPE zebfd_pr_tstmp_a,
        tstmp_d	TYPE zebfd_pr_tstmp_d,
        tstmp_e	TYPE zebfd_pr_tstmp_e,
        tstmp_v	TYPE zebfd_pr_tstmp_v,
        error_code  TYPE char4,
        error_text  TYPE zebfd_pr_error_text,
       END OF ty_response.

TYPES: BEGIN OF ty_slog_key,
        ch TYPE char2,
        opbel TYPE e_printdoc,
        doc_type TYPE zbcd_docty,
        fccnu	TYPE sww_retcnt,
       END OF ty_slog_key.

TYPES: BEGIN OF ty_fajl,
        1 TYPE string,                                      "#EC *
        2 TYPE string,                                      "#EC *
        3 TYPE string,                                      "#EC *
        4 TYPE string,                                      "#EC *
        5 TYPE string,                                      "#EC *
        6 TYPE string,                                      "#EC *
        7 TYPE string,                                      "#EC *
        8 TYPE string,                                      "#EC *
        9 TYPE string,                                      "#EC *
       10 TYPE string,                                      "#EC *
       END OF ty_fajl.


*----------------------------------------------------------------------*
* Globális változók
*----------------------------------------------------------------------*
* LOG
DATA: gv_log_handle TYPE balloghndl.   "Application Log: Log Handle
DATA: gv_dummy TYPE string.                                 "#EC NEEDED
DATA: gt_stock TYPE STANDARD TABLE OF ty_stock.

*----------------------------------------------------------------------*
* SELECTION-SCREEN - for demonstration purposes only                   *
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.
SELECTION-SCREEN SKIP.
SELECT-OPTIONS: so_stock FOR zebft_pr_stock-stock_id
                         MATCHCODE OBJECT zebfh_pr_stock_closed.
SELECTION-SCREEN SKIP.
PARAMETERS: p_det AS CHECKBOX.
SELECTION-SCREEN SKIP.
PARAMETERS: p_stat AS CHECKBOX.

SELECTION-SCREEN END OF BLOCK b01.

**----------------------------------------------------------------------*
** AT SELECTION-SCREEN                                                  *
**----------------------------------------------------------------------*
AT SELECTION-SCREEN.

  IF p_stat EQ abap_true AND
     so_stock[] IS INITIAL.
    MESSAGE e032.
  ENDIF.


INITIALIZATION.

  AUTHORITY-CHECK OBJECT 'S_TCODE'
  ID 'TCD' FIELD 'ZEBF_PR_DOC_STATUS'.

  IF sy-subrc = 0.

  ELSE.
    MESSAGE i000 WITH 'Nincs joga a'(100) sy-tcode 'tranzakcióhoz!'(101).
    LEAVE PROGRAM.
  ENDIF.

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

* felolgozás
  PERFORM processing.


*&---------------------------------------------------------------------*
*&      Form  SELECT_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM select_data.


  IF p_stat EQ abap_true.
    SELECT stock_id FROM zebft_pr_stock
      INTO TABLE gt_stock
     WHERE stock_id IN so_stock
       AND closed   EQ abap_true.
  ELSE.
    SELECT stock_id FROM zebft_pr_stock
      INTO TABLE gt_stock
     WHERE stock_id IN so_stock
       AND closed   EQ abap_true
       AND stock_status NE 'D'.
*ERDAT
*ERNAM
*ERTIM
*CLOSED
*ERDAT_CLO
*ERNAM_CLO
*ERTIM_CLO
*PRIORITY
*DCCOMPL
*QMCOMPL
*NOTEST
*STOCK_STATUS
*STOCK_STATUS_ER
  ENDIF.

  IF sy-subrc NE 0.
    MESSAGE e002.
  ENDIF.


ENDFORM.                    " SELECT_DATA
*&---------------------------------------------------------------------*
*&      Form  PROCESSING
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM processing .

  DATA: lv_tabix  TYPE i,
        lv_string TYPE string,
        lv_hiba   TYPE flag,
        lv_stock_flag TYPE flag. "ha van nyitoot dokumentum
  DATA: ls_slogkey   TYPE ty_slog_key,
        ls_exbilldoc TYPE ty_exbilldoc,
        ls_slog2     TYPE zpr_slog2,
        ls_stock     TYPE ty_stock,
        ls_output    TYPE zebf_pr_eon_forms_query_doc_d2,
        ls_response  TYPE ty_response.
  DATA: lt_exbilldoc TYPE STANDARD TABLE OF ty_exbilldoc.

  FIELD-SYMBOLS <fs_exbill> TYPE ty_exbilldoc.


  PERFORM log_create.

  LOOP AT gt_stock INTO ls_stock.

*   Stock zárolása
    PERFORM stock_zar USING ls_stock
                      CHANGING lv_hiba.
    IF lv_hiba EQ abap_true.
      CONTINUE.
    ENDIF.

    REFRESH lt_exbilldoc.
    SELECT zebft_pr_mssfile~stock_id
           zebft_pr_dcqm~exbilldocno
           zebft_pr_dcqm~envelope
           zebft_pr_dcqm~destination
           zebft_pr_dcqm~bukrs
           zebft_pr_dcqm~doc_type
           zebft_pr_dcqm~doc_cat
           zebft_pr_dcqm~sparte
           zebft_pr_dcqm~form
      FROM zebft_pr_mssfile INNER JOIN zebft_pr_dcqm
                                    ON zebft_pr_dcqm~filename EQ zebft_pr_mssfile~filename
      INTO CORRESPONDING FIELDS OF TABLE lt_exbilldoc
     WHERE zebft_pr_mssfile~stock_id EQ ls_stock-stock_id.


    LOOP AT lt_exbilldoc ASSIGNING <fs_exbill>.

      lv_tabix = sy-tabix.

      CLEAR ls_slogkey.
      ls_slogkey = <fs_exbill>-exbilldocno.

      CLEAR ls_slog2.
      SELECT SINGLE * FROM zpr_slog2                        "#EC *
        INTO ls_slog2
       WHERE opbel    EQ ls_slogkey-opbel
         AND fccnu    EQ ls_slogkey-fccnu
         AND doc_type EQ ls_slogkey-doc_type.

*      IF ls_slog2-tstmp_d        IS INITIAL AND
*         ls_slog2-tstmp_error    IS INITIAL AND
*         ls_slog2-tstmp_trigger  IS NOT INITIAL.
      <fs_exbill>-opbel	= ls_slog2-opbel.
      <fs_exbill>-fccnu = ls_slog2-fccnu.
      <fs_exbill>-extnu = ls_slog2-extnu.
      <fs_exbill>-tstmp_trigger = ls_slog2-tstmp_trigger.
      <fs_exbill>-tstmp_r = ls_slog2-tstmp_r.
      <fs_exbill>-tstmp_c = ls_slog2-tstmp_c.
      <fs_exbill>-tstmp_b = ls_slog2-tstmp_b.
      <fs_exbill>-tstmp_q = ls_slog2-tstmp_q.
      <fs_exbill>-tstmp_o = ls_slog2-tstmp_o.
      <fs_exbill>-tstmp_x = ls_slog2-tstmp_x.
      <fs_exbill>-tstmp_p = ls_slog2-tstmp_p.
      <fs_exbill>-tstmp_l = ls_slog2-tstmp_l.
      <fs_exbill>-tstmp_g = ls_slog2-tstmp_g.
      <fs_exbill>-tstmp_s = ls_slog2-tstmp_s.
      <fs_exbill>-tstmp_a = ls_slog2-tstmp_a.
      <fs_exbill>-tstmp_d = ls_slog2-tstmp_d.
      <fs_exbill>-tstmp_e = ls_slog2-tstmp_e.
      <fs_exbill>-tstmp_v = ls_slog2-tstmp_v.
      <fs_exbill>-tstmp_error = ls_slog2-tstmp_error.
      <fs_exbill>-error_code = ls_slog2-error_code.
      <fs_exbill>-error_text = ls_slog2-error_text.
*      ELSE.
*        DELETE lt_exbilldoc INDEX lv_tabix.
*      ENDIF.
*     ha valamelyik teljesül, akkor nem kell újra lekérni
      IF ( p_stat EQ abap_false AND
           ls_slog2-tstmp_d IS NOT INITIAL )   OR
         ls_slog2-tstmp_error   IS NOT INITIAL OR
         ls_slog2-tstmp_trigger IS INITIAL.
        DELETE lt_exbilldoc INDEX lv_tabix.
      ENDIF.

    ENDLOOP.

    CLEAR ls_output.
    PERFORM get_inspire_data USING    ls_stock-stock_id
                                      lt_exbilldoc
                             CHANGING ls_output.
    IF ls_output-success NE abap_true.
      CONTINUE.
    ENDIF.


    CLEAR lv_stock_flag. "

    LOOP AT ls_output-docs-d INTO lv_string.

      SPLIT lv_string AT ';' INTO
        ls_response-exbilldocno
        ls_response-filename
        ls_response-tstmp_r
        ls_response-tstmp_c
        ls_response-tstmp_b
        ls_response-tstmp_q
        ls_response-tstmp_o
        ls_response-tstmp_x
        ls_response-tstmp_p
        ls_response-tstmp_l
        ls_response-tstmp_g
        ls_response-tstmp_s
        ls_response-tstmp_a
        ls_response-tstmp_d
        ls_response-tstmp_e
        ls_response-tstmp_v
        ls_response-error_code
        ls_response-error_text.

      IF ls_response-exbilldocno IS INITIAL.
        MESSAGE e030 WITH ls_response-exbilldocno INTO gv_dummy.
        PERFORM log_add_message.
        CONTINUE.
      ENDIF.

      IF p_det EQ abap_true. "részletes napló
        PERFORM log_add_response USING ls_response.
      ENDIF.

*     SAP adatok
      READ TABLE lt_exbilldoc INTO ls_exbilldoc
        WITH KEY exbilldocno = ls_response-exbilldocno.
      IF sy-subrc EQ 0.
        "Dokumnetumok feldolgozása - update
        PERFORM db_update USING    ls_stock
                                   ls_exbilldoc
                          CHANGING ls_response
                                   lv_stock_flag.
      ELSE.
        MESSAGE e030 WITH ls_response-exbilldocno INTO gv_dummy.
        PERFORM log_add_message.
      ENDIF.

    ENDLOOP. "LOOP AT ls_output-docs-d INTO lv_string.

*   Stock feloldása
    PERFORM stock_felold USING ls_stock
                               lv_stock_flag.

    MESSAGE s031 WITH ls_stock-stock_id INTO gv_dummy.
    PERFORM log_add_message.

  ENDLOOP. "LOOP AT gt_stock INTO ls_stock.


  PERFORM log_display.


ENDFORM.                    " PROCESSING
*&---------------------------------------------------------------------*
*&      Form  GET_INSPIRE_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM get_inspire_data
  USING    uv_stock_id  TYPE zebfd_pr_stock_id
           ut_exbilldoc TYPE tty_exbilldoc
  CHANGING cs_output TYPE zebf_pr_eon_forms_query_doc_d2.


  DATA: lv_id     TYPE string.
  DATA: ls_input  TYPE zebf_pr_eon_forms_query_doc_d3,
        ls_exbilldoc  TYPE ty_exbilldoc.
  DATA: lo_doc_status TYPE REF TO zebf_pr_co_eon_forms_query_doc.
  DATA: lr_sys_fail   TYPE REF TO cx_ai_system_fault,       "#EC NEEDED
        lr_app_fail   TYPE REF TO cx_ai_application_fault.  "#EC NEEDED


  TRY.
      CREATE OBJECT lo_doc_status
*        EXPORTING
*          logical_port_name  =
          .
    CATCH cx_ai_system_fault INTO lr_sys_fail.
*        lv_ex_txt = lr_sys_fail->get_text( ).
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO gv_dummy.
      PERFORM log_add_message.
*        ev_error = 'X'.
  ENDTRY.

  ls_input-sap_system  = sy-sysid.
  ls_input-sap_mandant = sy-mandt.
  ls_input-stock_id    = uv_stock_id.

  LOOP AT ut_exbilldoc INTO ls_exbilldoc.

    CLEAR lv_id.
    lv_id = ls_exbilldoc-exbilldocno.

    APPEND lv_id TO ls_input-docs-i.

  ENDLOOP.

  TRY.
      CALL METHOD lo_doc_status->eon_forms_query_doc_details
        EXPORTING
          input  = ls_input
        IMPORTING
          output = cs_output.
    CATCH cx_ai_system_fault INTO lr_sys_fail.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO gv_dummy.
      PERFORM log_add_message.
    CATCH cx_ai_application_fault INTO lr_app_fail.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO gv_dummy.
      PERFORM log_add_message.
  ENDTRY.



ENDFORM.                    " GET_INSPIRE_DATA
*&---------------------------------------------------------------------*
*&      Form  DB_UPDATE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM db_update
  USING us_stock TYPE ty_stock
        us_exbilldoc TYPE ty_exbilldoc
  CHANGING cs_response  TYPE ty_response
           cv_stock_flag TYPE flag.

  DATA: lv_update_hiba TYPE flag.


  IF us_exbilldoc-destination EQ 'PO' AND
     us_exbilldoc-tstmp_d IS INITIAL AND
     cs_response-tstmp_d IS NOT INITIAL.
    PERFORM upd_eszla   USING    us_exbilldoc
                                 cs_response
                        CHANGING lv_update_hiba.
  ENDIF.

  IF NOT cs_response-error_code IS INITIAL.
    PERFORM upd_terti USING us_exbilldoc
                            cs_response
                      CHANGING lv_update_hiba.
  ENDIF.

  IF us_exbilldoc-tstmp_s IS INITIAL AND
     cs_response-tstmp_s IS NOT INITIAL.
    PERFORM upd_bc_stat USING    us_exbilldoc
                        CHANGING cs_response
                                 lv_update_hiba.
  ENDIF.

  IF us_exbilldoc-tstmp_a IS INITIAL AND
     cs_response-tstmp_a  IS NOT INITIAL.
    PERFORM upd_archlink USING    us_exbilldoc
                         CHANGING cs_response
                                  lv_update_hiba.
  ENDIF.

  IF us_exbilldoc-tstmp_a IS INITIAL AND
     cs_response-tstmp_a  IS NOT INITIAL .
    PERFORM upd_push_msg USING    us_exbilldoc
                         CHANGING cs_response
                                  lv_update_hiba.
  ENDIF.


*  IF us_exbilldoc-destination EQ 'PR'.
  PERFORM upd_slog USING    us_stock
                            us_exbilldoc
                            cs_response
                   CHANGING lv_update_hiba.
*  ENDIF.

* ZPR_SLOG2 frissítése
* Ha valahol nme sikerült módosítani,
* akkor nem állíthatjuk készre
  IF lv_update_hiba EQ abap_false.
    PERFORM upd_slog2 USING us_exbilldoc
                            cs_response.
  ELSE.
*   ha van ilyen akkor nem zárhatjuk le a stock-ot
    cv_stock_flag = abap_true.
  ENDIF.
  IF cs_response-tstmp_d    IS INITIAL AND
     cs_response-error_code IS INITIAL .
*     ha van ilyen akkor nem zárhatjuk le a stock-ot
    cv_stock_flag = abap_true.
  ENDIF.


ENDFORM.                    " DB_UPDATE
*&---------------------------------------------------------------------*
*&      Form  STOCK_ZAR
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_L  text
*----------------------------------------------------------------------*
FORM stock_zar
  USING us_stock TYPE ty_stock
  CHANGING cv_hiba TYPE flag.

  MESSAGE s003 WITH us_stock-stock_id INTO gv_dummy.
  PERFORM log_add_message.

  CLEAR cv_hiba.

  CALL FUNCTION 'ENQUEUE_EZEBFT_PR_STOCK'
    EXPORTING
      mode_zebft_pr_stock = 'E'
      mandt               = sy-mandt
      stock_id            = us_stock-stock_id
*     X_STOCK_ID          = ' '
      _scope              = '2'
*     _WAIT               = ' '
*     _COLLECT            = ' '
    EXCEPTIONS
      foreign_lock        = 1
      system_failure      = 2
      OTHERS              = 3.
  IF sy-subrc NE 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                         WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO gv_dummy.
    PERFORM log_add_message.

    cv_hiba = abap_true.

  ENDIF.



ENDFORM.                    " STOCK_ZAR


*&---------------------------------------------------------------------*
*&      Form  LOG_CREATE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM log_create .

  DATA: ls_log        TYPE bal_s_log.    "Log header data
* DEFINE SOME HEADER DATA OF THIS LOG
  CONCATENATE sy-datum sy-uzeit
    INTO ls_log-extnumber SEPARATED BY '_'. "  = p_stokid.
  ls_log-object     = 'ZEBF_PR'.
  ls_log-subobject  = 'ZSTOCK_ST'.
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

  IF sy-batch IS INITIAL.
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
  ENDIF.

ENDFORM.                    "log_display
*&---------------------------------------------------------------------*
*&      Form  STOCK_FELOLD
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM stock_felold
  USING us_stock TYPE ty_stock
        uv_stock_flag TYPE flag.

  "Stock lezárható
  IF uv_stock_flag EQ abap_false.

    UPDATE zebft_pr_stock SET stock_status = 'D'
     WHERE stock_id EQ us_stock-stock_id.

    IF sy-subrc EQ 0.
      COMMIT WORK.
    ELSE.
      ROLLBACK WORK.
      MESSAGE e028 WITH 'ZEBFT_PR_STOCK' us_stock-stock_id INTO gv_dummy.
      PERFORM log_add_message.
    ENDIF.

  ENDIF.


* Stock zárolását kivesszük a végén
  CALL FUNCTION 'DEQUEUE_EZEBFT_PR_STOCK'
    EXPORTING
      mode_zebft_pr_stock = 'E'
      mandt               = sy-mandt
      stock_id            = us_stock-stock_id.


ENDFORM.                    " STOCK_FELOLD
*&---------------------------------------------------------------------*
*&      Form  UPD_ESZLA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM upd_eszla
  USING us_exbilldoc TYPE ty_exbilldoc
        us_response  TYPE ty_response                       "#EC NEEDED
  CHANGING cv_hiba TYPE flag.

  DATA: ls_zxwebt_eszla_log TYPE zxwebt_eszla_log,
        ls_eszla_log        TYPE zxwebt_eszla_log.

  ls_zxwebt_eszla_log-opbel = us_exbilldoc-opbel.
  ls_zxwebt_eszla_log-status = '3'.
  ls_zxwebt_eszla_log-aedat = sy-datum.
  ls_zxwebt_eszla_log-aezet = sy-uzeit.


  CALL FUNCTION 'ENQUEUE_EZXWEBT_ESZLA_LO'
    EXPORTING
      mode_zxwebt_eszla_log = 'E'
      mandt                 = sy-mandt
      opbel                 = ls_zxwebt_eszla_log-opbel
*     X_OPBEL               = ' '
*     _SCOPE                = '2'
*     _WAIT                 = ' '
*     _COLLECT              = ' '
    EXCEPTIONS
      foreign_lock          = 1
      system_failure        = 2
      OTHERS                = 3.
  IF sy-subrc NE 0.
    MESSAGE e028 WITH 'ZXWEBT_ESZLA_LO' ls_zxwebt_eszla_log-opbel INTO gv_dummy.
    PERFORM log_add_message.
    cv_hiba = abap_true.

  ELSE.
    CLEAR ls_eszla_log.
    SELECT SINGLE * FROM zxwebt_eszla_log
      INTO ls_eszla_log
     WHERE opbel EQ ls_zxwebt_eszla_log-opbel.
    IF sy-subrc EQ 0.
      UPDATE zxwebt_eszla_log SET status = ls_zxwebt_eszla_log-status
                                  aedat  = ls_zxwebt_eszla_log-aedat
                                  aezet  = ls_zxwebt_eszla_log-aezet
       WHERE opbel EQ ls_zxwebt_eszla_log-opbel.
    ELSE.
      ls_zxwebt_eszla_log-erdat = sy-datum.
      ls_zxwebt_eszla_log-erzet = sy-uzeit.
      MODIFY zxwebt_eszla_log FROM ls_zxwebt_eszla_log.
    ENDIF.

    IF sy-subrc = 0.
      COMMIT WORK.
    ELSE.
      MESSAGE e028 WITH 'ZXWEBT_ESZLA_LO' ls_zxwebt_eszla_log-opbel INTO gv_dummy.
      PERFORM log_add_message.
      ROLLBACK WORK.
      cv_hiba = abap_true.
    ENDIF.

    CALL FUNCTION 'DEQUEUE_EZXWEBT_ESZLA_LO'
      EXPORTING
        opbel = ls_zxwebt_eszla_log-opbel.
  ENDIF.


ENDFORM.                    " UPD_ESZLA
*&---------------------------------------------------------------------*
*&      Form  UPD_TERTI
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM upd_terti
  USING us_exbilldoc TYPE ty_exbilldoc
        us_response  TYPE ty_response                       "#EC NEEDED
  CHANGING cv_hiba   TYPE flag.

  DATA: ls_pr_terti TYPE zpr_terti,
        lv_f064_count TYPE i,
        lv_terti_count TYPE i.

  CLEAR ls_pr_terti.
  SELECT SINGLE * FROM zpr_terti                            "#EC WARNOK
    INTO ls_pr_terti
   WHERE envelope_id EQ us_exbilldoc-envelope
     AND exbilldocno EQ us_exbilldoc-exbilldocno.
  IF sy-subrc EQ 0.

    DELETE FROM zpr_terti
     WHERE envelope_id EQ ls_pr_terti-envelope_id
       AND exbilldocno EQ ls_pr_terti-exbilldocno.
    IF sy-subrc EQ 0.
      COMMIT WORK.
    ELSE.
      MESSAGE e028 WITH 'ZPR_TERTI' us_exbilldoc-exbilldocno INTO gv_dummy.
      PERFORM log_add_message.
      ROLLBACK WORK.
      cv_hiba = abap_true.
    ENDIF.

    " If we have more than one documents in the envelope for
    " the same regmail number, we need to delete everything at first
    " from zisu_f064 and than live it as it is.
    SELECT COUNT( * ) FROM zisu_f064
      INTO lv_f064_count
      WHERE zisu_ragszam EQ ls_pr_terti-zisu_ragszam_128.

    SELECT COUNT( * ) FROM zpr_terti
      INTO lv_terti_count
      WHERE zisu_ragszam_128 EQ ls_pr_terti-zisu_ragszam_128.

    " csak akkor töröljük, ha már nincs több rekord a ragszámhoz a zpr_terti táblában
    IF lv_f064_count GT 0 AND lv_terti_count EQ 0.
      DELETE FROM zisu_f064
        WHERE zisu_ragszam EQ ls_pr_terti-zisu_ragszam_128.
      IF sy-subrc EQ 0.
        COMMIT WORK.
      ELSE.
        MESSAGE e028 WITH 'zisu_f064' us_exbilldoc-exbilldocno INTO gv_dummy.
        PERFORM log_add_message.
        ROLLBACK WORK.
        cv_hiba = abap_true.
      ENDIF.
    ENDIF.
  ENDIF.
ENDFORM.                   " UPD_TERTI
*&---------------------------------------------------------------------*
*&      Form  UPD_BC_STAT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM upd_bc_stat
  USING us_exbilldoc TYPE ty_exbilldoc
  CHANGING cs_response  TYPE ty_response
           cv_hiba TYPE flag.

  DATA: lv_doctype TYPE  zebid_bc_doc_type,
        lv_docid  TYPE  zebid_bc_doc_id,
        lv_sdate  TYPE  zebid_bc_sdate,
        lv_stime  TYPE  zebid_bc_stime.


  lv_docid = us_exbilldoc-opbel.
  IF us_exbilldoc-doc_type EQ '0042'. "OR
*     <fs_exbilldocno>-doc_type EQ '0044'. "SZÁMLÁK
    lv_doctype = zif_ebf_pr_const=>gc_bc_stat_doctype-_sn.
  ELSE.
    lv_doctype = zif_ebf_pr_const=>gc_bc_stat_doctype-_en.
  ENDIF.
  lv_sdate  = cs_response-tstmp_s(8).
  lv_stime  = cs_response-tstmp_s+8(6).


  CALL FUNCTION 'Z_EBI_BILL_CERT_SAVE_STAT'
    EXPORTING
      iv_doctype               = lv_doctype
      iv_docid                 = lv_docid "opbel
      iv_sdate                 = lv_sdate
      iv_stime                 = lv_stime
      iv_bukrs                 = us_exbilldoc-bukrs
      iv_sparte                = us_exbilldoc-sparte
      iv_check_par_valid       = space
*     IV_COMMIT                = ' '      ?????????????????????
      iv_status                = '3'
*     IV_GUID                  =
*   IMPORTING
*     EV_GUID                  =
   EXCEPTIONS
     missing_doctype          = 1
     missing_docid            = 2
     missing_bukrs            = 3
     invalid_doctype          = 4
     invalid_pack             = 5
     invalid_opbel            = 6
     invalid_bukrs            = 7
     invalid_sparte           = 8
     save_failed              = 9
     invalid_guid             = 10
     enqueue_error            = 11
     OTHERS                   = 12
            .
  IF sy-subrc = 0.
    COMMIT WORK.
  ELSE.
    MESSAGE e028 WITH 'ZEBIT_BC_STAT' lv_docid INTO gv_dummy.
    PERFORM log_add_message.
    ROLLBACK WORK.
    cv_hiba = abap_true.
    CLEAR cs_response-tstmp_s.
  ENDIF.


ENDFORM.                    " UPD_BC_STAT
*&---------------------------------------------------------------------*
*&      Form  UPD_ARCHLINK
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM upd_archlink
  USING us_exbilldoc TYPE ty_exbilldoc
  CHANGING cs_response  TYPE ty_response
           cv_hiba TYPE flag.

  DATA: ls_db_archlink    TYPE zebf_pr_archlink.


  SELECT SINGLE * FROM zebf_pr_archlink
    INTO ls_db_archlink
   WHERE exbilldocno EQ us_exbilldoc-exbilldocno.

  IF sy-subrc EQ 0.

    IF cs_response-error_code IS INITIAL.

      CALL FUNCTION 'ARCHIV_CONNECTION_INSERT'              "#EC *
        EXPORTING
          arc_doc_id            = ls_db_archlink-xsapdocid
          ar_object             = ls_db_archlink-xsapdocumenttype
          object_id             = ls_db_archlink-xsapobjectid
          sap_object            = ls_db_archlink-xsapobject
        EXCEPTIONS
          error_connectiontable = 1.

      IF sy-subrc NE 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO gv_dummy.
        PERFORM log_add_message.
        cv_hiba = abap_true.
        CLEAR cs_response-tstmp_a.
      ELSE.

        DELETE FROM zebf_pr_archlink
         WHERE exbilldocno EQ ls_db_archlink-exbilldocno.

      ENDIF.

    ELSE.

      DELETE FROM zebf_pr_archlink
       WHERE exbilldocno EQ ls_db_archlink-exbilldocno.

    ENDIF.

  ENDIF.



ENDFORM.                    " UPD_ARCHLINK
*&---------------------------------------------------------------------*
*&      Form  UPD_SLOG
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM upd_slog
  USING us_stock     TYPE ty_stock
        us_exbilldoc TYPE ty_exbilldoc
        us_response  TYPE ty_response
  CHANGING cv_hiba TYPE flag.

  DATA: lv_prdspool TYPE zedmd_prdspool,
        lv_prdfile  TYPE zedmd_prdfile,
        lv_prdstock	TYPE syprdsn.
  DATA: ls_tags TYPE ty_fajl.


  CALL FUNCTION 'ENQUEUE_EZPR_SLOG'
    EXPORTING
      mode_zpr_slog  = 'E'
      mandt          = sy-mandt
      opbel          = us_exbilldoc-opbel
      fccnu          = us_exbilldoc-fccnu
      extnu          = us_exbilldoc-extnu
      doc_type       = us_exbilldoc-doc_type
*     X_OPBEL        = ' '
*     X_FCCNU        = ' '
*     X_EXTNU        = ' '
*     X_DOC_TYPE     = ' '
      _scope         = '2'
*     _WAIT          = ' '
*     _COLLECT       = ' '
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc NE 0.
    MESSAGE e028 WITH 'ZPR_SLOG' us_exbilldoc-opbel INTO gv_dummy.
    PERFORM log_add_message.
    cv_hiba = abap_true.
    EXIT.
  ENDIF.

  SPLIT us_response-filename AT '_'
    INTO
         ls_tags-1
         ls_tags-2
         ls_tags-3
         ls_tags-4
         ls_tags-5
         ls_tags-6
         ls_tags-7
         ls_tags-8
         ls_tags-9
         ls_tags-10.

  IF ls_tags-6 IS INITIAL.
* Elektronikus ágon nem fájl
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
      EXPORTING
        input  = us_stock-stock_id
      IMPORTING
        output = lv_prdstock.
    UPDATE zpr_slog SET prdstock = lv_prdstock
        WHERE opbel       = us_exbilldoc-opbel
          AND fccnu       = us_exbilldoc-fccnu
          AND extnu       = us_exbilldoc-extnu
          AND doc_type    = us_exbilldoc-doc_type.
  ELSE.
    IF us_exbilldoc-destination EQ 'IN'. "AALAPNYOMAT
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
        EXPORTING
          input  = ls_tags-8
        IMPORTING
          output = lv_prdstock.
      CONCATENATE lv_prdstock '_' ls_tags-9 INTO lv_prdspool.
      UPDATE zpr_slog SET prdstock = lv_prdstock
                          prdspool = lv_prdspool
          WHERE opbel       = us_exbilldoc-opbel
            AND fccnu       = us_exbilldoc-fccnu
            AND extnu       = us_exbilldoc-extnu
            AND doc_type    = us_exbilldoc-doc_type.
    ELSE.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
        EXPORTING
          input  = ls_tags-6
        IMPORTING
          output = lv_prdstock.
      CONCATENATE lv_prdstock '_' ls_tags-7 INTO lv_prdspool.
      CONCATENATE us_exbilldoc-doc_cat '_' ls_tags-8 INTO lv_prdfile.
      UPDATE zpr_slog SET prdstock = lv_prdstock
                          prdspool = lv_prdspool
                          prdfile  = lv_prdfile
          WHERE opbel       = us_exbilldoc-opbel
            AND fccnu       = us_exbilldoc-fccnu
            AND extnu       = us_exbilldoc-extnu
            AND doc_type    = us_exbilldoc-doc_type.
    ENDIF.
  ENDIF.

*
  IF sy-subrc  NE 0.
    MESSAGE e028 WITH 'ZPR_SLOG' us_exbilldoc-opbel INTO gv_dummy.
    PERFORM log_add_message.
    ROLLBACK WORK.
  ELSE.
    COMMIT WORK.
  ENDIF.

  CALL FUNCTION 'DEQUEUE_EZPR_SLOG'
    EXPORTING
      mode_zpr_slog = 'E'
      mandt         = sy-mandt
      opbel         = us_exbilldoc-opbel
      fccnu         = us_exbilldoc-fccnu
      extnu         = us_exbilldoc-extnu
      doc_type      = us_exbilldoc-doc_type.

ENDFORM.                    " UPD_SLOG
*&---------------------------------------------------------------------*
*&      Form  UPD_SLOG2
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM upd_slog2
  USING us_exbilldoc TYPE ty_exbilldoc
        us_response  TYPE ty_response.

  DATA: ls_slog2 TYPE zpr_slog2.

  MOVE-CORRESPONDING us_exbilldoc TO ls_slog2.              "#EC ENHOK

  CALL FUNCTION 'ENQUEUE_EZPR_SLOG2'
    EXPORTING
*     MODE_ZPR_SLOG2 = 'E'
*     MANDT          = SY-MANDT
      opbel          = ls_slog2-opbel
      fccnu          = ls_slog2-fccnu
      extnu          = ls_slog2-extnu
      doc_type       = ls_slog2-doc_type
*     X_OPBEL        = ' '
*     X_FCCNU        = ' '
*     X_EXTNU        = ' '
*     X_DOC_TYPE     = ' '
*     _SCOPE         = '2'
*     _WAIT          = ' '
*     _COLLECT       = ' '
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc NE 0.
    MESSAGE e028 WITH 'ZPR_SLOG2' ls_slog2-opbel INTO gv_dummy.
    PERFORM log_add_message.
    EXIT.
  ENDIF.

  MOVE-CORRESPONDING us_response TO ls_slog2.               "#EC ENHOK

  MODIFY zpr_slog2 FROM ls_slog2.

  IF sy-subrc EQ 0.
    COMMIT WORK.
  ELSE.
    MESSAGE e028 WITH 'ZPR_SLOG2' ls_slog2-opbel INTO gv_dummy.
    PERFORM log_add_message.
    ROLLBACK WORK.
  ENDIF.


  CALL FUNCTION 'DEQUEUE_EZPR_SLOG2'
    EXPORTING
*     MODE_ZPR_SLOG2 = 'E'
*     MANDT          = SY-MANDT
      opbel          = ls_slog2-opbel
      fccnu          = ls_slog2-fccnu
      extnu          = ls_slog2-extnu
      doc_type       = ls_slog2-doc_type
*     X_OPBEL        = ' '
*     X_FCCNU        = ' '
*     X_EXTNU        = ' '
*     X_DOC_TYPE     = ' '
*     _SCOPE         = '3'
*     _SYNCHRON      = ' '
*     _COLLECT       = ' '
    .

ENDFORM.                                                    " UPD_SLOG2
*&---------------------------------------------------------------------*
*&      Form  UPD_PUSH_MSG
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM upd_push_msg
  USING us_exbilldoc TYPE ty_exbilldoc
  CHANGING cs_response  TYPE ty_response                    "#EC NEEDED
           cv_hiba TYPE flag.                               "#EC NEEDED

  DATA: lv_fkart TYPE fkart,
        lv_ndockey     TYPE i,
        lv_dockey      TYPE vbeln.

* Csak számlák esetén fusson
  IF us_exbilldoc-doc_type EQ '0031' OR
     us_exbilldoc-doc_type EQ '0038' OR
     us_exbilldoc-doc_type EQ '0039'.

    CALL FUNCTION 'ZEBI_PUSH_MSG'                     "INC2735509 (Az eredeti függvény hívása.)
      EXPORTING
        iv_opbel             = us_exbilldoc-opbel
        iv_no_druckdat_check = 'X'.

  ELSEIF us_exbilldoc-doc_type EQ '0042'.

    CALL FUNCTION 'ZEBI_PUSH_MSG'                     "INC2735509 (Az eredeti függvény hívása.)
      EXPORTING
        iv_opbel             = us_exbilldoc-opbel
        iv_sd                = 'X'.

  ENDIF.

ENDFORM.                    " UPD_PUSH_MSG
*&---------------------------------------------------------------------*
*&      Form  LOG_ADD_RESPONSE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM log_add_response
  USING us_response TYPE ty_response.

  DATA: ls_msg       TYPE bapiret2.

  CONCATENATE 'Doc.:' us_response-exbilldocno
         INTO ls_msg-message_v1 SEPARATED BY space.

  CONCATENATE us_response-tstmp_r
              us_response-tstmp_c
              us_response-tstmp_b
         INTO ls_msg-message_v2 SEPARATED BY ';'.

  CONCATENATE us_response-tstmp_q
              us_response-tstmp_o
              us_response-tstmp_x
         INTO ls_msg-message_v3 SEPARATED BY ';'.

  CONCATENATE us_response-tstmp_p
              us_response-tstmp_l
              us_response-tstmp_g
         INTO ls_msg-message_v4 SEPARATED BY ';'.

  MESSAGE s000 WITH ls_msg-message_v1 ls_msg-message_v2 ls_msg-message_v3 ls_msg-message_v4
     INTO gv_dummy.
  PERFORM log_add_message.

  CONCATENATE us_response-tstmp_s
              us_response-tstmp_a
              us_response-tstmp_d
         INTO ls_msg-message_v1 SEPARATED BY ';'.

  CONCATENATE us_response-tstmp_e
              us_response-tstmp_v
         INTO ls_msg-message_v2 SEPARATED BY ';'.

  MESSAGE s000 WITH ls_msg-message_v1 ls_msg-message_v2
     INTO gv_dummy.
  PERFORM log_add_message.

ENDFORM.                    " LOG_ADD_RESPONSE
