"! Adatbázis-hozzáférés a mintakategóriákhoz: itt van minden olvasás és írás,
"! a mintavételi logika csak az interfészen át éri el. Nem commitol és nem
"! görget vissza, ezt a hívó dönti el; kivétel a státuszváltás (CHANGE_STATUS),
"! amelyet a ZCL_PR_STOCK commitol.
class ZCL_PR_QM_DATA definition
  public
  create public .

public section.

  interfaces ZIF_PR_QM_DATA .
protected section.

  types:
    tt_doc_range TYPE RANGE OF zprt_dcqm-doc_no .

  methods GET_CATEGORY_DOCS
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
      !IV_QM_CAT type ZPRT_QMEXCL-QM_CAT
    returning
      value(RT_DOC_NO) type ZIF_PR_QM_DATA=>TT_DOC_NO .
  methods BUILD_RANGE
    importing
      !IT_DOC_NO type ZIF_PR_QM_DATA=>TT_DOC_NO
      !IV_FROM type I
      !IV_TO type I
    returning
      value(RR_DOC) type TT_DOC_RANGE .

  constants C_CHUNK_SIZE type I value 500 ##NO_TEXT.
private section.
ENDCLASS.



CLASS ZCL_PR_QM_DATA IMPLEMENTATION.


  METHOD zif_pr_qm_data~get_categories.
    " Csak az aktív kategóriák kellenek, mert az inaktív kategória nem vesz
    " részt a mintavételben. A sorrend (előbb a PRIO, azonos PRIO-nál a név)
    " dönti el, melyik kategóriába kerül a több szűrőnek is megfelelő dokumentum.
    SELECT qm_cat, prio, sample_size, active, descr
      FROM zprc_qmcat
      WHERE active EQ @abap_true
      ORDER BY prio, qm_cat
      INTO CORRESPONDING FIELDS OF TABLE @rt_cat.
  ENDMETHOD.


  METHOD zif_pr_qm_data~get_filters.
    " A szűrő-tételek sorszám szerint jönnek vissza, hogy a hibaüzenetben
    " szereplő tételszám a karbantartó nézet sorrendjével egyezzen.
    SELECT qm_cat, item, fieldname, sign, opti, low, high
      FROM zprc_qmcat_flt
      WHERE qm_cat EQ @iv_qm_cat
      ORDER BY item
      INTO CORRESPONDING FIELDS OF TABLE @rt_filter.
  ENDMETHOD.


  METHOD zif_pr_qm_data~get_candidates.
    " A szűrést nem az adatbázis végzi (nincs dinamikus feltétel), ezért itt
    " csak a csomagok dokumentumait olvassuk be a szűrhető mezőkkel együtt.
    " A DC-ellenőrzésen kizárt dokumentum nem kerülhet mintába, ezért kimarad;
    " így a maradékkal együtt nyomtatódik.
    DATA lr_package TYPE RANGE OF zprt_dcqm-package_id.

    lr_package = VALUE #( FOR lv_package IN it_package_id
                          ( sign = 'I' option = 'EQ' low = lv_package ) ).
    " Üres tartomány az egész táblát kiolvasná, ezért csomag nélkül nem keresünk.
    IF lr_package IS INITIAL.
      RETURN.
    ENDIF.

    SELECT dcqm~doc_no, doclog~doc_type, doclog~sparte, doclog~vkont,
           doclog~gpart, doclog~bukrs, doclog~opbel, doclog~channel,
           dcqm~doc_cat, dcqm~mahns, dcqm~mahnv, dcqm~amnt, dcqm~waers,
           dcqm~zbizcat, dcqm~cotyp, dcqm~form, dcqm~pymet, dcqm~land1,
           dcqm~duedate, dcqm~tariftyp, dcqm~aklasse
      FROM zprt_dcqm AS dcqm
      INNER JOIN zprt_doc_log AS doclog
        ON doclog~doc_no EQ dcqm~doc_no
      WHERE dcqm~package_id IN @lr_package
        AND dcqm~block_dc   EQ ''
      ORDER BY dcqm~doc_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_candidate.
  ENDMETHOD.


  METHOD zif_pr_qm_data~insert_assignments.
    " A létrehozás adatait (felhasználó, dátum, idő) itt töltjük ki, hogy a
    " hívónak ne kelljen vele foglalkoznia.
    DATA(lt_row) = it_assignment.

    LOOP AT lt_row ASSIGNING FIELD-SYMBOL(<ls_row>).
      <ls_row>-cruser = sy-uname.
      <ls_row>-crdate = sy-datum.
      <ls_row>-crtime = sy-uzeit.
    ENDLOOP.

    TRY.
        INSERT zprt_qmsample FROM TABLE @lt_row.
        IF sy-subrc NE 0.
          RAISE EXCEPTION TYPE zcx_form_message_error
            MESSAGE e003(zpr_qm)
            WITH 'ZPRT_QMSAMPLE'.
        ENDIF.
      CATCH cx_sy_open_sql_db.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e003(zpr_qm)
          WITH 'ZPRT_QMSAMPLE'.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_pr_qm_data~insert_exclusion_rows.
    " A kategóriánkénti kizárási sorok üres kóddal készülnek; a kódot később
    " a QM-ellenőrzés tölti ki.
    DATA(lt_row) = it_exclusion.

    LOOP AT lt_row ASSIGNING FIELD-SYMBOL(<ls_row>).
      <ls_row>-cruser = sy-uname.
      <ls_row>-crdate = sy-datum.
      <ls_row>-crtime = sy-uzeit.
    ENDLOOP.

    TRY.
        INSERT zprt_qmexcl FROM TABLE @lt_row.
        IF sy-subrc NE 0.
          RAISE EXCEPTION TYPE zcx_form_message_error
            MESSAGE e003(zpr_qm)
            WITH 'ZPRT_QMEXCL'.
        ENDIF.
      CATCH cx_sy_open_sql_db.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e003(zpr_qm)
          WITH 'ZPRT_QMEXCL'.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_pr_qm_data~update_dcqm_stock.
    " Minden feltöltött dokumentumnak pontosan egy sora van, ezért a módosított
    " sorok számának egyeznie kell az egyedi dokumentumok számával: ha kevesebb,
    " hiányzik egy dokumentum. A frissítést legfeljebb 500 dokumentumszámos
    " tartományokkal végezzük, hogy a nagy csomag ne lépje túl az adatbázis
    " utasításméret-korlátját.
    CONSTANTS lc_chunk TYPE i VALUE 500.
    DATA lr_doc TYPE RANGE OF zprt_dcqm-doc_no.
    DATA lt_unique TYPE SORTED TABLE OF zprd_doc_no WITH UNIQUE KEY table_line.
    DATA lv_from TYPE i VALUE 1.
    DATA lv_to TYPE i.
    DATA lv_total TYPE i.
    DATA lv_expected TYPE i.

    IF it_doc_no IS INITIAL.
      RETURN.
    ENDIF.

    INSERT LINES OF it_doc_no INTO TABLE lt_unique.
    lv_expected = lines( lt_unique ).

    WHILE lv_from LE lv_expected.
      lv_to = nmin( val1 = lv_from + lc_chunk - 1
                    val2 = lv_expected ).
      lr_doc = VALUE #( FOR lv_index = lv_from THEN lv_index + 1 WHILE lv_index LE lv_to
                        ( sign = 'I' option = 'EQ' low = lt_unique[ lv_index ] ) ).

      UPDATE zprt_dcqm
        SET prd_stock_id = @iv_stock_id,
            chuser       = @sy-uname,
            chdate       = @sy-datum,
            chtime       = @sy-uzeit
        WHERE doc_no IN @lr_doc.
      IF sy-subrc NE 0.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e004(zpr_qm)
          WITH CONV string( iv_stock_id ).
      ENDIF.
      lv_total = lv_total + sy-dbcnt.

      lv_from = lv_to + 1.
    ENDWHILE.

    IF lv_total NE lv_expected.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e004(zpr_qm)
        WITH CONV string( iv_stock_id ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_pr_qm_data~get_stock.
    " A teljes kulccsal olvasunk, ezért legfeljebb egy sor jön vissza; ha a
    " stock nem létezik, a struktúra üres marad, és a hívó dönt a teendőről.
    SELECT SINGLE stock_id, cruser, crdate, crtime, chuser, chdate, chtime,
                  status, erdat, ernam, ertim, closed, erdat_clo, ernam_clo,
                  ertim_clo, priority, dccompl, qmcompl, notest, stock_status_er
      FROM zprt_stock
      WHERE stock_id EQ @iv_stock_id
      INTO CORRESPONDING FIELDS OF @rs_stock.
    IF sy-subrc NE 0.
      CLEAR rs_stock.
    ENDIF.
  ENDMETHOD.


  METHOD zif_pr_qm_data~get_overview.
    " Három egyszerű lekérdezés adja az áttekintést: a kizárási sorok a
    " kategória leírásával, majd a tagok és a mintába került tagok száma
    " kategóriánként. A kategória nélküli (törölt) leírás üresen marad.
    TYPES:
      BEGIN OF ts_count,
        qm_cat TYPE zprt_qmsample-qm_cat,
        cnt    TYPE i,
      END OF ts_count.
    DATA lt_total TYPE SORTED TABLE OF ts_count WITH UNIQUE KEY qm_cat.
    DATA lt_sample TYPE SORTED TABLE OF ts_count WITH UNIQUE KEY qm_cat.

    SELECT excl~qm_cat, cat~descr, excl~block_qm, excl~block_qm_text
      FROM zprt_qmexcl AS excl
      LEFT OUTER JOIN zprc_qmcat AS cat
        ON cat~qm_cat EQ excl~qm_cat
      WHERE excl~stock_id EQ @iv_stock_id
      ORDER BY excl~qm_cat
      INTO TABLE @DATA(lt_head).
    IF lt_head IS INITIAL.
      RETURN.
    ENDIF.

    SELECT qm_cat, COUNT(*) AS cnt
      FROM zprt_qmsample
      WHERE stock_id EQ @iv_stock_id
      GROUP BY qm_cat
      INTO TABLE @lt_total.

    SELECT qm_cat, COUNT(*) AS cnt
      FROM zprt_qmsample
      WHERE stock_id  EQ @iv_stock_id
        AND in_sample EQ @abap_true
      GROUP BY qm_cat
      INTO TABLE @lt_sample.

    rt_overview = VALUE #( FOR ls_head IN lt_head
                           ( qm_cat       = ls_head-qm_cat
                             descr        = ls_head-descr
                             block_qm     = ls_head-block_qm
                             block_qm_text = ls_head-block_qm_text
                             doc_count    = VALUE #( lt_total[ qm_cat = ls_head-qm_cat ]-cnt OPTIONAL )
                             sample_count = VALUE #( lt_sample[ qm_cat = ls_head-qm_cat ]-cnt OPTIONAL ) ) ).
  ENDMETHOD.


  METHOD zif_pr_qm_data~lock_stock.
    " Szerkesztési zárolás a stockra, dialógus-zárként (1-es hatókör), hogy a
    " COMMIT WORK ne oldja fel. Ha más tartja, a nevét is megjelenítjük.
    CALL FUNCTION 'ENQUEUE_EZPRT_STOCK'
      EXPORTING
        mandt          = sy-mandt
        stock_id       = iv_stock_id
        _scope         = '1'
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc EQ 0.
      RETURN.
    ENDIF.
    IF sy-subrc EQ 1.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e006(zpr_qm)
        WITH sy-msgv1.
    ENDIF.
    RAISE EXCEPTION TYPE zcx_form_message_error
      MESSAGE e005(zpr_qm)
      WITH CONV string( iv_stock_id ).
  ENDMETHOD.


  METHOD zif_pr_qm_data~unlock_stock.
    " A zárolás feloldása ugyanazzal a hatókörrel, amellyel zároltunk; a
    " függvénynek nincs saját kivétele, de a váratlan hibát sem hagyjuk szó nélkül.
    CALL FUNCTION 'DEQUEUE_EZPRT_STOCK'
      EXPORTING
        mandt    = sy-mandt
        stock_id = iv_stock_id
        _scope   = '1'
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc NE 0.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e007(zpr_qm)
        WITH CONV string( iv_stock_id ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_pr_qm_data~code_exists.
    " A kód érvényes, ha szerepel a karbantartott kizárási kódok között.
    SELECT SINGLE block_qm
      FROM zprc_pr_qmcode
      WHERE block_qm EQ @iv_block_qm
      INTO @DATA(lv_code).
    rv_exists = xsdbool( sy-subrc EQ 0 ).
  ENDMETHOD.


  METHOD zif_pr_qm_data~set_block_qm.
    " A kategória összes tagjának (nem csak a mintának) ugyanazt a kódot adjuk.
    " A frissítés dokumentumszám-tartományokban, legfeljebb 500-as darabokban
    " fut, és a módosított sorok számának egyeznie kell a tagok számával.
    DATA lr_doc TYPE tt_doc_range.
    DATA lv_from TYPE i VALUE 1.
    DATA lv_to TYPE i.
    DATA lv_total TYPE i.

    DATA(lt_doc) = get_category_docs( iv_stock_id = iv_stock_id
                                      iv_qm_cat   = iv_qm_cat ).
    DATA(lv_expected) = lines( lt_doc ).

    WHILE lv_from LE lv_expected.
      lv_to = nmin( val1 = lv_from + c_chunk_size - 1
                    val2 = lv_expected ).
      lr_doc = build_range( it_doc_no = lt_doc
                            iv_from   = lv_from
                            iv_to     = lv_to ).

      UPDATE zprt_dcqm
        SET block_qm = @iv_block_qm,
            chuser   = @sy-uname,
            chdate   = @sy-datum,
            chtime   = @sy-uzeit
        WHERE doc_no       IN @lr_doc
          AND prd_stock_id EQ @iv_stock_id.
      IF sy-subrc NE 0.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e004(zpr_qm)
          WITH CONV string( iv_stock_id ).
      ENDIF.
      lv_total = lv_total + sy-dbcnt.

      lv_from = lv_to + 1.
    ENDWHILE.

    IF lv_total NE lv_expected.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e004(zpr_qm)
        WITH CONV string( iv_stock_id ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_pr_qm_data~set_block_text.
    " A szöveg kulcsa a dokumentumszám (EXBILLDOCNO). Ahol már van szövegsor,
    " csak a QM-szöveget írjuk át; ahol nincs, új sor készül üres DC-szöveggel.
    DATA lr_doc TYPE tt_doc_range.
    DATA lr_text TYPE RANGE OF zprt_dcqmlt-exbilldocno.
    DATA lr_existing TYPE RANGE OF zprt_dcqmlt-exbilldocno.
    DATA lt_existing TYPE SORTED TABLE OF zprt_dcqmlt-exbilldocno WITH UNIQUE KEY table_line.
    DATA lt_new TYPE STANDARD TABLE OF zprt_dcqmlt WITH DEFAULT KEY.
    DATA lv_from TYPE i VALUE 1.
    DATA lv_to TYPE i.

    DATA(lt_doc) = get_category_docs( iv_stock_id = iv_stock_id
                                      iv_qm_cat   = iv_qm_cat ).
    DATA(lv_count) = lines( lt_doc ).

    WHILE lv_from LE lv_count.
      lv_to = nmin( val1 = lv_from + c_chunk_size - 1
                    val2 = lv_count ).
      lr_doc = build_range( it_doc_no = lt_doc
                            iv_from   = lv_from
                            iv_to     = lv_to ).
      lr_text = VALUE #( FOR ls_range IN lr_doc
                         ( sign = ls_range-sign option = ls_range-option low = ls_range-low ) ).

      CLEAR: lt_existing, lt_new.
      SELECT exbilldocno
        FROM zprt_dcqmlt
        WHERE exbilldocno IN @lr_text
        ORDER BY exbilldocno
        INTO TABLE @lt_existing.

      IF lt_existing IS NOT INITIAL.
        lr_existing = VALUE #( FOR lv_existing IN lt_existing
                               ( sign = 'I' option = 'EQ' low = lv_existing ) ).
        UPDATE zprt_dcqmlt
          SET block_qm_text = @iv_text
          WHERE exbilldocno IN @lr_existing.
        IF sy-subrc NE 0.
          RAISE EXCEPTION TYPE zcx_form_message_error
            MESSAGE e008(zpr_qm)
            WITH 'ZPRT_DCQMLT'.
        ENDIF.
      ENDIF.

      LOOP AT lr_text INTO DATA(ls_text).
        IF NOT line_exists( lt_existing[ table_line = ls_text-low ] ).
          APPEND VALUE #( exbilldocno = ls_text-low
                          block_qm_text = iv_text ) TO lt_new.
        ENDIF.
      ENDLOOP.

      IF lt_new IS NOT INITIAL.
        TRY.
            INSERT zprt_dcqmlt FROM TABLE @lt_new.
            IF sy-subrc NE 0.
              RAISE EXCEPTION TYPE zcx_form_message_error
                MESSAGE e003(zpr_qm)
                WITH 'ZPRT_DCQMLT'.
            ENDIF.
          CATCH cx_sy_open_sql_db.
            RAISE EXCEPTION TYPE zcx_form_message_error
              MESSAGE e003(zpr_qm)
              WITH 'ZPRT_DCQMLT'.
        ENDTRY.
      ENDIF.

      lv_from = lv_to + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD zif_pr_qm_data~clear_block_text.
    " Visszavételnél csak a QM-szöveg ürül. A szövegsor nem törlődik, és a
    " DC-szöveg érintetlen marad. Ahol nincs szövegsor, nincs mit üríteni.
    DATA lr_doc TYPE tt_doc_range.
    DATA lr_text TYPE RANGE OF zprt_dcqmlt-exbilldocno.
    DATA lv_empty TYPE zprt_dcqmlt-block_qm_text.
    DATA lv_from TYPE i VALUE 1.
    DATA lv_to TYPE i.

    DATA(lt_doc) = get_category_docs( iv_stock_id = iv_stock_id
                                      iv_qm_cat   = iv_qm_cat ).
    DATA(lv_count) = lines( lt_doc ).

    WHILE lv_from LE lv_count.
      lv_to = nmin( val1 = lv_from + c_chunk_size - 1
                    val2 = lv_count ).
      lr_doc = build_range( it_doc_no = lt_doc
                            iv_from   = lv_from
                            iv_to     = lv_to ).
      lr_text = VALUE #( FOR ls_range IN lr_doc
                         ( sign = ls_range-sign option = ls_range-option low = ls_range-low ) ).

      UPDATE zprt_dcqmlt
        SET block_qm_text = @lv_empty
        WHERE exbilldocno IN @lr_text.
      " A 4-es kód azt jelenti, hogy egyik dokumentumhoz sincs szövegsor; ez nem hiba.
      IF sy-subrc NE 0 AND sy-subrc NE 4.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e008(zpr_qm)
          WITH 'ZPRT_DCQMLT'.
      ENDIF.

      lv_from = lv_to + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD zif_pr_qm_data~update_exclusion_row.
    " A kategória kizárási sora a stock létrehozásakor már elkészült, ezért itt
    " csak módosítunk; ha a sor hiányzik, a kategória nem tartozik a stockhoz.
    UPDATE zprt_qmexcl
      SET block_qm      = @iv_block_qm,
          block_qm_text = @iv_text,
          chuser        = @sy-uname,
          chdate        = @sy-datum,
          chtime        = @sy-uzeit
      WHERE stock_id EQ @iv_stock_id
        AND qm_cat   EQ @iv_qm_cat.
    IF sy-subrc NE 0.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e009(zpr_qm)
        WITH 'ZPRT_QMEXCL' CONV string( iv_stock_id ) iv_qm_cat.
    ENDIF.
  ENDMETHOD.


  METHOD zif_pr_qm_data~change_status.
    " A státusz egyetlen írási útja a ZCL_PR_STOCK; a döntés és az írás ott van.
    zcl_pr_stock=>change_status( iv_stock_id = iv_stock_id
                                 iv_from     = iv_from
                                 iv_to       = iv_to ).
  ENDMETHOD.


  METHOD zif_pr_qm_data~get_blocked_envelopes.
    " Csak azok a borítékok kellenek, amelyekben legalább egy dokumentum DC-
    " vagy QM-kizárást kapott; az üres borítékazonosítót kihagyjuk, az
    " egyedi lista pedig a DISTINCT miatt jön létre.
    SELECT DISTINCT envelope
      FROM zprt_dcqm
      WHERE prd_stock_id EQ @iv_stock_id
        AND envelope     NE ''
        AND ( block_dc NE '' OR block_qm NE '' )
      ORDER BY envelope
      INTO TABLE @rt_envelope.
  ENDMETHOD.


  METHOD get_category_docs.
    " A kategória tagjai: a stockhoz és a kategóriához rögzített dokumentumok.
    SELECT doc_no
      FROM zprt_qmsample
      WHERE stock_id EQ @iv_stock_id
        AND qm_cat   EQ @iv_qm_cat
      ORDER BY doc_no
      INTO TABLE @rt_doc_no.
  ENDMETHOD.


  METHOD build_range.
    " A megadott sorszámú szakasz dokumentumaiból egyenlőségi tartományt épít.
    rr_doc = VALUE #( FOR lv_index = iv_from THEN lv_index + 1 WHILE lv_index LE iv_to
                      ( sign = 'I' option = 'EQ' low = it_doc_no[ lv_index ] ) ).
  ENDMETHOD.
ENDCLASS.