class ZCL_PR_LOG definition
  public
  create public .

public section.

  data GV_LONG_MESSAGE type STRING .

  methods CONSTRUCTOR
    importing
      value(IV_LOG_OBJECT) type BALOBJ_D optional
      value(IV_LOG_SUBOBJECT) type BALSUBOBJ optional
      value(IV_EXT_ID) type CLIKE optional .
  methods ADD_SYSTEM_MESSAGE .
  methods ADD_LONG_MESSAGE
    importing
      !IV_LONG_MESSAGE type STRING .
  methods CLOSE .
  methods DISPLAY .
protected section.

  data GV_LOG_HANDLE type BALLOGHNDL .
  data GV_DUMMY_MESSAGE type CHAR1 .
private section.
ENDCLASS.



CLASS ZCL_PR_LOG IMPLEMENTATION.


  METHOD add_system_message.

    DATA ls_msg           TYPE bal_s_msg.

    ls_msg-msgid = sy-msgid.
    ls_msg-msgno = sy-msgno.
    ls_msg-msgty = sy-msgty.
    ls_msg-msgv1 = sy-msgv1.
    ls_msg-msgv2 = sy-msgv2.
    ls_msg-msgv3 = sy-msgv3.
    ls_msg-msgv4 = sy-msgv4.

    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle     = gv_log_handle
        i_s_msg          = ls_msg
      EXCEPTIONS
        log_not_found    = 1
        msg_inconsistent = 2
        log_is_full      = 3
        OTHERS           = 4.
    if sy-subrc ne 0.
      if 1 = 2. endif.
* Do nothing
    endif.

  ENDMETHOD.


  METHOD close.

    DATA:
        lt_log_handles   TYPE bal_t_logh.

    INSERT gv_log_handle INTO TABLE lt_log_handles.

    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle   = lt_log_handles[]
        i_in_update_task = abap_true
      EXCEPTIONS
        log_not_found    = 1
        save_not_allowed = 2
        numbering_error  = 3
        OTHERS           = 4.
    IF sy-subrc <> 0.
      MESSAGE e000 INTO gv_dummy_message.
    ENDIF.
    COMMIT WORK.

  ENDMETHOD.


  METHOD constructor.

    DATA: ls_log_header_create TYPE bal_s_log.

    ls_log_header_create-object    = iv_log_object.
    ls_log_header_create-subobject = iv_log_subobject.
    ls_log_header_create-alprog    = sy-repid.

    IF iv_ext_id IS NOT INITIAL.
      ls_log_header_create-extnumber = iv_ext_id.
    ELSE.
      CONCATENATE sy-datum sy-uzeit INTO ls_log_header_create-extnumber.
    ENDIF.

    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log                 = ls_log_header_create
      IMPORTING
        e_log_handle            = gv_log_handle
      EXCEPTIONS
        log_header_inconsistent = 1
        OTHERS                  = 2.
    IF sy-subrc NE 0.
    ENDIF.


  ENDMETHOD.


  METHOD display.
    DATA:
       lt_log_handles   TYPE bal_t_logh.

    INSERT gv_log_handle INTO TABLE lt_log_handles.

    CALL FUNCTION 'BAL_DSP_LOG_DISPLAY'
      EXPORTING
        i_t_log_handle       = lt_log_handles[]
      EXCEPTIONS
        profile_inconsistent = 1
        internal_error       = 2
        no_data_available    = 3
        no_authority         = 4
        OTHERS               = 5.

    CHECK sy-subrc IS NOT INITIAL.
  ENDMETHOD.


  METHOD add_long_message.

    DATA: ls_msg  TYPE bal_s_msg,
          lt_text TYPE TABLE OF char50,
          lv_text TYPE char50.

    ls_msg-msgid = sy-msgid.
    ls_msg-msgno = sy-msgno.
    ls_msg-msgty = sy-msgty.
    ls_msg-msgv1 = sy-msgv1.
    ls_msg-msgv2 = sy-msgv2.
    ls_msg-msgv3 = sy-msgv3.
    ls_msg-msgv4 = sy-msgv4.

    IF NOT iv_long_message IS INITIAL.
      gv_long_message = iv_long_message.
    ENDIF.

    IF NOT gv_long_message IS INITIAL.
      CALL FUNCTION 'SWA_STRING_TO_TABLE'
        EXPORTING
          character_string           = gv_long_message
*         APPEND                     = ' '
*         LINE_SIZE                  =
*         CHECK_TABLE_TYPE           = ' '
        IMPORTING
          character_table            = lt_text
*         TOTAL_LENGTH               =
*         LINE_SIZE_USED             =
*         LINES_FILLED               =
*         LAST_LINE_LENGTH           =
        EXCEPTIONS
          no_flat_charlike_structure = 1
          OTHERS                     = 2.
      IF sy-subrc EQ 0.
        IF 1 = 2.
        ENDIF.
      ENDIF.
      LOOP AT lt_text INTO lv_text.
        CASE sy-tabix.
          WHEN 1.
            ls_msg-msgv1  = lv_text.
          WHEN 2.
            ls_msg-msgv2  = lv_text.
          WHEN 3.
            ls_msg-msgv3  = lv_text.
          WHEN 4.
            ls_msg-msgv4  = lv_text.
        ENDCASE.
      ENDLOOP.

      CLEAR gv_long_message.
    ENDIF.


    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle     = gv_log_handle
        i_s_msg          = ls_msg
      EXCEPTIONS
        log_not_found    = 1
        msg_inconsistent = 2
        log_is_full      = 3
        OTHERS           = 4.
    IF sy-subrc NE 0.
      IF 1 = 2. ENDIF.
* Do nothing
    ENDIF.

  ENDMETHOD.
ENDCLASS.