# Fájltisztítás a mai MCP-export alapján

Státusz: **WIP**, 2026-10-17. Helyi leltár, tartalom- és diffvizsgálat.

**Archiválás végrehajtva a felhasználó kérésére:** a tegnapi export, 19 régi munkaforrás, 17 korábbi jegyzet, 13 történeti terv/diagnosztikai anyag, 8 korábbi cockpit-forrásmentés és 36 ideiglenes munkafájl az [archívumba](<../../../[99] archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/README.md>) került. Összesen 127 fájl, mozgatás utáni hash-ellenőrzéssel. Az alábbi táblázatok az archiválást megelőző értékelést dokumentálják; az eredeti és aktuális helyek az archív manifesztben szerepelnek. Fájl nem lett törölve, új SAP-hívás nem történt.

**Döntés:** a további munka elsődleges forrása a `05_FINAL/abap-2026-10-17/` mai MCP-export. A korábbi munkaforrások történeti összehasonlításhoz, illetve a még hiányzó kiegészítésekhez használhatók. A mai pillanatkép 33 tartalomfájljának manifeszt szerinti mérete és SHA256-értéke ismét ellenőrizve, változatlan.

A vizsgálat kezdetén 276 fájl volt a projektben, ebből 34 a mai exportban, 242 azon kívül. A projekten kívüli hét, ehhez a munkához tartozó `.tmp` munkakönyvtárban további 36 fájl volt. A nulla bájtos `.gitkeep` fájlokat a leltár tartalmazza, duplikációs érvként nem használtuk. A rejtett mintafájlok szerepelnek a leltárban; `node_modules` és `.git` nem része a vizsgálatnak.

## Könyvtárankénti javaslat

| Könyvtár / fájlcsoport | Javaslat | Indok |
|---|---|---|
| `05_FINAL/abap-2026-10-17/` | Marad, elsődleges munkabázis | Friss, ellenőrzött SAP-pillanatkép, 24 objektum / 34 fájl. |
| `05_FINAL/abap-2026-10-16/` | Egyelőre történeti mentés; később archiválható | 22 fájl bájtra egyezik a maival, 12 nem. Öt objektum forrása változott; a teljes tegnapi csomag nem duplikátum. A mai manifeszt és több leírás hivatkozik rá. |
| `01_SOURCES/QU5/` | Megtartandó eredeti referencia | Az átültetés kiinduló üzleti logikája, üzenetei, képei és DDIC-leírásai. Egy közös include bájtra egyezik egy mai include-dal, de ettől a QU5-forráscsomag nem válik feleslegessé. |
| `01_SOURCES/DHC/` | Függőségek megőrzendők; régi diagnosztikai pillanatképek archiválhatók | Több használt osztály, proxy, tábla, struktúra és cockpit-forrás nincs a mai 24 objektumban. A korábbi források dátuma nem jelent mai SAP-állapotot. |
| `01_SOURCES/*.docx`, `*.xlsx` | Megtartandó | Üzleti követelmények, bemeneti tábladefiníciók; az ABAP-export ezeket nem helyettesíti. A dokumentumok tartalmát ebben a tisztításban nem szerkesztettük. |
| `02_NOTES/` és `_LOG.md` | Megtartandó, történeti jegyzetek később archiválhatók | Döntések, eltérések, még nyitott feltételek. A régi ellenőrzési JSON-ok történeti bizonyítékok, nem a mai forrás teszteredményei. |
| `03_DRAFTS/2026-10-16_cockpit_WIP/` | Most megtartandó | Teljes cockpit TOP/O01/FM, flow logic, C01 adapter és új QA-javítás. Ezek jelentős része hiányzik a mai exportból. |
| `03_DRAFTS/2026-10-17_cockpit-hidden-okcodes_WIP.*` | Megtartandó, nyitott javítás | A két logikai jelzőre átvezetett TOP/O01 nincs a mai MCP-csomagban; az SAP-ba történt átvezetés ebből nem állapítható meg. |
| Egyéb cockpit-próbarutinok és diagnosztikai útmutatók | A fontos eredmény megőrzése után archiválhatók | Több változat ideiglenes méréshez készült. A felhasználó sikeres ALV-megjelenítést jelzett; a próbakód nem válhat új fejlesztési alappá. |
| `04_ASSETS/abap/` régi főprogramok és include-ok | Munkabázisként kiváltva; archiválás előtt eltérések rendezendők | Nem puszta másolatok: eltérő adattípusok, proxy-/logikaiport-kezelés, szelekció és programfelépítés is előfordul. |
| `04_ASSETS/abap/` flow logic, textelem-TSV, üzenetlista, útmutatók | Megtartandó kiegészítők | A mai export külön képernyő-, üzenet- és szövegkészletet nem tartalmaz. Több régi útmutató helye/hivatkozása már elavult, későbbi rendezéskor javítandó. |
| `04_ASSETS/abap/test/` | Megtartandó; mai forráshoz igazítandó | A DOC_RIP külön Unit-forrása nincs a mai csomagban; a régi MQ-teszt több ponton eltér az exportált MQ-teszttől. |
| `04_ASSETS/validation/` | Megtartandó eszközök, átállítás szükséges | A scriptek a régi `04_ASSETS/abap/` forrásait olvassák, ezért jelenleg nem a mai exportot ellenőrzik. |
| `04_ASSETS/playwright/`, `04_ASSETS/rest-client/` | Elhagyható sablonok | Mind a 11 fájl bájtra egyezik a projekt `_TEMPLATE` megfelelő fájljával. Projektspecifikus OData-teszt nincs bennük; a sablonból újra létrehozhatók. |
| `05_FINAL/TEST_DATA/` | Megtartandó tesztsegédlet | Feltöltő riport, 23 tesztsor TSV-ben és próbaesetek. Nincs a mai MCP-csomagban; futtatás előtt a mai adatmodellhez egyeztetendő. |
| `.tmp/` patch-próbák, munkamásolatok | Ellenőrzési maradványok elhagyhatók; `before`-mentéseket előbb archiválni célszerű | A patch-check/verify példányok segédfájlok. Több más almappa javítás előtti állapotot és külön előállító scriptet is őriz, ezért nem mind gyorsítótár. |

## Hat konkrét, tartalmilag kiváltható fájl

Az első háromnál csak sorvég/sorvégi whitespace különbség marad a mai teljes include-hoz képest. Az utolsó három a megjelölt teljes helyi forrás megfelelő rutinjával egyezik, sorvég/sorvégi whitespace normalizálása után.

| Elhagyható fájl | Megmaradó megfelelő |
|---|---|
| `03_DRAFTS/2026-10-16_cockpit_WIP/ZPR_DCQM_EXCLUDE_I01.abap` | Mai export `ZPR_DCQM_EXCLUDE_I01.abap` |
| `03_DRAFTS/2026-10-16_cockpit_WIP/ZPR_DCQM_EXCLUDE_O01.abap` | Mai export `ZPR_DCQM_EXCLUDE_O01.abap` |
| `04_ASSETS/abap/ZPR_DCQM_EXCLUDE_I01.abap` | Mai export `ZPR_DCQM_EXCLUDE_I01.abap` |
| `03_DRAFTS/2026-10-17_cockpit-pbo-meres-nelkul_WIP.abap` | Cockpit WIP `ZPR_DCQM_EXCLUDE_C01.abap`, `COCKPIT_PBO` |
| `03_DRAFTS/2026-10-17_create-controls-0100-meres-nelkul_WIP.abap` | Cockpit WIP `ZPR_DCQM_EXCLUDE.abap`, `CREATE_CONTROLS_0100` |
| `03_DRAFTS/2026-10-17_dm-controls-meres-nelkul_WIP.abap` | Cockpit WIP `LZPR_COCKPITO01.abap`, `DM_CONTROLS` |

**Törlési feltétel:** a leírások és a helyi ellenőrző script hivatkozásait át kell állítani a megmaradó megfelelőre. A három rutinkivonatra például a mérőkódtisztítási útmutató linkel; a cockpit-ellenőrző a helyi I01/O01 másolatát is olvassa. Tartalomvesztés nélkül elhagyhatók, de a hivatkozások javítása nélkül a csomag működése sérülne.

Két további, bájtra azonos eredeti DHC-másolatpár található:

- `01_SOURCES/DHC/LZPR_COCKPITTOP.abap` = `01_SOURCES/DHC/ZPR_COCKPIT/LZPR_COCKPITTOP.abap`.
- `01_SOURCES/DHC/LZPR_COCKPITUXX.abap` = `01_SOURCES/DHC/ZPR_COCKPIT/LZPR_COCKPITUXXabap`.

Ezek összevonhatók a hivatkozások felmérésével; az eredeti forráscsomagból nem töröltünk példányt. A névazonosságot önmagában sehol nem tekintettük tartalmi egyezésnek.

## Miért nem elég egyedül a mai 34 fájl?

1. A mai `ZPR_DCQM_EXCLUDE` hivatkozik a `ZPR_DCQM_EXCLUDE_C01` adapterre, de az adapter nincs a napi exportban. Helyi WIP-példány rendelkezésre áll, annak aktív SAP-azonossága e vizsgálatban nem ellenőrzött.
2. A cockpit TOP/O01/FM és 0100/1010 flow logic kimaradt a napi objektumkörből. A `Hidden OK-Codes` javítás jelenleg a külön WIP-ben található.
3. További hivatkozott függőségek, például `ZCL_PR_OUTPUT_MANAGEMENT`, `ZPRT_STOCK`, a proxyosztályok és kapcsolódó struktúráik csak a régebbi DHC-források között vannak részben mentve.
4. A DOC_STATUS mai kódja használja a 101–104 textelemeket, de a szövegeket a külön TSV őrzi; a napi export szövegkészletet nem tartalmaz.
5. A képernyők/GUI-státuszok beállításai és a tesztadatok szintén külön anyagok.

## A diffvizsgálat fontosabb eredményei

- **DC/cockpit:** a cockpit WIP DC-főprogramja és a mai forrás közel áll egymáshoz, de a keresési segítség neve például `ZPRH_PR_STOCKID` helyett a mai kódban `ZPRH_STOCK`; a külön források nem byteazonosak. A host konténerkezelés kapcsolódó részei megvannak, a külön C01 és cockpit források viszont szükségesek maradnak.
- **MQ:** a régi munkapéldány `ZPR_SLOG_EMAIL` / `ZPRB_SLOG_EMAIL` táblanévre és típusra épül, a mai export `ZPRT_EMAIL_SLOG` / `ZPRB_EMAIL_SLOG` értékeket használ. Zárhívások és proxykezelés is eltérnek. A régi `ZPR_MQ_REGISTER` opcionális kiegészítő sincs a napi csomagban; használat előtt mai modellhez igazítandó.
- **DOC_RIP:** a régi változat DATA/PROXY/DISPLAY/TESTS include-okra bontott; a mai főprogram ezek helyett a törzsben tartalmazza a kód jelentős részét, és csak O01/I01 include-okat hivatkozik. A régi hatos csomag nem másolható rá automatikusan a maira; a külön Unit-forrás megőrzendő.
- **DOC_STATUS:** a mai kódban megtalálható a négy textelemhivatkozás, a `DELETE zpr_terti FROM TABLE lt_terti` és a naplóhandle `INSERT ... INTO TABLE` javítása. Ettől a teljes régi munkapéldány még eltér: a logikai portot például a mai kód a `ZCL_PR_OUTPUT_MANAGEMENT` osztálytól kapja, és a kiválasztott adatstruktúrák is változtak.
- **CREATE_STOCK és sampler:** vannak valódi eltérések. A mai CREATE_STOCK például `STATUS = 'X'` feltételt használ; a sampler duplikációszűrése más kódmintával van megoldva. Ezek archiválási jelöltek, nem igazolt teljes másolatok.
- **Stocklezárás:** a régi `ZPR_STOCK_REPORT` mai megfelelője `ZPR_CLOSE_STOCK`. Nemcsak a név változott, például a módosító mód alapértéke és a logikaiport-kezelés is eltér.

Ez célzott tisztítási diffvizsgálat, nem teljes üzleti/szintaktikai kódreview, és nem igazolja, hogy minden régi javaslat SAP-ba került.

## Javasolt rendezési sorrend

1. A mai export legyen a közös fejlesztési kiindulópont; ezt a brief és a workspace-belépő rögzíti.
2. A hiányzó cockpit/C01 források és a nyitott QA-javítás kerüljenek egyeztetett, elkülönített kiegészítésbe. Helyi tervezetet nem szabad aktív MCP-exportként feltüntetni.
3. A képernyő-, szöveg-, üzenet-, teszt- és függőséganyagok maradjanak elérhetők; az ellenőrző scripteket az új munkabázishoz kell igazítani.
4. A kiváltható másolatok és a sablonok eltávolíthatók, a történeti források/diagnosztika pedig archiválható egy külön, későbbi takarításban. Törléshez ez a jegyzet ad konkrét határt; e körben csak elemzés történt.

Az elemzéskor a cockpit `ellenorzes.cjs` két helyen a megszűnt `05_FINAL/abap/` könyvtárra mutatott. Az archiváláskor ezt a megőrzött tegnapi pillanatkép új helyére igazítottuk. A három régi validátor az archivált munkaforrások útvonalát kapta, történeti jelöléssel. Ez útvonal- és szintaxisellenőrzés, nem friss SAP-/üzleti teszteredmény.
