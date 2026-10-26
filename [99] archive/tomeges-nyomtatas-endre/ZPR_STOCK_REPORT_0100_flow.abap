* Paste the executable statements below into SE51 screen 0100.
* Screen type: normal; next screen: 0100.
* OK-code field: GV_OKCODE_0100.
* Output-only header: GS_STOCK-STOCK_ID, GS_STOCK-STATUS,
* GV_TOTAL, GV_EXCLUDED, GV_ALLOWED, GV_BLOCK_REASON.
* Custom control: ALV_CONTAINER_01, below the header, resizable.
* SE41 status STAT_0100: BACK (F3), EXIT (Shift+F3), CANCEL (F12),
* all with function type E; REFRESH with normal function type.
* RELEASE is an ALV toolbar command, not a GUI status function.
* ALV application events are dispatched by USER_COMMAND_0100.
* SE41 titles TITLE_0100_MOD and TITLE_0100_DISP.

PROCESS BEFORE OUTPUT.
  MODULE status_0100.
  MODULE create_controls_0100.

PROCESS AFTER INPUT.
  MODULE exit_command_0100 AT EXIT-COMMAND.
  MODULE user_command_0100.
