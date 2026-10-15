*&---------------------------------------------------------------------*
*& Include ZPR_DOC_RIP_TESTS
*& Pure counter tests. No database or Inspire access.
*&---------------------------------------------------------------------*
CLASS ltc_reconciliation DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA: mt_stock LIKE gt_stock,
          mt_document TYPE ty_document_tab,
          mt_inspire TYPE ty_inspire_tab,
          mt_alv TYPE ty_alv_tab,
          ms_stock TYPE zprt_stock.
    METHODS setup.
    METHODS teardown.
    METHODS documents_and_envelopes FOR TESTING.
    METHODS channel_isolation FOR TESTING.
    METHODS timestamp_isolation FOR TESTING.
    METHODS any_ok_status FOR TESTING.
    METHODS inspire_only_row FOR TESTING.
    METHODS no_inspire_row FOR TESTING.
ENDCLASS.

CLASS ltc_reconciliation IMPLEMENTATION.
  METHOD setup.
    mt_stock = gt_stock.
    mt_document = gt_document.
    mt_inspire = gt_inspire.
    mt_alv = gt_alv.
    REFRESH: gt_stock, gt_document, gt_inspire, gt_alv.
    ms_stock-stock_id = '9900000001'.
    APPEND ms_stock TO gt_stock.
  ENDMETHOD.

  METHOD teardown.
    gt_stock = mt_stock.
    gt_document = mt_document.
    gt_inspire = mt_inspire.
    gt_alv = mt_alv.
  ENDMETHOD.

  METHOD documents_and_envelopes.
    DATA: ls_document TYPE ty_document,
          ls_inspire TYPE ty_inspire,
          ls_alv TYPE ty_alv.
    ls_document-stock_id = ms_stock-stock_id.
    ls_document-destination = 'PR'.
    ls_document-doc_no = 'D1'.
    ls_document-envelope = 'E1'.
    APPEND ls_document TO gt_document.
    ls_document-doc_no = 'D2'.
    APPEND ls_document TO gt_document.
    ls_document-doc_no = 'D3'.
    ls_document-envelope = 'E2'.
    ls_document-block_dc = 'ZZ'.
    ls_document-block_qm = 'Q1'.
    APPEND ls_document TO gt_document.
    ls_document-doc_no = 'D4'.
    CLEAR ls_document-block_dc.
    APPEND ls_document TO gt_document.
    ls_inspire-stock_id = ms_stock-stock_id.
    ls_inspire-destination = 'PR'.
    ls_inspire-doc_no = 2.
    ls_inspire-env_no = 1.
    APPEND ls_inspire TO gt_inspire.
    PERFORM summarize USING ms_stock 'PR' CHANGING ls_alv.
    cl_abap_unit_assert=>assert_equals( act = ls_alv-sap_doc_no exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = ls_alv-sap_env_no exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_alv-excl_doc_no exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_alv-excl_env_no exp = 1 ).
    cl_abap_unit_assert=>assert_initial( act = ls_alv-diff_doc ).
    cl_abap_unit_assert=>assert_initial( act = ls_alv-diff_env ).
  ENDMETHOD.

  METHOD channel_isolation.
    DATA: ls_document TYPE ty_document,
          ls_alv TYPE ty_alv.
    ls_document-stock_id = ms_stock-stock_id.
    ls_document-doc_no = 'D1'.
    ls_document-destination = 'PR'.
    APPEND ls_document TO gt_document.
    ls_document-doc_no = 'D2'.
    ls_document-destination = 'IN'.
    ls_document-block_dc = 'ZZ'.
    APPEND ls_document TO gt_document.
    PERFORM summarize USING ms_stock 'PR' CHANGING ls_alv.
    cl_abap_unit_assert=>assert_equals( act = ls_alv-sap_doc_no exp = 1 ).
    cl_abap_unit_assert=>assert_initial( act = ls_alv-excl_doc_no ).
    " QU5 counts the blank envelope as one distinct envelope.
    cl_abap_unit_assert=>assert_equals( act = ls_alv-sap_env_no exp = 1 ).
    PERFORM summarize USING ms_stock 'IN' CHANGING ls_alv.
    cl_abap_unit_assert=>assert_equals( act = ls_alv-excl_doc_no exp = 1 ).
  ENDMETHOD.

  METHOD timestamp_isolation.
    DATA: ls_inspire TYPE ty_inspire,
          ls_alv TYPE ty_alv.
    ls_inspire-stock_id = ms_stock-stock_id.
    ls_inspire-destination = 'PR'.
    ls_inspire-send_datetime = '20261015120000'.
    APPEND ls_inspire TO gt_inspire.
    ls_inspire-send_datetime = '20261014120000'.
    APPEND ls_inspire TO gt_inspire.
    PERFORM summarize USING ms_stock 'PR' CHANGING ls_alv.
    cl_abap_unit_assert=>assert_equals(
      act = ls_alv-insp_send_date exp = '20261015' ).
    PERFORM summarize USING ms_stock 'IN' CHANGING ls_alv.
    cl_abap_unit_assert=>assert_initial( act = ls_alv-insp_send_date ).
    cl_abap_unit_assert=>assert_initial( act = ls_alv-insp_send_time ).
    ms_stock-stock_id = '9900000002'.
    PERFORM summarize USING ms_stock 'PR' CHANGING ls_alv.
    cl_abap_unit_assert=>assert_initial( act = ls_alv-insp_send_date ).
  ENDMETHOD.

  METHOD any_ok_status.
    DATA: ls_inspire TYPE ty_inspire,
          ls_alv TYPE ty_alv.
    ls_inspire-stock_id = ms_stock-stock_id.
    ls_inspire-destination = 'PR'.
    ls_inspire-status_ok = abap_true.
    ls_inspire-doc_no = 2.
    APPEND ls_inspire TO gt_inspire.
    ls_inspire-status_ok = abap_false.
    ls_inspire-doc_no = 1.
    APPEND ls_inspire TO gt_inspire.
    PERFORM summarize USING ms_stock 'PR' CHANGING ls_alv.
    cl_abap_unit_assert=>assert_equals( act = ls_alv-status exp = 'OK' ).
    cl_abap_unit_assert=>assert_equals( act = ls_alv-insp_doc_no exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = ls_alv-diff_doc exp = -3 ).
  ENDMETHOD.

  METHOD inspire_only_row.
    DATA: ls_inspire TYPE ty_inspire,
          ls_alv TYPE ty_alv,
          lv_lines TYPE i.
    ls_inspire-stock_id = ms_stock-stock_id.
    ls_inspire-destination = 'PR'.
    ls_inspire-doc_no = 5.
    APPEND ls_inspire TO gt_inspire.
    ls_inspire-stock_id = '9900000002'.
    APPEND ls_inspire TO gt_inspire.
    PERFORM aggregate_data.
    DESCRIBE TABLE gt_alv LINES lv_lines.
    cl_abap_unit_assert=>assert_equals( act = lv_lines exp = 1 ).
    READ TABLE gt_alv INTO ls_alv INDEX 1.
    cl_abap_unit_assert=>assert_equals( act = ls_alv-diff_doc exp = -5 ).
  ENDMETHOD.

  METHOD no_inspire_row.
    DATA: ls_document TYPE ty_document,
          ls_alv TYPE ty_alv.
    ls_document-stock_id = ms_stock-stock_id.
    ls_document-destination = 'PR'.
    ls_document-doc_no = 'D1'.
    APPEND ls_document TO gt_document.
    PERFORM aggregate_data.
    READ TABLE gt_alv INTO ls_alv INDEX 1.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( act = ls_alv-status exp = 'NOK' ).
    cl_abap_unit_assert=>assert_equals( act = ls_alv-diff_doc exp = 1 ).
  ENDMETHOD.
ENDCLASS.
