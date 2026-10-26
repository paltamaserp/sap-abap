# Korábbi QA-példák

Forrás: a tomeges-nyomtatas-endre projekt helyi dokumentumai és a felhasználó 2026-10-13–18. közötti visszajelzései. Ezek részleges esetek, nem a céges ellenőrzési variáns teljes exportja. A nem közölt szabályazonosító, prioritás vagy variáns ismeretlen marad. Az itt leírt helyi javítások nem bizonyítják a teljes SAP QA-futtatás sikerét.

## Fordítható üzenetek

A ZPR_DOC_STATUS négy állandó MESSAGE-szövegére érkezett QA-jelzés. A helyi megoldás text-101–104 és külön szövegkarbantartási lista. Az állandó literál változóba emelése önmagában nem teszi fordíthatóvá. A forrás másolása nem hozza létre a text poolt; a hiányzó szövegszimbólum üres feliratot/hiányos üzenetet eredményezhet. A MESSAGE típusát és az utána futó vezérlést őrizd meg.

## Rendezett belső tábla

A BAL_T_LOGH típusú rendezett tábla APPEND műveletét helyileg INSERT ... INTO TABLE váltotta fel. A tényleges DDIC-típust mindig ellenőrizd. Egyedi kulcs esetén a duplikáció kezelése üzleti kérdés; ne vezess be automatikus elnyelést.

## SELECT / DELETE és index

A ZPR_TERTI kiválasztása az adott boríték és dokumentum összes kapcsolódó ragszámát/EXTNU sorát igényelte. A ragszámra tett új szűrés megváltoztatta volna az üzleti hatókört. A felhasználó 2026-10-15-én jelezte: az index segített. Az aktív index neve és teljes definíciója nincs visszaolvasva; a dokumentált MANDT + ENVELOPE_ID + EXBILLDOCNO indexjavaslatot ne jelentsd bizonyított aktív definíciónak. A helyi DELETE a már rendelkezésre álló teljes kulcsú rekordokat használja FROM TABLE művelettel.

## Hidden OK-Codes

A cockpitben a #STOCK / #CANCEL állapotokat belső funkciókódként kezelték. A helyi javítás külön GV_STOCK_CHANGED és GV_DM_CLOSE_CANCELLED logikai jelzőt használ; SAVE_OK csak a képernyő parancsát tárolja. A típustól eltérő belső állapotot ne rejtsd másik, új mesterséges parancskód mögé. A konkrét szabályazonosító és variáns nem áll rendelkezésre.

## Unchecked Classic Exception

A korábbi forrásvizsgálatban GUI FREE hívások után hiányzó visszatérésikód-kezelés merült fel. A saját felszabadítási sorrendet vizsgáld: egy korai RETURN miatt a következő kontroll takarítása elmaradhat. Az érintett hívás pontos klasszikus kivételeit és a visszatérési kódok kezelését ellenőrizd; ne vezess be általános kivételkezelést egy szűk QA-jelzés alapján.

## FINAL / Onapsis 2182 említés

A helyi ZPR_QM forrás kommentje Onapsis 2182 jelzéshez köti a FINAL használatát. Ez kommentből származó nyom, nem teljes nyers finding és nem az aktív eszközverzió bizonyítéka. Ne add automatikusan minden osztályhoz a FINAL-t: a tényleges szabályt és az öröklési/szerződéses követelményt előbb vizsgáld.

## A statikus ellenőrzés határa

A felhasználó ST22-részlete DYNPRO_NOT_FOUND hibát mutatott SAPLZPR_COCKPIT környezetben a CALL SELECTION-SCREEN 2000 utasításnál. A helyi javítás a közvetlen külső PERFORM-os QM-indítást SUBMIT ZPR_QM ... AND RETURN hívásra cseréli. Az ABAP-parser korábban sem bizonyította a helyes képernyő-programkörnyezetet. A működési próba és az aktív SAP-állapot külön igazolást igényel.

Az esetek részletei a workspace QA-ellenőrzőlistájában, a projekt 2026-10-17_cockpit-hidden-okcodes_WIP.md és 2026-10-18_cockpit-qm-dynpro-gomb-javitas_WIP.md dokumentumaiban találhatók. Az új javításnál mindig az aktuális forrás és tényleges találat az elsődleges.
