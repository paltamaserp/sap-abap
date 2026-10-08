*----------------------------------------------------------------------*
***INCLUDE ZEBF_PR_DCQM_REPORT_O01 .
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  STATUS_0100  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE status_0100 OUTPUT.

  IF gv_modif EQ abap_true.
    SET TITLEBAR 'TITLE_0100_MOD'.
    SET PF-STATUS 'STAT_0100'.
  ELSE.
    SET TITLEBAR 'TITLE_0100_DISP'.
    SET PF-STATUS 'STAT_0100_DISP'.
  ENDIF.

ENDMODULE.                 " STATUS_0100  OUTPUT
*&---------------------------------------------------------------------*
*&      Module  CREATE_CONTROLS_0100  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE create_controls_0100 OUTPUT.

  PERFORM create_controls_0100.

ENDMODULE.                 " CREATE_CONTROLS_0100  OUTPUT