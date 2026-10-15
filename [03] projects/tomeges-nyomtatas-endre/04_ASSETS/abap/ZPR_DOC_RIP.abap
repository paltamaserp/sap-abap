*&---------------------------------------------------------------------*
*& Report ZPR_DOC_RIP
*& Reconcile SAP stock documents with Inspire print house output.
*&---------------------------------------------------------------------*
REPORT zpr_doc_rip.

INCLUDE <icon>.

TYPES ty_count TYPE p LENGTH 16 DECIMALS 0.
TYPES ty_destination TYPE c LENGTH 2.
TYPES: BEGIN OF ty_document,
         stock_id    TYPE zprt_stock-stock_id,
         destination TYPE ty_destination,
         doc_no      TYPE zprt_dcqm-doc_no,
         envelope    TYPE zprt_dcqm-envelope,
         block_dc    TYPE zprt_dcqm-block_dc,
         block_qm    TYPE zprt_dcqm-block_qm,
       END OF ty_document.
TYPES ty_document_tab TYPE STANDARD TABLE OF ty_document
                      WITH DEFAULT KEY.
TYPES: BEGIN OF ty_inspire,
         stock_id      TYPE zprt_stock-stock_id,
         destination   TYPE ty_destination,
         sap_system    TYPE c LENGTH 8,
         sap_mandant   TYPE mandt,
         send_datetime TYPE c LENGTH 14,
         out_file      TYPE string,
         status_ok     TYPE abap_bool,
         doc_no        TYPE ty_count,
         env_no        TYPE ty_count,
         sheet_no      TYPE ty_count,
         page_no       TYPE ty_count,
         mark_no1      TYPE ty_count,
         mark_no2      TYPE ty_count,
         mark_no3      TYPE ty_count,
         mark_no4      TYPE ty_count,
       END OF ty_inspire.
TYPES ty_inspire_tab TYPE STANDARD TABLE OF ty_inspire WITH DEFAULT KEY.
TYPES: BEGIN OF ty_alv,
         stock_id       TYPE zprt_stock-stock_id,
         sapsysid       TYPE c LENGTH 8,
         sapmandt       TYPE mandt,
         destination    TYPE ty_destination,
         erdat          TYPE zprt_stock-erdat,
         ertim          TYPE zprt_stock-ertim,
         erdat_clo      TYPE zprt_stock-erdat_clo,
         sap_doc_no     TYPE ty_count,
         sap_env_no     TYPE ty_count,
         excl_doc_no    TYPE ty_count,
         excl_env_no    TYPE ty_count,
         status         TYPE c LENGTH 3,
         insp_send_date TYPE d,
         insp_send_time TYPE t,
         insp_doc_no    TYPE ty_count,
         insp_env_no    TYPE ty_count,
         insp_sheet_no  TYPE ty_count,
         insp_page_no   TYPE ty_count,
         insp_mark_no1  TYPE ty_count,
         insp_mark_no2  TYPE ty_count,
         insp_mark_no3  TYPE ty_count,
         insp_mark_no4  TYPE ty_count,
         diff_doc       TYPE ty_count,
         diff_env       TYPE ty_count,
       END OF ty_alv.
TYPES ty_alv_tab TYPE STANDARD TABLE OF ty_alv WITH DEFAULT KEY.
TYPES: BEGIN OF ty_detail,
         stock_id       TYPE zprt_stock-stock_id,
         destination    TYPE ty_destination,
         sapsysid       TYPE c LENGTH 8,
         sapmandt       TYPE mandt,
         status         TYPE c LENGTH 3,
         insp_send_date TYPE d,
         insp_send_time TYPE t,
         insp_out_file  TYPE string,
         insp_doc_no    TYPE ty_count,
         insp_env_no    TYPE ty_count,
         insp_sheet_no  TYPE ty_count,
         insp_page_no   TYPE ty_count,
         insp_mark_no1  TYPE ty_count,
         insp_mark_no2  TYPE ty_count,
         insp_mark_no3  TYPE ty_count,
         insp_mark_no4  TYPE ty_count,
       END OF ty_detail.
TYPES ty_detail_tab TYPE STANDARD TABLE OF ty_detail WITH DEFAULT KEY.

DATA: gs_stock        TYPE zprt_stock,
      gt_stock        TYPE STANDARD TABLE OF zprt_stock,
      gt_document     TYPE ty_document_tab,
      gt_inspire      TYPE ty_inspire_tab,
      gt_alv          TYPE ty_alv_tab,
      gt_detail       TYPE ty_detail_tab,
      gv_okcode_0100  TYPE syucomm,
      go_container    TYPE REF TO cl_gui_custom_container,
      go_grid         TYPE REF TO cl_gui_alv_grid.

CLASS lcl_events DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS on_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.
    CLASS-METHODS on_command FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
    CLASS-METHODS on_double_click FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING es_row_no e_column.
ENDCLASS.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.
SELECT-OPTIONS: so_stock FOR gs_stock-stock_id,
                so_erdat FOR gs_stock-erdat_clo.
SELECTION-SCREEN END OF BLOCK b01.
SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE text-002.
PARAMETERS: p_lport TYPE prx_logical_port_name OBLIGATORY,
            p_vari  TYPE disvariant-variant.
SELECTION-SCREEN END OF BLOCK b02.

INCLUDE zpr_doc_rip_data.
INCLUDE zpr_doc_rip_proxy.
INCLUDE zpr_doc_rip_display.
INCLUDE zpr_doc_rip_o01.
INCLUDE zpr_doc_rip_i01.

START-OF-SELECTION.
  PERFORM select_data.
  IF gt_alv IS INITIAL.
    RETURN.
  ENDIF.
  CALL SCREEN 0100.

CLASS lcl_events IMPLEMENTATION.
  METHOD on_toolbar.
    DATA ls_button TYPE stb_button.
    ls_button-butn_type = 3.
    APPEND ls_button TO e_object->mt_toolbar.
    CLEAR ls_button.
    ls_button-function = 'DETAIL'.
    ls_button-icon = icon_select_detail.
    ls_button-text = 'Részletes lista'.
    ls_button-quickinfo = 'Inspire nyomdai fájlok a kijelölt sorokhoz'.
    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_command.
    DATA: lt_rows TYPE lvc_t_row,
          ls_row  TYPE lvc_s_row.
    CHECK e_ucomm = 'DETAIL'.
    go_grid->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
    IF lt_rows IS INITIAL.
      MESSAGE 'Jelöljön ki legalább egy sort.' TYPE 'I'.
      RETURN.
    ENDIF.
    REFRESH gt_detail.
    LOOP AT lt_rows INTO ls_row.
      PERFORM append_details USING ls_row-index.
    ENDLOOP.
    PERFORM display_details.
  ENDMETHOD.

  METHOD on_double_click.
    REFRESH gt_detail.
    PERFORM append_details USING es_row_no-row_id.
    PERFORM display_details.
  ENDMETHOD.
ENDCLASS.

INCLUDE zpr_doc_rip_tests.
