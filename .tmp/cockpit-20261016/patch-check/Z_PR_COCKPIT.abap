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
  IF iv_stock_id IS NOT INITIAL.
    TRY.
        zprs_cockpit = zcl_pr_stock=>get_stock_header( iv_stock_id ).
      CATCH zcx_form_message_error INTO gx_error.
        MESSAGE e000 WITH gx_error->get_text(  ) INTO gv_dummy_message.
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
  gv_edit_mode = 'X'.
  CALL SCREEN 100.


ENDFUNCTION.