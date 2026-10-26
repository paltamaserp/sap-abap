*--------------------------------------------------------------------*
* Cockpit adapter. Called from SAPLZPR_COCKPIT, not by SUBMIT.
* The host owns the screen flow and all function codes.
*--------------------------------------------------------------------*
FORM cockpit_open USING iv_stock_id TYPE zprd_stock_id
                  CHANGING cv_ready TYPE abap_bool.

  cv_ready = abap_false.
* Preserve the authorization required by the original modifying entry point.
  AUTHORITY-CHECK OBJECT 'S_TCODE'
    ID 'TCD' FIELD 'ZPR_DC_EXCLUDE'.
  IF sy-subrc <> 0.
    MESSAGE i172(00) WITH 'ZPR_DC_EXCLUDE'.
    RETURN.
  ENDIF.

  PERFORM init_run.
  gv_embedded = abap_true.
  p_stokid = iv_stock_id.
  p_modif = abap_true.
  CLEAR: p_waers, p_vari.
* External PERFORM does not run the selection-screen events.
* Never inherit filters from another invocation of the report.
  REFRESH: so_docno, so_envlo, so_pymet, so_dcat, so_amnt,
           so_dued, so_bkacc, so_giro, so_name, so_sysid,
           so_land1, so_ab, so_bis, so_tarif, so_aklas,
           so_mahns, so_mahnv, so_zbizc, so_cotyp, so_form,
           so_pckid, so_aktyp, so_laufd, so_laufi,
           so_blodc, so_bloqm, so_regmn.
  PERFORM build_ranges.
  gv_modif = abap_true.
  PERFORM lock_and_check_stock.
  IF gv_embed_failed = abap_true.
    PERFORM unlock_stock.
    CLEAR: gv_embedded, gv_modif.
    RETURN.
  ENDIF.

  PERFORM select_data.
  IF gt_0100_alv IS INITIAL.
    PERFORM unlock_stock.
    gv_modif = abap_false.
    MESSAGE ID gc_msgid TYPE 'I' NUMBER gc_msgno-no_data WITH p_stokid.
  ENDIF.
  cv_ready = abap_true.
ENDFORM.

FORM cockpit_pbo USING io_container TYPE REF TO cl_gui_custom_container.

  CHECK gv_embedded = abap_true.
  CHECK io_container IS BOUND.
  CHECK go_alv_grid_01 IS INITIAL.

  go_alv_grid_cont_01 = io_container.
  PERFORM create_controls_0100.

ENDFORM.

FORM cockpit_save.
  CHECK gv_embedded = abap_true AND go_alv_grid_01 IS BOUND.
  gv_okcode_0100 = gc_ucomm_save.
  PERFORM user_command_0100.
ENDFORM.

FORM cockpit_close CHANGING cv_ok TYPE abap_bool.
  DATA: lv_answer TYPE char1,
        lv_valid  TYPE abap_bool VALUE abap_true.

  cv_ok = abap_false.
  IF go_alv_grid_01 IS BOUND.
* Even an invalid pending cell can be discarded explicitly.
    CALL METHOD go_alv_grid_01->check_changed_data
      IMPORTING
        e_valid = lv_valid.
  ENDIF.
  PERFORM check_changed.
  IF lv_valid <> abap_true.
    gv_changed = abap_true.
  ENDIF.
  IF gv_changed = abap_true.
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
        answer         = lv_answer.
    IF lv_answer <> 'J'.
      RETURN.
    ENDIF.
  ENDIF.

  PERFORM alv_grid_01_free.
  PERFORM init_run.
  CLEAR: gv_embedded, gv_embed_failed, gv_host_repid, gv_host_dynnr,
         gv_okcode_0100, p_stokid, p_modif.
  cv_ok = abap_true.
ENDFORM.