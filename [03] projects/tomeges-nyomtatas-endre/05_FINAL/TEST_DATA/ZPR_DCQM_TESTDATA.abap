REPORT zpr_dcqm_testdata.

*&---------------------------------------------------------------------*
*& Report ZPR_DCQM_TESTDATA
*---------------------------------------------------------------*
* Rövid leírás: Tesztadat-feltöltő a ZPR_DCQM_EXCLUDE (DC kizárás)
*               és a ZPR_DC_FRAME teszteléséhez
* Projekt:      CSHANA 2026
* Fejlesztő:    <USER>
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.10.14.   <USER>        Létrehozva
*---------------------------------------------------------------*
* Csak nem éles mandantban fut (T000-CCCATEGORY <> 'P').
*
* Érintett táblák: ZPRT_STOCK, ZPRT_DCQM, ZPRT_DCQMLT, ZPRC_DCCODE.
* A tesztrekordok jelölése:
*   - Stock ID 9900000001-9900000005, DOC_NO 'TESZT-DC-*'
*   - CRUSER = 'ZPR_TESZT' (ZPRT_STOCK, ZPRT_DCQM)
*   - T1, T2 DC-kód: a szöveg 'TESZT:' kezdetű. A 'ZZ' kódot csak
*     felveszi, ha hiányzik, és soha nem törli.
* Jelölés nélküli (idegen) rekordot a program nem ír felül és nem
* töröl: kulcsütközésnél adatbázis-módosítás nélkül leáll.
* A 9900000099 stock nem létezhet (nem létező stock teszteset).
*
* A ZPRT_DCQM sorai a TEST_DATA mappa TSV-fájljával és leírásával
* azonos forrásból készültek - módosításkor mindhármat frissíteni kell.
*
* Szövegelemek:
*   TEXT-001 Művelet               TEXT-002 Futtatás
*   A többi szövegszimbólum literál-alapértékkel szerepel a kódban
*   ('...'(xxx)), SE38 -> Szövegelemek -> "Összehasonlítás" felveszi.
*   Szelekciós szövegek: P_LOAD Feltöltés, P_RESET Alaphelyzet
*   (törlés + feltöltés), P_DEL Törlés, P_TEST Tesztfutás.
*---------------------------------------------------------------*

*---------------------------------------------------------------*
* Típusok
*---------------------------------------------------------------*
TYPES: ty_amount_ext TYPE p LENGTH 13 DECIMALS 2,
       BEGIN OF ty_stock_db,
         stock_id TYPE zprt_stock-stock_id,
         cruser   TYPE zprt_stock-cruser,
       END OF ty_stock_db,
       BEGIN OF ty_dcqm_db,
         doc_no TYPE zprt_dcqm-doc_no,
         cruser TYPE zprt_dcqm-cruser,
       END OF ty_dcqm_db.

*---------------------------------------------------------------*
* Konstansok
*---------------------------------------------------------------*
CONSTANTS:
  gc_marker      TYPE zprt_dcqm-cruser VALUE 'ZPR_TESZT',
  gc_doc_pattern TYPE zprd_doc_no      VALUE 'TESZT-DC-*'.

* Teszt-stockok
CONSTANTS:
  gc_stock_s1   TYPE zprd_stock_id VALUE '9900000001', "nyitott, kizárási tesztek
  gc_stock_s2   TYPE zprd_stock_id VALUE '9900000002', "lezárt (CL)
  gc_stock_s3   TYPE zprd_stock_id VALUE '9900000003', "DC kész (DM)
  gc_stock_s4   TYPE zprd_stock_id VALUE '9900000004', "nyitott, sor nélkül
  gc_stock_s5   TYPE zprd_stock_id VALUE '9900000005', "nyitott, DC engedélyezés
  gc_stock_none TYPE zprd_stock_id VALUE '9900000099'. "nem létezhet

* DC-kódok
* ⚠️ A ZPRC_DCCODE szövegmezőjének neve SE11-ben ellenőrizendő (QU5:
* DESCR40). Eltérő név esetén a kódok szöveg nélkül kerülnek be, és a
* T1/T2 törlése elmarad (nincs 'TESZT:' jelölés).
CONSTANTS:
  gc_dc_envelope TYPE zprd_pr_block_dc VALUE 'ZZ',
  gc_dc_test1    TYPE zprd_pr_block_dc VALUE 'T1',
  gc_dc_test2    TYPE zprd_pr_block_dc VALUE 'T2',
  gc_dc_invalid  TYPE zprd_pr_block_dc VALUE 'XX', "nem létezhet
  gc_dccode_text TYPE fieldname        VALUE 'DESCR40'.

*---------------------------------------------------------------*
* Globális adatok
*---------------------------------------------------------------*
DATA: gt_stock  TYPE STANDARD TABLE OF zprt_stock,
      gt_dcqm   TYPE STANDARD TABLE OF zprt_dcqm,
      gt_dcqmlt TYPE STANDARD TABLE OF zprt_dcqmlt,
      gt_dccode TYPE STANDARD TABLE OF zprc_dccode, "csak a hiányzók
      gt_locked TYPE STANDARD TABLE OF zprd_stock_id,
      gr_stock  TYPE RANGE OF zprd_stock_id,
      gr_docno  TYPE RANGE OF zprd_doc_no.

DATA: gv_ok          TYPE abap_bool,
      gv_own_stock   TYPE i,
      gv_own_dcqm    TYPE i,
      gv_own_dcqmlt  TYPE i,
      gv_del_stock   TYPE i,
      gv_del_dcqm    TYPE i,
      gv_del_dcqmlt  TYPE i,
      gv_del_dccode  TYPE i.

*---------------------------------------------------------------*
* Szelekciós képernyő
*---------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_load  RADIOBUTTON GROUP mod DEFAULT 'X',
            p_reset RADIOBUTTON GROUP mod,
            p_del   RADIOBUTTON GROUP mod.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_test AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b02.

*----------------------------------------------------------------------*
* START-OF-SELECTION                                                   *
*----------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM check_client.

  PERFORM build_ranges.
  PERFORM build_stock.
  PERFORM build_dcqm.
  PERFORM build_dcqmlt.
  PERFORM build_dccode.

* A riport és a keretprogram ugyanezt a zárat használja: futó teszt
* közben nem írjuk felül a stockot
  PERFORM lock_stocks CHANGING gv_ok.
  IF gv_ok EQ abap_true.
    PERFORM check_existing CHANGING gv_ok.
  ENDIF.
  IF gv_ok EQ abap_true.
    PERFORM process.
  ENDIF.
  PERFORM unlock_stocks.

  PERFORM write_rows.

*&---------------------------------------------------------------------*
*&      Form  CHECK_CLIENT
*&---------------------------------------------------------------------*
*       Éles mandantban nem fut
*----------------------------------------------------------------------*
FORM check_client .

  DATA: lv_category TYPE t000-cccategory.

  SELECT SINGLE cccategory FROM t000
    INTO @lv_category
    WHERE mandt = @sy-mandt.
  IF sy-subrc <> 0 OR lv_category EQ 'P'.
    MESSAGE 'Éles mandantban a tesztadat-feltöltés nem engedélyezett.'(e01)
            TYPE 'I' DISPLAY LIKE 'E'.
    LEAVE LIST-PROCESSING.
  ENDIF.

ENDFORM.                    " CHECK_CLIENT
*&---------------------------------------------------------------------*
*&      Form  BUILD_RANGES
*&---------------------------------------------------------------------*
FORM build_ranges .

  DATA: ls_stock LIKE LINE OF gr_stock,
        ls_docno LIKE LINE OF gr_docno.

  ls_stock-sign   = 'I'.
  ls_stock-option = 'BT'.
  ls_stock-low    = gc_stock_s1.
  ls_stock-high   = gc_stock_s5.
  APPEND ls_stock TO gr_stock.

  ls_docno-sign   = 'I'.
  ls_docno-option = 'CP'.
  ls_docno-low    = gc_doc_pattern.
  APPEND ls_docno TO gr_docno.

ENDFORM.                    " BUILD_RANGES
*&---------------------------------------------------------------------*
*&      Form  BUILD_STOCK
*&---------------------------------------------------------------------*
FORM build_stock .

  DATA: ls_stock TYPE zprt_stock.

* S1 - nyitott, a kizárási tesztek fő stockja
  PERFORM init_stock USING gc_stock_s1 CHANGING ls_stock.
  APPEND ls_stock TO gt_stock.

* S2 - lezárt: csak megjelenítés
  PERFORM init_stock USING gc_stock_s2 CHANGING ls_stock.
  ls_stock-status    = 'CL'.
  ls_stock-closed    = abap_true.
  ls_stock-dccompl   = abap_true.
  ls_stock-qmcompl   = abap_true.
  ls_stock-priority  = '05'.
  ls_stock-erdat_clo = sy-datum.
  ls_stock-ernam_clo = gc_marker.
  ls_stock-ertim_clo = sy-uzeit.
  APPEND ls_stock TO gt_stock.

* S3 - DC kész: nem módosítható
  PERFORM init_stock USING gc_stock_s3 CHANGING ls_stock.
  ls_stock-status  = 'DM'.
  ls_stock-dccompl = abap_true.
  APPEND ls_stock TO gt_stock.

* S4 - nyitott, ZPRT_DCQM sor nélkül
  PERFORM init_stock USING gc_stock_s4 CHANGING ls_stock.
  APPEND ls_stock TO gt_stock.

* S5 - nyitott, DC engedélyezés / visszavétel
  PERFORM init_stock USING gc_stock_s5 CHANGING ls_stock.
  APPEND ls_stock TO gt_stock.

ENDFORM.                    " BUILD_STOCK
*&---------------------------------------------------------------------*
*&      Form  INIT_STOCK
*&---------------------------------------------------------------------*
FORM init_stock USING    uv_stock_id TYPE zprd_stock_id
                CHANGING cs_stock    TYPE zprt_stock.

  CLEAR cs_stock.
  cs_stock-stock_id = uv_stock_id.
  cs_stock-cruser   = gc_marker.
  cs_stock-crdate   = sy-datum.
  cs_stock-crtime   = sy-uzeit.
  cs_stock-erdat    = sy-datum.
  cs_stock-ernam    = gc_marker.
  cs_stock-ertim    = sy-uzeit.

ENDFORM.                    " INIT_STOCK
*&---------------------------------------------------------------------*
*&      Form  BUILD_DCQM
*&---------------------------------------------------------------------*
*       Generált sorok - forrás: TEST_DATA leírás / TSV
*----------------------------------------------------------------------*
FORM build_dcqm .

  DATA: ls_dcqm   TYPE zprt_dcqm,
        lv_amount TYPE ty_amount_ext.

* TESZT-DC-S1-01 - Háromsoros boríték (1/3): kizárás, ZZ-társak, visszavonás
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-01'.
  ls_dcqm-envelope       = 'TDCENV001'.
  ls_dcqm-name1          = 'Teszt Elek'.
  ls_dcqm-cheqnumbr      = '9900001'.
  lv_amount = '12500'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-02 - Háromsoros boríték (2/3): erre szűrve 3 sorra bővül
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-02'.
  ls_dcqm-envelope       = 'TDCENV001'.
  ls_dcqm-name1          = 'Teszt Elek'.
  ls_dcqm-cheqnumbr      = '9900002'.
  lv_amount = '8900'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-03 - Háromsoros boríték (3/3): felszólítás
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-03'.
  ls_dcqm-envelope       = 'TDCENV001'.
  ls_dcqm-name1          = 'Teszt Elek'.
  ls_dcqm-doc_cat        = 'F'.
  ls_dcqm-zbizcat        = 'FELS'.
  ls_dcqm-mahns          = '01'.
  ls_dcqm-mahnv          = '01'.
  ls_dcqm-form           = 'ZPR_TESZT_FELSZ'.
  ls_dcqm-cheqnumbr      = '9900003'.
  ls_dcqm-regmailnumber  = 'RL990000003HU'.
  lv_amount = '3100'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-04 - Egysoros boríték; HUF 5 000 = az összegszűrés egyetlen HUF-találata
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-04'.
  ls_dcqm-envelope       = 'TDCENV002'.
  ls_dcqm-name1          = 'Minta Anna'.
  ls_dcqm-pymet          = 'D'.
  ls_dcqm-duedate        = '20261020'.
  ls_dcqm-bankaccountnum = '11773016-99000004-00000000'.
  lv_amount = '5000'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-05 - Üres boríték: a kizárás csak ezt a sort érinti
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-05'.
  ls_dcqm-name1          = 'Próba Péter'.
  ls_dcqm-cheqnumbr      = '9900005'.
  lv_amount = '7800'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-06 - Üres boríték; HUF 500 000 = belső 5000.00 (tizedes-korrekció csapda)
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-06'.
  ls_dcqm-name1          = 'Kísérleti Kft.'.
  ls_dcqm-pymet          = 'U'.
  ls_dcqm-bankaccountnum = '11773016-99000006-00000000'.
  ls_dcqm-tariftyp       = 'TESZT_B2'.
  ls_dcqm-aklasse        = 'NEM'.
  lv_amount = '500000'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-07 - Előre kizárt boríték: saját kód T1 + szöveg
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-07'.
  ls_dcqm-envelope       = 'TDCENV003'.
  ls_dcqm-name1          = 'Gipsz Jakab'.
  ls_dcqm-cheqnumbr      = '9900007'.
  ls_dcqm-block_dc       = 'T1'.
  lv_amount = '15000'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-08 - Előre kizárt boríték: ZZ-társ
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-08'.
  ls_dcqm-envelope       = 'TDCENV003'.
  ls_dcqm-name1          = 'Gipsz Jakab'.
  ls_dcqm-cheqnumbr      = '9900008'.
  ls_dcqm-block_dc       = 'ZZ'.
  lv_amount = '2200'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-09 - Előre kizárt boríték: ZZ-társ
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-09'.
  ls_dcqm-envelope       = 'TDCENV003'.
  ls_dcqm-name1          = 'Gipsz Jakab'.
  ls_dcqm-cheqnumbr      = '9900009'.
  ls_dcqm-block_dc       = 'ZZ'.
  lv_amount = '4600'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-10 - Vegyes boríték: saját T2 ok, ZZ nem írhatja felül
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-10'.
  ls_dcqm-envelope       = 'TDCENV004'.
  ls_dcqm-name1          = 'Példa Piroska'.
  ls_dcqm-cheqnumbr      = '9900010'.
  ls_dcqm-block_dc       = 'T2'.
  lv_amount = '21000'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-11 - Vegyes boríték: nyitott, ezt zárjuk ki T1-gyel
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-11'.
  ls_dcqm-envelope       = 'TDCENV004'.
  ls_dcqm-name1          = 'Példa Piroska'.
  ls_dcqm-cheqnumbr      = '9900011'.
  lv_amount = '9990'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-12 - Vegyes boríték: nyitott, ZZ-t kap
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-12'.
  ls_dcqm-envelope       = 'TDCENV004'.
  ls_dcqm-name1          = 'Példa Piroska'.
  ls_dcqm-cheqnumbr      = '9900012'.
  lv_amount = '1250'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-13 - EUR 5 000; QM-kód + QM-szöveg (QM-szöveg védelme)
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-13'.
  ls_dcqm-envelope       = 'TDCENV005'.
  ls_dcqm-name1          = 'Minta Anna'.
  ls_dcqm-pymet          = 'U'.
  ls_dcqm-waers          = 'EUR'.
  ls_dcqm-bankaccountnum = '11773016-99000013-00000000'.
  ls_dcqm-block_qm       = 'Q1'.
  lv_amount = '5000.00'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-14 - Kétsoros boríték, 2. szintű felszólítás: cellás szerkesztés
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-14'.
  ls_dcqm-envelope       = 'TDCENV006'.
  ls_dcqm-name1          = 'Teszt Ödön'.
  ls_dcqm-doc_cat        = 'F'.
  ls_dcqm-duedate        = '20261115'.
  ls_dcqm-zbizcat        = 'FELS'.
  ls_dcqm-mahns          = '02'.
  ls_dcqm-mahnv          = '01'.
  ls_dcqm-form           = 'ZPR_TESZT_FELSZ'.
  ls_dcqm-cheqnumbr      = '9900014'.
  ls_dcqm-regmailnumber  = 'RL990000014HU'.
  ls_dcqm-laufi          = 'TDC02'.
  lv_amount = '33000'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S1-15 - Kétsoros boríték, külföldi cím (AT)
  PERFORM init_dcqm USING gc_stock_s1 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S1-15'.
  ls_dcqm-envelope       = 'TDCENV006'.
  ls_dcqm-name1          = 'Teszt Ödön'.
  ls_dcqm-duedate        = '20261115'.
  ls_dcqm-land1          = 'AT'.
  ls_dcqm-cheqnumbr      = '9900015'.
  ls_dcqm-laufi          = 'TDC02'.
  lv_amount = '640'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S2-01 - Lezárt stock: ZZ-társ
  PERFORM init_dcqm USING gc_stock_s2 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S2-01'.
  ls_dcqm-envelope       = 'TDCENV101'.
  ls_dcqm-name1          = 'Lezárt Lajos'.
  ls_dcqm-cheqnumbr      = '9900101'.
  ls_dcqm-block_dc       = 'ZZ'.
  lv_amount = '4100'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S2-02 - Lezárt stock: saját T1
  PERFORM init_dcqm USING gc_stock_s2 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S2-02'.
  ls_dcqm-envelope       = 'TDCENV101'.
  ls_dcqm-name1          = 'Lezárt Lajos'.
  ls_dcqm-cheqnumbr      = '9900102'.
  ls_dcqm-block_dc       = 'T1'.
  lv_amount = '2900'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S3-01 - DC kész stock: nyitott sor
  PERFORM init_dcqm USING gc_stock_s3 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S3-01'.
  ls_dcqm-envelope       = 'TDCENV201'.
  ls_dcqm-name1          = 'Kész Klára'.
  ls_dcqm-cheqnumbr      = '9900201'.
  lv_amount = '6600'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S3-02 - DC kész stock: kizárt sor (T2)
  PERFORM init_dcqm USING gc_stock_s3 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S3-02'.
  ls_dcqm-envelope       = 'TDCENV202'.
  ls_dcqm-name1          = 'Kész Klára'.
  ls_dcqm-cheqnumbr      = '9900202'.
  ls_dcqm-block_dc       = 'T2'.
  lv_amount = '1800'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S5-01 - Ugyanaz a borítékazonosító, mint S1-ben: nem kerülhet be az S1 bővítésébe
  PERFORM init_dcqm USING gc_stock_s5 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S5-01'.
  ls_dcqm-envelope       = 'TDCENV001'.
  ls_dcqm-name1          = 'Másik Márton'.
  ls_dcqm-cheqnumbr      = '9900501'.
  lv_amount = '4000'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S5-02 - DC engedélyezés: kizárt (T1)
  PERFORM init_dcqm USING gc_stock_s5 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S5-02'.
  ls_dcqm-envelope       = 'TDCENV501'.
  ls_dcqm-name1          = 'Engedély Endre'.
  ls_dcqm-cheqnumbr      = '9900502'.
  ls_dcqm-block_dc       = 'T1'.
  lv_amount = '7300'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S5-03 - DC engedélyezés: ZZ-társ
  PERFORM init_dcqm USING gc_stock_s5 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S5-03'.
  ls_dcqm-envelope       = 'TDCENV501'.
  ls_dcqm-name1          = 'Engedély Endre'.
  ls_dcqm-cheqnumbr      = '9900503'.
  ls_dcqm-block_dc       = 'ZZ'.
  lv_amount = '2700'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

* TESZT-DC-S5-04 - DC engedélyezés: nyitott, üres boríték
  PERFORM init_dcqm USING gc_stock_s5 CHANGING ls_dcqm.
  ls_dcqm-doc_no         = 'TESZT-DC-S5-04'.
  ls_dcqm-name1          = 'Engedély Endre'.
  ls_dcqm-cheqnumbr      = '9900504'.
  lv_amount = '990'.
  PERFORM append_dcqm USING lv_amount CHANGING ls_dcqm.

ENDFORM.                    " BUILD_DCQM
*&---------------------------------------------------------------------*
*&      Form  INIT_DCQM
*&---------------------------------------------------------------------*
*       Alapértékek; a BUILD_DCQM csak az eltéréseket állítja
*----------------------------------------------------------------------*
FORM init_dcqm USING    uv_stock_id TYPE zprd_stock_id
               CHANGING cs_dcqm     TYPE zprt_dcqm.

  CLEAR cs_dcqm.
  cs_dcqm-prd_stock_id   = uv_stock_id.
  cs_dcqm-pymet          = 'C'.
  cs_dcqm-doc_cat        = 'S'.
  cs_dcqm-waers          = 'HUF'.
  cs_dcqm-duedate        = '20261031'.
  cs_dcqm-bankaccountnum = '11773016-99000000-00000000'.
  cs_dcqm-giro           = 'TESZTGIRO01'.
  cs_dcqm-sysid          = 'DHC'.
  cs_dcqm-land1          = 'HU'.
  cs_dcqm-ab             = '20260901'.
  cs_dcqm-bis            = '20260930'.
  cs_dcqm-tariftyp       = 'TESZT_A1'.
  cs_dcqm-aklasse        = 'LAK'.
  cs_dcqm-zbizcat        = 'SZLA'.
  cs_dcqm-form           = 'ZPR_TESZT_SZAMLA'.
  cs_dcqm-cotyp          = 'ZPR1'.
  cs_dcqm-package_id     = '0099000001'.
  cs_dcqm-opbuk_pr       = 'T01'.
  cs_dcqm-aktyp          = 'ZPRT'.
  cs_dcqm-laufd          = '20261014'.
  cs_dcqm-laufi          = 'TDC01'.
  cs_dcqm-prdfile        = '0001'.

ENDFORM.                    " INIT_DCQM
*&---------------------------------------------------------------------*
*&      Form  APPEND_DCQM
*&---------------------------------------------------------------------*
*       Származtatott és technikai mezők, összeg belső formára
*----------------------------------------------------------------------*
FORM append_dcqm USING    uv_amount TYPE ty_amount_ext
                 CHANGING cs_dcqm   TYPE zprt_dcqm.

  PERFORM to_internal_amount USING    uv_amount
                                      cs_dcqm-waers
                             CHANGING cs_dcqm-amnt.

  cs_dcqm-cokey   = cs_dcqm-doc_no.
  CONCATENATE 'Q1' cs_dcqm-prd_stock_id INTO cs_dcqm-prdspool.
  cs_dcqm-counter = 1.
  cs_dcqm-cruser  = gc_marker.
  cs_dcqm-crdate  = sy-datum.
  cs_dcqm-crtime  = sy-uzeit.

  APPEND cs_dcqm TO gt_dcqm.

ENDFORM.                    " APPEND_DCQM
*&---------------------------------------------------------------------*
*&      Form  TO_INTERNAL_AMOUNT
*&---------------------------------------------------------------------*
*       A riport BUILD_RANGES logikája: a CURR mező belső értéke a DDIC
*       tizedesjegyein (AMNT: 2) alapul, a pénznemé a TCURX-ben van
*       (HUF: 0). Így 5 000 HUF belső értéke 50.00.
*----------------------------------------------------------------------*
FORM to_internal_amount USING    uv_amount TYPE ty_amount_ext
                                 uv_waers  TYPE zprt_dcqm-waers
                        CHANGING cv_amnt   TYPE zprt_dcqm-amnt.

  DATA: lv_ddic_dec TYPE i,
        lv_faktor   TYPE i,
        ls_tcurx    TYPE tcurx.

  DESCRIBE FIELD cv_amnt DECIMALS lv_ddic_dec.

  SELECT SINGLE * FROM tcurx
    INTO @ls_tcurx
    WHERE currkey = @uv_waers.
  IF sy-subrc <> 0.
    ls_tcurx-currdec = lv_ddic_dec.
  ENDIF.
  lv_faktor = lv_ddic_dec - ls_tcurx-currdec.

  cv_amnt = uv_amount / ( 10 ** lv_faktor ).

ENDFORM.                    " TO_INTERNAL_AMOUNT
*&---------------------------------------------------------------------*
*&      Form  BUILD_DCQMLT
*&---------------------------------------------------------------------*
FORM build_dcqmlt .

* Előre kizárt boríték (S1, TDCENV003): a kód és a ZZ-társak szövege
  PERFORM add_dcqmlt USING 'TESZT-DC-S1-07'
                           'TESZT: hibás levelezési cím' ''.
  PERFORM add_dcqmlt USING 'TESZT-DC-S1-08'
                           'TESZT: hibás levelezési cím' ''.
  PERFORM add_dcqmlt USING 'TESZT-DC-S1-09'
                           'TESZT: hibás levelezési cím' ''.
* Vegyes boríték (S1, TDCENV004): saját ok
  PERFORM add_dcqmlt USING 'TESZT-DC-S1-10'
                           'TESZT: vitatott összeg, ügyfélpanasz folyamatban' ''.
* Csak QM-szöveg: DC-mentéskor meg kell maradnia
  PERFORM add_dcqmlt USING 'TESZT-DC-S1-13'
                           '' 'TESZT QM: nyomdai minőségi eltérés'.
* Lezárt stock (S2)
  PERFORM add_dcqmlt USING 'TESZT-DC-S2-01'
                           'TESZT: lezárt stock kizárt borítékja' ''.
  PERFORM add_dcqmlt USING 'TESZT-DC-S2-02'
                           'TESZT: lezárt stock kizárt borítékja' ''.
* DC kész stock (S3)
  PERFORM add_dcqmlt USING 'TESZT-DC-S3-02'
                           'TESZT: DC kész stock kizárt sora' ''.
* DC engedélyezés (S5)
  PERFORM add_dcqmlt USING 'TESZT-DC-S5-02'
                           'TESZT: szerződés megszűnt' ''.
  PERFORM add_dcqmlt USING 'TESZT-DC-S5-03'
                           'TESZT: szerződés megszűnt' ''.

ENDFORM.                    " BUILD_DCQMLT
*&---------------------------------------------------------------------*
*&      Form  ADD_DCQMLT
*&---------------------------------------------------------------------*
FORM add_dcqmlt USING uv_doc_no  TYPE csequence
                      uv_dc_text TYPE csequence
                      uv_qm_text TYPE csequence.

  DATA: ls_dcqmlt TYPE zprt_dcqmlt.

  ls_dcqmlt-exbilldocno   = uv_doc_no.
  ls_dcqmlt-block_dc_text = uv_dc_text.
  ls_dcqmlt-block_qm_text = uv_qm_text.
  APPEND ls_dcqmlt TO gt_dcqmlt.

ENDFORM.                    " ADD_DCQMLT
*&---------------------------------------------------------------------*
*&      Form  BUILD_DCCODE
*&---------------------------------------------------------------------*
*       Jelöltek; a CHECK_EXISTING kiveszi a már meglévő kódokat
*----------------------------------------------------------------------*
FORM build_dccode .

* A borítéktársak kódja - a riport mentése nélküle elhasal
  PERFORM add_dccode USING gc_dc_envelope 'Borítékban kizárt tétel'.
  PERFORM add_dccode USING gc_dc_test1    'TESZT: hibás cím'.
  PERFORM add_dccode USING gc_dc_test2    'TESZT: vitatott összeg'.

ENDFORM.                    " BUILD_DCCODE
*&---------------------------------------------------------------------*
*&      Form  ADD_DCCODE
*&---------------------------------------------------------------------*
FORM add_dccode USING uv_block_dc TYPE zprd_pr_block_dc
                      uv_text     TYPE csequence.

  DATA: ls_dccode TYPE zprc_dccode.
  FIELD-SYMBOLS: <lv_text> TYPE any.

  ls_dccode-block_dc = uv_block_dc.
  ASSIGN COMPONENT gc_dccode_text OF STRUCTURE ls_dccode TO <lv_text>.
  IF sy-subrc EQ 0.
    <lv_text> = uv_text.
  ENDIF.
  APPEND ls_dccode TO gt_dccode.

ENDFORM.                    " ADD_DCCODE
*&---------------------------------------------------------------------*
*&      Form  LOCK_STOCKS
*&---------------------------------------------------------------------*
FORM lock_stocks CHANGING cv_ok TYPE abap_bool.

  DATA: ls_stock TYPE zprt_stock,
        lv_text  TYPE string.

  cv_ok = abap_true.

  LOOP AT gt_stock INTO ls_stock.
    CALL FUNCTION 'ENQUEUE_EZPRT_STOCK'
      EXPORTING
        stock_id       = ls_stock-stock_id
        _scope         = '1'
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      cv_ok = abap_false.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_text.
      WRITE: / icon_red_light AS ICON,
               'Stock zárolása sikertelen:'(o01), ls_stock-stock_id,
             / lv_text.
      RETURN.
    ENDIF.
    APPEND ls_stock-stock_id TO gt_locked.
  ENDLOOP.

ENDFORM.                    " LOCK_STOCKS
*&---------------------------------------------------------------------*
*&      Form  UNLOCK_STOCKS
*&---------------------------------------------------------------------*
FORM unlock_stocks .

  DATA: lv_stock_id TYPE zprd_stock_id.

  LOOP AT gt_locked INTO lv_stock_id.
    CALL FUNCTION 'DEQUEUE_EZPRT_STOCK'
      EXPORTING
        stock_id = lv_stock_id
        _scope   = '1'.
  ENDLOOP.
  REFRESH gt_locked.

ENDFORM.                    " UNLOCK_STOCKS
*&---------------------------------------------------------------------*
*&      Form  CHECK_EXISTING
*&---------------------------------------------------------------------*
*       Meglévő saját tesztadat számlálása, idegen rekord a teszt-
*       kulcsokon -> leállás. DC-kódok: a meglévők nem kerülnek be.
*----------------------------------------------------------------------*
FORM check_existing CHANGING cv_ok TYPE abap_bool.

  DATA: lt_stock_db TYPE STANDARD TABLE OF ty_stock_db,
        ls_stock_db TYPE ty_stock_db,
        lt_dcqm_db  TYPE STANDARD TABLE OF ty_dcqm_db,
        ls_dcqm_db  TYPE ty_dcqm_db,
        lt_code_db  TYPE STANDARD TABLE OF zprc_dccode,
        ls_code_db  TYPE zprc_dccode,
        lv_stock_id TYPE zprd_stock_id,
        lv_text     TYPE string.
  FIELD-SYMBOLS: <lv_text> TYPE any.

  cv_ok = abap_true.

* Stockok
  SELECT stock_id, cruser FROM zprt_stock
    INTO TABLE @lt_stock_db
    WHERE stock_id IN @gr_stock.
  LOOP AT lt_stock_db INTO ls_stock_db.
    IF ls_stock_db-cruser EQ gc_marker.
      gv_own_stock = gv_own_stock + 1.
    ELSE.
      cv_ok = abap_false.
      WRITE: / icon_red_light AS ICON,
               'Idegen stock a tesztkulcson:'(o02), ls_stock_db-stock_id.
    ENDIF.
  ENDLOOP.

  SELECT SINGLE stock_id FROM zprt_stock
    INTO @lv_stock_id
    WHERE stock_id = @gc_stock_none.
  IF sy-subrc EQ 0.
    WRITE: / icon_yellow_light AS ICON,
             'Létező stock, a "nem létező stock" teszthez másik kell:'(o03),
             gc_stock_none.
  ENDIF.

* Dokumentumok: a tesztkulcsok és a teszt-stockok összes sora
  SELECT doc_no, cruser FROM zprt_dcqm
    INTO TABLE @lt_dcqm_db
    WHERE doc_no       IN @gr_docno
       OR prd_stock_id IN @gr_stock.
  LOOP AT lt_dcqm_db INTO ls_dcqm_db.
    IF ls_dcqm_db-cruser EQ gc_marker.
      gv_own_dcqm = gv_own_dcqm + 1.
    ELSE.
      cv_ok = abap_false.
      WRITE: / icon_red_light AS ICON,
               'Idegen dokumentum a tesztkulcson / teszt-stockban:'(o04),
               ls_dcqm_db-doc_no.
    ENDIF.
  ENDLOOP.

* Hosszú szövegek: a 'TESZT-DC-' előtag a miénk
  SELECT COUNT(*) FROM zprt_dcqmlt
    INTO @gv_own_dcqmlt
    WHERE exbilldocno IN @gr_docno.

  IF p_load EQ abap_true
     AND ( gv_own_stock  GT 0
        OR gv_own_dcqm   GT 0
        OR gv_own_dcqmlt GT 0 ).
    cv_ok = abap_false.
    WRITE: / icon_red_light AS ICON,
             'Már van betöltött tesztadat - használja az Alaphelyzet módot.'(o05).
  ENDIF.

* DC-kódok: a meglévőt változatlanul használjuk
  SELECT * FROM zprc_dccode
    INTO TABLE @lt_code_db
    WHERE block_dc = @gc_dc_envelope
       OR block_dc = @gc_dc_test1
       OR block_dc = @gc_dc_test2
       OR block_dc = @gc_dc_invalid.
  LOOP AT lt_code_db INTO ls_code_db.
    IF ls_code_db-block_dc EQ gc_dc_invalid.
      WRITE: / icon_yellow_light AS ICON,
               'Létező DC-kód, a hibás kód teszthez másik kell:'(o06),
               gc_dc_invalid.
      CONTINUE.
    ENDIF.
    DELETE gt_dccode WHERE block_dc = ls_code_db-block_dc.
    IF ls_code_db-block_dc EQ gc_dc_envelope.
      CONTINUE.
    ENDIF.
    CLEAR lv_text.
    ASSIGN COMPONENT gc_dccode_text OF STRUCTURE ls_code_db TO <lv_text>.
    IF sy-subrc EQ 0.
      lv_text = <lv_text>.
    ENDIF.
    IF lv_text NP 'TESZT:*'.
      WRITE: / icon_yellow_light AS ICON,
               'Meglévő, nem teszt DC-kód, változatlanul használva:'(o07),
               ls_code_db-block_dc, lv_text.
    ENDIF.
  ENDLOOP.

ENDFORM.                    " CHECK_EXISTING
*&---------------------------------------------------------------------*
*&      Form  PROCESS
*&---------------------------------------------------------------------*
*       Törlés és/vagy feltöltés egy LUW-ban; hiba -> teljes ROLLBACK
*----------------------------------------------------------------------*
FORM process .

  DATA: lv_error     TYPE abap_bool,
        lv_err_text  TYPE string,
        lo_sql_error TYPE REF TO cx_sy_open_sql_db.

  IF p_test EQ abap_true.
    PERFORM write_plan.
    RETURN.
  ENDIF.

  TRY.
      IF p_reset EQ abap_true OR p_del EQ abap_true.
        PERFORM delete_testdata.
      ENDIF.
      IF p_load EQ abap_true OR p_reset EQ abap_true.
        PERFORM insert_testdata CHANGING lv_error.
      ENDIF.
    CATCH cx_sy_open_sql_db INTO lo_sql_error.
      lv_error    = abap_true.
      lv_err_text = lo_sql_error->get_text( ).
  ENDTRY.

  IF lv_error EQ abap_false.
    COMMIT WORK.
    PERFORM write_result.
  ELSE.
    ROLLBACK WORK.
    WRITE: / icon_red_light AS ICON,
             'Adatbázishiba, minden módosítás visszagörgetve.'(o08).
    IF lv_err_text IS NOT INITIAL.
      WRITE: / lv_err_text.
    ENDIF.
  ENDIF.

ENDFORM.                    " PROCESS
*&---------------------------------------------------------------------*
*&      Form  DELETE_TESTDATA
*&---------------------------------------------------------------------*
FORM delete_testdata RAISING cx_sy_open_sql_db.

  DATA: lt_code  TYPE STANDARD TABLE OF zprc_dccode,
        ls_code  TYPE zprc_dccode,
        lv_count TYPE i,
        lv_text  TYPE string.
  FIELD-SYMBOLS: <lv_text> TYPE any.

* A riport mentése a tesztdokumentumokhoz új szövegrekordot is
* létrehozhat - az előtag alapján ezek is törlődnek
  DELETE FROM zprt_dcqmlt WHERE exbilldocno IN @gr_docno.
  gv_del_dcqmlt = sy-dbcnt.

  DELETE FROM zprt_dcqm WHERE doc_no IN @gr_docno
                          AND cruser = @gc_marker.
  gv_del_dcqm = sy-dbcnt.

  DELETE FROM zprt_stock WHERE stock_id IN @gr_stock
                           AND cruser   = @gc_marker.
  gv_del_stock = sy-dbcnt.

* T1/T2: csak 'TESZT:' jelöléssel, és ha már semmi nem hivatkozik rá
  SELECT * FROM zprc_dccode
    INTO TABLE @lt_code
    WHERE block_dc = @gc_dc_test1
       OR block_dc = @gc_dc_test2.
  LOOP AT lt_code INTO ls_code.
    ASSIGN COMPONENT gc_dccode_text OF STRUCTURE ls_code TO <lv_text>.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.
    lv_text = <lv_text>.
    IF lv_text NP 'TESZT:*'.
      CONTINUE.
    ENDIF.
    SELECT COUNT(*) FROM zprt_dcqm
      INTO @lv_count
      WHERE block_dc = @ls_code-block_dc.
    IF lv_count GT 0.
      WRITE: / icon_yellow_light AS ICON,
               'Teszt DC-kód megmarad, más sor hivatkozik rá:'(o09),
               ls_code-block_dc.
      CONTINUE.
    ENDIF.
    DELETE zprc_dccode FROM @ls_code.
    gv_del_dccode = gv_del_dccode + sy-dbcnt.
  ENDLOOP.

ENDFORM.                    " DELETE_TESTDATA
*&---------------------------------------------------------------------*
*&      Form  INSERT_TESTDATA
*&---------------------------------------------------------------------*
FORM insert_testdata CHANGING cv_error TYPE abap_bool
                     RAISING  cx_sy_open_sql_db.

  cv_error = abap_false.

  INSERT zprt_stock FROM TABLE @gt_stock.
  IF sy-dbcnt <> lines( gt_stock ).
    cv_error = abap_true.
    RETURN.
  ENDIF.

  INSERT zprt_dcqm FROM TABLE @gt_dcqm.
  IF sy-dbcnt <> lines( gt_dcqm ).
    cv_error = abap_true.
    RETURN.
  ENDIF.

  INSERT zprt_dcqmlt FROM TABLE @gt_dcqmlt.
  IF sy-dbcnt <> lines( gt_dcqmlt ).
    cv_error = abap_true.
    RETURN.
  ENDIF.

  IF gt_dccode IS NOT INITIAL.
    INSERT zprc_dccode FROM TABLE @gt_dccode.
    IF sy-dbcnt <> lines( gt_dccode ).
      cv_error = abap_true.
      RETURN.
    ENDIF.
  ENDIF.

ENDFORM.                    " INSERT_TESTDATA
*&---------------------------------------------------------------------*
*&      Form  WRITE_PLAN
*&---------------------------------------------------------------------*
*       Tesztfutás: mi történne
*----------------------------------------------------------------------*
FORM write_plan .

  DATA: lv_count TYPE i.

  WRITE: / icon_information AS ICON,
           'Tesztfutás - adatbázis-módosítás nem történt.'(o10).
  SKIP.

  IF p_reset EQ abap_true OR p_del EQ abap_true.
    WRITE: / 'Törlendő stock:'(o11),            gv_own_stock,
           / 'Törlendő ZPRT_DCQM sor:'(o12),    gv_own_dcqm,
           / 'Törlendő ZPRT_DCQMLT sor:'(o13),  gv_own_dcqmlt.
  ENDIF.

  IF p_load EQ abap_true OR p_reset EQ abap_true.
    lv_count = lines( gt_stock ).
    WRITE: / 'Felveendő stock:'(o14),           lv_count.
    lv_count = lines( gt_dcqm ).
    WRITE: / 'Felveendő ZPRT_DCQM sor:'(o15),   lv_count.
    lv_count = lines( gt_dcqmlt ).
    WRITE: / 'Felveendő ZPRT_DCQMLT sor:'(o16), lv_count.
    lv_count = lines( gt_dccode ).
    WRITE: / 'Felveendő DC-kód:'(o17),          lv_count.
  ENDIF.

ENDFORM.                    " WRITE_PLAN
*&---------------------------------------------------------------------*
*&      Form  WRITE_RESULT
*&---------------------------------------------------------------------*
FORM write_result .

  DATA: lv_count TYPE i.

  WRITE: / icon_green_light AS ICON,
           'Sikeres futás, az adatok mentve.'(o18).
  SKIP.

  IF p_reset EQ abap_true OR p_del EQ abap_true.
    WRITE: / 'Törölt stock:'(o19),              gv_del_stock,
           / 'Törölt ZPRT_DCQM sor:'(o20),      gv_del_dcqm,
           / 'Törölt ZPRT_DCQMLT sor:'(o21),    gv_del_dcqmlt,
           / 'Törölt teszt DC-kód:'(o22),       gv_del_dccode.
  ENDIF.

  IF p_load EQ abap_true OR p_reset EQ abap_true.
    lv_count = lines( gt_stock ).
    WRITE: / 'Felvett stock:'(o23),             lv_count.
    lv_count = lines( gt_dcqm ).
    WRITE: / 'Felvett ZPRT_DCQM sor:'(o24),     lv_count.
    lv_count = lines( gt_dcqmlt ).
    WRITE: / 'Felvett ZPRT_DCQMLT sor:'(o25),   lv_count.
    lv_count = lines( gt_dccode ).
    WRITE: / 'Felvett DC-kód:'(o26),            lv_count.
  ENDIF.

ENDFORM.                    " WRITE_RESULT
*&---------------------------------------------------------------------*
*&      Form  WRITE_ROWS
*&---------------------------------------------------------------------*
*       A tesztsorok listája; az összeg a pénznem szerint formázva
*       (a belső forma helyességét is mutatja)
*----------------------------------------------------------------------*
FORM write_rows .

  DATA: ls_dcqm TYPE zprt_dcqm.

  CHECK p_del EQ abap_false.

  SKIP.
  FORMAT COLOR COL_HEADING.
  WRITE: / 'Dokumentum'(h01),
        22 'Stock'(h02),
        34 'Boríték'(h03),
        45 'DC'(h04),
        49 'QM'(h05),
        53 'Összeg'(h06),
        75 'Pénznem'(h07),
        84 'Név'(h08).
  FORMAT COLOR OFF.

  LOOP AT gt_dcqm INTO ls_dcqm.
    WRITE: / ls_dcqm-doc_no,
          22 ls_dcqm-prd_stock_id,
          34 ls_dcqm-envelope,
          45 ls_dcqm-block_dc,
          49 ls_dcqm-block_qm,
          53 ls_dcqm-amnt CURRENCY ls_dcqm-waers,
          75 ls_dcqm-waers,
          84 ls_dcqm-name1.
  ENDLOOP.

ENDFORM.                    " WRITE_ROWS
