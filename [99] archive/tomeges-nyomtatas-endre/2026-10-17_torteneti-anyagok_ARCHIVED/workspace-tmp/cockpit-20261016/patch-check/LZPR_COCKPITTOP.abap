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
        prog        LIKE sy-repid VALUE 'ZPR_COCKPIT',
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