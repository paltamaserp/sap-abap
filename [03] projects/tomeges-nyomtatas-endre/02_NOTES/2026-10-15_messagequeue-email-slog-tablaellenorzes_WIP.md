# Messenger naplótábla cseréje

Státusz: WIP. Dátum: 2026-10-15. Helyi ellenőrzés; SAP-hívás nem történt.

A felhasználó a `ZPR_MESSAGE_QUERY` riportban a `ZPR_SLOG_EMAIL` → `ZPRT_EMAIL_SLOG` cserét kérte. A helyi főprogram neve `ZPR_MESSAGEQUEUE_QUERY`; külön `ZPR_MESSAGE_QUERY` forrás nem található.

## Mezőellenőrzés

Forrás: `01_SOURCES/ZPRT_NEW_TABLES.xlsx`, `ZPRT_EMAIL_SLOG!A1:I9`.

| Mező | Kulcs | Típus | Hossz |
|---|---|---|---|
| MANDT | X | CLNT | 3 |
| EXBILLDOCNO | X | CHAR | 20 |
| OPBEL | | CHAR | 12 |
| EMAIL_ADDRESS | | CHAR | 241 |
| TSTMP_EMAIL_SENT | | CHAR | 14 |
| SENDING_STATUS | | CHAR | 1 |
| TSTMP_SENDING_STATUS | | CHAR | 14 |
| ERROR_MESSAGE | | CHAR | 255 |

A korábbi táblából a `TSTMP_PRINT`, `GPART` és `VKONT` hiányzik. A munkalap OPBEL-megjegyzése szerint az OPBEL is opcionális lehet a tényleges táblában, ha egy megjelenítő a dokumentumnaplóból társítja; aktív megléte ezért nem igazolt.

## Érintett kód és függőségek

- `ZPR_MESSAGEQUEUE_QUERY.abap`: eredménysor, skalár típusok, SELECT/UPDATE, zárolási paraméterek, időbélyeg-alapú feldolgozás és konkurenciavizsgálat.
- `ZPR_MQ_PROXY.abap`: válasz- és ellenőrző sor típusa.
- `ZPR_MQ_REGISTER.abap`: teljes bemeneti sor, SELECT/INSERT, kötelező TSTMP_PRINT és ismételt regisztráció ellenőrzése, zárolás.
- `test/ZPR_MQ_TESTS.abap`: típusok, TSTMP_PRINT és GPART/VKONT megőrzési tesztje.
- `ZPRB_SLOG_EMAIL`: a régi DDIC-sortípusra mutathat. Helyi `STANDARD TABLE OF zprt_email_slog WITH DEFAULT KEY` típussal a függőség elhagyható.
- `EZPR_SLOG_EMAIL`: az új táblára mutató zárobjektum és generált interfész még tisztázandó. A régi `MODE_ZPR_SLOG_EMAIL` paramétert puszta táblanévcsere nem javítja.

## Előkészítés és nyitott kérdés

A név- és táblatípus-csere munkapéldányai a workspace `.tmp/messagequeue-table-20261015/candidate/` mappájában találhatók; az előző források a mellette levő `before/` mappában. Ezek nem bemásolható kész források: még a hiányzó mezőkre és régi zárobjektumra hivatkoznak. A `04_ASSETS/abap/` forrásai változatlanok.

**Döntés:** a hiányzó TSTMP_PRINT helyére nem választunk önkényesen létrehozási, státusz- vagy küldési időpontot, és nem kapcsoljuk ki csendben a hétnapos N-státuszt. A felhasználótól kértük a tényleges mezőlista megerősítését és a hétnapos határ kezdő időpontjának forrását. E válasz szükséges a működő átvezetés befejezéséhez.

SAP-fordítás, ATC és Unit-futtatás nem történt. A módosított munkapéldányokhoz parserellenőrzés sem történt; hiányzó mezőkre hivatkozás miatt ezek még nem tekinthetők fordíthatónak. Az aktív SAP-állapot nincs ellenőrizve; az ADT-kapcsolat a korábbi leállás miatt nem került használatra.
