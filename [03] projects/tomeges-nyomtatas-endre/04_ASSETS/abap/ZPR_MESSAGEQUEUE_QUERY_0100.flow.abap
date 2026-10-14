* Screen 0100: normal screen, next screen 0.
* Custom control: ALV_CONTAINER_01.
* OK-code field: GV_OKCODE_0100.
* GUI status STATUS_0100: BACK / EXIT / CANC, function type E.
PROCESS BEFORE OUTPUT.
  MODULE status_0100.

PROCESS AFTER INPUT.
  MODULE exit_0100 AT EXIT-COMMAND.
  MODULE command_0100.
