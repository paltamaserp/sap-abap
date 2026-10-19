* Temporary replacement for COCKPIT_PBO in ZPR_DCQM_EXCLUDE_C01.
* Query again on Enter after the screen has already been displayed.
FORM cockpit_pbo USING io_container TYPE REF TO cl_gui_custom_container.
  DATA: lv_ui_cc_visible   TYPE c LENGTH 1,
        lv_ui_grid_visible TYPE c LENGTH 1,
        lv_ui_rc_ccv       TYPE sysubrc,
        lv_ui_rc_gv        TYPE sysubrc,
        lv_ui_rc_vflush    TYPE sysubrc.

  CHECK gv_embedded = abap_true.
  CHECK io_container IS BOUND.
  IF go_alv_grid_01 IS INITIAL.
    go_alv_grid_cont_01 = io_container.
    PERFORM create_controls_0100.
  ENDIF.
  CHECK go_alv_grid_01 IS BOUND.

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

* Set the session breakpoint on the following CHECK, before leaving this FORM.
  CHECK lv_ui_rc_vflush = 0.
ENDFORM.
