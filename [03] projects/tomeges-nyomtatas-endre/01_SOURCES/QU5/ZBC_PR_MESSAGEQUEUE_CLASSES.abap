*&---------------------------------------------------------------------*
*&  Include           ZBC_PR_MESSAGEQUEUE_CLASSES
*&---------------------------------------------------------------------*
class lcl_consumer definition final.
  public section.
    methods: constructor importing it_exbilldocnos type zebf_pr_string_tab.
    methods: query exporting rs_result type zebf_pr_eon_query_messenger_s1.

  private section.
    constants lv_logical_port_name type prx_logical_port_name value 'LOGPORT'.
    data lr_consumer type ref to zebf_pr_co_eon_query_messenger.
    data ls_input type zebf_pr_eon_query_messenger_s2.
    data lt_exbilldocno type zebf_pr_string_tab.
endclass.

class lcl_consumer implementation.
  method constructor.
    try.
        create object me->lr_consumer
          exporting
            logical_port_name = me->lv_logical_port_name.
        me->ls_input-sap_system = sy-sysid.
        me->ls_input-sap_mandant = sy-mandt.
        ls_input-exbilldocnos-exbilldocno[] = it_exbilldocnos[].
      catch cx_ai_system_fault.
        message 'Hiba az Inspire kommunikációban!'(002) type 'E'.  "#EC CI_USE_WANTED
    endtry.
  endmethod.

  method query.
    if lr_consumer is not bound.
      return.
    endif.
    try.
        me->lr_consumer->eon_query_messenger_status(
          exporting input = me->ls_input
            importing output = rs_result ).
      catch cx_ai_system_fault.
        message 'Hiba az Inspire kommunikációban!'(002) type 'E'.  "#EC CI_USE_WANTED
    endtry.
  endmethod.
endclass.