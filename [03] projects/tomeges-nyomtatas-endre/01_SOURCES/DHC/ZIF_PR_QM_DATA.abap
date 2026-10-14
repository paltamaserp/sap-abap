INTERFACE zif_pr_qm_data PUBLIC.

  TYPES tt_category TYPE STANDARD TABLE OF zprc_qmcat WITH DEFAULT KEY.
  TYPES tt_filter TYPE STANDARD TABLE OF zprc_qmcat_flt WITH DEFAULT KEY.
  TYPES tt_doc_no TYPE STANDARD TABLE OF zprd_doc_no WITH DEFAULT KEY.
  TYPES tt_package_id TYPE STANDARD TABLE OF zprd_package_id WITH DEFAULT KEY.
  TYPES tt_assignment TYPE STANDARD TABLE OF zprt_qmsample WITH DEFAULT KEY.
  TYPES tt_exclusion TYPE STANDARD TABLE OF zprt_qmexcl WITH DEFAULT KEY.

  TYPES:
    BEGIN OF ts_candidate,
      doc_no    TYPE zprt_dcqm-doc_no,
      doc_type  TYPE zprt_doc_log-doc_type,
      sparte    TYPE zprt_doc_log-sparte,
      vkont     TYPE zprt_doc_log-vkont,
      gpart     TYPE zprt_doc_log-gpart,
      bukrs     TYPE zprt_doc_log-bukrs,
      opbel     TYPE zprt_doc_log-opbel,
      channel   TYPE zprt_doc_log-channel,
      doc_cat   TYPE zprt_dcqm-doc_cat,
      mahns     TYPE zprt_dcqm-mahns,
      mahnv     TYPE zprt_dcqm-mahnv,
      amnt      TYPE zprt_dcqm-amnt,
      waers     TYPE zprt_dcqm-waers,
      zbizcat   TYPE zprt_dcqm-zbizcat,
      cotyp     TYPE zprt_dcqm-cotyp,
      form      TYPE zprt_dcqm-form,
      pymet     TYPE zprt_dcqm-pymet,
      land1     TYPE zprt_dcqm-land1,
      duedate   TYPE zprt_dcqm-duedate,
      tariftyp  TYPE zprt_dcqm-tariftyp,
      aklasse   TYPE zprt_dcqm-aklasse,
    END OF ts_candidate.
  TYPES tt_candidate TYPE STANDARD TABLE OF ts_candidate WITH DEFAULT KEY.

  TYPES tt_overview TYPE STANDARD TABLE OF zprs_qm_overview WITH DEFAULT KEY.
  TYPES tt_envelope TYPE STANDARD TABLE OF zprd_envelope_id WITH DEFAULT KEY.

  CONSTANTS c_filter_fields TYPE string VALUE `,DOC_TYPE,SPARTE,VKONT,GPART,BUKRS,OPBEL,CHANNEL,DOC_CAT,MAHNS,MAHNV,AMNT,` &
                                              `WAERS,ZBIZCAT,COTYP,FORM,PYMET,LAND1,DUEDATE,TARIFTYP,AKLASSE,`.

  METHODS get_categories
    RETURNING
      VALUE(rt_cat) TYPE tt_category.

  METHODS get_filters
    IMPORTING
      iv_qm_cat        TYPE zprc_qmcat-qm_cat
    RETURNING
      VALUE(rt_filter) TYPE tt_filter.

  METHODS get_candidates
    IMPORTING
      it_package_id        TYPE tt_package_id
    RETURNING
      VALUE(rt_candidate)  TYPE tt_candidate.

  METHODS insert_assignments
    IMPORTING
      it_assignment TYPE tt_assignment
    RAISING
      zcx_form_message_error.

  METHODS insert_exclusion_rows
    IMPORTING
      it_exclusion TYPE tt_exclusion
    RAISING
      zcx_form_message_error.

  METHODS update_dcqm_stock
    IMPORTING
      it_doc_no   TYPE tt_doc_no
      iv_stock_id TYPE zprd_stock_id
    RAISING
      zcx_form_message_error.

  "! A stock fejsora; ha a stock nem létezik, a visszaadott struktúra üres.
  METHODS get_stock
    IMPORTING
      iv_stock_id     TYPE zprd_stock_id
    RETURNING
      VALUE(rs_stock) TYPE zprt_stock.

  "! A stock kategóriánkénti áttekintése: kizárási állapot, leírás, a tagok
  "! száma és a mintába került tagok száma.
  METHODS get_overview
    IMPORTING
      iv_stock_id         TYPE zprd_stock_id
    RETURNING
      VALUE(rt_overview)  TYPE tt_overview.

  "! Zárolja a stockot (szerkesztési zárolás).
  METHODS lock_stock
    IMPORTING
      iv_stock_id TYPE zprd_stock_id
    RAISING
      zcx_form_message_error.

  "! Feloldja a stock zárolását.
  METHODS unlock_stock
    IMPORTING
      iv_stock_id TYPE zprd_stock_id
    RAISING
      zcx_form_message_error.

  "! Igaz, ha a kizárási kód szerepel az érvényes kódok között.
  METHODS code_exists
    IMPORTING
      iv_block_qm      TYPE zprd_pr_block_qm
    RETURNING
      VALUE(rv_exists) TYPE abap_bool.

  "! Beállítja a stock és a kategória összes dokumentumának QM-kizárási kódját
  "! (üres kód: visszavétel). Nem commitol.
  METHODS set_block_qm
    IMPORTING
      iv_stock_id TYPE zprd_stock_id
      iv_qm_cat   TYPE zprt_qmexcl-qm_cat
      iv_block_qm TYPE zprd_pr_block_qm
    RAISING
      zcx_form_message_error.

  "! Beírja a QM-kizárás szövegét a kategória összes dokumentumához: ha van
  "! szövegsor, módosítja, különben új sort vesz fel üres DC-szöveggel.
  METHODS set_block_text
    IMPORTING
      iv_stock_id TYPE zprd_stock_id
      iv_qm_cat   TYPE zprt_qmexcl-qm_cat
      iv_text     TYPE zprd_pr_block_qm_text
    RAISING
      zcx_form_message_error.

  "! Kiüríti a kategória dokumentumainak QM-szövegét. A szövegsor és a
  "! DC-szöveg megmarad.
  METHODS clear_block_text
    IMPORTING
      iv_stock_id TYPE zprd_stock_id
      iv_qm_cat   TYPE zprt_qmexcl-qm_cat
    RAISING
      zcx_form_message_error.

  "! Frissíti a stock és a kategória kizárási sorát (kód és szöveg).
  METHODS update_exclusion_row
    IMPORTING
      iv_stock_id TYPE zprd_stock_id
      iv_qm_cat   TYPE zprt_qmexcl-qm_cat
      iv_block_qm TYPE zprd_pr_block_qm
      iv_text     TYPE zprd_pr_block_qm_text
    RAISING
      zcx_form_message_error.

  "! Beállítja a stock QM-engedélyezési jelzőjét (X, vagy üres a visszavételhez).
  METHODS set_qmcompl
    IMPORTING
      iv_stock_id TYPE zprd_stock_id
      iv_value    TYPE zprd_qmcompl
    RAISING
      zcx_form_message_error.

  "! A stock azon dokumentumainak borítékai (egyedi, nem üres lista), ahol a
  "! DC- vagy a QM-kizárási kód ki van töltve.
  METHODS get_blocked_envelopes
    IMPORTING
      iv_stock_id         TYPE zprd_stock_id
    RETURNING
      VALUE(rt_envelope)  TYPE tt_envelope.

ENDINTERFACE.