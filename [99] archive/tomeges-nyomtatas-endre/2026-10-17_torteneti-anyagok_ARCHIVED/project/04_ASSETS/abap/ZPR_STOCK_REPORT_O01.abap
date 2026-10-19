*&---------------------------------------------------------------------*
*& Include ZPR_STOCK_REPORT_O01
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STAT_0100'.
  IF gv_modif = abap_true.
    SET TITLEBAR 'TITLE_0100_MOD'.
  ELSE.
    SET TITLEBAR 'TITLE_0100_DISP'.
  ENDIF.
ENDMODULE.

MODULE create_controls_0100 OUTPUT.
  PERFORM create_controls_0100.
ENDMODULE.
