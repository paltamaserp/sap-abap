# Üres DM-ALV – átmeneti frontenddiagnosztika

Státusz: WIP, 2026-10-17. A felhasználó szerint a normál képernyő F8 után is üres. Igazolt: GV_DM_READY = X, host SAPLZPR_COCKPIT / 1010, mindkét CREATE OBJECT és SET_TABLE_FOR_FIRST_DISPLAY SY-SUBRC = 0, mezőkatalógus 38 sor, adattábla 4 sor. A debugger szinkron Automation Controller beállítását a felhasználó nem találja.

Ez a blokk a hiba helyének meghatározását szolgálja; nem igazolt végleges javítás. SAP-fordítása és működési próbája nincs, SAP-ba nem írtuk. A korábbi HTTP 400 utáni kapcsolati leállás érvényes; a próba a felhasználó SAP GUI-munkamenetében történik.

## Beillesztés

A `ZPR_DCQM_EXCLUDE` főprogram `FORM create_controls_0100` rutinjában, a `go_alv_grid_01->set_toolbar_interactive` hívás **után**, az `ENDFORM` **elé** tedd ideiglenesen ezt a blokkot. A lokális változók deklarációja szükség esetén áthelyezhető ugyanennek a FORM-nak a meglévő DATA-részébe. Az azonosítók csak ehhez a diagnosztikához tartoznak.

```abap
  DATA: lv_ui_cc_width   TYPE i,
        lv_ui_cc_height  TYPE i,
        lv_ui_grid_width TYPE i,
        lv_ui_grid_height TYPE i,
        lv_ui_rc_ccw     TYPE sysubrc,
        lv_ui_rc_cch     TYPE sysubrc,
        lv_ui_rc_gw      TYPE sysubrc,
        lv_ui_rc_gh      TYPE sysubrc,
        lv_ui_rc_flush   TYPE sysubrc.

  CALL METHOD go_alv_grid_cont_01->get_width
    IMPORTING width = lv_ui_cc_width
    EXCEPTIONS cntl_error = 1 OTHERS = 2.
  lv_ui_rc_ccw = sy-subrc.

  CALL METHOD go_alv_grid_cont_01->get_height
    IMPORTING height = lv_ui_cc_height
    EXCEPTIONS cntl_error = 1 OTHERS = 2.
  lv_ui_rc_cch = sy-subrc.

  CALL METHOD go_alv_grid_01->get_width
    IMPORTING width = lv_ui_grid_width
    EXCEPTIONS cntl_error = 1 OTHERS = 2.
  lv_ui_rc_gw = sy-subrc.

  CALL METHOD go_alv_grid_01->get_height
    IMPORTING height = lv_ui_grid_height
    EXCEPTIONS cntl_error = 1 OTHERS = 2.
  lv_ui_rc_gh = sy-subrc.

  CALL METHOD cl_gui_cfw=>flush
    EXCEPTIONS
      cntl_system_error = 1
      cntl_error        = 2
      OTHERS            = 3.
  lv_ui_rc_flush = sy-subrc.
```

Aktiválás után új SAP GUI-móduszban indítsd a cockpitot. A stockot a már látható kezdőképernyőn add meg és nyomj Entert. A blokk utolsó sorára tegyél session breakpointot, majd F6-tal hajtsd végre az értékadást. A méretértékeket **csak a FLUSH és az utolsó értékadás után** olvasd ki; előtte a pufferelt frontend-válasz még nem feltétlenül érkezett meg. A mérés után F8-cal a képernyőig folytasd is a futást.

## Visszaküldendő eredmény

```text
LV_UI_RC_CCW =
LV_UI_RC_CCH =
LV_UI_RC_GW =
LV_UI_RC_GH =
LV_UI_RC_FLUSH =
LV_UI_CC_WIDTH =
LV_UI_CC_HEIGHT =
LV_UI_GRID_WIDTH =
LV_UI_GRID_HEIGHT =
F8 után megjelent-e az ALV =
```

Értelmezés: nem nulla visszatérési kód frontend-/vezérlőhibát jelez; ilyenkor a méretértékek nem tekinthetők megbízhatónak. Sikeres kódok mellett a nulla szélesség vagy magasság a vezérlő tényleges méretezésének/képernyőhöz rendelésének vizsgálatát indokolja. Pozitív méretek, nulla hibakódok és továbbra is üres kép esetén az aktív elemlista, az elem típusa/helye, a láthatóság és esetleges átfedés vizsgálata következik. Egyetlen kimenet sem igazolt előre, ezért a blokk nem helyettesít tényleges hibaazonosítást.

A mérési adatokat végig a lokális változók élettartamán belül szinkronizáljuk. A külön FLUSH itt átmeneti mérési pont; a normál PBO végén a rendszer egyébként is szinkronizál. A diagnosztikai blokk a hiba rendezése után eltávolítandó.

Források: [SAP: get_width](https://help.sap.com/docs/SAP_NETWEAVER_700/a85596deeb19418982bee031d1fd1427/4d7449e46b7a18b5e10000000a42189e.html), [SAP: get_height](https://help.sap.com/docs/SAP_NETWEAVER_700/12aa56e76c531014b1edbe82ab3371b8/4d75841606cf44b4e10000000a42189e.html), [SAP: FLUSH](https://help.sap.com/docs/SAP_NETWEAVER_731_BW_ABAP/70396d7dec4c4f19b9ca3b2e47559d12/4d70cfeda9e24cb2e10000000a42189c.html?version=7.31.22).

## Első mérés és célzott igazítási próba

A felhasználó eredménye: konténer 1366×424, Grid 0×0, `LV_UI_RC_FLUSH = 0`. Utólag megerősítette: `LV_UI_RC_GW = 0` és `LV_UI_RC_GH = 0`. A Grid méretlekérdezései sikeresek, a mérés szerinti nullaméret így megerősített; ennek kiváltó oka és a SET_ALIGNMENT próba eredménye még nem igazolt. A konténer két egyedi getter-kódját külön nem közölte.

Ha a méretlekérdezések is sikeresek, a következő, egyetlen célzott próba a Grid mind a négy konténerszélhez igazítása. Ez dokumentált API, de ennél a hibánál még nem igazolt megoldás. Az előző mérőblokk elé, a `set_toolbar_interactive` után kerüljön; a két új DATA-deklaráció szükség esetén a FORM elejére vihető:

```abap
  DATA: lv_ui_alignment TYPE i,
        lv_ui_rc_align  TYPE sysubrc.

  lv_ui_alignment = go_alv_grid_01->align_at_left
                  + go_alv_grid_01->align_at_right
                  + go_alv_grid_01->align_at_top
                  + go_alv_grid_01->align_at_bottom.

  CALL METHOD go_alv_grid_01->set_alignment
    EXPORTING
      alignment         = lv_ui_alignment
    EXCEPTIONS
      cntl_error        = 1
      cntl_system_error = 2
      OTHERS            = 3.
  lv_ui_rc_align = sy-subrc.
```

Aktiválás és friss cockpitindítás után ugyanott, a mérőblokk FLUSH-a után olvasandó a `LV_UI_RC_ALIGN`, valamennyi korábbi hibakód, valamint a két Grid-méret. Ezután F8-cal a normál képernyőig kell futni. Siker: hibakódok 0, pozitív Grid-méretek és látható ALV a négy adatsorral. Siker esetén még ablakátméretezés, fülváltás/visszatérés és az önálló `ZPR_DC_EXCLUDE` tranzakció ellenőrzendő; csak utána emelendő át a fő WIP-forrásba. A 1366/424 méreteket nem rögzítjük kódban. Változatlan 0×0 esetén a próba nem igazolja az igazítási feltételezést; nem adunk mellé újabb találomra történő módosítást.

Forrás: [SAP: set_alignment](https://help.sap.com/docs/SAP_NETWEAVER_731_BW_ABAP/70396d7dec4c4f19b9ca3b2e47559d12/4d752803d7cb508ce10000000a42189e.html?version=7.31.30). A négy széligazítás összeadható. A fő ABAP-forrás és az összesített WIP-diff ebben a körben változatlan; csak ez az ideiglenes próba és a napló bővült. SAP-elérés, írás, aktiválás és asszisztens által futtatott működési teszt nincs.

## Az igazítás nem segített: offline működés elkülönítése

A felhasználó a három kért értékre „minden nulla” választ adott: ALIGN-kód 0, Grid-szélesség/magasság továbbra is 0. A próba nem igazolta az igazítási feltételezést. A helyi forrás a Grid I_PARENT paraméterének a GO_ALV_GRID_CONT_01 referenciát adja; hiányzó SE51-attribútumot ebből nem azonosítottunk. Az SAP szerint a Custom Containerbe helyezett vezérlő alapmérete a konténer mérete, ezért nem indokolt egy újabb resizing pipát biztos gyökéroként megnevezni.

Pontosítás a korábbi következtetéshez: sikeres objektumlétrehozás és a 0×0 lekérdezési eredmény önmagában nem bizonyítja, hogy egy létrejött frontend-Grid méretezése hibás. A CL_GUI_ALV_GRID konstruktora offline módban frontendobjektum nélkül hoz létre backendpéldányt. Ezért a következő egyetlen elkülönítő ellenőrzés a dokumentált OFFLINE metódus. Még nincs igazolva, hogy ez okozza a hibát.

A CREATE_CONTROLS_0100 rutinban közvetlenül a `CREATE OBJECT go_alv_grid_01` elé ideiglenesen:

```abap
  DATA lv_ui_offline TYPE int4.

  CALL METHOD cl_gui_alv_grid=>offline
    RECEIVING
      e_offline = lv_ui_offline.
```

A hívás után, a Grid konstruktora előtt kiolvasandó: LV_UI_OFFLINE, SY-BATCH és SY-BINPT. LV_UI_OFFLINE = 1 esetén az ALV frontend nélküli működése igazolt; ezt kiváltó környezetet külön kell feltárni. 0 esetén az offline ág kizárható, utána az aktív konstruktor/PARENT és a frontend láthatósági-konténerlánc célzott vizsgálata indokolt. Ezt nem próbáljuk privát flag módosításával vagy újabb méretezési kerülőmegoldással elnyomni. A fő WIP-forrást nem módosítottuk.

Források: [SAP: offline](https://help.sap.com/docs/ABAP_PLATFORM_NEW/70396d7dec4c4f19b9ca3b2e47559d12/ad1a793814e5e968e10000009b38f8cf.html?locale=en-US&state=PRODUCTION&version=202310.001), [SAP: Custom Container alapméret](https://help.sap.com/docs/SAP_NETWEAVER_700/10a086726c531014ba6d98210e538ce0/4d3eb34ea9bf2304e10000000a15822b.html).

## Offline ág kizárva; aktív kód és layout egyeztetése

A felhasználó megerősítette: LV_UI_OFFLINE = 0, SY-BATCH és SY-BINPT üres. Az offline hipotézis kizárva. A helyi teljes CREATE_CONTROLS_0100, cockpit O01 és C01 újraolvasása nem mutatott explicit elrejtést; I_PARENT = GO_ALV_GRID_CONT_01. Az aktív kód jelenlegi tartalma és a tényleges SE51 layout nincs visszaolvasva. Nem bizonyított, hogy egy resizing vagy láthatósági attribútum hiányzik.

Döntés: újabb találomra történő forrásmódosítás helyett a SAP-ban most aktív teljes FORM CREATE_CONTROLS_0100 bekérése (a diagnosztikai blokkokkal együtt), valamint a SAPLZPR_COCKPIT / 1010 Layout ALV_CONTAINER_01 attribútumablakának képe. Az aktív kódot a helyi konstruktorral, létrehozási feltételekkel, láthatósági/méretezési hívásokkal és végrehajtási sorrenddel kell összevetni; a layouton a technikai név/típus és geometria ellenőrizendő. A korábban már igazolt hostértékeket, sorokat és visszatérési kódokat nem kérjük újra. A konténer alapértelmezett méretkövetését és a szülő láthatóságának hatását az SAP dokumentálja: [Displaying and Relinking Containers](https://help.sap.com/docs/ABAP_PLATFORM_NEW/70396d7dec4c4f19b9ca3b2e47559d12/4d3dd58bd936391ee10000000a15822b.html).

Csak helyi diagnosztikai dokumentáció változott. SAP-kapcsolati kísérlet nincs, a korábbi leállás érvényes; az aktív állapot és a gyökérok továbbra sincs ellenőrizve.

## Új MCP-olvasás részleges eredménye, 13:49

A felhasználó kérésére GetProgram(ZPR_DCQM_EXCLUDE, active) sikeres, HTTP 200. A teljes aktuális főprogram mentve: `../01_SOURCES/DHC/2026-10-17_cockpit_114947_WIP/ZPR_DCQM_EXCLUDE.abap`. A constructor bekötése a fő WIP-pel egyezik; a három diagnosztikai blokk aktív. A `SHIFT lv_stokid LEFT DELETING LEADING '0'.` még aktív; ez külön címformázási eltérés, nem igazolt oka az üres fülnek.

A következő GetInclude(LZPR_COCKPITO01) eszközhívást az automatikus jóváhagyási ellenőrzés elutasította az egyszeri újrapróbálási engedély értelmezése miatt. Ez nem SAP-válasz és nem HTTP-hiba. További MCP-olvasási sorozatra külön engedélyt kértünk; addig nincs több SAP-eszközhasználat. A cockpit include-jai, a 1010 aktuális layout/flow logic és a standard osztályok implementációja ebben a körben nem lettek lekérve. A gyökérok változatlanul nyitott; SAP-írás/aktiválás/futtatás nincs.

Későbbi állapot: a felhasználó megadta a kifejezett olvasásisorozat-engedélyt, de az auto-review az egyetlen új GetInclude(LZPR_COCKPITO01) hívást ennek ellenére is elutasította a korábbi egyszeri szabályra hivatkozva. Nincs új SAP-válasz vagy kapcsolati hiba. Az engedély megléte rögzítve; azonos kérés ismétlése helyett az automatikus korlátozás rendezése vagy felhasználói export szükséges. Újabb eszközre/kerülőútra nem váltottunk, a szabályfájlokat nem írtuk át a korlátozás megkerülésére. Az aktív riportmentésen kívül továbbra sincs friss adat.

## Resizing után is üres: önálló riportút elkülönítése

A felhasználó képe szerint a resizing átállítása után a korábbi belső keret eltűnt; 0000000033 és DM-státusz látszik, ALV-eszköztár/táblázat nem. A kontroll aktuális mérete és láthatósága nem mérhető a képből. A resizing változtatása nem igazolt megoldás az üres fülre.

Döntés: újabb kód vagy attribútum állítgatása előtt az önálló `ZPR_DC_EXCLUDE` tranzakció megjelenítése ellenőrizendő ugyanerre a stockra. A cockpitból előbb normálisan ki kell lépni, hogy a saját stockzár felszabaduljon; utána önálló tranzakció, `0000000033`, F8, mentés/adatmódosítás nélkül. Az önálló ALV eddig nem volt felhasználói próbával igazolt. Ha ott megjelenik, a beágyazási út vizsgálata következik; ha ott is üres, az önálló kontroll-/frontendmegjelenítést kell előbb rendezni. A fő WIP-forrás változatlan, asszisztens általi SAP-futtatás nem történt.

Az önálló próba eredménye zárüzenet az EZPRT_STOCK objektumra, nem ALV-hiba. A mentett aktív riport szerint az enqueue hibája a LOCK_AND_CHECK_STOCK rutinból LEAVE LIST-PROCESSING-gel lép ki, tehát nem jut el a SELECT_DATA/DISPLAY_ALV-ig. Ez nem igazolja vagy cáfolja az önálló ALV-megjelenítést, és nem magyarázza a korábbi cockpitbeli ürességet, ahol az adapter ready és 4 adatsor már igazolt volt.

Döntés: zártörlés helyett önálló megjelenítő próba friss SAP GUI-móduszból SE38 → ZPR_DCQM_EXCLUDE → F8 → stock 0000000033 → F8, szelekciós variáns betöltése nélkül. A mentett forrás P_MODIF rejtett paramétere alapból üres; INITIALIZATION csak SY-TCODE = ZPR_DC_EXCLUDE esetén állítja X-re. SE38-ból alapértékkel GV_MODIF üres, a zárrutin CHECK GV_MODIF EQ ABAP_TRUE miatt nem hív enqueue-t. Ez a konkrét forrásból levezetett várható működés; aktív futásból még nincs visszajelzés. Ha a megjelenítő próba is zárat kér, a tényleges P_MODIF/GV_MODIF/futtatási út eltér az alapértékű SE38-feltételezéstől, ezt kell tisztázni. Asszisztens általi SAP-elérés/futtatás és forrásmódosítás nincs.

## Önálló út működik; konténerreferencia átadása

**Új objektumkép és fontos diagnosztikai korrekció:** a felhasználó képén ACTIVEX = X, GUI_IS_RUNNING = X, IS_INIT = X, INIT_STATE = 2 (FINAL = 2), CFW_MODE = 0, SHELLSTYLE = 1342177280 = WS_CHILD + WS_VISIBLE, LIFETIME = 2, PARENT = O:29 CL_GUI_CONTAINER. H_CONTROL/H_GUI struktúrák, belső mezőik nincsenek kibontva. A saját konténer név/program/subscreen linkje korábban egyezett a megadottal, de ez nem bizonyította a frontend főképernyő-szintjének helyességét.

Egy pontosan egyező, első kézből dokumentált subscreenes ALV-hibánál a REPId/DYNNR explicit átadása okozta az üres kontrollt; a szerző a két paraméter elhagyása után megjelenő ALV-t igazolta, további megjegyzésben a konstruktor főképernyőszám-elvárását írta le. [Elsődleges felhasználói hibaleírás és eredmény](https://community.sap.com/t5/application-development-and-automation-discussions/alv-grid-in-a-subscreen/m-p/5767584). Az automatikus program-/dynpro-felismerés a [SAP konstruktor-dokumentációban](https://help.sap.com/docs/SAP_NETWEAVER_700/10a086726c531014ba6d98210e538ce0/4d3d46339a852303e10000000a15822b.html) is szerepel. Ez erős, célzott nyom, nem a jelenlegi rendszerben végzett implementáció-visszaolvasás vagy sikeres próba.

Döntés: a saját host PBO-ban létrehozott konténerből a `repid = sy-repid` és `dynnr = sy-dynnr` sor törlendő; csak CONTAINER_NAME marad. A fő WIP O01 és a másolható útmutató frissítve, a regressziós ellenőrző ezt a kényszerített subscreen-kötést már tiltja. A korábbi 1010-et kötelezőként/igazoltként előíró értékelés téves volt; ezt jeleztük a felhasználónak. A standalone riport 0100-as konstrukciójához nem nyúlunk. Aktiválás után régi cockpitmódusz bezárása és új indítás szükséges, hogy ténylegesen új konténer készüljön. Sikerkritérium: stock + egy Enter után látható ALV, utána reset/fülváltás és önálló regresszió. A további GET_VISIBLE/IS_ALIVE/parent-mérési kör most nem szükséges a célzott kétparaméteres változtatás előtt. SAP-eszközhívás nincs, a konkrét siker még nem igazolt.

**GET_LINK_INFO eredménye és objektumképek:** PROGRAM = SAPLZPR_COCKPIT, DYNNR = 1010, MODI_LEVEL = 0, NAME = ALV_CONTAINER_01 a felhasználó képe szerint. A tárolt linkadatok egyeznek a várttal. CHILDREN = 1 bejegyzés, M_CONTAINER_TYPE = 2 látszik a konténeren. A példányattribútumokat felsoroló képen H_CONTROL / H_GUI / IS_INIT / PARENT / CFW_MODE neve látható, de az értékoszlop lemaradt. A következő képeken VISIBLE_TRUE = 1, VISIBLE_FALSE = 0, STATE_ALIVE = 0 stb. konstansértékek vannak; ezek nem állapotlekérdezések, nem szabad belőlük élő/halott vagy látható/rejtett objektumot következtetni. A tényleges öt attribútumértéket ugyanabban a debuggermegállásban kérjük, az ablak szélesítésével vagy vízszintes görgetéssel, új kód és új futtatás nélkül. A szülő-/frontendpéldány állapota továbbra is nyitott.

**SET_VISIBLE próba sikertelen:** a felhasználó szerint a két setter-kód, a két láthatósági érték és a FLUSH kódja egyaránt 0. Nincs igazolt megjelenítési javulás, a rejtett állapot pontos oka ebből még nem ismert. Következő adat a tényleges linkállapot, új beállításmódosítás nélkül. A mostani COCKPIT_PBO-ban a végső `CHECK lv_ui_rc_vflush = 0.` elé:

```abap
  DATA ls_ui_link TYPE cfw_link.
  CALL METHOD io_container->get_link_info
    RECEIVING
      link_info = ls_ui_link.
```

A már meglévő végső CHECK-breakpointnál az LS_UI_LINK struktúra teljes kibontott tartalma szükséges, valamint az IO_CONTAINER debuggerben megnyitott objektumának attribútumképe (a szülőreferenciát is beleértve, ha látható). A meglévő két-Enteres eljárás alkalmazható. Várt hostértékek: SAPLZPR_COCKPIT / 1010 / ALV_CONTAINER_01; az új objektum tényleges linkállapota még nem ismert. A GET_LINK_INFO a standard konténer linkállapotát adja vissza, nem köti át az objektumot. LINK/újabb parent/set_visible változtatás e vizsgálat előtt nem kerül be. A hivatalos paraméterjelentésekhez: [SAP Container LINK](https://help.sap.com/docs/SAP_NETWEAVER_701/6da46ca46c4b10148fdef062ca158e15/4d3eacc2a9bf2304e10000000a15822b.html). A fő WIP változatlan, SAP-eszközhívás nincs.

**Láthatóságmérés eredménye:** a felhasználó szerint LV_UI_CC_VISIBLE = 0, LV_UI_GRID_VISIBLE = 0, LV_UI_RC_CCV / GV / VFLUSH mind 0. A következő célzott próba a konténer és a Grid SET_VISIBLE hívása a meglévő két GET_VISIBLE elé, VISIBLE_TRUE osztálykonstanssal. A két setter SY-SUBRC-ja külön LV_UI_RC_SHOW_CC és LV_UI_RC_SHOW_GRID változóba kerül. Teljes ideiglenes FORM: [láthatóvá tételi próba](2026-10-17_cockpit-lathatova-tetel-proba_WIP.abap). A fő WIP stabil C01-je változatlan; SAP-fordítás/futtatás nincs.

Átvezetéskor a teljes aktuális mérő-FORM cserélhető erre, vagy a két új DATA és SET_VISIBLE blokk a meglévő `CHECK go_alv_grid_01 IS BOUND.` után, az első GET_VISIBLE elé illeszthető. A meglévő getterek és FLUSH maradjanak. Aktiválás, friss indítás, végső CHECK-breakpoint és F8 a képernyőig; sikerkritérium a tényleges ALV-eszköztár és sorok megjelenése. Ha nincs megjelenés, a két setter-kód, két visible jelző és három korábbi hibakód kérendő, a változók életében a FLUSH utáni breakpointon. Nem állítjuk, hogy a láthatóság explicit beállítása önmagában megoldja a képernyőszinthez kötési/ős-konténer problémát. A jelenlegi 0/0 érték nem mondja meg, miért maradt rejtett a vezérlő. Forrás: [SAP SET_VISIBLE](https://help.sap.com/docs/SAP_NETWEAVER_702/dc392981440a4d10931cb925534b66d8/4d75b95906cf44b4e10000000a42189e.html).

**Javítás utáni friss debug:** a felhasználó szerint a SET_TABLE_FOR_FIRST_DISPLAY breakpoint megáll, a hívás utáni SY-SUBRC = 0, GT_0100_ALV = 4 sor. A régi konténer-CHECK megszüntetése utáni út elérése így igazolt; a frontend láthatósági állapota még nem.

Következő egyetlen próba: a C01 meglévő COCKPIT_PBO rutinjának ideiglenes teljes cseréje a [láthatósági mérőváltozatra](2026-10-17_cockpit-lathatosag-proba_WIP.abap). Nem újabb FORM-ot kell mellé illeszteni. A hívó szignatúrája változatlanul egy konténerreferencia; az adapter most az egyszeri létrehozás után is megengedi a GET_VISIBLE méréseket. A fő WIP adaptere nem lett felülírva a próbával. A blokk csak lekérdezi a konténer/Grid láthatóságát és külön hibakódjait, majd a lokális eredmények életében FLUSH-t hív; nincs SET_VISIBLE vagy más beállításmódosítás.

Főprogramkörnyezetben ellenőrzés/aktiválás után session breakpoint a mérő-FORM legutolsó `CHECK lv_ui_rc_vflush = 0.` sorára, **a CHECK végrehajtása előtt**. Friss cockpitindítás, stockazonosítás, első megálláskor F8 a képernyőig, majd a már látható cockpitban újabb Enter. **E második megálláskor**, a FLUSH utáni CHECK soron a lokális változók még élnek: LV_UI_CC_VISIBLE, LV_UI_GRID_VISIBLE, LV_UI_RC_CCV, LV_UI_RC_GV, LV_UI_RC_VFLUSH. A nyers karakterértékeket kell visszaadni (például 0/1/X/üres), értelmezés vagy átírás nélkül. Az első létrehozási PBO közbeni adat helyett így a már megjelenített képernyőn végzett következő ciklusban mérünk. F8 után továbbra is a tényleges képernyő a végső megjelenítési bizonyíték. Ha a második Enter nem éri el ezt a breakpointot, ezt kell jelezni; nincs újabb kódváltoztatás találomra.

Az SAP szerint a nem látható szülő a gyermek vezérlőt is elrejti: [Displaying and Relinking Containers](https://help.sap.com/docs/SAP_NETWEAVER_700/10a086726c531014ba6d98210e538ce0/4d3dd58bd936391ee10000000a15822b.html). A kapott láthatósági adatból a getterek és a FLUSH hibakódjai nélkül nem következtetünk okra, és a láthatóként jelzett saját állapot sem bizonyítja a teljes felmenő konténerlánc láthatóságát. A próba nem igazolt javítás, SAP-fordítása/futása még nincs; az asszisztens nem használ SAP-eszközt.

**A konténer-CHECK törlése utáni visszajelzés:** a felhasználó szerint a kép változatlan. A blokkoló sor eltávolítása nem igazolt teljes javítást. Következő mérés kódmódosítás nélkül: friss cockpitmunkamenetben session breakpoint a riport CREATE_CONTROLS_0100 / SET_TABLE_FOR_FIRST_DISPLAY hívásán; eléri-e a futás, majd F6 után SY-SUBRC és GT_0100_ALV sorszáma. A korábbi 0/4 mérés még a referenciás átadás előtti kódra vonatkozott, a mostani elérést nem bizonyítja. Az új eredmény előtt nincs újabb méret-/láthatósági kód vagy layoutmódosítás.

**Új forrásbizonyíték:** a felhasználó 75d13247-6bca-4d13-8846-74ffbaa49025 csatolmányában a régi `CHECK go_alv_grid_cont_01 IS INITIAL.` még bent van, az új konténer-IF felett. Ez a kész konténerreferencia átadása után az ALV létrehozása előtt visszatér. Az aktuális blokkoló sor így igazolt; az egy sor eltávolításának megjelenítési eredménye még nem. Teljes, minimálisan javított FORM: [CREATE_CONTROLS_0100](2026-10-17_create-controls-0100-javitott_WIP.abap). A hiányzó FORM-fejléc pótlásán és az egyetlen CHECK törlésén kívül minden felhasználói tartalom megőrizve; helyi exact ellenőrzés sikeres. A fő WIP-ben ez a sor már nem volt benne, így a fő WIP-forrás most nem változott. SAP-művelet nincs.

**A fix szöveges próba eredménye:** a felhasználó képernyőképén a `DM 1010 TESZT` és `DM 1010 TESZT2` feliratok láthatók a DM-fülön. A 1010 tényleges láthatósága igazolt, az ALV továbbra sem látható. Újabb layoutmozgatás nem szükséges. A legutóbbi kódátvezetés óta nincs friss teljes CREATE_CONTROLS_0100 forrás, ezért előbb annak eleje szükséges: ha a régi `CHECK go_alv_grid_cont_01 IS INITIAL.` még bent maradt, az új adapter által már átadott konténer miatt korán visszatér. Ennek a sornak a meglétét nem állítjuk bizonyított oknak a jelenlegi SAP-forrás bekérése előtt. A DATA-résztől a Grid CREATE OBJECT végéig kérjük a blokkot; a helyi WIP-ben a megfelelő konténer-IF már megvan. Új ABAP-módosítás vagy MCP-hívás nincs.

**A statikus jelölés előkészítésének pontosítása:** a felhasználó szerint az attribútumablak Sor mezője nem írható. Az előző, közvetlen mezőátírást kérő utasítás pontatlan volt. A grafikus Layoutban az elemet kijelölve, egérrel kell az új helyre húzni. Először az attribútumablakban a magasság csökkentendő 35-ről 33-ra, Átvétel, majd a teljes konténer elmozdítandó két sorral lefelé a felső kijelölőfogantyúnál/élnél megfogva. Így a mozgatáskor van elegendő hely az eredeti 35 soron belül. Ha maga a magasság és a mozgatás is tiltott, a Layout módosítási módját kell ellenőrizni. A felszabadult első sorba kerülhet a fix próbaszöveg. Forrás: [SAP Screen Painter: Basic Operations with Screen Elements](https://help.sap.com/saphelp_gbt10/helpdata/en/d1/801bc5454211d189710000e8322d00/content.htm?no_cache=true). Ez kezelési pontosítás; új ABAP vagy SAP-hívás nincs.

**Későbbi visszajelzés:** az IO_CONTAINER aktiválási hiba tisztázása után a felhasználó szerint továbbra sem látható semmi. A konténerátadási változat nem igazolt javítás; a mostani teljes SAP-kód nem lett visszaolvasva. Következő diagnosztika a 1010-es subscreen statikus képernyőelemének láthatósága: SE51 SAPLZPR_COCKPIT / 1010 első sor, első oszlop, `DM 1010 TESZT` fix szöveg. A már létező custom control kezdősora 3, magassága 33 legyen a korábbi 1/35 helyett; a név/típus változatlan. Így a szöveg nem esik a frontendkontroll területére, és a kontroll továbbra is az eredeti 35 soros tartományon belül van. Mentés/aktiválás és friss cockpitindítás/stockazonosítás után a szöveg láthatósága szükséges. Látható szöveg esetén a subscreen megjelenik, a kontroll-lánc vizsgálata következik; hiányzó szöveg esetén a 0100 subscreen-területének/aktív fülhöz rendelésének és a tényleges képernyőazonosságnak a vizsgálata szükséges. Ez kizárólag megkülönböztető próba, nem javítás; új ABAP-kód nincs.

A felhasználó következő képén az önálló SE38-as megjelenítő ALV eszköztára és mind a négy adatsor látható. Ez az önálló megjelenítési út működését igazolja; a cockpit beágyazás konkrét hibás frontendkapcsolata továbbra sem bizonyított.

Döntés: újabb méretmérés helyett célzott helyi WIP-változat készült. A custom container létrehozását a host DM_CONTROLS PBO-ja végzi; a riport COCKPIT_PBO egyetlen típusos konténerreferenciát fogad, a CREATE_CONTROLS_0100 pedig nem térhet vissza pusztán a konténer létezése miatt. Sikeres bezáráskor a host elengedi saját referenciáját is. Az önálló út és a megjelenítési/mentési üzleti rutinok megmaradtak. Útmutató: [konténerátadás](2026-10-17_cockpit-kontener-atadas_WIP.md). A fő WIP-csomag négy ABAP-forrása már ezt tartalmazza; a korábban mentett felhasználói/aktív források változatlanok.

A helyi szerkezeti és kétirányú diffellenőrzés sikeres; SAP-fordítás, ATC és működési próba nincs. Ez javítási változat, nem igazolt gyökérok vagy kész megoldás. Az összetartozó módosításokat együtt kell aktiválni a megváltozott COCKPIT_PBO szignatúra miatt. A felhasználói friss cockpitpróba eredményét várjuk; MCP-hívás és kerülőút nincs.
