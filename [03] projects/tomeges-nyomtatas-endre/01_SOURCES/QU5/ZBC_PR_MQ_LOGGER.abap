*&---------------------------------------------------------------------*
*&  Include           ZBC_PR_MQ_LOGGER
*&---------------------------------------------------------------------*

class lcl_logger definition final create private.
  public section.
    class-methods get_instance returning value(ro_instance) type ref to lcl_logger.

    methods: log importing       iv_p1     type any,
             flush.

  private section.
    class-data gr_instance type ref to lcl_logger.
    data       lt_mess     type stringtab.

    methods: constructor,
             _fill_date returning value(rv_dates) type string.
endclass.

class lcl_logger implementation.
  method constructor.
  endmethod.

  method get_instance.
    if lcl_logger=>gr_instance is not bound.
      create object gr_instance.
    endif.
    ro_instance = lcl_logger=>gr_instance.
  endmethod.

  method _fill_date.
    data: lv_date type datum,
          lv_time type string.

    lv_date = sy-datum.
    lv_time = sy-uzeit.
    concatenate lv_date+0(4)
                lv_date+4(2)
                lv_date+6(2)
                into rv_dates separated by '.'." '.'
    concatenate lv_time+0(2)
                lv_time+2(2)
                lv_time+4(2)
                into lv_time separated by ':'." ':'
    concatenate rv_dates
                lv_time
                into rv_dates separated by space.
  endmethod.

  method log.
    data lv_str type string.
    data lv_date type string.

    lv_date = _fill_date( ).
    CONCATENATE lv_date iv_p1 INTO lv_str SEPARATED BY ' - '.
    append lv_str to me->lt_mess.
  endmethod.

  method flush.
    data lv_str type string.
    IF sy-batch eq space.
      return.
    ENDIF.

    loop at me->lt_mess into lv_str.
      write: / lv_str.
    endloop.
  endmethod.
endclass.