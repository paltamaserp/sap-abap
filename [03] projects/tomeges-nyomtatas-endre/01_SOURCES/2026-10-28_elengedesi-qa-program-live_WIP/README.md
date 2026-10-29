# Élő SAP-programfelderítés

2026-10-28 · WIP · További felderítés leállítva.

## Igazolt friss eredmények

1. A [16:08:41-kor sikerült MCP/SAP-elérési próba](../2026-10-28_sap-adt-access-retry-02_WIP/README.md) után GetSqlQuery olvasással a TADIR repository-leltárból 300 sor érkezett vissza, a válasz 5878 teljes találatot jelzett. Ez részleges leltár, nem teljes objektumlista. A /VFORGE/ névtér objektumai és a CTS_REQUEST_CHECK definíciója szerepelnek benne; ez önmagában még nem igazolja az aktív elengedési bekötést.
2. Az ellenőrző osztályt nevek/leírások alapján kereső következő SELECT **2026-10-28 16:10:55.859 Europe/Budapest** időpontban HTTP 400 választ kapott. A fail-stop előtöltés a válasz törzsének feldolgozása előtt leállította a kiszolgálót. A pontos alkalmazásoldali hibaüzenet nincs meg; ezért a hiba okát nem állapítjuk meg.

Ez HTTP 400, nem a korábbi EACCES vagy MCP-időtúllépés megismétlődése, és nem HTTP 401. Automatikus jóváhagyási elutasítás nem történt. A HTTP-válasz és a korábbi érvényes SAP-adatolvasás igazolja, hogy a kiszolgáló elérhető volt. A felderítés a 400 után leállt; újabb SAP-hívás nem történt. Ezt önmagában nem minősítjük hitelesítési vagy hálózati hibának, de a kliens STOP-rekordját nem kerültük meg.

## Fájlok

- [Sikeres repository-felderítés teljes MCP-válasza](checker-repository-discovery.json)
- [A sikeres kérés](request-checker-discovery.json)
- [A HTTP 400-at kiváltó osztálykereső kérés](request-checker-classes.json)
- [HTTP 400 leállási rekord](STOP.json)
- [Az MCP-eszközök leltára](tools.json)

Az ellenőrző program forrása és a tényleges elengedési konfiguráció nincs lekérve; a PDF programból történő igazolása továbbra is hiányzik. SAP-írás és QA-futtatás nem történt.
