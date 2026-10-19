* Temporary COCKPIT_PBO trial: explicitly show both controls, then query them.
FORM cockpit_pbo USING io_container TYPE REF TO cl_gui_custom_container.
  DATA: lv_ui_cc_visible   TYPE c LENGTH 1,
        lv_ui_grid_visible TYPE c LENGTH 1,
        lv_ui_rc_ccv       TYPE sysubrc,
        lv_ui_rc_gv        TYPE sysubrc,
        lv_ui_rc_vflush    TYPE sysubrc,
        lv_ui_rc_show_cc   TYPE sysubrc,
        lv_ui_rc_show_grid TYPE sysubrc.

  CHECK gv_embedded = abap_true.
  CHECK io_container IS BOUND.
  IF go_alv_grid_01 IS INITIAL.
    go_alv_grid_cont_01 = io_container.
    PERFORM create_controls_0100.
  ENDIF.
  CHECK go_alv_grid_01 IS BOUND.

  CALL METHOD io_container->set_visible
    EXPORTING
      visible           = cl_gui_control=>visible_true
    EXCEPTIONS
      cntl_error        = 1
      cntl_system_error = 2
      OTHERS            = 3.
  lv_ui_rc_show_cc = sy-subrc.

  CALL METHOD go_alv_grid_01->set_visible
    EXPORTING
      visible           = cl_gui_control=>visible_true
    EXCEPTIONS
      cntl_error        = 1
      cntl_system_error = 2
      OTHERS            = 3.
  lv_ui_rc_show_grid = sy-subrc.

  CALL METHOD io_container->get_visible
    IMPORTING
      visible           = lv_ui_cc_visible
    EXCEPTIONS
      cntl_error        = 1
      cntl_system_error = 2
      OTHERS            = 3.
  lv_ui_rc_ccv = sy-subrc.

  CALL METHOD go_alv_grid_01->get_visible
    IMPORTING
      visible           = lv_ui_grid_visible
    EXCEPTIONS
      cntl_error        = 1
      cntl_system_error = 2
      OTHERS            = 3.
  lv_ui_rc_gv = sy-subrc.

  CALL METHOD cl_gui_cfw=>flush
    EXCEPTIONS
      cntl_system_error = 1
      cntl_error        = 2
      OTHERS            = 3.
  lv_ui_rc_vflush = sy-subrc.

* Breakpoint before this CHECK; inspect replies while local variables exist.
  CHECK lv_ui_rc_vflush = 0.
ENDFORM.
