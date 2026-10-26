FUNCTION z_pr_cockpit.
*"----------------------------------------------------------------------
*"*"Lokális interfész:
*"  IMPORTING
*"     REFERENCE(IV_STOCK_ID) TYPE  ZPRD_STOCK_ID OPTIONAL
*"----------------------------------------------------------------------
* Rövid leírás: Stock menedzsment
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.13.   X0097         Létrehozva
*---------------------------------------------------------------*
  DATA lv_stock_id TYPE zprd_stock_id.

  PERFORM qm_close.
  CLEAR: zprs_cockpit, gv_stock_id, gv_dm_ready,
         gv_qm_ready, gv_qm_command_handled,
         ok_code, save_ok, gs_tabstrip.
  gs_tabstrip-prog = sy-repid.
  gs_tabstrip-pressed_tab = c_tabstrip-t_dm_item.
  IF iv_stock_id IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = iv_stock_id
      IMPORTING
        output = lv_stock_id.
    TRY.
        zprs_cockpit = zcl_pr_stock=>get_stock_header( lv_stock_id ).
        gv_stock_id = lv_stock_id.
      CATCH zcx_form_message_error INTO gx_error.
        MESSAGE gx_error->get_text( ) TYPE 'I' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
  ENDIF.

  CASE zprs_cockpit-status.
    WHEN space.
      gs_tabstrip-pressed_tab =  c_tabstrip-t_dm_item.
    WHEN 'DM'.
      gs_tabstrip-pressed_tab =  c_tabstrip-t_qm_check.
    WHEN 'QM'.
      gs_tabstrip-pressed_tab = c_tabstrip-t_close.
    WHEN 'CL'.
      gs_tabstrip-pressed_tab =  c_tabstrip-t_close.
  ENDCASE.
  gv_edit_mode = abap_false.
  IF gv_stock_id IS NOT INITIAL
     AND gs_tabstrip-pressed_tab = c_tabstrip-t_dm_item.
    PERFORM dm_open.
  ENDIF.
  CALL SCREEN 100.
  PERFORM qm_close.


ENDFUNCTION.
