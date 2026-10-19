*&---------------------------------------------------------------------*
*& Include ZPR_DOC_RIP_PROXY
*& Typed adapter for the active DHC print house consumer.
*&---------------------------------------------------------------------*
FORM query_inspire CHANGING ct_inspire TYPE ty_inspire_tab
                            cv_error TYPE string.
  DATA: lo_proxy TYPE REF TO zpr_co_eon_forms_query_printho,
        ls_input TYPE zpr_eon_forms_query_printhous3,
        ls_output TYPE zpr_eon_forms_query_printhous2,
        ls_file TYPE zpr_eon_forms_query_printhous1,
        ls_stock TYPE zprt_stock,
        ls_inspire TYPE ty_inspire,
        lv_stock TYPE string,
        lv_stamp TYPE timestamp,
        lv_date TYPE d,
        lv_time TYPE t,
        lx_fault TYPE REF TO cx_ai_system_fault.
  REFRESH ct_inspire.
  CLEAR cv_error.
  CHECK gt_stock IS NOT INITIAL.
  ls_input-sap_system = sy-sysid.
  ls_input-sap_mandant = sy-mandt.
  LOOP AT gt_stock INTO ls_stock.
    lv_stock = ls_stock-stock_id.
    APPEND lv_stock TO ls_input-stocks-stock_id.
  ENDLOOP.

  TRY.
      CREATE OBJECT lo_proxy
        EXPORTING logical_port_name = p_lport.
      lo_proxy->eon_forms_query_printhouse_out(
        EXPORTING input = ls_input
        IMPORTING output = ls_output ).
    CATCH cx_ai_system_fault INTO lx_fault.
      cv_error = lx_fault->get_text( ).
      RETURN.
  ENDTRY.
  IF ls_output-success <> abap_true.
    CONCATENATE 'Inspire nyomdai lekérdezési hiba:'
      ls_output-error_code ls_output-info INTO cv_error
      SEPARATED BY space.
    RETURN.
  ENDIF.

  LOOP AT ls_output-out_file_details INTO ls_file.
    CLEAR ls_inspire.
    IF ls_file-sap_system <> ls_input-sap_system OR
       ls_file-sap_mandant <> ls_input-sap_mandant.
      cv_error = 'Az Inspire-válasz SAP-rendszere vagy mandantja eltér.'.
      EXIT.
    ENDIF.
    IF ls_file-stock_id IS INITIAL OR
       strlen( ls_file-stock_id ) > 10 OR
       ls_file-stock_id CN '0123456789'.
      cv_error = 'Érvénytelen stockazonosító az Inspire-válaszban.'.
      EXIT.
    ENDIF.
    ls_inspire-stock_id = ls_file-stock_id.
    READ TABLE gt_stock TRANSPORTING NO FIELDS
      WITH KEY stock_id = ls_inspire-stock_id BINARY SEARCH.
    IF sy-subrc <> 0.
      cv_error = 'Az Inspire-válasz nem kért stockot tartalmaz.'.
      EXIT.
    ENDIF.
    IF ls_file-destination IS INITIAL.
      cv_error = 'Hiányzó irány az Inspire-válaszban.'.
      EXIT.
    ENDIF.
    CHECK ls_file-destination = 'PR' OR ls_file-destination = 'IN'.
    IF ls_file-send_datetime IS NOT INITIAL.
      IF strlen( ls_file-send_datetime ) <> 14 OR
         ls_file-send_datetime CN '0123456789'.
        cv_error = 'Érvénytelen küldési időbélyeg az Inspire-válaszban.'.
        EXIT.
      ENDIF.
      lv_stamp = ls_file-send_datetime.
      CONVERT TIME STAMP lv_stamp TIME ZONE 'UTC'
        INTO DATE lv_date TIME lv_time.
      IF sy-subrc <> 0.
        cv_error = 'Érvénytelen küldési dátum az Inspire-válaszban.'.
        EXIT.
      ENDIF.
    ENDIF.
    IF ls_file-doc_no < 0 OR ls_file-env_no < 0 OR
       ls_file-sheet_no < 0 OR ls_file-page_no < 0 OR
       ls_file-mark_no1 < 0 OR ls_file-mark_no2 < 0 OR
       ls_file-mark_no3 < 0 OR ls_file-mark_no4 < 0.
      cv_error = 'Negatív darabszám az Inspire-válaszban.'.
      EXIT.
    ENDIF.
    MOVE-CORRESPONDING ls_file TO ls_inspire.
    APPEND ls_inspire TO ct_inspire.
  ENDLOOP.
  IF cv_error IS NOT INITIAL.
    REFRESH ct_inspire.
  ENDIF.
ENDFORM.
