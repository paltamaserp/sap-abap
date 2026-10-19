*&---------------------------------------------------------------------*
*& Include ZPR_DOC_RIP_O01
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STAT_0100'.
  SET TITLEBAR 'TITLE_0100_DISP'.
ENDMODULE.

MODULE create_controls_0100 OUTPUT.
  PERFORM create_controls.
ENDMODULE.
