# ZPRS\_DCQM\_REPORT létrehozása SE11-ben

Státusz: WIP. A helyi DHC-export és a riport alapján összeállított DDIC-specifikáció; nem aktív SAP-objektum.

A `Type "ZPRS_DCQM_REPORT" is unknown` hiba azt jelzi, hogy a fordító nem talál ilyen aktív típust. A megvalósítási terv L4 pontja új DDIC-struktúraként írja elő. Ha már létezik, ellenőrizd a nevét és aktiváld; ha hiányzik, az alábbiak szerint hozd létre.

## Létrehozás

1. SE11 → **Adattípus**: `ZPRS_DCQM_REPORT` → Létrehozás → **Struktúra**.
2. Rövid leírás: `DC/QM funkciók ALV struktúra`.
3. Csomag: `ZPR_DDIC`; a projekt fejlesztési transportjába kerüljön.
4. Az alábbi komponenseket ebben a sorrendben, TYPE típusozással vedd fel. A `HANDLE_STYLE` táblatípusú mély komponens, nem CHAR mező.

## Komponensek

| Komponens | Komponenstípus |
|---|---|
| DOC\_NO | ZPRD\_DOC\_NO |
| BLOCK\_DC | ZPRD\_PR\_BLOCK\_DC |
| BLOCK\_DC\_TEXT | ZPRD\_PR\_BLOCK\_DC\_TEXT |
| BLOCK\_QM | ZPRD\_PR\_BLOCK\_QM |
| BLOCK\_QM\_TEXT | ZPRD\_PR\_BLOCK\_QM\_TEXT |
| ENVELOPE | ZPRD\_ENVELOPE\_ID |
| PYMET | PYMET\_KK |
| DOC\_CAT | ZPRD\_DOC\_CAT |
| AMNT | BETRW\_KK |
| WAERS | BLWAE\_KK |
| DUEDATE | FAEDN\_KK |
| BANKACCOUNTNUM | ZPRD\_BANKNUM |
| GIRO | ZECAD\_GIRO |
| NAME1 | AD\_NAME1 |
| SYSID | SYSYSID |
| LAND1 | LAND1 |
| AB | ABZEITSCH |
| BIS | BISZEITSCH |
| TARIFTYP | TARIFTYP |
| AKLASSE | AKLASSE |
| ZBIZCAT | /SAPCE/IU\_BBHUBIZCAT |
| MAHNS | MAHNS\_KK |
| MAHNV | MAHNV\_KK |
| FORM | ZPRD\_INSPIRE\_FORMNAME |
| COTYP | COTYP\_KK |
| PACKAGE\_ID | ZPRD\_PACKAGE\_ID |
| CHEQNUMBR | ZPRD\_PR\_CHEQNUMBR |
| COKEY | COKEY\_KK |
| REGMAILNUMBER | ZPRD\_REGMAILNUMBER |
| OPBUK\_PR | ZPRD\_PR\_OPBUKPR |
| AKTYP | AKTYP\_KK |
| LAUFD | LAUFD\_KK |
| LAUFI | LAUFI\_KK |
| PRD_STOCK_ID | ZPRD\_STOCK\_ID |
| PRDSPOOL | ZEDMD\_PRDSPOOL |
| PRDFILE | ZEDMD\_PRDFILE |
| COUNTER | ZPRD\_PR\_COUNTER |
| CHANGED | FLAG |
| HANDLE\_STYLE | LVC\_T\_STYL |

A `MANDT` nem része az ALV-struktúrának. A `COUNTER` az utolsó megjelenítendő adatmező; utána két technikai komponens következik.

**A frissített ZPRT_DCQM alapján:** a tábla a hat `CRUSER`, `CRDATE`, `CRTIME`, `CHUSER`, `CHDATE`, `CHTIME` mezőt is tartalmazza. Ezek adatbázisbeli technikai mezők, a DC-ALV 39 komponensű mezőlistáját nem bővítjük velük. A riport mentéskor kitölti a módosítási mezőket; a létrehozási mezőket megőrzi. Az `INTO CORRESPONDING FIELDS` az ALV-struktúrában szereplő, azonos nevű mezőket veszi át.

**Két elírás javítva a mezőlistában:** `BOCK_DC_TEXT` helyett `BLOCK_DC_TEXT`, `DOC_CATL` helyett `DOC_CAT`. Ha a SAP-struktúrában is a hibás név szerepel, azt javítani és a struktúrát aktiválni kell.

**Stockmező pontosítása:** a felhasználó a SAP-ban `PRD_STOCK_ID` mezőt jelzett. Ha a struktúrát már `PRDSTOCK` komponenssel hoztad létre, ennek a komponensnek a nevét is állítsd `PRD_STOCK_ID`-ra és aktiváld a struktúrát. Az `INTO CORRESPONDING FIELDS` a forrás és cél azonos mezőnevei alapján tölti az ALV-adatokat. A komponensszám továbbra is 39.

## Beállítások és aktiválás

- Ha hiányoznak, a terv L1 szerint előbb hozd létre és aktiváld a `ZPRD_PR_BLOCK_DC_TEXT` és `ZPRD_PR_BLOCK_QM_TEXT` adatelemeket, **CHAR 255** típussal. A többi üzleti adatelem a helyi `ZPRT_DCQM` exportból származik.
- A **Pénznem/mennyiség mezők** fülön az `AMNT` hivatkozási táblája/struktúrája: `ZPRS_DCQM_REPORT`, hivatkozási mezője: `WAERS`.
- A bővítési kategóriát a terv L4/projektszabvány szerint állítsd be, a mély `HANDLE_STYLE` komponens figyelembevételével.
- Mentés → Ellenőrzés → Aktiválás. Ezután a `ZPR_DCQM_EXCLUDE` és include-jai ismét ellenőrizhetők/aktiválhatók.

## További függőségek

A típust nem elég `ZPRT_DCQM`-re cserélni: a riportnak a `BLOCK_DC_TEXT`, `BLOCK_QM_TEXT`, `CHANGED` és `HANDLE_STYLE` komponensek is kellenek. Az ALV mezőkatalógusa és a kizárási popup szintén `ZPRS_DCQM_REPORT` néven hivatkozik a DDIC-objektumra; ezt egy helyi TYPES deklaráció önmagában nem oldja meg.

A teljes riporthoz a terv szerinti `ZPRT_DCQMLT`, `ZPRC_DCCODE`, `EZPRT_STOCK`, üzenetek, naplóosztály és képernyőobjektumok is szükségesek. A `BLOCK_DC` F4-ét a terv L4 szerinti DDIC-értéksegítséggel is be kell állítani, majd a popupban/ALV-ben kipróbálni.

Az aktív struktúra ADT-lekérése 2026-10-08-án HTTP 401 hibával meghiúsult. SAP-ban nem történt létrehozás/aktiválás ebben a munkamenetben.
