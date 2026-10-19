REPORT zpr_messagequeue_query
*MESSAGE-ID zpr.
.
*********************************************************************
* Report: ZPR_MESSAGEQUEUE_QUERY
* Leírás:
* Query Messenger email status and persist confirmed results.
*--------------------------------------------------------------------
* Modulfelelos: <XY>
* Tanácsadó:
* Programozó:   Pál Tamás
* Dátum, kérelem: 2026.10.13
* --------------------------------------------------------------------
* Módosítások:
* <dátum>, <programozó>, <kérelem>, <comment azonosító>
*          <rövid leírás>
**********************************************************************
* 13.10.2026 11:42:02    X0134  Létrehozás
*--------------------------------------------------------------------*


INCLUDE <icon>.

TYPES ty_email_tab TYPE STANDARD TABLE OF zprt_email_slog WITH DEFAULT KEY.
TYPES ty_docno_tab TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
TYPES: BEGIN OF ty_result.
         INCLUDE TYPE zprt_email_slog.
TYPES:   save_state TYPE c LENGTH 1,
         save_text  TYPE c LENGTH 100,
       END OF ty_result.
TYPES ty_result_tab TYPE STANDARD TABLE OF ty_result WITH DEFAULT KEY.

CONSTANTS: gc_tcode TYPE sytcode VALUE 'ZPR_MQ_QUERY',
           gc_missing TYPE zprt_email_slog-sending_status VALUE 'N',
           gc_missing_text TYPE zprt_email_slog-error_message
             VALUE 'Hét napon belül nem érkezett státusz a Messengertől.'.

PARAMETERS p_lport TYPE prx_logical_port_name NO-DISPLAY.


DATA: gt_pending TYPE ty_email_tab,
      gt_response TYPE ty_email_tab,
      gt_result TYPE ty_result_tab,
      gt_log TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
      gr_container TYPE REF TO cl_gui_custom_container,
      gr_alv TYPE REF TO cl_salv_table,
      gv_okcode_0100 TYPE syucomm.

CLASS lcl_age DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS parse_text
      IMPORTING iv_text TYPE clike
      RETURNING VALUE(rv_stamp) TYPE timestamp.
    CLASS-METHODS format_stamp
      IMPORTING iv_stamp TYPE timestamp
      RETURNING VALUE(rv_text) TYPE zprt_email_slog-tstmp_print.
    CLASS-METHODS expired
      IMPORTING iv_print TYPE zprt_email_slog-tstmp_print
                iv_now TYPE timestamp
      RETURNING VALUE(rv_expired) TYPE abap_bool.
ENDCLASS.

CLASS lcl_age IMPLEMENTATION.
  METHOD parse_text.
    DATA: lv_date TYPE d,
          lv_time TYPE t.
    CLEAR rv_stamp.
    IF strlen( iv_text ) <> 14 OR iv_text CN '0123456789'.
      RETURN.
    ENDIF.
    rv_stamp = iv_text.
    CONVERT TIME STAMP rv_stamp TIME ZONE 'UTC'
      INTO DATE lv_date TIME lv_time.
    IF sy-subrc <> 0.
      CLEAR rv_stamp.
    ENDIF.
  ENDMETHOD.

  METHOD format_stamp.
    DATA: lv_date TYPE d,
          lv_time TYPE t.
    CLEAR rv_text.
    IF iv_stamp IS INITIAL.
      RETURN.
    ENDIF.
    CONVERT TIME STAMP iv_stamp TIME ZONE 'UTC'
      INTO DATE lv_date TIME lv_time.
    IF sy-subrc = 0.
      CONCATENATE lv_date lv_time INTO rv_text.
    ENDIF.
  ENDMETHOD.

  METHOD expired.
    DATA: lv_date TYPE d,
          lv_time TYPE t,
          lv_print TYPE timestamp,
          lv_cutoff TYPE timestamp.
    rv_expired = abap_false.
    lv_print = parse_text( iv_text = iv_print ).
    IF lv_print IS INITIAL OR iv_now IS INITIAL.
      RETURN.
    ENDIF.
    CONVERT TIME STAMP iv_now TIME ZONE 'UTC'
      INTO DATE lv_date TIME lv_time.
    IF sy-subrc <> 0 OR lv_date < '00010108'.
      RETURN.
    ENDIF.
    lv_date = lv_date - 7.
    CONVERT DATE lv_date TIME lv_time
      INTO TIME STAMP lv_cutoff TIME ZONE 'UTC'.
    IF sy-subrc = 0 AND lv_print <= lv_cutoff.
      rv_expired = abap_true.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_screen DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS show.
    CLASS-METHODS on_command FOR EVENT added_function OF cl_salv_events
      IMPORTING e_salv_function.
ENDCLASS.

INCLUDE zpr_mq_proxy.
INCLUDE zpr_mq_display.

INITIALIZATION.
  zcl_pr_output_management=>get_logical_port_name(
    RECEIVING
      rv_logical_port_name =  p_lport                " Logikai portnév
  ).


  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
  IF sy-subrc <> 0.
    MESSAGE s172(00) WITH gc_tcode.
    LEAVE PROGRAM.
  ENDIF.

START-OF-SELECTION.
  PERFORM run.
  PERFORM flush_log.

FORM add_log USING iv_text TYPE clike.
  DATA: lv_line TYPE string,
        lv_date TYPE c LENGTH 8,
        lv_time TYPE c LENGTH 6.
  lv_date = sy-datum.
  lv_time = sy-uzeit.
  CONCATENATE lv_date lv_time iv_text INTO lv_line SEPARATED BY space.
  APPEND lv_line TO gt_log.
ENDFORM.

FORM flush_log.
  DATA lv_line TYPE string.
  LOOP AT gt_log INTO lv_line.
    WRITE / lv_line.
  ENDLOOP.
ENDFORM.

FORM run.
  DATA: lt_docnos TYPE ty_docno_tab,
        ls_email TYPE zprt_email_slog,
        lv_docno TYPE string,
        lv_ok TYPE abap_bool,
        lv_error TYPE string,
        lx_error TYPE REF TO cx_root.

  PERFORM add_log USING 'Messenger-státuszlekérdezés megkezdve.'.
  TRY.
      SELECT * INTO TABLE gt_pending FROM zprt_email_slog
        WHERE sending_status = space.
      IF gt_pending IS INITIAL.
        PERFORM add_log USING 'Nincs státusz nélküli e-mailnapló-bejegyzés.'.
        RETURN.
      ENDIF.
      SORT gt_pending BY exbilldocno.
      LOOP AT gt_pending INTO ls_email.
        IF ls_email-exbilldocno IS INITIAL.
          PERFORM add_log USING 'Üres dokumentumazonosító: a lekérdezés leállt.'.
          RETURN.
        ENDIF.
        lv_docno = ls_email-exbilldocno.
        APPEND lv_docno TO lt_docnos.
      ENDLOOP.

      PERFORM query_messenger USING lt_docnos
        CHANGING gt_response lv_ok lv_error.
      IF lv_ok = abap_false.
        PERFORM add_log USING lv_error.
        RETURN.
      ENDIF.
      PERFORM prepare_result.
      IF gt_result IS INITIAL.
        PERFORM add_log USING 'Nincs menthető státuszváltozás.'.
        RETURN.
      ENDIF.
      IF sy-batch = abap_true.
        PERFORM save_result.
      ELSE.
        CALL SCREEN 0100.
        IF gr_alv IS BOUND.
          FREE gr_alv.
        ENDIF.
        IF gr_container IS BOUND.
          gr_container->free( ).
          FREE gr_container.
        ENDIF.
      ENDIF.
    CATCH cx_root INTO lx_error.
      lv_error = lx_error->get_text( ).
      PERFORM add_log USING lv_error.
      IF sy-batch = space.
        MESSAGE lv_error TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
  ENDTRY.
  PERFORM add_log USING 'Messenger-státuszlekérdezés befejezve.'.
ENDFORM.

FORM prepare_result.
  DATA: ls_email TYPE zprt_email_slog,
        ls_response TYPE zprt_email_slog,
        ls_result TYPE ty_result,
        lv_now TYPE timestamp,
        lv_expired TYPE abap_bool.

  CLEAR gt_result.
  GET TIME STAMP FIELD lv_now.
  SORT gt_response BY exbilldocno.
  LOOP AT gt_pending INTO ls_email.
    CLEAR ls_result.
    MOVE-CORRESPONDING ls_email TO ls_result.
    READ TABLE gt_response INTO ls_response
      WITH KEY exbilldocno = ls_email-exbilldocno BINARY SEARCH.
    IF sy-subrc = 0 AND ls_response-sending_status IS NOT INITIAL.
      ls_result-sending_status = ls_response-sending_status.
      ls_result-tstmp_sending_status = ls_response-tstmp_sending_status.
      ls_result-error_message = ls_response-error_message.
      ls_result-tstmp_email_sent = ls_response-tstmp_email_sent.
    ELSE.
      lv_expired = lcl_age=>expired(
        iv_print = ls_email-tstmp_print iv_now = lv_now ).
      IF lv_expired = abap_false.
        CONTINUE.
      ENDIF.
      ls_result-sending_status = gc_missing.
      ls_result-tstmp_sending_status = lcl_age=>format_stamp( iv_stamp = lv_now ).
      ls_result-error_message = gc_missing_text.
    ENDIF.
    APPEND ls_result TO gt_result.
  ENDLOOP.
ENDFORM.

FORM unlock_email USING iv_docno TYPE zprt_email_slog-exbilldocno.
  CALL FUNCTION 'DEQUEUE_EZPR_SLOG_EMAIL'
    EXPORTING
      mode_zpr_slog_email = 'E'
      mandt = sy-mandt
      exbilldocno = iv_docno
      _scope = '1'.
ENDFORM.

FORM save_result.
  DATA: ls_original TYPE zprt_email_slog,
        ls_current TYPE zprt_email_slog,
        lx_error TYPE REF TO cx_root,
        lv_text TYPE string,
        lv_docno TYPE string,
        lv_saved TYPE i,
        lv_skipped TYPE i,
        lv_failed TYPE i,
        lv_saved_text TYPE c LENGTH 12,
        lv_skipped_text TYPE c LENGTH 12,
        lv_failed_text TYPE c LENGTH 12.
  FIELD-SYMBOLS <ls_result> TYPE ty_result.

  LOOP AT gt_result ASSIGNING <ls_result>.
    IF <ls_result>-save_state = 'S' OR <ls_result>-save_state = 'C'.
      CONTINUE.
    ENDIF.
    lv_docno = <ls_result>-exbilldocno.
    READ TABLE gt_pending INTO ls_original
      WITH KEY exbilldocno = <ls_result>-exbilldocno BINARY SEARCH.
    IF sy-subrc <> 0.
      <ls_result>-save_state = 'E'.
      <ls_result>-save_text = 'Az eredeti rekord nem található; nincs mentés.'.
      lv_failed = lv_failed + 1.
      CONTINUE.
    ENDIF.

    CALL FUNCTION 'ENQUEUE_EZPR_SLOG_EMAIL'
      EXPORTING
        mode_zpr_slog_email = 'E'
        mandt = sy-mandt
        exbilldocno = <ls_result>-exbilldocno
        _scope = '1'
        _wait = space
      EXCEPTIONS
        foreign_lock = 1
        system_failure = 2
        OTHERS = 3.
    IF sy-subrc <> 0.
      <ls_result>-save_state = 'E'.
      <ls_result>-save_text = 'A rekord nem zárolható; nincs mentés.'.
      lv_failed = lv_failed + 1.
      CONCATENATE lv_docno <ls_result>-save_text INTO lv_text
        SEPARATED BY space.
      PERFORM add_log USING lv_text.
      CONTINUE.
    ENDIF.

    TRY.
        CLEAR ls_current.
        SELECT SINGLE * INTO ls_current FROM zprt_email_slog
          WHERE exbilldocno = <ls_result>-exbilldocno.
        IF sy-subrc <> 0 OR ls_current <> ls_original.
          <ls_result>-save_state = 'C'.
          <ls_result>-save_text = 'A rekord megváltozott vagy törölték; új lekérdezés kell.'.
          lv_skipped = lv_skipped + 1.
        ELSE.
          UPDATE zprt_email_slog
            SET sending_status = <ls_result>-sending_status
                tstmp_sending_status = <ls_result>-tstmp_sending_status
                error_message = <ls_result>-error_message
                tstmp_email_sent = <ls_result>-tstmp_email_sent
            WHERE exbilldocno = <ls_result>-exbilldocno
              AND sending_status = space
              AND tstmp_print = ls_original-tstmp_print.
          IF sy-subrc = 0 AND sy-dbcnt = 1.
            COMMIT WORK AND WAIT.
            IF sy-subrc = 0.
              <ls_result>-save_state = 'S'.
              <ls_result>-save_text = 'Mentve.'.
              lv_saved = lv_saved + 1.
            ELSE.
              ROLLBACK WORK.
              <ls_result>-save_state = 'E'.
              <ls_result>-save_text = 'A commit hibát jelzett; a tényleges állapot ellenőrizendő.'.
              lv_failed = lv_failed + 1.
            ENDIF.
          ELSE.
            ROLLBACK WORK.
            <ls_result>-save_state = 'C'.
            <ls_result>-save_text = 'Nem frissült pontosan egy rekord; új lekérdezés kell.'.
            lv_skipped = lv_skipped + 1.
          ENDIF.
        ENDIF.
      CATCH cx_root INTO lx_error.
        ROLLBACK WORK.
        <ls_result>-save_state = 'E'.
        lv_text = lx_error->get_text( ).
        <ls_result>-save_text = lv_text.
        lv_failed = lv_failed + 1.
    ENDTRY.
    PERFORM unlock_email USING <ls_result>-exbilldocno.
    CONCATENATE lv_docno <ls_result>-save_text INTO lv_text
      SEPARATED BY space.
    PERFORM add_log USING lv_text.
  ENDLOOP.

  lv_saved_text = lv_saved.
  lv_skipped_text = lv_skipped.
  lv_failed_text = lv_failed.
  CONDENSE: lv_saved_text, lv_skipped_text, lv_failed_text.
  CONCATENATE 'Mentve:' lv_saved_text 'Kihagyva:' lv_skipped_text
    'Hibás:' lv_failed_text INTO lv_text SEPARATED BY space.
  PERFORM add_log USING lv_text.
  IF sy-batch = space.
    IF lv_failed > 0 OR lv_skipped > 0.
      MESSAGE lv_text TYPE 'S' DISPLAY LIKE 'W'.
    ELSE.
      MESSAGE lv_text TYPE 'S'.
    ENDIF.
  ENDIF.
ENDFORM.

MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_0100'.
  SET TITLEBAR 'QUEUE_TITLE'.
  lcl_screen=>show( ).
ENDMODULE.

MODULE exit_0100 INPUT.
  CLEAR gv_okcode_0100.
  LEAVE TO SCREEN 0.
ENDMODULE.

MODULE command_0100 INPUT.
  DATA lv_command TYPE syucomm.
  lv_command = gv_okcode_0100.
  CLEAR gv_okcode_0100.
  CASE lv_command.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.
  ENDCASE.
ENDMODULE.

INCLUDE zpr_mq_tests.