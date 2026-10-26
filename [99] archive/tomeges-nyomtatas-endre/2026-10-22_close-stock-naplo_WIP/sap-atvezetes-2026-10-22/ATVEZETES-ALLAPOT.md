# DHC/100 – átvezetés előtti összevetés, 2026-10-22

**SAP-módosítás és aktiválás még nem történt.**

## Frissítés – osztályengedély megérkezett, új munkamenet auto-review által elutasítva

A felhasználó kifejezetten engedélyezte a ZCL_PR_STOCK célzott módosítását és a négy osztálytextelemét is. Az objektumhatókör emiatt már nem akadály. Az alábbi, korábbi hatóköri döntés történeti megállapítás.

Az új ADT-MCP munkamenet indítását az automatikus jóváhagyási ellenőrzés **a folyamat elindítása előtt** elutasította. Indoka: a korábban engedélyezett egyszeri újrapróbálás már sikeres volt, de az a munkamenet lezárult; új munkamenethez külön kifejezett újrapróbálási kérést vár. Az elutasítás után nincs további kapcsolódási próbálkozás vagy kerülőút. Nem érkezett új SAP-válasz, így nincs új HTTP 401 vagy más hitelesítési/kapcsolati hiba.

A helyi, azonos két objektumra korlátozott MCP-kiegészítés és az átvezetési paraméterfájlok előkészítve: szövegek olvasása/ütközésellenőrzése/optimista zárolt mentése, kifejezetten aktív/inaktív szintaxisellenőrzés, célzott aktiválás. A telepített MCP-kiszolgáló és a hitelesítési konfiguráció nincs módosítva; a kiegészítés csak a folyamat memóriájában regisztrál szűk műveleteket. A helyi JavaScript szintaxisa rendben. SAP-oldali működésük az elutasított indítás miatt még nem ellenőrzött.

A felhasználó engedélyezte az ADT-kapcsolat egyszeri újrapróbálását és a ZPR_CLOSE_STOCK + 20 riporttextelem átvezetését a DHCK906297 kérelembe. A konfigurált, eredeti sap-abap-adt MCP-kiszolgálóval a DHC/100 kapcsolat sikeres: az aktív riport, az aktív ZCL_PR_STOCK és a transzport visszaolvasása HTTP 200 válaszokat adott. Hitelesítési/kapcsolati hiba és automatikus jóváhagyási elutasítás nem történt. A kapcsolat az első ilyen hibánál a kliens retry-ja előtt leállító védelemmel futott.

A DHCK906297 módosítható Workbench-kérelem. Módosítható feladata DHCK906298; a riport REPS-forrása és REPT-szövegkészlete már benne van. A kérelem más meglévő objektumaihoz nem nyúltunk.

## Miért nem alkalmazható változatlanul a korábbi diff?

A helyi FINAL-alapban a Lezárás gomb a RELEASE_STOCK → SEND_PRIORITY → közvetlen DCQMCompleted hívásra vezetett. Az aktív forrás viszont egy új RELEASE_STOCK_NEW ágat tartalmaz, és a gomb már erre van kötve. Ez a ZCL_PR_STOCK=>CLOSE_STOCK metódust hívja. A közvetlen összevetés 146 hozzáadott és 2 törölt sort mutat a helyi alaphoz képest; a változás az új ágból és annak gombbekötéséből áll.

A régi munkamásolat teljes feltöltése az aktív, új működést eltávolítaná. A régi diff egyszerű hozzáillesztése pedig a már nem használt RELEASE_STOCK/SEND_PRIORITY ágat naplózná; az aktív gombon a naplózás nem futna.

## Konkrét, áttekinthető javaslat

- [Aktív riporthoz illesztett forrás](ZPR_CLOSE_STOCK-DHC100-javaslat.abap) és [diff](ZPR_CLOSE_STOCK-DHC100-javaslat.diff). Megőrzi a RELEASE_STOCK_NEW gombbekötést és meglévő üzleti utasításait. A teljes stockból darabszámokat, a riportfolyamat és az osztályhívás határait, valamint a riport saját auditmentését naplózza.
- [Célzott osztályforrás-javaslat](ZCL_PR_STOCK-inspire-javaslat.abap) és [diff](ZCL_PR_STOCK-inspire-javaslat.diff). A tényleges DCQMCompleted proxyhívás előtt/után és a két kezelt hibánál mér időbélyeget; a meglévő osztálynaplóba ír. A payload, hibaágak és az üzleti LUW-utasítások megmaradnak.
- Az osztályhoz [4 további szövegszimbólum](ZCL_PR_STOCK-javaslat.texts.tsv) szükséges: 901–904. A riport 313/314 felirata az osztályhívás kezdetét/visszatérését jelenti; a pontos Inspire-hívási események az osztály saját naplójában jelennek meg.

**Döntés:** a pontos Inspire-hívási naplózás az aktív architektúrában a ZCL_PR_STOCK módosítását igényli. Ezt a felhasználó legutóbbi, csak a riportot és 20 riporttextelemét megnevező engedélye nem tartalmazza. Az osztálydiff kizárólag helyi, jóváhagyásra előkészített javaslat; a SAP-osztály nincs módosítva.

Ha a módosítás kizárólag a riportban marad, csak a teljes CLOSE_STOCK osztályhívás idejét lehet naplózni. Ebbe a prioritásablak és a class saját naplóablaka is beleszámít, ezért azt nem nevezzük hálózati Inspire-időtartamnak. A metódusnak nincs eredményt visszaadó paramétere, így a riport a visszatérő CL státusz alapján következtet, a jelenlegi aktív kóddal egyezően.

## Ellenőrzési eredmény és korlát

A beépített CheckProgram parancs a módosítás előtti objektumra „The REPORT/PROGRAM statement is missing, or the program type is INCLUDE.” hibát jelzett. Ez nem sikeres fordítás. A helyi MCP-kliens forrásának vizsgálata igazolta, hogy e parancs verzióparaméter nélkül az **inaktív** verziót ellenőrzi; a visszaolvasott aktív forrás REPORT-tal kezdődik, metaadata executableProgram. Az eredményből ezért nem állítjuk, hogy az aktív program deklarációja hibás. SAP-írás, új forrás ellenőrzése vagy aktiválása nem történt.

Az új helyi javaslatoknál a régi üzleti utasítások/payloadok/LUW-k megőrzését ellenőriztük. A SAP-szövegkészlet 301–323/901–904 azonosítóinak foglaltságát, az inaktív állapotot és az új változat SAP-szintaxisát az átvezetés előtt még ellenőrizni kell. A jelenlegi MCP eszközleltár nem kínál külön riport-/osztálytextelem-karbantartó parancsot; ennek támogatását is rendezni kell a tényleges írás előtt.

Az eredeti helyi FINAL-források változatlanok. Az aktív pillanatképek és a tisztán helyi javaslatok ebben az almappában vannak. A kapcsolat sikeres újrapróbálását rögzítettük; nincs új 401 vagy más kapcsolati hiba miatti ismételt leállás. Az MCP-munkamenet a CheckProgram eszközhibája után lezárult, nem hálózati/hitelesítési hiba miatt.


## Legfrissebb eredm?ny ? HTTP 500, le?ll?s az els? ?r?si l?p?sn?l

A felhaszn?l? ?j munkamenetre vonatkoz? kifejezett enged?lye ut?n az eredeti konfigur?lt MCP-kiszolg?l? elindult, ?s a DHC/100 kapcsolat sikeres volt. Az akt?v riport/oszt?ly v?ltozatlans?ga, a 20 + 4 sz?vegazonos?t? szabads?ga ?s az inakt?v objektumlista ?ress?ge ellen?rizve. Az akt?v forr?sok ?s a k?t ?j forr?sjel?lt kifejezetten akt?v verzi?ra k?rt SAP-szintaxisellen?rz?se is hibamentes.

Az els? m?dos?t?si l?p?sben a riportsz?vegek LOCK k?r?s?re **HTTP 500** ?rkezett, budapesti id? szerint **2026-10-22 14:43:36**-kor (UTC: 2026-10-22T12:43:36.526Z). A le?ll?t? v?delem a v?lasz ?rkez?sekor megszak?totta a folyamatot. Nem k?ldt?nk sz?veg-PUT, UpdateProgram, UpdateClass vagy aktiv?l?si k?r?st. Nincs automatikus ?jrapr?b?l?s vagy m?s SAP-eszk?zre v?lt?s. Ez val?s SAP HTTP 500 v?lasz volt; nem j?v?hagy?si elutas?t?s, ?s nem ?j HTTP 401.

A v?lasz t?rzs?t az azonnali le?ll?s miatt nem olvastuk tov?bb, ?gy a kiszolg?l?oldali ok ismeretlen. A z?rol?s ?llapota sem ellen?rizhet? ?jabb SAP-h?v?s n?lk?l. A szerveroldali napl?/ST22 a fenti id?pont ?s a ZPR_CLOSE_STOCK textelements LOCK k?r?s alapj?n vizsg?lhat?. ?j kapcsolati pr?b?hoz ?j kifejezett felhaszn?l?i k?r?s sz?ks?ges. R?szletes g?pi eredm?ny: deployment-result.json.
