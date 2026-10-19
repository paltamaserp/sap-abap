FORM cockpit_pbo USING io_container TYPE REF TO cl_gui_custom_container.
  CHECK gv_embedded = abap_true.
  CHECK io_container IS BOUND.
  CHECK go_alv_grid_01 IS INITIAL.
* Reuse the container already created by the cockpit's subscreen PBO.
  go_alv_grid_cont_01 = io_container.
  PERFORM create_controls_0100.
ENDFORM.
