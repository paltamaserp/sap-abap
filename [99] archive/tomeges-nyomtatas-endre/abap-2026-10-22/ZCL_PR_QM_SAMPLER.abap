"! Mintakategória-képzés: a feltöltendő dokumentumokat a kategóriák szűrői szerint
"! csoportosítja, és kategóriánként véletlen mintát választ. Adatbázist nem ír;
"! az adatokat és a véletlent interfészen át kapja, ezért adatbázis nélkül tesztelhető.
class ZCL_PR_QM_SAMPLER definition
  public
  create public .

public section.

  types TT_DOC_NO type ZIF_PR_QM_DATA=>TT_DOC_NO .
  types:
    BEGIN OF ts_group,
        qm_cat TYPE zprc_qmcat-qm_cat,
        doc_no TYPE tt_doc_no,
      END OF ts_group .
  types:
    tt_group TYPE STANDARD TABLE OF ts_group WITH DEFAULT KEY .
  types:
    BEGIN OF ts_result,
        assignments TYPE zif_pr_qm_data=>tt_assignment,
        exclusions  TYPE zif_pr_qm_data=>tt_exclusion,
        groups      TYPE tt_group,
        rest        TYPE tt_doc_no,
      END OF ts_result .

  methods CONSTRUCTOR
    importing
      !IO_DATA type ref to ZIF_PR_QM_DATA
      !IO_RANDOM type ref to ZIF_PR_QM_RANDOM .
  methods BUILD
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
      !IT_PACKAGE_ID type ZIF_PR_QM_DATA=>TT_PACKAGE_ID
      !IT_DOC_NO type ZIF_PR_QM_DATA=>TT_DOC_NO
    returning
      value(RS_RESULT) type TS_RESULT
    raising
      ZCX_FORM_MESSAGE_ERROR .
  methods PICK_SAMPLE
    importing
      !IT_POOL type TT_DOC_NO
      !IV_SIZE type I
    returning
      value(RT_SAMPLE) type TT_DOC_NO
    raising
      ZCX_FORM_MESSAGE_ERROR .
protected section.

  types:
    BEGIN OF ts_condition,
        fieldname TYPE string,
        line      TYPE REF TO cl_abap_structdescr,
        range     TYPE REF TO data,
      END OF ts_condition .
  types:
    tt_condition TYPE STANDARD TABLE OF ts_condition WITH DEFAULT KEY .

  methods BUILD_CONDITIONS
    importing
      !IV_QM_CAT type ZPRC_QMCAT-QM_CAT
      !IT_FILTER type ZIF_PR_QM_DATA=>TT_FILTER
    returning
      value(RT_CONDITION) type TT_CONDITION
    raising
      ZCX_FORM_MESSAGE_ERROR .
  methods CONVERT_VALUE
    importing
      !IO_TYPE type ref to CL_ABAP_ELEMDESCR
      !IV_TEXT type STRING
      !IV_PATTERN type ABAP_BOOLEAN default ABAP_FALSE
    changing
      !CV_VALUE type ANY
    returning
      value(RV_OK) type ABAP_BOOLEAN .
  methods MATCHES
    importing
      !IS_CANDIDATE type ZIF_PR_QM_DATA=>TS_CANDIDATE
      !IT_CONDITION type TT_CONDITION
    returning
      value(RV_MATCH) type ABAP_BOOLEAN .

  constants C_OPTIONS type STRING value `,EQ,NE,LT,LE,GT,GE,BT,NB,CP,NP,` ##NO_TEXT.
  data MO_DATA type ref to ZIF_PR_QM_DATA .
  data MO_RANDOM type ref to ZIF_PR_QM_RANDOM .
private section.
ENDCLASS.



CLASS ZCL_PR_QM_SAMPLER IMPLEMENTATION.


  METHOD constructor.
    " A függőségeket kívülről kapjuk, hogy tesztben dublőr kerülhessen a helyükre.
    mo_data   = io_data.
    mo_random = io_random.
  ENDMETHOD.


  METHOD build.
    " Egy dokumentum legfeljebb egy kategóriába kerülhet: a kategóriákat sorrendbe
    " állítjuk (a kisebb PRIO az erősebb), és a már besorolt dokumentumokat a
    " későbbi kategóriákból kihagyjuk. A hibás beállítású kategória az egész
    " képzést megállítja, mert különben a dokumentumai csendben a minta nélküli
    " maradékba kerülnének, és a minőségi kapu kimaradna.
    DATA lt_upload TYPE SORTED TABLE OF zprd_doc_no WITH UNIQUE KEY table_line.
    DATA lt_candidate TYPE SORTED TABLE OF zif_pr_qm_data=>ts_candidate WITH UNIQUE KEY doc_no.
    DATA lt_used TYPE SORTED TABLE OF zprd_doc_no WITH UNIQUE KEY table_line.
    DATA lt_sampled TYPE SORTED TABLE OF zprd_doc_no WITH UNIQUE KEY table_line.
    DATA lt_sample_sorted TYPE SORTED TABLE OF zprd_doc_no WITH UNIQUE KEY table_line.
    DATA lt_seen TYPE SORTED TABLE OF zprd_doc_no WITH UNIQUE KEY table_line.
    DATA lt_member TYPE tt_doc_no.
    DATA lt_sample TYPE tt_doc_no.

    " A feltöltött listában ugyanaz a dokumentumszám többször is állhat; az
    " egyedi kulcsú táblába a tömeges beszúrás ilyenkor futási hibával leállna,
    " ezért előbb kiszűrjük az ismétlődéseket.
    DATA(lt_upload_unique) = it_doc_no.
    SORT lt_upload_unique.
    DELETE ADJACENT DUPLICATES FROM lt_upload_unique.
    INSERT LINES OF lt_upload_unique INTO TABLE lt_upload.

    " Csak a ténylegesen feltöltendő dokumentumok vehetnek részt a mintavételben,
    " különben az Inspire olyan azonosítót kapna, amelyhez nincs fájl.
    DATA(lt_raw) = mo_data->get_candidates( it_package_id ).
    LOOP AT lt_raw INTO DATA(ls_raw).
      IF line_exists( lt_upload[ table_line = ls_raw-doc_no ] ).
        INSERT ls_raw INTO TABLE lt_candidate.
      ENDIF.
    ENDLOOP.

    DATA(lt_cat) = mo_data->get_categories( ).
    SORT lt_cat BY prio qm_cat.

    LOOP AT lt_cat INTO DATA(ls_cat).
      DATA(lt_filter) = mo_data->get_filters( ls_cat-qm_cat ).
      DATA(lt_condition) = build_conditions( iv_qm_cat = ls_cat-qm_cat
                                             it_filter = lt_filter ).

      CLEAR lt_member.
      LOOP AT lt_candidate INTO DATA(ls_candidate).
        IF line_exists( lt_used[ table_line = ls_candidate-doc_no ] ).
          CONTINUE.
        ENDIF.
        IF matches( is_candidate = ls_candidate
                    it_condition = lt_condition ) EQ abap_false.
          CONTINUE.
        ENDIF.
        APPEND ls_candidate-doc_no TO lt_member.
      ENDLOOP.

      IF lt_member IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT LINES OF lt_member INTO TABLE lt_used.

      lt_sample = pick_sample( it_pool = lt_member
                               iv_size = CONV i( ls_cat-sample_size ) ).
      CLEAR lt_sample_sorted.
      INSERT LINES OF lt_sample INTO TABLE lt_sample_sorted.

      LOOP AT lt_member INTO DATA(lv_member).
        APPEND VALUE #( stock_id  = iv_stock_id
                        qm_cat    = ls_cat-qm_cat
                        doc_no    = lv_member
                        in_sample = COND #( WHEN line_exists( lt_sample_sorted[ table_line = lv_member ] )
                                            THEN abap_true ) )
          TO rs_result-assignments.
      ENDLOOP.

      APPEND VALUE #( stock_id = iv_stock_id
                      qm_cat   = ls_cat-qm_cat )
        TO rs_result-exclusions.

      IF lt_sample IS NOT INITIAL.
        APPEND VALUE #( qm_cat = ls_cat-qm_cat
                        doc_no = lt_sample )
          TO rs_result-groups.
        INSERT LINES OF lt_sample INTO TABLE lt_sampled.
      ENDIF.
    ENDLOOP.

    " A maradékba minden feltöltött dokumentum kerül, amely nem tagja egyik
    " mintának sem: a kategóriák nem mintázott tagjai és a kategórián kívüliek is.
    LOOP AT it_doc_no INTO DATA(lv_doc).
      IF line_exists( lt_sampled[ table_line = lv_doc ] ).
        CONTINUE.
      ENDIF.
      INSERT lv_doc INTO TABLE lt_seen.
      IF sy-subrc NE 0.
        CONTINUE.
      ENDIF.
      APPEND lv_doc TO rs_result-rest.
    ENDLOOP.
  ENDMETHOD.


  METHOD pick_sample.
    " Részleges Fisher–Yates keverés: az i. lépésben a még nem kihúzott elemek
    " közül sorsolunk, és az i. helyre cseréljük, így pontosan iv_size különböző
    " elem kerül a mintába, ismétlődő húzás nélkül.
    DATA(lt_work) = it_pool.
    DATA(lv_count) = lines( lt_work ).
    DATA lv_pick TYPE i.
    DATA lv_other TYPE i.
    DATA lv_step TYPE i.
    DATA lv_left TYPE i.
    DATA lv_tmp TYPE zprd_doc_no.

    IF iv_size LE 0.
      RETURN.
    ENDIF.
    IF lv_count LE iv_size.
      rt_sample = lt_work.
      RETURN.
    ENDIF.

    DO iv_size TIMES.
      lv_step = sy-index.
      lv_left = lv_count - lv_step + 1.
      lv_pick = mo_random->get_int( lv_left ).
      IF lv_pick LT 1 OR lv_pick GT lv_left.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e017(zpr_qm)
          WITH CONV string( lv_pick ).
      ENDIF.
      lv_other = lv_step - 1 + lv_pick.
      IF lv_other NE lv_step.
        lv_tmp = lt_work[ lv_step ].
        lt_work[ lv_step ] = lt_work[ lv_other ].
        lt_work[ lv_other ] = lv_tmp.
      ENDIF.
      APPEND lt_work[ lv_step ] TO rt_sample.
    ENDDO.
  ENDMETHOD.


  METHOD build_conditions.
    " Kategóriánként, mezőnként egy tartomány-táblát építünk a mező saját
    " típusával, hogy az összehasonlítás a mező típusa szerint menjen. Az azonos
    " mező sorai egy táblába kerülnek (VAGY), a különböző mezők feltételei
    " ÉS kapcsolatban maradnak. Ellenőrzés: üres lista, nem engedélyezett mező,
    " érvénytelen előjel vagy reláció, nem konvertálható érték. A hibaüzenet
    " megnevezi a kategóriát, a tétel sorszámát és a mezőt, hogy a karbantartó
    " nézetben azonnal megtalálható legyen a hibás sor.
    DATA ls_dummy TYPE zif_pr_qm_data=>ts_candidate.
    DATA lr_row TYPE REF TO data.
    FIELD-SYMBOLS <ls_cond> TYPE ts_condition.
    FIELD-SYMBOLS <lt_range> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_comp> TYPE any.

    IF it_filter IS INITIAL.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e010(zpr_qm)
        WITH iv_qm_cat.
    ENDIF.

    DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( ls_dummy ) ).
    DATA(lt_comp) = lo_struct->get_components( ).

    LOOP AT it_filter INTO DATA(ls_filter).
      DATA(lv_field) = to_upper( CONV string( ls_filter-fieldname ) ).
      DATA(lv_option) = to_upper( CONV string( ls_filter-opti ) ).

      IF zif_pr_qm_data=>c_filter_fields NS |,{ lv_field },|.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e011(zpr_qm)
          WITH ls_filter-qm_cat CONV string( ls_filter-item ) ls_filter-fieldname.
      ENDIF.
      IF ls_filter-sign NE 'I' AND ls_filter-sign NE 'E'.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e012(zpr_qm)
          WITH ls_filter-qm_cat CONV string( ls_filter-item ) ls_filter-fieldname.
      ENDIF.
      IF c_options NS |,{ lv_option },|.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e013(zpr_qm)
          WITH ls_filter-qm_cat CONV string( ls_filter-item ) ls_filter-fieldname.
      ENDIF.

      READ TABLE lt_comp INTO DATA(ls_comp) WITH KEY name = lv_field.
      IF sy-subrc NE 0.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e011(zpr_qm)
          WITH ls_filter-qm_cat CONV string( ls_filter-item ) ls_filter-fieldname.
      ENDIF.
      DATA(lo_type) = CAST cl_abap_elemdescr( ls_comp-type ).

      IF ( lv_option EQ 'CP' OR lv_option EQ 'NP' )
         AND lo_type->type_kind NE cl_abap_typedescr=>typekind_char.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e015(zpr_qm)
          WITH ls_filter-qm_cat CONV string( ls_filter-item ) ls_filter-fieldname.
      ENDIF.
      IF ( lv_option EQ 'BT' OR lv_option EQ 'NB' ) AND ls_filter-high IS INITIAL.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e016(zpr_qm)
          WITH ls_filter-qm_cat CONV string( ls_filter-item ) ls_filter-fieldname.
      ENDIF.

      UNASSIGN <ls_cond>.
      READ TABLE rt_condition ASSIGNING <ls_cond> WITH KEY fieldname = lv_field.
      IF sy-subrc NE 0.
        DATA(lo_line) = cl_abap_structdescr=>create(
                          VALUE #( ( name = 'SIGN'   type = cl_abap_elemdescr=>get_c( 1 ) )
                                   ( name = 'OPTION' type = cl_abap_elemdescr=>get_c( 2 ) )
                                   ( name = 'LOW'    type = lo_type )
                                   ( name = 'HIGH'   type = lo_type ) ) ).
        DATA(lo_table) = cl_abap_tabledescr=>create( p_line_type = lo_line ).
        DATA lr_range TYPE REF TO data.
        CREATE DATA lr_range TYPE HANDLE lo_table.
        APPEND VALUE #( fieldname = lv_field
                        line      = lo_line
                        range     = lr_range )
          TO rt_condition ASSIGNING <ls_cond>.
      ENDIF.

      ASSIGN <ls_cond>-range->* TO <lt_range>.
      CREATE DATA lr_row TYPE HANDLE <ls_cond>-line.
      ASSIGN lr_row->* TO <ls_row>.

      ASSIGN COMPONENT 'SIGN' OF STRUCTURE <ls_row> TO <lv_comp>.
      <lv_comp> = ls_filter-sign.
      ASSIGN COMPONENT 'OPTION' OF STRUCTURE <ls_row> TO <lv_comp>.
      <lv_comp> = lv_option.

      ASSIGN COMPONENT 'LOW' OF STRUCTURE <ls_row> TO <lv_comp>.
      IF convert_value( EXPORTING io_type    = lo_type
                                  iv_text    = CONV string( ls_filter-low )
                                  iv_pattern = xsdbool( lv_option EQ 'CP' OR lv_option EQ 'NP' )
                        CHANGING  cv_value   = <lv_comp> ) EQ abap_false.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e014(zpr_qm)
          WITH ls_filter-qm_cat CONV string( ls_filter-item ) ls_filter-fieldname.
      ENDIF.

      IF lv_option EQ 'BT' OR lv_option EQ 'NB'.
        ASSIGN COMPONENT 'HIGH' OF STRUCTURE <ls_row> TO <lv_comp>.
        IF convert_value( EXPORTING io_type  = lo_type
                                    iv_text  = CONV string( ls_filter-high )
                          CHANGING  cv_value = <lv_comp> ) EQ abap_false.
          RAISE EXCEPTION TYPE zcx_form_message_error
            MESSAGE e014(zpr_qm)
            WITH ls_filter-qm_cat CONV string( ls_filter-item ) ls_filter-fieldname.
        ENDIF.
      ENDIF.

      APPEND <ls_row> TO <lt_range>.
    ENDLOOP.
  ENDMETHOD.


  METHOD convert_value.
    " A szűrő-tételben az érték szövegként áll; a mező típusára alakítjuk.
    " A szöveges és a numerikus szöveges (NUMC) mezőnél a hosszt is nézzük,
    " mert az értékadás csendben levágná a felesleget; a dátumnál érvényes
    " naptári napot várunk, a számoknál pedig számként értelmezhető szöveget.
    " A konverziós rutinos mezőknél (pl. ALPHA) az értéket belső formára hozzuk,
    " különben a szűrő a tárolt (nullákkal kitöltött) értékre soha nem illeszkedne;
    " a CP/NP mintát nem alakítjuk, mert abban a csillag és a pont szöveg marad.
    DATA lv_exit TYPE string.
    DATA lv_year TYPE i.
    DATA lv_month TYPE i.
    DATA lv_day TYPE i.
    DATA lv_last TYPE i.

    rv_ok = abap_true.

    IF io_type->is_ddic_type( ) EQ abap_true.
      lv_exit = io_type->get_ddic_field( )-convexit.
    ENDIF.

    CASE io_type->type_kind.
      WHEN cl_abap_typedescr=>typekind_char.
        IF strlen( iv_text ) GT io_type->output_length.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
        IF lv_exit IS NOT INITIAL AND iv_pattern EQ abap_false.
          IF lv_exit NE 'ALPHA'.
            " Más konverziós rutint nem ismerünk, ezért hibát jelzünk, nem találgatunk.
            rv_ok = abap_false.
            RETURN.
          ENDIF.
          cv_value = |{ iv_text ALPHA = IN }|.
        ELSE.
          cv_value = iv_text.
        ENDIF.

      WHEN cl_abap_typedescr=>typekind_num.
        IF strlen( iv_text ) GT io_type->output_length
           OR ( iv_text IS NOT INITIAL AND iv_text CN '0123456789' ).
          rv_ok = abap_false.
          RETURN.
        ENDIF.
        cv_value = iv_text.

      WHEN cl_abap_typedescr=>typekind_date.
        IF iv_text IS INITIAL.
          CLEAR cv_value.
          RETURN.
        ENDIF.
        IF strlen( iv_text ) NE 8 OR iv_text CN '0123456789'.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
        " Érvényes naptári napot követelünk: a hónap 1..12, a nap pedig legfeljebb
        " a hónap utolsó napja (a szökőévet is figyelembe véve).
        lv_year  = iv_text(4).
        lv_month = iv_text+4(2).
        lv_day   = iv_text+6(2).
        IF lv_year LT 1 OR lv_month LT 1 OR lv_month GT 12 OR lv_day LT 1.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
        CASE lv_month.
          WHEN 4 OR 6 OR 9 OR 11.
            lv_last = 30.
          WHEN 2.
            IF lv_year MOD 400 EQ 0 OR ( lv_year MOD 4 EQ 0 AND lv_year MOD 100 NE 0 ).
              lv_last = 29.
            ELSE.
              lv_last = 28.
            ENDIF.
          WHEN OTHERS.
            lv_last = 31.
        ENDCASE.
        IF lv_day GT lv_last.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
        cv_value = iv_text.

      WHEN OTHERS.
        TRY.
            cv_value = iv_text.
          CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
            rv_ok = abap_false.
        ENDTRY.
    ENDCASE.
  ENDMETHOD.


  METHOD matches.
    " Az ÉS kapcsolatot itt valósítjuk meg: a dokumentum akkor felel meg, ha
    " minden érintett mező értéke benne van a saját tartományában (az I/E
    " előjelek szerint, a VAGY kapcsolatot a tartomány-tábla adja).
    FIELD-SYMBOLS <lv_value> TYPE any.
    FIELD-SYMBOLS <lt_range> TYPE STANDARD TABLE.

    rv_match = abap_true.

    LOOP AT it_condition INTO DATA(ls_condition).
      ASSIGN COMPONENT ls_condition-fieldname OF STRUCTURE is_candidate TO <lv_value>.
      ASSIGN ls_condition-range->* TO <lt_range>.
      IF <lv_value> NOT IN <lt_range>.
        rv_match = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.