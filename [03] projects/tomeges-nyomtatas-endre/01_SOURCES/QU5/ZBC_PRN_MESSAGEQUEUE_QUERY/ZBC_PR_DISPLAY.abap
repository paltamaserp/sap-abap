*&---------------------------------------------------------------------*
*&  Include           ZBC_PR_DISPLAY
*&---------------------------------------------------------------------*

include <icon>.

data: gr_container type ref to cl_gui_custom_container.
data: gr_table type ref to cl_salv_table.


class lcl_screen definition final.
  public section.
    class-methods: show            importing ir_slog_email type ref to lcl_slog_email.
    class-methods: set_log_object  importing ir_slog_email type ref to lcl_slog_email.
    class-methods: on_user_command for event added_function of cl_salv_events
                                   importing e_salv_function.

  private section.
    class-data: lr_slog_email      type ref to lcl_slog_email.
    class-data: update_func        type salv_de_function value 'UPDATEDB'.
    class-data: button_disabled type abap_bool value abap_false.

    class-methods: set_columns.
endclass.

class lcl_screen implementation.
  method on_user_command.
    data lo_functions type ref to cl_salv_functions_list.
    case e_salv_function.
      when update_func.
        if not lcl_screen=>lr_slog_email is bound.
          return.
        endif.
        if lcl_screen=>button_disabled eq abap_true.
          message 'A rekordok már beillesztésre kerültek.' type 'I'.   "#EC CI_USE_WANTED
          return.
        endif.
        lcl_screen=>lr_slog_email->insert_data( ).
        lcl_screen=>button_disabled = abap_true.
        lo_functions = gr_table->get_functions( ).
        TRY.
          lo_functions->set_function(
                    name    = update_func
                    boolean = abap_false ).
        CATCH cx_salv_not_found.
        CATCH cx_salv_wrong_call.
        ENDTRY.
        message 'Rekordok beillesztve a ZPR_SLOG_EMAIL táblába.' type 'I'.   "#EC CI_USE_WANTED
        call screen 100.
      when others.
    endcase.
  endmethod.

  method set_log_object.
    lr_slog_email = ir_slog_email.
  endmethod.

  method show.
    data: lx_error      type ref to cx_salv_msg.
    data: lr_functions  type ref to cl_salv_functions_list,
          lr_events     type ref to cl_salv_events_table.
    data: lr_columns    type ref to cl_salv_columns,
          lr_column     type ref to cl_salv_column_table.
    data  lv_icon       type string.
    data: lt_slog_email type zprt_slog_email.

    if gr_container is bound.
      return.
    endif.

    if cl_salv_table=>is_offline( ) eq if_salv_c_bool_sap=>false.
      create object gr_container
        exporting
          container_name = 'CONTAINER'.
    endif.

    lt_slog_email[] = ir_slog_email->get_result( ).
    try.
        cl_salv_table=>factory(
          exporting
            r_container    = gr_container
            container_name = 'CONTAINER'
          importing
            r_salv_table   = gr_table
          changing
            t_table        = lt_slog_email ).
        lr_functions = gr_table->get_functions( ).
        lr_functions->set_all( abap_true ).
        lv_icon = icon_budget_update.
        TRY.
          lr_functions->add_function(
                    name     = update_func
                    icon     = lv_icon
                    text     = 'Insert to System'
                    tooltip  = 'Insert the displayed data into the system'
                    position = if_salv_c_function_position=>right_of_salv_functions
                  ).
        CATCH cx_salv_wrong_call.
        CATCH cx_salv_existing.
        ENDTRY.
        lr_columns = gr_table->get_columns( ).
        lr_columns->set_optimize( abap_true ).
        lr_events = gr_table->get_event( ).
        set handler lcl_screen=>on_user_command for lr_events.
      catch cx_salv_msg into lx_error.
        data lv_text type char255.
        lv_text = lx_error->get_text( ).
        message lv_text type 'E'.
    endtry.
    lcl_screen=>set_columns( ).
    gr_table->display( ).
  endmethod.

  method set_columns.
    data: lr_columns type ref to cl_salv_columns,
          lr_column  type ref to cl_salv_column.

    lr_columns = gr_table->get_columns( ).
    lr_columns->set_optimize( abap_true ).

    try.
        lr_column = lr_columns->get_column( 'SENDING_STATUS' ).
        lr_column->set_short_text( 'Hiba' ).
        lr_column->set_medium_text( 'Hibakód' ).
        lr_column->set_long_text( 'Hibakód' ).
      catch cx_salv_not_found.
    endtry.

    try.
        lr_column = lr_columns->get_column( 'ERROR_MESSAGE' ).
        lr_column->set_short_text( 'Üzenet' ).
        lr_column->set_medium_text( 'Hibaüzenet' ).
        lr_column->set_long_text( 'Hibaüzenet' ).
      catch cx_salv_not_found.
    endtry.
  endmethod.
endclass.