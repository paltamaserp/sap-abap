*&---------------------------------------------------------------------*
*& Include ZPR_DOC_RIP_I01
*&---------------------------------------------------------------------*
MODULE exit_command_0100 INPUT.
  DATA lv_exit_command TYPE syucomm.
  lv_exit_command = gv_okcode_0100.
  CLEAR gv_okcode_0100.
  CASE lv_exit_command.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      PERFORM free_controls.
      LEAVE TO SCREEN 0.
  ENDCASE.
ENDMODULE.

MODULE user_command_0100 INPUT.
  CLEAR gv_okcode_0100.
ENDMODULE.
