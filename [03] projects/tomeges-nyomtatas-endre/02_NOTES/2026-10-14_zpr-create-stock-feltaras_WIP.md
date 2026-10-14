# ZPR_CREATE_STOCK — aktív riport feltárása

**Dátum:** 2026-10-14 · **Státusz:** WIP

Az SAP ADT MCP `ReadProgram(program_name = ZPR_CREATE_STOCK, version = active)` sikeresen visszaadta az SE38-as végrehajtható riport aktív forrását. A `GetObjectStructure` lekérés is sikeres. SAP-módosítás és riportfuttatás nem történt.

## Export és azonosítás

- Forrás: `../01_SOURCES/DHC/ZPR_CREATE_STOCK.abap` — 806 sor, UTF-8 BOM nélkül; a fájl visszaolvasása karakterre egyezik az MCP forrásával.
- Eredeti ADT-metaadat: `../01_SOURCES/DHC/ZPR_CREATE_STOCK.metadata.xml`.
- MCP objektumstruktúra: `../01_SOURCES/DHC/ZPR_CREATE_STOCK.objectstructure.txt`.
- Leírás: „Tömeges nyomtatás - Stock képzés”; típus: `executableProgram`, `PROG/P`; csomag: `ZPR_FUNC`.
- Metaadat szerinti eredeti rendszer: `masterSystem = DHC`. Ez a mező önmagában nem igazolja a jelenleg kapcsolt rendszer SID-jét.
- Aktív módosítás: `2026-10-12T14:36:36Z`, módosító: `X0157`; felelős: `X0097`.
- Nincs külön programinclude: az `INCLUDE STRUCTURE zprt_package` típusdeklaráció része. A főprogram tartalmazza a FORM-okat és a PBO/PAI modulokat.
- A struktúralekérésben 0100 és 1000 képernyő, valamint `ZPR_CREATE_STOCK` tranzakcióhivatkozás szerepel. A képernyőlayout/flow logic, a GUI-státusz és a szövegelemek tartalma nem része az exportnak; ez forrásexport, nem teljes telepítési csomag.

## Működés a forrás alapján

1. A `ZPRT_PACKAGE` táblából csomagazonosító, létrehozó és dátum szerint kiválasztja a még stock nélküli (`STOCK_ID = 0`) csomagokat, majd a 0100 képernyő ALV-jében megjeleníti őket.
2. A `PROCESS` funkció a `process_package` → `create_stock` rutinokat hívja. Kijelölés nélkül visszatér; ellenőrzi, hogy minden kijelölt csomag még szabad-e.
3. A `ZPRT_DCQM` és `ZPRT_DOC_DATA` belső összekapcsolásával csak XML-lel rendelkező dokumentumokat vesz át. A `ZSTOCK` számkör 01-es intervallumából stockazonosítót kér.
4. Dokumentumonként `{SY-SYSID}_{SY-MANDT}_{stock}_{doc_no}.xml` fájlt képez. A `ZCL_PR_QM_SAMPLER` mintacsoportokat épít, a maradék dokumentumokat üres mintaazonosítójú csoportba teszi.
5. A gateway `upload_files`, majd `trigger_stock_completion` hívása történik, 30-as prioritással és üres `IV_NOTEST` értékkel.
6. Sikeres feladás után beszúrja a `ZPRT_STOCK` rekordot, a szabad csomagokat stockhoz rendeli, és a data adapterrel menti a dokumentum-stock kapcsolatokat, minta-hozzárendeléseket és kizárási sorokat. Ezután `COMMIT WORK` történik.
7. A kezelt `ZCX_FORM_MESSAGE_ERROR` kivételnél rollback és hibanaplózás történik; a már sikeres külső feladás utáni helyi hibát stockazonosítóval külön jelzi. A napló objektuma/alobjektuma `ZPR_MASS` / `STOCK`.

## Fő függőségek

- Táblák: `ZPRT_PACKAGE`, `ZPRT_DCQM`, `ZPRT_DOC_DATA`, `ZPRT_STOCK`.
- Aktív feldolgozási ág: `ZIF_PR_QM_DATA`, `ZCL_PR_QM_DATA`, `ZCL_PR_QM_SAMPLER`, `ZCL_PR_QM_RANDOM`, `ZIF_PR_INSPIRE_GW`, `ZCL_PR_INSPIRE_GW`, `ZCL_PR_ADMIN`, `ZCL_PR_LOG`, `ZCX_FORM_MESSAGE_ERROR`.
- Megmaradt régi rutin: `ZCL_PR_OUTPUT_MANAGEMENT`, `ZCL_PR_FILE_CONVERTER`, `ZPR_CO_EON_FORMS_UPLOADER_PORT` és a kapcsolódó generált proxytípusok.
- UI és üzenetek: 0100 dynpro, `D0100` GUI-státusz, `GV_OKCODE`, `TEXT-001/002/011/012`, `ZPR` és `ZPR_FUNC` üzenetosztályok.

## Statikus megállapítások, további ellenőrzések

- A `SO_STAT` szelekció deklarált, de a csomagleolvasás WHERE feltételében nincs felhasználva.
- A `STOCK_SIZE` paramétert beolvassa, de a `PACKAGE SIZE` sor kommentelt; a látható aktív feldolgozás nem használja fel a méretet.
- A `process_package_old` megmaradt a forrásban; a jelenlegi `PROCESS` ág az új rutint hívja.
- A főprogramban nincs ENQUEUE/DEQUEUE hívás. A két feldolgozás közti ütközést a külső feladás után végzett feltételes UPDATE érzékeli; a külső Inspire-hívás előtti csomagfoglalás az adapterek ellenőrzése nélkül nem igazolt.
- A sikeresen feldolgozott csomagok nem kerülnek ki a `GT_DOCUMENTS` listából; újabb feldolgozásnál a szabadságellenőrzés visszautasíthatja őket.
- Az új rutin csak `ZCX_FORM_MESSAGE_ERROR` kivételt fog el. A gateway tényleges technikai/alkalmazási hibakezeléséhez az osztályok forrása szükséges.

A függőségek aktív forrását, a runtime portokat és az adapterek tranzakciókezelését ebben a körben nem olvastuk vissza. SAP-szintaxisellenőrzés, ATC és funkcionális teszt nem történt; a riport forrása változtatás nélkül került helyi fájlba.
