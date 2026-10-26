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
*--------------------------------------------------------------------*

TYPE-POOLS icon.

CONSTANTS: gc_log_object       TYPE balobj_d VALUE 'ZPR_MASS',
           gc_log_subobject    TYPE balsubobj VALUE 'STOCK',
           gc_tcode            TYPE tcode VALUE 'ZPR_CLOSE_STOCK',
           gc_status_closed    TYPE zprd_stock_status VALUE 'CL',
           gc_status_qm        TYPE zprd_stock_status VALUE 'QM',
           gc_default_priority TYPE zprd_priority VALUE '30',
           gc_terti_table      TYPE tabname VALUE 'ZPR_TERTI',
           gc_f064_table       TYPE tabname VALUE 'ZISU_F064'.

TYPES: ty_alv_table TYPE STANDARD TABLE OF zprs_dcqm_report,
       BEGIN OF ty_regmail,
         envelope_id      TYPE zprt_dcqm-envelope,
         exbilldocno      TYPE zprt_dcqm-doc_no,
         zisu_ragszam_128 TYPE zprt_dcqm-regmailnumber,
       END OF ty_regmail,
       ty_regmail_table TYPE STANDARD TABLE OF ty_regmail,
       BEGIN OF ty_stock_f4,
         stock_id TYPE zprt_stock-stock_id,
         status   TYPE zprt_stock-status,
         closed   TYPE zprt_stock-closed,
         dccompl  TYPE zprt_stock-dccompl,
         qmcompl  TYPE zprt_stock-qmcompl,
         priority TYPE zprt_stock-priority,
       END OF ty_stock_f4.

CLASS lcl_grid_events DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      on_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,
      on_user_command FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm.
ENDCLASS.

DATA: gs_stock          TYPE zprt_stock,
      gt_alv            TYPE ty_alv_table,
      gt_messages       TYPE bal_t_msg,
      gv_okcode_0100    TYPE syucomm,
      gv_total          TYPE i,
      gv_excluded       TYPE i,
      gv_allowed        TYPE i,
      gv_modif          TYPE abap_bool VALUE 'X',
      gv_locked_stock   TYPE zprd_stock_id,
      gv_priority       TYPE zprd_priority,
      gv_error          TYPE abap_bool,
      gv_call_started   TYPE abap_bool,
      gv_remote_success TYPE abap_bool,
      gv_uncertain      TYPE abap_bool,
      gv_saved          TYPE abap_bool,
      gv_log_error      TYPE abap_bool,
      gv_busy           TYPE abap_bool,
      gv_block_reason   TYPE c LENGTH 120,
      gv_dummy          TYPE string,
      gr_container      TYPE REF TO cl_gui_custom_container,
      gr_grid           TYPE REF TO cl_gui_alv_grid,
      gr_header_container TYPE REF TO cl_gui_docking_container,
      gr_header         TYPE REF TO cl_dd_document,
      gv_header_valid   TYPE abap_bool.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
  PARAMETERS p_stokid TYPE zprd_stock_id OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b01.
SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-002.
  PARAMETERS p_vari TYPE slis_vari.
SELECTION-SCREEN END OF BLOCK b02.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_stokid.
  PERFORM stock_f4.

AT SELECTION-SCREEN.
  SELECT SINGLE * FROM zprt_stock INTO gs_stock
    WHERE stock_id = p_stokid.
  IF sy-subrc <> 0.
    MESSAGE e000 WITH 'A stock nem létezik:' p_stokid.
  ENDIF.

START-OF-SELECTION.
  IF sy-batch = abap_true.
    MESSAGE s000 WITH 'A riport csak dialógusban indítható.'
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
  IF sy-subrc <> 0.
    MESSAGE s000 WITH 'Nincs jogosultsag a tranzakciohoz:' gc_tcode
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  CLEAR: gv_busy, gv_saved, gv_uncertain, gv_remote_success,
         gv_call_started, gv_locked_stock.
  PERFORM read_stock.

  IF gv_error = abap_true.
    MESSAGE s000 WITH 'A stock beolvasása sikertelen.'
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM determine_mode.
  PERFORM sync_lock.
  IF gv_error = abap_true.
    PERFORM unlock_stock.
    PERFORM log_write.
    RETURN.
  ENDIF.
  PERFORM select_data.

  IF gv_error = abap_true.
    PERFORM unlock_stock.
    PERFORM log_write.
    RETURN.
  ENDIF.

  IF gs_stock-closed IS NOT INITIAL
     OR gs_stock-status = gc_status_closed.
    MESSAGE TEXT-108 TYPE 'I'.
  ELSEIF gs_stock-status <> gc_status_qm.
    MESSAGE TEXT-110 TYPE 'I'.
  ENDIF.

  CALL SCREEN 0100.

  PERFORM unlock_stock.
  PERFORM free_controls.

  INCLUDE zpr_stock_report_o01.
  INCLUDE zpr_stock_report_i01.

CLASS lcl_grid_events IMPLEMENTATION.
  METHOD on_toolbar.
    DATA ls_button TYPE stb_button.
    DELETE e_object->mt_toolbar
      WHERE function = 'RELEASE' OR function = 'ZREFRESH'.

    IF gv_modif = abap_true AND gv_busy = abap_false
      AND gv_locked_stock = p_stokid.
      CLEAR ls_button.
      ls_button-function = 'RELEASE'.
      ls_button-icon = icon_release.
      ls_button-text = TEXT-105.
      ls_button-quickinfo = TEXT-106.
      APPEND ls_button TO e_object->mt_toolbar.
    ENDIF.
    CLEAR ls_button.
    ls_button-function = 'ZREFRESH'.
    ls_button-icon = icon_refresh.
    ls_button-text = 'Frissítés'.
    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_user_command.
    CASE e_ucomm.
      WHEN 'RELEASE'.
*       zcl_pr_stock=>close_stock( iv_stock = p_stokid ).
*       PERFORM release_stock.
       PERFORM release_stock_new.
      WHEN 'ZREFRESH'.
        PERFORM reload_display.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

FORM read_stock.
  DATA lr_error TYPE REF TO cx_root.
  CLEAR gs_stock.
  gv_error = abap_true.
  TRY.
      SELECT SINGLE * FROM zprt_stock BYPASSING BUFFER INTO gs_stock
        WHERE stock_id = p_stokid.
      IF sy-subrc = 0.
        gv_error = abap_false.
      ENDIF.
    CATCH cx_root INTO lr_error.
      PERFORM add_exception USING lr_error.
  ENDTRY.
  IF gv_error = abap_true.
    CLEAR gv_header_valid.
  ENDIF.
ENDFORM.

FORM determine_mode.
  gv_modif = abap_false.
  CLEAR gv_block_reason.
  IF gs_stock-closed IS NOT INITIAL
     OR gs_stock-status = gc_status_closed.
    gv_block_reason = 'A stock lezárt, csak megjelenítés lehetséges.'.
  ELSEIF gs_stock-stock_status_er IS NOT INITIAL
         OR gv_uncertain = abap_true.
    gv_block_reason = 'A stock külső állapota ellenőrizendő; lezárás tiltva.'.
  ELSEIF gs_stock-status <> gc_status_qm.
    gv_block_reason = 'A lezárás csak QM státuszban engedélyezett.'.
  ELSE.
    gv_modif = abap_true.
  ENDIF.
ENDFORM.

FORM sync_lock.
  IF gv_modif <> abap_true.
    PERFORM unlock_stock.
    RETURN.
  ENDIF.
  IF gv_locked_stock = p_stokid.
    RETURN.
  ENDIF.
  PERFORM lock_stock.
  IF gv_locked_stock <> p_stokid.
    gv_modif = abap_false.
    RETURN.
  ENDIF.
  "Recheck the stock after acquiring the lock.
  PERFORM read_stock.
  IF gv_error = abap_true.
    gv_modif = abap_false.
    gv_block_reason = TEXT-104.
    PERFORM add_message USING 'E' TEXT-104 p_stokid space.
  ELSE.
    PERFORM determine_mode.
  ENDIF.
  IF gv_modif <> abap_true.
    PERFORM unlock_stock.
  ENDIF.
ENDFORM.

FORM select_data.
  DATA: lt_texts TYPE STANDARD TABLE OF zprt_dcqmlt,
        ls_text  TYPE zprt_dcqmlt,
        lr_error TYPE REF TO cx_root.
  FIELD-SYMBOLS <ls_alv> TYPE zprs_dcqm_report.

  CLEAR: gv_total, gv_excluded, gv_allowed, gv_header_valid.
  REFRESH gt_alv.
  gv_error = abap_true.
  TRY.
      SELECT COUNT(*) FROM zprt_dcqm INTO gv_total
        WHERE prd_stock_id = p_stokid.
      SELECT * FROM zprt_dcqm
        INTO CORRESPONDING FIELDS OF TABLE gt_alv
        WHERE prd_stock_id = p_stokid
          AND ( block_dc <> space OR block_qm <> space ).
      IF gt_alv IS NOT INITIAL.
        SELECT * FROM zprt_dcqmlt INTO TABLE lt_texts
          FOR ALL ENTRIES IN gt_alv
          WHERE exbilldocno = gt_alv-doc_no.
      ENDIF.
    CATCH cx_root INTO lr_error.
      PERFORM add_exception USING lr_error.
      RETURN.
  ENDTRY.
  SORT gt_alv BY doc_no envelope.
  SORT lt_texts BY exbilldocno.
  LOOP AT gt_alv ASSIGNING <ls_alv>.
    CLEAR ls_text.
    READ TABLE lt_texts INTO ls_text
      WITH KEY exbilldocno = <ls_alv>-doc_no BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_alv>-block_dc_text = ls_text-block_dc_text.
      <ls_alv>-block_qm_text = ls_text-block_qm_text.
    ENDIF.
    <ls_alv>-counter = 1.
    CLEAR: <ls_alv>-changed, <ls_alv>-handle_style.
  ENDLOOP.
  DESCRIBE TABLE gt_alv LINES gv_excluded.
  gv_allowed = gv_total - gv_excluded.
  gv_error = abap_false.
  gv_header_valid = abap_true.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form release_stock_new
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM release_stock_new .
  DATA: lt_displayed TYPE ty_alv_table,
        lv_displayed_total TYPE i,
        ls_after TYPE zprt_stock,
        lv_class_started TYPE abap_bool,
        lr_error TYPE REF TO cx_root.

  CHECK gv_busy = abap_false.
  REFRESH gt_messages.
  CLEAR: gv_saved, gv_call_started, gv_remote_success.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
  IF sy-subrc <> 0.
    MESSAGE s000 WITH text-201 gc_tcode DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF gv_modif <> abap_true OR gv_uncertain = abap_true.
    MESSAGE s000 WITH gv_block_reason DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF gv_locked_stock <> p_stokid.
    MESSAGE TEXT-111 TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  gv_busy = abap_true.
  PERFORM log_now USING 'I' text-310 space.
  TRY.
      DO 1 TIMES.
        PERFORM read_stock.
        IF gv_error = abap_true.
          PERFORM add_message USING 'E' text-202 p_stokid space.
          EXIT.
        ENDIF.
        PERFORM determine_mode.
        IF gv_modif <> abap_true.
          gv_error = abap_true.
          PERFORM add_message USING 'E' gv_block_reason p_stokid space.
          EXIT.
        ENDIF.

        lt_displayed = gt_alv.
        SORT lt_displayed BY doc_no envelope.
        lv_displayed_total = gv_total.
        PERFORM select_data.
        IF gv_error = abap_true.
          EXIT.
        ENDIF.
        IF lt_displayed <> gt_alv OR lv_displayed_total <> gv_total.
          gv_error = abap_true.
          PERFORM add_message USING 'E' text-203 space space.
          EXIT.
        ENDIF.
        IF gv_total = 0.
          gv_error = abap_true.
          PERFORM add_message USING 'E' text-204 p_stokid space.
          EXIT.
        ENDIF.

        "The unchanged class owns the priority popup and commits CL on success.
        "A normal return or SY-SUBRC alone is not a success indication.
        PERFORM log_stock_totals.
        PERFORM log_now USING 'I' text-313 space.
        lv_class_started = abap_true.
        zcl_pr_stock=>close_stock( iv_stock = p_stokid ).
        PERFORM log_now USING 'I' text-314 space.
        gv_error = abap_true.
        SELECT SINGLE * FROM zprt_stock BYPASSING BUFFER INTO ls_after
          WHERE stock_id = p_stokid.
        IF sy-subrc <> 0.
          gv_uncertain = abap_true.
          PERFORM add_message USING 'E' text-202 p_stokid space.
          EXIT.
        ENDIF.
        IF ls_after-status <> gc_status_closed.
          PERFORM add_message USING 'E' text-205 p_stokid space.
          EXIT.
        ENDIF.

        "Only the QM-to-CL transition observed under our lock permits the audit save.
        "The class commit has already completed; this is a separate local LUW.
        GET TIME.
        PERFORM log_now USING 'I' text-321 space.
        UPDATE zprt_stock
          SET status = gc_status_closed
              chuser = sy-uname
              chdate = sy-datum
              chtime = sy-uzeit
          WHERE stock_id = p_stokid
            AND status = gc_status_closed
            AND closed = space
            AND stock_status_er = space.
        IF sy-subrc <> 0 OR sy-dbcnt <> 1.
          ROLLBACK WORK.
          gv_uncertain = abap_true.
          PERFORM log_now USING 'E' text-323 space.
          PERFORM add_message USING 'E' text-206 p_stokid space.
          EXIT.
        ENDIF.
        COMMIT WORK.
        gv_saved = abap_true.
        gv_error = abap_false.
        PERFORM log_now USING 'S' text-322 space.
        PERFORM add_message USING 'S' text-207 p_stokid space.
      ENDDO.
    CATCH cx_root INTO lr_error.
      ROLLBACK WORK.
      gv_error = abap_true.
      IF lv_class_started = abap_true.
        gv_uncertain = abap_true.
      ENDIF.
      PERFORM add_exception USING lr_error.
  ENDTRY.

  IF gv_uncertain = abap_true.
    PERFORM mark_uncertain_state.
  ENDIF.
  gv_busy = abap_false.
  IF gv_saved <> abap_true.
    PERFORM add_message USING 'E' text-208 p_stokid space.
  ENDIF.
  IF gv_saved = abap_true.
    PERFORM log_now USING 'S' text-311 space.
  ELSE.
    PERFORM log_now USING 'E' text-312 space.
  ENDIF.
  PERFORM log_write.
  PERFORM read_stock.
  IF gv_error = abap_false.
    PERFORM determine_mode.
    PERFORM sync_lock.
  ELSE.
    gv_modif = abap_false.
    gv_block_reason = text-202.
    PERFORM unlock_stock.
  ENDIF.
  PERFORM refresh_grid.
  IF gv_saved = abap_true AND gv_log_error = abap_true.
    MESSAGE s000 WITH text-209 p_stokid DISPLAY LIKE 'E'.
  ELSEIF gv_saved = abap_true.
    MESSAGE s000 WITH text-207 p_stokid.
  ELSE.
    MESSAGE s000 WITH text-208 p_stokid DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.


FORM release_stock.
  DATA: lt_displayed       TYPE ty_alv_table,
        lt_regmail         TYPE ty_regmail_table,
        lv_displayed_total TYPE i,
        lv_confirmed       TYPE abap_bool,
        lv_priority_ok     TYPE abap_bool,
        lv_number          TYPE c LENGTH 20,
        lr_error           TYPE REF TO cx_root.

  CHECK gv_busy = abap_false.
  REFRESH gt_messages.
  CLEAR: gv_saved, gv_call_started, gv_remote_success.
  gv_error = abap_true.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
  IF sy-subrc <> 0.
    MESSAGE s000 WITH 'Nincs jogosultsag a tranzakciohoz:' gc_tcode
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF gv_modif <> abap_true OR gv_uncertain = abap_true.
    MESSAGE s000 WITH gv_block_reason DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF gv_locked_stock <> p_stokid.
    gv_modif = abap_false.
    gv_block_reason = TEXT-111.
    PERFORM refresh_grid.
    MESSAGE TEXT-111 TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM get_priority CHANGING lv_priority_ok.
  CHECK lv_priority_ok = abap_true.
  PERFORM confirm_release CHANGING lv_confirmed.
  CHECK lv_confirmed = abap_true.
  gv_busy = abap_true.

  PERFORM lock_stock.
  IF gv_locked_stock IS INITIAL.
    gv_busy = abap_false.
    RETURN.
  ENDIF.
  TRY.
      PERFORM read_stock.
      IF gv_error = abap_true.
        PERFORM add_message USING 'E' 'A stock nem létezik:' p_stokid space.
      ELSE.
        PERFORM determine_mode.
        IF gv_modif <> abap_true.
          gv_error = abap_true.
          PERFORM add_message USING 'E' gv_block_reason p_stokid space.
        ENDIF.
      ENDIF.

      IF gv_error = abap_false.
        lt_displayed = gt_alv.
        SORT lt_displayed BY doc_no envelope.
        lv_displayed_total = gv_total.
        PERFORM select_data.
        IF gv_error = abap_false
           AND ( lt_displayed <> gt_alv OR lv_displayed_total <> gv_total ).
          gv_error = abap_true.
          PERFORM add_message USING 'E'
            'Az adatok változtak; ellenőrizze az új listát.' space space.
        ENDIF.
      ENDIF.

      IF gv_error = abap_false AND gv_total = 0.
        gv_error = abap_true.
        PERFORM add_message USING 'E'
          'A stockhoz nincs nyomtatási sor.' p_stokid space.
      ENDIF.
      IF gv_error = abap_false.
        PERFORM prepare_regmail CHANGING lt_regmail.
      ENDIF.
      IF gv_error = abap_false.
        PERFORM send_priority.
      ENDIF.

      IF gv_error = abap_false AND gv_remote_success = abap_true.
        PERFORM save_release USING lt_regmail.
      ENDIF.
    CATCH cx_root INTO lr_error.
      ROLLBACK WORK.
      gv_error = abap_true.
      IF gv_call_started = abap_true OR gv_remote_success = abap_true.
        gv_uncertain = abap_true.
      ENDIF.
      PERFORM add_exception USING lr_error.
  ENDTRY.

  IF gv_uncertain = abap_true.
    PERFORM mark_uncertain_state.
  ENDIF.
  PERFORM unlock_stock.
  gv_busy = abap_false.

  IF gv_saved = abap_true.
    PERFORM add_message USING 'S' 'Stock lezárása sikeres:'
      p_stokid gv_priority.
    WRITE gv_total TO lv_number LEFT-JUSTIFIED.
    PERFORM add_message USING 'S' 'Nyomtatási sorok száma:' lv_number space.
    WRITE gv_excluded TO lv_number LEFT-JUSTIFIED.
    PERFORM add_message USING 'S' 'Kizárt sorok száma:' lv_number space.
    WRITE gv_allowed TO lv_number LEFT-JUSTIFIED.
    PERFORM add_message USING 'S' 'Engedélyezett sorok száma:' lv_number space.
    IF gs_stock-notest = abap_true.
      PERFORM add_message USING 'I' 'A stock NOTEST jelzője be van állítva.'
        space space.
    ENDIF.
  ELSE.
    PERFORM add_message USING 'E' 'A stock nem lett lezárva:' p_stokid space.
  ENDIF.
  PERFORM log_write.
  PERFORM read_stock.
  IF gv_error = abap_false.
    PERFORM determine_mode.
    PERFORM sync_lock.
  ELSE.
    gv_modif = abap_false.
    gv_block_reason = 'A stock beolvasása sikertelen.'.
    PERFORM unlock_stock.
  ENDIF.
  PERFORM refresh_grid.
  IF gv_saved = abap_true AND gv_log_error = abap_true.
    MESSAGE s000 WITH 'A stock lezárt, de a napló kezelése hibás:' p_stokid
      DISPLAY LIKE 'E'.
  ELSEIF gv_saved = abap_true.
    MESSAGE s000 WITH 'A stock lezárása sikeres:' p_stokid.
  ELSE.
    MESSAGE s000 WITH 'A stock nem lett lezárva. Lásd a naplót.'
      DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

FORM get_priority CHANGING cv_ok TYPE abap_bool.
  DATA: lt_fields TYPE STANDARD TABLE OF sval,
        ls_field  TYPE sval,
        lv_return TYPE c LENGTH 1.
  cv_ok = abap_false.
  CLEAR ls_field.
  ls_field-tabname = 'ZPRT_STOCK'.
  ls_field-fieldname = 'PRIORITY'.
  IF gs_stock-priority IS INITIAL.
    ls_field-value = gc_default_priority.
  ELSE.
    ls_field-value = gs_stock-priority.
  ENDIF.
  ls_field-field_obl = abap_true.
  APPEND ls_field TO lt_fields.
  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING
      popup_title     = 'Engedélyezés: adja meg a prioritást'
    IMPORTING
      returncode      = lv_return
    TABLES
      fields          = lt_fields
    EXCEPTIONS
      error_in_fields = 1
      OTHERS          = 2.
  IF sy-subrc <> 0 OR lv_return = 'A'.
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field INDEX 1.
  IF sy-subrc <> 0 OR ls_field-value IS INITIAL.
    MESSAGE s000 WITH 'A prioritás megadása kötelező.' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  gv_priority = ls_field-value.
  IF gv_priority IS INITIAL.
    MESSAGE s000 WITH 'A prioritás nem lehet nulla.' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  cv_ok = abap_true.
ENDFORM.

FORM confirm_release CHANGING cv_ok TYPE abap_bool.
  DATA: lv_answer   TYPE c LENGTH 1,
        lv_question TYPE c LENGTH 200.
  cv_ok = abap_false.
  CONCATENATE 'Engedélyezi és lezárja a stockot?' p_stokid
    'Prioritás:' gv_priority INTO lv_question SEPARATED BY space.
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Stock lezárása'
      text_question         = lv_question
      default_button        = '2'
      display_cancel_button = abap_true
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.
  IF sy-subrc = 0 AND lv_answer = '1'.
    cv_ok = abap_true.
  ENDIF.
ENDFORM.

FORM lock_stock.
  IF gv_locked_stock = p_stokid.
    RETURN.
  ENDIF.
  PERFORM unlock_stock.
  CALL FUNCTION 'ENQUEUE_EZPRT_STOCK'
    EXPORTING
      stock_id       = p_stokid
      _scope         = '1'
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    gv_block_reason = text-125.
    MESSAGE text-125 TYPE 'I' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  gv_locked_stock = p_stokid.
ENDFORM.

FORM unlock_stock.
  CHECK gv_locked_stock IS NOT INITIAL.
  CALL FUNCTION 'DEQUEUE_EZPRT_STOCK'
    EXPORTING
      stock_id = gv_locked_stock
      _scope   = '1'.
  CLEAR gv_locked_stock.
ENDFORM.

FORM check_regmail_tables.
  DATA: lt_fields      TYPE STANDARD TABLE OF dfies,
        ls_field       TYPE dfies,
        lv_table_class TYPE dd02l-tabclass.
  gv_error = abap_true.
  SELECT SINGLE tabclass FROM dd02l INTO lv_table_class
    WHERE tabname = gc_terti_table AND as4local = 'A' AND as4vers = '0000'.
  IF sy-subrc <> 0 OR lv_table_class <> 'TRANSP'.
    PERFORM add_message USING 'E' 'Hiányzó transzparens tábla:'
      gc_terti_table space.
    RETURN.
  ENDIF.
  CALL FUNCTION 'DDIF_FIELDINFO_GET'
    EXPORTING
      tabname        = gc_terti_table
    TABLES
      dfies_tab      = lt_fields
    EXCEPTIONS
      not_found      = 1
      internal_error = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    PERFORM add_message USING 'E' 'Hiányzó ragszámtábla:'
      gc_terti_table space.
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'MANDT'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CLNT' OR ls_field-leng <> 3.
    PERFORM add_message USING 'E' 'A tábla nem mandantfüggő:'
      gc_terti_table space.
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'ENVELOPE_ID'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CHAR' OR ls_field-leng <> 9.
    PERFORM add_message USING 'E' 'Nem megfelelő táblamező:'
      gc_terti_table 'ENVELOPE_ID'.
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'EXBILLDOCNO'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CHAR' OR ls_field-leng <> 20.
    PERFORM add_message USING 'E' 'Nem megfelelő táblamező:'
      gc_terti_table 'EXBILLDOCNO'.
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field
    WITH KEY fieldname = 'ZISU_RAGSZAM_128'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CHAR' OR ls_field-leng <> 16.
    PERFORM add_message USING 'E' 'Nem megfelelő táblamező:'
      gc_terti_table 'ZISU_RAGSZAM_128'.
    RETURN.
  ENDIF.
  REFRESH lt_fields.
  CLEAR lv_table_class.
  SELECT SINGLE tabclass FROM dd02l INTO lv_table_class
    WHERE tabname = gc_f064_table AND as4local = 'A' AND as4vers = '0000'.
  IF sy-subrc <> 0 OR lv_table_class <> 'TRANSP'.
    PERFORM add_message USING 'E' 'Hiányzó transzparens tábla:'
      gc_f064_table space.
    RETURN.
  ENDIF.
  CALL FUNCTION 'DDIF_FIELDINFO_GET'
    EXPORTING
      tabname        = gc_f064_table
    TABLES
      dfies_tab      = lt_fields
    EXCEPTIONS
      not_found      = 1
      internal_error = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    PERFORM add_message USING 'E' 'Hiányzó ragszámtábla:'
      gc_f064_table space.
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'MANDT'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CLNT' OR ls_field-leng <> 3.
    PERFORM add_message USING 'E' 'A tábla nem mandantfüggő:'
      gc_f064_table space.
    RETURN.
  ENDIF.
  READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'ZISU_RAGSZAM'.
  IF sy-subrc <> 0 OR ls_field-datatype <> 'CHAR' OR ls_field-leng <> 16.
    PERFORM add_message USING 'E' 'Nem megfelelő táblamező:'
      gc_f064_table 'ZISU_RAGSZAM'.
    RETURN.
  ENDIF.
  gv_error = abap_false.
ENDFORM.

FORM prepare_regmail CHANGING ct_regmail TYPE ty_regmail_table.
  DATA: ls_alv   TYPE zprs_dcqm_report,
        lt_found TYPE ty_regmail_table,
        ls_found TYPE ty_regmail,
        lr_error TYPE REF TO cx_root.
  REFRESH ct_regmail.
  gv_error = abap_false.
  CHECK gt_alv IS NOT INITIAL.
  PERFORM check_regmail_tables.
  CHECK gv_error = abap_false.
  TRY.
      LOOP AT gt_alv INTO ls_alv.
        IF ls_alv-doc_no IS INITIAL.
*        IF ls_alv-doc_no IS INITIAL OR ls_alv-envelope IS INITIAL.
          gv_error = abap_true.
          PERFORM add_message USING 'E' 'Hiányzó dokumentum vagy boríték:'
            ls_alv-doc_no ls_alv-envelope.
          RETURN.
        ENDIF.
        REFRESH lt_found.

        SELECT envelope_id exbilldocno zisu_ragszam_128
          FROM (gc_terti_table) INTO TABLE lt_found
          WHERE zisu_ragszam_128 = ls_alv-regmailnumber
            AND envelope_id = ls_alv-envelope
            AND exbilldocno = ls_alv-doc_no.

        IF ls_alv-regmailnumber IS NOT INITIAL AND lt_found IS INITIAL.
          gv_error = abap_true.
          PERFORM add_message USING 'E' 'Ragszámhoz nincs TERTI rekord:'
            ls_alv-doc_no ls_alv-regmailnumber.
          RETURN.
        ENDIF.
        LOOP AT lt_found INTO ls_found.
          IF ls_found-zisu_ragszam_128 IS INITIAL.
            gv_error = abap_true.
            PERFORM add_message USING 'E' 'A TERTI ragszáma üres:'
              ls_alv-doc_no space.
            RETURN.
          ENDIF.
          APPEND ls_found TO ct_regmail.
        ENDLOOP.
      ENDLOOP.
    CATCH cx_root INTO lr_error.
      gv_error = abap_true.
      PERFORM add_exception USING lr_error.
  ENDTRY.
  SORT ct_regmail BY envelope_id exbilldocno zisu_ragszam_128.
  DELETE ADJACENT DUPLICATES FROM ct_regmail COMPARING ALL FIELDS.
ENDFORM.

FORM send_priority.
  DATA: ls_input     TYPE zpr_eon_dcqmcompleted_request2,
        ls_output    TYPE zpr_eon_dcqmcompleted_response,
        lt_envelopes TYPE zpr_eon_dcqmcompleted_requ_tab,
        ls_envelope  TYPE zpr_eon_dcqmcompleted_request1,
        ls_alv       TYPE zprs_dcqm_report,
        lo_proxy     TYPE REF TO zpr_co_eon_dcqmcompleted_port,
        lv_port      TYPE prx_logical_port_name,
        lr_error     TYPE REF TO cx_root.

  "Only an explicit successful response permits local closing.
  gv_error = abap_true.
  CLEAR: gv_call_started, gv_remote_success.

  LOOP AT gt_alv INTO ls_alv.
    CLEAR ls_envelope.
    ls_envelope-envelope_id = ls_alv-envelope.
    APPEND ls_envelope TO lt_envelopes.
  ENDLOOP.

  SORT lt_envelopes BY envelope_id.
  DELETE ADJACENT DUPLICATES FROM lt_envelopes COMPARING envelope_id.

  ls_input-sap_mandant = sy-mandt.
  ls_input-sap_system = sy-sysid.
  ls_input-stock_id = p_stokid.
  ls_input-priority = gv_priority.
  ls_input-exclude_envelopes-envelope = lt_envelopes.

  TRY.
      lv_port = zcl_pr_output_management=>get_logical_port_name( ).
      IF lv_port IS INITIAL.
        PERFORM add_message USING 'E' 'Az Inspire logikai portja üres.'
          space space.
        RETURN.
      ENDIF.
      CREATE OBJECT lo_proxy EXPORTING logical_port_name = lv_port.
      gv_call_started = abap_true.
      lo_proxy->eon_dcqmcompleted(
        EXPORTING input = ls_input IMPORTING output = ls_output ).

    CATCH cx_ai_application_fault INTO lr_error.
      gv_error = abap_true.
      CLEAR: gv_call_started, gv_remote_success.
      PERFORM add_exception USING lr_error.
      PERFORM add_message USING 'E'
        'Az Inspire elutasította a lezárást:'
        p_stokid space.
      RETURN.
    CATCH cx_root INTO lr_error.
      PERFORM add_exception USING lr_error.
      IF gv_call_started = abap_true.
        gv_uncertain = abap_true.
        PERFORM add_message USING 'E' 'Az Inspire eredménye bizonytalan:'
          p_stokid 'Újraküldés előtt ellenőrzés szükséges.'.
      ENDIF.
      RETURN.
  ENDTRY.
  IF ls_output-parameters-success <> abap_true.
    PERFORM add_message USING 'E' 'Az Inspire elutasitotta a lezárást:'
      ls_output-parameters-error_code ls_output-parameters-info.
    RETURN.
  ENDIF.
  gv_remote_success = abap_true.
  gv_error = abap_false.
  PERFORM add_message USING 'S' 'Inspire jóváhagyás sikeres:' p_stokid space.
ENDFORM.

FORM save_release USING ut_regmail TYPE ty_regmail_table.
  DATA: ls_regmail TYPE ty_regmail,
        lt_current TYPE ty_regmail_table,
        lr_error   TYPE REF TO cx_root.
  gv_error = abap_true.
  gv_saved = abap_false.
  CHECK gv_remote_success = abap_true.
  CHECK gv_locked_stock = p_stokid.
  PERFORM prepare_regmail CHANGING lt_current.
  IF gv_error = abap_true OR lt_current <> ut_regmail.
    gv_error = abap_true.
    gv_uncertain = abap_true.
    PERFORM add_message USING 'E' 'A ragszámok változtak; a lezárás megszakadt.'
      p_stokid space.
    RETURN.
  ENDIF.
  gv_error = abap_true.
  TRY.
      LOOP AT ut_regmail INTO ls_regmail.
        DELETE FROM (gc_terti_table)
          WHERE envelope_id = ls_regmail-envelope_id
            AND exbilldocno = ls_regmail-exbilldocno
            AND zisu_ragszam_128 = ls_regmail-zisu_ragszam_128.
        IF sy-subrc <> 0.
          ROLLBACK WORK.
          gv_uncertain = abap_true.
          PERFORM add_message USING 'E' 'A TERTI törlés sikertelen:'
            ls_regmail-exbilldocno ls_regmail-zisu_ragszam_128.
          RETURN.
        ENDIF.
        "A missing F064 row is allowed; SQL exceptions abort the LUW.
        DELETE FROM (gc_f064_table)
          WHERE zisu_ragszam = ls_regmail-zisu_ragszam_128.
        IF sy-subrc NE 0.
          PERFORM add_message USING 'E' 'A ZISU_F064 törlés sikertelen:'
            ls_regmail-exbilldocno ls_regmail-zisu_ragszam_128.
        ENDIF.
      ENDLOOP.
      UPDATE zprt_stock
        SET closed = abap_true
            status = gc_status_closed
            priority = gv_priority
            erdat_clo = sy-datum
            ernam_clo = sy-uname
            ertim_clo = sy-uzeit
            chuser = sy-uname
            chdate = sy-datum
            chtime = sy-uzeit
        WHERE stock_id = p_stokid
          AND closed = space
          AND status = gc_status_qm
          AND stock_status_er = space.
      IF sy-subrc <> 0 OR sy-dbcnt <> 1.
        ROLLBACK WORK.
        gv_uncertain = abap_true.
        PERFORM add_message USING 'E' 'A stock mentése sikertelen:'
          p_stokid space.
        RETURN.
      ENDIF.
      COMMIT WORK.
      gv_saved = abap_true.
      gv_error = abap_false.
    CATCH cx_root INTO lr_error.
      ROLLBACK WORK.
      gv_uncertain = abap_true.
      PERFORM add_exception USING lr_error.
  ENDTRY.
ENDFORM.

FORM mark_uncertain_state.
  DATA lr_error TYPE REF TO cx_root.
  "Persist a retry block without marking the stock as closed.
  TRY.
      UPDATE zprt_stock
        SET stock_status_er = abap_true
            chuser = sy-uname chdate = sy-datum chtime = sy-uzeit
        WHERE stock_id = p_stokid.
      IF sy-subrc = 0 AND sy-dbcnt = 1.
        COMMIT WORK.
        PERFORM add_message USING 'E' 'Stock újraküldése tiltva; ellenőrizendő:'
          p_stokid space.
      ELSE.
        ROLLBACK WORK.
        PERFORM add_message USING 'E' 'A hibajelző sem menthető; ne küldje újra!'
          p_stokid space.
      ENDIF.
    CATCH cx_root INTO lr_error.
      ROLLBACK WORK.
      PERFORM add_exception USING lr_error.
      PERFORM add_message USING 'E' 'Ne indítsa újra külső ellenőrzés nélkül!'
        p_stokid space.
  ENDTRY.
ENDFORM.

FORM add_message USING uv_type TYPE symsgty uv_text TYPE clike
                       uv_value1 TYPE clike uv_value2 TYPE clike.
  DATA: ls_message TYPE bal_s_msg,
        lv_text    TYPE c LENGTH 200.
  CONCATENATE uv_text uv_value1 uv_value2 INTO lv_text SEPARATED BY space.
  ls_message-msgid = 'ZPR'.
  ls_message-msgno = '000'.
  ls_message-msgty = uv_type.
  ls_message-msgv1 = lv_text+0(50).
  ls_message-msgv2 = lv_text+50(50).
  ls_message-msgv3 = lv_text+100(50).
  ls_message-msgv4 = lv_text+150(50).
  APPEND ls_message TO gt_messages.
ENDFORM.

FORM add_exception USING ur_error TYPE REF TO cx_root.
  DATA: ls_message TYPE bal_s_msg,
        lv_text    TYPE c LENGTH 200.
  lv_text = ur_error->get_text( ).
  ls_message-msgid = 'ZPR'.
  ls_message-msgno = '000'.
  ls_message-msgty = 'E'.
  ls_message-msgv1 = lv_text+0(50).
  ls_message-msgv2 = lv_text+50(50).
  ls_message-msgv3 = lv_text+100(50).
  ls_message-msgv4 = lv_text+150(50).
  APPEND ls_message TO gt_messages.
ENDFORM.

FORM log_write.
  DATA: lo_log     TYPE REF TO zcl_pr_log,
        lr_error   TYPE REF TO cx_root,
        ls_message TYPE bal_s_msg,
        lv_text    TYPE string.
  gv_log_error = abap_false.
  CHECK gt_messages IS NOT INITIAL.
  "Business changes have already been committed or rolled back.
  TRY.
      CREATE OBJECT lo_log
        EXPORTING
          iv_log_object    = gc_log_object
          iv_log_subobject = gc_log_subobject.
      LOOP AT gt_messages INTO ls_message.
        MESSAGE ID ls_message-msgid TYPE ls_message-msgty
          NUMBER ls_message-msgno
          WITH ls_message-msgv1 ls_message-msgv2
               ls_message-msgv3 ls_message-msgv4 INTO gv_dummy.
        lo_log->add_system_message( ).
      ENDLOOP.
      lo_log->close( ).
      COMMIT WORK.
      lo_log->display( ).
    CATCH cx_root INTO lr_error.
      ROLLBACK WORK.
      gv_log_error = abap_true.
      lv_text = lr_error->get_text( ).
      MESSAGE s000 WITH 'A napló nem menthető/megjeleníthető:' lv_text
        DISPLAY LIKE 'E'.
  ENDTRY.
ENDFORM.

FORM stock_f4.
  DATA: lt_stocks  TYPE STANDARD TABLE OF ty_stock_f4,
        lt_returns TYPE STANDARD TABLE OF ddshretval,
        ls_return  TYPE ddshretval.
  SELECT stock_id status closed dccompl qmcompl priority
    FROM zprt_stock INTO TABLE lt_stocks UP TO 5000 ROWS
    ORDER BY stock_id DESCENDING.
  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield        = 'STOCK_ID'
      value_org       = 'S'
      window_title    = 'Stockok (legfeljebb 5000)'
    TABLES
      value_tab       = lt_stocks
      return_tab      = lt_returns
    EXCEPTIONS
      parameter_error = 1
      no_values_found = 2
      OTHERS          = 3.
  IF sy-subrc = 0.
    READ TABLE lt_returns INTO ls_return INDEX 1.
    IF sy-subrc = 0.
      p_stokid = ls_return-fieldval.
    ENDIF.
  ENDIF.
ENDFORM.

FORM create_controls_0100.
  DATA: lt_fields   TYPE lvc_t_fcat,
        ls_layout   TYPE lvc_s_layo,
        ls_variant  TYPE disvariant,
        lt_exclude  TYPE ui_functions,
        lv_function TYPE ui_func.
  FIELD-SYMBOLS <ls_field> TYPE lvc_s_fcat.
  IF gr_header_container IS NOT BOUND.
    CREATE OBJECT gr_header_container
      EXPORTING
        repid     = sy-repid
        dynnr     = sy-dynnr
        side      = cl_gui_docking_container=>dock_at_top
        extension = 110
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      FREE gr_header_container.
      MESSAGE text-128 TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.
  ENDIF.
  PERFORM build_header.

  CHECK gr_grid IS NOT BOUND.
  CREATE OBJECT gr_container
    EXPORTING
      container_name = 'ALV_CONTAINER_01'
    EXCEPTIONS
      OTHERS         = 1.
  IF sy-subrc <> 0.
    MESSAGE e000 WITH 'Az ALV-konténer nem hozható létre.'.
  ENDIF.
  CREATE OBJECT gr_grid
    EXPORTING
      i_parent      = gr_container
      i_appl_events = abap_true.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = 'ZPRS_DCQM_REPORT'
    CHANGING
      ct_fieldcat            = lt_fields
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.
  IF sy-subrc <> 0.
    MESSAGE e000 WITH 'Az ALV-mezőkatalógus nem készíthető el.'.
  ENDIF.
  LOOP AT lt_fields ASSIGNING <ls_field>.
    <ls_field>-edit = abap_false.
    <ls_field>-f4availabl = abap_false.
    IF <ls_field>-fieldname = 'CHANGED'
       OR <ls_field>-fieldname = 'HANDLE_STYLE'.
      <ls_field>-tech = abap_true.
    ELSEIF <ls_field>-fieldname = 'COUNTER'.
      <ls_field>-do_sum = abap_true.
      <ls_field>-coltext = 'Sorok száma'.
      <ls_field>-col_pos = 99.
    ENDIF.
  ENDLOOP.
  ls_layout-zebra = abap_true.
  ls_layout-cwidth_opt = abap_true.
  ls_layout-no_rowmark = abap_true.
  ls_variant-report = sy-repid.
  ls_variant-username = sy-uname.
  ls_variant-variant = p_vari.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_append_row.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_insert_row.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_delete_row.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_copy_row.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_cut.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_paste.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_loc_undo.
  APPEND lv_function TO lt_exclude.
  lv_function = cl_gui_alv_grid=>mc_fc_refresh.
  APPEND lv_function TO lt_exclude.
  SET HANDLER lcl_grid_events=>on_toolbar
              lcl_grid_events=>on_user_command FOR gr_grid.
  gr_grid->set_table_for_first_display(
    EXPORTING is_layout = ls_layout is_variant = ls_variant
              i_save = 'A' it_toolbar_excluding = lt_exclude
    CHANGING it_outtab = gt_alv it_fieldcatalog = lt_fields
    EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc <> 0.
    MESSAGE e000 WITH 'Az ALV-lista nem jeleníthető meg.'.
  ENDIF.
  gr_grid->set_ready_for_input(
    i_ready_for_input = 0                " Ready for Input Status
  ).
  gr_grid->set_toolbar_interactive( ).
ENDFORM.

FORM refresh_grid.
  DATA ls_stable TYPE lvc_s_stbl.
  PERFORM build_header.
  CHECK gr_grid IS BOUND.

  ls_stable-row = abap_true.
  ls_stable-col = abap_true.

  gr_grid->refresh_table_display(
    EXPORTING is_stable = ls_stable EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc <> 0.
    MESSAGE i000 WITH 'Az ALV-lista frissítése sikertelen.'
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  gr_grid->set_toolbar_interactive( ).
ENDFORM.

FORM reload_display.
  CHECK gv_busy = abap_false.
  REFRESH gt_messages.
  PERFORM read_stock.
  IF gv_error = abap_true.
    gv_modif = abap_false.
    PERFORM unlock_stock.
    PERFORM refresh_grid.
    MESSAGE s000 WITH 'A stock nem olvasható:' p_stokid DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM determine_mode.

  PERFORM sync_lock.
  IF gv_error = abap_true.
    PERFORM unlock_stock.
    PERFORM log_write.
    PERFORM refresh_grid.
    RETURN.
  ENDIF.

  PERFORM select_data.
  IF gv_error = abap_true.
    gv_modif = abap_false.
    PERFORM unlock_stock.
    PERFORM log_write.
  ENDIF.
  PERFORM refresh_grid.
ENDFORM.

FORM user_command_0100.
  DATA: lv_okcode      TYPE syucomm,
        lv_return_code TYPE i.
  lv_okcode = gv_okcode_0100.
  CLEAR gv_okcode_0100.
  cl_gui_cfw=>dispatch(
    IMPORTING return_code = lv_return_code ).
  IF lv_return_code = cl_gui_cfw=>rc_unknown
     OR lv_return_code = cl_gui_cfw=>rc_nodispatch.
    MESSAGE s000 WITH 'Az ALV-esemény feldolgozása sikertelen.'
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF lv_return_code = cl_gui_cfw=>rc_found.
    RETURN.
  ENDIF.
  CASE lv_okcode.
    WHEN 'REFRESH'.
      PERFORM reload_display.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      PERFORM exit_screen.
  ENDCASE.
ENDFORM.

FORM exit_command_0100.
  DATA lv_okcode TYPE syucomm.
  lv_okcode = gv_okcode_0100.
  CLEAR gv_okcode_0100.
  CASE lv_okcode.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      PERFORM exit_screen.
  ENDCASE.
ENDFORM.

FORM exit_screen.
  CHECK gv_busy = abap_false.
  PERFORM unlock_stock.
  SET SCREEN 0.
  LEAVE SCREEN.
ENDFORM.

FORM free_controls.
  DATA lv_free_failed TYPE abap_bool.

  IF gr_grid IS BOUND.
    gr_grid->free( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      lv_free_failed = abap_true.
    ENDIF.
    FREE gr_grid.
  ENDIF.

  IF gr_container IS BOUND.
    gr_container->free( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      lv_free_failed = abap_true.
    ENDIF.
    FREE gr_container.
  ENDIF.

  FREE gr_header.
  IF gr_header_container IS BOUND.
    gr_header_container->free( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      lv_free_failed = abap_true.
    ENDIF.
    FREE gr_header_container.
  ENDIF.
  CLEAR gv_header_valid.

  IF lv_free_failed = abap_true.
    MESSAGE i000 WITH 'Az ALV-vezérlők felszabadítása során hiba történt.'
      DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.

FORM build_header.
  "Display the stock summary independently of the release action.
  DATA: lv_text TYPE sdydo_text_element,
        lv_number TYPE c LENGTH 20,
        lv_reuse TYPE abap_bool.
  CHECK gr_header_container IS BOUND.
  IF gr_header IS BOUND.
    lv_reuse = abap_true.
    gr_header->initialize_document( ).
  ELSE.
    CREATE OBJECT gr_header.
  ENDIF.

  CONCATENATE text-136 p_stokid INTO lv_text SEPARATED BY space.
  PERFORM add_header_line USING lv_text.

  IF gv_header_valid = abap_true.
    WRITE gv_total TO lv_number LEFT-JUSTIFIED.
  ELSE.
    lv_number = text-141.
  ENDIF.
  CONCATENATE text-137 lv_number INTO lv_text SEPARATED BY space.
  PERFORM add_header_line USING lv_text.

  IF gv_header_valid = abap_true.
    WRITE gv_excluded TO lv_number LEFT-JUSTIFIED.
  ELSE.
    lv_number = text-141.
  ENDIF.
  CONCATENATE text-138 lv_number INTO lv_text SEPARATED BY space.
  PERFORM add_header_line USING lv_text.

  gr_header->merge_document( ).
  gr_header->display_document(
    EXPORTING parent = gr_header_container reuse_control = lv_reuse
    EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc <> 0.
    MESSAGE text-140 TYPE 'S' DISPLAY LIKE 'W'.
  ENDIF.
ENDFORM.

FORM add_header_line USING uv_text TYPE sdydo_text_element.
  gr_header->add_text( text = uv_text
    sap_emphasis = cl_dd_document=>strong ).
  gr_header->new_line( ).
ENDFORM.
"Logging only: use the complete stock, including allowed and excluded rows.
FORM log_stock_totals.
  TYPES: BEGIN OF ty_log_row,
           package_id TYPE zprt_dcqm-package_id,
           doc_no     TYPE zprt_dcqm-doc_no,
         END OF ty_log_row.
  DATA: lt_rows        TYPE STANDARD TABLE OF ty_log_row,
        ls_row         TYPE ty_log_row,
        lt_packages    TYPE SORTED TABLE OF zprt_dcqm-package_id
                         WITH UNIQUE KEY table_line,
        lt_documents   TYPE SORTED TABLE OF zprt_dcqm-doc_no
                         WITH UNIQUE KEY table_line,
        lv_count       TYPE i,
        lv_no_package  TYPE i,
        lv_no_document TYPE i,
        lv_number      TYPE c LENGTH 20,
        lv_error_text  TYPE string,
        lr_error       TYPE REF TO cx_root.

  PERFORM log_now USING 'I' text-307 space.
  TRY.
      SELECT package_id doc_no FROM zprt_dcqm INTO TABLE lt_rows
        WHERE prd_stock_id = p_stokid.
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
      WRITE lv_count TO lv_number LEFT-JUSTIFIED.
      PERFORM add_message USING 'I' text-301 lv_number space.
      DESCRIBE TABLE lt_documents LINES lv_count.
      WRITE lv_count TO lv_number LEFT-JUSTIFIED.
      PERFORM add_message USING 'I' text-302 lv_number space.
      DESCRIBE TABLE lt_rows LINES lv_count.
      WRITE lv_count TO lv_number LEFT-JUSTIFIED.
      PERFORM add_message USING 'I' text-303 lv_number space.
      IF lv_no_package > 0.
        WRITE lv_no_package TO lv_number LEFT-JUSTIFIED.
        PERFORM add_message USING 'W' text-304 lv_number space.
      ENDIF.
      IF lv_no_document > 0.
        WRITE lv_no_document TO lv_number LEFT-JUSTIFIED.
        PERFORM add_message USING 'W' text-305 lv_number space.
      ENDIF.
    CATCH cx_root INTO lr_error.
      lv_error_text = lr_error->get_text( ).
      PERFORM add_message USING 'W' text-306 p_stokid lv_error_text.
  ENDTRY.
ENDFORM.

FORM log_now USING uv_type TYPE symsgty uv_event TYPE clike
                   uv_detail TYPE clike.
  DATA lv_stamp TYPE timestampl.
  GET TIME STAMP FIELD lv_stamp.
  PERFORM log_at USING uv_type uv_event lv_stamp uv_detail.
ENDFORM.

FORM log_at USING uv_type TYPE symsgty uv_event TYPE clike
                  uv_stamp TYPE timestampl uv_detail TYPE clike.
  DATA: lv_time   TYPE c LENGTH 40,
        lv_detail TYPE c LENGTH 100.
  lv_time = |{ uv_stamp TIMESTAMP = ISO TIMEZONE = 'UTC' } UTC|.
  CONCATENATE p_stokid uv_detail INTO lv_detail SEPARATED BY space.
  PERFORM add_message USING uv_type uv_event lv_time lv_detail.
ENDFORM.

