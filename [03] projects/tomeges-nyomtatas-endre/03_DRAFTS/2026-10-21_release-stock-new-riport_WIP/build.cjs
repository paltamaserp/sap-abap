const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');
const dir = 'C:/Users/T13214/Documents/work/sap-abap-main/[03] projects/tomeges-nyomtatas-endre/03_DRAFTS/2026-10-21_release-stock-new-riport_WIP';
const base = path.resolve(dir, '../../05_FINAL/abap-2026-10-17');
const read = name => fs.readFileSync(path.join(base, name), 'utf8').replace(/\r\n/g, '\n');
const write = (name, value) => fs.writeFileSync(path.join(dir, name), value.replace(/\r?\n/g, '\r\n'));
let report = read('ZPR_CLOSE_STOCK.abap');
assert.equal(report.split('       PERFORM release_stock.').length, 2);
report = report.replace('       PERFORM release_stock.', '       PERFORM release_stock_new.');
const routine = `FORM release_stock_new.
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
        lv_class_started = abap_true.
        zcl_pr_stock=>close_stock( iv_stock = p_stokid ).
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
          PERFORM add_message USING 'E' text-206 p_stokid space.
          EXIT.
        ENDIF.
        COMMIT WORK.
        gv_saved = abap_true.
        gv_error = abap_false.
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

`;
assert.equal(report.split('FORM release_stock.\n').length, 2);
report = report.replace('FORM release_stock.\n', routine + 'FORM release_stock.\n');
write('ZPR_CLOSE_STOCK.abap', report);
write('ZPR_CLOSE_STOCK.texts.tsv', `ID\tNyelv\tSzöveg
201\tHU\tNincs jogosultság a tranzakcióhoz:
202\tHU\tA stock beolvasása sikertelen:
203\tHU\tAz adatok változtak; ellenőrizze az új listát.
204\tHU\tA stockhoz nincs nyomtatási sor:
205\tHU\tA lezárás sikere nem igazolható; ellenőrizze az osztály naplóját:
206\tHU\tA stock CL státuszú, de a CH* adatok mentése sikertelen:
207\tHU\tA stock CL státusza és a CH* adatok mentve:
208\tHU\tA riport nem igazolt sikeres státusz- és CH* mentést:
209\tHU\tA stockadatok mentve, de a napló kezelése hibás:
`);
console.log('Report-only local copy generated from ' + base);
