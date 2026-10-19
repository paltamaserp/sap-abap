*----------------------------------------------------------------------*
***INCLUDE LZPR_COCKPITO01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module T_TABSTRIP_ACTIVE_TAB_SET OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE t_tabstrip_active_tab_set OUTPUT.
  gs_tabstrip-prog = sy-repid.
  CASE gs_tabstrip-pressed_tab.
    WHEN c_tabstrip-t_dm_item.
      gs_tabstrip-subscreen = '1010'.
    WHEN c_tabstrip-t_dm_approve.
      gs_tabstrip-subscreen = '1020'.
    WHEN c_tabstrip-t_qm_check.
      PERFORM qm_open.
      IF gv_qm_ready = abap_true.
        gs_tabstrip-prog = 'ZPR_QM'.
        gs_tabstrip-subscreen = '1100'.
      ELSE.
        gs_tabstrip-pressed_tab = c_tabstrip-t_dm_approve.
        gs_tabstrip-subscreen = '1020'.
      ENDIF.
    WHEN c_tabstrip-t_qm_approve.
      gs_tabstrip-subscreen = '1040'.
    WHEN c_tabstrip-t_close.
      gs_tabstrip-subscreen = '1050'.
    WHEN OTHERS.
*&SPWIZARD:      DO NOTHING
  ENDCASE.
  t_tabstrip-activetab = gs_tabstrip-pressed_tab.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_100 OUTPUT.
  SET PF-STATUS '0100'.
  SET TITLEBAR 'Nyomtatás - Stock képzés'.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE prepare_command INPUT.
  save_ok = ok_code.
  CLEAR ok_code.
  CLEAR: gv_stock_changed, gv_dm_close_cancelled.
* Reset must work before stock validation and before the outgoing subscreen.
  IF save_ok = 'RESET'.
    PERFORM reset_cockpit.
    LEAVE TO SCREEN 100.
  ENDIF.
  IF zprs_cockpit-stock_id IS INITIAL AND save_ok IS INITIAL.
    LEAVE TO SCREEN 100.
  ENDIF.
  PERFORM accept_stock.
* Do not run the outgoing subscreen PAI against a changed stock.
  IF gv_stock_changed = abap_true OR gv_dm_close_cancelled = abap_true.
    LEAVE TO SCREEN 100.
  ENDIF.
ENDMODULE.

MODULE user_command INPUT.
* The selection-screen event only requests execution; the host dispatches it.
  CLEAR gv_qm_command_handled.
  IF gs_tabstrip-pressed_tab = c_tabstrip-t_qm_check
     AND gv_qm_ready = abap_true.
    PERFORM cockpit_execute IN PROGRAM zpr_qm
      CHANGING gv_qm_command_handled.
    IF gv_qm_command_handled = abap_true.
      CLEAR save_ok.
      RETURN.
    ENDIF.
  ENDIF.
  IF save_ok = c_tabstrip-t_dm_approve
     OR save_ok = c_tabstrip-t_qm_check
     OR save_ok = c_tabstrip-t_qm_approve
     OR save_ok = c_tabstrip-t_close
     OR save_ok = c_buttons-dm_close
     OR save_ok = c_buttons-dm_reopen
     OR save_ok = c_buttons-qm_close
     OR save_ok = c_buttons-qm_reopen
     OR save_ok = c_buttons-close
     OR save_ok = c_buttons-reopen.
    PERFORM dm_close.
    CHECK gv_dm_close_cancelled = abap_false.
  ENDIF.

  CASE save_ok.
    WHEN 'SAVE'.
      IF gv_dm_ready = abap_true.
        PERFORM cockpit_save IN PROGRAM zpr_dcqm_exclude.
      ENDIF.
    WHEN c_tabstrip-t_dm_item.
      gs_tabstrip-pressed_tab = c_tabstrip-t_dm_item.
    WHEN c_tabstrip-t_dm_approve.
      gs_tabstrip-pressed_tab = c_tabstrip-t_dm_approve.
    WHEN c_tabstrip-t_qm_check.
      gs_tabstrip-pressed_tab = c_tabstrip-t_qm_check.
    WHEN c_tabstrip-t_qm_approve.
      gs_tabstrip-pressed_tab = c_tabstrip-t_qm_approve.
    WHEN c_tabstrip-t_close.
      gs_tabstrip-pressed_tab = c_tabstrip-t_close.

    WHEN c_buttons-dm_close.

      zcl_pr_stock=>check_status(
        iv_old_status = zprs_cockpit-status
        iv_new_status = 'DM'
        iv_dir        = 'F' ). " Stock státusz

      zcl_pr_stock=>update_status(
        iv_stock_id   = zprs_cockpit-stock_id
        iv_new_status = 'DM' ). " Stock státusz

    WHEN c_buttons-dm_reopen.
      zcl_pr_stock=>check_status(
        iv_old_status = zprs_cockpit-status
        iv_new_status = space
        iv_dir        = 'B' ). " Stock státusz


      zcl_pr_stock=>update_status(
        iv_stock_id   = zprs_cockpit-stock_id
        iv_new_status = space ).

    WHEN c_buttons-qm_close.

      zcl_pr_stock=>check_status(
        iv_old_status = zprs_cockpit-status
        iv_new_status = 'QM'
        iv_dir        = 'F' ). " Stock státusz

      zcl_pr_stock=>update_status(
        iv_stock_id   = zprs_cockpit-stock_id
        iv_new_status = 'QM' ).

    WHEN c_buttons-qm_reopen.

      zcl_pr_stock=>check_status(
        iv_old_status = zprs_cockpit-status
        iv_new_status = 'DM'
        iv_dir        = 'B' ). " Stock státusz

      zcl_pr_stock=>update_status(
        iv_stock_id   = zprs_cockpit-stock_id
        iv_new_status = 'DM' ).

    WHEN c_buttons-close.

      zcl_pr_stock=>check_status(
        iv_old_status = zprs_cockpit-status
        iv_new_status = 'CL'
        iv_dir        = 'F' ). " Stock státusz

      zcl_pr_stock=>update_status(
        iv_stock_id   = zprs_cockpit-stock_id
        iv_new_status = 'CL' ).

    WHEN c_buttons-reopen.

      zcl_pr_stock=>check_status(
        iv_old_status = zprs_cockpit-status
        iv_new_status = 'QM'
        iv_dir        = 'B' ). " Stock státusz

      zcl_pr_stock=>update_status(
        iv_stock_id   = zprs_cockpit-stock_id
        iv_new_status = 'QM' ).

  ENDCASE.
  IF gs_tabstrip-pressed_tab = c_tabstrip-t_dm_item
     AND gv_dm_ready = abap_false.
    PERFORM dm_open.
  ENDIF.
ENDMODULE.

MODULE cancel INPUT.
  CLEAR save_ok.
  PERFORM dm_close.
  IF gv_dm_close_cancelled = abap_true.
    CLEAR: ok_code, save_ok.
    LEAVE TO SCREEN 100.
  ENDIF.
  PERFORM qm_close.
  LEAVE TO SCREEN 0.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module SCREEN_ATTRIBUTES OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE screen_attributes OUTPUT.
  LOOP AT SCREEN.
    IF screen-name = 'ZPRS_COCKPIT-STOCK_ID'.
      IF gv_stock_id IS INITIAL.
        screen-input = 1.
      ELSE.
        screen-input = 0.
      ENDIF.
      MODIFY SCREEN.
    ELSEIF screen-group1 = 'HDR'.
      screen-input = 0.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module UPDATE_HEADER OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE update_header OUTPUT.
  IF gv_stock_id IS NOT INITIAL.
    TRY.
        zprs_cockpit = zcl_pr_stock=>get_stock_header( gv_stock_id ).
      CATCH zcx_form_message_error INTO gx_error.
        CLEAR zprs_cockpit.
        zprs_cockpit-stock_id = gv_stock_id.
    ENDTRY.
  ENDIF.
ENDMODULE.

MODULE dm_controls OUTPUT.
  CHECK gv_dm_ready = abap_true.
  IF go_dm_container IS INITIAL.
    CREATE OBJECT go_dm_container
      EXPORTING
        container_name              = 'ALV_CONTAINER_01'
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc <> 0.
      MESSAGE text-102 TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ENDIF.
  PERFORM cockpit_pbo IN PROGRAM zpr_dcqm_exclude
    USING go_dm_container.
ENDMODULE.

FORM accept_stock.
  DATA ls_header LIKE zprs_cockpit.

* The accepted stock can only be changed through RESET.
  IF gv_stock_id IS NOT INITIAL.
    zprs_cockpit-stock_id = gv_stock_id.
  ENDIF.
  IF zprs_cockpit-stock_id IS INITIAL.
    MESSAGE text-101 TYPE 'E'.
  ENDIF.
* Normalize the external ID before lookup and context comparison.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = zprs_cockpit-stock_id
    IMPORTING
      output = zprs_cockpit-stock_id.
  TRY.
      ls_header = zcl_pr_stock=>get_stock_header( zprs_cockpit-stock_id ).
    CATCH zcx_form_message_error INTO gx_error.
      MESSAGE gx_error->get_text( ) TYPE 'E'.
  ENDTRY.

  IF zprs_cockpit-stock_id <> gv_stock_id.
    PERFORM dm_close.
    IF gv_dm_close_cancelled = abap_true.
      zprs_cockpit-stock_id = gv_stock_id.
      RETURN.
    ENDIF.
    PERFORM qm_close.
    gv_stock_id = zprs_cockpit-stock_id.
    zprs_cockpit = ls_header.
    gs_tabstrip-pressed_tab = c_tabstrip-t_dm_item.
    PERFORM dm_open.
    gv_stock_changed = abap_true.
  ELSE.
    zprs_cockpit = ls_header.
  ENDIF.
ENDFORM.

FORM dm_open.
  CHECK gv_stock_id IS NOT INITIAL.
  PERFORM cockpit_open IN PROGRAM zpr_dcqm_exclude
    USING gv_stock_id CHANGING gv_dm_ready.
ENDFORM.

FORM dm_close.
  DATA lv_ok TYPE abap_bool.
  CLEAR gv_dm_close_cancelled.
  CHECK gv_dm_ready = abap_true.
  PERFORM cockpit_close IN PROGRAM zpr_dcqm_exclude CHANGING lv_ok.
  IF lv_ok = abap_true.
* The report has freed the shared container; release the host reference too.
    FREE go_dm_container.
    CLEAR gv_dm_ready.
  ELSE.
    gv_dm_close_cancelled = abap_true.
  ENDIF.
ENDFORM.

FORM reset_cockpit.
* Keep the entire current context if discarding changes is declined.
  PERFORM dm_close.
  CHECK gv_dm_close_cancelled = abap_false.

  PERFORM qm_close.
  CLEAR: zprs_cockpit, gv_stock_id, gv_dm_ready, gv_edit_mode,
         gv_qm_ready, gv_qm_command_handled,
         gv_stock_changed, gv_dm_close_cancelled,
         gx_error, gv_dummy_message, ok_code, save_ok, gs_tabstrip.
  gs_tabstrip-prog = sy-repid.
  gs_tabstrip-subscreen = '1010'.
  gs_tabstrip-pressed_tab = c_tabstrip-t_dm_item.
  t_tabstrip-activetab = c_tabstrip-t_dm_item.
ENDFORM.

FORM qm_open.
  CHECK gv_stock_id IS NOT INITIAL.
  PERFORM cockpit_open IN PROGRAM zpr_qm
    USING gv_stock_id CHANGING gv_qm_ready.
ENDFORM.

FORM qm_close.
  CHECK gv_qm_ready = abap_true.
  PERFORM cockpit_close IN PROGRAM zpr_qm.
  CLEAR: gv_qm_ready, gv_qm_command_handled.
ENDFORM.
