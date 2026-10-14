*&---------------------------------------------------------------------*
*&  Include           ZBC_PR_INIT
*&---------------------------------------------------------------------*
initialization.
  data: lt_exbilldocnos type zebf_pr_string_tab.
  data: ls_exbilldocno  type line of zebf_pr_string_tab.
  data: lr_consumer     type ref to lcl_consumer.
  data: lr_slog_email   type ref to lcl_slog_email.
  data: lt_query_result type zebf_pr_eon_query_messenger_s1.
  data: lt_result_data  type zprt_slog_email.
  data: gv_okcode       type syucomm.
  data: gr_log          TYPE REF TO lcl_logger.

  gr_log = lcl_logger=>get_instance( ).