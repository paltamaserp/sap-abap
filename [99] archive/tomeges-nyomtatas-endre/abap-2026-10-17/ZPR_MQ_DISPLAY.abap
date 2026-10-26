*&---------------------------------------------------------------------*
*& Include ZPR_MQ_DISPLAY
*& The displayed table is global and remains alive across PBO calls.
*&---------------------------------------------------------------------*
CLASS lcl_screen IMPLEMENTATION.
  METHOD show.
    DATA: lo_functions TYPE REF TO cl_salv_functions_list,
          lo_columns TYPE REF TO cl_salv_columns_table,
          lo_column TYPE REF TO cl_salv_column,
          lo_events TYPE REF TO cl_salv_events_table,
          lv_icon TYPE string,
          lv_error TYPE string,
          lx_error TYPE REF TO cx_root.
    IF gr_alv IS BOUND.
      RETURN.
    ENDIF.
    TRY.
        CREATE OBJECT gr_container
          EXPORTING container_name = 'CONTAINER'.
        cl_salv_table=>factory(
          EXPORTING r_container = gr_container
          IMPORTING r_salv_table = gr_alv
          CHANGING t_table = gt_result ).
        lo_functions = gr_alv->get_functions( ).
        lo_functions->set_all( abap_true ).
        lv_icon = icon_system_save.
        lo_functions->add_function(
          name = 'SAVE' icon = lv_icon text = 'Státuszok mentése'
          tooltip = 'A megjelenített státuszváltozások mentése'
          position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_columns = gr_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        lo_column = lo_columns->get_column( 'MANDT' ).
        lo_column->set_visible( abap_false ).
        lo_column = lo_columns->get_column( 'SAVE_STATE' ).
        lo_column->set_short_text( 'Mentés' ).
        lo_column->set_medium_text( 'Mentési állapot' ).
        lo_column->set_long_text( 'Mentési állapot (S/C/E)' ).
        lo_column = lo_columns->get_column( 'SAVE_TEXT' ).
        lo_column->set_short_text( 'Eredmény' ).
        lo_column->set_medium_text( 'Mentés eredménye' ).
        lo_column->set_long_text( 'Mentés eredménye' ).
        lo_events = gr_alv->get_event( ).
        SET HANDLER lcl_screen=>on_command FOR lo_events.
        gr_alv->display( ).
      CATCH cx_root INTO lx_error.
        lv_error = lx_error->get_text( ).
        PERFORM add_log USING lv_error.
        MESSAGE lv_error TYPE 'S' DISPLAY LIKE 'E'.
        LEAVE TO SCREEN 0.
    ENDTRY.
  ENDMETHOD.

  METHOD on_command.
    DATA: ls_result TYPE ty_result,
          lo_functions TYPE REF TO cl_salv_functions_list,
          lv_retry TYPE abap_bool,
          lx_error TYPE REF TO cx_root,
          lv_error TYPE string.
    IF e_salv_function <> 'SAVE'.
      RETURN.
    ENDIF.
    PERFORM save_result.
    gr_alv->refresh( ).
    lv_retry = abap_false.
    LOOP AT gt_result INTO ls_result.
      IF ls_result-save_state IS INITIAL OR ls_result-save_state = 'E'.
        lv_retry = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    TRY.
        lo_functions = gr_alv->get_functions( ).
        lo_functions->set_function( name = 'SAVE' boolean = lv_retry ).
      CATCH cx_salv_not_found INTO lx_error.
        lv_error = lx_error->get_text( ).
        PERFORM add_log USING lv_error.
      CATCH cx_salv_wrong_call INTO lx_error.
        lv_error = lx_error->get_text( ).
        PERFORM add_log USING lv_error.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.