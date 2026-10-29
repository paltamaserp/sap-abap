# ZPT032_FIX_TTYP_MCP – működés és eredet

Dátum: 2026-10-28. Státusz: WIP; a technikai létrehozó igazolt, a létrehozó kliens és a megrendelés előzménye nem ismert.

## Működés

A ma SAP ADT MCP-vel visszaolvasott aktív program egy paraméter nélküli DDIC-javító segédreport. Futtatáskor a rögzített `ZEPTT_LOCK_INVOICE` táblatípus definícióját írja, majd aktiválja:

- Sortípus: `ZEPTS_LOCK_INVOICE` struktúra.
- Hozzáférés: standard belső tábla (`ACCESSMODE = T`).
- Kulcs: alapértelmezett, nem egyedi (`KEYDEF = D`, `KEYKIND = N`).
- Leírás: `PT032 card payment invoice locks`; nyelv: a futtató `SY-LANGU` értéke.
- Mentés: `DDIF_TTYP_PUT`, majd `COMMIT WORK AND WAIT`.
- Aktiválás: `DDIF_TTYP_ACTIVATE`.
- Mentési hiba, aktiválási kivétel vagy 4-nél nagyobb aktiválási visszatérési kód esetén hibaszöveget ír és kilép; egyébként sikerüzenetet ír.

A forrás nem tartalmaz tesztüzemmódot vagy megerősítést: a report végrehajtása valódi DDIC-módosítást indít. Üzleti számlaadatot vagy zárolási rekordot közvetlenül nem kezel. A program neve és kódja javítási szándékot jelez; korábbi hibát vagy korábbi sikeres futtatást önmagában nem bizonyít.

## Igazolt eredetadatok

| Bizonyíték | Friss SAP-eredmény |
|---|---|
| ADT programleírás | `PT032 TTYP fix helper` |
| ADT csomag | `$TMP` |
| ADT eredeti rendszer | `DHC` |
| ADT felelős / utolsó módosító | `X0134` |
| ADT létrehozási dátum | 2026-06-15 |
| ADT utolsó módosítás | 2026-06-15 14:23:05 UTC, azaz 16:23:05 Budapest |
| TRDIR CNAM / CDAT | `X0134` / `20260615` |
| TRDIR UNAM / UDAT | `X0134` / `20260615` |
| TRDIR SUBC | `1` – futtatható report |
| TADIR AUTHOR / DEVCLASS / SRCSYSTEM | `X0134` / `$TMP` / `DHC` |
| E071, pontos programnév | Nincs találat |

Az adatok alapján helyi, DHC eredetű segédobjektumként, az X0134 technikai felhasználó alatt hozták létre. A `$TMP` besorolás és a hiányzó E071-bejegyzés a helyi létrehozást támasztja alá; normál transzportos bekerülésre nincs talált bizonyíték. Ezek az adatok nem teljes történeti importauditok.

A javított `ZEPTT_LOCK_INVOICE` táblatípusnak van E071-nyoma: `DHCK901205`, `DHCK901206`, `DHC_P00002`, `DHCK901201`, mind `R3TR TTYP` bejegyzés. Ez a táblatípus transzportnyoma, nem a segédreporté.

Az `_MCP` név MCP-vel végzett fejlesztésre utalhat, de nem igazolja, melyik kliens vagy asszisztens hozta létre, ki kezdeményezte, illetve milyen felhasználói felhatalmazással. A munkatérben nem találtunk a pontos programnévre fájlt vagy előzménynaplót; a helyi Codex/Claude munkamenetnaplók keresése csak a jelen vizsgálatot találta meg. Az X0134 mögötti személyt nem azonosítottuk.

## Végrehajtott ellenőrzések

- `GetProgram` és `ReadProgram`: aktív forrás sikeresen olvasva; ADT-metaadatok sikeresen olvasva.
- `GetSqlQuery`: TRDIR, TADIR és E071 célzott SELECT-jei sikeresek.
- SAP-módosítás, aktiválás és programfuttatás nem történt. A javítóreport korábbi futtatása és a táblatípus mai definíciója nincs ellenőrizve.
- Ez olvasási vizsgálat volt; ABAP-objektum létrehozása/módosítása nem történt, így automatikus módosítás utáni QA-menetet nem indítottunk.

### A használt SQL-lekérdezések

```sql
SELECT name, cnam, cdat, unam, udat, subc
  FROM trdir WHERE name = 'ZPT032_FIX_TTYP_MCP'

SELECT pgmid, object, obj_name, devclass, srcsystem, author
  FROM tadir WHERE pgmid = 'R3TR' AND object = 'PROG'
  AND obj_name = 'ZPT032_FIX_TTYP_MCP'

SELECT trkorr, pgmid, object, obj_name
  FROM e071 WHERE obj_name = 'ZPT032_FIX_TTYP_MCP'
  OR obj_name = 'ZEPTT_LOCK_INVOICE'
```
