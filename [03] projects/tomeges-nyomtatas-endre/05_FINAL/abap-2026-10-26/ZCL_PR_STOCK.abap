class ZCL_PR_STOCK definition
  public
  create public .

public section.

  class-methods CHANGE_STATUS
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
      !IV_FROM type ZPRD_STOCK_STATUS
      !IV_TO type ZPRD_STOCK_STATUS
      !IV_PRIORITY type ZPRD_PRIORITY optional
    raising
      ZCX_FORM_MESSAGE_ERROR .
  class-methods CHECK_STATUS
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
      !IV_FROM type ZPRD_STOCK_STATUS
      !IV_TO type ZPRD_STOCK_STATUS
    raising
      ZCX_FORM_MESSAGE_ERROR .
  class-methods GET_STOCK_HEADER
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
    returning
      value(RS_STOCK_DATA) type ZPRS_COCKPIT_HEADER
    raising
      ZCX_FORM_MESSAGE_ERROR .
  class-methods CLOSE_STOCK
    importing
      !IV_STOCK type ZPRD_STOCK_ID
      !IV_PRIORITY type ZPRD_PRIORITY optional .
protected section.

  class-methods UPDATE_STATUS
    importing
      !IV_STOCK_ID type ZPRD_STOCK_ID
      !IV_NEW_STATUS type ZPRD_STOCK_STATUS
      !IV_PRIORITY type ZPRD_PRIORITY optional
    raising
      ZCX_FORM_MESSAGE_ERROR .
  class-data GV_DUMMY_MESSAGE type CHAR1 .
private section.
ENDCLASS.



CLASS ZCL_PR_STOCK IMPLEMENTATION.


  METHOD close_stock.
* ---------------------------------------------------------------*
* Rövid leírás: Stock lezárása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
* 2026.10.25.   X0086         ECH-21281: a lezárás a CHANGE_STATUS-on át (QM -> CL),
*                             a prioritással együtt
* 2026.10.25.   X0086         ECH-21281: a hibák teljes szöveggel a naplóba, a
*                             státuszváltás hibája is; szövegelemek
*----------------------------------------------------------------*
* Deklaráció
    DATA: ls_input  TYPE zpr_eon_dcqmcompleted_request2,
          ls_output	TYPE zpr_eon_dcqmcompleted_response.
    DATA: lo_dcqm TYPE REF TO zpr_co_eon_dcqmcompleted_port.
    DATA: lv_ex_txt TYPE string.
    DATA: lr_sys_fail TYPE REF TO cx_ai_system_fault,
          lr_app_fail TYPE REF TO cx_ai_application_fault.
    DATA: lv_error_flag TYPE flag,
          lv_lines      TYPE i,
          lv_ret        TYPE char1,
          lv_hiba       TYPE flag,
          lv_dummy      TYPE string.
    DATA: ls_edit   TYPE lvc_s_styl,
          ls_stable TYPE lvc_s_stbl.
    DATA: lt_rows TYPE lvc_t_row,
          ls_rows LIKE LINE OF lt_rows.
    DATA: ls_sval  TYPE sval.
    DATA: lt_sval  TYPE STANDARD TABLE OF sval.
    DATA: gs_stock TYPE zprt_stock.
    DATA gv_priority TYPE zprd_priority VALUE '30'.
    DATA lv_logical_port_name TYPE prx_logical_port_name.
    DATA lv_call_start TYPE timestampl.
    DATA lv_call_end TYPE timestampl.
    DATA lv_log_stamp TYPE c LENGTH 40.
    DATA lv_seconds TYPE p LENGTH 12 DECIMALS 3.
    DATA lv_log_duration TYPE c LENGTH 40.

    DATA lv_obj  TYPE balobj_d VALUE 'ZPR_MASS'.
    DATA lv_subobj  TYPE balsubobj VALUE 'PACKAGE'.

* A boritékolás tisztázandó
    DATA: lt_env_tab TYPE zpr_eon_dcqmcompleted_requ_tab,
          ls_env_tab TYPE zpr_eon_dcqmcompleted_request1.
*    DATA lt_exc_env TYPE zebf_pr_string_tab.
*    DATA ls_exc_env TYPE string.
*    DATA ls_0100_alv TYPE zebfs_pr_dcqm_report.
    DATA lv_excluded_no_of_doc TYPE sytabix.
    DATA lv_total_doc_no TYPE sytabix.
    DATA lv_total_envelope_no TYPE sytabix.

*----------------------------------------------------------------*
* Prioritás megállapítása
    gs_stock-priority = '30'.
    REFRESH lt_sval.
    ls_sval-tabname   = 'ZPRT_STOCK'.
    ls_sval-fieldname = 'PRIORITY'.
    ls_sval-value     = gs_stock-priority.
    APPEND ls_sval TO lt_sval.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title     = 'Engedélyezés, kérem adja meg a prioritást:'(001)
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
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      EXIT.
    ELSE.
      IF lv_ret EQ 'A'. "Abort
        EXIT.
      ENDIF.
      LOOP AT lt_sval INTO ls_sval.
        CASE ls_sval-fieldname.
          WHEN 'PRIORITY'.
            IF ls_sval-value IS INITIAL .
              MESSAGE i087(zpr) WITH 'Prioritás'(002).
              lv_hiba = abap_true.
              EXIT.
            ENDIF.
            gv_priority = ls_sval-value.
        ENDCASE.
      ENDLOOP.
      IF lv_hiba EQ abap_true.
        EXIT.
      ENDIF.
    ENDIF.

*    LOOP AT gt_0100_alv INTO ls_0100_alv.
**    ls_exc_env = ls_0100_alv-envelope.
*      ls_env_tab-envelope_id = ls_0100_alv-envelope.
*      APPEND ls_env_tab TO lt_env_tab.
*    ENDLOOP.
*    SORT lt_env_tab.
*    DELETE ADJACENT DUPLICATES FROM lt_env_tab.
*    ls_input-exclude_envelopes-envelope[] = lt_env_tab[].
*---------------------------------------------------------------*
* Alkalmazási napló megnyitása
    DATA(lo_log) = NEW zcl_pr_log(
      iv_log_object    = lv_obj
      iv_log_subobject = lv_subobj ).

*---------------------------------------------------------------*
* Kizárt dokumentumok esetén a boritékban lévő többi dokumentumot is kizárjuk
    SELECT doc_no,
           envelope,
           block_dc,
           block_qm
      INTO TABLE @DATA(lt_doc)
      FROM zprt_dcqm
      INNER JOIN zprt_package
      ON zprt_package~package_id = zprt_dcqm~package_id
      INNER JOIN zprt_stock
      ON zprt_stock~stock_id = zprt_package~stock_id
      WHERE zprt_stock~stock_id = @iv_stock.
    LOOP AT lt_doc INTO DATA(ls_doc)
      WHERE block_dc <> space
      OR    block_qm <> space.
      ls_env_tab-envelope_id = ls_doc-envelope.
      APPEND ls_env_tab TO lt_env_tab.
      ADD 1 TO lv_excluded_no_of_doc.
    ENDLOOP.
    SORT lt_env_tab.
    DELETE ADJACENT DUPLICATES FROM lt_env_tab.
    DESCRIBE TABLE lt_env_tab LINES lv_total_envelope_no.
    DESCRIBE TABLE lt_doc LINES lv_total_doc_no.

* ---------------------------------------------------------------*
* Statisztika
    MESSAGE s350(zpr) WITH lv_total_doc_no INTO lv_dummy.
    lo_log->add_system_message( ).
    MESSAGE s351(zpr) WITH lv_excluded_no_of_doc INTO lv_dummy.
    lo_log->add_system_message( ).
    MESSAGE s352(zpr) WITH lv_total_envelope_no INTO lv_dummy.
    lo_log->add_system_message( ).

* ---------------------------------------------------------------*
* Logikai port előállítása
    lv_logical_port_name = zcl_pr_output_management=>get_logical_port_name(  ).

* ---------------------------------------------------------------*
* Proxy objektum létrehozása
    TRY.
        CREATE OBJECT lo_dcqm
          EXPORTING
*           destination       = lo_destination
            logical_port_name = lv_logical_port_name. "lv_logical_port_name..
      CATCH cx_ai_system_fault INTO DATA(lx_system_fault). " Application Integration: Technical Error
        lo_log->add_exception( lx_system_fault ).
        lv_error_flag = abap_true.
    ENDTRY.

* ---------------------------------------------------------------*
* Hívás felparaméterezése
    ls_input-sap_mandant = sy-mandt.
    ls_input-sap_system = sy-sysid.
    ls_input-stock_id = iv_stock.
    ls_input-priority = gv_priority.
    ls_input-exclude_envelopes-envelope[] = lt_env_tab[].

* ---------------------------------------------------------------*
* Inspire hívás
    IF lv_error_flag IS INITIAL.
      TRY.
          GET TIME STAMP FIELD lv_call_start.
          lv_log_stamp = |{ lv_call_start TIMESTAMP = ISO TIMEZONE = 'UTC' } UTC|.
          MESSAGE s000(zpr) WITH TEXT-901 iv_stock lv_log_stamp INTO lv_dummy.
          lo_log->add_system_message( ).

          CALL METHOD lo_dcqm->eon_dcqmcompleted
            EXPORTING
              input  = ls_input
            IMPORTING
              output = ls_output.

          GET TIME STAMP FIELD lv_call_end.

        CATCH cx_ai_system_fault INTO lx_system_fault.
          GET TIME STAMP FIELD lv_call_end.
          lo_log->add_exception( lx_system_fault ).
          lv_error_flag = abap_true.
        CATCH cx_ai_application_fault INTO DATA(lx_application_fault).
          GET TIME STAMP FIELD lv_call_end.
          lo_log->add_exception( lx_application_fault ).
          lv_error_flag = abap_true.
      ENDTRY.

*TODO: Még ne !!
*CLEAR: lv_call_start, lv_call_end.
      IF lv_call_start IS NOT INITIAL AND lv_call_end IS NOT INITIAL.
        lv_log_stamp = |{ lv_call_end TIMESTAMP = ISO TIMEZONE = 'UTC' } UTC|.
        IF lv_error_flag IS INITIAL.
          MESSAGE s000(zpr) WITH TEXT-902 iv_stock lv_log_stamp INTO lv_dummy.
        ELSE.
          MESSAGE e000(zpr) WITH TEXT-903 iv_stock lv_log_stamp INTO lv_dummy.
        ENDIF.
        lo_log->add_system_message( ).
        TRY.
            lv_seconds = cl_abap_tstmp=>subtract(
              tstmp1 = lv_call_end
              tstmp2 = lv_call_start ).
            WRITE lv_seconds TO lv_log_duration LEFT-JUSTIFIED
              DECIMALS 3 NO-GROUPING.
            MESSAGE s000(zpr) WITH TEXT-904 iv_stock lv_log_duration INTO lv_dummy.
            lo_log->add_system_message( ).
          CATCH cx_root INTO DATA(lo_timing).
            " Az időmérés hibája nem változtathatja meg az üzleti hibakezelést,
            " ezért csak figyelmeztetésként kerül a naplóba.
            lo_log->add_exception( ir_cx    = lo_timing
                                   iv_msgty = 'W' ).
        ENDTRY.
      ENDIF.
    ENDIF.

* ---------------------------------------------------------------*
* Hibakezelés
    IF lv_error_flag IS INITIAL.
      IF ls_output-parameters-success = abap_true.
        MESSAGE s071 WITH iv_stock INTO gv_dummy_message.
        lo_log->add_system_message(  ).
      ELSE.
        " Az Inspire hibaszövege teljes terjedelmében kerül a naplóba.
        lo_log->add_text( |{ ls_output-parameters-error_code }: { ls_output-parameters-info }| ).
        lv_error_flag = abap_true.
      ENDIF.
    ENDIF.

*---------------------------------------------------------------*
* Hiba kezelés
    IF lv_error_flag EQ abap_true.
      MESSAGE s072 WITH iv_stock INTO gv_dummy_message.
      lo_log->add_system_message(  ).
    ENDIF.

*---------------------------------------------------------------*
* Adatbázis update
    IF lv_error_flag IS INITIAL.
      TRY.
          zcl_pr_stock=>change_status(
            iv_stock_id = iv_stock
            iv_from     = 'QM'
            iv_to       = 'CL'
            iv_priority = gv_priority ).
        CATCH zcx_form_message_error INTO DATA(lo_status).
          lo_log->add_exception( lo_status ).
      ENDTRY.
    ENDIF.

*---------------------------------------------------------------*
* Napló
    lo_log->close(  ).
    IF sy-batch IS INITIAL.
      lo_log->display(  ).
    ENDIF.

  ENDMETHOD.


  METHOD change_status.
*---------------------------------------------------------------*
* Rövid leírás: Stock státuszváltás ellenőrzéssel
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.10.25.   X0086         Létrehozva (ECH-21264)
* 2026.10.25.   X0086         ECH-21281: az írás sikerét is visszaadja; opcionális
*                             prioritás
* 2026.10.25.   X0086         ECH-21281: a visszatérési érték megszűnt, hibánál
*                             ZCX_FORM_MESSAGE_ERROR kivétel
*---------------------------------------------------------------*
    check_status(
      iv_stock_id = iv_stock_id
      iv_from     = iv_from
      iv_to       = iv_to ).

    " A megadott (akár üres) prioritás felülír, ezért csak akkor adjuk tovább, ha a hívó megadta.
    IF iv_priority IS SUPPLIED.
      update_status(
        iv_stock_id   = iv_stock_id
        iv_new_status = iv_to
        iv_priority   = iv_priority ).
    ELSE.
      update_status(
        iv_stock_id   = iv_stock_id
        iv_new_status = iv_to ).
    ENDIF.

  ENDMETHOD.


  METHOD get_stock_header.
*---------------------------------------------------------------*
* Rövid leírás: Összeg konverzió text formátumra
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.13.   X0097         Létrehozva
* 2026.10.25.   X0086         ECH-21264: szöveg a domainből, DC és AD
* 2026.10.25.   X0086         ECH-21281: a hiányzó stock kivételt ad (ZPR/045);
*                             egy ikon-lekérdezés
*---------------------------------------------------------------*
    DATA lv_icon_name TYPE icon-name.

    SELECT SINGLE *
      INTO CORRESPONDING FIELDS OF rs_stock_data
      FROM zprt_stock
      WHERE stock_id = iv_stock_id.
    IF sy-subrc NE 0.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e045(zpr).
    ENDIF.
    " A státusz szövege a ZPRD_STOCK_STATUS domain fix értékeiből jön.
    " A szöveg csak magyarul van meg, ezért hiánya nem hiba: üresen marad.
    SELECT SINGLE ddtext
      FROM dd07t
      WHERE domname    EQ 'ZPRD_STOCK_STATUS'
        AND ddlanguage EQ @sy-langu
        AND as4local   EQ 'A'
        AND domvalue_l EQ @rs_stock_data-status
      INTO @rs_stock_data-text.
    IF sy-subrc NE 0.
      CLEAR rs_stock_data-text.
    ENDIF.

    " A státuszhoz tartozó ikon neve; ismeretlen státuszhoz nincs ikon.
    CASE rs_stock_data-status.
      WHEN space.
        lv_icon_name = 'ICON_OPEN_FOLDER'.
      WHEN 'DC'.
        lv_icon_name = 'ICON_CHECKED'.
      WHEN 'QM'.
        lv_icon_name = 'ICON_RELEASE'.
      WHEN 'CL' OR 'AD'.
        lv_icon_name = 'ICON_CLOSED_FOLDER'.
    ENDCASE.

    " Hiányzó ikonnál az ikon mező üresen marad.
    IF lv_icon_name IS NOT INITIAL.
      SELECT SINGLE id
        INTO rs_stock_data-icon
        FROM icon
        WHERE name EQ lv_icon_name.
      IF sy-subrc NE 0.
        CLEAR rs_stock_data-icon.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD update_status.
*---------------------------------------------------------------*
* Rövid leírás: Stock státuszának írása; a jelzők vele együtt mozognak
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.10.25.   X0086         ECH-21281: DCCOMPL/QMCOMPL az új státuszból,
*                             visszatérési érték, opcionális prioritás
* 2026.10.25.   X0086         ECH-21281: a visszatérési érték megszűnt, az írás
*                             hibája ZCX_FORM_MESSAGE_ERROR kivétel
*---------------------------------------------------------------*

    DATA lv_closed    TYPE char1.
    DATA lv_dccompl   TYPE zprt_stock-dccompl.
    DATA lv_erdat_clo TYPE sydatum.
    DATA lv_ernam_clo TYPE syuname.
    DATA lv_ertim_clo TYPE sy-uzeit.
    DATA lv_qmcompl   TYPE zprt_stock-qmcompl.

    " A jelzők az új státuszból jönnek, ezért visszalépésnél (pl. QM -> DC) ki is ürülnek.
    CASE iv_new_status.
      WHEN 'DC'.
        lv_dccompl = abap_true.
      WHEN 'QM'.
        lv_dccompl = abap_true.
        lv_qmcompl = abap_true.
      WHEN 'CL'.
        lv_dccompl     = abap_true.
        lv_qmcompl     = abap_true.
        lv_closed      = 'X'.
        lv_erdat_clo   = sy-datum.
        lv_ernam_clo   = sy-uname.
        lv_ertim_clo   = sy-uzeit.
      WHEN 'AD'.
        " Az AD a lezárt (CL) stockból jön: a lezárás adatai változatlanul megmaradnak.
        lv_dccompl = abap_true.
        lv_qmcompl = abap_true.
        SELECT SINGLE closed, erdat_clo, ernam_clo, ertim_clo
          FROM zprt_stock
          WHERE stock_id EQ @iv_stock_id
          INTO ( @lv_closed, @lv_erdat_clo, @lv_ernam_clo, @lv_ertim_clo ).
        " Ha a stock nem létezik, nincs mit írni.
        IF sy-subrc NE 0.
          RAISE EXCEPTION TYPE zcx_form_message_error
            MESSAGE e045(zpr).
        ENDIF.
    ENDCASE.
    " A prioritás csak megadáskor íródik, különben a mező változatlan marad.
    IF iv_priority IS SUPPLIED.
      UPDATE zprt_stock
         SET priority = @iv_priority
       WHERE stock_id EQ @iv_stock_id.
      IF sy-subrc NE 0.
        ROLLBACK WORK.
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e049(zpr).
      ENDIF.
    ENDIF.
    UPDATE zprt_stock
       SET status = @iv_new_status,
           dccompl = @lv_dccompl,
           qmcompl = @lv_qmcompl,
           chuser = @sy-uname,
           chdate = @sy-datum,
           chtime = @sy-uzeit,
           closed = @lv_closed,
           erdat_clo = @lv_erdat_clo ,
           ernam_clo = @lv_ernam_clo,
           ertim_clo = @lv_ertim_clo
     WHERE stock_id = @iv_stock_id.

    IF sy-subrc NE 0.
      ROLLBACK WORK.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e049(zpr).
    ENDIF.

    COMMIT WORK.

  ENDMETHOD.


  METHOD check_status.
*---------------------------------------------------------------*
* Rövid leírás: Stock státuszváltás ellenőrzéssel
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.10.25.   X0086         Létrehozva (ECH-21264)
* 2026.10.25.   X0086         ECH-21281: új átmenet CL -> AD
* 2026.10.25.   X0086         ECH-21281: a visszatérési érték megszűnt, a tiltott
*                             váltás kivételt ad (ZPR/044, ZPR/045)
*---------------------------------------------------------------*

    DATA lv_status TYPE zprd_stock_status.

    " Megengedett átmenetek: Nyitott <-> DC <-> QM -> CL -> AD, minden más tilos.
    IF NOT ( ( iv_from EQ space AND iv_to EQ 'DC' )
          OR ( iv_from EQ 'DC' AND ( iv_to EQ space OR iv_to EQ 'QM' ) )
          OR ( iv_from EQ 'QM' AND ( iv_to EQ 'DC' OR iv_to EQ 'CL' ) )
          OR ( iv_from EQ 'CL' AND iv_to EQ 'AD' ) ).
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e044(zpr)
        WITH iv_from iv_to.
    ENDIF.

    " A váltás csak akkor indul, ha a stock most is a várt státuszban van.
    SELECT SINGLE status
      FROM zprt_stock
      WHERE stock_id EQ @iv_stock_id
      INTO @lv_status.
    IF sy-subrc NE 0.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e045(zpr).
    ENDIF.
    IF lv_status NE iv_from.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e044(zpr)
        WITH lv_status iv_to.
    ENDIF.

  ENDMETHOD.
ENDCLASS.