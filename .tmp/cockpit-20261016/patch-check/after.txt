*&---------------------------------------------------------------------*
*& Report ZPR_QM
*&---------------------------------------------------------------------*
* Rövid leírás: Tömeges nyomtatás - QM-ellenőrzés: a stock mintakategóriáinak
*               kizárása / visszavétele, a minta-PDF megtekintése és letöltése,
*               valamint a stock QM-engedélyezése és annak visszavétele.
* Rendszer:     DHC (S/4HANA)
*
* A program csak vezérel: az üzleti logika a ZCL_PR_QM_EXCLUSION és a
* ZCL_PR_QM_DATA osztályokban van, a tranzakció végét (COMMIT / ROLLBACK)
* itt döntjük el.
*&---------------------------------------------------------------------*
REPORT zpr_qm.

TABLES sscrfields.
CONSTANTS gc_cockpit_run TYPE syucomm VALUE 'QRUN'.
DATA: gv_cockpit_embedded TYPE abap_bool,
      gv_cockpit_run_requested TYPE abap_bool,
      gv_cockpit_stock TYPE zprd_stock_id.

*----------------------------------------------------------------------*
* Kijelölő képernyő (1000). A feliratok a program szövegelemei (TEXT-nnn).
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b_main WITH FRAME TITLE TEXT-001.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(28) TEXT-003 FOR FIELD p_stock.
PARAMETERS p_stock TYPE zprd_stock_id OBLIGATORY MATCHCODE OBJECT ZPR_STOCK.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN SKIP 1.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_mod RADIOBUTTON GROUP grp DEFAULT 'X'.
SELECTION-SCREEN COMMENT 3(60) TEXT-004 FOR FIELD p_mod.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_disp RADIOBUTTON GROUP grp.
SELECTION-SCREEN COMMENT 3(60) TEXT-005 FOR FIELD p_disp.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_rel RADIOBUTTON GROUP grp.
SELECTION-SCREEN COMMENT 3(60) TEXT-006 FOR FIELD p_rel.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_relb RADIOBUTTON GROUP grp.
SELECTION-SCREEN COMMENT 3(60) TEXT-007 FOR FIELD p_relb.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_main.

SELECTION-SCREEN BEGIN OF BLOCK b_layout WITH FRAME TITLE TEXT-002.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(28) TEXT-008 FOR FIELD p_vari.
PARAMETERS p_vari TYPE disvariant-variant.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_layout.

* Reuse the standard input blocks on the cockpit's third tab.
* Screen 1000 remains the independent transaction entry point.
SELECTION-SCREEN BEGIN OF SCREEN 1100 AS SUBSCREEN NESTING LEVEL 1.
SELECTION-SCREEN INCLUDE BLOCKS b_main.
SELECTION-SCREEN INCLUDE BLOCKS b_layout.
SELECTION-SCREEN SKIP 1.
SELECTION-SCREEN PUSHBUTTON /1(24) pb_qrun USER-COMMAND qrun.
SELECTION-SCREEN END OF SCREEN 1100.

* A 2000-es képernyő üres: csak a konténereknek ad helyet (a dynpro
* ADT-ből nem szerkeszthető, ezért kódban definiáljuk).
SELECTION-SCREEN BEGIN OF SCREEN 2000 TITLE TEXT-009.
SELECTION-SCREEN END OF SCREEN 2000.

*----------------------------------------------------------------------*
* A program vezérlése: a kategória-áttekintő rács, a minta-PDF megjelenítése,
* a zárolás és a mentés. Minden adatművelet a ZCL_PR_QM_* osztályokon át
* történik, a zárolás is (ZCL_PR_QM_DATA, dialógus-zár), hogy sem a mentés
* COMMIT-ja, sem a PDF-lekérés implicit commitja ne oldja fel.
* Az osztály FINAL marad: csak statikus metódusai vannak, a statikus
* metódust nem lehet felüldefiniálni, és az Onapsis 2182 FINAL nélkül jelez.
*----------------------------------------------------------------------*
CLASS lcl_qm DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS:
      init,
      f4_layout CHANGING cv_layout TYPE disvariant-variant,
      check_stock,
      start,
      pbo_2000,
      on_exit_2000,
      on_toolbar
        FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,
      on_user_command
        FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm,
      on_double_click
        FOR EVENT double_click OF cl_gui_alv_grid
        IMPORTING e_row e_column,
      on_data_changed
        FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING er_data_changed,
      on_data_changed_finished
        FOR EVENT data_changed_finished OF cl_gui_alv_grid
        IMPORTING e_modified et_good_cells,
      on_f4
        FOR EVENT onf4 OF cl_gui_alv_grid
        IMPORTING e_fieldname es_row_no er_event_data.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ts_parts,
        v1 TYPE string,
        v2 TYPE string,
        v3 TYPE string,
        v4 TYPE string,
      END OF ts_parts.

    CONSTANTS:
      c_log_object    TYPE balobj_d VALUE 'ZPR_MASS' ##NO_TEXT,
      c_log_subobject  TYPE balsubobj VALUE 'STOCK' ##NO_TEXT,
      c_mem_id         TYPE c LENGTH 20 VALUE 'ZPR_QM_STOCK_ID' ##NO_TEXT,
      c_ucomm_save     TYPE ui_func VALUE 'ZQM_SAVE' ##NO_TEXT,
      c_ucomm_download TYPE ui_func VALUE 'ZQM_DOWNLOAD' ##NO_TEXT,
      c_answer_yes    TYPE c LENGTH 1 VALUE '1',
      c_answer_no      TYPE c LENGTH 1 VALUE '2',
      c_file_bin       TYPE char10 VALUE 'BIN' ##NO_TEXT,
      c_chunk_len      TYPE i VALUE 50.

    CLASS-DATA:
      go_data    TYPE REF TO zif_pr_qm_data,
      go_gateway TYPE REF TO zif_pr_inspire_gw,
      go_excl    TYPE REF TO zcl_pr_qm_exclusion,
      go_dock    TYPE REF TO cl_gui_docking_container,
      go_split   TYPE REF TO cl_gui_splitter_container,
      go_grid    TYPE REF TO cl_gui_alv_grid,
      go_html    TYPE REF TO cl_gui_html_viewer,
      gt_ovr     TYPE zif_pr_qm_data=>tt_overview,
      gt_orig    TYPE SORTED TABLE OF zprs_qm_overview WITH UNIQUE KEY qm_cat,
      gv_edit    TYPE abap_bool,
      gv_changed TYPE abap_bool,
      gv_reshow  TYPE abap_bool,
      gv_locked  TYPE zprd_stock_id,
      gv_dummy   TYPE string.

    CLASS-METHODS:
      ensure_objects,
      reset_state,
      stock_text
        RETURNING VALUE(rv_text) TYPE string,
      chunk
        IMPORTING iv_text        TYPE string
                  iv_part        TYPE i
        RETURNING VALUE(rv_text) TYPE string,
      split_text
        IMPORTING iv_text         TYPE string
        RETURNING VALUE(rs_parts) TYPE ts_parts,
      new_log
        RETURNING VALUE(ro_log) TYPE REF TO zcl_pr_log,
      lock
        RETURNING VALUE(rv_ok) TYPE abap_bool,
      unlock,
      change_release
        IMPORTING iv_release TYPE abap_bool,
      open_editor,
      set_icons,
      recalc_changed,
      reload_overview,
      create_controls,
      show_grid,
      free_controls,
      save,
      show_pdf
        IMPORTING iv_qm_cat TYPE zprd_qm_cat,
      download,
      refresh_grid.
ENDCLASS.

CLASS lcl_qm IMPLEMENTATION.

  METHOD init.
    " Az utoljára megnyitott stockot (cockpit-hívás) itt töltjük.
    DATA lv_stock TYPE zprd_stock_id.

    IMPORT stock_id TO lv_stock FROM MEMORY ID c_mem_id.
    IF sy-subrc EQ 0.
      FREE MEMORY ID c_mem_id.
      IF p_stock IS INITIAL.
        p_stock = lv_stock.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD f4_layout.
    " Az elrendezés keresési súgója ugyanaz, mint a többi riportban.
    DATA(ls_key) = VALUE salv_s_layout_key( report = sy-repid ).
    DATA(ls_layout) = cl_salv_layout_service=>f4_layouts( s_key    = ls_key
                                                          restrict = if_salv_c_layout=>restrict_none ).
    cv_layout = ls_layout-layout.
  ENDMETHOD.


  METHOD ensure_objects.
    " Az osztályokat egyszer példányosítjuk; a teszt dublőrrel cserélheti őket.
    IF go_data IS NOT BOUND.
      go_data    = NEW zcl_pr_qm_data( ).
      go_gateway = NEW zcl_pr_inspire_gw( ).
      go_excl    = NEW zcl_pr_qm_exclusion( io_data    = go_data
                                            io_gateway = go_gateway ).
    ENDIF.
  ENDMETHOD.


  METHOD stock_text.
    rv_text = |{ p_stock ALPHA = OUT }|.
    CONDENSE rv_text NO-GAPS.
  ENDMETHOD.


  METHOD chunk.
    " Az üzenet egy változója legfeljebb 50 karakter, ezért a hosszú
    " szöveget négy részre vágjuk.
    DATA(lv_off) = iv_part * c_chunk_len.
    DATA(lv_len) = strlen( iv_text ).
    IF lv_len GT lv_off.
      rv_text = substring( val = iv_text
                           off = lv_off
                           len = nmin( val1 = c_chunk_len
                                       val2 = lv_len - lv_off ) ).
    ENDIF.
  ENDMETHOD.


  METHOD split_text.
    " A hosszú szöveget négy üzenetváltozóba osztjuk.
    rs_parts = VALUE #( v1 = chunk( iv_text = iv_text iv_part = 0 )
                        v2 = chunk( iv_text = iv_text iv_part = 1 )
                        v3 = chunk( iv_text = iv_text iv_part = 2 )
                        v4 = chunk( iv_text = iv_text iv_part = 3 ) ).
  ENDMETHOD.


  METHOD new_log.
    " A kereshetőség miatt a stock azonosítója a napló külső azonosítója.
    ro_log = NEW zcl_pr_log( iv_log_object    = c_log_object
                             iv_log_subobject = c_log_subobject
                             iv_ext_id        = stock_text( ) ).
  ENDMETHOD.


  METHOD check_stock.
    " Nem létező stockkal a riport el sem indulhat.
    ensure_objects( ).
    IF p_stock IS NOT INITIAL AND go_data->get_stock( p_stock ) IS INITIAL.
      MESSAGE e018(zpr_qm) WITH stock_text( ).
    ENDIF.
  ENDMETHOD.


  METHOD lock.
    " A zárat a kizárás-kezelő osztály kéri, dialógus-zárként; így sem a mentés
    " COMMIT-ja, sem a PDF-lekérés implicit commitja nem oldja fel.
    DATA ls_parts TYPE ts_parts.

    TRY.
        go_excl->lock_stock( p_stock ).
        gv_locked = p_stock.
        rv_ok = abap_true.
      CATCH zcx_form_message_error INTO DATA(lx_lock).
        ls_parts = split_text( lx_lock->get_text( ) ).
        MESSAGE s031(zpr_qm) DISPLAY LIKE 'E'
                WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4.
    ENDTRY.
  ENDMETHOD.


  METHOD unlock.
    " Csak a saját, sikeres zárat oldjuk fel.
    DATA ls_parts TYPE ts_parts.

    IF gv_locked IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        go_excl->unlock_stock( gv_locked ).
      CATCH zcx_form_message_error INTO DATA(lx_unlock).
        ls_parts = split_text( lx_unlock->get_text( ) ).
        MESSAGE s031(zpr_qm) DISPLAY LIKE 'E'
                WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4.
    ENDTRY.
    CLEAR gv_locked.
  ENDMETHOD.


  METHOD reset_state.
    " Egy korábbi futás maradványai (zár, konténerek, adatok) ne maradjanak.
    free_controls( ).
    unlock( ).
    CLEAR: gt_ovr, gt_orig, gv_edit, gv_changed, gv_reshow.
  ENDMETHOD.


  METHOD start.
    " A mód dönt: a QM-engedélyezés / visszavétel azonnal lefut, a kizárások
    " szerkesztése és a megtekintés a rácsos képernyőn történik.
    ensure_objects( ).
    reset_state( ).
    CASE abap_true.
      WHEN p_rel.
        change_release( abap_true ).
      WHEN p_relb.
        change_release( abap_false ).
      WHEN OTHERS.
        open_editor( ).
    ENDCASE.
  ENDMETHOD.


  METHOD change_release.
    " A QM-engedélyezés egy LUW: zárolás, módosítás, majd COMMIT; bármely
    " hiba esetén ROLLBACK. A napló a végeredményt rögzíti.
    DATA ls_parts TYPE ts_parts.

    DATA(lo_log) = new_log( ).

    IF lock( ) EQ abap_false.
      RETURN.
    ENDIF.

    TRY.
        IF iv_release EQ abap_true.
          go_excl->release( p_stock ).
        ELSE.
          go_excl->release_back( p_stock ).
        ENDIF.
        COMMIT WORK.
        IF iv_release EQ abap_true.
          MESSAGE s043(zpr_qm) WITH stock_text( ) INTO gv_dummy.
          lo_log->add_system_message( ).
          MESSAGE s043(zpr_qm) WITH stock_text( ).
        ELSE.
          MESSAGE s044(zpr_qm) WITH stock_text( ) INTO gv_dummy.
          lo_log->add_system_message( ).
          MESSAGE s044(zpr_qm) WITH stock_text( ).
        ENDIF.
      CATCH zcx_form_message_error INTO DATA(lx_error).
        ROLLBACK WORK.
        ls_parts = split_text( lx_error->get_text( ) ).
        MESSAGE e031(zpr_qm)
                WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4 INTO gv_dummy.
        lo_log->add_system_message( ).
        MESSAGE s045(zpr_qm) DISPLAY LIKE 'E'
                WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4.
    ENDTRY.

    unlock( ).
    lo_log->close( ).
  ENDMETHOD.


  METHOD open_editor.
    " Szerkesztő módban zárolunk, és a zár megszerzése után friss állapotot
    " ellenőrzünk: lezárt vagy már QM-engedélyezett stocknál megtekintő
    " módra váltunk, és a zárat feloldjuk.
    DATA ls_parts TYPE ts_parts.

    gv_edit = xsdbool( p_mod EQ abap_true ).

    IF gv_edit EQ abap_true.
      IF lock( ) EQ abap_false.
        RETURN.
      ENDIF.
      TRY.
          go_excl->check_editable( p_stock ).
        CATCH zcx_form_message_error INTO DATA(lx_view).
          unlock( ).
          gv_edit = abap_false.
          ls_parts = split_text( lx_view->get_text( ) ).
          MESSAGE i033(zpr_qm)
                  WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4.
      ENDTRY.
    ENDIF.

    gt_ovr = go_data->get_overview( p_stock ).
    IF gt_ovr IS INITIAL.
      unlock( ).
      MESSAGE i032(zpr_qm) WITH stock_text( ).
      RETURN.
    ENDIF.
    set_icons( ).
    gt_orig = gt_ovr.

    " Ha a felhasználó a kilépést nem erősíti meg, a képernyőt újra
    " megnyitjuk; a rács módosításai a belső táblában megmaradnak.
    DO.
      CLEAR gv_reshow.
      CALL SELECTION-SCREEN 2000.
      IF gv_reshow EQ abap_false.
        EXIT.
      ENDIF.
    ENDDO.

    free_controls( ).
    unlock( ).
  ENDMETHOD.


  METHOD set_icons.
    " A kizárt kategória lakat, a szabad kategória zöld jelzés.
    LOOP AT gt_ovr ASSIGNING FIELD-SYMBOL(<ls_row>).
      <ls_row>-icon = COND #( WHEN <ls_row>-block_qm IS INITIAL
                              THEN icon_led_green
                              ELSE icon_locked ).
    ENDLOOP.
  ENDMETHOD.


  METHOD recalc_changed.
    " A módosított sorokat az induláskor eltárolt állapothoz hasonlítjuk.
    gv_changed = abap_false.
    LOOP AT gt_ovr ASSIGNING FIELD-SYMBOL(<ls_row>).
      READ TABLE gt_orig ASSIGNING FIELD-SYMBOL(<ls_orig>)
           WITH TABLE KEY qm_cat = <ls_row>-qm_cat.
      IF sy-subrc EQ 0
         AND <ls_orig>-block_qm      EQ <ls_row>-block_qm
         AND <ls_orig>-block_qm_text EQ <ls_row>-block_qm_text.
        CLEAR <ls_row>-changed.
      ELSE.
        <ls_row>-changed = abap_true.
        gv_changed = abap_true.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD reload_overview.
    " Mentés után az adatbázis állapotát olvassuk vissza, hogy a rács a
    " ténylegesen tárolt értékeket mutassa.
    gt_ovr = go_data->get_overview( p_stock ).
    set_icons( ).
    gt_orig = gt_ovr.
    gv_changed = abap_false.
  ENDMETHOD.


  METHOD refresh_grid.
    IF go_grid IS NOT BOUND.
      RETURN.
    ENDIF.
    go_grid->refresh_table_display(
      EXPORTING
        is_stable = VALUE lvc_s_stbl( row = abap_true col = abap_true )
      EXCEPTIONS
        finished  = 1
        OTHERS    = 2 ).
    IF sy-subrc NE 0.
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD pbo_2000.
    " A 2000-es képernyőn nincs futtatás (F8) és Enter-es folytatás; a
    " konténereket csak egyszer hozzuk létre.
    DATA lt_exclude TYPE STANDARD TABLE OF sy-ucomm WITH DEFAULT KEY.

    lt_exclude = VALUE #( ( 'ONLI' ) ( 'CRET' ) ).
    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING
        p_status  = sy-pfkey
      TABLES
        p_exclude = lt_exclude.

    IF go_dock IS NOT BOUND.
      create_controls( ).
    ENDIF.
  ENDMETHOD.


  METHOD create_controls.
    " Felül a kategória-rács, alul a minta-PDF megjelenítője.
    DATA lo_top    TYPE REF TO cl_gui_container.
    DATA lo_bottom TYPE REF TO cl_gui_container.

    CREATE OBJECT go_dock
      EXPORTING
        repid     = sy-repid
        dynnr     = sy-dynnr
        side      = cl_gui_docking_container=>dock_at_left
        extension = 5000
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc NE 0.
      MESSAGE s048(zpr_qm) DISPLAY LIKE 'E'.
      free_controls( ).
      RETURN.
    ENDIF.

    CREATE OBJECT go_split
      EXPORTING
        parent  = go_dock
        rows    = 2
        columns = 1
      EXCEPTIONS
        OTHERS  = 1.
    IF sy-subrc NE 0.
      MESSAGE s048(zpr_qm) DISPLAY LIKE 'E'.
      free_controls( ).
      RETURN.
    ENDIF.

    go_split->set_row_height( EXPORTING id     = 1
                                        height = 50
                              EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc NE 0.
      " A felosztás aránya csak kinézet, a működést nem érinti.
      CLEAR sy-subrc.
    ENDIF.

    lo_top    = go_split->get_container( row = 1 column = 1 ).
    lo_bottom = go_split->get_container( row = 2 column = 1 ).

    CREATE OBJECT go_html
      EXPORTING
        parent = lo_bottom
      EXCEPTIONS
        OTHERS = 1.
    IF sy-subrc NE 0.
      MESSAGE s048(zpr_qm) DISPLAY LIKE 'E'.
      free_controls( ).
      RETURN.
    ENDIF.

    CREATE OBJECT go_grid
      EXPORTING
        i_parent      = lo_top
        i_appl_events = abap_false
      EXCEPTIONS
        OTHERS        = 1.
    IF sy-subrc NE 0.
      MESSAGE s048(zpr_qm) DISPLAY LIKE 'E'.
      free_controls( ).
      RETURN.
    ENDIF.

    show_grid( ).
  ENDMETHOD.


  METHOD show_grid.
    " A szerkeszthető oszlopok csak szerkesztő módban nyitottak; a kód
    " oszlop keresési súgóját az onf4 esemény adja.
    DATA lt_fcat TYPE lvc_t_fcat.

    SET HANDLER on_toolbar
                on_user_command
                on_double_click
                on_data_changed
                on_data_changed_finished
                on_f4
                FOR go_grid.

    CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name       = 'ZPRS_QM_OVERVIEW'
      CHANGING
        ct_fieldcat            = lt_fcat
      EXCEPTIONS
        inconsistent_interface = 1
        program_error          = 2
        OTHERS                 = 3.
    IF sy-subrc NE 0.
      MESSAGE s048(zpr_qm) DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    LOOP AT lt_fcat ASSIGNING FIELD-SYMBOL(<ls_fcat>).
      CASE <ls_fcat>-fieldname.
        WHEN 'ICON'.
          <ls_fcat>-coltext = TEXT-011.
          <ls_fcat>-icon    = abap_true.
        WHEN 'QM_CAT'.
          <ls_fcat>-coltext = TEXT-012.
        WHEN 'DESCR'.
          <ls_fcat>-coltext = TEXT-013.
        WHEN 'DOC_COUNT'.
          <ls_fcat>-coltext = TEXT-014.
        WHEN 'SAMPLE_COUNT'.
          <ls_fcat>-coltext = TEXT-015.
        WHEN 'BLOCK_QM'.
          <ls_fcat>-coltext    = TEXT-016.
          <ls_fcat>-edit       = gv_edit.
          <ls_fcat>-f4availabl = gv_edit.
        WHEN 'BLOCK_QM_TEXT'.
          <ls_fcat>-coltext = TEXT-017.
          <ls_fcat>-edit    = gv_edit.
        WHEN 'CHANGED' OR 'HANDLE_STYLE'.
          <ls_fcat>-tech = abap_true.
      ENDCASE.
    ENDLOOP.

    DATA(ls_layout) = VALUE lvc_s_layo( zebra      = abap_true
                                        cwidth_opt = abap_true
                                        sel_mode   = 'A'
                                        smalltitle = abap_true
                                        grid_title = |{ stock_text( ) } { TEXT-010 }| ).
    DATA(ls_variant) = VALUE disvariant( report   = sy-repid
                                         username = sy-uname
                                         variant  = p_vari ).

    IF gv_edit EQ abap_true.
      go_grid->set_ready_for_input( i_ready_for_input = 1 ).
      go_grid->register_edit_event(
        EXPORTING
          i_event_id = cl_gui_alv_grid=>mc_evt_modified
        EXCEPTIONS
          error      = 1
          OTHERS     = 2 ).
      IF sy-subrc NE 0.
        MESSAGE s048(zpr_qm) DISPLAY LIKE 'E'.
      ENDIF.
      go_grid->register_f4_for_fields(
        it_f4 = VALUE lvc_t_f4( ( fieldname = 'BLOCK_QM' register = abap_true ) ) ).
    ENDIF.

    go_grid->set_table_for_first_display(
      EXPORTING
        is_variant                    = ls_variant
        i_save                        = 'A'
        i_default                     = abap_true
        is_layout                     = ls_layout
      CHANGING
        it_outtab                     = gt_ovr
        it_fieldcatalog               = lt_fcat
      EXCEPTIONS
        invalid_parameter_combination = 1
        program_error                 = 2
        too_many_lines                = 3
        OTHERS                        = 4 ).
    IF sy-subrc NE 0.
      MESSAGE s048(zpr_qm) DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    go_grid->set_toolbar_interactive( ).
  ENDMETHOD.


  METHOD free_controls.
    " A konténereket a képernyő elhagyásakor felszabadítjuk; a rács
    " módosításai a belső táblában megmaradnak.
    IF go_grid IS BOUND.
      go_grid->free( EXCEPTIONS OTHERS = 1 ).
      IF sy-subrc NE 0.
        CLEAR sy-subrc.
      ENDIF.
    ENDIF.
    IF go_html IS BOUND.
      go_html->free( EXCEPTIONS OTHERS = 1 ).
      IF sy-subrc NE 0.
        CLEAR sy-subrc.
      ENDIF.
    ENDIF.
    IF go_split IS BOUND.
      go_split->free( EXCEPTIONS OTHERS = 1 ).
      IF sy-subrc NE 0.
        CLEAR sy-subrc.
      ENDIF.
    ENDIF.
    IF go_dock IS BOUND.
      go_dock->free( EXCEPTIONS OTHERS = 1 ).
      IF sy-subrc NE 0.
        CLEAR sy-subrc.
      ENDIF.
    ENDIF.
    FREE: go_grid, go_html, go_split, go_dock.
  ENDMETHOD.


  METHOD on_exit_2000.
    " Kilépéskor a nem mentett módosításról figyelmeztetünk. Nemleges válasznál
    " a képernyő újranyílik (gv_reshow), a módosítások megmaradnak.
    DATA lv_answer TYPE c LENGTH 1.
    DATA lv_title TYPE c LENGTH 80.
    DATA lv_question TYPE c LENGTH 256.

    IF gv_edit EQ abap_true AND go_grid IS BOUND.
      go_grid->check_changed_data( ).
      recalc_changed( ).
      IF gv_changed EQ abap_true.
        lv_title    = TEXT-020.
        lv_question = TEXT-021.
        CALL FUNCTION 'POPUP_TO_CONFIRM'
          EXPORTING
            titlebar              = lv_title
            text_question         = lv_question
            default_button        = c_answer_no
            display_cancel_button = abap_false
          IMPORTING
            answer                = lv_answer
          EXCEPTIONS
            text_not_found        = 1
            OTHERS                = 2.
        IF sy-subrc NE 0 OR lv_answer NE c_answer_yes.
          gv_reshow = abap_true.
        ENDIF.
      ENDIF.
    ENDIF.

    free_controls( ).
  ENDMETHOD.


  METHOD on_toolbar.
    " A felesleges szabványos gombokat töröljük, a sajátokat hozzáadjuk; a
    " Mentés gomb csak szerkesztő módban jelenik meg.
    DELETE e_object->mt_toolbar
      WHERE function EQ cl_gui_alv_grid=>mc_mb_view
         OR function EQ cl_gui_alv_grid=>mc_fc_detail
         OR function EQ cl_gui_alv_grid=>mc_fc_loc_append_row
         OR function EQ cl_gui_alv_grid=>mc_fc_loc_copy_row
         OR function EQ cl_gui_alv_grid=>mc_fc_loc_delete_row
         OR function EQ cl_gui_alv_grid=>mc_fc_loc_insert_row
         OR function EQ cl_gui_alv_grid=>mc_fc_graph
         OR function EQ cl_gui_alv_grid=>mc_fc_info
         OR function EQ cl_gui_alv_grid=>mc_fc_refresh
         OR function EQ cl_gui_alv_grid=>mc_fc_loc_undo
         OR function EQ cl_gui_alv_grid=>mc_fc_loc_copy
         OR function EQ cl_gui_alv_grid=>mc_fc_loc_cut
         OR function EQ cl_gui_alv_grid=>mc_fc_loc_paste.

    APPEND VALUE #( butn_type = 3 ) TO e_object->mt_toolbar.

    IF gv_edit EQ abap_true.
      APPEND VALUE #( function  = c_ucomm_save
                      icon      = icon_system_save
                      quickinfo = TEXT-018
                      text      = TEXT-018 ) TO e_object->mt_toolbar.
    ENDIF.

    APPEND VALUE #( function  = c_ucomm_download
                    icon      = icon_export
                    quickinfo = TEXT-019
                    text      = TEXT-019 ) TO e_object->mt_toolbar.
  ENDMETHOD.


  METHOD on_user_command.
    CASE e_ucomm.
      WHEN c_ucomm_save.
        IF gv_edit EQ abap_true.
          save( ).
        ENDIF.
      WHEN c_ucomm_download.
        download( ).
    ENDCASE.
  ENDMETHOD.


  METHOD on_double_click.
    " A kategória-kódon végzett dupla kattintás a minta-PDF-et mutatja.
    IF e_column-fieldname NE 'QM_CAT'.
      RETURN.
    ENDIF.
    READ TABLE gt_ovr ASSIGNING FIELD-SYMBOL(<ls_row>) INDEX e_row-index.
    IF sy-subrc NE 0.
      RETURN.
    ENDIF.
    IF <ls_row>-sample_count EQ 0.
      MESSAGE i038(zpr_qm) WITH <ls_row>-qm_cat.
      RETURN.
    ENDIF.
    show_pdf( <ls_row>-qm_cat ).
  ENDMETHOD.


  METHOD on_data_changed.
    " Csak érvényesítés: ismeretlen kizárási kódnál hibaprotokoll, az érték
    " nem kerül át a táblába.
    DATA lv_code TYPE zprd_pr_block_qm.

    LOOP AT er_data_changed->mt_mod_cells INTO DATA(ls_cell)
         WHERE fieldname EQ 'BLOCK_QM'.
      er_data_changed->get_cell_value(
        EXPORTING
          i_row_id    = ls_cell-row_id
          i_fieldname = ls_cell-fieldname
        IMPORTING
          e_value     = lv_code ).
      IF lv_code IS NOT INITIAL AND go_data->code_exists( lv_code ) EQ abap_false.
        MESSAGE e024(zpr_qm) WITH lv_code INTO gv_dummy.
        er_data_changed->add_protocol_entry(
          i_msgid     = sy-msgid
          i_msgty     = sy-msgty
          i_msgno     = sy-msgno
          i_msgv1     = sy-msgv1
          i_fieldname = ls_cell-fieldname
          i_row_id    = ls_cell-row_id ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD on_data_changed_finished.
    IF e_modified EQ abap_true.
      recalc_changed( ).
    ENDIF.
  ENDMETHOD.


  METHOD on_f4.
    " A kizárási kód keresési súgója a karbantartott kódtáblából jön.
    TYPES:
      BEGIN OF ts_code,
        block_qm TYPE zprc_pr_qmcode-block_qm,
        descr40  TYPE zprc_pr_qmcode-descr40,
      END OF ts_code.
    DATA lt_code TYPE STANDARD TABLE OF ts_code WITH DEFAULT KEY.
    DATA lt_return TYPE STANDARD TABLE OF ddshretval WITH DEFAULT KEY.
    FIELD-SYMBOLS <lt_modi> TYPE lvc_t_modi.

    SELECT block_qm descr40
      FROM zprc_pr_qmcode
      INTO TABLE lt_code.
    IF sy-subrc EQ 0.
      SORT lt_code BY block_qm.
      CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
        EXPORTING
          retfield        = 'BLOCK_QM'
          value_org       = 'S'
        TABLES
          value_tab       = lt_code
          return_tab      = lt_return
        EXCEPTIONS
          parameter_error = 1
          no_values_found = 2
          OTHERS          = 3.
      IF sy-subrc EQ 0 AND lt_return IS NOT INITIAL.
        ASSIGN er_event_data->m_data->* TO <lt_modi>.
        IF sy-subrc EQ 0.
          APPEND VALUE #( row_id    = es_row_no-row_id
                          fieldname = e_fieldname
                          value     = lt_return[ 1 ]-fieldval ) TO <lt_modi>.
        ENDIF.
      ENDIF.
    ENDIF.
    " A saját keresési súgó után a szabványos nem nyílhat meg.
    er_event_data->m_event_handled = abap_true.
  ENDMETHOD.


  METHOD save.
    " A mentés egy LUW: a módosított sorok közül bármelyik hibája esetén az
    " egész ROLLBACK, siker esetén COMMIT. A rács hiba után nyitva marad. A
    " zár dialógus-hatókörű, ezért a COMMIT után is megmarad.
    DATA lv_valid TYPE c LENGTH 1.
    DATA lv_error TYPE string.
    DATA lv_count TYPE i.
    DATA ls_parts TYPE ts_parts.

    go_grid->check_changed_data( IMPORTING e_valid = lv_valid ).
    IF lv_valid NE abap_true.
      RETURN.
    ENDIF.

    recalc_changed( ).
    IF gv_changed EQ abap_false.
      MESSAGE i036(zpr_qm).
      RETURN.
    ENDIF.

    " A szöveg csak kóddal adható meg: ezt írás előtt ellenőrizzük.
    LOOP AT gt_ovr ASSIGNING FIELD-SYMBOL(<ls_check>)
         WHERE changed EQ abap_true
           AND block_qm IS INITIAL
           AND block_qm_text IS NOT INITIAL.
      MESSAGE s037(zpr_qm) DISPLAY LIKE 'E' WITH <ls_check>-qm_cat.
      RETURN.
    ENDLOOP.

    DATA(lo_log) = new_log( ).

    TRY.
        LOOP AT gt_ovr ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE changed EQ abap_true.
          IF <ls_row>-block_qm IS INITIAL.
            go_excl->unblock_category( iv_stock_id = p_stock
                                       iv_qm_cat   = <ls_row>-qm_cat ).
            MESSAGE s047(zpr_qm) WITH <ls_row>-qm_cat INTO gv_dummy.
            lo_log->add_system_message( ).
          ELSE.
            go_excl->block_category( iv_stock_id = p_stock
                                     iv_qm_cat   = <ls_row>-qm_cat
                                     iv_block_qm = <ls_row>-block_qm
                                     iv_text     = <ls_row>-block_qm_text ).
            MESSAGE s046(zpr_qm) WITH <ls_row>-qm_cat <ls_row>-block_qm INTO gv_dummy.
            lo_log->add_system_message( ).
          ENDIF.
          lv_count = lv_count + 1.
        ENDLOOP.
      CATCH zcx_form_message_error INTO DATA(lx_error).
        lv_error = lx_error->get_text( ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        lv_error = lx_sql->get_text( ).
    ENDTRY.

    IF lv_error IS INITIAL.
      COMMIT WORK.
      MESSAGE s034(zpr_qm) WITH |{ lv_count }| INTO gv_dummy.
      lo_log->add_system_message( ).
      lo_log->close( ).
      reload_overview( ).
      refresh_grid( ).
      MESSAGE s034(zpr_qm) WITH |{ lv_count }|.
    ELSE.
      ROLLBACK WORK.
      " A visszagörgetett sorok sikerüzenetei nem maradhatnak a naplóban,
      " ezért új naplót nyitunk, és csak a hibát rögzítjük.
      lo_log = new_log( ).
      ls_parts = split_text( lv_error ).
      MESSAGE e031(zpr_qm)
              WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4 INTO gv_dummy.
      lo_log->add_system_message( ).
      lo_log->close( ).
      MESSAGE s035(zpr_qm) DISPLAY LIKE 'E'
              WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4.
    ENDIF.
  ENDMETHOD.


  METHOD show_pdf.
    " A PDF-lekérés proxyhívás, amely commitol; itt nincs függő írás, mert a
    " rács módosításai csak a memóriában vannak, a zár pedig dialógus-hatókörű.
    DATA lt_binary TYPE STANDARD TABLE OF x255 WITH DEFAULT KEY.
    DATA lv_length TYPE i.
    DATA lv_url    TYPE c LENGTH 1024.
    DATA ls_parts  TYPE ts_parts.

    TRY.
        DATA(ls_pdf) = go_gateway->get_sample_pdf( iv_stock_id = p_stock
                                                   iv_qm_cat   = iv_qm_cat ).
      CATCH zcx_form_message_error INTO DATA(lx_error).
        ls_parts = split_text( lx_error->get_text( ) ).
        MESSAGE i039(zpr_qm)
                WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4.
        RETURN.
    ENDTRY.

    IF ls_pdf-success EQ abap_false OR ls_pdf-content IS INITIAL.
      ls_parts = split_text( ls_pdf-info ).
      MESSAGE i039(zpr_qm)
              WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4.
      RETURN.
    ENDIF.

    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        buffer        = ls_pdf-content
      IMPORTING
        output_length = lv_length
      TABLES
        binary_tab    = lt_binary.

    go_html->load_data(
      EXPORTING
        type                 = 'application'
        subtype              = 'pdf'
        size                 = lv_length
      IMPORTING
        assigned_url         = lv_url
      CHANGING
        data_table           = lt_binary
      EXCEPTIONS
        dp_invalid_parameter = 1
        dp_error_general     = 2
        cntl_error           = 3
        OTHERS               = 4 ).
    IF sy-subrc NE 0.
      MESSAGE i039(zpr_qm) WITH iv_qm_cat.
      RETURN.
    ENDIF.

    go_html->show_url(
      EXPORTING
        url        = lv_url
      EXCEPTIONS
        cntl_error = 1
        OTHERS     = 2 ).
    IF sy-subrc NE 0.
      MESSAGE i039(zpr_qm) WITH iv_qm_cat.
    ENDIF.
  ENDMETHOD.


  METHOD download.
    " A kijelölt kategóriák minta-PDF-jét újra lekérjük és a megadott
    " könyvtárba mentjük <stock>_<kategória>.pdf néven; gyorsítótár nincs.
    DATA lt_index  TYPE lvc_t_row.
    DATA lv_folder TYPE string.
    DATA lv_sep    TYPE c LENGTH 1.
    DATA lt_binary TYPE STANDARD TABLE OF x255 WITH DEFAULT KEY.
    DATA lv_length TYPE i.
    DATA lv_count  TYPE i.
    DATA ls_parts  TYPE ts_parts.

    go_grid->get_selected_rows( IMPORTING et_index_rows = lt_index ).
    IF lt_index IS INITIAL.
      MESSAGE i041(zpr_qm).
      RETURN.
    ENDIF.

    cl_gui_frontend_services=>directory_browse(
      CHANGING
        selected_folder      = lv_folder
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4 ).
    IF sy-subrc NE 0 OR lv_folder IS INITIAL.
      RETURN.
    ENDIF.

    cl_gui_frontend_services=>get_file_separator(
      CHANGING
        file_separator       = lv_sep
      EXCEPTIONS
        not_supported_by_gui = 1
        error_no_gui         = 2
        cntl_error           = 3
        OTHERS               = 4 ).
    IF sy-subrc NE 0.
      RETURN.
    ENDIF.
    cl_gui_cfw=>flush( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc NE 0.
      CLEAR sy-subrc.
    ENDIF.

    LOOP AT lt_index INTO DATA(ls_index).
      READ TABLE gt_ovr ASSIGNING FIELD-SYMBOL(<ls_row>) INDEX ls_index-index.
      IF sy-subrc NE 0 OR <ls_row>-sample_count EQ 0.
        CONTINUE.
      ENDIF.

      TRY.
          DATA(ls_pdf) = go_gateway->get_sample_pdf( iv_stock_id = p_stock
                                                     iv_qm_cat   = <ls_row>-qm_cat ).
        CATCH zcx_form_message_error INTO DATA(lx_error).
          ls_parts = split_text( |{ <ls_row>-qm_cat } { lx_error->get_text( ) }| ).
          MESSAGE s039(zpr_qm) DISPLAY LIKE 'E'
                  WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4.
          CONTINUE.
      ENDTRY.
      IF ls_pdf-success EQ abap_false OR ls_pdf-content IS INITIAL.
        ls_parts = split_text( |{ <ls_row>-qm_cat } { ls_pdf-info }| ).
        MESSAGE s039(zpr_qm) DISPLAY LIKE 'E'
                WITH ls_parts-v1 ls_parts-v2 ls_parts-v3 ls_parts-v4.
        CONTINUE.
      ENDIF.

      CLEAR lt_binary.
      CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
        EXPORTING
          buffer        = ls_pdf-content
        IMPORTING
          output_length = lv_length
        TABLES
          binary_tab    = lt_binary.

      DATA(lv_file) = |{ lv_folder }{ lv_sep }{ stock_text( ) }_{ <ls_row>-qm_cat }.pdf|.
      cl_gui_frontend_services=>gui_download(
        EXPORTING
          bin_filesize = lv_length
          filename     = lv_file
          filetype     = c_file_bin
        CHANGING
          data_tab     = lt_binary
        EXCEPTIONS
          OTHERS       = 1 ).
      IF sy-subrc NE 0.
        MESSAGE s040(zpr_qm) DISPLAY LIKE 'E' WITH <ls_row>-qm_cat.
        CONTINUE.
      ENDIF.
      lv_count = lv_count + 1.
    ENDLOOP.

    MESSAGE s042(zpr_qm) WITH |{ lv_count }|.
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* Események
*----------------------------------------------------------------------*
* Cockpit adapter: opening the input screen never starts QM business work.
FORM cockpit_open USING iv_stock_id TYPE zprd_stock_id
                  CHANGING cv_ready TYPE abap_bool.
  cv_ready = abap_false.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD 'ZPR_QM'.
  IF sy-subrc <> 0.
    MESSAGE s172(00) WITH 'ZPR_QM' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  CHECK iv_stock_id IS NOT INITIAL.
  IF gv_cockpit_embedded <> abap_true OR gv_cockpit_stock <> iv_stock_id.
    CLEAR: p_disp, p_rel, p_relb, p_vari, gv_cockpit_run_requested.
    p_mod = abap_true.
    gv_cockpit_stock = iv_stock_id.
  ENDIF.
  p_stock = iv_stock_id.
  gv_cockpit_embedded = abap_true.
  cv_ready = abap_true.
ENDFORM.

FORM cockpit_execute CHANGING cv_handled TYPE abap_bool.
  cv_handled = abap_false.
  CHECK gv_cockpit_run_requested = abap_true.
  CLEAR gv_cockpit_run_requested.
  cv_handled = abap_true.
  CHECK gv_cockpit_embedded = abap_true AND gv_cockpit_stock IS NOT INITIAL.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD 'ZPR_QM'.
  IF sy-subrc <> 0.
    MESSAGE s172(00) WITH 'ZPR_QM' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  p_stock = gv_cockpit_stock.
* Start a separate report session so screen 2000 belongs to ZPR_QM.
  SUBMIT zpr_qm
    WITH p_stock = gv_cockpit_stock
    WITH p_mod   = p_mod
    WITH p_disp  = p_disp
    WITH p_rel   = p_rel
    WITH p_relb  = p_relb
    WITH p_vari  = p_vari
    AND RETURN.
ENDFORM.

FORM cockpit_close.
* The input screen itself owns no lock or unsaved business data.
* The existing START path cleans up its editor before returning to the host.
  CLEAR: gv_cockpit_embedded, gv_cockpit_run_requested, gv_cockpit_stock,
         p_stock, p_disp, p_rel, p_relb, p_vari.
  p_mod = abap_true.
ENDFORM.

INITIALIZATION.
  lcl_qm=>init( ).

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_vari.
  lcl_qm=>f4_layout( CHANGING cv_layout = p_vari ).

AT SELECTION-SCREEN ON p_stock.
* The host validates its accepted stock before the subscreen PAI.
* Do not block navigation with a report-level E message on this subscreen.
  IF sy-dynnr <> '1100' OR gv_cockpit_embedded <> abap_true.
    lcl_qm=>check_stock( ).
  ENDIF.

AT SELECTION-SCREEN.
  IF sy-dynnr = '1100' AND gv_cockpit_embedded = abap_true
     AND sscrfields-ucomm = gc_cockpit_run.
    gv_cockpit_run_requested = abap_true.
    CLEAR sscrfields-ucomm.
  ENDIF.

AT SELECTION-SCREEN OUTPUT.
  IF sy-dynnr = '1100' AND gv_cockpit_embedded = abap_true.
    pb_qrun = 'QM indítása'(101).
    p_stock = gv_cockpit_stock.
    LOOP AT SCREEN.
      IF screen-name = 'P_STOCK'.
        screen-input = 0.
        MODIFY SCREEN.
      ENDIF.
    ENDLOOP.
  ENDIF.
  IF sy-dynnr EQ '2000'.
    lcl_qm=>pbo_2000( ).
  ENDIF.

AT SELECTION-SCREEN ON EXIT-COMMAND.
  IF sy-dynnr EQ '2000'.
    lcl_qm=>on_exit_2000( ).
  ENDIF.

START-OF-SELECTION.
  lcl_qm=>start( ).