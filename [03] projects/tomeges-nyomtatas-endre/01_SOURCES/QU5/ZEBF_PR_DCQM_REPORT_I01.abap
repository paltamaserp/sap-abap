*----------------------------------------------------------------------*
***INCLUDE ZEBF_PR_DCQM_REPORT_I01 .
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.

  DATA lv_valid2.
  CALL METHOD go_alv_grid_01->check_changed_data
    IMPORTING
      e_valid = lv_valid2.

  PERFORM check_entered_data .

  PERFORM user_command_0100.

ENDMODULE.                 " USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*&      Module  EXIT_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE exit_command_0100 INPUT.

  DATA lv_valid.
  CALL METHOD go_alv_grid_01->check_changed_data
    IMPORTING
      e_valid = lv_valid.

  PERFORM exit_command_0100.

ENDMODULE.                 " EXIT_COMMAND_0100  INPUT