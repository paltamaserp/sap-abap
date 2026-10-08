*----------------------------------------------------------------------*
***INCLUDE ZPR_DCQM_EXCLUDE_I01 .
*----------------------------------------------------------------------*
* PAI modulok - Screen 0100
* A check_changed_data hívása és az e_valid vizsgálata a FORM-okban
* történik (USER_COMMAND_0100, EXIT_COMMAND_0100).
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.

  PERFORM user_command_0100.

ENDMODULE.                 " USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*&      Module  EXIT_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
MODULE exit_command_0100 INPUT.

  PERFORM exit_command_0100.

ENDMODULE.                 " EXIT_COMMAND_0100  INPUT
