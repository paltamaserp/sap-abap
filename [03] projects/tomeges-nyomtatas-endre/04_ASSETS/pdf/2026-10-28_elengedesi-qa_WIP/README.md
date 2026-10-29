# Fejlesztői QA-PDF - előállítás és ellenőrzés

Dátum: 2026-10-28 · Státusz: WIP.

- [Kimenet: hétoldalas fejlesztői útmutató](<../../../../../[04] outputs/2026-10-28_elengedesi-qa-fejlesztoi-utmutato_WIP.pdf>)
- [Szerkeszthető tartalmi alap](../../../03_DRAFTS/2026-10-28_elengedesi-qa-fejlesztoi-szabalyok_WIP.md)
- [Előállító Python-szkript](build_developer_qa_pdf.py)
- [Ellenőrzési jegyzék és SHA256-lenyomatok](2026-10-28_pdf-validation_WIP.json)
- [Oldaláttekintő](preview.png)

A tartalmi alap tematikus oldalcsoportokat kapott, és a korábban dokumentált SCI-előellenőrzés futtatási lépéseivel egészült ki. Az öt ismert kód, a történeti darabszámok, a források és az igazolási hiányok megmaradtak. A példakérelem DHCK906030; a korábbi variáns Z_CONTROL_FOR_CODE. Az SCI-futás nem igazoltan azonos az elengedési kapuval.

Előállítás: a helyi csomagolt Python/ReportLab futtatókörnyezettel, beágyazott Calibri/Consolas betűkészlettel. Renderelés: a csomagolt Poppler pdftoppm eszközével, 110 dpi felbontásban. Mind a hét oldalt átnéztük; a címben talált kezdeti tördelési jelölést javítottuk, a legfrissebb érintett oldalakat újrarendereltük és újraellenőriztük. Nincs levágott szöveg, táblázat-átfedés, hibás karakter vagy oldalszámozási eltérés. A szövegkinyerés a szabálykódokat, kulcsazonosítókat és a magyar karaktereket is ellenőrizte; a karakterek a megengedett oldaltartományban maradnak.

Ez PDF-tartalmi és megjelenítési ellenőrzés, nem SAP QA-futtatás. Az érintett SAP-kapcsolatot nem használtuk; a korábbi EACCES miatti leállás változatlanul fennáll.
