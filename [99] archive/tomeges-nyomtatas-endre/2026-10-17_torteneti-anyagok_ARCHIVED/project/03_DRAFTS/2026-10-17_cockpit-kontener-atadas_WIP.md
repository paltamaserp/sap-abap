# Cockpit: a kész képernyőkonténer átadása a riportnak

**Fontos pontosítás, 2026-10-17:** a cockpit saját DM_CONTROLS PBO-jában a custom container létrehozásakor **csak a CONTAINER_NAME kerül átadásra**. A korábbi `repid = sy-repid` / `dynnr = sy-dynnr` sorok törölve az alábbi kódból és a fő WIP-ből. A subscreen 1010 számának explicit frontend-hozzárendelése valószínű hibaforrás: egy azonos tünetű, első kézből dokumentált SAP Community esetben a konstruktornak a főképernyő kellett, a két paraméter elhagyásával az automatikus felismerés megoldotta a problémát. A korábbi 1010-es linket helyesnek minősítő diagnosztikai értékelés túl erős és valószínűleg hibás volt. A subscreen a továbbiakban is 1010, az adapter továbbra is a kész konténert kapja; az önálló riport 0100-as útja nem változik. [Azonos subscreen-hiba és felhasználói megoldása](https://community.sap.com/t5/application-development-and-automation-discussions/alv-grid-in-a-subscreen/m-p/5767584), [SAP: a konténerkonstruktor automatikus program-/képernyő-meghatározása](https://help.sap.com/docs/SAP_NETWEAVER_700/10a086726c531014ba6d98210e538ce0/4d3d46339a852303e10000000a15822b.html).

Az explicit REPId/DYNNR elhagyása után a konténert újra kell létrehozni: mentés/függvénycsoport-aktiválás, a régi cockpitot futtató módusz normál bezárása és friss indítás szükséges. A cél közvetlenül a stock beazonosítása utáni ALV; a két Enter csak a korábbi méréshez kellett. A helyi módosítás sikere ebben a konkrét SAP-ban még nem igazolt.

Státusz: **WIP**, 2026-10-17. A felhasználó SE38-as megjelenítő próbáján az önálló ZPR\_DCQM\_EXCLUDE ALV eszköztára és mind a négy adatsor látható. A cockpit továbbra is üres. Ezzel az önálló út működése igazolt; a beágyazás konkrét hibás frontendkapcsolata még nem azonosított. Az alábbi változat a konténer létrehozását a képernyőt kezelő program saját PBO-jába helyezi, és a riportnak a kész objektumreferenciát adja. Eredményessége SAP-ban még kipróbálandó; nem állítunk igazolt gyökérokot.

A négy érintett forrás a `2026-10-16_cockpit_WIP/` csomagban már ezt tartalmazza. Az SAP-ban az alábbi részeket együtt kell átvezetni. A meglévő MODULE/FORM definíciót cseréld, ne vegyél fel mellé másodikat. Az O01/C01 felhasználói másolata és a 13:49-es aktív riport volt az összevetés alapja. A fő WIP riportban nincs benne a korábbi ideiglenes mérőkód; az SAP-forrás többi részét meg kell őrizni.

## 1. LZPR\_COCKPITTOP: egy új globális referencia

A globális DATA-deklarációkhoz add hozzá:

```abap
DATA go_dm_container TYPE REF TO cl_gui_custom_container.
```

## 2. LZPR\_COCKPITO01: DM\_CONTROLS cseréje

```abap
MODULE dm_controls OUTPUT.
  CHECK gv_dm_ready = abap_true.
  IF go_dm_container IS INITIAL.
    CREATE OBJECT go_dm_container
      EXPORTING
        container_name              = 'ALV_CONTAINER_01'
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc <> 0.
      MESSAGE text-102 TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ENDIF.
  PERFORM cockpit_pbo IN PROGRAM zpr_dcqm_exclude
    USING go_dm_container.
ENDMODULE.
```

Ugyanebben az include-ban a `FORM dm_close` sikeres ágába egy sor kerüljön, közvetlenül a `CLEAR gv_dm_ready.` elé:

```abap
  IF lv_ok = abap_true.
    FREE go_dm_container.
    CLEAR gv_dm_ready.
  ELSE.
    save_ok = '#CANCEL'.
  ENDIF.
```


A riport COCKPIT\_CLOSE rutinja a kontrollokat már felszabadítja; itt a cockpit saját referenciáját engedjük el. Az elutasított kilépési/reset megerősítés ágában a referencia megmarad. Az eredeti `PERFORM cockpit_close ...` hívás és a rutin többi része maradjon meg.

## 3. ZPR\_DCQM\_EXCLUDE\_C01: csak a COCKPIT\_PBO cseréje

A korábbi két szöveges paraméter helyett egy típusos objektumreferenciát fogad:

```abap
FORM cockpit_pbo USING io_container TYPE REF TO cl_gui_custom_container.
  CHECK gv_embedded = abap_true.
  CHECK io_container IS BOUND.
  CHECK go_alv_grid_01 IS INITIAL.
  go_alv_grid_cont_01 = io_container.
  PERFORM create_controls_0100.
ENDFORM.
```


A COCKPIT\_OPEN/SAVE/CLOSE rutinok változatlanok. A C01 INCLUDE továbbra is egyszer szerepeljen a főprogramban.

## 4. ZPR\_DCQM\_EXCLUDE: a CREATE\_CONTROLS\_0100 eleje

A meglévő DATA-rész utáni két CHECK-et és konténerlétrehozást az alábbi blokkra cseréld. Fontos: a `CHECK go_alv_grid_cont_01 IS INITIAL.` sort el kell távolítani, mert a cockpit már átadta a kész konténert. A Grid létrehozása és a rutin további része az alábbi ENDIF után változatlanul folytatódik.

```abap
  CHECK go_alv_grid_01 IS INITIAL.

  IF go_alv_grid_cont_01 IS INITIAL.
    CREATE OBJECT go_alv_grid_cont_01
      EXPORTING
        container_name              = 'ALV_CONTAINER_01'
        repid                       = gv_host_repid
        dynnr                       = gv_host_dynnr
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5.
    IF NOT sy-subrc IS INITIAL.
      EXIT.
    ENDIF.
  ENDIF.
```

Az ezt követő meglévő `CREATE OBJECT go_alv_grid_01` EXPORTING részében továbbra is `i_parent = go_alv_grid_cont_01` legyen. Az önálló riport az IF ágon létrehozza saját konténerét, a cockpit a már átadott példányra hozza létre a Gridet. A főprogram hostváltozói és DISPLAY\_ALV rutinja az önálló úthoz maradnak.

## Szöveg, aktiválás, próba

**Aktiválási hiba: `Field IO_CONTAINER is unknown`.** Az `IO_CONTAINER` kizárólag a C01 adapter `COCKPIT_PBO` rutinjának új formális paramétere; a deklarációja a teljes új FORM-fejlécben van. Nem a TOP-ba felveendő globális változó. A felhasználó ilyen hibát jelzett, de include/sorszám nélkül; a konkrét SAP-beli eltérés nincs ellenőrizve.

- C01: a meglévő teljes `COCKPIT_PBO` FORM-ot a 3. pont teljes blokkjára kell cserélni, az új fejléccel együtt. Ha a régi `USING iv_repid ... iv_dynnr ...` fejléc maradt meg az új törzs előtt, az `IO_CONTAINER` ismeretlen lesz. Ne kerüljön be második FORM-definíció.
- Cockpit O01: a tényleges paraméter `USING go_dm_container.`, a TOP-ban ennek a referenciának van DATA-deklarációja.
- Riport `CREATE_CONTROLS_0100`: a Grid `I_PARENT` értéke `GO_ALV_GRID_CONT_01`; itt az `IO_CONTAINER` név nem használható, mert nem ennek a FORM-nak a paramétere.

Fennmaradó hibánál az include neve, a hibasor és a környező FORM-fejléc szükséges; egy találomra felvett globális `IO_CONTAINER` nem megfelelő javítás.


SE80/SE38 → SAPLZPR\_COCKPIT szövegszimbólumok: új `102` = `A DM lista képernyőkonténere nem hozható létre.` A szükséges fordításokat és transzportot is karban kell tartani. A teljes szöveglista a csomag `2026-10-17_cockpit-textelemek_WIP.tsv` fájljában van; a 101 meglévő szöveg marad.

Az összetartozó módosításokat a **ZPR\_DCQM\_EXCLUDE + C01** főprogramkörnyezetében és a **ZPR\_COCKPIT függvénycsoportban** együtt ellenőrizd/aktiváld. A COCKPIT\_PBO paraméterszáma megváltozott: a régi hívó két paraméterrel nem maradhat aktív az új adapter mellett. Az aktiválások között ne fusson cockpitpróba. Új SE51-flow logic vagy újabb konténer nem szükséges; a meglévő 1010 PBO `MODULE dm_controls.` és ALV\_CONTAINER\_01 marad.

Friss cockpitindítással, a stockra zárat tartó saját korábbi munkamenetek normál bezárása után:

1. Stock 0000000033, Enter: megjelenik-e az ALV eszköztára és a négy sor ugyanabban a fülben? Ez a javítás első sikerkritériuma; a Grid örökölt méret-gettereinek 0 értékét nem használjuk egyedüli sikerkritériumként.
2. Fülváltás és visszatérés, majd Új stock / alaphelyzet és ismételt beazonosítás: új konténerrel megjelenik-e? A régi ready/objektumreferencia ne akadályozza az új létrehozást.
3. Mentetlen cellaváltozás miatti eldobás elutasításakor a képernyő, érték és referencia maradjon meg; elfogadáskor szabaduljon fel a saját stockzár és a két referencia.
4. Az önálló SE38-as megjelenítés továbbra is működjön. A módosítás nem változtat adatlekérési vagy mentési üzleti logikát.
5. Ablakátméretezés és a stock vezető nulláinak megjelenése külön ellenőrizendő. Az aktív riportban még meglévő címformázó SHIFT továbbra is külön, ismert eltérés; a fő WIP-ben már nincs benne.


Sikeres próba után a korábbi LV\_UI\_\* mérőblokkok eltávolíthatók a riportból. Előtte nem szükséges átírni őket. Ez a csomag csak helyben módosult, az asszisztens nem írt/aktivált/futtatott SAP-objektumot; az MCP auto-review korlátozása fennmarad.

Forrás a szülőkonténer átadásához: [SAP ALV Grid CONSTRUCTOR](https://help.sap.com/docs/SAP_NETWEAVER_700/12a9d91a6c53101489a69be2cd91f0df/0ab552f7d30911d2b467006094192fe3.html). A dokumentált I\_PARENT használat nem bizonyítja előre, hogy ez a változtatás megoldja az adott frontendhibát.
