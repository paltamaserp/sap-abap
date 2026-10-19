*&---------------------------------------------------------------------*
*& Include ZPR_DOC_RIP_DISPLAY
*&---------------------------------------------------------------------*
FORM create_controls.
  DATA: ls_layout   TYPE lvc_s_layo,
        ls_variant  TYPE disvariant,
        lt_fieldcat TYPE lvc_t_fcat.

  CHECK go_grid IS NOT BOUND.
  CREATE OBJECT go_container
    EXPORTING container_name = 'ALV_CONTAINER_01'
    EXCEPTIONS OTHERS = 1.
  IF sy-subrc <> 0.
    MESSAGE 'Az ALV-konténer nem hozható létre.' TYPE 'S' DISPLAY LIKE 'E'.
    LEAVE TO SCREEN 0.
  ENDIF.
  CREATE OBJECT go_grid
    EXPORTING i_parent = go_container
              i_appl_events = space
    EXCEPTIONS OTHERS = 1.
  IF sy-subrc <> 0.
    PERFORM free_controls.
    MESSAGE 'Az ALV nem hozható létre.' TYPE 'S' DISPLAY LIKE 'E'.
    LEAVE TO SCREEN 0.
  ENDIF.

  PERFORM build_fieldcat CHANGING lt_fieldcat.
  ls_layout-zebra = abap_true.
  ls_layout-cwidth_opt = abap_true.
  ls_layout-sel_mode = 'A'.
  ls_variant-report = sy-repid.
  ls_variant-handle = '1'.
  ls_variant-variant = p_vari.
  SET HANDLER lcl_events=>on_toolbar
              lcl_events=>on_command
              lcl_events=>on_double_click FOR go_grid.
  go_grid->set_table_for_first_display(
    EXPORTING is_layout = ls_layout
              is_variant = ls_variant
              i_save = 'A'
    CHANGING  it_outtab = gt_alv
              it_fieldcatalog = lt_fieldcat
    EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc <> 0.
    PERFORM free_controls.
    MESSAGE 'Az ALV megjelenítése sikertelen.' TYPE 'S' DISPLAY LIKE 'E'.
    LEAVE TO SCREEN 0.
  ENDIF.
  go_grid->set_toolbar_interactive( ).
ENDFORM.

FORM build_fieldcat CHANGING ct_fieldcat TYPE lvc_t_fcat.
  REFRESH ct_fieldcat.
  PERFORM add_field USING 'STOCK_ID' 'Stock azonosító' 'N' 10
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'SAPSYSID' 'SAP rendszer' 'C' 8
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'SAPMANDT' 'Mandant' 'C' 3
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'DESTINATION' 'Irány' 'C' 2
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'ERDAT' 'Stock létrehozás dátuma' 'D' 8
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'ERTIM' 'Stock létrehozás ideje' 'T' 6
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'ERDAT_CLO' 'Engedélyezés dátuma' 'D' 8
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'SAP_DOC_NO' 'Dokumentumok száma' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'SAP_ENV_NO' 'Borítékok száma' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'EXCL_DOC_NO' 'Kizárt dokumentumok' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'EXCL_ENV_NO' 'Kizárt borítékok' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'STATUS' 'Inspire státusz' 'C' 3
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'INSP_SEND_DATE' 'Küldés dátuma' 'D' 8
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'INSP_SEND_TIME' 'Küldés ideje' 'T' 6
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'INSP_DOC_NO' 'Inspire dokumentumok' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'INSP_ENV_NO' 'Inspire borítékok' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'INSP_SHEET_NO' 'Inspire lapok' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'INSP_PAGE_NO' 'Inspire oldalak' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'INSP_MARK_NO1' 'Inspire marketing 1' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'INSP_MARK_NO2' 'Inspire marketing 2' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'INSP_MARK_NO3' 'Inspire marketing 3' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'INSP_MARK_NO4' 'Inspire marketing 4' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'DIFF_DOC' 'Dokumentum eltérés' 'P' 16
    CHANGING ct_fieldcat.
  PERFORM add_field USING 'DIFF_ENV' 'Boríték eltérés' 'P' 16
    CHANGING ct_fieldcat.
ENDFORM.

FORM add_field USING iv_name TYPE clike
                     iv_text TYPE clike
                     iv_type TYPE c
                     iv_length TYPE i
               CHANGING ct_fieldcat TYPE lvc_t_fcat.
  DATA ls_field TYPE lvc_s_fcat.
  ls_field-fieldname = iv_name.
  ls_field-coltext = iv_text.
  ls_field-scrtext_l = iv_text.
  ls_field-scrtext_m = iv_text.
  ls_field-scrtext_s = iv_text.
  ls_field-inttype = iv_type.
  ls_field-intlen = iv_length.
  IF iv_type CA 'CNDT'.
    ls_field-intlen = iv_length * cl_abap_char_utilities=>charsize.
  ENDIF.
  ls_field-col_opt = abap_true.
  CASE iv_type.
    WHEN 'P'.
      ls_field-datatype = 'DEC'.
      ls_field-outputlen = 20.
      ls_field-do_sum = abap_true.
      ls_field-decimals_o = 0.
    WHEN 'N'.
      ls_field-datatype = 'NUMC'.
      ls_field-ref_table = 'ZPRT_STOCK'.
      ls_field-ref_field = 'STOCK_ID'.
      ls_field-key = abap_true.
    WHEN 'D'.
      ls_field-datatype = 'DATS'.
    WHEN 'T'.
      ls_field-datatype = 'TIMS'.
    WHEN OTHERS.
      ls_field-datatype = 'CHAR'.
  ENDCASE.
  APPEND ls_field TO ct_fieldcat.
ENDFORM.

FORM append_details USING iv_index TYPE i.
  DATA: ls_alv TYPE ty_alv,
        ls_inspire TYPE ty_inspire,
        ls_detail TYPE ty_detail.
  READ TABLE gt_alv INTO ls_alv INDEX iv_index.
  CHECK sy-subrc = 0.
  LOOP AT gt_inspire INTO ls_inspire
    WHERE stock_id = ls_alv-stock_id
      AND destination = ls_alv-destination.
    CLEAR ls_detail.
    ls_detail-stock_id = ls_inspire-stock_id.
    ls_detail-destination = ls_inspire-destination.
    ls_detail-sapsysid = ls_inspire-sap_system.
    ls_detail-sapmandt = ls_inspire-sap_mandant.
    ls_detail-status = 'NOK'.
    IF ls_inspire-status_ok = abap_true.
      ls_detail-status = 'OK'.
    ENDIF.
    ls_detail-insp_send_date = ls_inspire-send_datetime(8).
    ls_detail-insp_send_time = ls_inspire-send_datetime+8(6).
    ls_detail-insp_out_file = ls_inspire-out_file.
    ls_detail-insp_doc_no = ls_inspire-doc_no.
    ls_detail-insp_env_no = ls_inspire-env_no.
    ls_detail-insp_sheet_no = ls_inspire-sheet_no.
    ls_detail-insp_page_no = ls_inspire-page_no.
    ls_detail-insp_mark_no1 = ls_inspire-mark_no1.
    ls_detail-insp_mark_no2 = ls_inspire-mark_no2.
    ls_detail-insp_mark_no3 = ls_inspire-mark_no3.
    ls_detail-insp_mark_no4 = ls_inspire-mark_no4.
    APPEND ls_detail TO gt_detail.
  ENDLOOP.
ENDFORM.

FORM display_details.
  DATA: lo_table TYPE REF TO cl_salv_table,
        lo_functions TYPE REF TO cl_salv_functions_list,
        lo_columns TYPE REF TO cl_salv_columns_table,
        lo_column TYPE REF TO cl_salv_column_table,
        lo_layout TYPE REF TO cl_salv_layout,
        ls_key TYPE salv_s_layout_key,
        lt_fieldcat TYPE lvc_t_fcat,
        ls_field TYPE lvc_s_fcat,
        lx_error TYPE REF TO cx_salv_msg.
  IF gt_detail IS INITIAL.
    MESSAGE 'Nincs Inspire-fájlrészlet a kijelölt sorokhoz.' TYPE 'I'.
    RETURN.
  ENDIF.
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_table
        CHANGING t_table = gt_detail ).
    CATCH cx_salv_msg INTO lx_error.
      MESSAGE lx_error->get_text( ) TYPE 'I' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.
  lo_functions = lo_table->get_functions( ).
  lo_functions->set_all( abap_true ).
  lo_layout = lo_table->get_layout( ).
  ls_key-report = sy-repid.
  ls_key-handle = '2'.
  lo_layout->set_key( ls_key ).
  lo_layout->set_save_restriction( if_salv_c_layout=>restrict_none ).
  lo_columns = lo_table->get_columns( ).
  lo_columns->set_optimize( abap_true ).
  PERFORM build_fieldcat CHANGING lt_fieldcat.
  PERFORM add_field USING 'INSP_OUT_FILE' 'Nyomdai állomány' 'C' 1
    CHANGING lt_fieldcat.
  LOOP AT lt_fieldcat INTO ls_field.
    TRY.
        lo_column ?= lo_columns->get_column( ls_field-fieldname ).
        lo_column->set_long_text( ls_field-scrtext_l ).
        lo_column->set_medium_text( ls_field-scrtext_m ).
        lo_column->set_short_text( ls_field-scrtext_s ).
      CATCH cx_salv_not_found.
        CONTINUE.
    ENDTRY.
  ENDLOOP.
  lo_table->display( ).
ENDFORM.

FORM free_controls.
  DATA lv_error TYPE abap_bool.
  IF go_grid IS BOUND.
    go_grid->free( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      lv_error = abap_true.
    ENDIF.
    FREE go_grid.
  ENDIF.
  IF go_container IS BOUND.
    go_container->free( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      lv_error = abap_true.
    ENDIF.
    FREE go_container.
  ENDIF.
  IF lv_error = abap_true.
    MESSAGE 'Az ALV-vezérlők felszabadítása nem teljes.' TYPE 'S'
      DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.
