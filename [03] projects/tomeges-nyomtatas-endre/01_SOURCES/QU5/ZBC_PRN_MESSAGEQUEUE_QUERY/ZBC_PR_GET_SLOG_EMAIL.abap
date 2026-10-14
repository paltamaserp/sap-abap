*&---------------------------------------------------------------------*
*&  Include           ZBC_PR_GET_SLOG_EMAIL
*&---------------------------------------------------------------------*

class lcl_slog_email definition final.
  public section.
    methods constructor importing io_logger type ref to lcl_logger optional
                        raising zcx_ebf_pr_main.
    methods get_exbilldocnos returning value(rt_slog_emails) type zebf_pr_string_tab.
    methods get_count returning value(rv_i) type i.
    methods prepare_data importing it_data type zebf_pr_eon_query_messenger_s1 raising zcx_ebf_pr_main.
    methods insert_data.
    methods get_result returning value(rt_slog_email) type zprt_slog_email.

  private section.
    constants lc_not_received type zebfd_send_status value 'N'.
    constants lc_not_received_message type char1000sf value 'Hét napon belül nem érkezett státusz a Messengertől.'.
    data lt_slog_emails type zprt_slog_email.
    data lr_log TYPE REF TO lcl_logger.

    methods: _lock_table importing iv_exbilldocno type zebfd_pr_exbilldocno raising zcx_ebf_pr_main,
             _unlock_table importing iv_exbilldocno type zebfd_pr_exbilldocno.
endclass.

class lcl_slog_email implementation.
  method constructor.
    lr_log = io_logger.

    select *
      into table me->lt_slog_emails
      from zpr_slog_email
      where sending_status = space.
    if sy-subrc <> 0.
      raise exception type zcx_ebf_pr_main.
    endif.
  endmethod.

  method get_count.
    describe table me->lt_slog_emails lines rv_i.
  endmethod.

  method get_exbilldocnos.
    data ls_slog_email type line of zprt_slog_email.
    data lv_exbilldocno type line of zebf_pr_string_tab.

    loop at me->lt_slog_emails into ls_slog_email.
      move ls_slog_email-exbilldocno to lv_exbilldocno.
      append lv_exbilldocno to rt_slog_emails.
    endloop.
  endmethod.

  method prepare_data.
    data ls_doc type zebf_pr_teon_query_messenger_2.
    field-symbols: <fs_slog_emails> type line of zprt_slog_email.
    data lv_seven_days type d.

    if it_data-parameters-success = space.
      lr_log->log( it_data-parameters-info ).
      if sy-batch eq abap_false.
        message it_data-parameters-info type 'E'.
      endif.
      raise exception type zcx_ebf_pr_main.
    endif.

    if it_data-parameters-docs-doc[] is initial.
      lr_log->log( 'Nem érkezett adat az Inspireből'(003) ).
      if sy-batch eq abap_false.
        message 'Nem érkezett adat az Inspireből'(003) type 'E'.   "#EC CI_USE_WANTED
      endif.
      raise exception type zcx_ebf_pr_main.
    endif.

    loop at it_data-parameters-docs-doc into ls_doc.
      read table me->lt_slog_emails assigning <fs_slog_emails> with key exbilldocno = ls_doc-exbilldocno.
      if sy-subrc <> 0.
        continue.
      endif.
      <fs_slog_emails>-sending_status = ls_doc-sending_status.
      <fs_slog_emails>-tstmp_sending_status = ls_doc-tstmp_sending_status.
      <fs_slog_emails>-error_message = ls_doc-error_message.
      <fs_slog_emails>-tstmp_email_sent = ls_doc-tstmp_email_sent.
    endloop.

    lv_seven_days = sy-datum - 8.

    loop at me->lt_slog_emails assigning <fs_slog_emails> where sending_status eq space.
      if <fs_slog_emails>-tstmp_print le lv_seven_days.
        <fs_slog_emails>-sending_status = me->lc_not_received.
        <fs_slog_emails>-error_message = lc_not_received_message.
      else.
        delete table me->lt_slog_emails from <fs_slog_emails>.
      endif.
    endloop.
  endmethod.

  method insert_data.
    field-symbols: <fs_slog_emails> type line of zprt_slog_email.
    loop at me->lt_slog_emails assigning <fs_slog_emails>.
      try.
          me->_lock_table( iv_exbilldocno = <fs_slog_emails>-exbilldocno ).
          modify zpr_slog_email from <fs_slog_emails>.
          me->_unlock_table( iv_exbilldocno = <fs_slog_emails>-exbilldocno ).
        catch zcx_ebf_pr_main.
          continue.
      endtry.
    endloop.
  endmethod.

  method _lock_table.
    call function 'ENQUEUE_EZPR_SLOG_EMAIL'
      exporting
        mode_zpr_slog_email = 'E'
        mandt               = sy-mandt
        exbilldocno         = iv_exbilldocno
      exceptions
        foreign_lock        = 1
        system_failure      = 2
        others              = 3.
    if sy-subrc <> 0.
      raise exception type zcx_ebf_pr_main.
    endif.
  endmethod.

  method _unlock_table.
    call function 'DEQUEUE_EZPR_SLOG_EMAIL'
      exporting
        mode_zpr_slog_email = 'E'
        mandt               = sy-mandt
        exbilldocno         = iv_exbilldocno.
  endmethod.

  method get_result.
    rt_slog_email[] = me->lt_slog_emails[].
  endmethod.
endclass.