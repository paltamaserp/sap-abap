*&---------------------------------------------------------------------*
*&  Include           ZBC_PR_MESSAGEQUEUE_MAIN
*&---------------------------------------------------------------------*

class lcl_main definition final.
  public section.
    class-methods: main.
endclass.

class lcl_main implementation.
  method main.
    data lv_log type string.
    data lv_i type i.

    gr_log->log( 'Feldolgozás megkezdve' ).
    try.
        create object lr_slog_email
          exporting
            io_logger = gr_log.
      catch zcx_ebf_pr_main.
        gr_log->log( 'Nem található dokumentum a ZPR_SLOG_EMAIL táblában státusz nélkül!' ).
        if sy-batch eq abap_false.
          message 'Nem található dokumentum a ZPR_SLOG_EMAIL táblában státusz nélkül!'(001) type 'E'.  "#EC CI_USE_WANTED
        endif.
        return.
    endtry.

    lt_exbilldocnos = lr_slog_email->get_exbilldocnos( ).
    create object lr_consumer
      exporting
        it_exbilldocnos = lt_exbilldocnos.
    lv_log = lr_slog_email->get_count( ).
    CONCATENATE lv_log 'darab dokumentumot találtam a ZPR_SLOG_EMAIL táblában.' INTO lv_log SEPARATED BY space.
    gr_log->log( lv_log ).
    lr_consumer->query( importing rs_result = lt_query_result ).
    describe table lt_query_result-parameters-docs-doc[] lines lv_i.
    lv_log = lv_i.
    CONCATENATE 'Inspire lekérdezés befejezve,' lv_log 'dokumentumot találtam.' into lv_log SEPARATED BY space.
    gr_log->log( lv_log ).

    try.
        lr_slog_email->prepare_data( exporting it_data = lt_query_result ).
        if sy-batch ne space.
          lr_slog_email->insert_data( ).
          gr_log->log( 'Dokumetumok beillesztve' ).
        else.
          lcl_screen=>set_log_object( lr_slog_email ).
          call screen 100.
        endif.
      catch zcx_ebf_pr_main.
        gr_log->log( 'Hiba törtét az adatok beillesztésekor a ZPR_SLOG_EMAIL táblába.' ).
    endtry.

    gr_log->log( 'Feldolgozás befejezve' ).
  endmethod.
endclass.