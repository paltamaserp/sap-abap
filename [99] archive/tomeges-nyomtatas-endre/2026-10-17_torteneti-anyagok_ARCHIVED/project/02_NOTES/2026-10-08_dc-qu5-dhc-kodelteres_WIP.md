# QU5 → DHC riport: kódeltérés

Dátum: 2026-10-08. Státusz: WIP. Statikus összevetés, a SAP-beli fordítást és funkcionális tesztet nem helyettesíti.

Összehasonlítás: `01_SOURCES/QU5/ZEBF_PR_DCQM_REPORT.abap` és `04_ASSETS/abap/ZPR_DCQM_EXCLUDE.abap`, továbbá a hozzájuk tartozó `_O01` és `_I01` include-ok. A QU5 keretprogram nem része a számoknak.

## Méret és szöveges diff

| Fájl | QU5 sor | DHC sor | Nettó eltérés | Git hozzáadott / eltávolított sor |
|---|---:|---:|---:|---:|
| Főprogram | 1376 | 1592 | +216 (+15,7%) | +1130 / −914 |
| PBO `_O01` | 29 | 27 | −2 | +3 / −5 |
| PAI `_I01` | 35 | 23 | −12 | +5 / −17 |
| Összesen | 1440 | 1642 | +202 (+14,0%) | +1138 / −936 |

Mérés: fizikai sorok, kommentekkel és üres sorokkal; a záró sortörés nem külön sor. Git: `diff --no-index --ignore-space-at-eol --numstat`. Az áthelyezett vagy átírt sorokat a diff eltávolításként és hozzáadásként mutatja. A sorvégi whitespace/CRLF eltérést figyelmen kívül hagyja, de a névcserét, behúzást és kommentátírást beleszámítja. Ezek nem a megváltozott üzleti működés százalékai.

A kommentek, üres sorok és whitespace kiszűrése után a főprogram 955 → 1081 kódsor. Ez a kódszerkezet bővülését is jelzi, a szám továbbra sem funkcionális eltérésmérték.

## Az eltérések tartalma

| Terület | QU5 | Mostani DHC-tervezet | Jelleg |
|---|---|---|---|
| Adatmodell | `ZEBFT_*`, `EXBILLDOCNO`, QU5-típusok | `ZPR*`, `DOC_NO`, DHC-típusok, új SQL-szintaxis | Átültetés |
| Stock sorainak kiválasztása | `MSSFILE` → fájlok → dokumentumok | Közvetlen `PRDSTOCK = p_stokid` | Adatmodellhez igazítás |
| Szelekció/ALV mezők | QU5 mezők | A DHC-ban nem létezők elhagyva, pl. `PACKAGE_ID`, `AKTYP`, `LAUFD`, `LAUFI` szűrőként hozzáadva | Látható mezők változása |
| Stockállapot | Riportban `CLOSED`, keretben `DCCOMPL` ellenőrzés | Riportban zárolás után friss `CLOSED`/`DCCOMPL`; mindkettőnél megjelenítő mód | Védelem és viselkedésváltozás |
| Zár | ENQUEUE, riportban explicit DEQUEUE nélkül | `_SCOPE = 1`, saját zárjelző, explicit DEQUEUE | Zárkezelés átdolgozása |
| Cellás szerkesztés | `data_changed` közben rögtön módosítja a társakat | Érvényesítés `data_changed`-ben, társak kezelése `data_changed_finished`-ben | Jelentős átdolgozás |
| Meglévő kizárási ok | Cellás módosításkor a társ saját kódját is `ZZ`-re írhatja | `ZZ` csak az addig nem kizárt társakra; saját ok megmarad | Üzleti eredményt érintő javítás |
| Szöveg cellás továbbadása | Minden borítéktárs szövegét módosítja | Saját kódú forrássor szövegét a `ZZ` társakra továbbítja | Üzleti eredményt érintő változás |
| Üres boríték | Az üres azonosítók is csoportot alkotnak | Üres boríték kizárásnál/visszavételnél sem csoportosít | Üzleti eredményt érintő változás |
| Mentés | Ciklus utáni `sy-subrc` dönt, hibás mentés után is kilép | Írásonkénti ellenőrzés, SQL-kivételkezelés, teljes rollback; hibánál ALV nyitva | Jelentős hibakezelési változás |
| Hosszú szöveg | Üres DC-szövegnél teljes szövegrekord törlése | Csak DC-szöveget ürít, QM-szöveget megőrzi; munkaterület ürítve | Adatvesztés elleni javítás |
| Napló | BAL függvények | `ZCL_PR_LOG`, a végeredmény szerinti üzenetek, külön naplócommit | Technikai átdolgozás, ellenőrizendő függőség |
| Összegszűrés | A felhasználói tartományt írja át | Minden futáskor belső másolatot épít | Ismételt futás javítása |
| Összeg pénznem nélkül | Speciális nulla/EQ eset megengedett | Bármely megadott összegtartományhoz pénznem szükséges | Szelekciós szabály szigorítása |
| Változásfigyelés | Teljes struktúra összehasonlítása, régi jelző megmaradhat | `BLOCK_DC` és `BLOCK_DC_TEXT` alapján jelző újraszámítása | Hibajavítás |
| Darab oszlop | `COUNTER = 1` már szerepel | `COUNTER = 1` megmarad, „Darab” fejléc | Nem új számlálási funkció |
| Kódszerkezet | Nagy `on_alv_user_command`, egyetlen cellaesemény, BAL FORM-ok | Kisebb metódusokra bontás, `save_data`, `save_row`, `log_write`, `init_run` stb. | Refaktorálás |
| PBO/PAI include | PBO státusz és kontroll; PAI közvetlen cellaellenőrzések | PBO érdemben azonos; PAI ellenőrzései a főprogram FORM-jaiba kerültek | Többnyire áthelyezés |

## Értékelés

A funkció alapja továbbra is a QU5 riport: stock kiválasztása, borítékbővítés, ALV, kizárás és visszavétel, mentés, napló, layout és számlálás. A mostani tervezet jelentős átdolgozás; az „egy az egyben, csak más tábla” elvhez képest több működési változást tartalmaz. Az adatmodellhez igazítás szükséges, a javítások többsége indokolt, de a módváltás, a kizárási okok/szövegek megőrzése és az üres boríték szabálya jóváhagyandó viselkedés.

A főprogram TODO-i szerint az üzenetszámok és a `ZCL_PR_LOG` szerződése még ideiglenesek. Az összevetés nem igazolja, hogy a tervezet már fordul vagy működik DHC-ban.
