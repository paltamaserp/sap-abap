*----------------------------------------------------------------------*
***INCLUDE LZPR_COCKPITO01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module T_TABSTRIP_ACTIVE_TAB_SET OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE t_tabstrip_active_tab_set OUTPUT.
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
MODULE user_command INPUT.
  save_ok = ok_code.
  CLEAR ok_code.
  CASE save_ok.
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
ENDMODULE.

MODULE cancel INPUT.
  LEAVE PROGRAM.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module SCREEN_ATTRIBUTES OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE screen_attributes OUTPUT.
  LOOP AT SCREEN.
    IF screen-group1 = 'HDR'.
      IF gv_edit_mode = abap_true.
        screen-input = 0.
      ELSE.
        screen-input = 1.
      ENDIF.
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

*  BREAK-POINT.
  IF gv_edit_mode IS INITIAL.
    IF zprs_cockpit-stock_id IS NOT INITIAL.
      zprs_cockpit = zcl_pr_stock=>get_stock_header( zprs_cockpit-stock_id ).
    ENDIF.
  ENDIF.

ENDMODULE.