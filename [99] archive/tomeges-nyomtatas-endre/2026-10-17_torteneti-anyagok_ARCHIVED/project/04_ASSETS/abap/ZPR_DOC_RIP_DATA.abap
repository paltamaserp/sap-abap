*&---------------------------------------------------------------------*
*& Include ZPR_DOC_RIP_DATA
*&---------------------------------------------------------------------*
FORM select_data.
  DATA: lv_error TYPE string,
        ls_document TYPE ty_document,
        lt_doc_id TYPE SORTED TABLE OF zprt_dcqm-doc_no
                  WITH UNIQUE KEY table_line.
  REFRESH: gt_stock, gt_document, gt_inspire, gt_alv, gt_detail.
  SELECT * FROM zprt_stock INTO TABLE gt_stock
    WHERE stock_id IN so_stock
      AND erdat_clo IN so_erdat.
  IF gt_stock IS INITIAL.
    MESSAGE 'Nincs a kiválasztásnak megfelelő stock.' TYPE 'S'.
    RETURN.
  ENDIF.

  " The channel is stored in the document log, not in DCQM.
  SELECT dcqm~prd_stock_id AS stock_id
         doclog~channel AS destination dcqm~doc_no dcqm~envelope
         dcqm~block_dc dcqm~block_qm
    FROM zprt_dcqm AS dcqm
    LEFT OUTER JOIN zprt_doc_log AS doclog
      ON doclog~doc_no = dcqm~doc_no
    INTO CORRESPONDING FIELDS OF TABLE gt_document
    FOR ALL ENTRIES IN gt_stock
    WHERE dcqm~prd_stock_id = gt_stock-stock_id.

  SORT gt_stock BY stock_id.
  LOOP AT gt_document INTO ls_document.
    IF ls_document-doc_no IS INITIAL.
      MESSAGE 'Hiányzó dokumentumazonosító a kiválasztott stockban.'
        TYPE 'S' DISPLAY LIKE 'E'.
      REFRESH gt_document.
      RETURN.
    ENDIF.
    IF ls_document-destination IS INITIAL.
      MESSAGE 'Hiányzó dokumentumirány a ZPRT_DOC_LOG táblában.'
        TYPE 'S' DISPLAY LIKE 'E'.
      REFRESH gt_document.
      RETURN.
    ENDIF.
  ENDLOOP.
  " Do not let a non-unique log join multiply the document counters.
  SORT gt_document BY stock_id destination doc_no envelope block_dc block_qm.
  DELETE ADJACENT DUPLICATES FROM gt_document COMPARING ALL FIELDS.
  LOOP AT gt_document INTO ls_document.
    INSERT ls_document-doc_no INTO TABLE lt_doc_id.
    IF sy-subrc <> 0.
      MESSAGE 'Ellentmondó dokumentum- vagy irányadat a SAP-táblákban.'
        TYPE 'S' DISPLAY LIKE 'E'.
      REFRESH gt_document.
      RETURN.
    ENDIF.
  ENDLOOP.
  DELETE gt_document WHERE destination <> 'PR' AND destination <> 'IN'.

  PERFORM query_inspire CHANGING gt_inspire lv_error.
  IF lv_error IS NOT INITIAL.
    MESSAGE lv_error TYPE 'S' DISPLAY LIKE 'E'.
    REFRESH gt_inspire.
    RETURN.
  ENDIF.
  PERFORM aggregate_data.
  IF gt_alv IS INITIAL.
    MESSAGE 'Nincs megjeleníthető PR/IN nyomtatási adat.' TYPE 'S'.
  ENDIF.
ENDFORM.

FORM aggregate_data.
  TYPES: BEGIN OF ty_key,
           stock_id TYPE zprt_stock-stock_id,
           destination TYPE ty_destination,
         END OF ty_key.
  DATA: lt_keys TYPE SORTED TABLE OF ty_key
                WITH UNIQUE KEY stock_id destination,
        ls_key TYPE ty_key,
        ls_document TYPE ty_document,
        ls_inspire TYPE ty_inspire,
        ls_stock TYPE zprt_stock,
        ls_alv TYPE ty_alv.

  REFRESH gt_alv.
  LOOP AT gt_document INTO ls_document.
    MOVE-CORRESPONDING ls_document TO ls_key.
    INSERT ls_key INTO TABLE lt_keys.
  ENDLOOP.
  " Keep unmatched Inspire output visible, with negative differences.
  LOOP AT gt_inspire INTO ls_inspire
    WHERE destination = 'PR' OR destination = 'IN'.
    READ TABLE gt_stock TRANSPORTING NO FIELDS
      WITH KEY stock_id = ls_inspire-stock_id BINARY SEARCH.
    CHECK sy-subrc = 0.
    MOVE-CORRESPONDING ls_inspire TO ls_key.
    INSERT ls_key INTO TABLE lt_keys.
  ENDLOOP.
  LOOP AT lt_keys INTO ls_key.
    READ TABLE gt_stock INTO ls_stock
      WITH KEY stock_id = ls_key-stock_id BINARY SEARCH.
    CHECK sy-subrc = 0.
    PERFORM summarize USING ls_stock ls_key-destination
      CHANGING ls_alv.
    APPEND ls_alv TO gt_alv.
  ENDLOOP.
ENDFORM.

FORM summarize USING is_stock TYPE zprt_stock
                     iv_destination TYPE ty_destination
               CHANGING cs_alv TYPE ty_alv.
  DATA: lt_envelope TYPE SORTED TABLE OF zprt_dcqm-envelope
                    WITH UNIQUE KEY table_line,
        lt_excluded TYPE SORTED TABLE OF zprt_dcqm-envelope
                    WITH UNIQUE KEY table_line,
        ls_document TYPE ty_document,
        ls_inspire TYPE ty_inspire,
        lv_count TYPE i,
        lv_latest TYPE c LENGTH 14.

  CLEAR cs_alv.
  cs_alv-stock_id = is_stock-stock_id.
  cs_alv-sapsysid = sy-sysid.
  cs_alv-sapmandt = sy-mandt.
  cs_alv-destination = iv_destination.
  cs_alv-erdat = is_stock-erdat.
  cs_alv-ertim = is_stock-ertim.
  cs_alv-erdat_clo = is_stock-erdat_clo.
  cs_alv-status = 'NOK'.
  LOOP AT gt_document INTO ls_document
    WHERE stock_id = is_stock-stock_id
      AND destination = iv_destination.
    ADD 1 TO cs_alv-sap_doc_no.
    " Preserve the QU5 rule: the blank envelope is also one value.
    INSERT ls_document-envelope INTO TABLE lt_envelope.
    IF ls_document-block_dc IS NOT INITIAL OR
       ls_document-block_qm IS NOT INITIAL.
      ADD 1 TO cs_alv-excl_doc_no.
      INSERT ls_document-envelope INTO TABLE lt_excluded.
    ENDIF.
  ENDLOOP.
  DESCRIBE TABLE lt_envelope LINES lv_count.
  cs_alv-sap_env_no = lv_count.
  DESCRIBE TABLE lt_excluded LINES lv_count.
  cs_alv-excl_env_no = lv_count.
  LOOP AT gt_inspire INTO ls_inspire
    WHERE stock_id = is_stock-stock_id
      AND destination = iv_destination.
    " As in QU5, at least one successful file makes the status OK.
    IF ls_inspire-status_ok = abap_true.
      cs_alv-status = 'OK'.
    ENDIF.
    IF ls_inspire-send_datetime > lv_latest.
      lv_latest = ls_inspire-send_datetime.
    ENDIF.
    ADD ls_inspire-doc_no TO cs_alv-insp_doc_no.
    ADD ls_inspire-env_no TO cs_alv-insp_env_no.
    ADD ls_inspire-sheet_no TO cs_alv-insp_sheet_no.
    ADD ls_inspire-page_no TO cs_alv-insp_page_no.
    ADD ls_inspire-mark_no1 TO cs_alv-insp_mark_no1.
    ADD ls_inspire-mark_no2 TO cs_alv-insp_mark_no2.
    ADD ls_inspire-mark_no3 TO cs_alv-insp_mark_no3.
    ADD ls_inspire-mark_no4 TO cs_alv-insp_mark_no4.
  ENDLOOP.
  IF lv_latest IS NOT INITIAL.
    cs_alv-insp_send_date = lv_latest(8).
    cs_alv-insp_send_time = lv_latest+8(6).
  ENDIF.
  cs_alv-diff_doc = cs_alv-sap_doc_no - cs_alv-excl_doc_no
                   - cs_alv-insp_doc_no.
  cs_alv-diff_env = cs_alv-sap_env_no - cs_alv-excl_env_no
                   - cs_alv-insp_env_no.
ENDFORM.
