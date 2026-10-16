# Messenger e-mailstátusz-lekérdezés DHC-ban

Státusz: WIP. A felhasználó megerősítette, hogy a `ZPR_SLOG_EMAIL` transzparens tábla létezik, és a régi `ZPRT_SLOG_EMAIL` megfelelőjét `ZPRB_SLOG_EMAIL` táblatípusként létrehozta. A helyi MESSAGEQUEUE-források ezekre átvezetve. Ebben a módosítási körben SAP-hívás, aktiválás és tesztfuttatás nem történt; az ADT-kapcsolat a korábbi HTTP 422 után leállítva maradt.

## A módosítások

- Adatbázistábla és sortípus: minden végrehajtható hivatkozás `ZPR_SLOG_EMAIL`-re került. A főprogram `TY_EMAIL_TAB` típusa `ZPRB_SLOG_EMAIL`, ebből készül a függő és a proxyeredmény-tábla.
- Zárolás: `ENQUEUE_EZPR_SLOG_EMAIL` / `DEQUEUE_EZPR_SLOG_EMAIL`, `MODE_ZPR_SLOG_EMAIL`, `MANDT`, `EXBILLDOCNO`, `_SCOPE = 1`. A nevek és kulcsparaméterek a régi forrásból származnak; aktív DHC-zárobjektum-visszaolvasás még nem történt.
- Időmezők: a CHAR 14 értékeket `YYYYMMDDhhmmss` formátumként ellenőrizzük, majd numerikus TIMESTAMP-re konvertáljuk. Az összehasonlítás ezen történik; a helyi státuszidőpont mentéskor ismét 14 karakter. Üres/hibás nyomtatási időpont nem eredményez helyi N-státuszt; hibás proxy-időpontnál a válasz elutasított.
- Hibaüzenet: a tábla `ERROR_MESSAGE` mezőjére típusozva, CHAR255 hosszal. A proxyadapter 255-nél hosszabb szöveget elutasít, így nincs csendes csonkolás.
- A teljes eredeti naplósor megmarad az ALV-ban és az összevetésben, beleértve `OPBEL`, `GPART`, `VKONT`, `EMAIL_ADDRESS` mezőit. Az UPDATE továbbra is csak a négy státuszmezőt írja.
- Az opcionális regisztrációs rutin most teljes `ZPR_SLOG_EMAIL` sort fogad. Az üzleti mezők is bekerülnek az INSERT-be; nem csak dokumentum és időbélyeg.
- A korábbi új `ZPRT_MQ_EMAIL.table` specifikáció eltávolítva. Új naplótábla, új MQ-domének/adatelemek vagy `EZPRT_MQ_EMAIL` zár létrehozása nem része a csomagnak.
- A Unit-forrás hatról kilenc tesztre bővült: CHAR 14 oda-vissza konverzió, hibás szöveges időpontok és az üzleti mezők megőrzése is ellenőrizhető.

## Fájlok és aktiválási sorrend

1. Meglévő `ZPR_SLOG_EMAIL` tábla, a létrehozott `ZPRB_SLOG_EMAIL` táblatípus, valamint az `EZPR_SLOG_EMAIL` zárobjektum és generált FM-ek legyenek aktívak.
2. A `ZPRB_SLOG_EMAIL` sortípusa `ZPR_SLOG_EMAIL`, táblakategóriája **STANDARD TABLE** legyen. A kód APPEND/SORT/BINARY SEARCH műveleteket használ. A felhasználó a létrehozást jelezte; a definíció aktív visszaolvasása nem történt.
3. Generált Inspire consumer proxy, request/response típusok és logikai port: lásd az alábbi leképezést.
4. Az include-ok teljes forrását vedd fel: [ZPR_MQ_PROXY](ZPR_MQ_PROXY.abap), [ZPR_MQ_DISPLAY](ZPR_MQ_DISPLAY.abap), [ZPR_MQ_TESTS](test/ZPR_MQ_TESTS.abap), majd a [ZPR_MESSAGEQUEUE_QUERY](ZPR_MESSAGEQUEUE_QUERY.abap) főprogrammal együtt ellenőrizd és aktiváld őket. Az include-ok a főprogramban definiált típusokat/osztályokat használják; nem önálló programok.
5. A 0100 képernyő, GUI-státusz, cím és tranzakció aktiválása.

A csomagot/transzportot a meglévő DHC fejlesztési rend szerint válaszd. A QU5 források és a stock/DC riportok ebben a feladatban nem módosultak.

## Meglévő tábladefiníció és adatértelmezés

A korábbi sikeres MCP-lekérés szerint a tábla kulcsa `MANDT + EXBILLDOCNO`; dokumentumazonosítója CHAR 20, státusza CHAR 1, mindhárom időmezője CHAR 14, hibaüzenete CHAR255. A teljes visszakapott definíció a [MCP-ellenőrzési jegyzetben](../../02_NOTES/2026-10-13_messagequeue-mcp-ellenorzes_WIP.md) szerepel. A korábbi válasz célrendszer-azonossága nem volt igazolva; a mostani helyi átvezetést a felhasználó meglévő táblára vonatkozó utasítása engedélyezte.

Az időmezők értelmezése a jelenlegi kódban UTC `YYYYMMDDhhmmss`. A CHAR 14 DDIC-típus önmagában nem igazolja az időzónát; a tényleges naplófeltöltő és a szolgáltatás szerződésében ezt még ellenőrizni kell. Ha helyi időt tárolnak, az időzónakonverziót ahhoz kell igazítani. A meglévő `TSTMP_PRINT` mező üzleti jelentését nem írjuk át az átvezetés során.

A tábla meglévő feltöltését használjuk. A `ZPR_MQ_REGISTER` csak akkor szükséges, ha a DHC küldési folyamatból hiányzik a naplóregisztráció. A dokumentumazonosítót változtatás nélkül küldjük az Inspire-nek; nincs ALPHA-konverzió vagy nullalevágás.

## Proxy és logikai port

**Új MCP-visszaolvasás (2026-10-13):** a kapcsolt rendszerben az aktív consumer proxy neve `ZPR_CO_EON_QUERY_MESSENGER_STA`; INPUT típusa `ZPR_EON_QUERY_MESSENGER_STATU2`, OUTPUT típusa `ZPR_EON_QUERY_MESSENGER_STATU1`. A 100-as mandantban négy port-hozzárendelés szerepel: `LOGPORT_QMS_SBOX`, `LOGPORT_QMS_DEV`, `LOGPORT_QMS_QA`, `LOGPORT_QMS_UAT`. A helyi adapter nevei még nincsenek átvezetve a most igazolt nevekre; a request/response komponensek ellenőrzése és a célkörnyezet kiválasztása még szükséges. [MCP-eredmény és host-hozzárendelések](../../02_NOTES/2026-10-13_messagequeue-logikai-port-mcp_WIP.md).

A táblamódosítás nem igazolja a proxy/típusok meglétét. A `ZPR_MQ_PROXY` include alábbi nevei továbbra is tervezett DHC-nevek; a valóban generált nevekhez egy helyen kell illeszteni őket.

| Régi QU5-elem | Az adapterben szereplő DHC-név |
|---|---|
| `ZEBF_PR_CO_EON_QUERY_MESSENGER` | `ZPR_CO_QUERY_MESSENGER` |
| Request `ZEBF_PR_EON_QUERY_MESSENGER_S2` | `ZPR_QUERY_MESSENGER_REQUEST` |
| Response `ZEBF_PR_EON_QUERY_MESSENGER_S1` | `ZPR_QUERY_MESSENGER_RESPONSE` |
| `EON_QUERY_MESSENGER_STATUS` | Azonos metódusnév, INPUT/OUTPUT paraméterekkel |
| Fix `LOGPORT` | `P_LPORT` paraméter, rendszerfüggő alapérték: DHC → DEV, QHC → QA, PHC → UAT |

A valódi WSDL/ESR-definíció alapján generált requestben `SAP_SYSTEM`, `SAP_MANDANT`, `EXBILLDOCNOS-EXBILLDOCNO[]`; a response-ban `PARAMETERS-SUCCESS`, `PARAMETERS-INFO`, `PARAMETERS-DOCS-DOC[]` szükséges. A DOC sor mezői: `EXBILLDOCNO`, `SENDING_STATUS`, `TSTMP_SENDING_STATUS`, `ERROR_MESSAGE`, `TSTMP_EMAIL_SENT`.

A SUCCESS jelenlegi ellenőrzése csak `ABAP_TRUE` (`X`) értéket fogad el. Eltérő generált igaz/hamis reprezentáció esetén explicit leképezés kell. Az adapter a két visszakapott időpontnál pontosan 14 számjegyű, érvényes időértéket vár; ISO 8601 vagy törtmásodperces érték esetén a valódi proxyadapterben további konverzió szükséges. Az üres időmező megengedett.

SOAMANAGER-ben a tényleges lekérdező proxy saját logikai portját használd, majd a `P_LPORT` értékét ehhez állítsd. Ha proxy hiányzik, a valódi szolgáltatás WSDL-jéből kell generálni; a helyi forrás nem helyettesíti azt. Hitelesítési adat nem kerül a kódba.

## A régi riport rendszerfüggő portkezelése

A megadott QU5 ZBC_PR_MESSAGEQUEUE_CLASSES forrás minden futásban fix `LOGPORT` nevet ad át a consumer proxy konstruktorának. Nincs SY-SYSID szerinti CASE vagy más portnév-választás. A request `SAP_SYSTEM = SY-SYSID`, `SAP_MANDANT = SY-MANDT` mezői a hívó rendszer és mandant azonosítására szolgálnak; nem ezek választják ki az ABAP oldali portnevet.

A kód alapján az adott rendszer/mandant runtime LOGPORT-konfigurációjának kellett meghatároznia a szolgáltatás végpontját. Egy logikai port a consumer rendszer futásidejű végpontkonfigurációjára hivatkozik: [SAP fogyasztóiproxy-konfiguráció](https://help.sap.com/docs/SAP_NETWEAVER_700/12aa7f056c531014aa5bca7aee037e55/9ec7a3591dc74a679bbc9716354e42af.html). A régi külön rendszerek tényleges SOAMANAGER-beállításait nem olvastuk vissza, ezért konkrét régi DEV/QA/éles végpontmegfeleltetés nincs igazolva.

A most kapcsolt rendszerben ugyanahhoz az új proxyhoz négy külön nevű port-hozzárendelés található; a P_LPORT ezeket választhatja ki. Ez a helyi átültetésben bevezetett paraméterezés, nem a régi riport működése.

## Rendszerfüggő P_LPORT alapérték

A felhasználó kifejezetten megadta a megfeleltetést, a helyi főprogramba átvezetve:

| SY-SYSID | P_LPORT alapértéke |
|---|---|
| DHC | `LOGPORT_QMS_DEV` |
| QHC | `LOGPORT_QMS_QA` |
| PHC | `LOGPORT_QMS_UAT` |
| Más rendszer | Üres, a kötelező paramétert kézzel/variánssal kell megadni |

A LOGPORT_QMS_SBOX-hoz nem adott rendszerazonosítót a felhasználó, ezért nincs automatikus sandbox-hozzárendelés. A PHC → UAT beállítás kifejezett felhasználói döntés, nem a PHC névből kikövetkeztetett port.

A mechanizmus: a fix DEFAULT kiegészítés eltávolítva a PARAMETERS deklarációból, és a főprogram meglévő INITIALIZATION eseményében CASE SY-SYSID tölti ki P_LPORT-ot. Így kezdőérték képződik, amelyet a szelekciós képernyő vagy egy variáns felülírhat; ez nem kényszerített környezetválasztás. Az INITIALIZATION szerepét a [SAP leírás](https://help.sap.com/saphelp_autoid2007/helpdata/en/9f/db9a2135c111d1829f0000e829fbfe/content.htm) részletezi.

A CASE blokk a meglévő INITIALIZATION esemény elejére került, a jogosultságellenőrzés megmaradt. A portneveknek az adott célrendszer és mandant tényleges proxykonfigurációjában is létezniük kell; egy kapcsolt rendszerben kiolvasott névlista ezt nem bizonyítja minden más rendszerre. Ebben a módosítási körben nem történt új SAP-hívás vagy aktiválás.

## Képernyő és tranzakció

- Program: `ZPR_MESSAGEQUEUE_QUERY`, végrehajtható program; szelekciós szöveg `P_LPORT`: „Messenger logikai port”.
- 0100: normál képernyő, következő képernyő 0; Custom Control `ALV_CONTAINER_01`; OK-mező pontosan `GV_OKCODE_0100`.
- Flow logic: [másolható forrás](ZPR_MESSAGEQUEUE_QUERY_0100.flow.abap), a PROCESS részt illeszd be SE51-be.
- SE41 `STATUS_0100`: `BACK`, `EXIT`, `CANC`, mindhárom E funkciótípussal. Mentés az ALV saját SAVE gombjával.
- SE41 `QUEUE_TITLE`: „Messenger e-mailstátuszok”.
- SE93 `ZPR_MQ_QUERY`: program és szelekciós képernyő, `ZPR_MESSAGEQUEUE_QUERY`, 1000. Futtatási jogosultság: `S_TCODE / ZPR_MQ_QUERY`, batch felhasználónak is.

## FORM QUERY_MESSENGER does not exist

A felhasználó ezt a fordítási hibát jelezte a ZPR_MQ_TESTS ellenőrzésekor; a hibasor a ZPR_MESSAGEQUEUE_QUERY főprogramra mutat. A helyi főprogram PERFORM QUERY_MESSENGER hívását a ZPR_MQ_PROXY include FORM QUERY_MESSENGER rutinja szolgálja ki; a tesztinclude nem definiálja és nem hívja ezt a rutint.

1. SE38/SE80-ban ellenőrizd, hogy a főprogram tartalmazza az `INCLUDE zpr_mq_proxy.` sort. A helyi forrásban ez a típus-/osztálydefiníciók után, az INITIALIZATION előtt szerepel.
2. A `ZPR_MQ_PROXY` legyen include típusú program, a mellékelt teljes forrással. A rutin kezdete `FORM query_messenger USING it_docnos TYPE ty_docno_tab`, folytatása `CHANGING ct_response TYPE ty_email_tab cv_ok TYPE abap_bool cv_error TYPE string.`, lezárása `ENDFORM.`. Üres include vagy eltérő forrás nem biztosítja ezt a rutint.
3. A főprogramot és include-jait közös programkontextusban ellenőrizd/aktiváld. Ha a proxyinclude-ban is van hiba, először annak legelső szintaxishibáját kell javítani; a még nem egyeztetett generált proxy/típusnevek önálló akadályok lehetnek. A tesztinclude eltávolítása nem szünteti meg a főprogram proxyfüggőségét.

A helyi hívás és FORM definíció neve/szignatúrája egyezik. SAP-oldali visszaolvasás nélkül a konkrét hiány vagy elsődleges szintaxishiba nincs igazolva; a végrehajtható kódot ezért nem helyettesítettük üres rutinnal.

## Opcionális küldő oldali regisztráció

Ha a meglévő küldő már tölti a `ZPR_SLOG_EMAIL` táblát, ide nem kell új bekötés. Szükség esetén a küldőbe illeszthető [ZPR_MQ_REGISTER](ZPR_MQ_REGISTER.abap) teljes naplósort kap; az összes üzleti mezőt a küldő tölti ki.

```abap
DATA: ls_email TYPE zpr_slog_email,
      lv_ok TYPE abap_bool,
      lv_error TYPE string,
      lv_lock_held TYPE abap_bool.

" Fill EXBILLDOCNO, TSTMP_PRINT (CHAR 14), OPBEL, GPART,
" VKONT and EMAIL_ADDRESS from the actual handoff context.
" Leave SENDING_STATUS initial for a new pending handoff.
PERFORM mq_register USING ls_email
  CHANGING lv_ok lv_error lv_lock_held.

" Handle LV_OK / LV_ERROR in the producer's existing logic.
" Close its existing LUW with the normal COMMIT or ROLLBACK.
PERFORM mq_register_unlock USING ls_email-exbilldocno
  CHANGING lv_lock_held.
```

A rutin nem commitol vagy rollbackel a hívó helyett. Siker esetén a zárat a küldő LUW-lezárásáig tartja; minden kilépési/kivételágban a lezárás után kell feloldani. Új rekordnál a teljes átadott sor kerül INSERT-be, az aktuális mandanttal. Azonos dokumentum/időbélyeg ismételt regisztrációja változatlanul hagyja a meglévő sort, eltérő időpont hibát ad. Nem törli a már meglévő küldés státuszát, és nem indít új e-mailküldést.

## Működés és ellenőrzés

- Sikeres proxyválasz után háttérben automatikus, párbeszédben ALV-gombos mentés. Mentés nélkül kilépve nincs adatváltozás. Hibás port/proxy/application fault vagy sikertelen üzleti válasz esetén nincs mentés és nincs N-jelölés.
- Sikeres, akár üres válasz mellett hét teljes UTC-nap után lesz N a továbbra is státusz nélküli rekord. Az üres/hibás TSTMP_PRINT függő marad. A valódi visszakapott státusz elsőbbséget élvez.
- Zár alatti újraolvasás és teljes eredeti sorösszevetés előzi meg a mentést. Kizárólag SENDING_STATUS, TSTMP_SENDING_STATUS, ERROR_MESSAGE, TSTMP_EMAIL_SENT frissül. Nincs whole-row MODIFY vagy törölt rekordot visszahozó INSERT a lekérdezőben.
- Dokumentumonként commit; részleges siker lehetséges. A zár commit/rollback után oldódik. Mentési oszlopok: S = mentve, C = közben megváltozott/törölt, E = hiba. Az ALV rendezése mellett is dokumentumkulcs szerint ellenőrzünk.
- Zárhiba után a mentési gomb külön helyi újrapróbálást enged, új proxyhívás nélkül. Közben változott sorhoz új riportfutás kell. A spool mentett/kihagyott/hibás összesítése jelzi az eredményt; a job Finished állapota önmagában nem jelent teljes üzleti sikert.

A korábbi [SAP COMMIT WORK](https://help.sap.com/doc/abapdocu_752_index_htm/7.52/en-US/abapcommit.htm), [zárolási scope](https://help.sap.com/saphelp_snc700_ehp01/helpdata/en/47/daadf638793c85e10000000a42189c/content.htm) és [UTC-konverziós dokumentáció](https://help.sap.com/doc/abapdocu_751_index_htm/7.51/en-us/abapconvert_time-stamp.htm) alapján megtartottuk a commit/feloldás sorrendet. Commit utáni hiba esetén a későbbi rollback nem vonja vissza a már committed közvetlen SQL-t; a tényleges sorállapot ellenőrizendő.

SAP-ban szükséges: DDIC/table type/lock/proxy/gui aktiválás és szintaxisellenőrzés; ATC; a kilenc ABAP Unit-teszt futtatása. Funkcionális esetek: CHAR 14 formátum/időzóna, 255 karakteres szöveghatár, hibás/üres/duplikált proxyválasz, ALV-rendezés, mentés nélküli kilépés, zárütközés, közben módosított/törölt sor és üzleti mezők változatlansága. A valódi szolgáltatáshívást kijelölt tesztvégponton végezd. SM36-ban a tesztelt portértéket tartalmazó variánst használd.

Helyi ellenőrzési eredmény: [jegyzet](../../02_NOTES/2026-10-13_messagequeue-dhc-helyi-ellenorzes_WIP.md). SAP quality gate nem futott, ezért WIP marad.
