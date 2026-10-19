# A ZZ kizárási kód szerepe – QU5 és DHC

Dátum: 2026-10-17. Státusz: WIP. Helyi forrásellenőrzés; futtatás és friss SAP-visszaolvasás nélkül.

## Mit jelent a ZZ?

A `BLOCK_DC = 'ZZ'` a borítéktárs automatikus DC-kizárásának jelölése. Ha egy dokumentumot kizárnak, az ugyanahhoz a borítékhoz tartozó többi, még nem kizárt dokumentum is kizárást kap. A közvetlenül módosított soron a felhasználó által megadott ok marad; az automatikusan bevont társak kódja `ZZ`.

A DHC-forrás ezt a `gc_block_dc_envelope` konstansban nevezi meg. A kódban rögzített indok: „hiányos boríték nem mehet ki”. A megvalósítás tehát a boríték egészére viszi tovább a kizárást. Ez forrásban dokumentált szabály; külön üzleti specifikációt vagy a `ZZ` customizingban tárolt hivatalos megnevezését ez az ellenőrzés nem igazolja.

Példa: A, B és C dokumentum azonos borítékban van, kezdetben mindhárom kódja üres. A sorra `01` okot adunk:

| Dokumentum | Eredmény | Miért? |
|---|---|---|
| A | `01` | Közvetlenül megadott kizárási ok |
| B | `ZZ` | Az A-val közös boríték miatt automatikusan kizárt |
| C | `ZZ` | Az A-val közös boríték miatt automatikusan kizárt |

Ez a példa a kód logikai következménye, nem végrehajtott SAP-teszt.

## DHC: pontosan mikor kerül bele?

Az elsődleges vizsgált változat: [a 2026-10-17. 13:49-kor aktívként visszaolvasott riport](<../../../[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/project/01_SOURCES/DHC/2026-10-17_cockpit_114947_WIP/ZPR_DCQM_EXCLUDE.abap>). Az [export README-je](<../../../[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/project/01_SOURCES/DHC/2026-10-17_cockpit_114947_WIP/README.md>) rögzíti a mentés eredetét. A felhasználó által írt `ZPR_DCQM_EXLCUDE` név helyett a helyi objektumnév `ZPR_DCQM_EXCLUDE`.

- A 142. sorban `gc_block_dc_envelope ... VALUE 'ZZ'` van.
- A **Kizárás gomb** az `exclude_selected` metódusban beállítja a kijelölt sorok kódját és szövegét, összegyűjti a nem üres borítékazonosítóikat, majd meghívja az `exclude_envelope_partners` metódust (788–841. sor).
- **Cellás kódmegadáskor** a `handle_data_changed` ellenőrzi a kódot; a jóváhagyott cellák feldolgozása a `handle_data_changed_finished` metódusban ugyanezt a társkizáró rutint hívja (672–786. sor).
- A társkizáró rutin csak az üres `BLOCK_DC` mezőjű, nem üres és az érintett borítékkal egyező sorokra ír `ZZ`-t és átveszi a kizárás szövegét (956–976. sor). A meglévő saját okot az automatikus továbbadás megőrzi. A felhasználó által közvetlenül kijelölt/módosított sor kódja természetesen átírható.

Az adatbetöltés az eredeti szűrés találatait az azonos stockhoz tartozó teljes borítékokkal kibővíti (530–542. sor). Emiatt olyan társ is bekerülhet az ALV-ba és a kizárásba, amelyet az eredeti részletes szűrés önmagában nem talált volna meg. Üres borítékazonosító DHC-ban nem kapcsol össze sorokat.

A `ZZ` először az ALV belső táblájába kerül. Tartós mentéskor a `save_row` írja a `ZPRT_DCQM-BLOCK_DC` mezőt, a szöveget pedig a `ZPRT_DCQMLT-BLOCK_DC_TEXT` mezőbe (1211–1255. sor). Az automatikus kitöltés tehát a riportban végrehajtott értékadás.

**Visszavétel:** a gomb egy kijelölt sor borítékának összes sorából törli a kódot és a szöveget, nem csak a `ZZ` sorokból (843–882., 978–1000. sor). Cellás kódtörlés is borítékszintű; egyidejű többcellás módosításkor a kifejezetten új kódot kapó sorokat a rutin megőrzi, majd újra lefuttatja a kizárásokat (734–770. sor).

## QU5 és DHC eltérései

QU5 forrás: [ZEBF_PR_DCQM_REPORT.abap](../01_SOURCES/QU5/ZEBF_PR_DCQM_REPORT.abap).

| Művelet | QU5 | DHC, 2026-10-17. 13:49-es mentés |
|---|---|---|
| Kizárás gomb | Kijelölt sor: megadott ok; azonos boríték üres kódú társai: `ZZ` (674–702. sor) | Ugyanez, közös társkizáró metódussal |
| Cellába írt nem üres kód | A más dokumentumazonosítójú borítéktársak kódját feltétel nélkül `ZZ`-re írja, meglévő okot is felülírhat (859–882. sor) | Csak a még üres kódú társak kapnak `ZZ`-t |
| Cellás szövegmódosítás | A többi borítéktárs szövegét is átírja | Saját, nem `ZZ` kódú sorból csak a `ZZ` társakra továbbítja |
| Üres borítékazonosító | Ezekben az ágakban nincs külön védelem; az üres azonosítójú sorok is összecsoportosulhatnak | Nem csoportosít |
| Kizárás visszavétele | A boríték kódját és szövegét törli (712–741. sor) | Szintén borítékszintű |

A QU5 stockriport minden nem üres DC- vagy QM-kódú dokumentumot kiválaszt, majd a borítékazonosítókból állítja össze az `exclude_envelopes` listát. Ebbe a `ZZ` sorok is beletartoznak; ebben az ágban nincs külön `ZZ`-feldolgozás. Forrás: [ZEBF_PR_STOCK_REPORT.abap](../01_SOURCES/QU5/ZEBF_PR_STOCK_REPORT.abap), 154–159. és 865–872. sor.

## Fontos forráskülönbség és ellenőrzési korlát

A [DHC könyvtár gyökerében lévő korábbi ZPR_DCQM_EXCLUDE.abap](../01_SOURCES/DHC/ZPR_DCQM_EXCLUDE.abap) más megvalósítás: az `exclude_doc` a kijelölt sorokra fix `01`-et ír (427–442. sor); ott nincs `ZZ`-terjesztés. Ezért a könyvtár gyökerében lévő másolat és a későbbi aktívként mentett riport nem kezelhető azonos verzióként. A jelenlegi helyi cockpit WIP-ben a fenti `ZZ`-konstans és társkizáró logika szintén megtalálható.

A DHC mentés előtt minden módosított, nem üres kód létezését ellenőrzi a `ZPRC_DCCODE` táblában (1002–1013., 1620–1645. sor). Így az automatikus `ZZ` mentéséhez is kell megfelelő kódtábla-bejegyzés; a vizsgált riport nem hozza létre ezt. Az aktív kódtábla tartalmát nem ellenőriztük.

További forrásból látható szélső eset: mindkét popupellenőrzés megengedi, hogy a kód és a szöveg is üres maradjon. Ha ezt a popup engedi jóváhagyni, a kizárási ág ezután is lefut, és az érintett boríték üres kódú sorai `ZZ`-t kaphatnak. Ez statikus következtetés, GUI-ban nem teszteltük (QU5: 1332–1354.; DHC: 1669–1685., 815–832. sor).

Ebben a munkakörben kizárólag helyi fájlokat olvastunk; SAP-hívás, kódmódosítás és futtatás nem történt. A korábbi kapcsolati leállás és az azt követő automatikus jóváhagyási elutasítás után nem kezdeményeztünk új elérést. A korábbi elutasítás nem SAP-válasz és nem új HTTP 401. Az aktuális aktív QU5/DHC-állapot nincs ellenőrizve.
