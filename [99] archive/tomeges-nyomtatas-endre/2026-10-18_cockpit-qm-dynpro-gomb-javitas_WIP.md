# QM-indítás: dynprohiba és üres gombfelirat

Státusz: **WIP**, 2026-10-18. Kizárólag helyi javítás; az aktív SAP-forrás nincs ellenőrizve.

A javítás már szerepel a [ZPR_QM.abap](2026-10-16_cockpit_WIP/ZPR_QM.abap) munkapéldányban. A [külön javító diff](2026-10-18_cockpit-qm-dynpro-gomb-javitas_WIP.diff) a közvetlenül előző QM-bekötéshez képest mutatja a három módosított részt. A [teljes QM-bekötés diffje](2026-10-18_cockpit-qm-minta_WIP.diff) szintén frissült; új átvezetéshez az használható. A két diff ugyanazt a javítást tartalmazza, ezért egymás után nem alkalmazandók.

## A képernyőhívás hibája

A korábbi adapter külső PERFORM-ból közvetlenül hívta a LCL_QM=>START metódust, amely a szerkesztőben CALL SELECTION-SCREEN 2000 utasítást futtat. A külső alprogram a cockpit programcsoportjához tartozik; az így indított képernyőt a futtatókörnyezet a hívó főprogramhoz/függvénycsoporthoz köti. Így a meglévő ZPR_QM / 2000 helyett SAPLZPR_COCKPIT / 2000 keresése is történhet. Ezt a korábbi bekötés hibájaként javítottuk. [SAP: külső eljárások és képernyőkezelés](https://help.sap.com/docs/SAP_NETWEAVER_701/6da3d9466c4b1014a5a2e370bd8c5dc8/c5aa575926ad11d2954d0000e8353423.html?locale=en-US).

A COCKPIT_EXECUTE most SUBMIT ZPR_QM ... AND RETURN utasítással indítja a riportot saját belső munkamenetben. Átadja a stockot, mind a négy rádiógombot és az elrendezést: P_STOCK, P_MOD, P_DISP, P_REL, P_RELB, P_VARI. A külön VIA SELECTION-SCREEN nincs megadva: a fülön kitöltött indítóképernyőt nem kérjük be újra normál indításkor. A riport saját START-OF-SELECTION eseménye hívja a meglévő üzleti vezérlést, és a 2000-es képernyő így a ZPR_QM programé. Visszalépéskor a cockpit folytatódik. [SAP: SUBMIT](https://help.sap.com/docs/SUPPORT_CONTENT/abapfaq/3353526147.html).

A fülön továbbra is a ZPR_QM / 1100 indító-subscreen jelenik meg az elfogadott stockkal. A fül megnyitása nem indítja el a QM-műveletet. A kérésjelző az indítás előtt törlődik; Enter vagy fülváltás nem ismétli az előző indítást. A QM üzleti osztályimplementációja változatlan.

## A gomb felirata

A korábbi PUSHBUTTON közvetlenül a TEXT-101 szöveget használta. Hiányzó szövegszimbólum esetén ez üres lehet; a forrás bemásolása önmagában nem hozza létre a szövegkészletet. A gomb most a SELECTION-SCREEN által létrehozott PB_QRUN mezőt használja, amelyet az 1100-as képernyő OUTPUT eseménye tölt ki:

~~~abap
pb_qrun = 'QM indítása'(101).
~~~

Ez továbbra is fordítható, a 101-es szövegszimbólumhoz kötött literál. Ha a szimbólum hiányzik, a magyar alapfelirat jelenik meg. A 101-es textelem és fordításainak karbantartása továbbra is szükséges a többnyelvű használathoz; a TSV változatlan. [SAP: szövegszimbólum és alapértelmezett literál](https://help.sap.com/saphelp_scm700_ehp02/helpdata/en/e3/960a0eeb0711d194d100a0c94260a5/content.htm?no_cache=true).

## A bejelentett dump megerősítése

A felhasználó második ST22-részlete megerősítette az érintett hívást:

~~~text
Futási hiba: DYNPRO_NOT_FOUND
ABAP program: SAPLZPR_COCKPIT
393       CLEAR gv_reshow.
>>>       CALL SELECTION-SCREEN 2000.
395       IF gv_reshow EQ abap_false.
~~~

A hiba a QM-szerkesztő 2000-es képernyőjének hívásakor, a cockpit programkörnyezetében történik. Ez megfelel a fenti külső PERFORM-os programcsoport-hibának. A már elkészített SUBMIT-os javítás pontosan ezt a hívási utat váltja ki; a mostani pontosítás miatt további ABAP-módosítás nem szükséges. A javított változat sikeres SAP-futása még nem igazolt.

A CALL SELECTION-SCREEN 2000 utasítás a QM-szerkesztőben megmarad. A COCKPIT_EXECUTE adapterben kell kiváltani a közvetlen LCL_QM=>START hívást a diff szerinti SUBMIT-tal; ezután a riport saját START-OF-SELECTION eseményéből futó szerkesztő a ZPR_QM / 2000 képernyőt használja. A 2000-es selection screent nem kell a cockpit függvénycsoportjába átmásolni. A QM_CLOSE FORM csak az adapter beviteli állapotát törli, nem ez a hibás képernyőhívás.

## Ellenőrzés

A helyi ellenőrzési eredmények a munkacsomag HELYI-ELLENORZES_WIP.json, QM-PARSER_WIP.json és QM-DIFF-ELLENORZES_WIP.json fájljaiban találhatók. A parser és a patch-ellenőrzés nem helyettesíti az SAP-fordítást és a GUI-próbát.

SAP-ban ellenőrizendő: QM-fülön látható felirat és helyes stock; Indítás szerkesztés és megtekintés módban, saját 2000-es QM-képernyő és visszatérés; a két engedélyezési mód paraméterátadása megfelelő tesztstockkal; Enter/fülváltás nem indít újra; reset után új stock és alapértékek; önálló ZPR_QM működése. SAP-kapcsolati kísérlet nem történt.
