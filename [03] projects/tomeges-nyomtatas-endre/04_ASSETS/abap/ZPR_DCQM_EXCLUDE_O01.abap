*----------------------------------------------------------------------*
***INCLUDE ZPR_DCQM_EXCLUDE_O01 .
*----------------------------------------------------------------------*
* PBO modulok - Screen 0100
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  STATUS_0100  OUTPUT
*&---------------------------------------------------------------------*
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
MODULE create_controls_0100 OUTPUT.

  PERFORM create_controls_0100.

ENDMODULE.                 " CREATE_CONTROLS_0100  OUTPUT
