# ZPR_CLOSE_STOCK – kérdések és megoldási javaslat

Státusz: **WIP** · 2026-10-17
Forrás: [ZPR_CLOSE_STOCK.abap](../05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap) (mai aktív export),
[ZCL_PR_STOCK.abap](../01_SOURCES/DHC/ZCL_PR_STOCK.abap) (helyi DHC-másolat, **régebbi**: az aktív
verziót módosítás előtt vissza kell olvasni), QU5-referencia:
[ZEBF_PR_STOCK_REPORT.abap](../01_SOURCES/QU5/ZEBF_PR_STOCK_REPORT.abap).

SAP-hívás, SAP-írás és teszt nem történt (az ADT MCP ebben a sessionben nem csatlakozott).

---

## Összefoglaló – mi a gond és mi a megoldás

| # | Kérés | Mi a mostani állapot | Megoldás |
|---|---|---|---|
| 1 | Lezárt stocknál üzenet: „engedélyezve van, csak megtekintés” | A `DETERMINE_MODE` beállítja a `GV_BLOCK_REASON`-t, de **megjelenítési módban semmi nem írja ki**; csak a gombnyomáskor, illetve a 0100-as képernyő (nem létező) fejlécmezőjében lenne látható. | Új `SHOW_MODE_MESSAGE` FORM: `I` típusú popup a `CALL SCREEN` előtt (mint a QU5-ben az i021/i031/i037). |
| 2 | Nem QM-státusznál hasonló üzenet | Ugyanaz, mint az 1. pont. | Ugyanaz a FORM, a státusszal együtt. |
| 3 | Lezárhatónál AB-zár (enqueue) a teljes futásra + lezáró gomb az ALV-n | A gomb már megvan (`ON_TOOLBAR`, `RELEASE`). A zár viszont **csak gombnyomáskor jön létre, és a `RELEASE_STOCK` végén fel is oldódik**. | Új `SYNC_LOCK` FORM: induláskor és frissítéskor zárol, ha a stock lezárható. Ha más zárolja, megjelenítési mód lesz („X felhasználó zárolja”). A gomb csak saját zár mellett jelenik meg. |
| 4 | A gomb hívja a `ZCL_PR_STOCK` lezáró metódusát (Inspire), siker esetén AB UPDATE: státusz + lezárási mezők | A riport **saját** proxyhívást (`SEND_PRIORITY`) és saját UPDATE-et (`SAVE_RELEASE`) használ. A `CLOSE_STOCK` **nem ad vissza eredményt**, saját prioritás-popupot dob fel, és csak a `STATUS = 'CL'` mezőt írja. | A `CLOSE_STOCK` **bővítése** (nem átírása): opcionális `IV_PRIORITY`, új `EV_SUCCESS`, és a teljes lezárási UPDATE. A riport ezt hívja `SEND_PRIORITY` + `SAVE_RELEASE` helyett. |
| 5 | Megjelenítéskor a képen látható fejrész (Stock ID, sorok száma) | A képernyőkép a **QU5-ös** riport `CL_DD_DOCUMENT` fejléce. Ez a DHC-átültetésből kimaradt. Amit a `RELEASE_STOCK`-ban találtál (`'Nyomtatási sorok száma:'` stb.), az **naplóüzenet** (`ADD_MESSAGE` → BAL-napló), és **csak sikeres lezárás után** fut. Megjelenítési módban a gomb sincs kint, így soha nem hívódik meg. | Új `BUILD_HEADER` FORM: dokkoló konténer felül + `CL_DD_DOCUMENT`, mint a QU5-ben. Frissítéskor és lezárás után újrarajzolódik. |
| 6 | A kivételeket a lezárás során most nem kezeljük | – | Csak információ, lásd a [6. pontot](#6-kivételek--nyitott-holnapi-egyeztetésre-márkkal). |

---

## 1–2. Üzenet megjelenítési módban

**Miért nem jelenik meg most:** a [DETERMINE_MODE](../05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap#L178-L192)
csak változót tölt. Üzenet csak a [RELEASE_STOCK 256–259. sorában](../05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap#L256-L259)
megy ki, de a gomb megjelenítési módban nincs kint.

A `ZPR 000` üzenet `& & & &`, változónként legfeljebb 50 karakter. A mostani
`'A stock külső állapota ellenőrizendő; lezárás tiltva.'` szöveg 53 karakter, így levágódna. Ezért:

- a `GV_BLOCK_REASON` típusa `SYMSGV` legyen (50 karakter, kikényszeríti a hosszt);
- kapjon egy társmezőt, `GV_BLOCK_DETAIL TYPE SYMSGV` néven (státusz, illetve a zároló felhasználó).

```abap
DATA: ...
      gv_block_reason TYPE symsgv,          "volt: c LENGTH 120
      gv_block_detail TYPE symsgv,          "új
      ...
```

```abap
FORM determine_mode.
  DATA lv_status TYPE c LENGTH 10.
  gv_modif = abap_false.
  CLEAR: gv_block_reason, gv_block_detail.
  IF gs_stock-closed IS NOT INITIAL
     OR gs_stock-status = gc_status_closed.
    gv_block_reason = 'A stock engedélyezve (lezárva) van.'.
  ELSEIF gs_stock-stock_status_er IS NOT INITIAL
         OR gv_uncertain = abap_true.
    gv_block_reason = 'A stock külső állapota ellenőrizendő.'.
  ELSEIF gs_stock-status <> gc_status_qm.
    gv_block_reason = 'Csak QM státuszú stock zárható le.'.
    lv_status = gs_stock-status.
    IF lv_status IS INITIAL.
      lv_status = 'nyitott'.
    ENDIF.
    CONCATENATE 'Jelenlegi státusz:' lv_status
      INTO gv_block_detail SEPARATED BY space.
  ELSE.
    gv_modif = abap_true.
  ENDIF.
ENDFORM.

FORM show_mode_message.
  CHECK gv_modif = abap_false.
  MESSAGE i000 WITH gv_block_reason gv_block_detail
                    'Csak megtekintés lehetséges.'.
ENDFORM.
```

Eredmény (popup):
- lezárt stock: *„A stock engedélyezve (lezárva) van. Csak megtekintés lehetséges.”*
- DM-stock: *„Csak QM státuszú stock zárható le. Jelenlegi státusz: DM Csak megtekintés lehetséges.”*

Az üzenet a `START-OF-SELECTION`-ben, a `CALL SCREEN` előtt fut, nem az `AT SELECTION-SCREEN`-ben.
Így nem jön fel minden Enterre a szelekciós képernyőn.

---

## 3. AB-zár a teljes futásra + lezáró gomb

**Mostani állapot:** a [LOCK_STOCK](../05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap#L417-L428) csak a
`RELEASE_STOCK`-ból hívódik, a [324. sor](../05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap#L324) pedig
a végén feloldja a zárat. Közben két felhasználó ugyanazt a stockot „szerkeszthetőként” látja.

**Szabály:** ha a stock lezárható, akkor a zár a képernyő teljes ideje alatt nálunk van.
Ha nem zárolható, a riport megjelenítési módra vált. A `_SCOPE = '1'` marad: a zár a COMMIT WORK
után is a dialógusprogramnál marad, és nem kerül át az update taskhoz.

```abap
FORM lock_stock.
  CLEAR gv_locked_stock.
  CALL FUNCTION 'ENQUEUE_EZPRT_STOCK'
    EXPORTING stock_id = p_stokid _scope = '1'
    EXCEPTIONS foreign_lock = 1 system_failure = 2 OTHERS = 3.
  IF sy-subrc = 1.
    gv_block_reason = 'A stockot más felhasználó zárolja:'.
    gv_block_detail = sy-msgv1.
    RETURN.
  ELSEIF sy-subrc <> 0.
    gv_block_reason = 'A stock zárolása sikertelen.'.
    CLEAR gv_block_detail.
    RETURN.
  ENDIF.
  gv_locked_stock = p_stokid.
ENDFORM.

"Zár és mód összehangolása: lezárható -> saját zár; különben nincs zár.
FORM sync_lock.
  IF gv_modif = abap_false.
    PERFORM unlock_stock.
    RETURN.
  ENDIF.
  CHECK gv_locked_stock IS INITIAL.
  PERFORM lock_stock.
  IF gv_locked_stock IS INITIAL.
    gv_modif = abap_false.
    RETURN.
  ENDIF.
  "Zárolás után friss olvasás: a zár előtt más lezárhatta.
  PERFORM read_stock.
  IF gv_error = abap_true.
    gv_modif = abap_false.
    gv_block_reason = 'A stock beolvasása sikertelen.'.
    CLEAR gv_block_detail.
  ELSE.
    PERFORM determine_mode.
  ENDIF.
  IF gv_modif = abap_false.
    PERFORM unlock_stock.
  ENDIF.
ENDFORM.
```

**START-OF-SELECTION** (a 117–125. sor helyett):

```abap
  PERFORM determine_mode.
  PERFORM sync_lock.
  PERFORM select_data.

  IF gv_error = abap_true.
    PERFORM unlock_stock.          "új: riportnál a szelekciós képernyőre visszatérve
    PERFORM log_write.             "a zár különben megmaradna
    RETURN.
  ENDIF.

  PERFORM show_mode_message.
  CALL SCREEN 0100.
```

**Gomb (`ON_TOOLBAR`)**: a meglévő feltétel kiegészül a saját zárral. Közben javítandó a 143. sor is:
template string van benne, ami a CLAUDE.md szerint tiltott.

```abap
    IF gv_modif = abap_true AND gv_busy = abap_false
       AND gv_locked_stock = p_stokid.
      CLEAR ls_button.
      ls_button-function = 'RELEASE'.
      ls_button-icon = icon_release.
      ls_button-text = 'Lezárás'.
      ls_button-quickinfo = 'Stock engedélyezése és lezárása'.
      APPEND ls_button TO e_object->mt_toolbar.
    ENDIF.
```

**RELOAD_DISPLAY**: a `DETERMINE_MODE` után `PERFORM sync_lock.` kell. Az olvasási hibaágban
(`gv_modif = abap_false`) `PERFORM unlock_stock.` kell. Így a *Frissítés* gombbal újra
próbálkozhat az, aki korábban más zárja miatt csak megjelenítést kapott.

A kilépés (`EXIT_SCREEN`) és a `CALL SCREEN` utáni `UNLOCK_STOCK` már most is helyes.

---

## 4. Lezárás a `ZCL_PR_STOCK=>CLOSE_STOCK`-kal

### 4.1 Mi hiányzik most a metódusból

[CLOSE_STOCK](../01_SOURCES/DHC/ZCL_PR_STOCK.abap#L40-L222):
1. **Nincs visszatérési jelző.** A hívó nem tudja meg, sikerült-e a lezárás.
2. **Saját prioritás-popup.** A riportnak már van popupja és megerősítése, ez duplán jelenne meg.
   A popup alapértéke is hibás: a lokális `gs_stock` sosincs beolvasva, ezért `00`-t mutat.
3. **Az UPDATE csak `STATUS = 'CL'`** (`UPDATE_STATUS`). A `CLOSED`, `PRIORITY`, `ERDAT_CLO`,
   `ERNAM_CLO`, `ERTIM_CLO` és a `CH*` mezők nem íródnak, és nincs `status = 'QM'` védelem sem.

### 4.2 Bővítés (a meglévő hívók változatlanul fordulnak)

Az új paraméterek opcionálisak, illetve exporting típusúak, így a cockpit régi
`close_stock( iv_stock = ... )` hívása is fordul.

```abap
  class-methods CLOSE_STOCK
    importing
      !IV_STOCK type ZPRD_STOCK_ID
      !IV_PRIORITY type ZPRD_PRIORITY optional
    exporting
      !EV_SUCCESS type ABAP_BOOL .
```

A metódus elején:

```abap
    CLEAR ev_success.
*----------------------------------------------------------------*
* Prioritás megállapítása – ha a hívó átadta, nincs popup
    IF iv_priority IS NOT INITIAL.
      gv_priority = iv_priority.
    ELSE.
      ... a meglévő POPUP_GET_VALUES blokk változatlanul ...
    ENDIF.
```

Az `* Adatbázis update` blokk (a `zcl_pr_stock=>update_status( ... 'CL' )` hívás) helyett:

```abap
*---------------------------------------------------------------*
* Adatbázis update: státuszváltás + lezárási mezők
    IF lv_error_flag IS INITIAL.
      UPDATE zprt_stock
         SET status    = 'CL'
             closed    = @abap_true
             priority  = @gv_priority
             erdat_clo = @sy-datum
             ernam_clo = @sy-uname
             ertim_clo = @sy-uzeit
             chuser    = @sy-uname
             chdate    = @sy-datum
             chtime    = @sy-uzeit
       WHERE stock_id = @iv_stock
         AND status   = 'QM'.
      IF sy-subrc = 0.
        COMMIT WORK.
        ev_success = abap_true.
      ELSE.
        ROLLBACK WORK.
        MESSAGE e000 WITH 'A stock mentése sikertelen:' iv_stock
          INTO gv_dummy_message.
        lo_log->add_system_message( ).
      ENDIF.
    ENDIF.
```

Az `UPDATE_STATUS` metódus változatlan marad, mert a cockpit DM/QM-váltásai ezt használják.

> **Pontosítandó – „CR\* mezők”:** a `ZPRT_STOCK`-ban a `CRUSER/CRDATE/CRTIME` a **létrehozási**
> adatokat tárolja, ezeket lezáráskor nem szabad felülírni. Feltételezésem szerint a lezárási mezőkre
> gondoltál (`CLOSED`, `ERDAT_CLO`, `ERNAM_CLO`, `ERTIM_CLO`, `PRIORITY`). Mellettük a `CH*`
> módosítási mezők is töltődnek. Ha mást értettél alatta, az UPDATE `SET` listáját kell igazítani.

### 4.3 Riport: `RELEASE_STOCK` új változata

A zár már a képernyő megnyitása óta a miénk, ezért a `LOCK_STOCK`/`UNLOCK_STOCK` pár kikerül.
A `SEND_PRIORITY` + `SAVE_RELEASE` helyére a `CLOSE_STOCK` hívása kerül. A napló sikeres esetben
a metódusé (az maga jeleníti meg), a riport csak a hívás **előtti** ellenőrzési hibákat naplózza.
Így nem jön fel két napló egymás után.

```abap
FORM release_stock.
  DATA: lt_displayed TYPE ty_alv_table,
        lv_displayed_total TYPE i,
        lv_confirmed TYPE abap_bool,
        lv_priority_ok TYPE abap_bool.

  CHECK gv_busy = abap_false.
  REFRESH gt_messages.
  CLEAR gv_saved.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
  IF sy-subrc <> 0.
    MESSAGE s000 WITH 'Nincs jogosultsag a tranzakciohoz:' gc_tcode
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF gv_modif <> abap_true OR gv_locked_stock <> p_stokid.
    MESSAGE s000 WITH gv_block_reason gv_block_detail
      'Csak megtekintés lehetséges.' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM get_priority CHANGING lv_priority_ok.
  CHECK lv_priority_ok = abap_true.
  PERFORM confirm_release CHANGING lv_confirmed.
  CHECK lv_confirmed = abap_true.
  gv_busy = abap_true.

  "Friss újraellenőrzés a saját zár alatt.
  PERFORM read_stock.
  IF gv_error = abap_true.
    PERFORM add_message USING 'E' 'A stock nem létezik:' p_stokid space.
  ELSE.
    PERFORM determine_mode.
    IF gv_modif <> abap_true.
      gv_error = abap_true.
      PERFORM add_message USING 'E' gv_block_reason gv_block_detail space.
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
    PERFORM close_stock_call.
  ENDIF.
  gv_busy = abap_false.

  IF gt_messages IS NOT INITIAL.
    PERFORM log_write.
  ENDIF.
  PERFORM read_stock.
  IF gv_error = abap_false.
    PERFORM determine_mode.
  ELSE.
    gv_modif = abap_false.
    gv_block_reason = 'A stock beolvasása sikertelen.'.
    CLEAR gv_block_detail.
  ENDIF.
  PERFORM sync_lock.               "lezárva -> zár elengedése
  PERFORM refresh_grid.            "fejléc + gomb frissül
  IF gv_saved = abap_true.
    MESSAGE s000 WITH 'A stock lezárása sikeres:' p_stokid.
  ELSE.
    MESSAGE s000 WITH 'A stock nem lett lezárva. Lásd a naplót.'
      DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

FORM close_stock_call.
  DATA lv_success TYPE abap_bool.
  gv_error = abap_true.
  "Inspire-hívás és státusz-/lezárási mezők mentése a stockosztályban.
  zcl_pr_stock=>close_stock(
    EXPORTING iv_stock    = p_stokid
              iv_priority = gv_priority
    IMPORTING ev_success  = lv_success ).
  IF lv_success = abap_true.
    gv_saved = abap_true.
    gv_error = abap_false.
  ENDIF.
ENDFORM.
```

Sikertelen Inspire-hívás esetén a stock QM-ben marad, a zár nálunk marad, a gomb is látható marad,
így újra lehet próbálni.

A `PREPARE_REGMAIL`, `CHECK_REGMAIL_TABLES`, `SEND_PRIORITY`, `SAVE_RELEASE` és
`MARK_UNCERTAIN_STATE` FORM-ok **egyelőre maradjanak a kódban, hívás nélkül**. A holnapi döntésig
(6. pont) nem töröljük őket. Az ATC „nem használt FORM” figyelmeztetést fog adni rájuk, ez várható.

---

## 5. Fejrész megjelenítési módban (a képernyőképen látható blokk)

**Miért nem jelenik meg:** a kért blokk a QU5-ben a
[CREATE_CONTROLS_0100-ban](../01_SOURCES/QU5/ZEBF_PR_STOCK_REPORT.abap#L586-L615) készült
(`CL_GUI_DOCKING_CONTAINER` felül + `CL_DD_DOCUMENT`, nagy félkövér betű). A DHC-változatba nem
került át. A `RELEASE_STOCK`-ban talált
[sorok](../05_FINAL/abap-2026-10-17/ZPR_CLOSE_STOCK.abap#L327-L339) nem ezt csinálják: azok
BAL-naplóüzenetek, és csak `GV_SAVED = X` (sikeres lezárás) után futnak le. Megjelenítési módban
a gomb sincs kint, így ez az ág soha nem fut.

Globális adatok:

```abap
DATA: go_dock   TYPE REF TO cl_gui_docking_container,
      go_header TYPE REF TO cl_dd_document.
```

Új FORM-ok:

```abap
FORM build_header.
  DATA: lv_text TYPE sdydo_text_element,
        lv_number TYPE c LENGTH 20.
  CHECK go_dock IS BOUND.
  IF go_header IS NOT BOUND.
    CREATE OBJECT go_header.
  ELSE.
    go_header->initialize_document( ).
  ENDIF.
  CONCATENATE 'Stock ID:' p_stokid INTO lv_text SEPARATED BY space.
  PERFORM add_header_line USING lv_text.
  WRITE gv_total TO lv_number LEFT-JUSTIFIED.
  CONCATENATE 'Nyomtatási sorok száma:' lv_number
    INTO lv_text SEPARATED BY space.
  PERFORM add_header_line USING lv_text.
  WRITE gv_excluded TO lv_number LEFT-JUSTIFIED.
  CONCATENATE 'Kizárt nyomtatási sorok száma:' lv_number
    INTO lv_text SEPARATED BY space.
  PERFORM add_header_line USING lv_text.
  go_header->display_document(
    EXPORTING parent = go_dock reuse_control = abap_true
    EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc <> 0.
    MESSAGE s000 WITH 'A fejléc nem jeleníthető meg.' DISPLAY LIKE 'W'.
  ENDIF.
ENDFORM.

FORM add_header_line USING uv_text TYPE sdydo_text_element.
  go_header->add_text( text         = uv_text
                       sap_fontsize = cl_dd_document=>large
                       sap_emphasis = cl_dd_document=>strong ).
  go_header->new_line( ).
ENDFORM.
```

Bekötés:

- **`CREATE_CONTROLS_0100`**: a `CHECK go_grid IS NOT BOUND.` után, az ALV-konténer előtt:
  ```abap
    CREATE OBJECT go_dock
      EXPORTING repid = sy-repid
                dynnr = '0100'
                side  = cl_gui_docking_container=>dock_at_top
                ratio = 10
      EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      FREE go_dock.
      MESSAGE s000 WITH 'A fejléc-konténer nem hozható létre.' DISPLAY LIKE 'W'.
    ENDIF.
    PERFORM build_header.
  ```
- **`REFRESH_GRID`**: az elején `PERFORM build_header.`, így a *Frissítés* gomb és a lezárás után
  is friss számok jelennek meg.
- **`FREE_CONTROLS`**: `FREE go_header.`, valamint `go_dock->free( EXCEPTIONS OTHERS = 1 )` a
  meglévő hibajelzős mintával, végül `FREE go_dock.`

Megjegyzések:
- A `ratio = 10` a QU5-értéket követi. Ha kis ablakban levágódik, 12–15 is lehet.
- Ha a 0100-as SE51-layoutba már fel lettek véve fejlécmezők (a
  [flow-leírás](../04_ASSETS/abap/ZPR_STOCK_REPORT_0100_flow.abap) ezt javasolta), azokat törölni
  kell, különben duplán jelenik meg a fejléc.
- Ha frissítéskor a dokumentum nem frissül vagy duplikálódik, az `INITIALIZE_DOCUMENT` után egy
  `go_header->merge_document( )` hívás kell. Ezt GUI-próbán kell ellenőrizni.
- Opcionálisan felvehető egy 4. sor (`Engedélyezett sorok száma`), illetve megjelenítési módban
  a `GV_BLOCK_REASON` is. A képernyőkép alapján ez nem kell.

---

## 6. Kivételek – nyitott, holnapi egyeztetésre (Márkkal)

Ebbe most nem vágunk bele, csak rögzítem, mi múlik rajta:

- **Ha a „kivételek” a kizárt (DC/QM-blokkolt) tételeket jelentik:** a riport eddig átadta az
  Inspire-nek a kizárt borítékokat (`EXCLUDE_ENVELOPES`), és törölte a ragszámukat
  (`ZPR_TERTI` / `ZISU_F064`). A `CLOSE_STOCK`-ban ez ki van kommentezve („A borítékolás
  tisztázandó”). A fenti átállással **kizárt tétel esetén is mindent nyomtatásra küldünk.**
  Átmeneti biztosítékként javaslom: amíg ez nincs eldöntve, `GV_EXCLUDED > 0` esetén a lezárás
  legyen tiltva, egy üzenettel. → **döntés kell**
- **Ha a hibakezelésre (exception) gondoltál:** a `CLOSE_STOCK` nem ellenőrzi az üres logikai
  portot. Bizonytalan Inspire-eredménynél (rendszerhiba a hívás közben) a riport eddig a
  `STOCK_STATUS_ER` jelzővel tiltotta az újraküldést. Az új úton ez nem aktiválódik, tehát ismételt
  gombnyomás duplán küldhet.

---

## Átvezetési sorrend és teszt

1. Az aktív `ZCL_PR_STOCK` visszaolvasása, mert a helyi másolat régebbi. Utána a 4.2-es bővítés és aktiválás.
2. A cockpit lezáró ága (`c_buttons-close`) ellenőrzése: a régi
   [DHC-változat](../01_SOURCES/DHC/LZPR_COCKPITO01.abap#L99-L111) a `CLOSE_STOCK` után feltétel
   nélkül hívja az `UPDATE_STATUS('CL')`-t, így Inspire-hiba esetén is lezár. Ha ez az ág még él,
   az `EV_SUCCESS`-re kell feltételezni.
3. A `ZPR_CLOSE_STOCK` módosításai (1–5. pont), közös aktiválás. Utána `/abap-code-review` (ATC + Unit).
4. GUI-teszt:

| Eset | Elvárt |
|---|---|
| CL-stock | popup „engedélyezve… csak megtekintés”, megjelenítési cím, nincs gomb, SM12-ben nincs zár, fejléc látszik |
| DM- vagy nyitott stock | popup „Csak QM státuszú…, Jelenlegi státusz: DM”, nincs gomb |
| QM-stock | nincs popup, van **Lezárás** gomb, SM12-ben `EZPRT_STOCK` zár a felhasználónál |
| QM-stock második sessionben | popup „A stockot más felhasználó zárolja: <user>”, nincs gomb |
| Lezárás – siker | prioritás + megerősítés, Inspire-napló; `STATUS = CL`, `CLOSED = X`, `*_CLO` és `CH*` kitöltve; a képernyő megjelenítési módra vált, a zár feloldódik |
| Lezárás – Inspire-hiba | `STATUS = QM` marad, a zár és a gomb megmarad |
| Vissza (F3) | a zár feloldódik |
