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
      gs_tabstrip-subscreen = '1030'.
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
  IF zprs_cockpit-stock_id IS INITIAL AND save_ok IS INITIAL.
    LEAVE TO SCREEN 100.
  ENDIF.
  PERFORM accept_stock.
* Do not run the outgoing subscreen PAI against a changed stock.
  IF save_ok = '#STOCK' OR save_ok = '#CANCEL'.
    LEAVE TO SCREEN 100.
  ENDIF.
ENDMODULE.

MODULE user_command INPUT.
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
    CHECK save_ok <> '#CANCEL'.
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
  IF save_ok = '#CANCEL'.
    CLEAR: ok_code, save_ok.
    LEAVE TO SCREEN 100.
  ENDIF.
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
      screen-input = 1.
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
  DATA: lv_repid TYPE syrepid,
        lv_dynnr TYPE sydynnr.
  IF gv_dm_ready = abap_true.
    lv_repid = sy-repid.
    lv_dynnr = sy-dynnr.
    PERFORM cockpit_pbo IN PROGRAM zpr_dcqm_exclude
      USING lv_repid lv_dynnr.
  ENDIF.
ENDMODULE.

FORM accept_stock.
  DATA ls_header LIKE zprs_cockpit.

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
    IF save_ok = '#CANCEL'.
      zprs_cockpit-stock_id = gv_stock_id.
      RETURN.
    ENDIF.
    gv_stock_id = zprs_cockpit-stock_id.
    zprs_cockpit = ls_header.
    gs_tabstrip-pressed_tab = c_tabstrip-t_dm_item.
    PERFORM dm_open.
    save_ok = '#STOCK'.
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
  CHECK gv_dm_ready = abap_true.
  PERFORM cockpit_close IN PROGRAM zpr_dcqm_exclude CHANGING lv_ok.
  IF lv_ok = abap_true.
    CLEAR gv_dm_ready.
  ELSE.
    save_ok = '#CANCEL'.
  ENDIF.
ENDFORM.
