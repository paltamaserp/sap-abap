REPORT zpr_close_stock MESSAGE-ID zpr.

*********************************************************************
* Report: ZPR_CLOSE_STOCK
* Leírás: STOCK Engedélyezés / Lezárás
* Final stock release and Inspire notification
*--------------------------------------------------------------------
* Modulfelelos: <XY>
* Tanácsadó:
* Programozó:   Pál Tamás
* Dátum, kérelem: 2026.10.13
* --------------------------------------------------------------------
* Módosítások:
* <dátum>, <programozó>, <kérelem>, <comment azonosító>
*          <rövid leírás>
**********************************************************************
* 13.10.2026 11:42:02    X0134  Létrehozás
* 26.10.2026             X0086  ECH-21281: átszerkesztés osztályokra
*--------------------------------------------------------------------*

TYPE-POOLS icon.

TYPES tt_alv TYPE STANDARD TABLE OF zprs_dcqm_report.

TYPES: BEGIN OF ts_stock_f4,
         stock_id TYPE zprt_stock-stock_id,
         status   TYPE zprt_stock-status,
         closed   TYPE zprt_stock-closed,
         dccompl  TYPE zprt_stock-dccompl,
         qmcompl  TYPE zprt_stock-qmcompl,
         priority TYPE zprt_stock-priority,
       END OF ts_stock_f4.

CLASS lcl_view DEFINITION DEFERRED.

* A stock állapota és az üzleti döntések (olvasás, mód, zár, lezárás, napló).
* Az ALV-ről nem tud; a megjelenítést az lcl_view végzi, a védett tagokat
* barát osztályként éri el.
CLASS lcl_stock DEFINITION FRIENDS lcl_view.
  PUBLIC SECTION.
    CLASS-METHODS exists
      IMPORTING iv_stock_id      TYPE zprd_stock_id
      RETURNING VALUE(rv_exists) TYPE abap_bool.
    METHODS constructor
      IMPORTING iv_stock_id TYPE zprd_stock_id.
    METHODS check_authority
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS open
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS unlock.

  PROTECTED SECTION.
    CONSTANTS gc_log_object TYPE balobj_d VALUE 'ZPR_MASS'.
    CONSTANTS gc_log_subobject TYPE balsubobj VALUE 'STOCK'.
    CONSTANTS gc_status_closed TYPE zprd_stock_status VALUE 'CL'.
    CONSTANTS gc_status_qm TYPE zprd_stock_status VALUE 'QM'.
    CONSTANTS gc_tcode TYPE tcode VALUE 'ZPR_CLOSE_STOCK'.

    DATA mv_block_msgno TYPE symsgno.
    DATA mv_busy TYPE abap_bool.
    DATA mv_excluded TYPE i.
    DATA mv_header_valid TYPE abap_bool.
    DATA mv_locked TYPE zprd_stock_id.
    DATA mv_log_failed TYPE abap_bool.
    DATA mv_modif TYPE abap_bool VALUE abap_true.
    DATA mv_saved TYPE abap_bool.
    DATA mv_stock_id TYPE zprd_stock_id.
    DATA mv_total TYPE i.
    DATA mv_uncertain TYPE abap_bool.
    DATA ms_stock TYPE zprt_stock.
    DATA mt_alv TYPE tt_alv.
    DATA mo_log TYPE REF TO zcl_pr_log.

    CLASS-METHODS number_text
      IMPORTING iv_count       TYPE i
      RETURNING VALUE(rv_text) TYPE string.
    METHODS read_stock
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS determine_mode.
    METHODS sync_lock
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS lock.
    METHODS select_data
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS release
      RETURNING VALUE(rv_done) TYPE abap_bool.
    METHODS release_execute
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS show_release_result.
    METHODS reload
      RETURNING VALUE(rv_done) TYPE abap_bool.
    METHODS mark_uncertain.
    METHODS get_log
      RETURNING VALUE(rr_log) TYPE REF TO zcl_pr_log.
    METHODS log_sy.
    METHODS log_event
      IMPORTING iv_type TYPE symsgty
                iv_text TYPE clike.
    METHODS log_stock_totals.
    METHODS write_log.
ENDCLASS.

* Az ALV-rács, a fejléc és a képernyő-események kezelése. Az állapotot
* és a döntéseket az lcl_stock példánytól kéri.
CLASS lcl_view DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS f4_stock
      CHANGING cv_stock TYPE zprd_stock_id.
    METHODS constructor
      IMPORTING ir_stock   TYPE REF TO lcl_stock
                iv_variant TYPE slis_vari.
    METHODS create_controls.
    METHODS is_modifiable
      RETURNING VALUE(rv_modif) TYPE abap_bool.
    METHODS user_command
      CHANGING cv_okcode TYPE syucomm.
    METHODS exit_command
      CHANGING cv_okcode TYPE syucomm.
    METHODS free_controls.

  PROTECTED SECTION.
    DATA mv_variant TYPE slis_vari.
    DATA mo_container TYPE REF TO cl_gui_custom_container.
    DATA mo_grid TYPE REF TO cl_gui_alv_grid.
    DATA mo_header TYPE REF TO cl_dd_document.
    DATA mo_header_container TYPE REF TO cl_gui_docking_container.
    DATA mo_stock TYPE REF TO lcl_stock.

    METHODS get_fieldcatalog
      RETURNING VALUE(rt_fcat) TYPE lvc_t_fcat.
    METHODS get_excluded_functions
      RETURNING VALUE(rt_exclude) TYPE ui_functions.
    METHODS build_header.
    METHODS refresh_grid.
    METHODS reload_display.
    METHODS exit_screen.
    METHODS on_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.
    METHODS on_user_command FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
ENDCLASS.

DATA gv_okcode_0100 TYPE syucomm.
DATA go_stock TYPE REF TO lcl_stock.
DATA go_view TYPE REF TO lcl_view.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
  PARAMETERS p_stokid TYPE zprd_stock_id OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b01.
SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-002.
  PARAMETERS p_vari TYPE slis_vari.
SELECTION-SCREEN END OF BLOCK b02.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_stokid.
  lcl_view=>f4_stock( CHANGING cv_stock = p_stokid ).

AT SELECTION-SCREEN.
  IF lcl_stock=>exists( p_stokid ) EQ abap_false.
    MESSAGE e149(zpr) WITH p_stokid.
  ENDIF.

START-OF-SELECTION.
  IF sy-batch EQ abap_true.
    MESSAGE s150(zpr) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  go_stock = NEW lcl_stock( p_stokid ).
  IF go_stock->check_authority( ) EQ abap_false.
    RETURN.
  ENDIF.
  IF go_stock->open( ) EQ abap_false.
    RETURN.
  ENDIF.
  go_view = NEW lcl_view( ir_stock   = go_stock
                          iv_variant = p_vari ).

  CALL SCREEN 0100.

  go_stock->unlock( ).
  go_view->free_controls( ).

  INCLUDE zpr_stock_report_o01.
  INCLUDE zpr_stock_report_i01.

CLASS lcl_stock IMPLEMENTATION.
  METHOD exists.
    DATA lv_stock_id TYPE zprt_stock-stock_id.

    SELECT SINGLE stock_id FROM zprt_stock INTO lv_stock_id
      WHERE stock_id EQ iv_stock_id.
    IF sy-subrc EQ 0.
      rv_exists = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD constructor.
    mv_stock_id = iv_stock_id.
  ENDMETHOD.

  METHOD check_authority.
    AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
    IF sy-subrc NE 0.
      MESSAGE s205(zpr) WITH gc_tcode DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    rv_ok = abap_true.
  ENDMETHOD.

  METHOD open.
    " A riport indulása: olvasás, mód, zár, adat; hibánál a zár feloldva, a napló kiírva.
    IF read_stock( ) EQ abap_false.
      MESSAGE s151(zpr) WITH mv_stock_id DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    determine_mode( ).
    IF sync_lock( ) EQ abap_false.
      unlock( ).
      write_log( ).
      RETURN.
    ENDIF.
    IF select_data( ) EQ abap_false.
      unlock( ).
      write_log( ).
      RETURN.
    ENDIF.

    IF ms_stock-closed IS NOT INITIAL
       OR ms_stock-status EQ gc_status_closed.
      MESSAGE 'A stock engedélyezve van, csak megtekintés lehetséges.'(108) TYPE 'I'.
    ELSEIF ms_stock-status NE gc_status_qm.
      MESSAGE 'Csak QM státuszú stock zárható le. Csak megtekintés lehetséges.'(110) TYPE 'I'.
    ENDIF.
    rv_ok = abap_true.
  ENDMETHOD.

  METHOD unlock.
    IF mv_locked IS INITIAL.
      RETURN.
    ENDIF.
    CALL FUNCTION 'DEQUEUE_EZPRT_STOCK'
      EXPORTING
        stock_id = mv_locked
        _scope   = '1'.
    CLEAR mv_locked.
  ENDMETHOD.

  METHOD number_text.
    " A számot balra igazítva írja ki, a felhasználó számformátuma szerint.
    DATA lv_number TYPE c LENGTH 20.

    WRITE iv_count TO lv_number LEFT-JUSTIFIED.
    rv_text = lv_number.
  ENDMETHOD.

  METHOD read_stock.
    DATA lo_error TYPE REF TO cx_root.

    CLEAR ms_stock.
    TRY.
        SELECT SINGLE * FROM zprt_stock BYPASSING BUFFER INTO ms_stock
          WHERE stock_id EQ mv_stock_id.
        IF sy-subrc EQ 0.
          rv_ok = abap_true.
        ENDIF.
      CATCH cx_root INTO lo_error.
        get_log( )->add_exception( ir_cx = lo_error ).
    ENDTRY.
    IF rv_ok EQ abap_false.
      CLEAR mv_header_valid.
    ENDIF.
  ENDMETHOD.

  METHOD determine_mode.
    mv_modif = abap_false.
    CLEAR mv_block_msgno.
    IF ms_stock-closed IS NOT INITIAL
       OR ms_stock-status EQ gc_status_closed.
      mv_block_msgno = 152.
    ELSEIF ms_stock-stock_status_er IS NOT INITIAL
           OR mv_uncertain EQ abap_true.
      mv_block_msgno = 153.
    ELSEIF ms_stock-status NE gc_status_qm.
      mv_block_msgno = 154.
    ELSE.
      mv_modif = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD sync_lock.
    DATA lv_dummy TYPE string.

    rv_ok = abap_true.
    IF mv_modif NE abap_true.
      unlock( ).
      RETURN.
    ENDIF.
    IF mv_locked EQ mv_stock_id.
      RETURN.
    ENDIF.
    lock( ).
    IF mv_locked NE mv_stock_id.
      mv_modif = abap_false.
      RETURN.
    ENDIF.
    " A zárolás után újraolvassuk a stockot.
    IF read_stock( ) EQ abap_false.
      rv_ok = abap_false.
      mv_modif = abap_false.
      mv_block_msgno = 151.
      MESSAGE e151(zpr) WITH mv_stock_id INTO lv_dummy.
      log_sy( ).
    ELSE.
      determine_mode( ).
    ENDIF.
    IF mv_modif NE abap_true.
      unlock( ).
    ENDIF.
  ENDMETHOD.

  METHOD lock.
    IF mv_locked EQ mv_stock_id.
      RETURN.
    ENDIF.
    unlock( ).
    CALL FUNCTION 'ENQUEUE_EZPRT_STOCK'
      EXPORTING
        stock_id       = mv_stock_id
        _scope         = '1'
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc NE 0.
      mv_block_msgno = 156.
      MESSAGE i156(zpr) WITH mv_stock_id DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    mv_locked = mv_stock_id.
  ENDMETHOD.

  METHOD select_data.
    DATA ls_text TYPE zprt_dcqmlt.
    DATA lt_texts TYPE STANDARD TABLE OF zprt_dcqmlt.
    DATA lo_error TYPE REF TO cx_root.
    FIELD-SYMBOLS <ls_alv> TYPE zprs_dcqm_report.

    CLEAR mv_total.
    CLEAR mv_excluded.
    CLEAR mv_header_valid.
    REFRESH mt_alv.
    TRY.
        SELECT COUNT(*) FROM zprt_dcqm INTO mv_total
          WHERE prd_stock_id EQ mv_stock_id.
        SELECT * FROM zprt_dcqm
          INTO CORRESPONDING FIELDS OF TABLE mt_alv
          WHERE prd_stock_id EQ mv_stock_id
            AND ( block_dc NE space OR block_qm NE space ).
        IF mt_alv IS NOT INITIAL.
          SELECT * FROM zprt_dcqmlt INTO TABLE lt_texts
            FOR ALL ENTRIES IN mt_alv
            WHERE exbilldocno EQ mt_alv-doc_no.
        ENDIF.
      CATCH cx_root INTO lo_error.
        get_log( )->add_exception( ir_cx = lo_error ).
        RETURN.
    ENDTRY.
    SORT mt_alv BY doc_no envelope.
    SORT lt_texts BY exbilldocno.
    LOOP AT mt_alv ASSIGNING <ls_alv>.
      CLEAR ls_text.
      READ TABLE lt_texts INTO ls_text
        WITH KEY exbilldocno = <ls_alv>-doc_no BINARY SEARCH.
      IF sy-subrc EQ 0.
        <ls_alv>-block_dc_text = ls_text-block_dc_text.
        <ls_alv>-block_qm_text = ls_text-block_qm_text.
      ENDIF.
      <ls_alv>-counter = 1.
      CLEAR <ls_alv>-changed.
      CLEAR <ls_alv>-handle_style.
    ENDLOOP.
    DESCRIBE TABLE mt_alv LINES mv_excluded.
    rv_ok = abap_true.
    mv_header_valid = abap_true.
  ENDMETHOD.

  METHOD release.
    " A RELEASE gomb: feltételek, lezárás, napló, majd a stock újraolvasása.
    DATA lv_dummy TYPE string.

    IF mv_busy EQ abap_true.
      RETURN.
    ENDIF.
    FREE mo_log.
    CLEAR mv_saved.
    IF check_authority( ) EQ abap_false.
      RETURN.
    ENDIF.
    IF mv_modif NE abap_true OR mv_uncertain EQ abap_true.
      MESSAGE ID 'ZPR' TYPE 'S' NUMBER mv_block_msgno
        WITH mv_stock_id DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    IF mv_locked NE mv_stock_id.
      MESSAGE s155(zpr) WITH mv_stock_id DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    mv_busy = abap_true.
    log_event( iv_type = 'I'
               iv_text = 'Stock lezárási folyamat indul:'(310) ).
    " A lezárás hibánál idő előtt visszatér; az alábbi lezáró rész ezért mindig lefut.
    release_execute( ).

    IF mv_uncertain EQ abap_true.
      mark_uncertain( ).
    ENDIF.
    mv_busy = abap_false.
    IF mv_saved NE abap_true.
      MESSAGE e161(zpr) WITH mv_stock_id INTO lv_dummy.
      log_sy( ).
    ENDIF.
    IF mv_saved EQ abap_true.
      log_event( iv_type = 'S'
                 iv_text = 'Stock lezárási folyamat vége - siker:'(311) ).
    ELSE.
      log_event( iv_type = 'E'
                 iv_text = 'Stock lezárási folyamat vége - sikertelen:'(312) ).
    ENDIF.
    write_log( ).
    IF read_stock( ) EQ abap_true.
      determine_mode( ).
      sync_lock( ).
    ELSE.
      mv_modif = abap_false.
      mv_block_msgno = 151.
      unlock( ).
    ENDIF.
    rv_done = abap_true.
  ENDMETHOD.

  METHOD release_execute.
    " A stock lezárása: újraellenőrzés, a ZCL_PR_STOCK=>CLOSE_STOCK hívása
    " és az eredmény visszaolvasása. Hibánál visszatér; a busy jelzőt a hívó törli.
    DATA lv_class_started TYPE abap_bool.
    DATA lv_displayed_total TYPE i.
    DATA lv_dummy TYPE string.
    DATA ls_after TYPE zprt_stock.
    DATA lt_displayed TYPE tt_alv.
    DATA lo_error TYPE REF TO cx_root.

    TRY.
        IF read_stock( ) EQ abap_false.
          MESSAGE e151(zpr) WITH mv_stock_id INTO lv_dummy.
          log_sy( ).
          RETURN.
        ENDIF.
        determine_mode( ).
        IF mv_modif NE abap_true.
          MESSAGE ID 'ZPR' TYPE 'E' NUMBER mv_block_msgno
            WITH mv_stock_id INTO lv_dummy.
          log_sy( ).
          RETURN.
        ENDIF.

        lt_displayed = mt_alv.
        SORT lt_displayed BY doc_no envelope.
        lv_displayed_total = mv_total.
        IF select_data( ) EQ abap_false.
          RETURN.
        ENDIF.
        IF lt_displayed NE mt_alv OR lv_displayed_total NE mv_total.
          MESSAGE e157(zpr) WITH mv_stock_id INTO lv_dummy.
          log_sy( ).
          RETURN.
        ENDIF.
        IF mv_total EQ 0.
          MESSAGE e158(zpr) WITH mv_stock_id INTO lv_dummy.
          log_sy( ).
          RETURN.
        ENDIF.

        " A prioritás-ablakot az osztály kezeli, és sikernél a CHANGE_STATUS-on át
        " véglegesíti a lezárt státuszt. A sima visszatérés vagy a SY-SUBRC még nem
        " jelent sikert, ezért az eredményt alább visszaolvassuk.
        log_stock_totals( ).
        log_event( iv_type = 'I'
                   iv_text = 'CLOSE_STOCK osztályhívás indul:'(313) ).

        lv_class_started = abap_true.
        zcl_pr_stock=>close_stock( iv_stock = mv_stock_id ).
        log_event( iv_type = 'I'
                   iv_text = 'CLOSE_STOCK osztályhívás visszatért:'(314) ).

        SELECT SINGLE * FROM zprt_stock BYPASSING BUFFER INTO ls_after
          WHERE stock_id EQ mv_stock_id.
        IF sy-subrc NE 0.
          mv_uncertain = abap_true.
          MESSAGE e151(zpr) WITH mv_stock_id INTO lv_dummy.
          log_sy( ).
          RETURN.
        ENDIF.
        IF ls_after-status NE gc_status_closed.
          MESSAGE e159(zpr) WITH mv_stock_id INTO lv_dummy.
          log_sy( ).
          RETURN.
        ENDIF.

        " A QM -> CL váltást és a commitot a ZCL_PR_STOCK=>CLOSE_STOCK végezte a
        " CHANGE_STATUS-on át, ezért külön mentés nem kell; a fenti ellenőrzés
        " igazolja, hogy a stock lezárt lett.
        mv_saved = abap_true.
        rv_ok = abap_true.
        log_event( iv_type = 'S'
                   iv_text = 'SAP lezárási mentés vége - siker:'(322) ).
        MESSAGE s160(zpr) WITH mv_stock_id INTO lv_dummy.
        log_sy( ).
      CATCH cx_root INTO lo_error.
        ROLLBACK WORK.
        IF lv_class_started EQ abap_true.
          mv_uncertain = abap_true.
        ENDIF.
        get_log( )->add_exception( ir_cx = lo_error ).
    ENDTRY.
  ENDMETHOD.

  METHOD show_release_result.
    IF mv_saved EQ abap_true AND mv_log_failed EQ abap_true.
      MESSAGE s162(zpr) WITH mv_stock_id DISPLAY LIKE 'E'.
    ELSEIF mv_saved EQ abap_true.
      MESSAGE s160(zpr) WITH mv_stock_id.
    ELSE.
      MESSAGE s161(zpr) WITH mv_stock_id DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD reload.
    " A Frissítés: a stock újraolvasása; a hibák a naplóba kerülnek, a nézetet a hívó frissíti.
    IF mv_busy EQ abap_true.
      RETURN.
    ENDIF.
    FREE mo_log.
    rv_done = abap_true.
    IF read_stock( ) EQ abap_false.
      mv_modif = abap_false.
      unlock( ).
      MESSAGE s151(zpr) WITH mv_stock_id DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    determine_mode( ).
    IF sync_lock( ) EQ abap_false.
      unlock( ).
      write_log( ).
      RETURN.
    ENDIF.

    IF select_data( ) EQ abap_false.
      mv_modif = abap_false.
      unlock( ).
      write_log( ).
    ENDIF.
  ENDMETHOD.

  METHOD mark_uncertain.
    " Hibajelzőt mentünk, hogy a lezárás ne küldhető újra, de a stock ne legyen lezártnak jelölve.
    DATA lv_dummy TYPE string.
    DATA lo_error TYPE REF TO cx_root.

    TRY.
        UPDATE zprt_stock
          SET stock_status_er = abap_true
              chuser = sy-uname chdate = sy-datum chtime = sy-uzeit
          WHERE stock_id EQ mv_stock_id.
        IF sy-subrc EQ 0 AND sy-dbcnt EQ 1.
          COMMIT WORK.
          MESSAGE e169(zpr) WITH mv_stock_id INTO lv_dummy.
          log_sy( ).
        ELSE.
          ROLLBACK WORK.
          MESSAGE e170(zpr) WITH mv_stock_id INTO lv_dummy.
          log_sy( ).
        ENDIF.
      CATCH cx_root INTO lo_error.
        ROLLBACK WORK.
        get_log( )->add_exception( ir_cx = lo_error ).
        MESSAGE e171(zpr) WITH mv_stock_id INTO lv_dummy.
        log_sy( ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_log.
    " A naplót az első használatkor hozza létre.
    IF mo_log IS NOT BOUND.
      CREATE OBJECT mo_log
        EXPORTING
          iv_log_object    = gc_log_object
          iv_log_subobject = gc_log_subobject.
    ENDIF.
    rr_log = mo_log.
  ENDMETHOD.

  METHOD log_sy.
    get_log( )->add_system_message( ).
  ENDMETHOD.

  METHOD log_event.
    " Időbélyeges eseménysor a naplóba, a stock azonosítójával.
    DATA lv_stamp TYPE timestampl.

    GET TIME STAMP FIELD lv_stamp.
    get_log( )->add_text(
      iv_text  = |{ iv_text } { lv_stamp TIMESTAMP = ISO TIMEZONE = 'UTC' } UTC { mv_stock_id }|
      iv_msgty = iv_type ).
  ENDMETHOD.

  METHOD log_stock_totals.
    " Csak naplózáshoz: a teljes stockot nézi, az engedett és a kizárt sorokkal együtt.
    TYPES: BEGIN OF ts_log_row,
             package_id TYPE zprt_dcqm-package_id,
             doc_no     TYPE zprt_dcqm-doc_no,
           END OF ts_log_row.
    DATA lv_count TYPE i.
    DATA lv_no_document TYPE i.
    DATA lv_no_package TYPE i.
    DATA ls_row TYPE ts_log_row.
    DATA lt_documents TYPE SORTED TABLE OF zprt_dcqm-doc_no
                      WITH UNIQUE KEY table_line.
    DATA lt_packages TYPE SORTED TABLE OF zprt_dcqm-package_id
                     WITH UNIQUE KEY table_line.
    DATA lt_rows TYPE STANDARD TABLE OF ts_log_row.
    DATA lo_error TYPE REF TO cx_root.

    log_event( iv_type = 'I'
               iv_text = 'Stock naplóösszesítés:'(307) ).
    TRY.
        SELECT package_id doc_no FROM zprt_dcqm INTO TABLE lt_rows
          WHERE prd_stock_id EQ mv_stock_id.
        LOOP AT lt_rows INTO ls_row.
          IF ls_row-package_id IS INITIAL.
            ADD 1 TO lv_no_package.
          ELSE.
            INSERT ls_row-package_id INTO TABLE lt_packages.
          ENDIF.
          IF ls_row-doc_no IS INITIAL.
            ADD 1 TO lv_no_document.
          ELSE.
            INSERT ls_row-doc_no INTO TABLE lt_documents.
          ENDIF.
        ENDLOOP.
        DESCRIBE TABLE lt_packages LINES lv_count.
        get_log( )->add_text( iv_text  = |{ 'Egyedi, kitöltött PACKAGE_ID-k száma:'(301) } { number_text( lv_count ) }|
                              iv_msgty = 'I' ).
        DESCRIBE TABLE lt_documents LINES lv_count.
        get_log( )->add_text( iv_text  = |{ 'Egyedi, kitöltött DOC_NO-k száma:'(302) } { number_text( lv_count ) }|
                              iv_msgty = 'I' ).
        DESCRIBE TABLE lt_rows LINES lv_count.
        get_log( )->add_text( iv_text  = |{ 'Nyomtatási rekordok száma (DCQM):'(303) } { number_text( lv_count ) }|
                              iv_msgty = 'I' ).
        IF lv_no_package GT 0.
          get_log( )->add_text( iv_text  = |{ 'PACKAGE_ID nélküli nyomtatási rekordok:'(304) } { number_text( lv_no_package ) }|
                                iv_msgty = 'W' ).
        ENDIF.
        IF lv_no_document GT 0.
          get_log( )->add_text( iv_text  = |{ 'DOC_NO nélküli nyomtatási rekordok:'(305) } { number_text( lv_no_document ) }|
                                iv_msgty = 'W' ).
        ENDIF.
      CATCH cx_root INTO lo_error.
        get_log( )->add_text( iv_text  = |{ 'A napló darabszámai nem olvashatók:'(306) } { mv_stock_id } { lo_error->get_text( ) }|
                              iv_msgty = 'W' ).
    ENDTRY.
  ENDMETHOD.

  METHOD write_log.
    " A napló lezárása és megjelenítése; a mentési vagy megjelenítési hibát jelzi.
    DATA lo_error TYPE REF TO cx_root.

    mv_log_failed = abap_false.
    IF mo_log IS NOT BOUND.
      RETURN.
    ENDIF.
    " Az üzleti változások ekkorra már véglegesítve vagy visszagörgetve vannak.
    TRY.
        IF mo_log->close( ) EQ abap_false.
          mv_log_failed = abap_true.
        ENDIF.
        mo_log->display( ).
      CATCH cx_root INTO lo_error.
        ROLLBACK WORK.
        mv_log_failed = abap_true.
        MESSAGE lo_error TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_view IMPLEMENTATION.
  METHOD f4_stock.
    DATA ls_return TYPE ddshretval.
    DATA lt_returns TYPE STANDARD TABLE OF ddshretval.
    DATA lt_stocks TYPE STANDARD TABLE OF ts_stock_f4.

    SELECT stock_id status closed dccompl qmcompl priority
      FROM zprt_stock INTO TABLE lt_stocks UP TO 5000 ROWS
      ORDER BY stock_id DESCENDING.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield        = 'STOCK_ID'
        value_org       = 'S'
        window_title    = 'Stockok (legfeljebb 5000)'(144)
      TABLES
        value_tab       = lt_stocks
        return_tab      = lt_returns
      EXCEPTIONS
        parameter_error = 1
        no_values_found = 2
        OTHERS          = 3.
    IF sy-subrc EQ 0.
      READ TABLE lt_returns INTO ls_return INDEX 1.
      IF sy-subrc EQ 0.
        cv_stock = ls_return-fieldval.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD constructor.
    mo_stock = ir_stock.
    mv_variant = iv_variant.
  ENDMETHOD.

  METHOD create_controls.
    DATA ls_layout TYPE lvc_s_layo.
    DATA ls_variant TYPE disvariant.
    DATA lt_exclude TYPE ui_functions.
    DATA lt_fields TYPE lvc_t_fcat.

    IF mo_header_container IS NOT BOUND.
      CREATE OBJECT mo_header_container
        EXPORTING
          repid     = sy-repid
          dynnr     = sy-dynnr
          side      = cl_gui_docking_container=>dock_at_top
          extension = 110
        EXCEPTIONS
          OTHERS    = 1.
      IF sy-subrc NE 0.
        FREE mo_header_container.
        MESSAGE 'A fejléc-konténer nem hozható létre.'(128) TYPE 'S' DISPLAY LIKE 'W'.
      ENDIF.
    ENDIF.
    build_header( ).

    " Az ALV-rácsot csak egyszer hozzuk létre.
    IF mo_grid IS BOUND.
      RETURN.
    ENDIF.
    CREATE OBJECT mo_container
      EXPORTING
        container_name = 'ALV_CONTAINER_01'
      EXCEPTIONS
        OTHERS         = 1.
    IF sy-subrc NE 0.
      MESSAGE e163(zpr).
    ENDIF.
    CREATE OBJECT mo_grid
      EXPORTING
        i_parent      = mo_container
        i_appl_events = abap_true.
    lt_fields = get_fieldcatalog( ).
    ls_layout-zebra = abap_true.
    ls_layout-cwidth_opt = abap_true.
    ls_layout-no_rowmark = abap_true.
    ls_variant-report = sy-repid.
    ls_variant-username = sy-uname.
    ls_variant-variant = mv_variant.
    lt_exclude = get_excluded_functions( ).
    SET HANDLER me->on_toolbar me->on_user_command FOR mo_grid.
    mo_grid->set_table_for_first_display(
      EXPORTING is_layout = ls_layout is_variant = ls_variant
                i_save = 'A' it_toolbar_excluding = lt_exclude
      CHANGING it_outtab = mo_stock->mt_alv it_fieldcatalog = lt_fields
      EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc NE 0.
      MESSAGE e165(zpr).
    ENDIF.
    mo_grid->set_ready_for_input( i_ready_for_input = 0 ).
    mo_grid->set_toolbar_interactive( ).
  ENDMETHOD.

  METHOD is_modifiable.
    rv_modif = mo_stock->mv_modif.
  ENDMETHOD.

  METHOD user_command.
    DATA lv_okcode TYPE syucomm.
    DATA lv_return_code TYPE i.

    lv_okcode = cv_okcode.
    CLEAR cv_okcode.
    cl_gui_cfw=>dispatch( IMPORTING return_code = lv_return_code ).
    IF lv_return_code EQ cl_gui_cfw=>rc_unknown
       OR lv_return_code EQ cl_gui_cfw=>rc_nodispatch.
      MESSAGE s167(zpr) DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    IF lv_return_code EQ cl_gui_cfw=>rc_found.
      RETURN.
    ENDIF.
    CASE lv_okcode.
      WHEN 'REFRESH'.
        reload_display( ).
      WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
        exit_screen( ).
    ENDCASE.
  ENDMETHOD.

  METHOD exit_command.
    " A kilépő parancs nem futtatja le a vezérlők eseménykezelését (dispatch).
    DATA lv_okcode TYPE syucomm.

    lv_okcode = cv_okcode.
    CLEAR cv_okcode.
    CASE lv_okcode.
      WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
        exit_screen( ).
    ENDCASE.
  ENDMETHOD.

  METHOD free_controls.
    DATA lv_free_failed TYPE abap_bool.

    IF mo_grid IS BOUND.
      mo_grid->free( EXCEPTIONS OTHERS = 1 ).
      IF sy-subrc NE 0.
        lv_free_failed = abap_true.
      ENDIF.
      FREE mo_grid.
    ENDIF.

    IF mo_container IS BOUND.
      mo_container->free( EXCEPTIONS OTHERS = 1 ).
      IF sy-subrc NE 0.
        lv_free_failed = abap_true.
      ENDIF.
      FREE mo_container.
    ENDIF.

    FREE mo_header.
    IF mo_header_container IS BOUND.
      mo_header_container->free( EXCEPTIONS OTHERS = 1 ).
      IF sy-subrc NE 0.
        lv_free_failed = abap_true.
      ENDIF.
      FREE mo_header_container.
    ENDIF.

    IF lv_free_failed EQ abap_true.
      MESSAGE i168(zpr) DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD get_fieldcatalog.
    FIELD-SYMBOLS <ls_field> TYPE lvc_s_fcat.

    CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name       = 'ZPRS_DCQM_REPORT'
      CHANGING
        ct_fieldcat            = rt_fcat
      EXCEPTIONS
        inconsistent_interface = 1
        program_error          = 2
        OTHERS                 = 3.
    IF sy-subrc NE 0.
      MESSAGE e164(zpr).
    ENDIF.
    LOOP AT rt_fcat ASSIGNING <ls_field>.
      <ls_field>-edit = abap_false.
      <ls_field>-f4availabl = abap_false.
      IF <ls_field>-fieldname EQ 'CHANGED'
         OR <ls_field>-fieldname EQ 'HANDLE_STYLE'.
        <ls_field>-tech = abap_true.
      ELSEIF <ls_field>-fieldname EQ 'COUNTER'.
        <ls_field>-do_sum = abap_true.
        <ls_field>-coltext = 'Sorok száma'(143).
        <ls_field>-col_pos = 99.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_excluded_functions.
    APPEND cl_gui_alv_grid=>mc_fc_loc_append_row TO rt_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_insert_row TO rt_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_delete_row TO rt_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_copy_row TO rt_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_cut TO rt_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_paste TO rt_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_undo TO rt_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_refresh TO rt_exclude.
  ENDMETHOD.

  METHOD build_header.
    " A stock összegzését a lezárási művelettől függetlenül jeleníti meg.
    DATA lv_number TYPE string.
    DATA lv_reuse TYPE abap_bool.
    DATA lv_text TYPE sdydo_text_element.

    IF mo_header_container IS NOT BOUND.
      RETURN.
    ENDIF.
    IF mo_header IS BOUND.
      lv_reuse = abap_true.
      mo_header->initialize_document( ).
    ELSE.
      CREATE OBJECT mo_header.
    ENDIF.

    CONCATENATE 'Stock ID:'(136) mo_stock->mv_stock_id INTO lv_text SEPARATED BY space.
    mo_header->add_text( text         = lv_text
                         sap_emphasis = cl_dd_document=>strong ).
    mo_header->new_line( ).

    IF mo_stock->mv_header_valid EQ abap_true.
      lv_number = lcl_stock=>number_text( mo_stock->mv_total ).
    ELSE.
      lv_number = 'Nem elérhető'(141).
    ENDIF.
    CONCATENATE 'Nyomtatási sorok száma:'(137) lv_number INTO lv_text SEPARATED BY space.
    mo_header->add_text( text         = lv_text
                         sap_emphasis = cl_dd_document=>strong ).
    mo_header->new_line( ).

    IF mo_stock->mv_header_valid EQ abap_true.
      lv_number = lcl_stock=>number_text( mo_stock->mv_excluded ).
    ELSE.
      lv_number = 'Nem elérhető'(141).
    ENDIF.
    CONCATENATE 'Kizárt nyomtatási sorok száma:'(138) lv_number INTO lv_text SEPARATED BY space.
    mo_header->add_text( text         = lv_text
                         sap_emphasis = cl_dd_document=>strong ).
    mo_header->new_line( ).

    mo_header->merge_document( ).
    mo_header->display_document(
      EXPORTING parent = mo_header_container reuse_control = lv_reuse
      EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc NE 0.
      MESSAGE 'A fejléc nem jeleníthető meg.'(140) TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.
  ENDMETHOD.

  METHOD refresh_grid.
    DATA ls_stable TYPE lvc_s_stbl.

    build_header( ).
    IF mo_grid IS NOT BOUND.
      RETURN.
    ENDIF.

    ls_stable-row = abap_true.
    ls_stable-col = abap_true.

    mo_grid->refresh_table_display(
      EXPORTING is_stable = ls_stable EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc NE 0.
      MESSAGE i166(zpr) DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    mo_grid->set_toolbar_interactive( ).
  ENDMETHOD.

  METHOD reload_display.
    IF mo_stock->reload( ) EQ abap_true.
      refresh_grid( ).
    ENDIF.
  ENDMETHOD.

  METHOD exit_screen.
    IF mo_stock->mv_busy EQ abap_true.
      RETURN.
    ENDIF.
    mo_stock->unlock( ).
    SET SCREEN 0.
    LEAVE SCREEN.
  ENDMETHOD.

  METHOD on_toolbar.
    DATA ls_button TYPE stb_button.

    DELETE e_object->mt_toolbar
      WHERE function EQ 'RELEASE' OR function EQ 'ZREFRESH'.

    IF mo_stock->mv_modif EQ abap_true
       AND mo_stock->mv_busy EQ abap_false
       AND mo_stock->mv_locked EQ mo_stock->mv_stock_id.
      CLEAR ls_button.
      ls_button-function = 'RELEASE'.
      ls_button-icon = icon_release.
      ls_button-text = 'Lezárás'(105).
      ls_button-quickinfo = 'Stock engedélyezése és lezárása'(106).
      APPEND ls_button TO e_object->mt_toolbar.
    ENDIF.
    CLEAR ls_button.
    ls_button-function = 'ZREFRESH'.
    ls_button-icon = icon_refresh.
    ls_button-text = 'Frissítés'(142).
    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_user_command.
    CASE e_ucomm.
      WHEN 'RELEASE'.
        IF mo_stock->release( ) EQ abap_true.
          refresh_grid( ).
          mo_stock->show_release_result( ).
        ENDIF.
      WHEN 'ZREFRESH'.
        reload_display( ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.