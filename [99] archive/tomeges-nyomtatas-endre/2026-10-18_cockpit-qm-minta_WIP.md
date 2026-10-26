# Cockpit – QM minta fül, stockkal előtöltött indítóképernyő

**2026-10-18-i korrekció:** a külső adapter közvetlen START-hívása helyett most `SUBMIT ZPR_QM ... AND RETURN` indítja a saját 2000-es QM-képernyőt, hat paraméter átadásával. A gomb fordítható alapfeliratot kapott. [Külön javító diff és a bejelentett dump pontosítása](2026-10-18_cockpit-qm-dynpro-gomb-javitas_WIP.md). A javítás már a munkaforrásban és a teljes QM-diffben is szerepel.

Státusz: **WIP** · Dátum: **2026-10-18**

**A módosítás csak helyben történt.** A harmadik, `T_QM_CHECK` / „QM minta” fül a `ZPR_QM` indítóképernyőjének beágyazható változatát jeleníti meg, a cockpitban elfogadott stockkal kitöltve. A fül megnyitása nem futtat QM-üzleti műveletet és nem kér stockzárat. A négy művelet és az elrendezés kiválasztása után a **QM indítása** gomb indítja a meglévő riportfolyamatot.

## Hol vannak a módosítások?

| Fájl | Változás |
|---|---|
| [LZPR_COCKPITO01.abap](2026-10-16_cockpit_WIP/LZPR_COCKPITO01.abap) | A QM-fül programja `ZPR_QM`, képernyője `1100`. Új `QM_OPEN` / `QM_CLOSE` adapterhívások; az Indítás-kérés feldolgozása a főképernyő PAI-jában. Resetnél, kilépésnél és stockváltásnál a QM-indítólap állapota törlődik. |
| [LZPR_COCKPITTOP.abap](2026-10-16_cockpit_WIP/LZPR_COCKPITTOP.abap) | Két logikai jelző: `GV_QM_READY`, `GV_QM_COMMAND_HANDLED`. Nincs új objektumreferencia. |
| [Z_PR_COCKPIT.abap](2026-10-16_cockpit_WIP/Z_PR_COCKPIT.abap) | A QM-kontextus törlése a függvény új hívásakor és a cockpitképernyő visszatérése után. |
| [ZPR_QM.abap](2026-10-16_cockpit_WIP/ZPR_QM.abap) | Új helyi munkamásolat; új 1100-as selection subscreen a meglévő `B_MAIN` és `B_LAYOUT` blokkokkal. Stockátadás, külön Indítás gomb, adapterrutinok. Az eredeti 1000-es indítóképernyő és a teljes `LCL_QM` implementáció változatlan. |
| [QM-textelem](2026-10-16_cockpit_WIP/2026-10-18_qm-textelemek_WIP.tsv) | A `ZPR_QM` új `TEXT-101` felirata: `QM indítása`. |
| [ellenorzes.cjs](2026-10-16_cockpit_WIP/ellenorzes.cjs) | A korábbi helyi ellenőrzések kiegészítése a QM-adapterrel, stockátadással, életciklussal és a változatlan üzleti vezérlés ellenőrzésével. |

**Célzott diff:** [2026-10-18_cockpit-qm-minta_WIP.diff](2026-10-18_cockpit-qm-minta_WIP.diff). Ez csak a mostani QM-bekötést tartalmazza: a három cockpitforrásnál a feladat eleji WIP-hez, a `ZPR_QM`-nél az eredeti [helyi referenciaforráshoz](../01_SOURCES/QU5/ZPR_QM.abap) viszonyít. Négy ABAP-fájlt érint, 13 hunkkal; a szövegelem karbantartása a TSV szerint külön szükséges.

A csomag [ABAP-valtozasok_WIP.diff](2026-10-16_cockpit_WIP/ABAP-valtozasok_WIP.diff) fájlja is frissült. Az a teljes cockpitfejlesztést mutatja a korábbi helyi kiinduló forrásokhoz képest, nem csak ezt a QM-bekötést. A két diff eltérő összehasonlítási alapot használ, ugyanarra a célra nem kell mindkettőt alkalmazni.

## Mit fogsz látni?

1. Stock megadása és elfogadása a cockpit fejlécében.
2. „QM minta” fül: a képen látható QM-ellenőrzés és Megjelenítés blokkok, kitöltött stockazonosítóval. A stock a fülön csak megtekinthető, a cockpit közös stockja érvényes.
3. Alapértelmezés: Kizárások szerkesztése. A Megtekintés, QM-engedélyezés és QM-engedélyezés visszavétele rádiógombok is az eredeti riporthoz tartoznak.
4. A **QM indítása** gomb végrehajtja a kiválasztott műveletet. Szerkesztésnél/megtekintésnél a meglévő 2000-es QM-rács/PDF-képernyő nyílik meg, majd visszatér a cockpit QM-fülére. A 2000-es eredményképernyőt ebben a feladatban nem ágyaztuk át; a kérés szerinti első, indítóképernyő van a fülön.
5. Ugyanannál a stocknál a fülváltás megőrzi a kiválasztott módot és elrendezést. Reset vagy másik stock új elfogadása törli ezeket, és szerkesztési alapállapotot állít be; nem maradhat másik stockról engedélyezési/visszavételi választás.

A QM-indítás gomb eseménye a riportban csak egy logikai kérést állít be. Az üzleti műveletet a cockpit a subscreen PAI-jának befejezése után, `SUBMIT ... AND RETURN` hívással külön riport-munkamenetben indítja; a kérésjelzőt előtte törli, így egy újabb Enter vagy fülváltás nem ismétli meg az előző indítást. A fül megnyitásakor és az indításkor is van `S_TCODE / ZPR_QM` ellenőrzés. Jogosultság nélkül a QM-fül nem töltődik be, a cockpit a DM-jóváhagyás fülre tér át tájékoztató üzenettel.

## Miért új 1100-as képernyő?

A standard 1000-es selection screen normál indítóképernyő; beágyazáshoz külön `AS SUBSCREEN` definíció szükséges. Az új 1100-as képernyő `INCLUDE BLOCKS` utasításokkal ugyanazokat a paramétereket és feliratokat használja, ezért a stock és a rádiógombok nincsenek külön lemásolva. A főképernyő meglévő PBO/PAI `CALL SUBSCREEN` párja kezeli az adatátadást. Forrás: [SAP – Selection Screens as Subscreens](https://help.sap.com/saphelp_scm700_ehp02/helpdata/EN/4a/43c16a5a503f04e10000000a421937/content.htm?no_cache=true), [SAP – Defining Selection Screens](https://help.sap.com/saphelp_em92/helpdata/en/4a/43c2a55a503f04e10000000a421937/content.htm?no_cache=true).

A saját gomb `QRUN` funkciókódját a `SSCRFIELDS-UCOMM` mezőből vesszük át. Forrás: [SAP – Pushbuttons on the Selection Screen](https://help.sap.com/saphelp_em92/helpdata/en/4a/43f6ac5bc52baee10000000a421937/content.htm?no_cache=true).

## SAP-ba történő későbbi átvezetés

Ebben a feladatban SAP-írás, aktiválás vagy kapcsolati kísérlet nem történt. A fennálló leállási szabály szerint új SAP-kísérlethez külön, kifejezett újrapróbálási kérés kell.

1. Az aktív cockpit és `ZPR_QM` esetleges újabb módosításait össze kell vezetni a helyi forrásokkal. A QM-program egyetlen helyi példánya a `01_SOURCES/QU5/` mappában volt; a saját fejlécében DHC szerepel. A mappanév alapján nem állítjuk, hogy ez az aktív DHC-program friss exportja. A `ZPR_QM` tranzakció aktív SE93-hozzárendelése sem lett külön visszaolvasva; a felhasználó által megadott tranzakció-/programnévre építünk.
2. A három cockpitforrást és a `ZPR_QM` módosításait együtt kell átvezetni. A riport új adapterrutinjai nélkül a cockpit hívásai nem futtathatók.
3. A `ZPR_QM` szövegszimbólumaihoz fel kell venni a 101-es szöveget a mellékelt TSV szerint, a meglévő 001–021 szövegek és fordítások megőrzésével. Ha az aktív szövegkészletben a 101 foglalt, a forrás és a szövegazonosító együtt számozandó át.
4. A cockpit 0100 flow logic PBO-részében a subscreen programja **`GS_TABSTRIP-PROG`** legyen, ne rögzített `SY-REPID`. A helyi [0100 flow](2026-10-16_cockpit_WIP/ZPR_COCKPIT_0100.flow.abap) már ezt tartalmazza, ezért most nem kellett módosítani. A PAI-részben a `CALL SUBSCREEN T_SUB_SC.` a `USER_COMMAND` előtt maradjon.
5. A `T_QM_CHECK` fül továbbra is a közös `T_SUB_SC` területet használja, normál/szerveroldali fülváltással. Nincs szükség új QM custom controlra, kézzel létrehozott selection dynpróra vagy új QM-gomb SE41-karbantartására: az 1100 és a QM indítása gomb a riport forrásából generálódik. A korábbi 1030-as cockpit-subscreen ezen az ágon már nem hívódik.
6. Fordítás/aktiválás, ATC és az alábbi GUI-próbák szükségesek. A [korábbi DM-gombjavítás diffje](2026-10-18_cockpit-dm-gombok-beragadas_WIP.diff) továbbra is külön alkalmazható; ennek kompatibilitását az új O01-gyel ellenőriztük, de a DM-gombpatch nincs automatikusan beolvasztva a mostani QM-feladatba.

## Ellenőrzés

- [QM-PARSER_WIP.json](2026-10-16_cockpit_WIP/QM-PARSER_WIP.json): `@abaplint/core 2.120.60`, ABAP 7.54, a cockpit összeállított forrása és a QM-riport parserhibák nélkül. Ez nem aktív DDIC-/osztályfeloldás vagy SAP-fordítás.
- [HELYI-ELLENORZES_WIP.json](2026-10-16_cockpit_WIP/HELYI-ELLENORZES_WIP.json): az eredeti DM-üzleti rutinok és státuszváltó hívások megőrzése, az összes adapterhívás és paraméterszám, a QM-beviteli blokkok és a teljes üzleti osztályimplementáció változatlansága, indítás nélküli fülmegnyitás, stockátadás, kérésfogyasztás, reset/kilépés/stockváltás és a teljes csomagdiff ellenőrizve.
- [QM-DIFF-ELLENORZES_WIP.json](2026-10-16_cockpit_WIP/QM-DIFF-ELLENORZES_WIP.json): a mostani célzott diff külön másolaton előre és vissza alkalmazva bájtpontos. Az eredeti QM-forrás megmaradt; a DM-gombjavítás az új O01-re továbbra is alkalmazható.
- SAP-futás, ATC, ABAP Unit és valódi frontendpróba nem történt. A `ZCL_PR_QM_DATA`, `ZCL_PR_QM_EXCLUSION`, interfészek, Inspire gateway és a riport meglévő függőségeinek aktív állapota nincs ellenőrizve. A QM üzleti kódjában örökölt modern szintaxis és korábbi névkonvenciók nem kerültek általános átírásra; az új adapterkód explicit típusozású, új template stringet nem tartalmaz.

SAP-ban végrehajtandó próbák: stock+Enter után QM-fül és előtöltés; DM-stockkal paraméteres indulás; fülváltáskor nincs automatikus QM-művelet; F4 az elrendezéshez; Indítás mind a négy móddal; a QM-rácsból visszatérés és mentetlen módosítások elutasítása; Enter nem ismétli az indítást; reset az egyik stockról másikra, alapértékek visszaállítása; jogosulatlan felhasználó; kilépés és új belépés; az önálló `ZPR_QM` 1000/2000 út és a DM-fül regressziója.
