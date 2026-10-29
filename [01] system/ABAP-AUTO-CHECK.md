# ABAP objektumok automatikus utóellenőrzése

Rögzítve: **2026-10-27**, a felhasználó kérésére. A munkatérben az asszisztens által létrehozott vagy módosított SAP ABAP-objektumokra vonatkozik. A végrehajtási leírás a [review-skillben](../.claude/skills/abap-code-review/SKILL.md) található.

## Indítás és hatókör

- **MCP-s objektumlétrehozás után kötelező az egységteszt-futtatás (ABAP Unit), külön kérés nélkül** — a felhasználó 2026-10-28-i megerősítése alapján. A tesztkód elkészítése nem helyettesíti a futtatást; az eredményt objektumonként jelentsd és mentsd. Hiányzó teszt vagy akadályozott futtatás „nem futott”, az ok megadásával. A logika nélküli objektumok alább meghatározott, indokolt nem alkalmazhatósága és a kapcsolati leállási szabály továbbra is érvényes.
- Létrehozás, módosítás és aktiválás után külön kérés nélkül következik az ellenőrzés, még az átadás előtt. Összetartozó objektumoknál az utolsó mentés után, a teljes megváltozott objektumkörre egyszer fusson. Új javítás után az érintett ellenőrzéseket ismételni kell.
- A munka kezdetén nevezd meg a célrendszert, mandantot, objektumokat, a létrehozandó állapotot és a sikerfeltételeket. A már ismert adatot ne kérd újra, az ismeretlent ne találd ki. Lokális diff vagy forrás előkészítése nem SAP-telepítés.
- Az automatizmus az asszisztens munkamenetének része. Nem hoz létre SAP-jobot, nem telepít IDE-hookot, nem figyeli a felhasználó más szerkesztőben végzett mentéseit, és nem módosít transzportelengedési beállítást.
- Kapcsolati hiba után a gyökér [AGENTS.md](../AGENTS.md) leállási szabálya elsőbbséget élvez. Automatikus ellenőrzés címén sincs újrapróbálás vagy másik hozzáférési út.

## Sikerfeltételek

| Ellenőrzés | Mikor sikeres | Mi nem elegendő |
|---|---|---|
| SAP-szintaxis | A módosított verzióra befejezett vizsgálat nulla hibával; minden figyelmeztetés rendezve vagy indokoltan elfogadva. | Sikeres mentés, helyi parser vagy egy korábbi aktív verzió vizsgálata. |
| Aktív állapot | Az engedélyezetten telepített végleges forrás/definíció aktív SAP-visszaolvasása egyezik a szándékolt változattal; a szükséges include-ok és szövegek is kezelve vannak. | Az aktiváló hívás puszta visszatérése vagy a FINAL mappanév. |
| ABAP Unit | A releváns tesztfutás befejeződött; tesztszám nagyobb nullánál, nulla bukás és technikai hiba, nincs indokolatlan kihagyás. | Run ID, még futó teszt, nulla teszt vagy tesztkód puszta megléte. |
| QA ATC SCI Onapsis | A végleges forrásra futott, objektumkört lefedő vizsgálat igazolt rendszerrel és variánssal; nulla, az adott kapu szerint blokkoló találat, minden más találat kezelése rögzítve. | A CheckClass, CheckProgram, CheckPackage és más Check* szintaxisválasz. |

Tiszta DDIC-, interfész- vagy hasonló, önálló futtatható logika nélküli változtatásnál az ABAP Unit lehet **nem alkalmazható**, konkrét indokkal és a fogyasztókat érintő regresszió mérlegelésével. Érdemi üzleti logika tesztjének hiánya **nem futott**, nem mentesség. A QA-variánst és blokkoló prioritásokat ne találgasd.

Aktiválás csak a felhasználó adott feladatban megadott felhatalmazásával történhet. Ha a cél csak helyi forrás, a helyi eredmény átadható, az SAP-szintaxis/aktív állapot/Unit/QA nyitott marad.

## Eredmény és bizonyíték

Az ellenőrzés kimenete: **SIKERES**, **RÉSZLEGES** vagy **HIBÁS**. Ezek vizsgálati eredmények, nem projektstátuszok. Hibás kötelező ellenőrzésnél HIBÁS; hiányzó eredmény, nyitott figyelmeztetés, nem hozzáférhető QA-futtató vagy nem igazolt aktív állapot esetén RÉSZLEGES. Csak minden kötelező feltétel teljesülésekor SIKERES.

Az MCP-válaszokat és releváns forrásokat mentsd a projekt `04_ASSETS/validation/<dátum>_<téma>_WIP/` könyvtárába, a futási összesítéssel együtt. Hitelesítési/session adatot soha ne tárolj; a titkot tartalmazó technikai mezőt hagyd ki, és a kihagyást jelöld. Rögzítsd a rendszert, mandantot, objektumot/verziót, időpontot, run ID-t, QA-variánst, találatszámokat és a bizonyítékok relatív fájlneveit. Az eredmény mindig az utolsó módosított változatra vonatkozzon.

A mentett összesítést automatikusan ellenőrzi a [validate_report.py](../.claude/skills/abap-code-review/scripts/validate_report.py) segéd. Ez az összesítés és bizonyítékfájlok ellenőrzője, nem SAP-futtató; a normalizált eredmények szakszerű kiolvasását nem helyettesíti.

## Kötelező visszajelzés

```text
Objektum: <név, rendszer/mandant, vizsgált verzió>
Sikerfeltételek: hibamentes szintaxis; egyező aktív forrás;
                alkalmazható Unit-tesztek sikeresek; QA-kapu teljesült.
Szintaxis: <hibák, figyelmeztetések és eredmény>
Aktív állapot: <egyezik / eltér / nem ellenőrzött>
ABAP Unit: <befejezett tesztszám és bukás / nem alkalmazható indokkal / nem futott>
QA: <tényleges variáns és eredmény / nem futott és oka>
Összesítés: SIKERES / RÉSZLEGES / HIBÁS
Nyitott feltétel: <mi hiányzik a sikerhez>
Bizonyíték: <helyi jelentés>
```

Az érdemi eredményt és döntést a projekt `_LOG.md` fájljába is írd be. Vizsgálati hiba miatt ne indíts automatikusan üzleti riportot, adatot módosító tesztet, nagyobb objektumkört vagy csomagszintű vizsgálatot.
