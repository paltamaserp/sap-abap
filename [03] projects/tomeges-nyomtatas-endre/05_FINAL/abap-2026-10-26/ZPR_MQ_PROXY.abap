*&---------------------------------------------------------------------*
*& Include ZPR_MQ_PROXY
*& Bind these generated names to the actual Inspire WSDL in SPROXY.
*& No local replacement for a generated consumer proxy is provided.
*&---------------------------------------------------------------------*
FORM query_messenger USING it_docnos TYPE ty_docno_tab
  CHANGING ct_response TYPE ty_email_tab
           cv_ok TYPE abap_bool cv_error TYPE string.

  DATA: lo_proxy      TYPE REF TO zpr_co_eon_query_messenger_sta,
        ls_input      TYPE zpr_eon_query_messenger_statu2, "zpr_query_messenger_request
        ls_output     TYPE zpr_eon_query_messenger_statu1, "zpr_query_messenger_response,

        ls_doc        LIKE LINE OF ls_output-parameters-docs-doc,
        ls_response   TYPE zprt_email_slog,
        lv_docno      TYPE string,
        lv_stamp_text TYPE string,
        lv_stamp      TYPE timestamp,
        lx_error      TYPE REF TO cx_root.

  CLEAR: ct_response, cv_error.
  cv_ok = abap_false.

  ls_input-sap_system = sy-sysid.
  ls_input-sap_mandant = sy-mandt.
  LOOP AT it_docnos INTO lv_docno.
    APPEND lv_docno TO ls_input-exbilldocnos-exbilldocno.
  ENDLOOP.

  TRY.
      CREATE OBJECT lo_proxy EXPORTING logical_port_name = p_lport.
      lo_proxy->eon_query_messenger_status(
        EXPORTING input = ls_input IMPORTING output = ls_output ).
      IF ls_output-parameters-success <> abap_true.
        cv_error = ls_output-parameters-info.
        IF cv_error IS INITIAL.
          cv_error = 'Az Inspire sikertelen státuszlekérdezést jelzett.'.
        ENDIF.
        RETURN.
      ENDIF.

      LOOP AT ls_output-parameters-docs-doc INTO ls_doc.
        IF ls_doc-exbilldocno IS INITIAL
          OR strlen( ls_doc-exbilldocno ) > 20
          OR strlen( ls_doc-sending_status ) > 1
          OR strlen( ls_doc-error_message ) > 255.
          cv_error = 'A proxyválasz mezőhossza eltér a DHC-adatszerződéstől.'.
          CLEAR ct_response.
          RETURN.
        ENDIF.
        lv_docno = ls_doc-exbilldocno.
        READ TABLE it_docnos TRANSPORTING NO FIELDS
          WITH KEY table_line = lv_docno.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        CLEAR ls_response.
        ls_response-mandt = sy-mandt.
        ls_response-exbilldocno = ls_doc-exbilldocno.
        ls_response-sending_status = ls_doc-sending_status.
        ls_response-error_message = ls_doc-error_message.
        lv_stamp_text = ls_doc-tstmp_sending_status.
        IF lv_stamp_text IS NOT INITIAL.
          lv_stamp = lcl_age=>parse_text( iv_text = lv_stamp_text ).
          IF lv_stamp IS INITIAL.
            cv_error = 'Érvénytelen státusz-időbélyeg a proxyválaszban.'.
            CLEAR ct_response.
            RETURN.
          ENDIF.
          ls_response-tstmp_sending_status =
            lcl_age=>format_stamp( iv_stamp = lv_stamp ).
        ENDIF.
        lv_stamp_text = ls_doc-tstmp_email_sent.
        IF lv_stamp_text IS NOT INITIAL.
          lv_stamp = lcl_age=>parse_text( iv_text = lv_stamp_text ).
          IF lv_stamp IS INITIAL.
            cv_error = 'Érvénytelen küldési időbélyeg a proxyválaszban.'.
            CLEAR ct_response.
            RETURN.
          ENDIF.
          ls_response-tstmp_email_sent =
            lcl_age=>format_stamp( iv_stamp = lv_stamp ).
        ENDIF.
        READ TABLE ct_response TRANSPORTING NO FIELDS
          WITH KEY exbilldocno = ls_response-exbilldocno.
        IF sy-subrc EQ 0.
          " A régi riporthoz hasonlóan ugyanannak a dokumentumnak a későbbi státusza felülírja a korábbit.
          MODIFY ct_response FROM ls_response INDEX sy-tabix.
        ELSE.
          APPEND ls_response TO ct_response.
        ENDIF.
      ENDLOOP.
      SORT ct_response BY exbilldocno.
      cv_ok = abap_true.
    CATCH cx_ai_application_fault INTO lx_error.
      cv_error = lx_error->get_text( ).
      CLEAR ct_response.
    CATCH cx_root INTO lx_error.
      cv_error = lx_error->get_text( ).
      CLEAR ct_response.
  ENDTRY.
ENDFORM.