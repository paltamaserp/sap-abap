# Cockpit: a mérőkódok eltávolítása

Státusz: **WIP**, 2026-10-17. A felhasználó szerint az ALV megjelent a cockpit konténerkonstruktorának explicit REPId/DYNNR paraméterei nélkül. A mérőkódok és próba-SET_VISIBLE hívások ekkor még bent voltak; az alábbi tisztítás utáni friss példányos megjelenítést külön ellenőrizni kell. Az önálló megjelenítés már korábban működött. A helyi fő WIP nem tartalmazza a diagnosztikai blokkokat, ezért az annak rutinjaiból kimentett tiszta változatokat adjuk meg. A jelenlegi SAP-forrás nincs újra visszaolvasva.

## 1. ZPR_DCQM_EXCLUDE_C01: teljes COCKPIT_PBO csere

Csak a meglévő `FORM cockpit_pbo ... ENDFORM` blokkot cseréld; ne az egész C01 include-ot. Tiszta rutin: [COCKPIT_PBO](2026-10-17_cockpit-pbo-meres-nelkul_WIP.abap).

```abap
FORM cockpit_pbo USING io_container TYPE REF TO cl_gui_custom_container.
  CHECK gv_embedded = abap_true.
  CHECK io_container IS BOUND.
  CHECK go_alv_grid_01 IS INITIAL.
  go_alv_grid_cont_01 = io_container.
  PERFORM create_controls_0100.
ENDFORM.
```

Ez kiváltja a teljes ideiglenes mérőrutin tartalmát: LV_UI_* változók, LS_UI_LINK, két GET_VISIBLE, két próba-SET_VISIBLE, GET_LINK_INFO, a hozzájuk tartozó hibakód-értékadások, FLUSH és a `CHECK lv_ui_rc_vflush = 0.` megszűnnek. A próba-SET_VISIBLE eltávolítását friss példánnyal kell ellenőrizni, hogy ne egy már láthatóra állított régi objektum fedje el az esetleges további függést. A COCKPIT_OPEN/SAVE/CLOSE és a kész konténerreferencia átadása megmarad.

## 2. ZPR_DCQM_EXCLUDE: CREATE_CONTROLS_0100 tisztítása

Tiszta teljes rutin: [CREATE_CONTROLS_0100](2026-10-17_create-controls-0100-meres-nelkul_WIP.abap). A csatolmányban szereplő forráshoz képest az alábbi mérőrészek törlendők.

Első blokk, a Grid CREATE OBJECT előtt:

```abap
DATA lv_ui_offline TYPE int4.

  CALL METHOD cl_gui_alv_grid=>offline
    RECEIVING
      e_offline = lv_ui_offline.
```

Második blokk: a `go_alv_grid_01->set_toolbar_interactive` **után** kezdődő teljes diagnosztika törlendő az ENDFORM-ig, az ENDFORM-ot megtartva. Ide tartozik a LV_UI_ALIGNMENT/LV_UI_RC_ALIGN DATA és értékadás, SET_ALIGNMENT, a méretváltozók és hibakódok deklarációi, a négy GET_WIDTH/GET_HEIGHT, a mérés FLUSH-a és a kapcsolódó SY-SUBRC értékadások.

A rutin vége így legyen:

```abap
  CALL METHOD go_alv_grid_01->set_toolbar_interactive.
ENDFORM.
```

Nem minden FLUSH hívás törlendő a rendszerből; csak az itt felvett diagnosztikai hívások. A set_table_for_first_display és a többi eredeti ALV-kód megmarad.

A korábbi vezetőnulla-kéréshez a címformázó `SHIFT lv_stokid LEFT DELETING LEADING '0'.` is törlendő, ha még szerepel. A mellékelt tiszta teljes rutin ezt a formázási javítást is tartalmazza. A beazonosítás ALPHA_INPUT hívásai és az input With leading zeros attribútuma megmaradnak.

## 3. LZPR_COCKPITO01 / TOP: a működő bekötés marad

Ellenőrzési másolat: [DM_CONTROLS](2026-10-17_dm-controls-meres-nelkul_WIP.abap). Nem szükséges újra lecserélni, ha már ez van SAP-ban.

- TOP: GO_DM_CONTAINER deklaráció marad.
- DM_CONTROLS: a konténer létrehozásakor csak CONTAINER_NAME; nincs explicit REPID/DYNNR. A PERFORM COCKPIT_PBO USING GO_DM_CONTAINER marad.
- DM_CLOSE: sikeres riportbezárás után FREE GO_DM_CONTAINER marad, megszakított bezáráskor nem törlünk referenciát.
- A riport CREATE_CONTROLS_0100 elején a Grid CHECK marad; a régi konténer-CHECK nem kerülhet vissza. A konténerlétrehozás IF-be csomagolva marad.
- A riport saját standalone 0100-as útjának GV_HOST_REPID/GV_HOST_DYNNR adatai és az ottani konstruktorparaméterek maradnak; a két paraméter elhagyása a cockpit GO_DM_CONTAINER konstruktorára vonatkozott.
- A 0100/1010 flow logic, a RESET/Enter/inputlezárás, az adapter és a mentési rutinok megmaradnak.

## 4. SE51 és breakpointok

1010 Layout: a `DM 1010 TESZT` és `DM 1010 TESZT2` fix szövegek törölhetők. Ha a konténer még a próba miatt a 3. sorban, 33 sor magas: a szövegek törlése után a grafikus Layoutban húzd vissza az 1. sorba, majd a magasságát állítsd 35-re. A Sor mező helyett mozgatást használj. Mindkét resizing marad bekapcsolva, a minimum 5 sor / 10 oszlop megmarad. Mentés/aktiválás szükséges. A teszthez felvett session breakpointokat kapcsold ki.

## 5. Aktiválás és rövid ellenőrzés

Az érintett riportot/C01-et és módosított képernyőt saját programkörnyezetükben ellenőrizd és aktiváld. A régi cockpitot normálisan zárd be, és friss móduszban indíts új konténert. Stock + egy Enter után meg kell jelennie az ALV-nak a négy sorral. A próba-SET_VISIBLE eltávolításának sikerét ez igazolja.

Utána fülváltás/visszatérés és RESET → ismételt beazonosítás ellenőrizendő a referenciák újralétrehozásához. Ezek nem voltak még teljes felhasználói regressziós próbával igazolva; mentési művelethez külön üzleti próba szükséges. A fő WIP szerkezeti és kétirányú diffellenőrzése korábban sikeres; a három mostani tiszta rutin annak változatlan, ellenőrzött másolata. Új SAP-eszközhívás/írás/aktiválás/futtatás az asszisztens részéről nincs.
