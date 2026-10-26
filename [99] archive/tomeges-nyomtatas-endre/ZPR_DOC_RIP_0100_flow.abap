* Screen 0100: normal screen, next screen 0100.
* Custom control: ALV_CONTAINER_01, resize vertically and horizontally.
* OK-code field (type OK): GV_OKCODE_0100.
* STAT_0100: BACK, EXIT, CANCEL, all function type E.
PROCESS BEFORE OUTPUT.
  MODULE status_0100.
  MODULE create_controls_0100.

PROCESS AFTER INPUT.
  MODULE exit_command_0100 AT EXIT-COMMAND.
  MODULE user_command_0100.
