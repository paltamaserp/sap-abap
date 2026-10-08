REPORT zpr_dcqm_exclude MESSAGE-ID zpr.

*&---------------------------------------------------------------------*
*& Report ZPR_DCQM_EXCLUDE
*---------------------------------------------------------------*
* Rövid leírás: DC adatellenőrzés - nyomtatási sorok kizárása /
*               megjelenítése (QU5 ZEBF_PR_DCQM_REPORT átvétele)
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
* 2026.10.08.   <USER>        DC kizárás - QU5 ZEBF_PR_DCQM_REPORT
*                             átvétele
*---------------------------------------------------------------*
* Hívás:
*   - ZPR_DC_FRAME (tranzakció ZPR_DC): SUBMIT ... WITH p_modif
*   - tranzakció ZPR_DCQM_DISP: mindig csak megjelenítés
*
* Függőségek (aktívnak kell lenniük):
*   ZPRS_DCQM_REPORT, ZPRT_DCQMLT, ZPRC_DCCODE (benne a 'ZZ' kód),
*   EZPRT_STOCK zárobjektum, ZPR üzenetek, SLG0 ZPR_MASS / DC,
*   0100-as képernyő (ZPR_DCQM_EXCLUDE_0100_flow.abap),
*   GUI-státuszok STAT_0100, STAT_0100_DISP, címsorok TITLE_0100_MOD,
*   TITLE_0100_DISP.
*
* Szövegelemek:
*   TEXT-001 Szelekció             TEXT-002 Megjelenítés
*   A többi szövegszimbólum literál-alapértékkel szerepel a kódban
*   ('...'(xxx)), SE38 -> Szövegelemek -> "Összehasonlítás" felveszi.
*   Szelekciós szövegek: Szótár-hivatkozás, kivéve P_VARI = Layout.
*---------------------------------------------------------------*

TABLES: zprt_dcqm.

*---------------------------------------------------------------*
* Típusok
*---------------------------------------------------------------*
TYPES: BEGIN OF ty_envelope,
         envelope      TYPE zprd_envelope_id,
         block_dc_text TYPE zprd_pr_block_dc_text,
       END OF ty_envelope,
       tt_envelope  TYPE SORTED TABLE OF ty_envelope
                    WITH UNIQUE KEY envelope,
       tt_row_index TYPE SORTED TABLE OF sytabix
                    WITH UNIQUE KEY table_line,
       BEGIN OF ty_docno,
         doc_no TYPE zprd_doc_no,
       END OF ty_docno,
       tt_docno     TYPE STANDARD TABLE OF ty_docno WITH DEFAULT KEY.

*----------------------------------------------------------------------*
* Esemény kezelő - ALV Grid 01, Screen 0100
*----------------------------------------------------------------------*
CLASS gcl_alv_grid_01_event_receiver DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      on_alv_toolbar
                    FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,
      on_alv_user_command
                    FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm,
      handle_data_changed
                    FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING er_data_changed,
      handle_data_changed_finished
                    FOR EVENT data_changed_finished OF cl_gui_alv_grid
        IMPORTING e_modified et_good_cells,
      is_dc_code_valid
        IMPORTING iv_block_dc     TYPE zprd_pr_block_dc
        RETURNING VALUE(rv_valid) TYPE abap_bool.

  PRIVATE SECTION.
    CLASS-METHODS:
      exclude_selected,
      release_selected,
      get_selected_rows
        RETURNING VALUE(rt_rows) TYPE lvc_t_row,
      get_exclusion_values
        EXPORTING ev_block_dc      TYPE zprd_pr_block_dc
                  ev_block_dc_text TYPE zprd_pr_block_dc_text
                  ev_cancelled     TYPE abap_bool,
      exclude_envelope_partners
        IMPORTING it_envelope     TYPE tt_envelope
        RETURNING VALUE(rv_count) TYPE i,
      release_envelopes
        IMPORTING it_envelope  TYPE tt_envelope
                  it_keep_rows TYPE tt_row_index,
      refresh_grid.

ENDCLASS.                    "gcl_alv_grid_01_event_receiver DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_layout_f4 DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_layout_f4 DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      for_salv
        CHANGING cv_layout TYPE disvariant-variant.
ENDCLASS.                    "lcl_layout_f4 DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_layout_f4 IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_layout_f4 IMPLEMENTATION.
  METHOD for_salv.

    DATA: ls_layout TYPE salv_s_layout_info,
          ls_key    TYPE salv_s_layout_key.

    ls_key-report = sy-repid.

    ls_layout = cl_salv_layout_service=>f4_layouts(
                  s_key    = ls_key
                  restrict = if_salv_c_layout=>restrict_none ).

    cv_layout = ls_layout-layout.

  ENDMETHOD.                    "for_salv
ENDCLASS.                    "lcl_layout_f4 IMPLEMENTATION

*---------------------------------------------------------------*
* Konstansok
*---------------------------------------------------------------*
* Üzenetek (ZPR)
* DC üzenetek: ZPR 045-066; az általános üzenet ZPR 000.
* A DC üzeneteket a riport használata előtt SE91-ben fel kell venni.
* Az üzenetszámok a 2026.10.08-i DHC-export alapján szabadok.
* Általános üzenet: ZPR 000 = '& & & &' (négy helyettesítő).
CONSTANTS:
  gc_msgid TYPE symsgid VALUE 'ZPR',
  BEGIN OF gc_msgno,
    generic         TYPE symsgno VALUE '000', "& & & &
    stock_not_found TYPE symsgno VALUE '045', "A Stock ID nem létezik!
    stock_closed    TYPE symsgno VALUE '046', "A stock lezárt, csak megjelenítés lehetséges
    no_row_selected TYPE symsgno VALUE '047', "Nincs kijelölt sor
    save_ok         TYPE symsgno VALUE '048', "Mentés sikeres
    save_failed     TYPE symsgno VALUE '049', "Mentés sikertelen
    row_excluded    TYPE symsgno VALUE '058', "&1 kizárva: &2 &3
    row_released    TYPE symsgno VALUE '059', "&1 kizárása visszavonva
    dc_code_unknown TYPE symsgno VALUE '060', "DC zárolás kód &1 nem létezik.
    dc_text_no_code TYPE symsgno VALUE '061', "DC zárolási szöveghez DC zárolási kódot is meg kell adni!
    dc_completed    TYPE symsgno VALUE '062', "DC kész, a stock nem módosítható
    no_data         TYPE symsgno VALUE '063', "A &1 stockhoz nincs adat
    sel_extended    TYPE symsgno VALUE '064', "A szelekció kibővült az azonos borítékba kerülő nyomtatványokkal.
    amount_no_curr  TYPE symsgno VALUE '065', "Ha megadott összeget, akkor adjon meg pénznemet is.
    excluded_count  TYPE symsgno VALUE '066', "A kizárt rekordok száma: &1.
  END OF gc_msgno.

* Alkalmazásnapló
CONSTANTS: gc_log_object TYPE balobj_d  VALUE 'ZPR_MASS',
           gc_log_subobj TYPE balsubobj VALUE 'DC'.

* Borítéktársak automatikus kizárási kódja - a ZPRC_DCCODE-ban léteznie kell!
CONSTANTS: gc_block_dc_envelope TYPE zprd_pr_block_dc VALUE 'ZZ'.

* Funkciókódok, tranzakció
CONSTANTS: gc_ucomm_exclude TYPE syucomm VALUE 'KIZAR',
           gc_ucomm_release TYPE syucomm VALUE 'KIZVISSZ',
           gc_ucomm_save    TYPE syucomm VALUE 'SAVE',
           gc_tcode_disp    TYPE sytcode VALUE 'ZPR_DCQM_DISP'.

*---------------------------------------------------------------*
* Globális adatok
*---------------------------------------------------------------*
DATA:
* Képernyő OK-kódok
  gv_okcode_0100      TYPE syucomm.
DATA:
* Custom container és ALV Grid - Screen 0100
  go_alv_grid_cont_01 TYPE REF TO cl_gui_custom_container,
  go_alv_grid_01      TYPE REF TO cl_gui_alv_grid.
DATA:
* ALV táblák; az eredeti példány a változásfigyeléshez
* ⚠️ A DOC_NO egyediségét feltételezzük (ZPRT_DCQM kulcs)
  gt_0100_alv  TYPE STANDARD TABLE OF zprs_dcqm_report,
  gt_0100_orig TYPE SORTED TABLE OF zprs_dcqm_report
               WITH NON-UNIQUE KEY doc_no.

DATA: gv_modif        TYPE flag,          "effektív mód
      gv_changed      TYPE flag,
      gv_locked_stock TYPE zprd_stock_id, "saját sikeres zárolás
      gv_dummy        TYPE string.

* LOG
DATA: go_log TYPE REF TO zcl_pr_log.

* Belső szelekciós tartományok - minden futáskor újraépülnek
DATA: gr_amnt  TYPE RANGE OF zprt_dcqm-amnt,
      gr_waers TYPE RANGE OF zprt_dcqm-waers.

*---------------------------------------------------------------*
* Szelekciós feltételek
*---------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
SELECTION-SCREEN SKIP.
PARAMETERS: p_stokid TYPE zprd_stock_id OBLIGATORY,
            p_modif  TYPE flag NO-DISPLAY.
SELECTION-SCREEN SKIP.
SELECT-OPTIONS:
  so_docno FOR zprt_dcqm-doc_no,
  so_envlo FOR zprt_dcqm-envelope,
  so_pymet FOR zprt_dcqm-pymet,
  so_dcat  FOR zprt_dcqm-doc_cat,
  so_amnt  FOR zprt_dcqm-amnt.
PARAMETERS p_waers TYPE waers.
SELECT-OPTIONS:
  so_dued  FOR zprt_dcqm-duedate,
  so_bkacc FOR zprt_dcqm-bankaccountnum,
  so_giro  FOR zprt_dcqm-giro,
  so_name  FOR zprt_dcqm-name1,
  so_sysid FOR zprt_dcqm-sysid,
  so_land1 FOR zprt_dcqm-land1,
  so_ab    FOR zprt_dcqm-ab,
  so_bis   FOR zprt_dcqm-bis,
  so_tarif FOR zprt_dcqm-tariftyp,
  so_aklas FOR zprt_dcqm-aklasse,
  so_mahns FOR zprt_dcqm-mahns,
  so_mahnv FOR zprt_dcqm-mahnv,
  so_zbizc FOR zprt_dcqm-zbizcat,
  so_cotyp FOR zprt_dcqm-cotyp,
  so_form  FOR zprt_dcqm-form,
  so_pckid FOR zprt_dcqm-package_id,
  so_aktyp FOR zprt_dcqm-aktyp,
  so_laufd FOR zprt_dcqm-laufd,
  so_laufi FOR zprt_dcqm-laufi,
  so_blodc FOR zprt_dcqm-block_dc,
  so_bloqm FOR zprt_dcqm-block_qm,
  so_regmn FOR zprt_dcqm-regmailnumber.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-002.
PARAMETERS:
  p_vari TYPE slis_vari. "LAYOUT
SELECTION-SCREEN END OF BLOCK b02.

*----------------------------------------------------------------------*
* AT SELECTION-SCREEN                                                  *
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.

  IF p_stokid IS NOT INITIAL.
    PERFORM check_stockid.
  ENDIF.

  IF so_amnt[] IS NOT INITIAL AND p_waers IS INITIAL.
    MESSAGE ID gc_msgid TYPE 'E' NUMBER gc_msgno-amount_no_curr.
*   Ha megadott összeget, akkor adjon meg pénznemet is.
  ENDIF.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_vari.
  lcl_layout_f4=>for_salv( CHANGING cv_layout = p_vari ).

*----------------------------------------------------------------------*
* START-OF-SELECTION                                                   *
*----------------------------------------------------------------------*
START-OF-SELECTION.

* Előző futás maradványainak törlése (visszalépés + újrafuttatás)
  PERFORM init_run.

* Összeg- és pénznemszűrés belső tartományai
  PERFORM build_ranges.

* Effektív mód
  IF sy-tcode EQ gc_tcode_disp.
    gv_modif = abap_false.
  ELSE.
    gv_modif = p_modif.
  ENDIF.

* Módosító módban: zárolás + friss stockállapot
  PERFORM lock_and_check_stock.

* Adatszelekció
  PERFORM select_data.

  IF gt_0100_alv IS INITIAL.
    PERFORM unlock_stock.
    MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-no_data WITH p_stokid.
*   A &1 stockhoz nincs adat
    LEAVE LIST-PROCESSING.
  ENDIF.

*----------------------------------------------------------------------*
* END-OF-SELECTION                                                     *
*----------------------------------------------------------------------*
END-OF-SELECTION.

  PERFORM display_alv.


INCLUDE zpr_dcqm_exclude_o01.

INCLUDE zpr_dcqm_exclude_i01.

*&---------------------------------------------------------------------*
*&      Form  INIT_RUN
*&---------------------------------------------------------------------*
*       Globális állapot alaphelyzetbe
*----------------------------------------------------------------------*
FORM init_run .

  PERFORM unlock_stock.

  REFRESH: gt_0100_alv,
           gt_0100_orig,
           gr_amnt,
           gr_waers.
  CLEAR: gv_modif,
         gv_changed.
  FREE go_log.

ENDFORM.                    " INIT_RUN
*&---------------------------------------------------------------------*
*&      Form  BUILD_RANGES
*&---------------------------------------------------------------------*
*       Összeg tizedes-korrekció és pénznem-tartomány. A szelekciós
*       mezőt nem módosítjuk, csak a másolatát.
*----------------------------------------------------------------------*
FORM build_ranges .

  DATA: lv_ddic_dec TYPE i,
        lv_faktor   TYPE i,
        ls_tcurx    TYPE tcurx,
        ls_amnt     LIKE LINE OF gr_amnt,
        ls_waers    LIKE LINE OF gr_waers.

* A CURR mező belső értéke a DDIC tizedesjegyein alapul (AMNT: 2), a
* pénznem tényleges tizedesjegye a TCURX-ben van (pl. HUF: 0).
* A beírt összeget ennek megfelelően kell átváltani a belső formára.
  DESCRIBE FIELD zprt_dcqm-amnt DECIMALS lv_ddic_dec.

  IF p_waers IS NOT INITIAL.
    SELECT SINGLE * FROM tcurx
      INTO @ls_tcurx
      WHERE currkey = @p_waers.
  ENDIF.
  IF p_waers IS INITIAL OR sy-subrc <> 0.
    ls_tcurx-currdec = lv_ddic_dec.
  ENDIF.
  lv_faktor = lv_ddic_dec - ls_tcurx-currdec.

  LOOP AT so_amnt INTO ls_amnt.
    ls_amnt-low  = ls_amnt-low  / ( 10 ** lv_faktor ).
    ls_amnt-high = ls_amnt-high / ( 10 ** lv_faktor ).
    APPEND ls_amnt TO gr_amnt.
  ENDLOOP.

  IF p_waers IS NOT INITIAL.
    CLEAR ls_waers.
    ls_waers-sign   = 'I'.
    ls_waers-option = 'EQ'.
    ls_waers-low    = p_waers.
    APPEND ls_waers TO gr_waers.
  ENDIF.

ENDFORM.                    " BUILD_RANGES
*&---------------------------------------------------------------------*
*&      Form  CHECK_STOCKID
*&---------------------------------------------------------------------*
*       Szelekciós képernyő: létezik-e a stock. A lezárt / DC kész
*       állapotot a zárolás után, frissen vizsgáljuk.
*----------------------------------------------------------------------*
FORM check_stockid .

  DATA: lv_stock_id TYPE zprd_stock_id.

  SELECT SINGLE stock_id FROM zprt_stock
    INTO @lv_stock_id
    WHERE stock_id = @p_stokid.
  IF sy-subrc NE 0.
    MESSAGE ID gc_msgid TYPE 'E' NUMBER gc_msgno-stock_not_found.
*   A Stock ID nem létezik!
  ENDIF.

ENDFORM.                    " CHECK_STOCKID
*&---------------------------------------------------------------------*
*&      Form  LOCK_AND_CHECK_STOCK
*&---------------------------------------------------------------------*
*       Módosító módban a stock zárolása, majd a stock aktuális
*       állapotának újraolvasása. Lezárt vagy DC kész stock
*       esetén megjelenítő módra vált és a zárat feloldja.
*----------------------------------------------------------------------*
FORM lock_and_check_stock .

  DATA: ls_stock TYPE zprt_stock.

  CHECK gv_modif EQ abap_true.

* _SCOPE = 1: a zár a dialógusé, COMMIT WORK nem oldja fel;
* feloldás: UNLOCK_STOCK (ALV elhagyása, nincs adat, programvége)
  CALL FUNCTION 'ENQUEUE_EZPRT_STOCK'
    EXPORTING
      stock_id       = p_stokid
      _scope         = '1'
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE 'I' NUMBER sy-msgno DISPLAY LIKE 'E'
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    LEAVE LIST-PROCESSING.
  ENDIF.
  gv_locked_stock = p_stokid.

* Friss állapot a zár megszerzése után
  SELECT SINGLE * FROM zprt_stock BYPASSING BUFFER
    INTO @ls_stock
    WHERE stock_id = @p_stokid.
  IF sy-subrc <> 0.
    PERFORM unlock_stock.
    MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-stock_not_found
            DISPLAY LIKE 'E'.
*   A Stock ID nem létezik!
    LEAVE LIST-PROCESSING.
  ENDIF.

  IF ls_stock-closed EQ abap_true.
    PERFORM unlock_stock.
    gv_modif = abap_false.
    MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-stock_closed.
*   A stock lezárt, csak megjelenítés lehetséges
  ELSEIF ls_stock-dccompl EQ abap_true.
    PERFORM unlock_stock.
    gv_modif = abap_false.
    MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-dc_completed.
*   DC kész, a stock nem módosítható
  ENDIF.

ENDFORM.                    " LOCK_AND_CHECK_STOCK
*&---------------------------------------------------------------------*
*&      Form  UNLOCK_STOCK
*&---------------------------------------------------------------------*
*       Csak a saját, sikeres zárolást oldja fel
*----------------------------------------------------------------------*
FORM unlock_stock .

  CHECK gv_locked_stock IS NOT INITIAL.

  CALL FUNCTION 'DEQUEUE_EZPRT_STOCK'
    EXPORTING
      stock_id = gv_locked_stock
      _scope   = '1'.

  CLEAR gv_locked_stock.

ENDFORM.                    " UNLOCK_STOCK
*&---------------------------------------------------------------------*
*&      Form  SELECT_DATA
*&---------------------------------------------------------------------*
*       A stock sorai a szelekció szerint + borítékbővítés + hosszú
*       szöveg + számláló
*----------------------------------------------------------------------*
FORM select_data .

  DATA: lt_env      TYPE tt_envelope,
        ls_env      TYPE ty_envelope,
        lt_env_plus TYPE STANDARD TABLE OF zprs_dcqm_report,
        lt_plus     TYPE STANDARD TABLE OF zprs_dcqm_report,
        lt_docno    TYPE tt_docno,
        ls_docno    TYPE ty_docno,
        lt_dcqmlt   TYPE SORTED TABLE OF zprt_dcqmlt
                    WITH UNIQUE KEY exbilldocno,
        ls_dcqmlt   TYPE zprt_dcqmlt,
        lv_plus_lines TYPE i.
  FIELD-SYMBOLS: <ls_alv>  TYPE zprs_dcqm_report,
                 <ls_plus> TYPE zprs_dcqm_report.

* 1) A stock sorai a szelekció szerint
  SELECT * FROM zprt_dcqm
    INTO CORRESPONDING FIELDS OF TABLE @gt_0100_alv
    WHERE prd_stock_id       =  @p_stokid
      AND doc_no         IN @so_docno
      AND envelope       IN @so_envlo
      AND pymet          IN @so_pymet
      AND doc_cat        IN @so_dcat
      AND amnt           IN @gr_amnt
      AND waers          IN @gr_waers
      AND duedate        IN @so_dued
      AND bankaccountnum IN @so_bkacc
      AND giro           IN @so_giro
      AND name1          IN @so_name
      AND sysid          IN @so_sysid
      AND land1          IN @so_land1
      AND ab             IN @so_ab
      AND bis            IN @so_bis
      AND tariftyp       IN @so_tarif
      AND aklasse        IN @so_aklas
      AND mahns          IN @so_mahns
      AND mahnv          IN @so_mahnv
      AND zbizcat        IN @so_zbizc
      AND cotyp          IN @so_cotyp
      AND form           IN @so_form
      AND package_id     IN @so_pckid
      AND aktyp          IN @so_aktyp
      AND laufd          IN @so_laufd
      AND laufi          IN @so_laufi
      AND block_dc       IN @so_blodc
      AND block_qm       IN @so_bloqm
      AND regmailnumber  IN @so_regmn.

  CHECK gt_0100_alv IS NOT INITIAL.

* 2) Borítékbővítés: a talált borítékok összes sora (azonos stock).
*    Üres boríték nem csoportosít.
  LOOP AT gt_0100_alv ASSIGNING <ls_alv> WHERE envelope IS NOT INITIAL.
    ls_env-envelope = <ls_alv>-envelope.
    INSERT ls_env INTO TABLE lt_env.
  ENDLOOP.

  IF lt_env IS NOT INITIAL.
    SELECT * FROM zprt_dcqm
      INTO CORRESPONDING FIELDS OF TABLE @lt_env_plus
      FOR ALL ENTRIES IN @lt_env
      WHERE prd_stock_id = @p_stokid
        AND envelope = @lt_env-envelope.
  ENDIF.

  SORT gt_0100_alv BY doc_no.
  LOOP AT lt_env_plus ASSIGNING <ls_plus>.
    READ TABLE gt_0100_alv TRANSPORTING NO FIELDS
      WITH KEY doc_no = <ls_plus>-doc_no
      BINARY SEARCH.
    IF sy-subrc NE 0.
      APPEND <ls_plus> TO lt_plus.
    ENDIF.
  ENDLOOP.
  lv_plus_lines = lines( lt_plus ).
  APPEND LINES OF lt_plus TO gt_0100_alv.

* 3) Hosszú szövegek + számláló oszlop
  LOOP AT gt_0100_alv ASSIGNING <ls_alv>.
    ls_docno-doc_no = <ls_alv>-doc_no.
    APPEND ls_docno TO lt_docno.
  ENDLOOP.

  SELECT * FROM zprt_dcqmlt
    INTO TABLE @lt_dcqmlt
    FOR ALL ENTRIES IN @lt_docno
    WHERE exbilldocno = @lt_docno-doc_no.

  LOOP AT gt_0100_alv ASSIGNING <ls_alv>.
    READ TABLE lt_dcqmlt INTO ls_dcqmlt
      WITH TABLE KEY exbilldocno = <ls_alv>-doc_no.
    IF sy-subrc EQ 0.
      <ls_alv>-block_dc_text = ls_dcqmlt-block_dc_text.
      <ls_alv>-block_qm_text = ls_dcqmlt-block_qm_text.
    ENDIF.
    <ls_alv>-counter = 1.
  ENDLOOP.

* 4) Rendezés, eredeti példány, tájékoztatás
  SORT gt_0100_alv BY envelope doc_no.
  gt_0100_orig = gt_0100_alv.

  IF lv_plus_lines GT 0.
    MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-sel_extended.
*   A szelekció kibővült az azonos borítékba kerülő nyomtatványokkal.
  ENDIF.

ENDFORM.                    " SELECT_DATA
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv .

  CALL SCREEN '0100'.

ENDFORM.                    " DISPLAY_ALV
*----------------------------------------------------------------------*
*       CLASS gcl_alv_grid_01_event_receiver IMPLEMENTATION
*----------------------------------------------------------------------*
* Borítékszabályok - a popupos és a cellás út ugyanígy működik:
*  - Kizárás: a sor a megadott kódot kapja; a boríték MÉG NEM KIZÁRT
*    sorai 'ZZ'-t és a kizárás szövegét kapják. A már meglévő saját
*    kizárási okot nem írjuk felül.
*  - Visszavonás: a teljes boríték visszavonódik (kód + szöveg), mert
*    hiányos boríték nem mehet ki.
*  - Szöveg cellás módosítása: csak a saját (nem 'ZZ') kódú sor szövege
*    öröklődik a boríték 'ZZ' soraira.
*  - Üres ENVELOPE nem csoportosít: csak maga a sor változik.
*  - Egy lépésben több cella: először a visszavonások, majd a kizárások
*    futnak; borítékonként a legkisebb sorindexű forrás érvényes.
*----------------------------------------------------------------------*
CLASS gcl_alv_grid_01_event_receiver IMPLEMENTATION.

  METHOD on_alv_user_command.

    CHECK gv_modif EQ abap_true.

    CASE e_ucomm.
      WHEN gc_ucomm_exclude.
        exclude_selected( ).
      WHEN gc_ucomm_release.
        release_selected( ).
    ENDCASE.

  ENDMETHOD.                    "on_alv_user_command

  METHOD on_alv_toolbar.

    DATA: ls_toolbar TYPE stb_button.

*   Standard gombok letiltása
    DELETE e_object->mt_toolbar
      WHERE function = cl_gui_alv_grid=>mc_mb_view
         OR function = cl_gui_alv_grid=>mc_fc_detail
         OR function = cl_gui_alv_grid=>mc_fc_loc_append_row
         OR function = cl_gui_alv_grid=>mc_fc_loc_copy_row
         OR function = cl_gui_alv_grid=>mc_fc_loc_delete_row
         OR function = cl_gui_alv_grid=>mc_fc_loc_insert_row
         OR function = cl_gui_alv_grid=>mc_fc_graph
         OR function = cl_gui_alv_grid=>mc_fc_info
         OR function = cl_gui_alv_grid=>mc_fc_refresh
         OR function = cl_gui_alv_grid=>mc_fc_loc_undo
         OR function = cl_gui_alv_grid=>mc_fc_loc_copy
         OR function = cl_gui_alv_grid=>mc_fc_loc_cut
         OR function = cl_gui_alv_grid=>mc_fc_loc_paste.

    CHECK gv_modif EQ abap_true.

*   Szeparátor
    CLEAR ls_toolbar.
    ls_toolbar-butn_type = 3.
    APPEND ls_toolbar TO e_object->mt_toolbar.

    CLEAR ls_toolbar.
    ls_toolbar-function  = gc_ucomm_exclude.
    ls_toolbar-icon      = icon_locked.
    ls_toolbar-quickinfo = 'Kizárás'(b01).
    ls_toolbar-text      = 'Kizárás'(b01).
    APPEND ls_toolbar TO e_object->mt_toolbar.

    CLEAR ls_toolbar.
    ls_toolbar-function  = gc_ucomm_release.
    ls_toolbar-icon      = icon_unlocked.
    ls_toolbar-quickinfo = 'Kizárás visszavétele'(b02).
    ls_toolbar-text      = 'Kizárás vissza'(b03).
    APPEND ls_toolbar TO e_object->mt_toolbar.

  ENDMETHOD.                    "on_alv_toolbar

  METHOD handle_data_changed.
*   Csak érvényesítés: hibás DC-kódnál hibaprotokoll, az érték nem kerül
*   át a táblába, és a borítéktársakon sincs mellékhatás.

    DATA: ls_mod_cell TYPE lvc_s_modi,
          lv_block_dc TYPE zprd_pr_block_dc.

    LOOP AT er_data_changed->mt_mod_cells INTO ls_mod_cell
      WHERE fieldname = 'BLOCK_DC'.

      CALL METHOD er_data_changed->get_cell_value
        EXPORTING
          i_row_id    = ls_mod_cell-row_id
          i_fieldname = ls_mod_cell-fieldname
        IMPORTING
          e_value     = lv_block_dc.

      IF lv_block_dc IS NOT INITIAL
         AND is_dc_code_valid( lv_block_dc ) EQ abap_false.
        CALL METHOD er_data_changed->add_protocol_entry
          EXPORTING
            i_msgid     = gc_msgid
            i_msgty     = 'E'
            i_msgno     = gc_msgno-dc_code_unknown
            i_msgv1     = lv_block_dc
            i_fieldname = ls_mod_cell-fieldname
            i_row_id    = ls_mod_cell-row_id.
*       DC zárolás kód &1 nem létezik.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.                    "handle_data_changed

  METHOD handle_data_changed_finished.
*   Az érvényes cellák már a táblában vannak - borítékszabályok

    DATA: lt_cells     TYPE lvc_t_modi,
          ls_cell      TYPE lvc_s_modi,
          lt_release   TYPE tt_envelope,
          lt_exclude   TYPE tt_envelope,
          lt_text      TYPE tt_envelope,
          ls_envelope  TYPE ty_envelope,
          lt_keep_rows TYPE tt_row_index.
    FIELD-SYMBOLS: <ls_src> TYPE zprs_dcqm_report,
                   <ls_alv> TYPE zprs_dcqm_report.

    CHECK e_modified EQ abap_true.

*   Sorrendfüggetlen feldolgozás
    lt_cells = et_good_cells.
    SORT lt_cells BY row_id fieldname.

    LOOP AT lt_cells INTO ls_cell.

      READ TABLE gt_0100_alv ASSIGNING <ls_src> INDEX ls_cell-row_id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      CASE ls_cell-fieldname.
        WHEN 'BLOCK_DC'.
          IF <ls_src>-block_dc IS INITIAL.
*           Visszavonás: a sor szövege is törlődik
            CLEAR <ls_src>-block_dc_text.
            IF <ls_src>-envelope IS NOT INITIAL.
              CLEAR ls_envelope.
              ls_envelope-envelope = <ls_src>-envelope.
              INSERT ls_envelope INTO TABLE lt_release.
            ENDIF.
          ELSE.
*           Kizárás: ez a sor a visszavonásnál is megtartja a kódját
            INSERT ls_cell-row_id INTO TABLE lt_keep_rows.
            IF <ls_src>-envelope IS NOT INITIAL.
              ls_envelope-envelope      = <ls_src>-envelope.
              ls_envelope-block_dc_text = <ls_src>-block_dc_text.
              INSERT ls_envelope INTO TABLE lt_exclude.
            ENDIF.
          ENDIF.

        WHEN 'BLOCK_DC_TEXT'.
          IF <ls_src>-envelope IS NOT INITIAL
             AND <ls_src>-block_dc IS NOT INITIAL
             AND <ls_src>-block_dc NE gc_block_dc_envelope.
            ls_envelope-envelope      = <ls_src>-envelope.
            ls_envelope-block_dc_text = <ls_src>-block_dc_text.
            INSERT ls_envelope INTO TABLE lt_text.
          ENDIF.
      ENDCASE.

    ENDLOOP.

    IF lt_release IS NOT INITIAL.
      release_envelopes( it_envelope  = lt_release
                         it_keep_rows = lt_keep_rows ).
    ENDIF.

    IF lt_exclude IS NOT INITIAL.
      exclude_envelope_partners( lt_exclude ).
    ENDIF.

    IF lt_text IS NOT INITIAL.
      LOOP AT gt_0100_alv ASSIGNING <ls_alv>
        WHERE block_dc = gc_block_dc_envelope.
        READ TABLE lt_text INTO ls_envelope
          WITH TABLE KEY envelope = <ls_alv>-envelope.
        IF sy-subrc EQ 0.
          <ls_alv>-block_dc_text = ls_envelope-block_dc_text.
        ENDIF.
      ENDLOOP.
    ENDIF.

    refresh_grid( ).

  ENDMETHOD.                    "handle_data_changed_finished

  METHOD exclude_selected.

    DATA: lt_rows          TYPE lvc_t_row,
          ls_row           TYPE lvc_s_row,
          lt_envelope      TYPE tt_envelope,
          ls_envelope      TYPE ty_envelope,
          lv_block_dc      TYPE zprd_pr_block_dc,
          lv_block_dc_text TYPE zprd_pr_block_dc_text,
          lv_cancelled     TYPE abap_bool,
          lv_count         TYPE i,
          lv_partners      TYPE i.
    FIELD-SYMBOLS: <ls_alv> TYPE zprs_dcqm_report.

    lt_rows = get_selected_rows( ).
    IF lt_rows IS INITIAL.
      MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-no_row_selected.
*     Nincs kijelölt sor
      RETURN.
    ENDIF.

    get_exclusion_values( IMPORTING ev_block_dc      = lv_block_dc
                                    ev_block_dc_text = lv_block_dc_text
                                    ev_cancelled     = lv_cancelled ).
    IF lv_cancelled EQ abap_true.
      RETURN.
    ENDIF.

    LOOP AT lt_rows INTO ls_row.
      READ TABLE gt_0100_alv ASSIGNING <ls_alv> INDEX ls_row-index.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      <ls_alv>-block_dc      = lv_block_dc.
      <ls_alv>-block_dc_text = lv_block_dc_text.
      lv_count = lv_count + 1.

*     Csak a társak keresését védi; a kijelölt sor maga mindig változik
      IF <ls_alv>-envelope IS NOT INITIAL.
        ls_envelope-envelope      = <ls_alv>-envelope.
        ls_envelope-block_dc_text = lv_block_dc_text.
        INSERT ls_envelope INTO TABLE lt_envelope.
      ENDIF.
    ENDLOOP.

    lv_partners = exclude_envelope_partners( lt_envelope ).
    lv_count = lv_count + lv_partners.

    MESSAGE ID gc_msgid TYPE 'S' NUMBER gc_msgno-excluded_count
            WITH lv_count.
*   A kizárt rekordok száma: &1.

    refresh_grid( ).

  ENDMETHOD.                    "exclude_selected

  METHOD release_selected.

    DATA: lt_rows      TYPE lvc_t_row,
          ls_row       TYPE lvc_s_row,
          lt_envelope  TYPE tt_envelope,
          ls_envelope  TYPE ty_envelope,
          lt_keep_rows TYPE tt_row_index.
    FIELD-SYMBOLS: <ls_alv> TYPE zprs_dcqm_report.

    lt_rows = get_selected_rows( ).
    IF lt_rows IS INITIAL.
      MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-no_row_selected.
*     Nincs kijelölt sor
      RETURN.
    ENDIF.

    LOOP AT lt_rows INTO ls_row.
      READ TABLE gt_0100_alv ASSIGNING <ls_alv> INDEX ls_row-index.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      CLEAR: <ls_alv>-block_dc,
             <ls_alv>-block_dc_text.

*     Üres boríték: csak a kijelölt sor változik
      IF <ls_alv>-envelope IS NOT INITIAL.
        CLEAR ls_envelope.
        ls_envelope-envelope = <ls_alv>-envelope.
        INSERT ls_envelope INTO TABLE lt_envelope.
      ENDIF.
    ENDLOOP.

    IF lt_envelope IS NOT INITIAL.
      release_envelopes( it_envelope  = lt_envelope
                         it_keep_rows = lt_keep_rows ).
    ENDIF.

    refresh_grid( ).

  ENDMETHOD.                    "release_selected

  METHOD get_selected_rows.

    CALL METHOD go_alv_grid_01->get_selected_rows
      IMPORTING
        et_index_rows = rt_rows.

*   Összeg- és részösszegsorok nem dokumentumok
    DELETE rt_rows WHERE rowtype IS NOT INITIAL.

  ENDMETHOD.                    "get_selected_rows

  METHOD get_exclusion_values.

    DATA: lt_sval TYPE STANDARD TABLE OF sval,
          ls_sval TYPE sval,
          lv_ret  TYPE char1.

    CLEAR: ev_block_dc,
           ev_block_dc_text.
    ev_cancelled = abap_true.

*   A ZPRS_DCQM_REPORT-BLOCK_DC idegen kulcsa (ZPRC_DCCODE) adja az F4-et
    CLEAR ls_sval.
    ls_sval-tabname    = 'ZPRS_DCQM_REPORT'.
    ls_sval-fieldname  = 'BLOCK_DC'.
    ls_sval-fieldtext  = 'Hibakód'(p01).
    ls_sval-field_obl  = abap_true.
    ls_sval-comp_tab   = 'ZPRC_DCCODE'.
    ls_sval-comp_field = 'BLOCK_DC'.
    APPEND ls_sval TO lt_sval.

    CLEAR ls_sval.
    ls_sval-tabname   = 'ZPRT_DCQMLT'.
    ls_sval-fieldname = 'BLOCK_DC_TEXT'.
    ls_sval-fieldtext = 'Leírás'(p02).
    APPEND ls_sval TO lt_sval.

    CALL FUNCTION 'POPUP_GET_VALUES_USER_CHECKED'
      EXPORTING
        formname        = 'CHECK_ENTERED_DATA_POPUP'
        programname     = 'ZPR_DCQM_EXCLUDE'
        popup_title     = 'Kérem, adja meg a kizárás paramétereit:'(p03)
        start_column    = '12'
        start_row       = '8'
      IMPORTING
        returncode      = lv_ret
      TABLES
        fields          = lt_sval
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'I' NUMBER sy-msgno DISPLAY LIKE 'E'
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      RETURN.
    ENDIF.
    IF lv_ret EQ 'A'. "Megszakítva
      RETURN.
    ENDIF.

    LOOP AT lt_sval INTO ls_sval.
      CASE ls_sval-fieldname.
        WHEN 'BLOCK_DC'.
          ev_block_dc = ls_sval-value.
        WHEN 'BLOCK_DC_TEXT'.
          ev_block_dc_text = ls_sval-value.
      ENDCASE.
    ENDLOOP.
    ev_cancelled = abap_false.

  ENDMETHOD.                    "get_exclusion_values

  METHOD exclude_envelope_partners.
*   A borítékok még nem kizárt sorai 'ZZ'-t kapnak (meglévő okot nem írunk felül)

    DATA: ls_envelope TYPE ty_envelope.
    FIELD-SYMBOLS: <ls_alv> TYPE zprs_dcqm_report.

    CHECK it_envelope IS NOT INITIAL.

    LOOP AT gt_0100_alv ASSIGNING <ls_alv>
      WHERE block_dc IS INITIAL
        AND envelope IS NOT INITIAL.
      READ TABLE it_envelope INTO ls_envelope
        WITH TABLE KEY envelope = <ls_alv>-envelope.
      IF sy-subrc EQ 0.
        <ls_alv>-block_dc      = gc_block_dc_envelope.
        <ls_alv>-block_dc_text = ls_envelope-block_dc_text.
        rv_count = rv_count + 1.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.                    "exclude_envelope_partners

  METHOD release_envelopes.
*   A borítékok összes sorának visszavonása, kivéve a megtartandó sorokat

    DATA: lv_tabix TYPE sytabix.
    FIELD-SYMBOLS: <ls_alv> TYPE zprs_dcqm_report.

    LOOP AT gt_0100_alv ASSIGNING <ls_alv> WHERE envelope IS NOT INITIAL.
      lv_tabix = sy-tabix.
      READ TABLE it_envelope TRANSPORTING NO FIELDS
        WITH TABLE KEY envelope = <ls_alv>-envelope.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE it_keep_rows TRANSPORTING NO FIELDS
        WITH TABLE KEY table_line = lv_tabix.
      IF sy-subrc EQ 0.
        CONTINUE.
      ENDIF.
      CLEAR: <ls_alv>-block_dc,
             <ls_alv>-block_dc_text.
    ENDLOOP.

  ENDMETHOD.                    "release_envelopes

  METHOD is_dc_code_valid.

    DATA: lv_block_dc TYPE zprd_pr_block_dc.

    SELECT SINGLE block_dc FROM zprc_dccode
      INTO @lv_block_dc
      WHERE block_dc = @iv_block_dc.
    IF sy-subrc EQ 0.
      rv_valid = abap_true.
    ENDIF.

  ENDMETHOD.                    "is_dc_code_valid

  METHOD refresh_grid.

    DATA: ls_stable TYPE lvc_s_stbl.

    ls_stable-row = abap_true.
    ls_stable-col = abap_true.

    CALL METHOD go_alv_grid_01->refresh_table_display
      EXPORTING
        is_stable = ls_stable
      EXCEPTIONS
        finished  = 1
        OTHERS    = 2.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno DISPLAY LIKE 'E'
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

  ENDMETHOD.                    "refresh_grid

ENDCLASS.                    "gcl_alv_grid_01_event_receiver IMPLEMENTATION

*&---------------------------------------------------------------------*
*&      Form  ALV_GRID_01_FREE
*&---------------------------------------------------------------------*
FORM alv_grid_01_free .

* ALV Grid törlés
  IF go_alv_grid_01 IS BOUND.
    CALL METHOD go_alv_grid_01->free.
    FREE go_alv_grid_01.
  ENDIF.
* Custom container törlés
  IF go_alv_grid_cont_01 IS BOUND.
    CALL METHOD go_alv_grid_cont_01->free.
    FREE go_alv_grid_cont_01.
  ENDIF.

ENDFORM.                    " ALV_GRID_01_FREE
*&---------------------------------------------------------------------*
*&      Form  LEAVE_ALV
*&---------------------------------------------------------------------*
*       ALV elhagyása: kontrollok törlése, zár feloldása
*----------------------------------------------------------------------*
FORM leave_alv .

  PERFORM alv_grid_01_free.
  PERFORM unlock_stock.
  SET SCREEN 0.
  LEAVE SCREEN.

ENDFORM.                    " LEAVE_ALV
*&---------------------------------------------------------------------*
*&      Form  USER_COMMAND_0100
*&---------------------------------------------------------------------*
FORM user_command_0100 .

  DATA: lv_okcode TYPE syucomm,
        lv_valid  TYPE char01.

  lv_okcode = gv_okcode_0100.
  CLEAR gv_okcode_0100.

  CASE lv_okcode.
    WHEN gc_ucomm_save.
      CHECK gv_modif EQ abap_true.

*     Függő cellabevitel átvétele; hibás cella esetén nincs mentés
      CALL METHOD go_alv_grid_01->check_changed_data
        IMPORTING
          e_valid = lv_valid.
      IF lv_valid NE abap_true.
        RETURN.
      ENDIF.

      PERFORM save_data.
  ENDCASE.

ENDFORM.                    " USER_COMMAND_0100
*&---------------------------------------------------------------------*
*&      Form  SAVE_DATA
*&---------------------------------------------------------------------*
*       Mentés egy LUW-ban: bármely hiba -> teljes ROLLBACK, az ALV
*       nyitva marad. Napló csak a végső eredményről.
*----------------------------------------------------------------------*
FORM save_data .

  DATA: lt_msg        TYPE bal_t_msg,
        ls_msg        TYPE bal_s_msg,
        lv_ok         TYPE abap_bool,
        lv_error      TYPE abap_bool,
        lv_doc_no     TYPE zprd_doc_no,
        lv_err_text   TYPE string,
        lo_sql_error  TYPE REF TO cx_sy_open_sql_db.
  FIELD-SYMBOLS: <ls_alv> TYPE zprs_dcqm_report.

  PERFORM check_changed.
  IF gv_changed EQ abap_false.
    MESSAGE ID gc_msgid TYPE 'S' NUMBER gc_msgno-generic
            WITH 'Nincs mentendő módosítás.'(m01).
    RETURN.
  ENDIF.

  PERFORM check_entered_data CHANGING lv_ok.
  IF lv_ok EQ abap_false.
    RETURN.
  ENDIF.

  TRY.
      LOOP AT gt_0100_alv ASSIGNING <ls_alv> WHERE changed EQ abap_true.

        lv_doc_no = <ls_alv>-doc_no.
        PERFORM save_row USING <ls_alv> CHANGING lv_error.
        IF lv_error EQ abap_true.
          EXIT.
        ENDIF.

*       Sorüzenet - csak sikeres COMMIT után kerül a naplóba
        CLEAR ls_msg.
        ls_msg-msgid = gc_msgid.
        ls_msg-msgty = 'S'.
        ls_msg-msgv1 = <ls_alv>-doc_no.
        IF <ls_alv>-block_dc IS INITIAL.
          ls_msg-msgno = gc_msgno-row_released.
*         &1 kizárása visszavonva
        ELSE.
          ls_msg-msgno = gc_msgno-row_excluded.
          ls_msg-msgv2 = <ls_alv>-block_dc.
          ls_msg-msgv3 = <ls_alv>-block_dc_text.
*         &1 kizárva: &2 &3
        ENDIF.
        APPEND ls_msg TO lt_msg.

      ENDLOOP.

    CATCH cx_sy_open_sql_db INTO lo_sql_error.
      lv_error    = abap_true.
      lv_err_text = lo_sql_error->get_text( ).
  ENDTRY.

  IF lv_error EQ abap_false.
    COMMIT WORK.

    CLEAR ls_msg.
    ls_msg-msgid = gc_msgid.
    ls_msg-msgty = 'S'.
    ls_msg-msgno = gc_msgno-save_ok.
*   Mentés sikeres
    APPEND ls_msg TO lt_msg.
  ELSE.
    ROLLBACK WORK.

*   A visszagörgetett sorok nem kerülnek sikerként a naplóba
    REFRESH lt_msg.
    CLEAR ls_msg.
    ls_msg-msgid = gc_msgid.
    ls_msg-msgty = 'E'.
    ls_msg-msgno = gc_msgno-generic.
    ls_msg-msgv1 = 'Mentési hiba, dokumentum:'(m02).
    ls_msg-msgv2 = lv_doc_no.
    ls_msg-msgv3 = lv_err_text.
    APPEND ls_msg TO lt_msg.

    CLEAR ls_msg.
    ls_msg-msgid = gc_msgid.
    ls_msg-msgty = 'E'.
    ls_msg-msgno = gc_msgno-save_failed.
*   Mentés sikertelen
    APPEND ls_msg TO lt_msg.
  ENDIF.

  PERFORM log_write USING lt_msg.

  IF lv_error EQ abap_false.
    gt_0100_orig = gt_0100_alv.
    CLEAR gv_changed.
    MESSAGE ID gc_msgid TYPE 'S' NUMBER gc_msgno-save_ok.
*   Mentés sikeres
    PERFORM leave_alv.
  ELSE.
*   Az ALV a módosított adatokkal nyitva marad, a zár megmarad ->
*   javítás / újrapróbálás lehetséges
    MESSAGE ID gc_msgid TYPE 'S' NUMBER gc_msgno-save_failed
            DISPLAY LIKE 'E'.
*   Mentés sikertelen
  ENDIF.

ENDFORM.                    " SAVE_DATA
*&---------------------------------------------------------------------*
*&      Form  SAVE_ROW
*&---------------------------------------------------------------------*
*       Egy sor írása: ZPRT_DCQM-BLOCK_DC + ZPRT_DCQMLT-BLOCK_DC_TEXT
*----------------------------------------------------------------------*
FORM save_row USING    us_alv   TYPE zprs_dcqm_report
              CHANGING cv_error TYPE abap_bool
              RAISING  cx_sy_open_sql_db.

  DATA: ls_dcqmlt TYPE zprt_dcqmlt.

  cv_error = abap_false.

* A stockfeltétel védi az időközben más stockhoz rendelt dokumentumot
  UPDATE zprt_dcqm SET block_dc = @us_alv-block_dc,
                      chuser   = @sy-uname,
                      chdate   = @sy-datum,
                      chtime   = @sy-uzeit
    WHERE doc_no   = @us_alv-doc_no
      AND prd_stock_id = @p_stokid.
  IF sy-subrc <> 0 OR sy-dbcnt <> 1.
    cv_error = abap_true.
    RETURN.
  ENDIF.

* Hosszú szöveg - a munkaterület minden sornál üres
  CLEAR ls_dcqmlt.
  SELECT SINGLE * FROM zprt_dcqmlt
    INTO @ls_dcqmlt
    WHERE exbilldocno = @us_alv-doc_no.
  IF sy-subrc EQ 0.
    IF ls_dcqmlt-block_dc_text NE us_alv-block_dc_text.
*     Üres DC-szövegnél sem töröljük a rekordot: a QM-szöveg megmarad
      UPDATE zprt_dcqmlt SET block_dc_text = @us_alv-block_dc_text
        WHERE exbilldocno = @us_alv-doc_no.
      IF sy-subrc <> 0 OR sy-dbcnt <> 1.
        cv_error = abap_true.
      ENDIF.
    ENDIF.
  ELSEIF us_alv-block_dc_text IS NOT INITIAL.
    CLEAR ls_dcqmlt.
    ls_dcqmlt-exbilldocno   = us_alv-doc_no.
    ls_dcqmlt-block_dc_text = us_alv-block_dc_text.
    INSERT zprt_dcqmlt FROM @ls_dcqmlt.
    IF sy-subrc <> 0.
      cv_error = abap_true.
    ENDIF.
  ENDIF.

ENDFORM.                    " SAVE_ROW
*&---------------------------------------------------------------------*
*&      Form  LOG_WRITE
*&---------------------------------------------------------------------*
*       Napló létrehozása, mentése és megjelenítése
*----------------------------------------------------------------------*
FORM log_write USING ut_msg TYPE bal_t_msg.

  DATA: ls_msg TYPE bal_s_msg.

* ⚠️ A ZCL_PR_LOG szignatúrája ellenőrizendő (konstruktor, close,
* display). Ha a konstruktor fogad külső azonosítót (EXTNUMBER), adjuk
* át a p_stokid-t, hogy a napló SLG1-ben stock szerint kereshető legyen.
  CREATE OBJECT go_log
    EXPORTING
      iv_log_object    = gc_log_object
      iv_log_subobject = gc_log_subobj.

  LOOP AT ut_msg INTO ls_msg.
    MESSAGE ID ls_msg-msgid TYPE ls_msg-msgty NUMBER ls_msg-msgno
            WITH ls_msg-msgv1 ls_msg-msgv2 ls_msg-msgv3 ls_msg-msgv4
            INTO gv_dummy.
    go_log->add_system_message( ).
  ENDLOOP.

* ⚠️ Feltételezés - a close( ) menti a naplót (BAL_DB_SAVE).
* Az üzleti COMMIT/ROLLBACK már lefutott; ez a COMMIT csak a naplót
* teszi tartóssá (update task esetén is).
  go_log->close( ).
  COMMIT WORK.

  go_log->display( ).

ENDFORM.                    " LOG_WRITE
*&---------------------------------------------------------------------*
*&      Form  EXIT_COMMAND_0100
*&---------------------------------------------------------------------*
FORM exit_command_0100 .

  DATA: lv_okcode TYPE syucomm,
        lv_valasz TYPE char1.

  lv_okcode = gv_okcode_0100.
  CLEAR gv_okcode_0100.

  CASE lv_okcode.
    WHEN 'BACK'
      OR 'EXIT'
      OR 'CANCEL'.

      IF go_alv_grid_01 IS BOUND.
        CALL METHOD go_alv_grid_01->check_changed_data.
      ENDIF.
      PERFORM check_changed.

      IF gv_changed EQ abap_true.
        "figyelmeztetés
        CALL FUNCTION 'POPUP_TO_CONFIRM_WITH_MESSAGE'
          EXPORTING
            defaultoption  = 'N'
            diagnosetext1  = 'Történtek módosítások, nem mentett adatok elvesznek!'(w01)
            textline1      = 'Biztosan kilép?'(w02)
            titel          = 'Figyelmeztetés'(w03)
            start_column   = 35
            start_row      = 11
            cancel_display = space
          IMPORTING
            answer         = lv_valasz.
        IF lv_valasz NE 'J'.
          RETURN.
        ENDIF.
      ENDIF.

      PERFORM leave_alv.

  ENDCASE.

ENDFORM.                    " EXIT_COMMAND_0100
*&---------------------------------------------------------------------*
*&      Form  CREATE_CONTROLS_0100
*&---------------------------------------------------------------------*
FORM create_controls_0100 .

  DATA:
    ls_layout   TYPE lvc_s_layo,
    ls_variant  TYPE disvariant,
    lt_fieldcat TYPE lvc_t_fcat,
    lv_stokid   TYPE char10.

* Csak ha még nem létezik a konténer és az ALV Grid objektum
  CHECK go_alv_grid_cont_01 IS INITIAL.
  CHECK go_alv_grid_01      IS INITIAL.

* Custom container control létrehozás
  CREATE OBJECT go_alv_grid_cont_01
    EXPORTING
      container_name              = 'ALV_CONTAINER_01'
    EXCEPTIONS
      cntl_error                  = 1
      cntl_system_error           = 2
      create_error                = 3
      lifetime_error              = 4
      lifetime_dynpro_dynpro_link = 5.
  IF NOT sy-subrc IS INITIAL.
    EXIT.
  ENDIF.

* ALV Grid control létrehozás
  CREATE OBJECT go_alv_grid_01
    EXPORTING
      i_parent          = go_alv_grid_cont_01
      i_appl_events     = space
    EXCEPTIONS
      error_cntl_create = 1
      error_cntl_init   = 2
      error_cntl_link   = 3
      error_dp_create   = 4.
  IF NOT sy-subrc IS INITIAL.
    EXIT.
  ENDIF.

* ALV Grid cellák módosíthatósága
  IF gv_modif EQ abap_true.
    PERFORM cell_style_alv_outtab_0100.
  ENDIF.

* ALV Grid layout beállítás
  CLEAR ls_layout.
  ls_layout-zebra      = abap_true.
  ls_layout-cwidth_opt = abap_true.
  lv_stokid = p_stokid.
  SHIFT lv_stokid LEFT DELETING LEADING '0'.
  IF gv_modif EQ abap_true.
    CONCATENATE lv_stokid 'stock feldolgozása'(t01)
           INTO ls_layout-grid_title SEPARATED BY space.
  ELSE.
    CONCATENATE lv_stokid 'stock megjelenítése'(t02)
           INTO ls_layout-grid_title SEPARATED BY space.
  ENDIF.
  ls_layout-sel_mode   = 'A'.
  ls_layout-smalltitle = abap_true.
  ls_layout-stylefname = 'HANDLE_STYLE'.

* Mezőkatalógus generálás
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = 'ZPRS_DCQM_REPORT'
    CHANGING
      ct_fieldcat            = lt_fieldcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2.
  IF NOT sy-subrc IS INITIAL.
    REFRESH lt_fieldcat.
  ENDIF.

* Mezőkatalógus módosítás
  PERFORM alv_fieldcat_0100_mod CHANGING lt_fieldcat.

* Esemény kezelő regisztrálás
  SET HANDLER
    gcl_alv_grid_01_event_receiver=>on_alv_user_command
    gcl_alv_grid_01_event_receiver=>on_alv_toolbar
    gcl_alv_grid_01_event_receiver=>handle_data_changed
    gcl_alv_grid_01_event_receiver=>handle_data_changed_finished
    FOR go_alv_grid_01.

  IF gv_modif EQ abap_true.
    CALL METHOD go_alv_grid_01->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.

    CALL METHOD go_alv_grid_01->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_modified
      EXCEPTIONS
        error      = 1
        OTHERS     = 2.
  ENDIF.

  CLEAR ls_variant.
  ls_variant-report   = sy-repid.
  ls_variant-username = sy-uname.
  ls_variant-variant  = p_vari.

* ALV Grid megjelenítés
  CALL METHOD go_alv_grid_01->set_table_for_first_display
    EXPORTING
      is_variant                    = ls_variant
      i_save                        = 'A'
      i_default                     = abap_true
      is_layout                     = ls_layout
    CHANGING
      it_outtab                     = gt_0100_alv
      it_fieldcatalog               = lt_fieldcat
    EXCEPTIONS
      invalid_parameter_combination = 1
      program_error                 = 2
      too_many_lines                = 3.
  IF NOT sy-subrc IS INITIAL.
    EXIT.
  ENDIF.

* Toolbar esemény kiváltás, hogy a gombok megjelenjenek a toolbaron
  CALL METHOD go_alv_grid_01->set_toolbar_interactive.

ENDFORM.                    " CREATE_CONTROLS_0100
*&---------------------------------------------------------------------*
*&      Form  ALV_FIELDCAT_0100_MOD
*&---------------------------------------------------------------------*
FORM alv_fieldcat_0100_mod CHANGING ct_fieldcat TYPE lvc_t_fcat.

  FIELD-SYMBOLS: <ls_fcat> TYPE lvc_s_fcat.

  LOOP AT ct_fieldcat ASSIGNING <ls_fcat>.
    CASE <ls_fcat>-fieldname.
      WHEN 'NAME1'.
        <ls_fcat>-coltext = 'Név'(f01).
        <ls_fcat>-col_opt = abap_true.
      WHEN 'CHANGED'.
        <ls_fcat>-tech    = abap_true.
      WHEN 'BLOCK_DC'
        OR 'BLOCK_QM'.
        <ls_fcat>-f4availabl = abap_true.
      WHEN 'COUNTER'.
*       Összegző oszlop: a struktúrában az utolsó látható mező;
*       az összegzést a felhasználó kéri (Σ) és layoutba menti
        <ls_fcat>-coltext   = 'Darab'(f02).
        <ls_fcat>-scrtext_s = 'Darab'(f02).
        <ls_fcat>-scrtext_m = 'Darab'(f02).
        <ls_fcat>-scrtext_l = 'Darab'(f02).
      WHEN OTHERS.
        <ls_fcat>-col_opt = abap_true.
    ENDCASE.
  ENDLOOP.

ENDFORM.                    " ALV_FIELDCAT_0100_MOD
*&---------------------------------------------------------------------*
*&      Form  CELL_STYLE_ALV_OUTTAB_0100
*&---------------------------------------------------------------------*
*       Szerkeszthető cellák: BLOCK_DC, BLOCK_DC_TEXT
*----------------------------------------------------------------------*
FORM cell_style_alv_outtab_0100 .

  DATA: ls_edit TYPE lvc_s_styl.

  FIELD-SYMBOLS: <ls_alv> TYPE zprs_dcqm_report.

  LOOP AT gt_0100_alv ASSIGNING <ls_alv>.

    REFRESH <ls_alv>-handle_style.

    CLEAR ls_edit.
    ls_edit-fieldname = 'BLOCK_DC'.
    ls_edit-style     = cl_gui_alv_grid=>mc_style_enabled.
    INSERT ls_edit INTO TABLE <ls_alv>-handle_style.

    CLEAR ls_edit.
    ls_edit-fieldname = 'BLOCK_DC_TEXT'.
    ls_edit-style     = cl_gui_alv_grid=>mc_style_enabled.
    INSERT ls_edit INTO TABLE <ls_alv>-handle_style.

  ENDLOOP.

ENDFORM.                    " CELL_STYLE_ALV_OUTTAB_0100
*&---------------------------------------------------------------------*
*&      Form  CHECK_CHANGED
*&---------------------------------------------------------------------*
*       Módosításjelző újraszámítása minden sorra, az üzleti mezők
*       alapján; a cellastílus érintetlen marad
*----------------------------------------------------------------------*
FORM check_changed .

  FIELD-SYMBOLS: <ls_alv>  TYPE zprs_dcqm_report,
                 <ls_orig> TYPE zprs_dcqm_report.

  CLEAR gv_changed.

  LOOP AT gt_0100_alv ASSIGNING <ls_alv>.
    READ TABLE gt_0100_orig ASSIGNING <ls_orig>
      WITH TABLE KEY doc_no = <ls_alv>-doc_no.
    IF sy-subrc EQ 0
       AND <ls_alv>-block_dc      EQ <ls_orig>-block_dc
       AND <ls_alv>-block_dc_text EQ <ls_orig>-block_dc_text.
      CLEAR <ls_alv>-changed.
    ELSE.
      <ls_alv>-changed = abap_true.
      gv_changed = abap_true.
    ENDIF.
  ENDLOOP.

ENDFORM.                    " CHECK_CHANGED
*&---------------------------------------------------------------------*
*&      Form  CHECK_ENTERED_DATA
*&---------------------------------------------------------------------*
*       Mentés előtti ellenőrzés a módosított sorokra
*----------------------------------------------------------------------*
FORM check_entered_data CHANGING cv_ok TYPE abap_bool.

  FIELD-SYMBOLS: <ls_alv> TYPE zprs_dcqm_report.

  cv_ok = abap_true.

  LOOP AT gt_0100_alv ASSIGNING <ls_alv> WHERE changed EQ abap_true.
    IF <ls_alv>-block_dc IS NOT INITIAL.
      IF gcl_alv_grid_01_event_receiver=>is_dc_code_valid(
           <ls_alv>-block_dc ) EQ abap_false.
        cv_ok = abap_false.
        MESSAGE ID gc_msgid TYPE 'S' NUMBER gc_msgno-dc_code_unknown
                DISPLAY LIKE 'E' WITH <ls_alv>-block_dc.
*       DC zárolás kód &1 nem létezik.
        RETURN.
      ENDIF.
    ELSEIF <ls_alv>-block_dc_text IS NOT INITIAL.
      cv_ok = abap_false.
      MESSAGE ID gc_msgid TYPE 'S' NUMBER gc_msgno-dc_text_no_code
              DISPLAY LIKE 'E'.
*     DC zárolási szöveghez DC zárolási kódot is meg kell adni!
      RETURN.
    ENDIF.
  ENDLOOP.

ENDFORM.                    " CHECK_ENTERED_DATA
*&---------------------------------------------------------------------*
*&      Form  CHECK_ENTERED_DATA_POPUP
*&---------------------------------------------------------------------*
*       POPUP_GET_VALUES_USER_CHECKED visszahívás (a felületet az FM
*       határozza meg)
*----------------------------------------------------------------------*
FORM check_entered_data_popup TABLES pt_fields STRUCTURE sval
                              USING  ps_error  STRUCTURE svale.

  DATA: lv_block_dc      TYPE zprd_pr_block_dc,
        lv_block_dc_text TYPE zprd_pr_block_dc_text,
        ls_fields        TYPE sval.

  LOOP AT pt_fields INTO ls_fields.
    CASE ls_fields-fieldname.
      WHEN 'BLOCK_DC'.
        lv_block_dc = ls_fields-value.
      WHEN 'BLOCK_DC_TEXT'.
        lv_block_dc_text = ls_fields-value.
    ENDCASE.
  ENDLOOP.

  IF lv_block_dc IS NOT INITIAL.
    IF gcl_alv_grid_01_event_receiver=>is_dc_code_valid( lv_block_dc )
       EQ abap_false.
      CLEAR ps_error.
      ps_error-msgid = gc_msgid.
      ps_error-msgty = 'E'.
      ps_error-msgno = gc_msgno-dc_code_unknown.
      ps_error-msgv1 = lv_block_dc.
*     DC zárolás kód &1 nem létezik.
    ENDIF.
  ELSEIF lv_block_dc_text IS NOT INITIAL.
    CLEAR ps_error.
    ps_error-msgid = gc_msgid.
    ps_error-msgty = 'E'.
    ps_error-msgno = gc_msgno-dc_text_no_code.
*   DC zárolási szöveghez DC zárolási kódot is meg kell adni!
  ENDIF.

ENDFORM.                    " CHECK_ENTERED_DATA_POPUP
