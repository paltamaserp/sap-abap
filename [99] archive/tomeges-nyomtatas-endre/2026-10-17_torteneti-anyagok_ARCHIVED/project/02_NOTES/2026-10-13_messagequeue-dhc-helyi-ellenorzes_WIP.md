# Messenger DHC: helyi ellenőrzés

Státusz: WIP. Dátum: 2026-10-13. Aktuális állapot: a felhasználó utasítására a meglévő `ZPR_SLOG_EMAIL` tábla és a létrehozott `ZPRB_SLOG_EMAIL` táblatípus használata. A csomag és a változások a [bemásolási útmutatóban](<../../../../../[03] projects/tomeges-nyomtatas-endre/04_ASSETS/abap/info.md/2026-10-13_messagequeue-dhc-bemasolas_WIP.md>) szerepelnek.

## Helyi ellenőrzés

- Az öt ABAP-fájl (főprogram, proxy-, ALV-, Unit-, regisztrációs include) blokknyitásai/zárásai párosítva. A szöveges ellenőrző kihagyja a sztringeket és kommenteket; ez nem teljes ABAP-parser vagy SAP-fordítás.
- A főprogram három saját include-ja létezik, a kilenc FORM-hivatkozásnak megvan a célrutinja, a 0100 flow logic három MODULE-hívása definiált.
- A közvetlen `ZPR_SLOG_EMAIL` mezőhivatkozások a korábbi MCP-ben visszakapott tizenegy mezős aktív definícióval egyeznek. A főprogram `TY_EMAIL_TAB` típusa `ZPRB_SLOG_EMAIL`. E táblatípust a felhasználó létrehozta; STANDARD TABLE OF ZPR_SLOG_EMAIL definícióját aktívan nem olvastuk vissza.
- Nincs végrehajtható `ZPRT_MQ_EMAIL`, `EZPRT_MQ_EMAIL` vagy régi `ZPRT_SLOG_EMAIL` hivatkozás a MESSAGEQUEUE-fájlokban. A régi új-táblaspecifikáció törölve, az útmutató hivatkozásai frissítve.
- A CHAR 14 időmezőkre nem használunk közvetlen GET TIME STAMP / CONVERT TIME STAMP műveletet: a konverzió numerikus TIMESTAMP segédváltozóval történik. A szöveges bevitel pontosan 14 számjegy és érvényes dátum/idő kell legyen; visszaformázás DATE + TIME összefűzéssel, pontosan 14 karakterre.
- A proxy hibaüzenetének ellenőrzési határa 255 karakter; ennél hosszabb érték elutasított. A tábla négy státuszmezőjét frissítő UPDATE megmaradt, egész rekordos MODIFY/upsert nincs.
- A zárhívások a régi forrásban látott ENQUEUE_EZPR_SLOG_EMAIL / DEQUEUE_EZPR_SLOG_EMAIL neveket és MODE_ZPR_SLOG_EMAIL paramétert használják. A scope és commit utáni feloldás megmaradt.
- A regisztrációs rutin teljes ZPR_SLOG_EMAIL sort fogad. Az INSERT az üzleti mezőket is átveszi; a meglévő sor státuszát nem módosítja. Nem commitol/rollbackel a hívó helyett, és meglévő naplófeltöltés mellett nincs rá új bekötési szükség.
- A források UTF-8-ként olvashatók, nincs helyettesítő karakter, 255-nél hosszabb ABAP-sor vagy sorvégi whitespace. A dokumentáció relatív hivatkozásai létező fájlokra mutatnak.

## Vezérlési ágak forrásvizsgálata

| Feltétel | Eredmény |
|---|---|
| Sikeres valódi státuszválasz | A teljes eredeti sor üzleti mezői megmaradnak, négy státuszmező frissül az eredményben |
| Státusz nélkül maradt, hét napnál frissebb rekord | Nem kerül a mentési listába |
| Sikeres lekérdezés mellett hét teljes UTC-napnál régebbi hiányzó státusz | N és 14 karakteres helyi státuszidőpont kerül a mentési listába |
| Üres, nem 14 számjegyű vagy érvénytelen TSTMP_PRINT | Függő marad, nincs helyi N |
| Hibás proxy-időbélyeg vagy 255-nél hosszabb hibaüzenet | Teljes válasz elutasítása, nincs mentés |
| Proxy/port/application fault vagy sikertelen üzleti válasz | Nincs adatmentés és nincs N-jelölés |
| ALV-kilépés mentés nélkül | Adatbázis változatlan |
| Zárütközés | E mentési jelzés, nincs UPDATE |
| Közben módosult/törölt naplósor | C jelzés, nincs felülírás vagy visszalétrehozás |
| Mentés sikeres | Dokumentumonként commit, utána zárfeloldás és S jelzés |
| Ismételt azonos regisztráció | Meglévő teljes naplósor változatlan; eltérő időpontnál hiba |

Az ágakat forrásból ellenőriztük, SAP-ban nem futottak.

## Unit-forrás és korlátok

A ZPR_MQ_TESTS kilenc tesztjének forrása készült el. A korábbi hat eset mellett CHAR 14 oda-vissza konverzió, hibás számjegy/hossz/dátum és az üzleti mezők megőrzése is szerepel. Az üzleti mezők tesztjében a proxyeredmény csak dokumentumazonosítót és státuszt ad; OPBEL, GPART, VKONT és EMAIL_ADDRESS kizárólag az eredeti naplósorból maradhat meg. Nincs adatbázis-, zár- vagy hálózati hívásuk. Futtatásuk nem történt.

Az időértékek formátumának és UTC-értelmezésének üzleti igazolása, a ZPRB_SLOG_EMAIL tényleges sortípusa/táblakategóriája, az EZPR_SLOG_EMAIL aktív definíciója, a valódi DHC consumer proxy/request/response és a SOAMANAGER port még nem olvasott vissza. A ZPR_MQ_PROXY proxynevei továbbra is tervezett nevek, a valóban generált objektumokhoz illesztendők.

A korábbi MCP-sikerek és a HTTP 422-es leállás a [MCP-jegyzetben](2026-10-13_messagequeue-mcp-ellenorzes_WIP.md) szerepelnek. A jelen módosítás során új SAP-hívás nem történt. SAP-szintaxisellenőrzés, ATC, ABAP Unit és funkcionális teszt nem futott; a helyi szerkezeti ellenőrzés ezeket nem helyettesíti. A stock/DC kódhoz nem nyúltunk.
