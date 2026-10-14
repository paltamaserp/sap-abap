*&---------------------------------------------------------------------*
*& Report  ZBC_PRN_MESSAGEQUEUE_QUERY
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*
report  zbc_prn_messagequeue_query.

include zbc_pr_mq_logger.
include zbc_pr_messagequeue_classes.
include zbc_pr_get_slog_email.
include zbc_pr_init.
include zbc_pr_display.
include zbc_pr_messagequeue_main.
include zbc_pr_messagequeue_modules.

constants gc_tcode type sytcode value 'ZBC_PRN_MESSAGEQUEUE'.

initialization.
  authority-check object 'S_TCODE' id 'TCD' field gc_tcode.
  if sy-subrc is not initial.
    message s172(00) with sy-tcode.
    leave program.
  endif.

  set pf-status 'STATUS'.
  set titlebar 'QUEUE_TITLE'.

start-of-selection.
  lcl_main=>main( ).
  gr_log->flush( ).