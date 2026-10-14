*&---------------------------------------------------------------------*
*& Include ZPR_MQ_REGISTER for the DHC email handoff producer.
*& Does not commit or roll back the caller's LUW.
*& After success the caller must close its LUW and release the lock.
*&---------------------------------------------------------------------*
FORM mq_register USING is_email TYPE zpr_slog_email
  CHANGING cv_ok TYPE abap_bool cv_error TYPE string
           cv_lock_held TYPE abap_bool.
  DATA: ls_email TYPE zpr_slog_email,
        ls_current TYPE zpr_slog_email,
        lv_stamp TYPE timestamp,
        lv_date TYPE d,
        lv_time TYPE t,
        lx_error TYPE REF TO cx_root.

  CLEAR: cv_error, cv_lock_held.
  cv_ok = abap_false.
  IF is_email-exbilldocno IS INITIAL OR is_email-tstmp_print IS INITIAL.
    cv_error = 'Dokumentumazonosító és átadási időbélyeg kötelező.'.
    RETURN.
  ENDIF.
  IF strlen( is_email-tstmp_print ) <> 14
    OR is_email-tstmp_print CN '0123456789'.
    cv_error = 'Az átadási időbélyeg formátuma YYYYMMDDhhmmss legyen.'.
    RETURN.
  ENDIF.
  lv_stamp = is_email-tstmp_print.
  CONVERT TIME STAMP lv_stamp TIME ZONE 'UTC'
    INTO DATE lv_date TIME lv_time.
  IF sy-subrc <> 0.
    cv_error = 'Érvénytelen Messenger-átadási időbélyeg.'.
    RETURN.
  ENDIF.
  IF is_email-sending_status IS NOT INITIAL.
    cv_error = 'Új küldést csak üres kezdeti státusszal lehet regisztrálni.'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'ENQUEUE_EZPR_SLOG_EMAIL'
    EXPORTING
      mode_zpr_slog_email = 'E'
      mandt = sy-mandt
      exbilldocno = is_email-exbilldocno
      _scope = '1'
      _wait = space
    EXCEPTIONS
      foreign_lock = 1
      system_failure = 2
      OTHERS = 3.
  IF sy-subrc <> 0.
    cv_error = 'Az e-mailnapló-bejegyzés nem zárolható.'.
    RETURN.
  ENDIF.
  cv_lock_held = abap_true.
  TRY.
      SELECT SINGLE * INTO ls_current FROM zpr_slog_email
        WHERE exbilldocno = is_email-exbilldocno.
      IF sy-subrc = 0.
        IF ls_current-tstmp_print = is_email-tstmp_print.
          cv_ok = abap_true.
        ELSE.
          cv_error = 'Ez a dokumentum már másik küldéssel regisztrált; nincs felülírás.'.
        ENDIF.
      ELSE.
        ls_email = is_email.
        ls_email-mandt = sy-mandt.
        INSERT zpr_slog_email FROM ls_email.
        IF sy-subrc = 0.
          cv_ok = abap_true.
        ELSE.
          cv_error = 'Az e-mailnapló-bejegyzés létrehozása sikertelen.'.
        ENDIF.
      ENDIF.
    CATCH cx_root INTO lx_error.
      cv_error = lx_error->get_text( ).
  ENDTRY.
  IF cv_ok = abap_false.
    PERFORM mq_register_unlock USING is_email-exbilldocno CHANGING cv_lock_held.
  ENDIF.
ENDFORM.

FORM mq_register_unlock USING iv_docno TYPE zpr_slog_email-exbilldocno
  CHANGING cv_lock_held TYPE abap_bool.
  IF cv_lock_held = abap_true.
    CALL FUNCTION 'DEQUEUE_EZPR_SLOG_EMAIL'
      EXPORTING
        mode_zpr_slog_email = 'E'
        mandt = sy-mandt
        exbilldocno = iv_docno
        _scope = '1'.
    cv_lock_held = abap_false.
  ENDIF.
ENDFORM.
