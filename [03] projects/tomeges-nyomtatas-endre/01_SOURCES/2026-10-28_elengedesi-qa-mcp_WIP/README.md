# Elengedési QA – MCP-felderítés

Dátum: 2026-10-28 · Státusz: WIP · Példakérelem: DHCK906030, a felhasználó által példaként elfogadva.

## Eredmény

Az MCP stdio-kapcsolat eszközleltára sikerült; az első rendszeradat-olvasás `network / EACCES` hibával megszakadt. SAP-konfiguráció, táblalista, kérelemadat és QA-eredmény nem érkezett. Az érintett kapcsolat további használata leállt. Új kísérlet csak kifejezett egyszeri felhasználói újrapróbálási kérésre engedett.

Ez nem HTTP 401-válasz és nem automatikus jóváhagyási elutasítás. Az EACCES pontos oka és az SAP-rendszer saját elérhetősége nincs megállapítva.

## Fájlok

| Fájl | Tartalom |
|---|---|
| [tools.json](tools.json) | A helyileg konfigurált MCP-szerver aktuális eszközleltára, nem SAP-adat |
| [request-qa-tables.json](request-qa-tables.json) | A GetSqlQuery SELECT-kérése: QA-kapcsolódású aktív DDIC-táblák felderítése |
| [STOP.json](STOP.json) | Első hibajelzés, 2026-10-28 12:49:43.244 UTC = 13:49:43.244 Europe/Budapest; network/EACCES |
| [2026-10-28_ellenorzes_WIP.json](2026-10-28_ellenorzes_WIP.json) | Helyi link-/számlálóellenőrzés és a gyűjtési fájlok SHA256-lenyomatai |

Kliens: [qa-readonly-2026-10-28.cjs](../../04_ASSETS/mcp-export/qa-readonly-2026-10-28.cjs). Kizárólag engedélyezési listán szereplő olvasásra készült; ebben a körben csak eszközleltár és egy SELECT-kísérlet történt. A meglévő fail-stop előtöltés az első hálózati/HTTP-hibánál leállította a kiszolgálót, megelőzve annak automatikus újrapróbálását. A STOP.json a kliens újbóli futtatását is tiltja. Titkot és SAP-kapcsolati paramétert nem másoltunk a csomagba.

[Fejlesztői szabályleírás helyi bizonyítékokból](../../03_DRAFTS/2026-10-28_elengedesi-qa-fejlesztoi-szabalyok_WIP.md).
