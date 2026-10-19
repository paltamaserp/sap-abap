PROCESS BEFORE OUTPUT.
  MODULE status_100.
  MODULE update_header.
  MODULE screen_attributes.
  MODULE t_tabstrip_active_tab_set.

  CALL SUBSCREEN t_sub_sc
    INCLUDING sy-repid gs_tabstrip-subscreen.

PROCESS AFTER INPUT.
  MODULE cancel AT EXIT-COMMAND.
*  CALL SUBSCREEN t_sub_sc.
  MODULE user_command.