"! A stock QM-oldali kezelése: ellenőrzés, zárolás, mintakategória kizárása
"! és visszavétele, QM-engedélyezés, valamint a stock végső engedélyezésének
"! közlése az Inspire felé. Az osztály nem commitol és nem görget vissza, ezt
"! a hívó (a ZPR_QM program vagy a cockpit) dönti el. Kivétel a QM-engedélyezés
"! és visszavétele (RELEASE, RELEASE_BACK): a státuszváltást a ZCL_PR_STOCK
"! commitolja.
class ZCL_PR_QM_EXCLUSION definition
  public
  create public .

public section.

    "! @parameter io_data | az adatbázis-hozzáférés (a teszt kiváltja)
    "! @parameter io_gateway | az Inspire-kapu (a teszt kiváltja)
  methods CONSTRUCTOR
    importing
      !IO_DATA type ref to ZIF_PR_QM_DATA
      !IO_GATEWAY type ref to ZIF_PR_INSPIRE_GW .
    "! Zárolja a stockot szerkesztésre.
  methods LOCK_STOCK
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
    raising
      ZCX_FORM_MESSAGE_ERROR .
    "! Feloldja a stock zárolását.
  methods UNLOCK_STOCK
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
    raising
      ZCX_FORM_MESSAGE_ERROR .
    "! Ellenőrzi, hogy a stock szerkeszthető: létezik, nincs lezárva, nincs
    "! QM-engedélyezve, és az állapota nem CL.
  methods CHECK_EDITABLE
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
    raising
      ZCX_FORM_MESSAGE_ERROR .
    "! Kizárja a mintakategóriát: a kategória összes tagja megkapja a kódot.
    "! A szöveg csak kóddal adható meg, a kódnak léteznie kell. Nem commitol.
  methods BLOCK_CATEGORY
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
      !IV_QM_CAT type ZPRT_QMEXCL-QM_CAT
      !IV_BLOCK_QM type ZPRD_PR_BLOCK_QM
      !IV_TEXT type ZPRD_PR_BLOCK_QM_TEXT
    raising
      ZCX_FORM_MESSAGE_ERROR .
    "! Visszaveszi a kategória kizárását: a kód és a QM-szöveg ürül, a DC-szöveg
    "! és a szövegsor megmarad. Nem commitol.
  methods UNBLOCK_CATEGORY
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
      !IV_QM_CAT type ZPRT_QMEXCL-QM_CAT
    raising
      ZCX_FORM_MESSAGE_ERROR .
    "! QM-engedélyezés: a stock DC státuszból QM-be lép, a jelzők a státusszal
    "! együtt változnak. Más státuszból kivételt ad. A státuszváltás commitol.
  methods RELEASE
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
    raising
      ZCX_FORM_MESSAGE_ERROR .
    "! A QM-engedélyezés visszavétele: a stock QM státuszból DC-be lép vissza, a
    "! QMCOMPL jelző kiürül. Más státuszból kivételt ad. A státuszváltás commitol.
  methods RELEASE_BACK
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
    raising
      ZCX_FORM_MESSAGE_ERROR .
    "! A stock végső engedélyezésének közlése az Inspire felé: a kizárást kapott
    "! dokumentumok borítékainak egyedi, nem üres listájával. Nem ír és nem
    "! commitol, a stock lezárását a hívó (cockpit) végzi sikeres válasz után.
    "! A gateway-hívás commitolja a hívás előtti módosításokat, ezért a hívás
    "! előtt nem lehet függő írás.
    "! @parameter iv_stock_id | a stock azonosítója
    "! @parameter iv_priority | a feldolgozás prioritása
    "! @parameter iv_require_compl | igaz esetén a DC- és a QM-engedélyezés is kötelező
    "! @parameter rs_result | az Inspire válasza; a success jelzi a sikert
  methods COMPLETE_STOCK
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
      !IV_PRIORITY type ZPRD_PRIORITY
      !IV_REQUIRE_COMPL type ABAP_BOOL default ABAP_TRUE
    returning
      value(RS_RESULT) type ZIF_PR_INSPIRE_GW=>TS_RESPONSE
    raising
      ZCX_FORM_MESSAGE_ERROR .
protected section.

  methods GET_OPEN_STOCK
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
    returning
      value(RS_STOCK) type ZPRT_STOCK
    raising
      ZCX_FORM_MESSAGE_ERROR .

  data MO_DATA type ref to ZIF_PR_QM_DATA .
  data MO_GATEWAY type ref to ZIF_PR_INSPIRE_GW .
private section.
ENDCLASS.



CLASS ZCL_PR_QM_EXCLUSION IMPLEMENTATION.


  METHOD constructor.
    " A függőségeket kívülről kapjuk, hogy a teszt dublőrt adhasson helyettük.
    mo_data    = io_data.
    mo_gateway = io_gateway.
  ENDMETHOD.


  METHOD lock_stock.
    " A zárolást az adatréteg végzi; ha más tartja, kivétel keletkezik.
    mo_data->lock_stock( iv_stock_id ).
  ENDMETHOD.


  METHOD unlock_stock.
    " A zárolás feloldása az adatrétegen át történik.
    mo_data->unlock_stock( iv_stock_id ).
  ENDMETHOD.


  METHOD get_open_stock.
    " Közös előfeltétel: a stock létezik és nincs lezárva. Az ellenőrzés a
    " zárolás után olvasott, friss adaton fut.
    rs_stock = mo_data->get_stock( iv_stock_id ).
    IF rs_stock IS INITIAL.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e018(zpr_qm)
        WITH CONV string( iv_stock_id ).
    ENDIF.
    IF rs_stock-closed IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e019(zpr_qm)
        WITH CONV string( iv_stock_id ).
    ENDIF.
  ENDMETHOD.


  METHOD check_editable.
    " A QM-oldali módosításhoz a stocknak nyitottnak kell lennie: nincs lezárva,
    " még nincs QM-engedélyezve, és nincs CL állapotban.
    DATA(ls_stock) = get_open_stock( iv_stock_id ).
    IF ls_stock-qmcompl IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e020(zpr_qm)
        WITH CONV string( iv_stock_id ).
    ENDIF.
    IF ls_stock-status EQ 'CL'.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e021(zpr_qm)
        WITH CONV string( iv_stock_id ).
    ENDIF.
  ENDMETHOD.


  METHOD block_category.
    " Előbb a stockot és a bemenetet ellenőrizzük, és csak utána írunk, hogy
    " hiba esetén ne maradjon félig elvégzett módosítás. A szöveg nélküli
    " kizárás törli a korábbi QM-szöveget, így a kód és a szöveg mindig összetartozik.
    check_editable( iv_stock_id ).

    IF iv_block_qm IS INITIAL.
      IF iv_text IS NOT INITIAL.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e023(zpr_qm).
      ENDIF.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e022(zpr_qm).
    ENDIF.

    IF mo_data->code_exists( iv_block_qm ) EQ abap_false.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e024(zpr_qm)
        WITH iv_block_qm.
    ENDIF.

    mo_data->set_block_qm( iv_stock_id = iv_stock_id
                           iv_qm_cat   = iv_qm_cat
                           iv_block_qm = iv_block_qm ).

    IF iv_text IS NOT INITIAL.
      mo_data->set_block_text( iv_stock_id = iv_stock_id
                               iv_qm_cat   = iv_qm_cat
                               iv_text     = iv_text ).
    ELSE.
      mo_data->clear_block_text( iv_stock_id = iv_stock_id
                                 iv_qm_cat   = iv_qm_cat ).
    ENDIF.

    mo_data->update_exclusion_row( iv_stock_id = iv_stock_id
                                   iv_qm_cat   = iv_qm_cat
                                   iv_block_qm = iv_block_qm
                                   iv_text     = iv_text ).
  ENDMETHOD.


  METHOD unblock_category.
    " Visszavételnél a kód és a QM-szöveg ürül; a szövegsor és a DC-szöveg
    " megmarad, mert azt a DC-kizárás használja.
    DATA lv_no_code TYPE zprd_pr_block_qm.
    DATA lv_no_text TYPE zprd_pr_block_qm_text.

    check_editable( iv_stock_id ).

    mo_data->set_block_qm( iv_stock_id = iv_stock_id
                           iv_qm_cat   = iv_qm_cat
                           iv_block_qm = lv_no_code ).
    mo_data->clear_block_text( iv_stock_id = iv_stock_id
                               iv_qm_cat   = iv_qm_cat ).
    mo_data->update_exclusion_row( iv_stock_id = iv_stock_id
                                   iv_qm_cat   = iv_qm_cat
                                   iv_block_qm = lv_no_code
                                   iv_text     = lv_no_text ).
  ENDMETHOD.


  METHOD release.
    " A QM-engedélyezés a DC -> QM státuszváltás; a döntést és az írást a
    " státuszváltás végzi, hibánál annak kivétele adja az okot. A QM-engedélyezés
    " után a kizárások már nem módosíthatók.
    mo_data->change_status( iv_stock_id = iv_stock_id
                            iv_from     = 'DC'
                            iv_to       = 'QM' ).
  ENDMETHOD.


  METHOD release_back.
    " A visszavétel a QM -> DC státuszváltás; a döntést és az írást a
    " státuszváltás végzi, hibánál annak kivétele adja az okot.
    mo_data->change_status( iv_stock_id = iv_stock_id
                            iv_from     = 'QM'
                            iv_to       = 'DC' ).
  ENDMETHOD.


  METHOD complete_stock.
    " Csak olvas és hív: a borítékok egyedi, nem üres listáját adjuk az Inspire-nak.
    " A lezárást (CLOSED, STATUS, PRIORITY) és a commitot a hívó végzi, de csak
    " sikeres válasz után; sikertelen válasznál semmi nem íródik.
    DATA(ls_stock) = get_open_stock( iv_stock_id ).

    IF iv_require_compl EQ abap_true.
      IF ls_stock-dccompl IS INITIAL.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e026(zpr_qm)
          WITH CONV string( iv_stock_id ).
      ENDIF.
      IF ls_stock-qmcompl IS INITIAL.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e027(zpr_qm)
          WITH CONV string( iv_stock_id ).
      ENDIF.
    ENDIF.

    " Az adatréteg listáját itt is megtisztítjuk, hogy a kapu mindig egyedi,
    " nem üres azonosítókat kapjon, akármilyen forrásból jön a lista.
    DATA(lt_envelope) = mo_data->get_blocked_envelopes( iv_stock_id ).
    DELETE lt_envelope WHERE table_line IS INITIAL.
    SORT lt_envelope.
    DELETE ADJACENT DUPLICATES FROM lt_envelope.

    rs_result = mo_gateway->dcqm_completed( iv_stock_id = iv_stock_id
                                            iv_priority = iv_priority
                                            it_envelope = lt_envelope ).
  ENDMETHOD.
ENDCLASS.