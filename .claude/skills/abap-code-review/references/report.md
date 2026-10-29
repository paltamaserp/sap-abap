# Ellenőrzési összesítés

A validate_report.py a már végrehajtott vizsgálatok **normalizált összesítését** ellenőrzi. A találatszámokat a teljes mentett SAP-válaszból kell pontosan kiolvasni; a segéd nem a különböző SAP-válaszformátumok parsere és nem SAP-futtató. A bizonyíték épsége önmagában nem bizonyítja annak tartalmi értelmezését.

## Kötelező adatok

A gyökérben nem üres `objects` lista kell. Objektumonként `name`, `type`, `system`, `client`, `source_sha256` és `checks` szerepel. A mandant szöveg, például `"100"`. A rendszer vagy mandant ismeretlenségét `null` jelöli; ez nem teljes siker. A forráshash a végleges, ellenőrizni kívánt helyi forrás/definíció SHA256-értéke. Jelentésen belül egy objektum egy rendszer/mandant mellett egyszer szerepel.

A checks alatt négy mező van: `syntax`, `active_readback`, `unit`, `qa`. Bármelyik hiánya nem futott lépést jelent. Minden mező `status` értéke `passed`, `failed`, `not_run` vagy `not_applicable`. Az utolsó csak Unit-lépéshez elfogadható, szakmai `reason` indoklással. Érdemi kód teszthiánya not_run, nem not_applicable.

Sikeresnek jelölt vizsgálathoz kell `source_sha256`, időzónás ISO `checked_at` és nem üres `evidence` lista. Minden bizonyíték `{ "file": "relatív-fájlnév", "sha256": "64 hex karakter" }`. A fájlok a jelentés könyvtárában vagy annak alkönyvtáraiban legyenek. A hivatkozott forrás és vizsgálat ugyanarra az objektumra és verzióra vonatkozzon. Include-osztályoknál a kapcsolt változott include-ok ellenőrzését és mentését is igazold; a főforrás egyezése önmagában nem elég.

## Lépcsőnkénti adatok

| Lépés | További mezők és feltételek |
|---|---|
| syntax | `errors: 0`, `warnings`, `unresolved_warnings: 0`, `checked_version: active/inactive/source`; figyelmeztetésnél szöveges `warning_disposition`. |
| active_readback | `version: active`, `expected_file`, `actual_file`; mindkét fájlhash egyezzen az objektum source_sha256 értékével. |
| unit | `completed: true`, `run_id`, `tests` nagyobb nullánál, `failures: 0`, `errors: 0`, `skipped: 0`. A befejezett státusz és végső eredmény válasza is legyen mentve. |
| qa | `completed: true`, `tool`, `variant`, `run_id`, `checking_system`, `blocking_findings: 0`, `unresolved_findings: 0`; a Check* tool nem fogadható el QA-futtatóként. |

A számlálók nem negatív egész számok. A kezeletlen figyelmeztetés/találat vagy kihagyott teszt RÉSZLEGES. Hibás eredmény, eltérő aktív forrás, sérült bizonyíték vagy ellentmondásos passed jelölés HIBÁS. A hiányzó SAP-vizsgálatot not_run állapottal rögzítsd, például:

```json
{
  "objects": [
    {
      "name": "ZCL_A_FELADAT_TENYLEGES_OBJEKTUMA",
      "type": "CLAS",
      "system": null,
      "client": null,
      "source_sha256": null,
      "checks": {
        "syntax": {"status": "not_run", "reason": "Csak helyi forrás készült."},
        "active_readback": {"status": "not_run", "reason": "Nem történt SAP-telepítés."},
        "unit": {"status": "not_run", "reason": "Nincs végrehajtott releváns teszt."},
        "qa": {"status": "not_run", "reason": "Nincs elérhető teljes QA-futtató."}
      }
    }
  ]
}
```

Ez csak formai példa, nem valós objektum vagy sikeres futás. Mindig a tényleges objektumnevet és adatokat használd. Ne ments hitelesítési/session adatot. Az eredmény a bemenet mellé `<téma>_eredmeny_WIP.json` néven kerül. A 0 kilépési kód SIKERES, 2 RÉSZLEGES, 1 HIBÁS; hiányzó vizsgálatot ne emelj át passed állapotba a kilépési kód megváltoztatásáért.
