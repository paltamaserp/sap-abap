# LZPR\_COCKPITO01 – Hidden OK-Codes

Státusz: **WIP**, 2026-10-17. Helyi javítás, SAP-aktiválás és QA/ATC-futtatás nélkül. Az aktív SAP-állapot nincs ellenőrizve; a korábbi kapcsolati leállás miatt új SAP-hívás nem történt.

A bejelentett 54. sor pontosan szerepel a korábbi felhasználói O01-másolatban. A `#STOCK` és `#CANCEL` itt belső feldolgozási eredmény, mégis a képernyő parancsát tároló `SAVE_OK` mezőbe került. A javítás ezeket külön logikai jelzőre cseréli, valamennyi írási és olvasási helyen. A képernyő funkciókódjának mentése és az OK-mező törlése megmarad a [SAP dokumentált mintája](https://help.sap.com/docs/ABAP_PLATFORM_NEW/bd833c8355f34e96a6e83096b38bf192/4a44a8dd76f0044ee10000000a421937.html) szerint.

**Döntés:** nincs konstansba rejtés vagy QA-kikapcsolás; a `SAVE_OK` kizárólag felhasználói funkciókódot tartalmazhat.

## Átvezetés

A [TOP](2026-10-16_cockpit_WIP/LZPR_COCKPITTOP.abap) és az [O01](2026-10-16_cockpit_WIP/LZPR_COCKPITO01.abap) együtt változik. A célzott [diff](2026-10-17_cockpit-hidden-okcodes_WIP.diff) kizárólag az e javítás előtti helyi WIP-hez viszonyít; a teljes friss forrásban a javítás már benne van. A nyers felhasználói és SAP-exportok változatlanok. A célrendszer esetleges újabb módosításait meg kell őrizni.

1. A TOP globális deklarációihoz:

```abap
DATA: gv_stock_changed      TYPE abap_bool,
      gv_dm_close_cancelled TYPE abap_bool.
```

1. Az O01 `PREPARE_COMMAND` elején, a meglévő `CLEAR ok_code.` után:

```abap
  CLEAR: gv_stock_changed, gv_dm_close_cancelled.
```

1. A jelzett feltétel helyére:

```abap
  IF gv_stock_changed = abap_true OR gv_dm_close_cancelled = abap_true.
    LEAVE TO SCREEN 100.
  ENDIF.
```

1. Az O01 összes további kapcsolódó helyét is át kell vezetni:



| Hely | Új működés |
|---|---|
| ACCEPT\_STOCK, sikeres kontextusváltás | `gv_stock_changed = abap_true.` |
| ACCEPT\_STOCK, elutasított bezárás | `IF gv_dm_close_cancelled = abap_true.` |
| DM\_CLOSE eleje, a meglévő CHECK előtt | `CLEAR gv_dm_close_cancelled.` |
| DM\_CLOSE, sikertelen/elutasított adapterbezárás | `gv_dm_close_cancelled = abap_true.` |
| USER\_COMMAND és RESET\_COCKPIT, DM\_CLOSE után | `CHECK gv_dm_close_cancelled = abap_false.` |
| CANCEL, DM\_CLOSE után | `IF gv_dm_close_cancelled = abap_true.` |
| RESET\_COCKPIT, sikeres alaphelyzet | A CLEAR-listába mindkét új jelző bekerül. |

A DM\_CLOSE eleji törlés a már inaktív DM-adapter miatti korai visszatéréskor is szükséges: egy előző elutasítás jelzője nem maradhat érvényben. Az új PAI eleji törlés a stockváltás jelzőjének átszivárgását is megakadályozza. Az eredeti felhasználói parancsot egyik belső rutin sem írja felül.

Ehhez a javításhoz nem kell új SE41 funkciókód vagy képernyőmódosítás. A TOP és O01 ellenőrzése/aktiválása a függvénycsoporttal együtt szükséges. A korábbi konténerátadási útmutató DM\_CLOSE-részlete még a régi állapotkódot mutatja; az aktuális rutint a fenti O01-ből kell venni.

## Helyi ellenőrzés

A csomag `ellenorzes.cjs` ellenőrzése sikeres: a belső kódok hiányoznak a végrehajtható cockpitforrásból, a `SAVE_OK` egyetlen értékadó utasítása `save_ok = ok_code.`, az új jelzők deklarálva és inicializálva vannak. A stockállapot-műveletek és a riport üzleti rutinjai változatlanok; a hívásparaméterek, képernyőmodulok és a konténer életciklusának szerkezeti ellenőrzése megfelelt. A teljes csomagdiff előre/vissza pontosan alkalmazható; a SHA256-jegyzék frissült. A célzott QA-diff külön másolaton szintén előre/vissza ellenőrizve.

Ez forrásszerkezeti ellenőrzés; nincs helyi ABAP-futtatás, új ABAP-parseres ellenőrzés, SAP-fordítás, ABAP Unit, QA/ATC vagy GUI-próba. A QA-találat lezárásához a célrendszerbeli újrafuttatás szükséges; a megadott találat nem tartalmazta az ellenőrzés azonosítóját/variánsát.

## SAP-ban még végrehajtandó próbák

| Próba | Elvárt eredmény |
|---|---|
| Üres stock + Enter; hibás stock | Kezdőképernyő, illetve meglévő hibaüzenet; nincs művelet. |
| Új érvényes stock + Enter | Fejléc és DM-lista betölt, stockmező lezárul; a kimenő subscreen PAI kimarad. |
| Új érvényes stock és ugyanabban a körben státuszgomb | Stock elfogadva; a régi parancs nem hajt végre státuszmódosítást az új stockon. |
| Ugyanaz a stock, következő Enter | Stockváltás jelzője törölve; normál PAI, nincs megismételt kontextusváltás. |
| Fülváltás/státuszgomb, eldobás elutasítva | Stock, fül, adatok és zár megmaradnak; nincs státuszmódosítás. |
| RESET, eldobás elutasítva, majd jóváhagyva | Először teljes kontextus marad, utána alaphelyzet; mindkét jelző üres. |
| Kilépés, eldobás elutasítva, majd jóváhagyva | Először a cockpiton marad, utána kilép; kontroll/zár megfelelően felszabadul. |
| Ismételt bezárás, már inaktív DM | Nincs korábbi elutasításból visszamaradt tiltás. |

Nyitott: aktív SAP-verzió egyeztetése, fordítás, a jelzett QA-ellenőrzés újrafuttatása és a fenti GUI-regresszió.
