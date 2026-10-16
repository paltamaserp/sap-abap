# DC-üzenetek létrehozása a DHC ZPR üzenetosztályban

**Dátum:** 2026-10-08  
**Státusz:** WIP  
**Rendszer:** DHC

A két helyi program DC-üzeneteit a ZPR 045–066 tartományra vezettük át. A megadott `01_SOURCES/DHC/ZPR.message` exportban 000–044 szerepel; a 045–066 számok ott nincsenek. A 14 foglalt és a 8 hiányzó régi szám helyett 22 új DC-üzenet szükséges. A közös üzenetek mindkét programban azonos számot kapnak.

## Mit kell létrehozni SAP-ban?

1. SE91 → üzenetosztály: **ZPR** → Módosítás, magyar nyelven.
2. Ellenőrizd, hogy **045–066** az aktuális DHC-ban is szabad. Ha az export óta foglalt lett valamelyik, annak meglévő szövegét ne írd felül; más szabad szám és az érintett kódkonstansok összehangolása szükséges.
3. Vedd fel az alábbi **22 rövid üzenetszöveget**. Az `&1`, `&2`, `&3` jeleket pontosan tartsd meg.
4. Mentsd a módosítást a fejlesztés transportjába.
5. Másold át a két frissített programot (`ZPR_DCQM_EXCLUDE`, `ZPR_DC_FRAME`), és ellenőrizd/aktiváld őket. Az include-okhoz, a 0100 képernyőhöz, a DDIC-hez és a tranzakciókhoz ez a módosítás nem igényel új objektumot.

| Új ZPR szám | Korábbi kódbeli szám | Létrehozandó magyar rövid szöveg |
|---|---|---|
| `045` | `020` | A Stock ID nem létezik! |
| `046` | `021` | A stock lezárt, csak megjelenítés lehetséges |
| `047` | `023` | Nincs kijelölt sor |
| `048` | `024` | Mentés sikeres |
| `049` | `025` | Mentés sikertelen |
| `050` | `026` | A DC már engedélyezve van |
| `051` | `027` | DC engedélyezés sikeres |
| `052` | `028` | DC engedélyezés sikertelen |
| `053` | `029` | Engedélyezett sorok száma: &1 |
| `054` | `030` | Kizárt sorok száma: &1 |
| `055` | `031` | A DC még nincs engedélyezve |
| `056` | `032` | Engedélyezés visszavétele sikeres |
| `057` | `033` | Engedélyezés visszavétele sikertelen |
| `058` | `044` | &1 kizárva: &2 &3 |
| `059` | `045` | &1 kizárása visszavonva |
| `060` | `046` | DC zárolás kód &1 nem létezik. |
| `061` | `047` | DC zárolási szöveghez DC zárolási kódot is meg kell adni! |
| `062` | `048` | DC kész, a stock nem módosítható |
| `063` | `054` | A &1 stockhoz nincs adat |
| `064` | `056` | A szelekció kibővült az azonos borítékba kerülő nyomtatványokkal. |
| `065` | `057` | Ha megadott összeget, akkor adjon meg pénznemet is. |
| `066` | `059` | A kizárt rekordok száma: &1. |

A meglévő **000** (`& & & &`) változatlanul használható általános szövegekhez. A meglévő **001–044** üzeneteket nem módosítjuk. A fenti „korábbi szám” a javítás előtti kódkonstans értéke; nem azt jelenti, hogy a DHC meglévő üzenetét át kell nevezni vagy felül kell írni.

A `061` és `064` szövegét rövidebbre fogalmaztuk az SE91 rövid szövegének hosszkorlátjához; a jelentésük megmaradt. Minden új szöveg legfeljebb 73 karakter. A kódbeli paraméterátadásokhoz illeszkednek: 053/054/066 darabszám, 058 dokumentum + kód + szöveg, 059 dokumentum, 060 DC-kód, 063 stockazonosító.

Másolható, sorszám nélküli szöveglista: [2026-10-08_dc-zpr-uj-uzenetek_WIP.message](2026-10-08_dc-zpr-uj-uzenetek_WIP.message). A 22 sor a 045–066 üzenetek sorrendjében szerepel; az SE91 szövegoszlopába a 045-ös sortól másolható. Ez létrehozási segédlet, nem aktív SAP-export.

## Mi változott a kódban?

- `ZPR_DCQM_EXCLUDE.abap`: 14 DC-üzenet konstansának száma átvezetve.
- `ZPR_DC_FRAME.abap`: 11 DC-üzenet konstansának száma átvezetve.
- A közös jelentések: 045 (stock nem létezik), 046 (stock lezárt), 062 (DC kész).
- Az üzenetekhez tartozó elavult TODO-kommentek és a két rövidített üzenet kommentjei pontosítva. A ZPR 000 kommentje a meglévő négy helyettesítőhöz igazítva.
- Az üzleti feltételek, az üzenettípusok, a MESSAGE WITH paraméterek, a naplóbejegyzések felépítése és az adatbázis-műveletek megmaradtak. Minden üzenet, ALV-hibaprotokoll és popup a név szerinti konstansokat használja, ezért az átvezetés ezekre is érvényes.

A [2026-10-08_dc-zpr-uzenetek-atvezetes_WIP.diff](2026-10-08_dc-zpr-uzenetek-atvezetes_WIP.diff) a két program közvetlenül e javítás előtti helyi változatához képest mutatja az eltérést. A diff útvonalai az `04_ASSETS/abap/` mappához viszonyítottak; nem a QU5 eredetihez vagy az aktív SAP-verzióhoz hasonlít.

## Ellenőrzés és korlátok

A helyi ellenőrzés rendben: a konstansok teljesek, az új számok egyediek és nem ütköznek az exporttal, a két program közös üzenetei egyeznek, a rövid szövegek és a helyettesítők megfelelnek. A végrehajtható kódban kizárólag az üzenetszámok változtak. A diff előre- és visszafelé alkalmazható; az előállított tartalom a sorvégek normalizálása után pontosan egyezik a két programmal.

SAP-objektumot nem módosítottunk. Az új üzeneteket a fenti lépésekben kell létrehozni. SAP-szintaxisellenőrzés/ATC és funkcionális teszt nem futott.

A korábban jelzett címszámos szöveg a ZPR 020 üzenet volt. Ugyanebben a kódbeli helyzetben a javítás után a ZPR 045 jelenik meg: „A Stock ID nem létezik!”. Ez az üzenetjavítás nem hozza létre a hiányzó stockrekordot.
