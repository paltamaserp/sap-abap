MODULE dm_controls OUTPUT.
  CHECK gv_dm_ready = abap_true.
  IF go_dm_container IS INITIAL.
    CREATE OBJECT go_dm_container
      EXPORTING
        container_name              = 'ALV_CONTAINER_01'
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc <> 0.
      MESSAGE text-102 TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ENDIF.
  PERFORM cockpit_pbo IN PROGRAM zpr_dcqm_exclude
    USING go_dm_container.
ENDMODULE.
