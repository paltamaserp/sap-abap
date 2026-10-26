*----------------------------------------------------------------------*
* ZPR_DCQM_EXCLUDE - Screen 0100 flow logic (SE51)
*----------------------------------------------------------------------*
* Képernyőtípus: normál
* Elemlista:
*   - SE51 -> Elemlista: az OK típusú elem neve GV_OKCODE_0100.
*     Ez a képernyő technikai OK-mezője; nem látható beviteli mező.
*     A névnek egyeznie kell a program globális változójával.
*     A képernyőt a hozzárendelés után aktiválni kell.
*   - Custom control: ALV_CONTAINER_01 (teljes képernyő, átméretezhető
*     függőlegesen és vízszintesen, min. 10 x 10)
* GUI-státuszok (SE41):
*   - STAT_0100      : SAVE (Ctrl+S), BACK (F3), EXIT (Shift+F3), CANCEL (F12)
*   - STAT_0100_DISP : BACK, EXIT, CANCEL
*   A BACK, EXIT, CANCEL funkciótípusa "E" (Exit command) legyen!
* Címsorok:
*   - TITLE_0100_MOD  : Nyomtatási sorok kizárása
*   - TITLE_0100_DISP : Nyomtatási sorok megjelenítése
*----------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
  MODULE status_0100.
  MODULE create_controls_0100.

PROCESS AFTER INPUT.
  MODULE exit_command_0100 AT EXIT-COMMAND.
  MODULE user_command_0100.
