*&---------------------------------------------------------------------*
*& Report ZPR_DOC_STATUS
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zpr_doc_status.
*MESSAGE-ID zpr.
.
*********************************************************************
* Report: ZPR_MESSAGEQUEUE_QUERY
* Leírás:
* Retrieve Inspire document statuses and apply the DHC follow-up steps.
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
*&---------------------------------------------------------------------*

TYPES ty_stamp TYPE c LENGTH 14.
TYPES: BEGIN OF ty_event,
         status TYPE zprt_doc_slog-status,
         stamp  TYPE ty_stamp,
       END OF ty_event.
TYPES ty_event_tab TYPE STANDARD TABLE OF ty_event WITH DEFAULT KEY.
TYPES: BEGIN OF ty_response,
         doc_no     TYPE zprt_dcqm-doc_no,
         filename   TYPE string,
         events     TYPE ty_event_tab,
         error_code TYPE string,
         error_text TYPE string,
       END OF ty_response.
TYPES ty_response_tab TYPE SORTED TABLE OF ty_response
                      WITH UNIQUE KEY doc_no.
TYPES ty_docno_tab TYPE SORTED TABLE OF zprt_dcqm-doc_no
                   WITH UNIQUE KEY table_line.
TYPES ty_slog_tab TYPE STANDARD TABLE OF zprt_doc_slog WITH DEFAULT KEY.
TYPES: BEGIN OF ty_document,
         doc_no     TYPE zprt_dcqm-doc_no,
         package_id TYPE zprt_dcqm-package_id,
         log_doc_no TYPE zprt_doc_log-doc_no,
         envelope   TYPE zprt_dcqm-envelope,
         doc_cat    TYPE zprt_dcqm-doc_cat,
         channel    TYPE zprs_control_data-channel,
         doc_type   TYPE zprs_control_data-doc_type,
         opbel      TYPE zprs_business_data-opbel,
         bukrs      TYPE zprs_business_data-bukrs,
         sparte     TYPE zprs_business_data-sparte,
       END OF ty_document.
TYPES ty_document_tab TYPE STANDARD TABLE OF ty_document WITH DEFAULT KEY.

DATA: gs_stock      TYPE zprt_stock,
      gt_stock      TYPE STANDARD TABLE OF zprt_stock,
      gv_log_handle TYPE balloghndl,
      gv_log_error  TYPE abap_bool,
      go_proxy      TYPE REF TO zpr_co_eon_forms_query_doc_det.


SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS so_stock FOR gs_stock-stock_id
                  MATCHCODE OBJECT zprh_stock.

  PARAMETERS: p_det   AS CHECKBOX,
              p_stat  AS CHECKBOX,
              p_lport TYPE prx_logical_port_name NO-DISPLAY.
SELECTION-SCREEN END OF BLOCK b01.


CLASS lcl_response DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS parse
      IMPORTING iv_line TYPE string
      EXPORTING es_response TYPE ty_response ev_error TYPE string.
    CLASS-METHODS print_file
      IMPORTING iv_channel TYPE clike iv_doc_cat TYPE clike
                iv_filename TYPE string
      EXPORTING ev_file TYPE zprt_dcqm-prdfile
                ev_change TYPE abap_bool ev_error TYPE string.
ENDCLASS.

INITIALIZATION.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD 'ZPR_DOC_STATUS'.

  IF sy-subrc <> 0.
    MESSAGE TEXT-101 TYPE 'I'.
    LEAVE PROGRAM.
  ENDIF.

  zcl_pr_output_management=>get_logical_port_name(
    RECEIVING
      rv_logical_port_name =  p_lport                " Logikai portnév
  ).


AT SELECTION-SCREEN.
  IF p_stat = abap_true AND so_stock[] IS INITIAL.
    MESSAGE TEXT-102 TYPE 'E'.
  ENDIF.

START-OF-SELECTION.
  PERFORM run.

CLASS lcl_response IMPLEMENTATION.
  METHOD parse.
    CONSTANTS lc_statuses TYPE c LENGTH 14 VALUE 'RCBQOXPLGSADEV'.
    DATA: lt_fields   TYPE STANDARD TABLE OF string,
          lv_field    TYPE string,
          lv_lines    TYPE i,
          lv_index    TYPE i,
          lv_offset   TYPE i,
          lv_limit    TYPE i,
          lv_stamp    TYPE timestamp,
          lv_date     TYPE d,
          lv_time     TYPE t,
          ls_error    TYPE zprt_doc_error,
          ls_event    TYPE ty_event.
    CLEAR: es_response, ev_error.
    SPLIT iv_line AT ';' INTO TABLE lt_fields.


    lv_offset = strlen( iv_line ) - 1.
    IF lv_offset >= 0.
      IF iv_line+lv_offset(1) = ';'.
        APPEND INITIAL LINE TO lt_fields.
      ENDIF.
    ENDIF.

    DESCRIBE TABLE lt_fields LINES lv_lines.
    IF lv_lines < 18.
      ev_error = 'Az Inspire-válasz 18 mező helyett csonka sort tartalmaz.'.
      RETURN.
    ENDIF.
    READ TABLE lt_fields INTO lv_field INDEX 1.
    IF lv_field IS INITIAL OR strlen( lv_field ) > 20.
      ev_error = 'Érvénytelen dokumentumazonosító az Inspire-válaszban.'.
      RETURN.
    ENDIF.
    es_response-doc_no = lv_field.
    READ TABLE lt_fields INTO es_response-filename INDEX 2.
    DO 14 TIMES.
      lv_index = sy-index + 2.
      lv_offset = sy-index - 1.
      READ TABLE lt_fields INTO lv_field INDEX lv_index.
      CHECK lv_field IS NOT INITIAL.
      IF strlen( lv_field ) <> 14 OR lv_field CN '0123456789'.
        ev_error = 'Érvénytelen státusz-időbélyeg az Inspire-válaszban.'.
        RETURN.
      ENDIF.
      lv_stamp = lv_field.
      CONVERT TIME STAMP lv_stamp TIME ZONE 'UTC'
        INTO DATE lv_date TIME lv_time.
      IF sy-subrc <> 0.
        ev_error = 'Érvénytelen státuszdátum az Inspire-válaszban.'.
        RETURN.
      ENDIF.
      ls_event-status = lc_statuses+lv_offset(1).
      ls_event-stamp = lv_field.
      APPEND ls_event TO es_response-events.
    ENDDO.
    READ TABLE lt_fields INTO es_response-error_code INDEX 17.
    READ TABLE lt_fields INTO es_response-error_text INDEX 18.
    " Semicolons after field 17 belong to the error text.
    LOOP AT lt_fields INTO lv_field FROM 19.
      CONCATENATE es_response-error_text lv_field
        INTO es_response-error_text SEPARATED BY ';'.
    ENDLOOP.
    DESCRIBE FIELD ls_error-error_code LENGTH lv_limit IN CHARACTER MODE.
    IF strlen( es_response-error_code ) > lv_limit.
      ev_error = 'Az Inspire-hibakód nem fér el a ZPRT_DOC_ERROR mezőben.'.
      RETURN.
    ENDIF.
    DESCRIBE FIELD ls_error-error_text LENGTH lv_limit IN CHARACTER MODE.
    IF strlen( es_response-error_text ) > lv_limit.
      ev_error = 'Az Inspire-hibaszöveg nem fér el a ZPRT_DOC_ERROR mezőben.'.
    ENDIF.
  ENDMETHOD.

  METHOD print_file.
    DATA: lt_parts TYPE STANDARD TABLE OF string,
          lv_file  TYPE string,
          lv_text  TYPE string,
          lv_limit TYPE i,
          lv_lines TYPE i.
    CLEAR: ev_file, ev_change, ev_error.
    " PACKAGE_ID already identifies the spool; only PRDFILE is derived.
    CHECK iv_channel = 'PR'.
    CHECK iv_filename IS NOT INITIAL.
    SPLIT iv_filename AT '_' INTO TABLE lt_parts.
    DESCRIBE TABLE lt_parts LINES lv_lines.
    " The legacy electronic/no-output-file path has no sixth tag.
    IF lv_lines < 6.
      RETURN.
    ENDIF.
    READ TABLE lt_parts INTO lv_text INDEX 6.
    CHECK lv_text IS NOT INITIAL.
    READ TABLE lt_parts INTO lv_file INDEX 8.
    IF lv_file IS INITIAL.
      ev_error = 'Hiányzó fájlsorszám az Inspire-fájlnévben.'.
      RETURN.
    ENDIF.
    CONCATENATE iv_doc_cat lv_file INTO lv_text SEPARATED BY '_'.
    DESCRIBE FIELD ev_file LENGTH lv_limit IN CHARACTER MODE.
    IF strlen( lv_text ) > lv_limit.
      ev_error = 'A nyomtatási fájl értéke túl hosszú a PRDFILE mezőhöz.'.
      RETURN.
    ENDIF.
    ev_file = lv_text.
    ev_change = abap_true.
  ENDMETHOD.

ENDCLASS.

FORM run.
  DATA: ls_stock TYPE zprt_stock,
        lx_fault TYPE REF TO cx_ai_system_fault,
        lv_error TYPE string.
  SELECT * FROM zprt_stock INTO TABLE gt_stock
    WHERE stock_id IN so_stock AND status = 'CL'. "abap_true'.
  IF gt_stock IS INITIAL.
    MESSAGE TEXT-103 TYPE 'S'.
    RETURN.
  ENDIF.
  PERFORM open_log CHANGING lv_error.
  IF lv_error IS NOT INITIAL.
    MESSAGE lv_error TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  TRY.
      CREATE OBJECT go_proxy EXPORTING logical_port_name = p_lport.
    CATCH cx_ai_system_fault INTO lx_fault.
      lv_error = lx_fault->get_text( ).
      PERFORM add_log USING 'E' space space lv_error.
      PERFORM close_log.
      RETURN.
  ENDTRY.
  LOOP AT gt_stock INTO ls_stock.
    PERFORM process_stock USING ls_stock-stock_id.
  ENDLOOP.
  PERFORM close_log.
ENDFORM.

FORM process_stock USING iv_stock TYPE zprt_stock-stock_id.
  DATA: lv_error TYPE string,
        lx_error TYPE REF TO cx_root.
  CALL FUNCTION 'ENQUEUE_EZPRT_STOCK'
    EXPORTING
      stock_id       = iv_stock
      _scope         = '1'
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    PERFORM add_log USING 'E' iv_stock space 'A stock zárolása sikertelen.'.
    RETURN.
  ENDIF.
  TRY.
      PERFORM process_locked_stock USING iv_stock.
    CATCH cx_root INTO lx_error.
      ROLLBACK WORK.
      lv_error = lx_error->get_text( ).
      PERFORM add_log USING 'E' iv_stock space lv_error.
  ENDTRY.
  CALL FUNCTION 'DEQUEUE_EZPRT_STOCK'
    EXPORTING
      stock_id = iv_stock
      _scope   = '1'.
ENDFORM.

FORM process_locked_stock USING iv_stock TYPE zprt_stock-stock_id.
  DATA: ls_stock     TYPE zprt_stock,
        lt_document  TYPE ty_document_tab,
        ls_document  TYPE ty_document,
        lt_requested TYPE ty_docno_tab,
        lt_seen      TYPE ty_docno_tab,
        lt_response  TYPE ty_response_tab,
        ls_response  TYPE ty_response,
        ls_input     TYPE zpr_eon_forms_query_doc_detai3,
        ls_output    TYPE zpr_eon_forms_query_doc_detai2,
        lv_line      TYPE string,
        lv_id        TYPE string,
        lv_error     TYPE string,
        lv_terminal  TYPE abap_bool,
        lv_missing   TYPE i,
        lv_count     TYPE i,
        lv_text      TYPE string,
        lx_fault     TYPE REF TO cx_ai_system_fault.
  SELECT SINGLE * FROM zprt_stock INTO ls_stock
    WHERE stock_id = iv_stock.
  IF sy-subrc <> 0 OR ls_stock-closed <> abap_true
    OR ls_stock-status <> 'CL'.
    PERFORM add_log USING 'E' iv_stock space 'A stock még nem lezárt.'.
    RETURN.
  ENDIF.
  " DCQM and DOC_LOG share the DOC_NO assigned at document creation.
  SELECT dcqm~doc_no dcqm~package_id doclog~doc_no AS log_doc_no
         dcqm~envelope dcqm~doc_cat doclog~channel doclog~doc_type
         doclog~opbel doclog~bukrs doclog~sparte
    FROM zprt_dcqm AS dcqm
    INNER JOIN zprt_package AS package
      ON package~package_id = dcqm~package_id
    LEFT OUTER JOIN zprt_doc_log AS doclog
      ON doclog~doc_no = dcqm~doc_no
    INTO CORRESPONDING FIELDS OF TABLE lt_document
    WHERE package~stock_id = iv_stock.
  IF lt_document IS INITIAL.
    PERFORM add_log USING 'I' iv_stock space 'A stockhoz nincs dokumentum.'.
    RETURN.
  ENDIF.
  LOOP AT lt_document INTO ls_document.
    IF ls_document-doc_no IS INITIAL OR
       ls_document-log_doc_no <> ls_document-doc_no OR
       ls_document-channel IS INITIAL.
      PERFORM add_log USING 'E' iv_stock ls_document-doc_no
        'Hiányzó vagy eltérő DOC_NO dokumentumkapcsolat, illetve csatorna.'.
      RETURN.
    ENDIF.
    INSERT ls_document-doc_no INTO TABLE lt_seen.
    IF sy-subrc <> 0.
      PERFORM add_log USING 'E' iv_stock ls_document-doc_no
        'A dokumentum több DCQM-sorban szerepel; automatikusan nem választható.'.
      RETURN.
    ENDIF.
    PERFORM is_terminal USING ls_document-doc_no
      CHANGING lv_terminal.
    CHECK lv_terminal = abap_false.
    INSERT ls_document-doc_no INTO TABLE lt_requested.
    lv_id = ls_document-doc_no.
    APPEND lv_id TO ls_input-docs-i.
  ENDLOOP.
  IF lt_requested IS INITIAL.
    PERFORM add_log USING 'I' iv_stock space
      'Nincs újra lekérendő dokumentum; a tárolt végállapotok megmaradtak.'.
    PERFORM update_stock_delivery USING iv_stock.
    RETURN.
  ENDIF.
  ls_input-sap_system = sy-sysid.
  ls_input-sap_mandant = sy-mandt.
  ls_input-stock_id = iv_stock.
  TRY.
      go_proxy->eon_forms_query_doc_details(
        EXPORTING input = ls_input IMPORTING output = ls_output ).
    CATCH cx_ai_system_fault INTO lx_fault.
      lv_error = lx_fault->get_text( ).
      PERFORM add_log USING 'E' iv_stock space lv_error.
      RETURN.
  ENDTRY.
  IF ls_output-success <> abap_true.
    CONCATENATE ls_output-error_code ls_output-info INTO lv_error
      SEPARATED BY space.
    PERFORM add_log USING 'E' iv_stock space lv_error.
    RETURN.
  ENDIF.
  " Validate the full response before starting any document transaction.
  LOOP AT ls_output-docs-d INTO lv_line.
    lcl_response=>parse( EXPORTING iv_line = lv_line
      IMPORTING es_response = ls_response ev_error = lv_error ).
    IF lv_error IS NOT INITIAL.
      PERFORM add_log USING 'E' iv_stock ls_response-doc_no lv_error.
      RETURN.
    ENDIF.
    READ TABLE lt_requested TRANSPORTING NO FIELDS
      WITH TABLE KEY table_line = ls_response-doc_no.
    IF sy-subrc <> 0.
      PERFORM add_log USING 'E' iv_stock ls_response-doc_no
        'Az Inspire nem kért dokumentumot adott vissza; a stock mentése elmarad.'.
      RETURN.
    ENDIF.
    INSERT ls_response INTO TABLE lt_response.
    IF sy-subrc <> 0.
      PERFORM add_log USING 'E' iv_stock ls_response-doc_no
        'Ismétlődő dokumentum az Inspire-válaszban; a stock mentése elmarad.'.
      RETURN.
    ENDIF.
  ENDLOOP.
  DESCRIBE TABLE lt_requested LINES lv_missing.
  DESCRIBE TABLE lt_response LINES lv_count.
  lv_missing = lv_missing - lv_count.
  IF lv_missing > 0.
    lv_text = lv_missing.
    CONCATENATE 'Ennyi kért dokumentum hiányzik a válaszból:' lv_text
      INTO lv_text SEPARATED BY space.
    PERFORM add_log USING 'W' iv_stock space lv_text.
  ENDIF.
  LOOP AT lt_response INTO ls_response.
    READ TABLE lt_document INTO ls_document
      WITH KEY doc_no = ls_response-doc_no.
    CHECK sy-subrc = 0.
    PERFORM process_document USING iv_stock ls_document ls_response.
  ENDLOOP.
*  PERFORM add_log USING 'I' iv_stock space
*    'Stocklekérdezés vége; a CL stockstátusz változatlan.'.
  PERFORM update_stock_delivery USING iv_stock.

ENDFORM.

FORM update_stock_delivery USING iv_stock TYPE zprt_stock-stock_id.
  DATA: lv_total        TYPE i,
        lv_missing      TYPE i,
        lv_total_text   TYPE c LENGTH 12,
        lv_missing_text TYPE c LENGTH 12,
        lv_text         TYPE string.
  "Use the complete stock/package document set, including documents without logs.
  SELECT COUNT( DISTINCT dcqm~doc_no )
    FROM zprt_dcqm AS dcqm
    INNER JOIN zprt_package AS package
      ON package~package_id = dcqm~package_id
    INTO lv_total
    WHERE package~stock_id = iv_stock.
  IF lv_total = 0.
    PERFORM add_log USING 'W' iv_stock space text-201.
    RETURN.
  ENDIF.
  "A historical D event is sufficient; other events do not count as delivery.
  SELECT COUNT( DISTINCT dcqm~doc_no )
    FROM zprt_dcqm AS dcqm
    INNER JOIN zprt_package AS package
      ON package~package_id = dcqm~package_id
    INTO lv_missing
    WHERE package~stock_id = iv_stock
      AND NOT EXISTS ( SELECT * FROM zprt_doc_slog AS slog
        WHERE slog~exbilldocno = dcqm~doc_no
          AND slog~status = 'D' ).
  IF lv_missing > 0.
    WRITE lv_total TO lv_total_text LEFT-JUSTIFIED.
    WRITE lv_missing TO lv_missing_text LEFT-JUSTIFIED.
    CONCATENATE text-202 lv_missing_text text-203 lv_total_text
      INTO lv_text SEPARATED BY space.
    PERFORM add_log USING 'W' iv_stock space lv_text.
    RETURN.
  ENDIF.
  "The caller holds the stock lock across the document commits and this update.
  UPDATE zprt_stock
    SET status = 'AD'
        chuser = sy-uname chdate = sy-datum chtime = sy-uzeit
    WHERE stock_id = iv_stock
      AND status = 'CL'
      AND closed = abap_true.
  IF sy-subrc <> 0 OR sy-dbcnt <> 1.
    ROLLBACK WORK.
    PERFORM add_log USING 'E' iv_stock space text-205.
    RETURN.
  ENDIF.
  COMMIT WORK AND WAIT.
  IF sy-subrc <> 0.
    PERFORM add_log USING 'E' iv_stock space text-206.
    RETURN.
  ENDIF.
  PERFORM add_log USING 'S' iv_stock space text-204.
ENDFORM.

FORM is_terminal USING iv_doc TYPE zprt_dcqm-doc_no
                 CHANGING cv_terminal TYPE abap_bool.
  DATA: lv_code   TYPE zprt_doc_error-error_code,
        lv_status TYPE zprt_doc_slog-status.
  cv_terminal = abap_false.
  SELECT SINGLE error_code FROM zprt_doc_error INTO lv_code
    WHERE exbilldocno = iv_doc.
  IF sy-subrc = 0 AND lv_code IS NOT INITIAL.
    cv_terminal = abap_true.
    RETURN.
  ENDIF.
  IF p_stat = abap_false.
    SELECT SINGLE status FROM zprt_doc_slog INTO lv_status
      WHERE exbilldocno = iv_doc AND status = 'D'.
    IF sy-subrc = 0.
      cv_terminal = abap_true.
    ENDIF.
  ENDIF.
ENDFORM.

FORM process_document USING iv_stock TYPE zprt_stock-stock_id
                            is_document TYPE ty_document
                            is_response TYPE ty_response.
  DATA: lv_key       TYPE rstable-varkey,
        lv_regkey    TYPE rstable-varkey,
        lv_error     TYPE string,
        lv_terminal  TYPE abap_bool,
        lv_reglocked TYPE abap_bool,
        lt_old       TYPE ty_slog_tab,
        lx_error     TYPE REF TO cx_root.
  IF is_response-events IS INITIAL AND is_response-error_code IS INITIAL.
    PERFORM add_log USING 'I' iv_stock is_document-doc_no
      'A dokumentumhoz még nincs Inspire-státusz; feldolgozandó marad.'.
    RETURN.
  ENDIF.
  CONCATENATE sy-mandt is_document-doc_no INTO lv_key
    RESPECTING BLANKS.
  PERFORM lock_rows USING 'ZPRT_DOC_SLOG' lv_key CHANGING lv_error.
  IF lv_error IS NOT INITIAL.
    PERFORM add_log USING 'E' iv_stock is_document-doc_no lv_error.
    RETURN.
  ENDIF.
  TRY.
      PERFORM is_terminal USING is_document-doc_no CHANGING lv_terminal.
      IF lv_terminal = abap_false.
        SELECT * FROM zprt_doc_slog INTO TABLE lt_old
          WHERE exbilldocno = is_document-doc_no.
        IF is_response-error_code IS NOT INITIAL.
          lv_regkey = sy-mandt.
          PERFORM lock_rows USING 'ZPR_TERTI' lv_regkey
            CHANGING lv_error.
          IF lv_error IS INITIAL.
            lv_reglocked = abap_true.
          ENDIF.
        ENDIF.
        IF lv_error IS INITIAL.
          PERFORM save_document USING iv_stock is_document is_response lt_old
            CHANGING lv_error.
        ENDIF.
        IF lv_error IS INITIAL.
          COMMIT WORK AND WAIT.
          IF sy-subrc <> 0.
            lv_error = 'Az update task hibás; ellenőrizze az SM13 naplót.'.
          ELSE.
            PERFORM add_log USING 'S' iv_stock is_document-doc_no
              'A dokumentum státuszai és követő műveletei mentve.'.
          ENDIF.
        ELSE.
          ROLLBACK WORK.
        ENDIF.
      ENDIF.
    CATCH cx_root INTO lx_error.
      ROLLBACK WORK.
      lv_error = lx_error->get_text( ).
  ENDTRY.
  IF lv_reglocked = abap_true.
    PERFORM unlock_rows USING 'ZPR_TERTI' lv_regkey.
  ENDIF.
  PERFORM unlock_rows USING 'ZPRT_DOC_SLOG' lv_key.
  IF lv_error IS NOT INITIAL.
    PERFORM add_log USING 'E' iv_stock is_document-doc_no lv_error.
  ENDIF.
ENDFORM.

FORM save_document USING iv_stock TYPE zprt_stock-stock_id
                         is_document TYPE ty_document
                         is_response TYPE ty_response
                         it_old TYPE ty_slog_tab
                   CHANGING cv_error TYPE string.
  DATA: ls_event  TYPE ty_event,
        ls_slog   TYPE zprt_doc_slog,
        ls_error  TYPE zprt_doc_error,
        lv_doc_no TYPE zprt_dcqm-doc_no,
        lv_file   TYPE zprt_dcqm-prdfile,
        lv_change TYPE abap_bool,
        lv_detail TYPE string.
  CLEAR cv_error.
*  SELECT SINGLE dcqm~guid FROM zprt_dcqm AS dcqm
*   INNER JOIN zprt_package AS package
*      ON package~package_id = dcqm~package_id
*    INTO lv_guid
*    WHERE dcqm~guid = is_document-guid AND dcqm~doc_no = is_document-doc_no
*      AND dcqm~package_id = is_document-package_id
*      AND package~stock_id = iv_stock.
*  IF sy-subrc <> 0.
*    cv_error = 'A dokumentum stock-hozzárendelése megváltozott.'.
*    RETURN.
*  ENDIF.

  lcl_response=>print_file(
    EXPORTING iv_channel = is_document-channel
              iv_doc_cat = is_document-doc_cat
              iv_filename = is_response-filename
    IMPORTING ev_file = lv_file
              ev_change = lv_change ev_error = cv_error ).
  CHECK cv_error IS INITIAL.

* DHC: UPD_ESZLA, UPD_BC_STAT and UPD_PUSH_MSG are intentionally disabled.
* Their original implementations and call conditions are retained below.
* No equivalent DHC objects were found; enable only after integration.

  IF is_response-error_code IS NOT INITIAL.
    PERFORM save_regmail USING is_document CHANGING cv_error.
    CHECK cv_error IS INITIAL.
  ENDIF.
  READ TABLE is_response-events TRANSPORTING NO FIELDS WITH KEY status = 'A'.
  IF sy-subrc = 0.
    READ TABLE it_old TRANSPORTING NO FIELDS WITH KEY status = 'A'.
    IF sy-subrc <> 0.
      PERFORM save_archive USING is_document is_response CHANGING cv_error.
      CHECK cv_error IS INITIAL.
    ENDIF.
  ENDIF.
  IF lv_change = abap_true.
    " Preserve the existing package/spool assignment.
    UPDATE zprt_dcqm SET prdfile = lv_file
                        chuser = sy-uname chdate = sy-datum chtime = sy-uzeit
      WHERE doc_no = is_document-doc_no
        AND package_id = is_document-package_id
        AND EXISTS ( SELECT * FROM zprt_package AS package
          WHERE package~package_id = is_document-package_id
            AND package~stock_id = iv_stock ).
    IF sy-subrc <> 0.
      cv_error = 'A DHC nyomtatási hivatkozások mentése sikertelen.'.
      RETURN.
    ENDIF.
  ENDIF.
  LOOP AT is_response-events INTO ls_event.
    READ TABLE it_old TRANSPORTING NO FIELDS
      WITH KEY timestamp = ls_event-stamp status = ls_event-status.
    CHECK sy-subrc <> 0.
    CLEAR ls_slog.
    ls_slog-mandt = sy-mandt.
    ls_slog-exbilldocno = is_document-doc_no.
    ls_slog-timestamp = ls_event-stamp.
    ls_slog-status = ls_event-status.
    INSERT zprt_doc_slog FROM ls_slog.
    IF sy-subrc <> 0.
      cv_error = 'A dokumentumstátusz mentése sikertelen.'.
      RETURN.
    ENDIF.
  ENDLOOP.
  IF is_response-error_code IS NOT INITIAL.
    ls_error-mandt = sy-mandt.
    ls_error-exbilldocno = is_document-doc_no.
    ls_error-error_code = is_response-error_code.
    ls_error-error_text = is_response-error_text.
    MODIFY zprt_doc_error FROM ls_error.
    IF sy-subrc <> 0.
      cv_error = 'A dokumentumhiba mentése sikertelen.'.
      RETURN.
    ENDIF.
  ENDIF.
  IF p_det = abap_true.
    LOOP AT is_response-events INTO ls_event.
      CONCATENATE ls_event-status ls_event-stamp INTO lv_detail
        SEPARATED BY ':'.
      PERFORM add_log USING 'I' iv_stock is_document-doc_no lv_detail.
    ENDLOOP.
    IF is_response-filename IS NOT INITIAL.
      PERFORM add_log USING 'I' iv_stock is_document-doc_no is_response-filename.
    ENDIF.
    IF is_response-error_code IS NOT INITIAL.
      CONCATENATE is_response-error_code is_response-error_text
        INTO lv_detail SEPARATED BY ':'.
      PERFORM add_log USING 'E' iv_stock is_document-doc_no lv_detail.
    ENDIF.
  ENDIF.
ENDFORM.

FORM save_regmail USING is_document TYPE ty_document
                  CHANGING cv_error TYPE string.
  DATA: lt_terti   TYPE STANDARD TABLE OF zpr_terti,
        ls_terti   TYPE zpr_terti,
        lt_regmail TYPE SORTED TABLE OF zpr_terti-zisu_ragszam_128
                   WITH UNIQUE KEY table_line,
        lv_regmail TYPE zpr_terti-zisu_ragszam_128,
        lv_count   TYPE i.

  SELECT * FROM zpr_terti INTO TABLE lt_terti
    WHERE envelope_id = is_document-envelope
      AND exbilldocno = is_document-doc_no.

  CHECK lt_terti IS NOT INITIAL.
  LOOP AT lt_terti INTO ls_terti.
    IF ls_terti-zisu_ragszam_128 IS NOT INITIAL.
      INSERT ls_terti-zisu_ragszam_128 INTO TABLE lt_regmail.
    ENDIF.
  ENDLOOP.

  DELETE zpr_terti FROM TABLE lt_terti.
*  DELETE FROM zpr_terti
*   WHERE envelope_id EQ ls_pr_terti-envelope_id
*     AND exbilldocno EQ ls_pr_terti-exbilldocno.

  IF sy-subrc <> 0.
    cv_error = 'A dokumentum tértivevény-sorainak törlése sikertelen.'.
    RETURN.
  ENDIF.
  LOOP AT lt_regmail INTO lv_regmail.
    SELECT COUNT( * ) FROM zpr_terti INTO lv_count
      WHERE zisu_ragszam_128 = lv_regmail.
    IF lv_count = 0.
      DELETE FROM zisu_f064 WHERE zisu_ragszam = lv_regmail.
      " An already absent F064 row is harmless.
      IF sy-subrc <> 0 AND sy-subrc <> 4.
        cv_error = 'A már nem használt F064-ragszám törlése sikertelen.'.
        RETURN.
      ENDIF.
    ENDIF.
  ENDLOOP.
ENDFORM.

FORM save_archive USING is_document TYPE ty_document
                        is_response TYPE ty_response
                  CHANGING cv_error TYPE string.
  DATA ls_link TYPE zprt_arch_link.
  SELECT SINGLE * FROM zprt_arch_link INTO ls_link
    WHERE doc_no = is_document-doc_no.
  CHECK sy-subrc = 0.
  IF is_response-error_code IS INITIAL.
    CALL FUNCTION 'ARCHIV_CONNECTION_INSERT'
      EXPORTING
        arc_doc_id            = ls_link-xsapdocid
        ar_object             = ls_link-xsapdocumenttype
        object_id             = ls_link-xsapobjectid
        sap_object            = ls_link-xsapobject
      EXCEPTIONS
        error_connectiontable = 1
        OTHERS                = 2.
    IF sy-subrc <> 0.
      cv_error = 'Az ArchiveLink-kapcsolat létrehozása sikertelen.'.
      RETURN.
    ENDIF.
    UPDATE zprt_doc_log SET archived = abap_true
                           chuser = sy-uname chdate = sy-datum chtime = sy-uzeit
      WHERE doc_no = is_document-doc_no.
    IF sy-subrc <> 0.
      cv_error = 'Az archiválási jelző mentése sikertelen.'.
      RETURN.
    ENDIF.
  ENDIF.
  DELETE FROM zprt_arch_link WHERE doc_no = is_document-doc_no.
  IF sy-subrc <> 0.
    cv_error = 'Az átmeneti archív kapcsolat törlése sikertelen.'.
  ENDIF.
ENDFORM.

FORM open_log CHANGING cv_error TYPE string.
  DATA ls_log TYPE bal_s_log.
  CLEAR: cv_error, gv_log_error.
  ls_log-object = 'ZPR_MASS'.
  ls_log-subobject = 'DOC'.
  ls_log-aldate = sy-datum.
  ls_log-altime = sy-uzeit.
  ls_log-aluser = sy-uname.
  ls_log-alprog = sy-repid.
  CONCATENATE sy-datum sy-uzeit INTO ls_log-extnumber SEPARATED BY '_'.
  CALL FUNCTION 'BAL_LOG_CREATE'
    EXPORTING
      i_s_log                 = ls_log
    IMPORTING
      e_log_handle            = gv_log_handle
    EXCEPTIONS
      log_header_inconsistent = 1
      OTHERS                  = 2.
  IF sy-subrc <> 0.
    cv_error = 'A ZPR_MASS/STOCK alkalmazási napló nem hozható létre.'.
  ENDIF.
ENDFORM.

FORM add_log USING iv_type TYPE clike iv_stock TYPE clike
                   iv_doc TYPE clike iv_text TYPE clike.
  DATA: lv_type   TYPE symsgty,
        lv_text   TYPE string,
        lv_chunk  TYPE c LENGTH 200,
        lv_length TYPE i.
  lv_type = iv_type.
  CONCATENATE iv_stock iv_doc iv_text INTO lv_text SEPARATED BY space.
  WHILE lv_text IS NOT INITIAL.
    lv_length = strlen( lv_text ).
    IF lv_length > 200.
      lv_length = 200.
    ENDIF.
    lv_chunk = lv_text(lv_length).
    CALL FUNCTION 'BAL_LOG_MSG_ADD_FREE_TEXT'
      EXPORTING
        i_log_handle     = gv_log_handle
        i_msgty          = lv_type
        i_text           = lv_chunk
      EXCEPTIONS
        log_not_found    = 1
        msg_inconsistent = 2
        log_is_full      = 3
        OTHERS           = 4.
    IF sy-subrc <> 0.
      gv_log_error = abap_true.
      RETURN.
    ENDIF.
    lv_text = lv_text+lv_length.
  ENDWHILE.
ENDFORM.

FORM close_log.
  DATA lt_handles TYPE bal_t_logh.

  INSERT gv_log_handle INTO TABLE lt_handles.

  CALL FUNCTION 'BAL_DB_SAVE'
    EXPORTING
      i_t_log_handle   = lt_handles
    EXCEPTIONS
      log_not_found    = 1
      save_not_allowed = 2
      numbering_error  = 3
      OTHERS           = 4.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    gv_log_error = abap_true.
  ELSE.
    COMMIT WORK AND WAIT.
    IF sy-subrc <> 0.
      gv_log_error = abap_true.
    ENDIF.
  ENDIF.
  IF sy-batch IS INITIAL.
    CALL FUNCTION 'BAL_DSP_LOG_DISPLAY'
      EXPORTING
        i_t_log_handle       = lt_handles
      EXCEPTIONS
        profile_inconsistent = 1
        internal_error       = 2
        no_data_available    = 3
        no_authority         = 4
        OTHERS               = 5.
    IF sy-subrc <> 0.
      gv_log_error = abap_true.
    ENDIF.
  ENDIF.
  IF gv_log_error = abap_true.
    MESSAGE TEXT-104 TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

FORM lock_rows USING iv_table TYPE clike iv_key TYPE clike
               CHANGING cv_error TYPE string.
  DATA: lv_table TYPE tabname,
        lv_key   TYPE rstable-varkey.
  CLEAR cv_error.
  lv_table = iv_table.
  lv_key = iv_key.
  CALL FUNCTION 'ENQUEUE_E_TABLE'
    EXPORTING
      tabname        = lv_table
      varkey         = lv_key
      _scope         = '1'
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    CONCATENATE 'Nem zárolható:' lv_table INTO cv_error SEPARATED BY space.
  ENDIF.
ENDFORM.

FORM unlock_rows USING iv_table TYPE clike iv_key TYPE clike.
  DATA: lv_table TYPE tabname,
        lv_key   TYPE rstable-varkey.
  lv_table = iv_table.
  lv_key = iv_key.
  CALL FUNCTION 'DEQUEUE_E_TABLE'
    EXPORTING
      tabname = lv_table
      varkey  = lv_key
      _scope  = '1'.
ENDFORM.

*----------------------------------------------------------------------*
CLASS ltc_response DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-METHODS fixture RETURNING VALUE(rv_line) TYPE string.
    METHODS valid_statuses FOR TESTING.
    METHODS truncated_row FOR TESTING.
    METHODS invalid_timestamp FOR TESTING.
    METHODS same_stamp_two_statuses FOR TESTING.
    METHODS all_statuses_same_stamp FOR TESTING.
    METHODS long_document FOR TESTING.
    METHODS semicolon_error_text FOR TESTING.
    METHODS print_shop_refs FOR TESTING.
    METHODS base_printout_refs FOR TESTING.
    METHODS no_output_file FOR TESTING.
    METHODS oversized_refs FOR TESTING.
    METHODS legacy_spool_ignored FOR TESTING.
ENDCLASS.

CLASS ltc_response IMPLEMENTATION.
  METHOD fixture.
    DATA: lt_fields TYPE STANDARD TABLE OF string,
          lv_text   TYPE string.
    DO 18 TIMES.
      APPEND INITIAL LINE TO lt_fields.
    ENDDO.
    lv_text = 'DOC1'.
    MODIFY lt_fields FROM lv_text INDEX 1.
    lv_text = '20261015100000'.
    MODIFY lt_fields FROM lv_text INDEX 3.
    lv_text = '20261015100100'.
    MODIFY lt_fields FROM lv_text INDEX 14.
    CONCATENATE LINES OF lt_fields INTO rv_line SEPARATED BY ';'.
  ENDMETHOD.

  METHOD valid_statuses.
    DATA: ls_response TYPE ty_response, ls_event TYPE ty_event,
          lv_error    TYPE string, lv_count TYPE i.
    lcl_response=>parse( EXPORTING iv_line = fixture( )
      IMPORTING es_response = ls_response ev_error = lv_error ).
    cl_abap_unit_assert=>assert_initial( act = lv_error ).
    cl_abap_unit_assert=>assert_equals( act = ls_response-doc_no exp = 'DOC1' ).
    DESCRIBE TABLE ls_response-events LINES lv_count.
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 2 ).
    READ TABLE ls_response-events INTO ls_event WITH KEY status = 'D'.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_event-stamp exp = '20261015100100' ).
  ENDMETHOD.

  METHOD truncated_row.
    DATA: ls_response TYPE ty_response, lv_error TYPE string.
    lcl_response=>parse( EXPORTING iv_line = 'DOC1;file;20261015100000'
      IMPORTING es_response = ls_response ev_error = lv_error ).
    cl_abap_unit_assert=>assert_not_initial( act = lv_error ).
  ENDMETHOD.

  METHOD invalid_timestamp.
    DATA: ls_response TYPE ty_response, lv_error TYPE string,
          lv_line     TYPE string.
    lv_line = fixture( ).
    REPLACE FIRST OCCURRENCE OF '20261015100000' IN lv_line
      WITH '20261315100000'.
    lcl_response=>parse( EXPORTING iv_line = lv_line
      IMPORTING es_response = ls_response ev_error = lv_error ).
    cl_abap_unit_assert=>assert_not_initial( act = lv_error ).
  ENDMETHOD.

  METHOD same_stamp_two_statuses.
    DATA: ls_response TYPE ty_response, ls_event TYPE ty_event,
          lv_error    TYPE string, lv_line TYPE string, lv_count TYPE i.
    lv_line = fixture( ).
    REPLACE FIRST OCCURRENCE OF '20261015100100' IN lv_line
      WITH '20261015100000'.
    lcl_response=>parse( EXPORTING iv_line = lv_line
      IMPORTING es_response = ls_response ev_error = lv_error ).
    " Az azonos időbélyegű, eltérő státuszú pár érvényes: hiba nincs, két esemény.
    cl_abap_unit_assert=>assert_initial( act = lv_error ).
    DESCRIBE TABLE ls_response-events LINES lv_count.
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 2 ).
    READ TABLE ls_response-events INTO ls_event WITH KEY status = 'R'.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_event-stamp exp = '20261015100000' ).
    READ TABLE ls_response-events INTO ls_event WITH KEY status = 'D'.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_event-stamp exp = '20261015100000' ).
  ENDMETHOD.

  METHOD all_statuses_same_stamp.
    DATA: ls_response TYPE ty_response, ls_event TYPE ty_event,
          lt_fields   TYPE STANDARD TABLE OF string,
          lv_text     TYPE string, lv_line TYPE string,
          lv_error    TYPE string, lv_index TYPE i, lv_count TYPE i.
    DO 18 TIMES.
      APPEND INITIAL LINE TO lt_fields.
    ENDDO.
    lv_text = 'DOC1'.
    MODIFY lt_fields FROM lv_text INDEX 1.
    lv_text = '20261015100000'.
    DO 14 TIMES.
      lv_index = sy-index + 2.
      MODIFY lt_fields FROM lv_text INDEX lv_index.
    ENDDO.
    CONCATENATE LINES OF lt_fields INTO lv_line SEPARATED BY ';'.
    lcl_response=>parse( EXPORTING iv_line = lv_line
      IMPORTING es_response = ls_response ev_error = lv_error ).
    " Mind a 14 státusz ugyanazzal az időbélyeggel: hiba nincs, 14 különböző státusz.
    cl_abap_unit_assert=>assert_initial( act = lv_error ).
    DESCRIBE TABLE ls_response-events LINES lv_count.
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 14 ).
    READ TABLE ls_response-events INTO ls_event INDEX 1.
    cl_abap_unit_assert=>assert_equals( act = ls_event-status exp = 'R' ).
    READ TABLE ls_response-events INTO ls_event INDEX 14.
    cl_abap_unit_assert=>assert_equals( act = ls_event-status exp = 'V' ).
  ENDMETHOD.

  METHOD long_document.
    DATA: ls_response TYPE ty_response, lv_error TYPE string,
          lv_line     TYPE string.
    lv_line = fixture( ).
    REPLACE FIRST OCCURRENCE OF 'DOC1' IN lv_line
      WITH '123456789012345678901'.
    lcl_response=>parse( EXPORTING iv_line = lv_line
      IMPORTING es_response = ls_response ev_error = lv_error ).
    cl_abap_unit_assert=>assert_not_initial( act = lv_error ).
  ENDMETHOD.

  METHOD semicolon_error_text.
    DATA: ls_response TYPE ty_response, lv_error TYPE string,
          lv_line     TYPE string.
    lv_line = fixture( ).
    CONCATENATE lv_line 'hiba;reszlet' INTO lv_line.
    lcl_response=>parse( EXPORTING iv_line = lv_line
      IMPORTING es_response = ls_response ev_error = lv_error ).
    cl_abap_unit_assert=>assert_initial( act = lv_error ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_response-error_text exp = 'hiba;reszlet' ).
  ENDMETHOD.

  METHOD  print_shop_refs.
    DATA: lv_file   TYPE zprt_dcqm-prdfile,
          lv_change TYPE abap_bool, lv_error TYPE string.
    lcl_response=>print_file(
      EXPORTING iv_channel = 'PR' iv_doc_cat = 'A'
        iv_filename = 'a_b_c_d_e_0000000123_1_02_end'
      IMPORTING ev_file = lv_file
                ev_change = lv_change ev_error = lv_error ).
    cl_abap_unit_assert=>assert_initial( act = lv_error ).
    cl_abap_unit_assert=>assert_equals( act = lv_file exp = 'A_02' ).
    cl_abap_unit_assert=>assert_equals( act = lv_change exp = abap_true ).
  ENDMETHOD.

  METHOD base_printout_refs.
    DATA: lv_file   TYPE zprt_dcqm-prdfile,
          lv_change TYPE abap_bool, lv_error TYPE string.
    lcl_response=>print_file(
      EXPORTING iv_channel = 'IN' iv_doc_cat = 'A'
        iv_filename = 'a_b_c_d_e_x_y_0000000123_2_end'
      IMPORTING ev_file = lv_file
                ev_change = lv_change ev_error = lv_error ).
    cl_abap_unit_assert=>assert_initial( act = lv_error ).
    cl_abap_unit_assert=>assert_initial( act = lv_file ).
    cl_abap_unit_assert=>assert_initial( act = lv_change ).
  ENDMETHOD.

  METHOD no_output_file.
    DATA: lv_change TYPE abap_bool, lv_error TYPE string.
    lcl_response=>print_file(
      EXPORTING iv_channel = 'PR' iv_doc_cat = 'A'
                iv_filename = 'DHC_100_stock_doc.xml'
      IMPORTING ev_change = lv_change ev_error = lv_error ).
    cl_abap_unit_assert=>assert_initial( act = lv_error ).
    cl_abap_unit_assert=>assert_initial( act = lv_change ).
  ENDMETHOD.

  METHOD oversized_refs.
    DATA: lv_change TYPE abap_bool, lv_error TYPE string.
    lcl_response=>print_file(
      EXPORTING iv_channel = 'PR' iv_doc_cat = 'A'
        iv_filename = 'a_b_c_d_e_0000000123_1_123_end'
      IMPORTING ev_change = lv_change ev_error = lv_error ).
    cl_abap_unit_assert=>assert_not_initial( act = lv_error ).
    cl_abap_unit_assert=>assert_initial( act = lv_change ).
  ENDMETHOD.


  METHOD legacy_spool_ignored.
    DATA: lv_file   TYPE zprt_dcqm-prdfile,
          lv_change TYPE abap_bool, lv_error TYPE string.
    lcl_response=>print_file(
      EXPORTING iv_channel = 'PR' iv_doc_cat = 'A'
        iv_filename = 'a_b_c_d_e_notnumeric_12345678901234567890_02_end'
      IMPORTING ev_file = lv_file
                ev_change = lv_change ev_error = lv_error ).
    cl_abap_unit_assert=>assert_initial( act = lv_error ).
    cl_abap_unit_assert=>assert_equals( act = lv_file exp = 'A_02' ).
    cl_abap_unit_assert=>assert_equals( act = lv_change exp = abap_true ).
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* DHC-BAN KIKAPCSOLVA:  e-számlanapló, számlahitelesítés, push üzenet.
* Az alábbi hívási feltételek és teljes FORM rutinok csak kommentként szerepelnek.
*----------------------------------------------------------------------*

* IF us_exbilldoc-destination = 'PO' AND
*    us_exbilldoc-tstmp_d IS INITIAL AND cs_response-tstmp_d IS NOT INITIAL.
*   PERFORM upd_eszla USING us_exbilldoc cs_response
*     CHANGING lv_update_hiba.
* ENDIF.

* IF us_exbilldoc-tstmp_s IS INITIAL AND cs_response-tstmp_s IS NOT INITIAL.
*   PERFORM upd_bc_stat USING us_exbilldoc
*     CHANGING cs_response lv_update_hiba.
* ENDIF.

* IF us_exbilldoc-tstmp_a IS INITIAL AND cs_response-tstmp_a IS NOT INITIAL.
*   PERFORM upd_push_msg USING us_exbilldoc
*     CHANGING cs_response lv_update_hiba.
* ENDIF.


* DHC DISABLED:  ZXWEBT_ESZLA_LOG- mentés
*--------------------------------------------------------------
* FORM upd_eszla
*   USING us_exbilldoc TYPE ty_exbilldoc
*         us_response  TYPE ty_response                       "#EC NEEDED
*   CHANGING cv_hiba TYPE flag.
*
*   DATA: ls_zxwebt_eszla_log TYPE zxwebt_eszla_log,
*         ls_eszla_log        TYPE zxwebt_eszla_log.
*
*   ls_zxwebt_eszla_log-opbel = us_exbilldoc-opbel.
*   ls_zxwebt_eszla_log-status = '3'.
*   ls_zxwebt_eszla_log-aedat = sy-datum.
*   ls_zxwebt_eszla_log-aezet = sy-uzeit.
*
*
*   CALL FUNCTION 'ENQUEUE_EZXWEBT_ESZLA_LO'
*     EXPORTING
*       mode_zxwebt_eszla_log = 'E'
*       mandt                 = sy-mandt
*       opbel                 = ls_zxwebt_eszla_log-opbel
* *     X_OPBEL               = ' '
* *     _SCOPE                = '2'
* *     _WAIT                 = ' '
* *     _COLLECT              = ' '
*     EXCEPTIONS
*       foreign_lock          = 1
*       system_failure        = 2
*       OTHERS                = 3.
*   IF sy-subrc NE 0.
*     MESSAGE e028 WITH 'ZXWEBT_ESZLA_LO' ls_zxwebt_eszla_log-opbel INTO gv_dummy.
*     PERFORM log_add_message.
*     cv_hiba = abap_true.
*
*   ELSE.
*     CLEAR ls_eszla_log.
*     SELECT SINGLE * FROM zxwebt_eszla_log
*       INTO ls_eszla_log
*      WHERE opbel EQ ls_zxwebt_eszla_log-opbel.
*     IF sy-subrc EQ 0.
*       UPDATE zxwebt_eszla_log SET status = ls_zxwebt_eszla_log-status
*                                   aedat  = ls_zxwebt_eszla_log-aedat
*                                   aezet  = ls_zxwebt_eszla_log-aezet
*        WHERE opbel EQ ls_zxwebt_eszla_log-opbel.
*     ELSE.
*       ls_zxwebt_eszla_log-erdat = sy-datum.
*       ls_zxwebt_eszla_log-erzet = sy-uzeit.
*       MODIFY zxwebt_eszla_log FROM ls_zxwebt_eszla_log.
*     ENDIF.
*
*     IF sy-subrc = 0.
*       COMMIT WORK.
*     ELSE.
*       MESSAGE e028 WITH 'ZXWEBT_ESZLA_LO' ls_zxwebt_eszla_log-opbel INTO gv_dummy.
*       PERFORM log_add_message.
*       ROLLBACK WORK.
*       cv_hiba = abap_true.
*     ENDIF.
*
*     CALL FUNCTION 'DEQUEUE_EZXWEBT_ESZLA_LO'
*       EXPORTING
*         opbel = ls_zxwebt_eszla_log-opbel.
*   ENDIF.
*
* ENDFORM.                    " UPD_ESZLA


* DHC DISABLED: Számlahitelesítés: Statisztika rekord mentés
*--------------------------------------------------------------
* FORM upd_bc_stat
*   USING us_exbilldoc TYPE ty_exbilldoc
*   CHANGING cs_response  TYPE ty_response
*            cv_hiba TYPE flag.
*
*   DATA: lv_doctype TYPE  zebid_bc_doc_type,
*         lv_docid  TYPE  zebid_bc_doc_id,
*         lv_sdate  TYPE  zebid_bc_sdate,
*         lv_stime  TYPE  zebid_bc_stime.
*
*
*   lv_docid = us_exbilldoc-opbel.
*   IF us_exbilldoc-doc_type EQ '0042'. "OR
* *     <fs_exbilldocno>-doc_type EQ '0044'. "SZÁMLÁK
*     lv_doctype = zif_ebf_pr_const=>gc_bc_stat_doctype-_sn.
*   ELSE.
*     lv_doctype = zif_ebf_pr_const=>gc_bc_stat_doctype-_en.
*   ENDIF.
*   lv_sdate  = cs_response-tstmp_s(8).
*   lv_stime  = cs_response-tstmp_s+8(6).
*
*
*   CALL FUNCTION 'Z_EBI_BILL_CERT_SAVE_STAT'
*     EXPORTING
*       iv_doctype               = lv_doctype
*       iv_docid                 = lv_docid "opbel
*       iv_sdate                 = lv_sdate
*       iv_stime                 = lv_stime
*       iv_bukrs                 = us_exbilldoc-bukrs
*       iv_sparte                = us_exbilldoc-sparte
*       iv_check_par_valid       = space
* *     IV_COMMIT                = ' '      ?????????????????????
*       iv_status                = '3'
* *     IV_GUID                  =
* *   IMPORTING
* *     EV_GUID                  =
*    EXCEPTIONS
*      missing_doctype          = 1
*      missing_docid            = 2
*      missing_bukrs            = 3
*      invalid_doctype          = 4
*      invalid_pack             = 5
*      invalid_opbel            = 6
*      invalid_bukrs            = 7
*      invalid_sparte           = 8
*      save_failed              = 9
*      invalid_guid             = 10
*      enqueue_error            = 11
*      OTHERS                   = 12
*             .
*   IF sy-subrc = 0.
*     COMMIT WORK.
*   ELSE.
*     MESSAGE e028 WITH 'ZEBIT_BC_STAT' lv_docid INTO gv_dummy.
*     PERFORM log_add_message.
*     ROLLBACK WORK.
*     cv_hiba = abap_true.
*     CLEAR cs_response-tstmp_s.
*   ENDIF.
*
* ENDFORM.                    " UPD_BC_STAT



* DHC DISABLED: Push üzenet
*--------------------------------------------------------------
* FORM upd_push_msg
*   USING us_exbilldoc TYPE ty_exbilldoc
*   CHANGING cs_response  TYPE ty_response                    "#EC NEEDED
*            cv_hiba TYPE flag.                               "#EC NEEDED
*
*   DATA: lv_fkart TYPE fkart,
*         lv_ndockey     TYPE i,
*         lv_dockey      TYPE vbeln.
*
* * Csak számlák esetén fusson
*   IF us_exbilldoc-doc_type EQ '0031' OR
*      us_exbilldoc-doc_type EQ '0038' OR
*      us_exbilldoc-doc_type EQ '0039'.
*
*     CALL FUNCTION 'ZEBI_PUSH_MSG'                     "INC2735509 (Az eredeti függvény hívása.)
*       EXPORTING
*         iv_opbel             = us_exbilldoc-opbel
*         iv_no_druckdat_check = 'X'.
*
*   ELSEIF us_exbilldoc-doc_type EQ '0042'.
*
*     CALL FUNCTION 'ZEBI_PUSH_MSG'                     "INC2735509 (Az eredeti függvény hívása.)
*       EXPORTING
*         iv_opbel             = us_exbilldoc-opbel
*         iv_sd                = 'X'.
*
*   ENDIF.
*
* ENDFORM.                    " UPD_PUSH_MSG