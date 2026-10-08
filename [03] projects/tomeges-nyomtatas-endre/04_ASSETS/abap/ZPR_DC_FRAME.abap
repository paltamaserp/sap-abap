REPORT zpr_dc_frame MESSAGE-ID zpr.

*&---------------------------------------------------------------------*
*& Report ZPR_DC_FRAME
*---------------------------------------------------------------*
* Rövid leírás: Data Control(DC): Műveletek - keretprogram
*               (QU5 ZEBF_PR_DC_FRAME átvétele)
* Projekt:      CSHANA 2026
* Fejlesztő:    <USER>
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.10.08.   <USER>        Létrehozva
*---------------------------------------------------------------*
* Tranzakció: ZPR_DC (report transaction, szelekciós kép 1000)
*
*
* Szövegelemek:
*   Programcím: Data Control(DC): Műveletek
*   TEXT-001  : Elvégzendő műveletek:
*   Szelekciós szövegek: P_STOKID = Stock ID,
*     P_MOD  = Nyomtatási sorok kizárása,
*     P_DISP = Nyomtatási sorok megtekintése,
*     P_ENG  = DC engedélyezés,
*     P_ENGV = DC engedélyezés visszavétele
*---------------------------------------------------------------*

*---------------------------------------------------------------*
* Konstansok
*---------------------------------------------------------------*
* Üzenetek (ZPR)
* DC üzenetek: ZPR 045-066; az általános üzenet ZPR 000.
* A DC üzeneteket a riport használata előtt SE91-ben fel kell venni.
CONSTANTS:
  gc_msgid TYPE symsgid VALUE 'ZPR',
  BEGIN OF gc_msgno,
    generic          TYPE symsgno VALUE '000', "& & & &
    stock_not_found  TYPE symsgno VALUE '045', "A Stock ID nem létezik!
    stock_closed     TYPE symsgno VALUE '046', "A stock lezárt, csak megjelenítés lehetséges
    dc_already_done  TYPE symsgno VALUE '050', "A DC már engedélyezve van
    release_ok       TYPE symsgno VALUE '051', "DC engedélyezés sikeres
    release_failed   TYPE symsgno VALUE '052', "DC engedélyezés sikertelen
    count_released   TYPE symsgno VALUE '053', "Engedélyezett sorok száma: &1
    count_excluded   TYPE symsgno VALUE '054', "Kizárt sorok száma: &1
    dc_not_done      TYPE symsgno VALUE '055', "A DC még nincs engedélyezve
    revoke_ok        TYPE symsgno VALUE '056', "Engedélyezés visszavétele sikeres
    revoke_failed    TYPE symsgno VALUE '057', "Engedélyezés visszavétele sikertelen
    dc_completed     TYPE symsgno VALUE '062', "DC kész, a stock nem módosítható
  END OF gc_msgno.

* Alkalmazásnapló
CONSTANTS: gc_log_object TYPE balobj_d  VALUE 'ZPR_MASS',
           gc_log_subobj TYPE balsubobj VALUE 'DC'.

*---------------------------------------------------------------*
* Globális adatok
*---------------------------------------------------------------*
DATA: gs_stock TYPE zprt_stock,
      gv_dummy TYPE string.
* LOG
DATA: go_log TYPE REF TO zcl_pr_log.

*----------------------------------------------------------------------*
* SELECTION-SCREEN                                                     *
*----------------------------------------------------------------------*
SELECTION-SCREEN SKIP.
PARAMETERS: p_stokid TYPE zprd_stock_id OBLIGATORY.
SELECTION-SCREEN SKIP.
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_mod  TYPE flag RADIOBUTTON GROUP gr1 DEFAULT 'X',
            p_disp TYPE flag RADIOBUTTON GROUP gr1,
            p_eng  TYPE flag RADIOBUTTON GROUP gr1,
            p_engv TYPE flag RADIOBUTTON GROUP gr1.
SELECTION-SCREEN END OF BLOCK b01.

*----------------------------------------------------------------------*
* AT SELECTION-SCREEN                                                  *
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.

  IF p_stokid IS NOT INITIAL.
    PERFORM check_stockid.
  ENDIF.

*----------------------------------------------------------------------*
* START-OF-SELECTION                                                   *
*----------------------------------------------------------------------*
START-OF-SELECTION.

  CASE abap_true.
    WHEN p_mod.
      PERFORM run_report USING abap_true.
    WHEN p_disp.
      PERFORM run_report USING abap_false.
    WHEN p_eng.
      PERFORM change_dc_status USING abap_true.
    WHEN p_engv.
      PERFORM change_dc_status USING abap_false.
  ENDCASE.

*&---------------------------------------------------------------------*
*&      Form  CHECK_STOCKID
*&---------------------------------------------------------------------*
*       Előzetes ellenőrzés a szelekciós képernyőn. A végleges
*       ellenőrzést a zárolás után a riport, ill. CHANGE_DC_STATUS
*       végzi friss adatokkal.
*----------------------------------------------------------------------*
FORM check_stockid .

  SELECT SINGLE * FROM zprt_stock
    INTO @gs_stock
    WHERE stock_id = @p_stokid.
  IF sy-subrc NE 0.
    MESSAGE ID gc_msgid TYPE 'E' NUMBER gc_msgno-stock_not_found.
*   A Stock ID nem létezik!
  ENDIF.

  IF p_mod EQ abap_true.
    IF gs_stock-closed EQ abap_true.
      CLEAR p_mod.
      p_disp = abap_true.
      MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-stock_closed.
*     A stock lezárt, csak megjelenítés lehetséges
    ELSEIF gs_stock-dccompl EQ abap_true.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER gc_msgno-dc_completed.
*     DC kész, a stock nem módosítható
    ENDIF.
  ELSEIF p_eng EQ abap_true OR p_engv EQ abap_true.
    IF gs_stock-closed EQ abap_true.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER gc_msgno-stock_closed
              DISPLAY LIKE 'I'.
*     A stock lezárt, csak megjelenítés lehetséges
    ENDIF.
  ENDIF.

ENDFORM.                    " CHECK_STOCKID
*&---------------------------------------------------------------------*
*&      Form  RUN_REPORT
*&---------------------------------------------------------------------*
*       Kizárás / megtekintés. A riport maga is ellenőrzi a stock
*       állapotát és zárol.
*----------------------------------------------------------------------*
FORM run_report
  USING uv_modif TYPE flag.

  SUBMIT zpr_dcqm_exclude VIA SELECTION-SCREEN
                WITH p_stokid EQ p_stokid
                WITH p_modif  EQ uv_modif
                AND RETURN.

ENDFORM.                    " RUN_REPORT
*&---------------------------------------------------------------------*
*&      Form  CHANGE_DC_STATUS
*&---------------------------------------------------------------------*
*       DC engedélyezés (uv_dccompl = X) vagy visszavétele (space)
*----------------------------------------------------------------------*
FORM change_dc_status
  USING uv_dccompl TYPE flag.

  DATA: ls_stock     TYPE zprt_stock,
        lt_msg       TYPE bal_t_msg,
        ls_msg       TYPE bal_s_msg,
        lv_locked    TYPE abap_bool,
        lv_error     TYPE abap_bool,
        lv_err_text  TYPE string,
        lo_sql_error TYPE REF TO cx_sy_open_sql_db.

* Stock ID zárolása
  PERFORM lock_stock CHANGING lv_locked.
  CHECK lv_locked EQ abap_true.

* Friss állapot a zár megszerzése után
  SELECT SINGLE * FROM zprt_stock BYPASSING BUFFER
    INTO @ls_stock
    WHERE stock_id = @p_stokid.
  IF sy-subrc NE 0.
    PERFORM unlock_stock.
    MESSAGE ID gc_msgid TYPE 'S' NUMBER gc_msgno-stock_not_found
            DISPLAY LIKE 'E'.
*   A Stock ID nem létezik!
    RETURN.
  ENDIF.

  IF ls_stock-closed EQ abap_true.
    PERFORM unlock_stock.
    MESSAGE ID gc_msgid TYPE 'S' NUMBER gc_msgno-stock_closed
            DISPLAY LIKE 'E'.
*   A stock lezárt, csak megjelenítés lehetséges
    RETURN.
  ENDIF.

  IF ls_stock-dccompl EQ uv_dccompl.
    PERFORM unlock_stock.
    IF uv_dccompl EQ abap_true.
      MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-dc_already_done.
*     A DC már engedélyezve van
    ELSE.
      MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-dc_not_done.
*     A DC még nincs engedélyezve
    ENDIF.
    RETURN.
  ENDIF.

  TRY.
      UPDATE zprt_stock SET dccompl = @uv_dccompl,
                           chuser  = @sy-uname,
                           chdate  = @sy-datum,
                           chtime  = @sy-uzeit
        WHERE stock_id = @p_stokid.
      IF sy-subrc NE 0 OR sy-dbcnt NE 1.
        lv_error = abap_true.
      ENDIF.
    CATCH cx_sy_open_sql_db INTO lo_sql_error.
      lv_error    = abap_true.
      lv_err_text = lo_sql_error->get_text( ).
  ENDTRY.

  IF lv_error EQ abap_false.
    COMMIT WORK.
  ELSE.
    ROLLBACK WORK.
  ENDIF.

  PERFORM unlock_stock.

* Napló: eredmény + darabszámok
  CLEAR ls_msg.
  ls_msg-msgid = gc_msgid.
  IF lv_error EQ abap_false.
    ls_msg-msgty = 'S'.
    IF uv_dccompl EQ abap_true.
      ls_msg-msgno = gc_msgno-release_ok.
*     DC engedélyezés sikeres
    ELSE.
      ls_msg-msgno = gc_msgno-revoke_ok.
*     Engedélyezés visszavétele sikeres
    ENDIF.
  ELSE.
    ls_msg-msgty = 'E'.
    IF uv_dccompl EQ abap_true.
      ls_msg-msgno = gc_msgno-release_failed.
*     DC engedélyezés sikertelen
    ELSE.
      ls_msg-msgno = gc_msgno-revoke_failed.
*     Engedélyezés visszavétele sikertelen
    ENDIF.
  ENDIF.
  APPEND ls_msg TO lt_msg.

  IF lv_err_text IS NOT INITIAL.
    CLEAR ls_msg.
    ls_msg-msgid = gc_msgid.
    ls_msg-msgty = 'E'.
    ls_msg-msgno = gc_msgno-generic.
    ls_msg-msgv1 = lv_err_text.
    APPEND ls_msg TO lt_msg.
  ENDIF.

  PERFORM get_count CHANGING lt_msg.

  PERFORM log_write USING lt_msg.

* Eredmény a státuszsorban is
  READ TABLE lt_msg INTO ls_msg INDEX 1.
  IF lv_error EQ abap_false.
    MESSAGE ID ls_msg-msgid TYPE 'S' NUMBER ls_msg-msgno.
  ELSE.
    MESSAGE ID ls_msg-msgid TYPE 'S' NUMBER ls_msg-msgno
            DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.                    " CHANGE_DC_STATUS
*&---------------------------------------------------------------------*
*&      Form  LOCK_STOCK
*&---------------------------------------------------------------------*
FORM lock_stock CHANGING cv_locked TYPE abap_bool.

  cv_locked = abap_false.

* _SCOPE = 1: a zár a dialógusé, a COMMIT WORK nem oldja fel
  CALL FUNCTION 'ENQUEUE_EZPRT_STOCK'
    EXPORTING
      stock_id       = p_stokid
      _scope         = '1'
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno DISPLAY LIKE 'E'
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    RETURN.
  ENDIF.

  cv_locked = abap_true.

ENDFORM.                    " LOCK_STOCK
*&---------------------------------------------------------------------*
*&      Form  UNLOCK_STOCK
*&---------------------------------------------------------------------*
FORM unlock_stock .

  CALL FUNCTION 'DEQUEUE_EZPRT_STOCK'
    EXPORTING
      stock_id = p_stokid
      _scope   = '1'.

ENDFORM.                    " UNLOCK_STOCK
*&---------------------------------------------------------------------*
*&      Form  GET_COUNT
*&---------------------------------------------------------------------*
*       Engedélyezett / kizárt sorok száma a stockban
*----------------------------------------------------------------------*
FORM get_count CHANGING ct_msg TYPE bal_t_msg.

  DATA: lv_kizart TYPE i,
        lv_enged  TYPE i,
        ls_msg    TYPE bal_s_msg.

  SELECT COUNT(*) FROM zprt_dcqm
    WHERE prd_stock_id = @p_stokid
      AND block_dc <> @space
    INTO @lv_kizart.

  SELECT COUNT(*) FROM zprt_dcqm
    WHERE prd_stock_id = @p_stokid
      AND block_dc = @space
    INTO @lv_enged.

  CLEAR ls_msg.
  ls_msg-msgid = gc_msgid.
  ls_msg-msgty = 'S'.
  ls_msg-msgno = gc_msgno-count_released.
  ls_msg-msgv1 = lv_enged.
  CONDENSE ls_msg-msgv1.
* Engedélyezett sorok száma: &1
  APPEND ls_msg TO ct_msg.

  CLEAR ls_msg.
  ls_msg-msgid = gc_msgid.
  ls_msg-msgty = 'S'.
  ls_msg-msgno = gc_msgno-count_excluded.
  ls_msg-msgv1 = lv_kizart.
  CONDENSE ls_msg-msgv1.
* Kizárt sorok száma: &1
  APPEND ls_msg TO ct_msg.

ENDFORM.                    " GET_COUNT
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
* teszi tartóssá.
  go_log->close( ).
  COMMIT WORK.

  go_log->display( ).

ENDFORM.                    " LOG_WRITE
