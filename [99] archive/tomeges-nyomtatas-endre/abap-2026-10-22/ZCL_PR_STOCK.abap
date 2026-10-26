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
      !IV_STOCK type ZPRD_STOCK_ID .
protected section.

  class-data GV_DUMMY_MESSAGE type CHAR1 .
private section.
ENDCLASS.



CLASS ZCL_PR_STOCK IMPLEMENTATION.


  METHOD close_stock.
* ---------------------------------------------------------------*
* Rövid leírás: Stock lezárása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*----------------------------------------------------------------*
* Deklaráció
    DATA: ls_input  TYPE zpr_eon_dcqmcompleted_request2,
          ls_output	TYPE zpr_eon_dcqmcompleted_response.
    DATA: lo_dcqm TYPE REF TO zpr_co_eon_dcqmcompleted_port.
    DATA: lv_ex_txt TYPE string.
    DATA: lr_sys_fail TYPE REF TO cx_ai_system_fault,
          lr_app_fail TYPE REF TO cx_ai_application_fault.
    DATA: lv_error_flag TYPE flag,
          lv_lines      TYPE i,
          lv_ret        TYPE char1,
          lv_hiba       TYPE flag,
          lv_dummy      TYPE string.
    DATA: ls_edit   TYPE lvc_s_styl,
          ls_stable TYPE lvc_s_stbl.
    DATA: lt_rows TYPE lvc_t_row,
          ls_rows LIKE LINE OF lt_rows.
    DATA: ls_sval  TYPE sval.
    DATA: lt_sval  TYPE STANDARD TABLE OF sval.
    DATA: gs_stock TYPE zprt_stock.
    DATA gv_priority TYPE zprd_priority VALUE '30'.
    DATA lv_logical_port_name TYPE prx_logical_port_name.
    DATA lv_call_start TYPE timestampl.
    DATA lv_call_end TYPE timestampl.
    DATA lv_log_stamp TYPE c LENGTH 40.
    DATA lv_seconds TYPE p LENGTH 12 DECIMALS 3.
    DATA lv_log_duration TYPE c LENGTH 40.

    DATA lv_obj  TYPE balobj_d VALUE 'ZPR_MASS'.
    DATA lv_subobj  TYPE balsubobj VALUE 'PACKAGE'.

* A boritékolás tisztázandó
    DATA: lt_env_tab TYPE zpr_eon_dcqmcompleted_requ_tab,
          ls_env_tab TYPE zpr_eon_dcqmcompleted_request1.
*    DATA lt_exc_env TYPE zebf_pr_string_tab.
*    DATA ls_exc_env TYPE string.
*    DATA ls_0100_alv TYPE zebfs_pr_dcqm_report.

*----------------------------------------------------------------*
* Prioritás megállapítása
    REFRESH lt_sval.
    ls_sval-tabname   = 'ZPRT_STOCK'.
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

*    LOOP AT gt_0100_alv INTO ls_0100_alv.
**    ls_exc_env = ls_0100_alv-envelope.
*      ls_env_tab-envelope_id = ls_0100_alv-envelope.
*      APPEND ls_env_tab TO lt_env_tab.
*    ENDLOOP.
*    SORT lt_env_tab.
*    DELETE ADJACENT DUPLICATES FROM lt_env_tab.
*    ls_input-exclude_envelopes-envelope[] = lt_env_tab[].

*---------------------------------------------------------------*
* Alkalmazási napló megnyitása
    DATA(lo_log) = NEW zcl_pr_log(
      iv_log_object    = lv_obj
      iv_log_subobject = lv_subobj ).

* ---------------------------------------------------------------*
* Logikai port előállítása
    lv_logical_port_name = zcl_pr_output_management=>get_logical_port_name(  ).

* ---------------------------------------------------------------*
* Proxy objektum létrehozása
    TRY.
        CREATE OBJECT lo_dcqm
          EXPORTING
*           destination       = lo_destination
            logical_port_name = lv_logical_port_name. "lv_logical_port_name..
      CATCH cx_ai_system_fault INTO DATA(lx_system_fault). " Application Integration: Technical Error
*        MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO gv_dummy_message.
        gv_dummy_message = zcl_pr_admin=>get_cx_message( io_cx = lx_system_fault iv_out = abap_false ).
        lo_log->add_system_message(  ).
        lv_error_flag = abap_true.
    ENDTRY.

* ---------------------------------------------------------------*
* Hívás felparaméterezése
    ls_input-sap_mandant = sy-mandt.
    ls_input-sap_system = sy-sysid.
    ls_input-stock_id = iv_stock.
    ls_input-priority = gv_priority.

* ---------------------------------------------------------------*
* Inspire hívás
    IF lv_error_flag IS INITIAL.
      TRY.
          GET TIME STAMP FIELD lv_call_start.
                               lv_log_stamp = |{ lv_call_start TIMESTAMP = ISO TIMEZONE = 'UTC' } UTC|.
          MESSAGE s000(zpr) WITH text-901 iv_stock lv_log_stamp INTO lv_dummy.
          lo_log->add_system_message( ).

          CALL METHOD lo_dcqm->eon_dcqmcompleted
            EXPORTING
              input  = ls_input
            IMPORTING
              output = ls_output.

          GET TIME STAMP FIELD lv_call_end.

        CATCH cx_ai_system_fault INTO lx_system_fault.
          GET TIME STAMP FIELD lv_call_end.
*          MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO gv_dummy_message.
          gv_dummy_message = zcl_pr_admin=>get_cx_message( io_cx = lx_system_fault iv_out = abap_false ).
          lo_log->add_system_message(  ).
          lv_error_flag = abap_true.
        CATCH cx_ai_application_fault INTO DATA(lx_application_fault).
          GET TIME STAMP FIELD lv_call_end.
*          MESSAGE e000 WITH lx_application_fault->get_text(  ) INTO gv_dummy_message.
          gv_dummy_message = zcl_pr_admin=>get_cx_message( io_cx = lx_application_fault iv_out = abap_false ).
          lo_log->add_system_message(  ).
          lv_error_flag = abap_true.
      ENDTRY.

*TODO: Még ne !!
CLEAR: lv_call_start, lv_call_end.
      IF lv_call_start IS NOT INITIAL AND lv_call_end IS NOT INITIAL.
        lv_log_stamp = |{ lv_call_end TIMESTAMP = ISO TIMEZONE = 'UTC' } UTC|.
        IF lv_error_flag IS INITIAL.
          MESSAGE s000(zpr) WITH text-902 iv_stock lv_log_stamp INTO lv_dummy.
        ELSE.
          MESSAGE e000(zpr) WITH text-903 iv_stock lv_log_stamp INTO lv_dummy.
        ENDIF.
        lo_log->add_system_message( ).
        TRY.
            lv_seconds = cl_abap_tstmp=>subtract(
              tstmp1 = lv_call_end tstmp2 = lv_call_start ).
            WRITE lv_seconds TO lv_log_duration LEFT-JUSTIFIED
              DECIMALS 3 NO-GROUPING.
            MESSAGE s000(zpr) WITH text-904 iv_stock lv_log_duration INTO lv_dummy.
            lo_log->add_system_message( ).
          CATCH cx_root.
            "Optional timing must not alter business error handling.
        ENDTRY.
      ENDIF.
    ENDIF.

* ---------------------------------------------------------------*
* Hibakezelés
    IF lv_error_flag IS INITIAL.
      IF ls_output-parameters-success = abap_true.
        MESSAGE s071 WITH iv_stock INTO gv_dummy_message.
        lo_log->add_system_message(  ).
      ELSE.
        MESSAGE e000 WITH ls_output-parameters-error_code ':' ls_output-parameters-info INTO  gv_dummy_message.
        lo_log->add_system_message(  ).
        lv_error_flag = abap_true.
      ENDIF.
    ENDIF.

*---------------------------------------------------------------*
* Hiba kezelés
    IF lv_error_flag EQ abap_true.
      MESSAGE s072 WITH iv_stock INTO gv_dummy_message.
      lo_log->add_system_message(  ).
    ENDIF.

*---------------------------------------------------------------*
* Adatbázis update
    IF lv_error_flag IS INITIAL.
      zcl_pr_stock=>update_status(
        iv_stock_id   = iv_stock
        iv_new_status = 'CL' ).
    ENDIF.

*---------------------------------------------------------------*
* Napló
    lo_log->close(  ).
    IF sy-batch IS INITIAL.
      lo_log->display(  ).
    ENDIF.

  ENDMETHOD.


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
      RAISE EXCEPTION TYPE zcx_form_message_error USING MESSAGE.
    ENDIF.
    CASE  rs_stock_data-status.
      WHEN space.
        rs_stock_data-text = 'Nyitott'.
        SELECT SINGLE id
          INTO rs_stock_data-icon
          FROM icon
          WHERE name = 'ICON_OPEN_FOLDER'.
        IF sy-subrc <> 0.
          MESSAGE e000 INTO gv_dummy_message.
        ENDIF.
      WHEN 'DM'.
        rs_stock_data-text = 'DM jóvahagyás megtörtént'.
        SELECT SINGLE id
          INTO rs_stock_data-icon
          FROM icon
          WHERE name = 'ICON_CHECKED'.
        IF sy-subrc <> 0.
          MESSAGE e000 INTO gv_dummy_message.
        ENDIF.
      WHEN 'QM'.
        rs_stock_data-text = 'QM jóvahagyás megtörtént'.
        SELECT SINGLE id
          INTO rs_stock_data-icon
          FROM icon
          WHERE name = 'ICON_RELEASE'.
        IF sy-subrc <> 0.
          MESSAGE e000 INTO gv_dummy_message.
        ENDIF.
      WHEN 'CL'.
        rs_stock_data-text = 'Lezárva'.
        SELECT SINGLE id
          INTO rs_stock_data-icon
          FROM icon
          WHERE name = 'ICON_CLOSED_FOLDER'.
        IF sy-subrc <> 0.
          MESSAGE e000 INTO gv_dummy_message.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


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
ENDCLASS.