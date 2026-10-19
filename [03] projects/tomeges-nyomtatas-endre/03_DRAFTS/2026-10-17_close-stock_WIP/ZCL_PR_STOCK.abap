class ZCL_PR_STOCK definition
  public
  create public .

public section.

  class-methods CHECK_STATUS
    importing
      !IV_NEW_STATUS type ZPRD_STOCK_STATUS
      !IV_OLD_STATUS type ZPRD_STOCK_STATUS
      !IV_DIR type CHAR1 .
  class-methods GET_STOCK_HEADER
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
    returning
      value(RS_STOCK_DATA) type ZPRS_COCKPIT_HEADER .
  class-methods UPDATE_STATUS
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
      !IV_NEW_STATUS type ZPRD_STOCK_STATUS .
  class-methods CLOSE_STOCK
    importing
      !IV_STOCK type ZPRD_STOCK_ID
      !IV_PRIORITY type ZPRD_PRIORITY optional
      !IV_LOCK_HELD type ABAP_BOOL default ABAP_FALSE
      !IV_DISPLAY_LOG type ABAP_BOOL default ABAP_TRUE
    exporting
      !EV_SUCCESS type ABAP_BOOL
      !EV_UNCERTAIN type ABAP_BOOL
      !ET_MESSAGES type BAL_T_MSG .
protected section.

  class-data GV_DUMMY_MESSAGE type CHAR1 .
private section.
  TYPES: ty_alv_table TYPE STANDARD TABLE OF zprs_dcqm_report WITH DEFAULT KEY,
         BEGIN OF ty_regmail,
           envelope_id TYPE zprt_dcqm-envelope,
           exbilldocno TYPE zprt_dcqm-doc_no,
           zisu_ragszam_128 TYPE zprt_dcqm-regmailnumber,
         END OF ty_regmail,
         ty_regmail_table TYPE STANDARD TABLE OF ty_regmail WITH DEFAULT KEY.
  CONSTANTS: gc_terti_table TYPE tabname VALUE 'ZPR_TERTI',
             gc_f064_table TYPE tabname VALUE 'ZISU_F064',
             gc_status_qm TYPE zprd_stock_status VALUE 'QM',
             gc_status_closed TYPE zprd_stock_status VALUE 'CL',
             gc_log_object TYPE balobj_d VALUE 'ZPR_MASS',
             gc_log_subobject TYPE balsubobj VALUE 'STOCK'.
  CLASS-METHODS check_regmail_tables
    EXPORTING ev_error TYPE abap_bool
    CHANGING ct_messages TYPE bal_t_msg.
  CLASS-METHODS prepare_regmail
    IMPORTING it_alv TYPE ty_alv_table
    EXPORTING et_regmail TYPE ty_regmail_table ev_error TYPE abap_bool
    CHANGING ct_messages TYPE bal_t_msg.
  CLASS-METHODS send_priority
    IMPORTING iv_stock TYPE zprd_stock_id iv_priority TYPE zprd_priority
              it_alv TYPE ty_alv_table
    EXPORTING ev_error TYPE abap_bool ev_call_started TYPE abap_bool
              ev_remote_success TYPE abap_bool ev_uncertain TYPE abap_bool
    CHANGING ct_messages TYPE bal_t_msg.
  CLASS-METHODS save_release
    IMPORTING iv_stock TYPE zprd_stock_id iv_priority TYPE zprd_priority
              it_alv TYPE ty_alv_table it_regmail TYPE ty_regmail_table
    EXPORTING ev_error TYPE abap_bool ev_saved TYPE abap_bool
              ev_uncertain TYPE abap_bool
    CHANGING ct_messages TYPE bal_t_msg.
  CLASS-METHODS mark_uncertain_state
    IMPORTING iv_stock TYPE zprd_stock_id
    CHANGING ct_messages TYPE bal_t_msg.
  CLASS-METHODS add_message
    IMPORTING iv_type TYPE symsgty iv_text TYPE clike
              iv_value1 TYPE clike OPTIONAL iv_value2 TYPE clike OPTIONAL
    CHANGING ct_messages TYPE bal_t_msg.
  CLASS-METHODS add_exception
    IMPORTING ir_error TYPE REF TO cx_root
    CHANGING ct_messages TYPE bal_t_msg.
  CLASS-METHODS write_log
    IMPORTING it_messages TYPE bal_t_msg
    EXPORTING ev_log_error TYPE abap_bool.
ENDCLASS.



CLASS ZCL_PR_STOCK IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PR_STOCK=>CLOSE_STOCK
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_STOCK                       TYPE        ZPRD_STOCK_ID
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD close_stock.
    DATA: ls_stock TYPE zprt_stock,
          lt_alv TYPE ty_alv_table,
          lt_regmail TYPE ty_regmail_table,
          lt_fields TYPE STANDARD TABLE OF sval,
          ls_field TYPE sval,
          lv_return TYPE c LENGTH 1,
          lv_priority TYPE zprd_priority,
          lv_own_lock TYPE abap_bool,
          lv_error TYPE abap_bool,
          lv_call_started TYPE abap_bool,
          lv_remote_success TYPE abap_bool,
          lv_log_error TYPE abap_bool,
          lv_total TYPE i,
          lv_excluded TYPE i,
          lv_allowed TYPE i,
          lv_number TYPE c LENGTH 20,
          lr_error TYPE REF TO cx_root.

    CLEAR: ev_success, ev_uncertain.
    REFRESH et_messages.
    TRY.
        DO 1 TIMES.
          "The caller retains a supplied dialog lock; otherwise this method owns it.
          IF iv_lock_held <> abap_true.
            CALL FUNCTION 'ENQUEUE_EZPRT_STOCK'
              EXPORTING stock_id = iv_stock _scope = '1'
              EXCEPTIONS foreign_lock = 1 system_failure = 2 OTHERS = 3.
            IF sy-subrc <> 0.
              add_message( EXPORTING iv_type = 'E'
                iv_text = text-101
                iv_value1 = iv_stock iv_value2 = sy-msgv1
                CHANGING ct_messages = et_messages ).
              EXIT.
            ENDIF.
            lv_own_lock = abap_true.
          ENDIF.

          SELECT SINGLE * FROM zprt_stock BYPASSING BUFFER INTO ls_stock
            WHERE stock_id = iv_stock.
          IF sy-subrc <> 0.
            add_message( EXPORTING iv_type = 'E' iv_text = text-102
              iv_value1 = iv_stock CHANGING ct_messages = et_messages ).
            EXIT.
          ENDIF.
          IF ls_stock-closed IS NOT INITIAL OR ls_stock-status <> gc_status_qm
             OR ls_stock-stock_status_er IS NOT INITIAL.
            add_message( EXPORTING iv_type = 'E'
              iv_text = text-103
              iv_value1 = iv_stock CHANGING ct_messages = et_messages ).
            EXIT.
          ENDIF.

          IF iv_priority IS SUPPLIED.
            lv_priority = iv_priority.
          ELSE.
            ls_field-tabname = 'ZPRT_STOCK'.
            ls_field-fieldname = 'PRIORITY'.
            IF ls_stock-priority IS INITIAL.
              ls_field-value = '30'.
            ELSE.
              ls_field-value = ls_stock-priority.
            ENDIF.
            ls_field-field_obl = abap_true.
            APPEND ls_field TO lt_fields.
            CALL FUNCTION 'POPUP_GET_VALUES'
              EXPORTING popup_title = text-104
              IMPORTING returncode = lv_return
              TABLES fields = lt_fields
              EXCEPTIONS error_in_fields = 1 OTHERS = 2.
            IF sy-subrc <> 0 OR lv_return = 'A'.
              EXIT.
            ENDIF.
            READ TABLE lt_fields INTO ls_field INDEX 1.
            IF sy-subrc <> 0.
              EXIT.
            ENDIF.
            lv_priority = ls_field-value.
          ENDIF.
          IF lv_priority IS INITIAL.
            add_message( EXPORTING iv_type = 'E' iv_text = text-105
              CHANGING ct_messages = et_messages ).
            EXIT.
          ENDIF.

          SELECT COUNT(*) FROM zprt_dcqm INTO lv_total
            WHERE prd_stock_id = iv_stock.
          IF lv_total = 0.
            add_message( EXPORTING iv_type = 'E' iv_text = text-106
              iv_value1 = iv_stock CHANGING ct_messages = et_messages ).
            EXIT.
          ENDIF.
          SELECT * FROM zprt_dcqm INTO CORRESPONDING FIELDS OF TABLE lt_alv
            WHERE prd_stock_id = iv_stock
              AND ( block_dc <> space OR block_qm <> space ).
          SORT lt_alv BY doc_no envelope.
          DESCRIBE TABLE lt_alv LINES lv_excluded.
          lv_allowed = lv_total - lv_excluded.

          prepare_regmail( EXPORTING it_alv = lt_alv
            IMPORTING et_regmail = lt_regmail ev_error = lv_error
            CHANGING ct_messages = et_messages ).
          IF lv_error = abap_true.
            EXIT.
          ENDIF.
          send_priority( EXPORTING iv_stock = iv_stock iv_priority = lv_priority
              it_alv = lt_alv
            IMPORTING ev_error = lv_error ev_call_started = lv_call_started
              ev_remote_success = lv_remote_success ev_uncertain = ev_uncertain
            CHANGING ct_messages = et_messages ).
          IF lv_error = abap_true OR lv_remote_success <> abap_true.
            EXIT.
          ENDIF.
          save_release( EXPORTING iv_stock = iv_stock iv_priority = lv_priority
              it_alv = lt_alv it_regmail = lt_regmail
            IMPORTING ev_error = lv_error ev_saved = ev_success
              ev_uncertain = ev_uncertain
            CHANGING ct_messages = et_messages ).
          IF ev_success = abap_true.
            add_message( EXPORTING iv_type = 'S' iv_text = text-107
              iv_value1 = iv_stock iv_value2 = lv_priority CHANGING ct_messages = et_messages ).
            WRITE lv_total TO lv_number LEFT-JUSTIFIED.
            add_message( EXPORTING iv_type = 'S' iv_text = text-108
              iv_value1 = lv_number CHANGING ct_messages = et_messages ).
            WRITE lv_excluded TO lv_number LEFT-JUSTIFIED.
            add_message( EXPORTING iv_type = 'S' iv_text = text-109
              iv_value1 = lv_number CHANGING ct_messages = et_messages ).
            WRITE lv_allowed TO lv_number LEFT-JUSTIFIED.
            add_message( EXPORTING iv_type = 'S' iv_text = text-110
              iv_value1 = lv_number CHANGING ct_messages = et_messages ).
            IF ls_stock-notest = abap_true.
              add_message( EXPORTING iv_type = 'I' iv_text = text-111
                CHANGING ct_messages = et_messages ).
            ENDIF.
          ENDIF.
        ENDDO.
      CATCH cx_root INTO lr_error.
        ROLLBACK WORK.
        IF ev_success <> abap_true
           AND ( lv_call_started = abap_true OR lv_remote_success = abap_true ).
          ev_uncertain = abap_true.
        ENDIF.
        add_exception( EXPORTING ir_error = lr_error CHANGING ct_messages = et_messages ).
    ENDTRY.

    IF ev_uncertain = abap_true AND ev_success <> abap_true.
      mark_uncertain_state( EXPORTING iv_stock = iv_stock CHANGING ct_messages = et_messages ).
    ENDIF.
    IF lv_own_lock = abap_true.
      CALL FUNCTION 'DEQUEUE_EZPRT_STOCK'
        EXPORTING stock_id = iv_stock _scope = '1'.
    ENDIF.
    IF ev_success <> abap_true.
      add_message( EXPORTING iv_type = 'E' iv_text = text-112
        iv_value1 = iv_stock CHANGING ct_messages = et_messages ).
    ENDIF.
    IF iv_display_log = abap_true.
      write_log( EXPORTING it_messages = et_messages IMPORTING ev_log_error = lv_log_error ).
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PR_STOCK=>CHECK_STATUS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_NEW_STATUS                  TYPE        ZPRD_STOCK_STATUS
* | [--->] IV_OLD_STATUS                  TYPE        ZPRD_STOCK_STATUS
* | [--->] IV_DIR                         TYPE        CHAR1
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD check_status.

    IF iv_dir = 'F'.
      IF iv_old_status = space AND iv_new_status NE 'DM'.
        MESSAGE e044(zpr) WITH iv_old_status iv_new_status.
      ENDIF.

      IF iv_old_status = 'DM' AND iv_new_status NE 'QM'.
        MESSAGE e044(zpr) WITH iv_old_status iv_new_status.
      ENDIF.

      IF iv_old_status = 'QM' AND iv_new_status NE 'CL'.
        MESSAGE e044(zpr) WITH iv_old_status iv_new_status.
      ENDIF.
    ENDIF.

    IF iv_dir = 'B'.
      IF iv_old_status = 'DM' AND iv_new_status NE space.
        MESSAGE e044(zpr) WITH iv_old_status iv_new_status.
      ENDIF.

      IF iv_old_status = 'QM' AND iv_new_status NE 'DM'.
        MESSAGE e044(zpr) WITH iv_old_status iv_new_status.
      ENDIF.

      IF iv_old_status = 'CL' AND iv_new_status NE 'QM'.
        MESSAGE e044(zpr) WITH iv_old_status iv_new_status.
      ENDIF.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PR_STOCK=>GET_STOCK_HEADER
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_STOCK_ID                    TYPE        ZPRD_STOCK_ID
* | [<-()] RS_STOCK_DATA                  TYPE        ZPRS_COCKPIT_HEADER
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_stock_header.
*---------------------------------------------------------------*
* Rövid leírás: Összeg konverzió text formátumra
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.13.   X0097         Létrehozva
*---------------------------------------------------------------*
    SELECT SINGLE *
      INTO CORRESPONDING FIELDS OF rs_stock_data
      FROM zprt_stock
      WHERE stock_id = iv_stock_id.
    IF sy-subrc NE 0.

      MESSAGE e042 WITH iv_stock_id INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.
    CASE  rs_stock_data-status.
      WHEN space.
        rs_stock_data-text = 'Nyitott'.
        SELECT SINGLE id
          INTO rs_stock_data-icon
          FROM icon
          WHERE name = 'ICON_OPEN_FOLDER'.
      WHEN 'DM'.
        rs_stock_data-text = 'DM jóvahagyás megtörtént'.
        SELECT SINGLE id
          INTO rs_stock_data-icon
          FROM icon
          WHERE name = 'ICON_CHECKED'.
      WHEN 'QM'.
        rs_stock_data-text = 'QM jóvahagyás megtörtént'.
        SELECT SINGLE id
          INTO rs_stock_data-icon
          FROM icon
          WHERE name = 'ICON_RELEASE'.
      WHEN 'CL'.
        rs_stock_data-text = 'Lezárva'.
        SELECT SINGLE id
          INTO rs_stock_data-icon
          FROM icon
          WHERE name = 'ICON_CLOSED_FOLDER'.
    ENDCASE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PR_STOCK=>UPDATE_STATUS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_STOCK_ID                    TYPE        ZPRD_STOCK_ID
* | [--->] IV_NEW_STATUS                  TYPE        ZPRD_STOCK_STATUS
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD update_status.

    UPDATE zprt_stock
       SET status = @iv_new_status
     WHERE stock_id = @iv_stock_id.

    IF sy-subrc = 0.
      commit work.
    else.
      ROLLBACK WORK.
    ENDIF.

  ENDMETHOD.
METHOD check_regmail_tables.
  DATA: lt_fields TYPE STANDARD TABLE OF dfies,
        ls_field TYPE dfies,
        lv_table_class TYPE dd02l-tabclass.
  ev_error = abap_true.
  SELECT SINGLE tabclass FROM dd02l INTO lv_table_class
    WHERE tabname = gc_terti_table AND as4local = 'A' AND as4vers = '0000'.
  IF sy-subrc <> 0 OR lv_table_class <> 'TRANSP'.
    add_message( EXPORTING iv_type = 'E' iv_text = text-113
      iv_value1 = gc_terti_table iv_value2 = space CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  CALL FUNCTION 'DDIF_FIELDINFO_GET'
    EXPORTING tabname = gc_terti_table
    TABLES dfies_tab = lt_fields
    EXCEPTIONS not_found = 1 internal_error = 2 OTHERS = 3.
  IF sy-subrc <> 0.
    add_message( EXPORTING iv_type = 'E' iv_text = text-114
      iv_value1 = gc_terti_table iv_value2 = space CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'MANDT'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CLNT' OR ls_field-leng <> 3.
    add_message( EXPORTING iv_type = 'E' iv_text = text-115
      iv_value1 = gc_terti_table iv_value2 = space CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'ENVELOPE_ID'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CHAR' OR ls_field-leng <> 9.
    add_message( EXPORTING iv_type = 'E' iv_text = text-116
      iv_value1 = gc_terti_table iv_value2 = 'ENVELOPE_ID' CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'EXBILLDOCNO'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CHAR' OR ls_field-leng <> 20.
    add_message( EXPORTING iv_type = 'E' iv_text = text-116
      iv_value1 = gc_terti_table iv_value2 = 'EXBILLDOCNO' CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field
    WITH KEY fieldname = 'ZISU_RAGSZAM_128'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CHAR' OR ls_field-leng <> 16.
    add_message( EXPORTING iv_type = 'E' iv_text = text-116
      iv_value1 = gc_terti_table iv_value2 = 'ZISU_RAGSZAM_128' CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  REFRESH lt_fields.
  CLEAR lv_table_class.
  SELECT SINGLE tabclass FROM dd02l INTO lv_table_class
    WHERE tabname = gc_f064_table AND as4local = 'A' AND as4vers = '0000'.
  IF sy-subrc <> 0 OR lv_table_class <> 'TRANSP'.
    add_message( EXPORTING iv_type = 'E' iv_text = text-113
      iv_value1 = gc_f064_table iv_value2 = space CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  CALL FUNCTION 'DDIF_FIELDINFO_GET'
    EXPORTING tabname = gc_f064_table
    TABLES dfies_tab = lt_fields
    EXCEPTIONS not_found = 1 internal_error = 2 OTHERS = 3.
  IF sy-subrc <> 0.
    add_message( EXPORTING iv_type = 'E' iv_text = text-114
      iv_value1 = gc_f064_table iv_value2 = space CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'MANDT'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CLNT' OR ls_field-leng <> 3.
    add_message( EXPORTING iv_type = 'E' iv_text = text-115
      iv_value1 = gc_f064_table iv_value2 = space CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'ZISU_RAGSZAM'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CHAR' OR ls_field-leng <> 16.
    add_message( EXPORTING iv_type = 'E' iv_text = text-116
      iv_value1 = gc_f064_table iv_value2 = 'ZISU_RAGSZAM' CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  ev_error = abap_false.
ENDMETHOD.

METHOD prepare_regmail.
  DATA: ls_alv TYPE zprs_dcqm_report,
        lt_found TYPE ty_regmail_table,
        ls_found TYPE ty_regmail,
        lr_error TYPE REF TO cx_root.
  REFRESH et_regmail.
  ev_error = abap_false.
  CHECK it_alv IS NOT INITIAL.
  check_regmail_tables( IMPORTING ev_error = ev_error CHANGING ct_messages = ct_messages ).
  CHECK ev_error = abap_false.
  TRY.
      LOOP AT it_alv INTO ls_alv.
        IF ls_alv-doc_no IS INITIAL.
*        IF ls_alv-doc_no IS INITIAL OR ls_alv-envelope IS INITIAL.
          ev_error = abap_true.
          add_message( EXPORTING iv_type = 'E' iv_text = text-117
      iv_value1 = ls_alv-doc_no iv_value2 = ls_alv-envelope CHANGING ct_messages = ct_messages ).
          RETURN.
        ENDIF.
        REFRESH lt_found.

        SELECT envelope_id exbilldocno zisu_ragszam_128
          FROM (gc_terti_table) INTO TABLE lt_found
          WHERE zisu_ragszam_128 = ls_alv-regmailnumber
            AND envelope_id = ls_alv-envelope
            AND exbilldocno = ls_alv-doc_no.

        IF ls_alv-regmailnumber IS NOT INITIAL AND lt_found IS INITIAL.
          ev_error = abap_true.
          add_message( EXPORTING iv_type = 'E' iv_text = text-118
      iv_value1 = ls_alv-doc_no iv_value2 = ls_alv-regmailnumber CHANGING ct_messages = ct_messages ).
          RETURN.
        ENDIF.
        LOOP AT lt_found INTO ls_found.
          IF ls_found-zisu_ragszam_128 IS INITIAL.
            ev_error = abap_true.
            add_message( EXPORTING iv_type = 'E' iv_text = text-119
      iv_value1 = ls_alv-doc_no iv_value2 = space CHANGING ct_messages = ct_messages ).
            RETURN.
          ENDIF.
          APPEND ls_found TO et_regmail.
        ENDLOOP.
      ENDLOOP.
    CATCH cx_root INTO lr_error.
      ev_error = abap_true.
      add_exception( EXPORTING ir_error = lr_error CHANGING ct_messages = ct_messages ).
  ENDTRY.
  SORT et_regmail BY envelope_id exbilldocno zisu_ragszam_128.
  DELETE ADJACENT DUPLICATES FROM et_regmail COMPARING ALL FIELDS.
ENDMETHOD.

METHOD send_priority.
  DATA: ls_input TYPE zpr_eon_dcqmcompleted_request2,
        ls_output TYPE zpr_eon_dcqmcompleted_response,
        lt_envelopes TYPE zpr_eon_dcqmcompleted_requ_tab,
        ls_envelope TYPE zpr_eon_dcqmcompleted_request1,
        ls_alv TYPE zprs_dcqm_report,
        lo_proxy TYPE REF TO zpr_co_eon_dcqmcompleted_port,
        lv_port TYPE prx_logical_port_name,
        lr_error TYPE REF TO cx_root.

  "Only an explicit successful response permits local closing.
  ev_error = abap_true.
  CLEAR ev_uncertain.
  CLEAR: ev_call_started, ev_remote_success.

  LOOP AT it_alv INTO ls_alv.
    CLEAR ls_envelope.
    ls_envelope-envelope_id = ls_alv-envelope.
    APPEND ls_envelope TO lt_envelopes.
  ENDLOOP.

  SORT lt_envelopes BY envelope_id.
  DELETE ADJACENT DUPLICATES FROM lt_envelopes COMPARING envelope_id.

  ls_input-sap_mandant = sy-mandt.
  ls_input-sap_system = sy-sysid.
  ls_input-stock_id = iv_stock.
  ls_input-priority = iv_priority.
  ls_input-exclude_envelopes-envelope = lt_envelopes.

  TRY.
      lv_port = zcl_pr_output_management=>get_logical_port_name( ).
      IF lv_port IS INITIAL.
        add_message( EXPORTING iv_type = 'E' iv_text = text-120
      iv_value1 = space iv_value2 = space CHANGING ct_messages = ct_messages ).
        RETURN.
      ENDIF.
      CREATE OBJECT lo_proxy EXPORTING logical_port_name = lv_port.
      ev_call_started = abap_true.
      lo_proxy->eon_dcqmcompleted(
        EXPORTING input = ls_input IMPORTING output = ls_output ).

    CATCH cx_ai_application_fault INTO lr_error.
      ev_error = abap_true.
      CLEAR: ev_call_started, ev_remote_success.
      add_exception( EXPORTING ir_error = lr_error CHANGING ct_messages = ct_messages ).
      add_message( EXPORTING iv_type = 'E' iv_text = text-121
      iv_value1 = iv_stock iv_value2 = space CHANGING ct_messages = ct_messages ).
      RETURN.
    CATCH cx_root INTO lr_error.
      add_exception( EXPORTING ir_error = lr_error CHANGING ct_messages = ct_messages ).
      IF ev_call_started = abap_true.
        ev_uncertain = abap_true.
        add_message( EXPORTING iv_type = 'E' iv_text = text-122
      iv_value1 = iv_stock iv_value2 = text-123 CHANGING ct_messages = ct_messages ).
      ENDIF.
      RETURN.
  ENDTRY.
  IF ls_output-parameters-success <> abap_true.
    add_message( EXPORTING iv_type = 'E' iv_text = text-124
      iv_value1 = ls_output-parameters-error_code iv_value2 = ls_output-parameters-info CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  ev_remote_success = abap_true.
  ev_error = abap_false.
  add_message( EXPORTING iv_type = 'S' iv_text = text-125
      iv_value1 = iv_stock iv_value2 = space CHANGING ct_messages = ct_messages ).
ENDMETHOD.

METHOD save_release.
  DATA: ls_regmail TYPE ty_regmail,
        lt_current TYPE ty_regmail_table,
        lr_error TYPE REF TO cx_root.
  ev_error = abap_true.
  ev_saved = abap_false.  CLEAR ev_uncertain.
  prepare_regmail( EXPORTING it_alv = it_alv
    IMPORTING et_regmail = lt_current ev_error = ev_error CHANGING ct_messages = ct_messages ).
  IF ev_error = abap_true OR lt_current <> it_regmail.
    ev_error = abap_true.
    ev_uncertain = abap_true.
    add_message( EXPORTING iv_type = 'E' iv_text = text-126
      iv_value1 = iv_stock iv_value2 = space CHANGING ct_messages = ct_messages ).
    RETURN.
  ENDIF.
  ev_error = abap_true.
  TRY.
      LOOP AT it_regmail INTO ls_regmail.
        DELETE FROM (gc_terti_table)
          WHERE envelope_id = ls_regmail-envelope_id
            AND exbilldocno = ls_regmail-exbilldocno
            AND zisu_ragszam_128 = ls_regmail-zisu_ragszam_128.
        IF sy-subrc <> 0.
          ROLLBACK WORK.
          ev_uncertain = abap_true.
          add_message( EXPORTING iv_type = 'E' iv_text = text-127
      iv_value1 = ls_regmail-exbilldocno iv_value2 = ls_regmail-zisu_ragszam_128 CHANGING ct_messages = ct_messages ).
          RETURN.
        ENDIF.
        "A missing F064 row is allowed; SQL exceptions abort the LUW.
        DELETE FROM (gc_f064_table)
          WHERE zisu_ragszam = ls_regmail-zisu_ragszam_128.
        IF sy-subrc ne 0.
          add_message( EXPORTING iv_type = 'E' iv_text = text-128
      iv_value1 = ls_regmail-exbilldocno iv_value2 = ls_regmail-zisu_ragszam_128 CHANGING ct_messages = ct_messages ).
        ENDIF.
      ENDLOOP.
      UPDATE zprt_stock
        SET closed = abap_true
            status = gc_status_closed
            priority = iv_priority
            erdat_clo = sy-datum
            ernam_clo = sy-uname
            ertim_clo = sy-uzeit
            chuser = sy-uname
            chdate = sy-datum
            chtime = sy-uzeit
        WHERE stock_id = iv_stock
          AND closed = space
          AND status = gc_status_qm
          AND stock_status_er = space.
      IF sy-subrc <> 0 OR sy-dbcnt <> 1.
        ROLLBACK WORK.
        ev_uncertain = abap_true.
        add_message( EXPORTING iv_type = 'E' iv_text = text-129
      iv_value1 = iv_stock iv_value2 = space CHANGING ct_messages = ct_messages ).
        RETURN.
      ENDIF.
      COMMIT WORK.
      ev_saved = abap_true.
      ev_error = abap_false.
    CATCH cx_root INTO lr_error.
      ROLLBACK WORK.
      ev_uncertain = abap_true.
      add_exception( EXPORTING ir_error = lr_error CHANGING ct_messages = ct_messages ).
  ENDTRY.
ENDMETHOD.

METHOD mark_uncertain_state.
  DATA lr_error TYPE REF TO cx_root.
  "Persist a retry block without marking the stock as closed.
  TRY.
      UPDATE zprt_stock
        SET stock_status_er = abap_true
            chuser = sy-uname chdate = sy-datum chtime = sy-uzeit
        WHERE stock_id = iv_stock.
      IF sy-subrc = 0 AND sy-dbcnt = 1.
        COMMIT WORK.
        add_message( EXPORTING iv_type = 'E' iv_text = text-130
      iv_value1 = iv_stock iv_value2 = space CHANGING ct_messages = ct_messages ).
      ELSE.
        ROLLBACK WORK.
        add_message( EXPORTING iv_type = 'E' iv_text = text-131
      iv_value1 = iv_stock iv_value2 = space CHANGING ct_messages = ct_messages ).
      ENDIF.
    CATCH cx_root INTO lr_error.
      ROLLBACK WORK.
      add_exception( EXPORTING ir_error = lr_error CHANGING ct_messages = ct_messages ).
      add_message( EXPORTING iv_type = 'E' iv_text = text-132
      iv_value1 = iv_stock iv_value2 = space CHANGING ct_messages = ct_messages ).
  ENDTRY.
ENDMETHOD.

METHOD add_message.
  DATA: ls_message TYPE bal_s_msg,
        lv_text TYPE c LENGTH 200.
  CONCATENATE iv_text iv_value1 iv_value2 INTO lv_text SEPARATED BY space.
  ls_message-msgid = 'ZPR'.
  ls_message-msgno = '000'.
  ls_message-msgty = iv_type.
  ls_message-msgv1 = lv_text+0(50).
  ls_message-msgv2 = lv_text+50(50).
  ls_message-msgv3 = lv_text+100(50).
  ls_message-msgv4 = lv_text+150(50).
  APPEND ls_message TO ct_messages.
ENDMETHOD.

METHOD add_exception.
  DATA: ls_message TYPE bal_s_msg,
        lv_text TYPE c LENGTH 200.
  lv_text = ir_error->get_text( ).
  ls_message-msgid = 'ZPR'.
  ls_message-msgno = '000'.
  ls_message-msgty = 'E'.
  ls_message-msgv1 = lv_text+0(50).
  ls_message-msgv2 = lv_text+50(50).
  ls_message-msgv3 = lv_text+100(50).
  ls_message-msgv4 = lv_text+150(50).
  APPEND ls_message TO ct_messages.
ENDMETHOD.

METHOD write_log.
  DATA lv_dummy TYPE string.
  DATA: lo_log TYPE REF TO zcl_pr_log,
        lr_error TYPE REF TO cx_root,
        ls_message TYPE bal_s_msg,
        lv_text TYPE string.
  ev_log_error = abap_false.
  CHECK it_messages IS NOT INITIAL.
  "Business changes have already been committed or rolled back.
  TRY.
      CREATE OBJECT lo_log
        EXPORTING iv_log_object = gc_log_object
                  iv_log_subobject = gc_log_subobject.
      LOOP AT it_messages INTO ls_message.
        MESSAGE ID ls_message-msgid TYPE ls_message-msgty
          NUMBER ls_message-msgno
          WITH ls_message-msgv1 ls_message-msgv2
               ls_message-msgv3 ls_message-msgv4 INTO lv_dummy.
        lo_log->add_system_message( ).
      ENDLOOP.
      lo_log->close( ).
      COMMIT WORK.
      lo_log->display( ).
    CATCH cx_root INTO lr_error.
      ROLLBACK WORK.
      ev_log_error = abap_true.
      lv_text = lr_error->get_text( ).
      MESSAGE s000 WITH text-133 lv_text
        DISPLAY LIKE 'E'.
  ENDTRY.
ENDMETHOD.
ENDCLASS.
