REPORT ZPR_CLOSE_STOCK MESSAGE-ID zpr.

*********************************************************************
* Report: ZPR_CLOSE_STOCK
* Leírás: STOCK Engedélyezés / Lezárás
* Final stock release and Inspire notification
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

TYPE-POOLS icon.

CONSTANTS: gc_log_object    TYPE balobj_d VALUE 'ZPR_MASS',
           gc_log_subobject TYPE balsubobj VALUE 'STOCK',
           gc_tcode         TYPE tcode VALUE 'ZPR_STOCK',
           gc_status_closed TYPE zprd_stock_status VALUE 'CL',
           gc_status_qm     TYPE zprd_stock_status VALUE 'QM',
           gc_default_priority TYPE zprd_priority VALUE '30'.

TYPES: ty_alv_table TYPE STANDARD TABLE OF zprs_dcqm_report,
       BEGIN OF ty_stock_f4,
         stock_id TYPE zprt_stock-stock_id,
         status TYPE zprt_stock-status,
         closed TYPE zprt_stock-closed,
         dccompl TYPE zprt_stock-dccompl,
         qmcompl TYPE zprt_stock-qmcompl,
         priority TYPE zprt_stock-priority,
       END OF ty_stock_f4.

CLASS lcl_grid_events DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      on_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,
      on_user_command FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm.
ENDCLASS.

DATA: gs_stock TYPE zprt_stock,
      gt_alv TYPE ty_alv_table,
      gt_messages TYPE bal_t_msg,
      gv_okcode_0100 TYPE syucomm,
      gv_total TYPE i,
      gv_excluded TYPE i,
      gv_allowed TYPE i,
      gv_modif TYPE abap_bool VALUE 'X',
      gv_locked_stock TYPE zprd_stock_id,
      gv_priority TYPE zprd_priority,
      gv_error TYPE abap_bool,
      gv_uncertain TYPE abap_bool,
      gv_saved TYPE abap_bool,
      gv_log_error TYPE abap_bool,
      gv_busy TYPE abap_bool,
      gv_block_reason TYPE c LENGTH 120,
      gv_dummy TYPE string,
      gr_container TYPE REF TO cl_gui_custom_container,
      gr_grid TYPE REF TO cl_gui_alv_grid,
      gr_header_container TYPE REF TO cl_gui_docking_container,
      gr_header TYPE REF TO cl_dd_document.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.
PARAMETERS p_stokid TYPE zprd_stock_id OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b01.
SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE text-002.
PARAMETERS p_vari TYPE slis_vari.
SELECTION-SCREEN END OF BLOCK b02.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_stokid.
  PERFORM stock_f4.

AT SELECTION-SCREEN.
  SELECT SINGLE * FROM zprt_stock INTO gs_stock
    WHERE stock_id = p_stokid.
  IF sy-subrc <> 0.
    MESSAGE e000 WITH text-101 p_stokid.
  ENDIF.

START-OF-SELECTION.
  IF sy-batch = abap_true.
    MESSAGE s000 WITH text-102
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
  IF sy-subrc <> 0.
    MESSAGE s000 WITH text-103 gc_tcode
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  CLEAR: gv_busy, gv_saved, gv_uncertain, gv_locked_stock.
  PERFORM read_stock.

  IF gv_error = abap_true.
    MESSAGE s000 WITH text-104
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM determine_mode.
  PERFORM sync_lock.
  IF gv_error = abap_true.
    PERFORM unlock_stock.
    PERFORM log_write.
    RETURN.
  ENDIF.
  PERFORM select_data.

  IF gv_error = abap_true.
    PERFORM unlock_stock.
    PERFORM log_write.
    RETURN.
  ENDIF.

  PERFORM show_mode_message.
  CALL SCREEN 0100.

  PERFORM unlock_stock.
  PERFORM free_controls.

INCLUDE zpr_stock_report_o01.
INCLUDE zpr_stock_report_i01.

CLASS lcl_grid_events IMPLEMENTATION.
  METHOD on_toolbar.
    DATA ls_button TYPE stb_button.
    DELETE e_object->mt_toolbar
      WHERE function = 'RELEASE' OR function = 'ZREFRESH'.
    IF gv_modif = abap_true AND gv_busy = abap_false
       AND gv_locked_stock = p_stokid.
      CLEAR ls_button.
      ls_button-function = 'RELEASE'.
      ls_button-icon = icon_release.
      ls_button-text = text-105.
      ls_button-quickinfo = text-106.
      APPEND ls_button TO e_object->mt_toolbar.
    ENDIF.
    CLEAR ls_button.
    ls_button-function = 'ZREFRESH'.
    ls_button-icon = icon_refresh.
    ls_button-text = text-107.
    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_user_command.
    CASE e_ucomm.
      WHEN 'RELEASE'.
        PERFORM release_stock.
      WHEN 'ZREFRESH'.
        PERFORM reload_display.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

FORM read_stock.
  DATA lr_error TYPE REF TO cx_root.
  CLEAR gs_stock.
  gv_error = abap_true.
  TRY.
      SELECT SINGLE * FROM zprt_stock BYPASSING BUFFER INTO gs_stock
        WHERE stock_id = p_stokid.
      IF sy-subrc = 0.
        gv_error = abap_false.
      ENDIF.
    CATCH cx_root INTO lr_error.
      PERFORM add_exception USING lr_error.
  ENDTRY.
ENDFORM.

FORM determine_mode.
  gv_modif = abap_false.
  CLEAR gv_block_reason.
  IF gs_stock-closed IS NOT INITIAL OR gs_stock-status = gc_status_closed.
    gv_block_reason = text-108.
  ELSEIF gs_stock-stock_status_er IS NOT INITIAL OR gv_uncertain = abap_true.
    gv_block_reason = text-109.
  ELSEIF gs_stock-status <> gc_status_qm.
    gv_block_reason = text-110.
  ELSE.
    gv_modif = abap_true.
  ENDIF.
ENDFORM.

FORM show_mode_message.
  "Dialog adapter: reads GV_MODIF and GV_BLOCK_REASON; no business update.
  CHECK gv_modif = abap_false AND gv_block_reason IS NOT INITIAL.
  MESSAGE gv_block_reason TYPE 'I'.
ENDFORM.

FORM sync_lock.
  "Dialog adapter: synchronizes GS_STOCK, GV_MODIF, GV_ERROR and the owned lock.
  IF gv_modif <> abap_true.
    PERFORM unlock_stock.
    RETURN.
  ENDIF.
  IF gv_locked_stock = p_stokid.
    RETURN.
  ENDIF.
  PERFORM lock_stock.
  IF gv_locked_stock <> p_stokid.
    gv_modif = abap_false.
    RETURN.
  ENDIF.
  "Recheck after enqueue; another session may have closed the stock.
  PERFORM read_stock.
  IF gv_error = abap_true.
    gv_modif = abap_false.
    gv_block_reason = text-104.
  ELSE.
    PERFORM determine_mode.
  ENDIF.
  IF gv_modif <> abap_true.
    PERFORM unlock_stock.
  ENDIF.
ENDFORM.

FORM select_data.
  DATA: lt_texts TYPE STANDARD TABLE OF zprt_dcqmlt,
        ls_text TYPE zprt_dcqmlt,
        lr_error TYPE REF TO cx_root.
  FIELD-SYMBOLS <ls_alv> TYPE zprs_dcqm_report.

  CLEAR: gv_total, gv_excluded, gv_allowed.
  REFRESH gt_alv.
  gv_error = abap_true.
  TRY.
      SELECT COUNT(*) FROM zprt_dcqm INTO gv_total
        WHERE prd_stock_id = p_stokid.
      SELECT * FROM zprt_dcqm
        INTO CORRESPONDING FIELDS OF TABLE gt_alv
        WHERE prd_stock_id = p_stokid
          AND ( block_dc <> space OR block_qm <> space ).
      IF gt_alv IS NOT INITIAL.
        SELECT * FROM zprt_dcqmlt INTO TABLE lt_texts
          FOR ALL ENTRIES IN gt_alv
          WHERE exbilldocno = gt_alv-doc_no.
      ENDIF.
    CATCH cx_root INTO lr_error.
      PERFORM add_exception USING lr_error.
      RETURN.
  ENDTRY.
  SORT gt_alv BY doc_no envelope.
  SORT lt_texts BY exbilldocno.
  LOOP AT gt_alv ASSIGNING <ls_alv>.
    CLEAR ls_text.
    READ TABLE lt_texts INTO ls_text
      WITH KEY exbilldocno = <ls_alv>-doc_no BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_alv>-block_dc_text = ls_text-block_dc_text.
      <ls_alv>-block_qm_text = ls_text-block_qm_text.
    ENDIF.
    <ls_alv>-counter = 1.
    CLEAR: <ls_alv>-changed, <ls_alv>-handle_style.
  ENDLOOP.
  DESCRIBE TABLE gt_alv LINES gv_excluded.
  gv_allowed = gv_total - gv_excluded.
  gv_error = abap_false.
ENDFORM.

FORM release_stock.
  DATA: lt_displayed TYPE ty_alv_table,
        lv_displayed_total TYPE i,
        lv_confirmed TYPE abap_bool,
        lv_priority_ok TYPE abap_bool,
        lv_selection_error TYPE abap_bool.

  CHECK gv_busy = abap_false.
  REFRESH gt_messages.
  CLEAR gv_saved.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
  IF sy-subrc <> 0.
    MESSAGE s000 WITH text-103 gc_tcode
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF gv_modif <> abap_true OR gv_uncertain = abap_true
     OR gv_locked_stock <> p_stokid.
    IF gv_block_reason IS INITIAL.
      gv_block_reason = text-111.
    ENDIF.
    MESSAGE gv_block_reason TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM get_priority CHANGING lv_priority_ok.
  CHECK lv_priority_ok = abap_true.
  PERFORM confirm_release CHANGING lv_confirmed.
  CHECK lv_confirmed = abap_true.
  gv_busy = abap_true.

  PERFORM read_stock.
  IF gv_error = abap_true.
    gv_modif = abap_false.
    PERFORM add_message USING 'E' text-101 p_stokid space.
  ELSE.
    PERFORM determine_mode.
    IF gv_modif <> abap_true.
      gv_error = abap_true.
      PERFORM add_message USING 'E' gv_block_reason p_stokid space.
    ENDIF.
  ENDIF.

  IF gv_error = abap_false.
    lt_displayed = gt_alv.
    SORT lt_displayed BY doc_no envelope.
    lv_displayed_total = gv_total.
    PERFORM select_data.
    lv_selection_error = gv_error.
    IF gv_error = abap_false
       AND ( lt_displayed <> gt_alv OR lv_displayed_total <> gv_total ).
      gv_error = abap_true.
      PERFORM add_message USING 'E'
        text-112 space space.
    ENDIF.
  ENDIF.
  IF gv_error = abap_false AND gv_total = 0.
    gv_error = abap_true.
    PERFORM add_message USING 'E'
      text-113 p_stokid space.
  ENDIF.
  IF gv_error = abap_false.
    "The class owns Inspire, the business commit and its existing error handling.
    zcl_pr_stock=>close_stock(
      EXPORTING iv_stock = p_stokid
                iv_priority = gv_priority
                iv_lock_held = abap_true
                iv_display_log = abap_false
      IMPORTING ev_success = gv_saved
                ev_uncertain = gv_uncertain
                et_messages = gt_messages ).
  ENDIF.
  gv_busy = abap_false.
  PERFORM log_write.

  PERFORM read_stock.
  IF gv_error = abap_false.
    PERFORM determine_mode.
    IF lv_selection_error = abap_true.
      gv_modif = abap_false.
      gv_block_reason = text-114.
      PERFORM unlock_stock.
    ELSE.
      PERFORM sync_lock.
    ENDIF.
  ELSE.
    gv_modif = abap_false.
    gv_block_reason = text-104.
    PERFORM unlock_stock.
  ENDIF.
  PERFORM refresh_grid.
  IF gv_saved = abap_true AND gv_log_error = abap_true.
    MESSAGE s000 WITH text-115 p_stokid
      DISPLAY LIKE 'E'.
  ELSEIF gv_saved = abap_true.
    MESSAGE s000 WITH text-116 p_stokid.
  ELSE.
    MESSAGE s000 WITH text-117
      DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

FORM get_priority CHANGING cv_ok TYPE abap_bool.
  DATA: lt_fields TYPE STANDARD TABLE OF sval,
        ls_field TYPE sval,
        lv_return TYPE c LENGTH 1.
  cv_ok = abap_false.
  CLEAR ls_field.
  ls_field-tabname = 'ZPRT_STOCK'.
  ls_field-fieldname = 'PRIORITY'.
  IF gs_stock-priority IS INITIAL.
    ls_field-value = gc_default_priority.
  ELSE.
    ls_field-value = gs_stock-priority.
  ENDIF.
  ls_field-field_obl = abap_true.
  APPEND ls_field TO lt_fields.
  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING popup_title = text-118
    IMPORTING returncode = lv_return
    TABLES fields = lt_fields
    EXCEPTIONS error_in_fields = 1 OTHERS = 2.
  IF sy-subrc <> 0 OR lv_return = 'A'.
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field INDEX 1.
  IF sy-subrc <> 0 OR ls_field-value IS INITIAL.
    MESSAGE s000 WITH text-119 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  gv_priority = ls_field-value.
  IF gv_priority IS INITIAL.
    MESSAGE s000 WITH text-120 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  cv_ok = abap_true.
ENDFORM.

FORM confirm_release CHANGING cv_ok TYPE abap_bool.
  DATA: lv_answer TYPE c LENGTH 1,
        lv_question TYPE c LENGTH 200.
  cv_ok = abap_false.
  CONCATENATE text-121 p_stokid
    text-122 gv_priority INTO lv_question SEPARATED BY space.
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING titlebar = text-123
              text_question = lv_question
              default_button = '2'
              display_cancel_button = abap_true
    IMPORTING answer = lv_answer
    EXCEPTIONS text_not_found = 1 OTHERS = 2.
  IF sy-subrc = 0 AND lv_answer = '1'.
    cv_ok = abap_true.
  ENDIF.
ENDFORM.

FORM lock_stock.
  IF gv_locked_stock = p_stokid.
    RETURN.
  ENDIF.
  PERFORM unlock_stock.
  CALL FUNCTION 'ENQUEUE_EZPRT_STOCK'
    EXPORTING stock_id = p_stokid _scope = '1'
    EXCEPTIONS foreign_lock = 1 system_failure = 2 OTHERS = 3.
  IF sy-subrc = 1.
    CONCATENATE text-124 sy-msgv1
      INTO gv_block_reason SEPARATED BY space.
    RETURN.
  ELSEIF sy-subrc <> 0.
    gv_block_reason = text-125.
    RETURN.
  ENDIF.
  gv_locked_stock = p_stokid.
ENDFORM.

FORM unlock_stock.
  CHECK gv_locked_stock IS NOT INITIAL.
  CALL FUNCTION 'DEQUEUE_EZPRT_STOCK'
    EXPORTING stock_id = gv_locked_stock _scope = '1'.
  CLEAR gv_locked_stock.
ENDFORM.











FORM add_message USING uv_type TYPE symsgty uv_text TYPE clike
                       uv_value1 TYPE clike uv_value2 TYPE clike.
  DATA: ls_message TYPE bal_s_msg,
        lv_text TYPE c LENGTH 200.
  CONCATENATE uv_text uv_value1 uv_value2 INTO lv_text SEPARATED BY space.
  ls_message-msgid = 'ZPR'.
  ls_message-msgno = '000'.
  ls_message-msgty = uv_type.
  ls_message-msgv1 = lv_text+0(50).
  ls_message-msgv2 = lv_text+50(50).
  ls_message-msgv3 = lv_text+100(50).
  ls_message-msgv4 = lv_text+150(50).
  APPEND ls_message TO gt_messages.
ENDFORM.

FORM add_exception USING ur_error TYPE REF TO cx_root.
  DATA: ls_message TYPE bal_s_msg,
        lv_text TYPE c LENGTH 200.
  lv_text = ur_error->get_text( ).
  ls_message-msgid = 'ZPR'.
  ls_message-msgno = '000'.
  ls_message-msgty = 'E'.
  ls_message-msgv1 = lv_text+0(50).
  ls_message-msgv2 = lv_text+50(50).
  ls_message-msgv3 = lv_text+100(50).
  ls_message-msgv4 = lv_text+150(50).
  APPEND ls_message TO gt_messages.
ENDFORM.

FORM log_write.
  DATA: lo_log TYPE REF TO zcl_pr_log,
        lr_error TYPE REF TO cx_root,
        ls_message TYPE bal_s_msg,
        lv_text TYPE string.
  gv_log_error = abap_false.
  CHECK gt_messages IS NOT INITIAL.
  "Business changes have already been committed or rolled back.
  TRY.
      CREATE OBJECT lo_log
        EXPORTING iv_log_object = gc_log_object
                  iv_log_subobject = gc_log_subobject.
      LOOP AT gt_messages INTO ls_message.
        MESSAGE ID ls_message-msgid TYPE ls_message-msgty
          NUMBER ls_message-msgno
          WITH ls_message-msgv1 ls_message-msgv2
               ls_message-msgv3 ls_message-msgv4 INTO gv_dummy.
        lo_log->add_system_message( ).
      ENDLOOP.
      lo_log->close( ).
      COMMIT WORK.
      lo_log->display( ).
    CATCH cx_root INTO lr_error.
      ROLLBACK WORK.
      gv_log_error = abap_true.
      lv_text = lr_error->get_text( ).
      MESSAGE s000 WITH text-126 lv_text
        DISPLAY LIKE 'E'.
  ENDTRY.
ENDFORM.

FORM stock_f4.
  DATA: lt_stocks TYPE STANDARD TABLE OF ty_stock_f4,
        lt_returns TYPE STANDARD TABLE OF ddshretval,
        ls_return TYPE ddshretval.
  SELECT stock_id status closed dccompl qmcompl priority
    FROM zprt_stock INTO TABLE lt_stocks UP TO 5000 ROWS
    ORDER BY stock_id DESCENDING.
  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING retfield = 'STOCK_ID' value_org = 'S'
              window_title = text-127
    TABLES value_tab = lt_stocks return_tab = lt_returns
    EXCEPTIONS parameter_error = 1 no_values_found = 2 OTHERS = 3.
  IF sy-subrc = 0.
    READ TABLE lt_returns INTO ls_return INDEX 1.
    IF sy-subrc = 0.
      p_stokid = ls_return-fieldval.
    ENDIF.
  ENDIF.
ENDFORM.

FORM create_controls_0100.
  DATA: lt_fields TYPE lvc_t_fcat,
        ls_layout TYPE lvc_s_layo,
        ls_variant TYPE disvariant,
        lt_exclude TYPE ui_functions,
        lv_function TYPE ui_func.
  FIELD-SYMBOLS <ls_field> TYPE lvc_s_fcat.
  CHECK gr_grid IS NOT BOUND.
  IF gr_header_container IS NOT BOUND.
    CREATE OBJECT gr_header_container
      EXPORTING side = cl_gui_docking_container=>dock_at_top
                extension = 135
      EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      FREE gr_header_container.
      MESSAGE s000 WITH text-128 DISPLAY LIKE 'W'.
    ENDIF.
  ENDIF.
  PERFORM build_header.
  CREATE OBJECT gr_container
    EXPORTING container_name = 'ALV_CONTAINER_01'
    EXCEPTIONS OTHERS = 1.
  IF sy-subrc <> 0.
    MESSAGE e000 WITH text-129.
  ENDIF.
  CREATE OBJECT gr_grid
    EXPORTING i_parent = gr_container i_appl_events = abap_true.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING i_structure_name = 'ZPRS_DCQM_REPORT'
    CHANGING ct_fieldcat = lt_fields
    EXCEPTIONS inconsistent_interface = 1 program_error = 2 OTHERS = 3.
  IF sy-subrc <> 0.
    MESSAGE e000 WITH text-130.
  ENDIF.
  LOOP AT lt_fields ASSIGNING <ls_field>.
    <ls_field>-edit = abap_false.
    <ls_field>-f4availabl = abap_false.
    IF <ls_field>-fieldname = 'CHANGED'
       OR <ls_field>-fieldname = 'HANDLE_STYLE'.
      <ls_field>-tech = abap_true.
    ELSEIF <ls_field>-fieldname = 'COUNTER'.
      <ls_field>-do_sum = abap_true.
      <ls_field>-coltext = text-131.
      <ls_field>-col_pos = 99.
    ENDIF.
  ENDLOOP.
  ls_layout-zebra = abap_true.
  ls_layout-cwidth_opt = abap_true.
  ls_layout-no_rowmark = abap_true.
  ls_variant-report = sy-repid.
  ls_variant-username = sy-uname.
  ls_variant-variant = p_vari.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_append_row.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_insert_row.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_delete_row.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_copy_row.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_cut.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_paste.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_undo.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_refresh.
  APPEND lv_function TO lt_exclude.
  SET HANDLER lcl_grid_events=>on_toolbar
              lcl_grid_events=>on_user_command FOR gr_grid.
  gr_grid->set_table_for_first_display(
    EXPORTING is_layout = ls_layout is_variant = ls_variant
              i_save = 'A' it_toolbar_excluding = lt_exclude
    CHANGING it_outtab = gt_alv it_fieldcatalog = lt_fields
    EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc <> 0.
    MESSAGE e000 WITH text-132.
  ENDIF.
  gr_grid->set_ready_for_input(
    i_ready_for_input = 0                " Ready for Input Status
  ).
  gr_grid->set_toolbar_interactive( ).
ENDFORM.

FORM refresh_grid.
  DATA ls_stable TYPE lvc_s_stbl.
  PERFORM build_header.
  CHECK gr_grid IS BOUND.

  ls_stable-row = abap_true.
  ls_stable-col = abap_true.

  gr_grid->refresh_table_display(
    EXPORTING is_stable = ls_stable EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc <> 0.
    MESSAGE i000 WITH text-133
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  gr_grid->set_toolbar_interactive( ).
ENDFORM.

FORM reload_display.
  CHECK gv_busy = abap_false.
  REFRESH gt_messages.
  PERFORM read_stock.
  IF gv_error = abap_false.
    PERFORM determine_mode.
    PERFORM sync_lock.
  ENDIF.
  IF gv_error = abap_false.
    PERFORM select_data.
  ENDIF.
  IF gv_error = abap_true.
    gv_modif = abap_false.
    gv_block_reason = text-104.
    CLEAR: gv_total, gv_excluded, gv_allowed.
    REFRESH gt_alv.
    PERFORM unlock_stock.
    PERFORM log_write.
  ENDIF.
  PERFORM refresh_grid.
  PERFORM show_mode_message.
ENDFORM.

FORM user_command_0100.
  DATA: lv_okcode TYPE syucomm,
        lv_return_code TYPE i.
  lv_okcode = gv_okcode_0100.
  CLEAR gv_okcode_0100.
  cl_gui_cfw=>dispatch(
    IMPORTING return_code = lv_return_code ).
  IF lv_return_code = cl_gui_cfw=>rc_unknown
     OR lv_return_code = cl_gui_cfw=>rc_nodispatch.
    MESSAGE s000 WITH text-134
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF lv_return_code = cl_gui_cfw=>rc_found.
    RETURN.
  ENDIF.
  CASE lv_okcode.
    WHEN 'REFRESH'.
      PERFORM reload_display.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      PERFORM exit_screen.
  ENDCASE.
ENDFORM.

FORM exit_command_0100.
  DATA lv_okcode TYPE syucomm.
  lv_okcode = gv_okcode_0100.
  CLEAR gv_okcode_0100.
  CASE lv_okcode.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      PERFORM exit_screen.
  ENDCASE.
ENDFORM.

FORM exit_screen.
  CHECK gv_busy = abap_false.
  PERFORM unlock_stock.
  SET SCREEN 0.
  LEAVE SCREEN.
ENDFORM.

FORM free_controls.
DATA lv_free_failed TYPE abap_bool.

  IF gr_grid IS BOUND.
    gr_grid->free( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      lv_free_failed = abap_true.
    ENDIF.
    FREE gr_grid.
  ENDIF.

  IF gr_container IS BOUND.
    gr_container->free( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      lv_free_failed = abap_true.
    ENDIF.
    FREE gr_container.
  ENDIF.

  FREE gr_header.
  IF gr_header_container IS BOUND.
    gr_header_container->free( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      lv_free_failed = abap_true.
    ENDIF.
    FREE gr_header_container.
  ENDIF.

  IF lv_free_failed = abap_true.
    MESSAGE i000 WITH text-135
      DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.
FORM build_header.
  "Display only: reads stock/count/mode globals and maintains the header controls.
  DATA: lv_text TYPE sdydo_text_element,
        lv_number TYPE c LENGTH 20,
        lv_reuse TYPE abap_bool.
  CHECK gr_header_container IS BOUND.
  IF gr_header IS BOUND.
    lv_reuse = abap_true.
    gr_header->initialize_document( ).
  ELSE.
    CREATE OBJECT gr_header.
  ENDIF.
  CONCATENATE text-136 p_stokid INTO lv_text SEPARATED BY space.
  PERFORM add_header_line USING lv_text.
  WRITE gv_total TO lv_number LEFT-JUSTIFIED.
  CONCATENATE text-137 lv_number INTO lv_text SEPARATED BY space.
  PERFORM add_header_line USING lv_text.
  WRITE gv_excluded TO lv_number LEFT-JUSTIFIED.
  CONCATENATE text-138 lv_number INTO lv_text SEPARATED BY space.
  PERFORM add_header_line USING lv_text.
  WRITE gv_allowed TO lv_number LEFT-JUSTIFIED.
  CONCATENATE text-139 lv_number INTO lv_text SEPARATED BY space.
  PERFORM add_header_line USING lv_text.
  IF gv_modif <> abap_true AND gv_block_reason IS NOT INITIAL.
    lv_text = gv_block_reason.
    PERFORM add_header_line USING lv_text.
  ENDIF.
  gr_header->merge_document( ).
  gr_header->display_document(
    EXPORTING parent = gr_header_container reuse_control = lv_reuse
    EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc <> 0.
    MESSAGE s000 WITH text-140 DISPLAY LIKE 'W'.
  ENDIF.
ENDFORM.

FORM add_header_line USING uv_text TYPE sdydo_text_element.
  gr_header->add_text( text = uv_text
    sap_emphasis = cl_dd_document=>strong ).
  gr_header->new_line( ).
ENDFORM.

CLASS ltc_stock_mode DEFINITION FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA: ms_stock TYPE zprt_stock,
          mv_modif TYPE abap_bool,
          mv_uncertain TYPE abap_bool,
          mv_reason TYPE c LENGTH 120.
    METHODS: setup,
             teardown,
             qm_can_close FOR TESTING,
             closed_flag_blocks_qm FOR TESTING,
             cl_status_is_display FOR TESTING,
             dm_status_is_display FOR TESTING,
             open_status_is_display FOR TESTING,
             external_error_blocks_qm FOR TESTING,
             uncertain_state_blocks_qm FOR TESTING.
ENDCLASS.

CLASS ltc_stock_mode IMPLEMENTATION.
  METHOD setup.
    ms_stock = gs_stock.
    mv_modif = gv_modif.
    mv_uncertain = gv_uncertain.
    mv_reason = gv_block_reason.
    CLEAR: gs_stock, gv_modif, gv_uncertain, gv_block_reason.
  ENDMETHOD.

  METHOD teardown.
    gs_stock = ms_stock.
    gv_modif = mv_modif.
    gv_uncertain = mv_uncertain.
    gv_block_reason = mv_reason.
  ENDMETHOD.

  METHOD qm_can_close.
    gs_stock-status = gc_status_qm.
    PERFORM determine_mode.
    cl_abap_unit_assert=>assert_equals( exp = abap_true act = gv_modif ).
    cl_abap_unit_assert=>assert_initial( act = gv_block_reason ).
  ENDMETHOD.

  METHOD closed_flag_blocks_qm.
    gs_stock-status = gc_status_qm.
    gs_stock-closed = abap_true.
    PERFORM determine_mode.
    cl_abap_unit_assert=>assert_equals( exp = abap_false act = gv_modif ).
    cl_abap_unit_assert=>assert_equals( exp = text-108 act = gv_block_reason ).
  ENDMETHOD.

  METHOD cl_status_is_display.
    gs_stock-status = gc_status_closed.
    PERFORM determine_mode.
    cl_abap_unit_assert=>assert_equals( exp = abap_false act = gv_modif ).
    cl_abap_unit_assert=>assert_equals( exp = text-108 act = gv_block_reason ).
  ENDMETHOD.

  METHOD dm_status_is_display.
    gs_stock-status = 'DM'.
    PERFORM determine_mode.
    cl_abap_unit_assert=>assert_equals( exp = abap_false act = gv_modif ).
    cl_abap_unit_assert=>assert_equals( exp = text-110 act = gv_block_reason ).
  ENDMETHOD.

  METHOD open_status_is_display.
    PERFORM determine_mode.
    cl_abap_unit_assert=>assert_equals( exp = abap_false act = gv_modif ).
    cl_abap_unit_assert=>assert_equals( exp = text-110 act = gv_block_reason ).
  ENDMETHOD.

  METHOD external_error_blocks_qm.
    gs_stock-status = gc_status_qm.
    gs_stock-stock_status_er = abap_true.
    PERFORM determine_mode.
    cl_abap_unit_assert=>assert_equals( exp = abap_false act = gv_modif ).
    cl_abap_unit_assert=>assert_equals( exp = text-109 act = gv_block_reason ).
  ENDMETHOD.

  METHOD uncertain_state_blocks_qm.
    gs_stock-status = gc_status_qm.
    gv_uncertain = abap_true.
    PERFORM determine_mode.
    cl_abap_unit_assert=>assert_equals( exp = abap_false act = gv_modif ).
    cl_abap_unit_assert=>assert_equals( exp = text-109 act = gv_block_reason ).
  ENDMETHOD.
ENDCLASS.
