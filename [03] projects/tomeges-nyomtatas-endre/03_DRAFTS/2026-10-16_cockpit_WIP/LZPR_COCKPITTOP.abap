FUNCTION-POOL zpr_cockpit                 MESSAGE-ID zpr.

* INCLUDE LZPR_COCKPITD...                   " Local class definition

*definitions for tabstrip
CONSTANTS: BEGIN OF c_tabstrip,
             t_dm_item    LIKE sy-ucomm VALUE  'T_DM_ITEM',
             t_dm_approve LIKE sy-ucomm VALUE  'T_DM_APPROVE',
             t_qm_check   LIKE sy-ucomm VALUE  'T_QM_CHECK',
             t_qm_approve LIKE sy-ucomm VALUE  'T_QM_APPROVE',
             t_close      LIKE sy-ucomm VALUE  'T_CLOSE',
           END OF c_tabstrip.

CONTROLS:  t_tabstrip TYPE TABSTRIP.
DATA: BEGIN OF gs_tabstrip,
        subscreen   LIKE sy-dynnr,
        prog        LIKE sy-repid,
        pressed_tab LIKE sy-ucomm VALUE c_tabstrip-t_dm_item,
      END OF gs_tabstrip.

*ok code.
DATA: save_ok TYPE sy-ucomm,
      ok_code TYPE sy-ucomm.

TABLES: zprs_cockpit.

DATA gx_error    TYPE REF TO zcx_form_message_error.        "Hibakezelés
DATA gv_dummy_message.
DATA gv_edit_mode.

"Nyomógombok
CONSTANTS: BEGIN OF c_buttons,
             dm_close  LIKE sy-ucomm VALUE  'DM_CLOSE',
             dm_reopen LIKE sy-ucomm VALUE  'DM_REOPEN',
             qm_close  LIKE sy-ucomm VALUE  'QM_CLOSE',
             qm_reopen LIKE sy-ucomm VALUE  'QM_REOPEN',
             close     LIKE sy-ucomm VALUE  'CLOSE',
             reopen    LIKE sy-ucomm VALUE  'REOPEN',
           END OF c_buttons.
* Accepted context; the screen field may contain an unvalidated candidate.
DATA: gv_stock_id TYPE zprd_stock_id,
      gv_dm_ready TYPE abap_bool.

* Internal processing results are independent of user function codes.
DATA: gv_stock_changed      TYPE abap_bool,
      gv_dm_close_cancelled TYPE abap_bool.

* Create the screen container in its own function group's PBO.
DATA go_dm_container TYPE REF TO cl_gui_custom_container.

* QM selection-screen state; no business work is started when the tab opens.
DATA: gv_qm_ready TYPE abap_bool,
      gv_qm_command_handled TYPE abap_bool.
