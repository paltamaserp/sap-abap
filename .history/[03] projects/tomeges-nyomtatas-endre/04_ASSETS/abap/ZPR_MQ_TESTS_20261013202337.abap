*&---------------------------------------------------------------------*
*& Include ZPR_MQ_TESTS: pure UTC age and result-preparation tests.
*& No database, enqueue or proxy calls.
*&---------------------------------------------------------------------*
CLASS ltc_mq_status DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS setup.
    METHODS seven_day_boundary FOR TESTING.
    METHODS invalid_timestamp FOR TESTING.
    METHODS month_boundary FOR TESTING.
    METHODS char_timestamp_roundtrip FOR TESTING.
    METHODS malformed_char_timestamp FOR TESTING.
    METHODS business_fields_preserved FOR TESTING.
    METHODS returned_status FOR TESTING.
    METHODS no_status_recent FOR TESTING.
    METHODS no_status_expired FOR TESTING.
ENDCLASS.

CLASS ltc_mq_status IMPLEMENTATION.
  METHOD setup.
    CLEAR: gt_pending, gt_response, gt_result.
  ENDMETHOD.

  METHOD seven_day_boundary.
    cl_abap_unit_assert=>assert_equals(
      act = lcl_age=>expired(
        iv_print = '20261006120000' iv_now = '20261013120000' )
      exp = abap_true ).
    cl_abap_unit_assert=>assert_equals(
      act = lcl_age=>expired(
        iv_print = '20261006120001' iv_now = '20261013120000' )
      exp = abap_false ).
  ENDMETHOD.

  METHOD invalid_timestamp.
    cl_abap_unit_assert=>assert_equals(
      act = lcl_age=>expired( iv_print = space iv_now = '20261013120000' )
      exp = abap_false ).
    cl_abap_unit_assert=>assert_equals(
      act = lcl_age=>expired(
        iv_print = '20261301120000' iv_now = '20261013120000' )
      exp = abap_false ).
  ENDMETHOD.

  METHOD month_boundary.
    cl_abap_unit_assert=>assert_equals(
      act = lcl_age=>expired(
        iv_print = '20260224120000' iv_now = '20260303120000' )
      exp = abap_true ).
  ENDMETHOD.

  METHOD returned_status.
    DATA: ls_email TYPE zpr_slog_email,
          ls_result TYPE ty_result.
    ls_email-exbilldocno = 'UNIT-STATUS'.
    APPEND ls_email TO gt_pending.
    ls_email-sending_status = 'S'.
    ls_email-tstmp_sending_status = '20261013120000'.
    ls_email-error_message = 'Messenger result'.
    APPEND ls_email TO gt_response.
    PERFORM prepare_result.
    cl_abap_unit_assert=>assert_equals( act = lines( gt_result ) exp = 1 ).
    READ TABLE gt_result INDEX 1 INTO ls_result.
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-sending_status exp = 'S' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-error_message exp = ls_email-error_message ).
  ENDMETHOD.

  METHOD no_status_recent.
    DATA: ls_email TYPE zpr_slog_email,
          lv_now TYPE timestamp.
    ls_email-exbilldocno = 'UNIT-RECENT'.
    GET TIME STAMP FIELD lv_now.
    ls_email-tstmp_print = lcl_age=>format_stamp( iv_stamp = lv_now ).
    APPEND ls_email TO gt_pending.
    PERFORM prepare_result.
    cl_abap_unit_assert=>assert_initial( act = gt_result ).
  ENDMETHOD.

  METHOD no_status_expired.
    DATA: ls_email TYPE zpr_slog_email,
          ls_result TYPE ty_result.
    ls_email-exbilldocno = 'UNIT-EXPIRED'.
    ls_email-tstmp_print = '20000101000000'.
    APPEND ls_email TO gt_pending.
    PERFORM prepare_result.
    cl_abap_unit_assert=>assert_equals( act = lines( gt_result ) exp = 1 ).
    READ TABLE gt_result INDEX 1 INTO ls_result.
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-sending_status exp = 'N' ).
    cl_abap_unit_assert=>assert_not_initial(
      act = ls_result-tstmp_sending_status ).
  ENDMETHOD.

  METHOD char_timestamp_roundtrip.
    DATA: lv_stamp TYPE timestamp,
          lv_expected TYPE timestamp,
          lv_text TYPE zpr_slog_email-tstmp_print.
    lv_expected = '20261013120509'.
    lv_stamp = lcl_age=>parse_text( iv_text = '20261013120509' ).
    cl_abap_unit_assert=>assert_equals( act = lv_stamp exp = lv_expected ).
    lv_text = lcl_age=>format_stamp( iv_stamp = lv_stamp ).
    cl_abap_unit_assert=>assert_equals( act = lv_text exp = '20261013120509' ).
  ENDMETHOD.

  METHOD malformed_char_timestamp.
    cl_abap_unit_assert=>assert_initial(
      act = lcl_age=>parse_text( iv_text = '20261013120X09' ) ).
    cl_abap_unit_assert=>assert_initial(
      act = lcl_age=>parse_text( iv_text = '20261013' ) ).
    cl_abap_unit_assert=>assert_initial(
      act = lcl_age=>parse_text( iv_text = '202610131205090' ) ).
    cl_abap_unit_assert=>assert_initial(
      act = lcl_age=>parse_text( iv_text = '20260230120509' ) ).
  ENDMETHOD.

  METHOD business_fields_preserved.
    DATA: ls_email TYPE zpr_slog_email,
          ls_response TYPE zpr_slog_email,
          ls_result TYPE ty_result.
    ls_email-exbilldocno = 'UNIT-BUSINESS'.
    ls_email-opbel = '000000000001'.
    ls_email-gpart = '0000000002'.
    ls_email-vkont = '000000000003'.
    ls_email-email_address = 'unit@example.invalid'.
    APPEND ls_email TO gt_pending.
    ls_response-exbilldocno = ls_email-exbilldocno.
    ls_response-sending_status = 'S'.
    APPEND ls_response TO gt_response.
    PERFORM prepare_result.
    READ TABLE gt_result INDEX 1 INTO ls_result.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-opbel exp = ls_email-opbel ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-gpart exp = ls_email-gpart ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-vkont exp = ls_email-vkont ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-email_address exp = ls_email-email_address ).
  ENDMETHOD.
ENDCLASS.
