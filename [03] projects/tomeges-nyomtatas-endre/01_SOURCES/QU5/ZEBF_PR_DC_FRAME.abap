***********************************************************************
* Report: ZEBF_PR_DC_FRAME
* Leírás: Data Control(DC) keretprogram
*
*--------------------------------------------------------------------
* Modulfelelos: <XY>
* --------------------------------------------------------------------
* Módosítások:
* <dátum>, <programozó>, <kérelem>, <comment azonosító>
*          <rövid leírás>
***********************************************************************
REPORT  zebf_pr_dc_frame.


TABLES: zebft_pr_dcqm.

TYPE-POOLS: abap.

TYPES: BEGIN OF ty_fname,
        file TYPE zebfd_pr_filename,
       END OF ty_fname.

DATA: gs_stock TYPE zebft_pr_stock.
* LOG
DATA: gv_log_handle TYPE balloghndl.   "Application Log: Log Handle

*----------------------------------------------------------------------*
* SELECTION-SCREEN -                                                   *
*----------------------------------------------------------------------*
SELECTION-SCREEN SKIP.
PARAMETERS: p_stokid TYPE zebfd_pr_stock_id
                     OBLIGATORY MATCHCODE OBJECT zebfh_pr_stock.
SELECTION-SCREEN SKIP.
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.
PARAMETERS: p_mod  TYPE flag RADIOBUTTON GROUP gr1,
            p_disp TYPE flag RADIOBUTTON GROUP gr1,
            p_eng  TYPE flag RADIOBUTTON GROUP gr1,
            p_engv TYPE flag RADIOBUTTON GROUP gr1.
SELECTION-SCREEN END OF BLOCK b01.

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

  CASE abap_true.
    WHEN p_mod.
      PERFORM run_report USING abap_true.
    WHEN p_disp.
      PERFORM run_report USING abap_false.
    WHEN p_eng.
      PERFORM release.
    WHEN p_engv.
      PERFORM release_back.
  ENDCASE.



*&---------------------------------------------------------------------*
*&      Form  CHECK_STOCKID
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM check_stockid .


  SELECT SINGLE * INTO gs_stock
    FROM zebft_pr_stock
   WHERE stock_id EQ p_stokid.

*A Stock ID nem létezik!
  IF sy-subrc NE 0.
    MESSAGE e020(zebf_pr).
  ENDIF.

  IF p_mod EQ abap_true.

    IF gs_stock-closed EQ abap_true.
      CLEAR: p_mod, p_eng, p_engv.
      p_disp = abap_true.
      MESSAGE i021(zebf_pr).
    ENDIF.

    IF gs_stock-dccompl EQ abap_true.
      CLEAR: p_mod, p_eng, p_engv.
      MESSAGE e048(zebf_pr)  .
    ENDIF.
  ENDIF.

  IF p_engv EQ abap_true OR p_eng EQ abap_true.
    IF gs_stock-closed EQ abap_true.
      MESSAGE e021(zebf_pr) DISPLAY LIKE 'I'.
    ENDIF.
  ENDIF.

ENDFORM.                    " CHECK_STOCKID
*&---------------------------------------------------------------------*
*&      Form  RUN_REPORT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM run_report
  USING uv_modif TYPE flag.


  IF gs_stock-closed EQ abap_true AND
     uv_modif        EQ abap_true.
    MESSAGE i021(zebf_pr).
  ENDIF.

  SUBMIT zebf_pr_dcqm_report VIA SELECTION-SCREEN
                WITH p_stokid EQ p_stokid
                WITH p_modif  EQ uv_modif
                AND RETURN.

ENDFORM.                    " RUN_REPORT
*&---------------------------------------------------------------------*
*&      Form  RELEASE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM release .

  DATA: lv_dummy  TYPE string.


  IF gs_stock-dccompl EQ abap_true.
    MESSAGE i026(zebf_pr).
    EXIT.
  ENDIF.

* Stock ID zár ellenőrzése
  PERFORM check_lock.

  PERFORM log_create.


  UPDATE zebft_pr_stock SET dccompl   = abap_true
*                            erdat_clo = sy-datum
*                            ernam_clo = sy-uname
*                            ertim_clo = sy-uzeit
   WHERE stock_id EQ p_stokid.

  IF sy-subrc EQ 0.
    COMMIT WORK.
    MESSAGE s027(zebf_pr) INTO lv_dummy.
  ELSE.
    ROLLBACK WORK.
    MESSAGE s028(zebf_pr) INTO lv_dummy.
  ENDIF.
  PERFORM log_add_message.

  PERFORM get_count.

  PERFORM log_display.


  CALL FUNCTION 'DEQUEUE_EZEBFT_PR_STOCK'
    EXPORTING
*     MODE_ZEBFT_PR_STOCK       = 'E'
*     MANDT                     = SY-MANDT
      stock_id                  = p_stokid
*     X_STOCK_ID                = ' '
*     _SCOPE                    = '3'
*     _SYNCHRON                 = ' '
*     _COLLECT                  = ' '
            .


ENDFORM.                    " RELEASE
*&---------------------------------------------------------------------*
*&      Form  CHECK_LOCK
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM check_lock .

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
*&---------------------------------------------------------------------*
*&      Form  RELEASE_BACK
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM release_back .

  DATA: lv_dummy  TYPE string.


  IF gs_stock-dccompl EQ abap_false.
    MESSAGE i031(zebf_pr).
    EXIT.
  ENDIF.

* Stock ID zár ellenőrzése
  PERFORM check_lock.

  PERFORM log_create.


  UPDATE zebft_pr_stock SET dccompl = abap_false
   WHERE stock_id EQ p_stokid.

  IF sy-subrc EQ 0.
    COMMIT WORK.
    MESSAGE s032(zebf_pr) INTO lv_dummy.
  ELSE.
    ROLLBACK WORK.
    MESSAGE s033(zebf_pr) INTO lv_dummy.
  ENDIF.
  PERFORM log_add_message.

  PERFORM get_count.

  PERFORM log_display.


  CALL FUNCTION 'DEQUEUE_EZEBFT_PR_STOCK'
    EXPORTING
*     MODE_ZEBFT_PR_STOCK       = 'E'
*     MANDT                     = SY-MANDT
      stock_id                  = p_stokid
*     X_STOCK_ID                = ' '
*     _SCOPE                    = '3'
*     _SYNCHRON                 = ' '
*     _COLLECT                  = ' '
            .

ENDFORM.                    " RELEASE_BACK
*&---------------------------------------------------------------------*
*&      Form  GET_COUNT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM get_count .

  DATA: lv_kizart TYPE i,
        lv_enged  TYPE i,
        lv_dummy  TYPE string.
  DATA: ls_dcqm  TYPE zebft_pr_dcqm.
  DATA: lt_dcqm  TYPE STANDARD TABLE OF zebft_pr_dcqm,
        lt_files TYPE STANDARD TABLE OF ty_fname.

  SELECT filename INTO TABLE lt_files
    FROM zebft_pr_mssfile
   WHERE stock_id EQ p_stokid.

  IF NOT lt_files IS INITIAL.
    SELECT * FROM zebft_pr_dcqm
      INTO TABLE lt_dcqm
      FOR ALL ENTRIES IN lt_files
    WHERE filename EQ lt_files-file.
  ENDIF.

  LOOP AT lt_dcqm INTO ls_dcqm.
    IF NOT ls_dcqm-block_dc IS INITIAL.
      ADD 1 TO lv_kizart.
    ELSE.
      ADD 1 TO lv_enged.
    ENDIF.
  ENDLOOP.
  MESSAGE s029(zebf_pr) WITH lv_enged INTO lv_dummy.
  PERFORM log_add_message.
  MESSAGE s030(zebf_pr) WITH lv_kizart INTO lv_dummy.
  PERFORM log_add_message.


ENDFORM.                    " GET_COUNT