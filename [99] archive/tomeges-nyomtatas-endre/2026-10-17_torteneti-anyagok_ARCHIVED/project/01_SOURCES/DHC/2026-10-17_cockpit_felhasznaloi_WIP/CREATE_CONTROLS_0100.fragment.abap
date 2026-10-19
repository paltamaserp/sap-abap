 .

  DATA:
    ls_layout   TYPE lvc_s_layo,
    ls_variant  TYPE disvariant,
    lt_fieldcat TYPE lvc_t_fcat,
    lv_stokid   TYPE char10.

* Csak ha még nem létezik a konténer és az ALV Grid objektum
  CHECK go_alv_grid_cont_01 IS INITIAL.
  CHECK go_alv_grid_01      IS INITIAL.

* Custom container control létrehozás
   IF go_alv_grid_cont_01 IS INITIAL.
    CREATE OBJECT go_alv_grid_cont_01
      EXPORTING
        container_name              = 'ALV_CONTAINER_01'
        repid                       = gv_host_repid
        dynnr                       = gv_host_dynnr
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5.
    IF NOT sy-subrc IS INITIAL.
      EXIT.
    ENDIF.
  ENDIF.

DATA lv_ui_offline TYPE int4.

  CALL METHOD cl_gui_alv_grid=>offline
    RECEIVING
      e_offline = lv_ui_offline.

* ALV Grid control létrehozás
  CREATE OBJECT go_alv_grid_01
    EXPORTING
      i_parent          = go_alv_grid_cont_01
      i_appl_events     = space
    EXCEPTIONS
      error_cntl_create = 1
      error_cntl_init   = 2
      error_cntl_link   = 3
      error_dp_create   = 4.
  IF NOT sy-subrc IS INITIAL.
    EXIT.
  ENDIF.

* ALV Grid cellák módosíthatósága
  IF gv_modif EQ abap_true.
    PERFORM cell_style_alv_outtab_0100.
  ENDIF.

* ALV Grid layout beállítás
  CLEAR ls_layout.
  ls_layout-zebra      = abap_true.
  ls_layout-cwidth_opt = abap_true.
  lv_stokid = p_stokid.
  SHIFT lv_stokid LEFT DELETING LEADING '0'.
  IF gv_modif EQ abap_true.
    CONCATENATE lv_stokid 'stock feldolgozása'(t01)
           INTO ls_layout-grid_title SEPARATED BY space.
  ELSE.
    CONCATENATE lv_stokid 'stock megjelenítése'(t02)
           INTO ls_layout-grid_title SEPARATED BY space.
  ENDIF.
  ls_layout-sel_mode   = 'A'.
  ls_layout-smalltitle = abap_true.
  ls_layout-stylefname = 'HANDLE_STYLE'.

* Mezőkatalógus generálás
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = 'ZPRS_DCQM_REPORT'
    CHANGING
      ct_fieldcat            = lt_fieldcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2.
  IF NOT sy-subrc IS INITIAL.
    REFRESH lt_fieldcat.
  ENDIF.

* Mezőkatalógus módosítás
  PERFORM alv_fieldcat_0100_mod CHANGING lt_fieldcat.

* Esemény kezelő regisztrálás
  SET HANDLER
    gcl_alv_grid_01_event_receiver=>on_alv_user_command
    gcl_alv_grid_01_event_receiver=>on_alv_toolbar
    gcl_alv_grid_01_event_receiver=>handle_data_changed
    gcl_alv_grid_01_event_receiver=>handle_data_changed_finished
    FOR go_alv_grid_01.

  IF gv_modif EQ abap_true.
    CALL METHOD go_alv_grid_01->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.

    CALL METHOD go_alv_grid_01->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_modified
      EXCEPTIONS
        error      = 1
        OTHERS     = 2.
    IF NOT sy-subrc IS INITIAL.
      EXIT.
    ENDIF.
  ENDIF.

  CLEAR ls_variant.
  ls_variant-report   = sy-repid.
  ls_variant-username = sy-uname.
  ls_variant-variant  = p_vari.

* ALV Grid megjelenítés
  CALL METHOD go_alv_grid_01->set_table_for_first_display
    EXPORTING
      is_variant                    = ls_variant
      i_save                        = 'A'
      i_default                     = abap_true
      is_layout                     = ls_layout
    CHANGING
      it_outtab                     = gt_0100_alv
      it_fieldcatalog               = lt_fieldcat
    EXCEPTIONS
      invalid_parameter_combination = 1
      program_error                 = 2
      too_many_lines                = 3.
  IF NOT sy-subrc IS INITIAL.
    EXIT.
  ENDIF.

* Toolbar esemény kiváltás, hogy a gombok megjelenjenek a toolbaron
  CALL METHOD go_alv_grid_01->set_toolbar_interactive.


  DATA: lv_ui_alignment TYPE i,
        lv_ui_rc_align  TYPE sysubrc.

  lv_ui_alignment = go_alv_grid_01->align_at_left
                  + go_alv_grid_01->align_at_right
                  + go_alv_grid_01->align_at_top
                  + go_alv_grid_01->align_at_bottom.

  CALL METHOD go_alv_grid_01->set_alignment
    EXPORTING
      alignment         = lv_ui_alignment
    EXCEPTIONS
      cntl_error        = 1
      cntl_system_error = 2
      OTHERS            = 3.
  lv_ui_rc_align = sy-subrc.

  DATA: lv_ui_cc_width   TYPE i,
        lv_ui_cc_height  TYPE i,
        lv_ui_grid_width TYPE i,
        lv_ui_grid_height TYPE i,
        lv_ui_rc_ccw     TYPE sysubrc,
        lv_ui_rc_cch     TYPE sysubrc,
        lv_ui_rc_gw      TYPE sysubrc,
        lv_ui_rc_gh      TYPE sysubrc,
        lv_ui_rc_flush   TYPE sysubrc.

  CALL METHOD go_alv_grid_cont_01->get_width
    IMPORTING width = lv_ui_cc_width
    EXCEPTIONS cntl_error = 1 OTHERS = 2.
  lv_ui_rc_ccw = sy-subrc.

  CALL METHOD go_alv_grid_cont_01->get_height
    IMPORTING height = lv_ui_cc_height
    EXCEPTIONS cntl_error = 1 OTHERS = 2.
  lv_ui_rc_cch = sy-subrc.

  CALL METHOD go_alv_grid_01->get_width
    IMPORTING width = lv_ui_grid_width
    EXCEPTIONS cntl_error = 1 OTHERS = 2.
  lv_ui_rc_gw = sy-subrc.

  CALL METHOD go_alv_grid_01->get_height
    IMPORTING height = lv_ui_grid_height
    EXCEPTIONS cntl_error = 1 OTHERS = 2.
  lv_ui_rc_gh = sy-subrc.

  CALL METHOD cl_gui_cfw=>flush
    EXCEPTIONS
      cntl_system_error = 1
      cntl_error        = 2
      OTHERS            = 3.
  lv_ui_rc_flush = sy-subrc.

ENDFORM.                    " CREATE_CONTROLS_0100