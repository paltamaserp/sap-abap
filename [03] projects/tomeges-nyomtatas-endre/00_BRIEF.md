# 00_BRIEF — TomegesNyomtatasEndre (tömeges nyomtatás)

> Ezt olvasd elsőként minden session elején. (Új projekt indítása: lásd a
> `_TEMPLATE/README.md` checklistjét.)

---

## Cél

<Mit építünk / oldunk meg? 1–3 mondat.>

## Miért

<Üzleti / technikai indok. Honnan jön az igény? ClickUp-kód, ha van.>

## „Kész" kritérium

- <Mérhető feltétel 1>
- <Mérhető feltétel 2>

## Érintett objektumok

- <SAP objektumok, táblák, szervizek>

## Kulcs-konvenciók

| Elem | Érték |
|---|---|
| Rendszer | ECC / CRM (**válaszd ki** — a CLAUDE.md alapértéke ECC) |
| Csomag / transport | <…> |
| ATC variant | <…> |
| Guideline | oneERP ABAP Development Guideline V22 (`[02] context/`) |

## Tartalom-térkép

Áttekintés: **2026-10-26**, első körös tisztítás és friss MCP-forrásmentés után. [Aktuális állapot és nyitott pontok](_LOG.md).

- **Elsődleges munkabázis (felhasználói döntés, 2026-10-26):** [05_FINAL/abap-2026-10-26/](05_FINAL/abap-2026-10-26/README.md), 39/39 kijelölt objektum friss MCP-forrása/definíciója, 90 ellenőrzött fájl. A további elemzések és javítások ebből indulnak. Státusz WIP; nem teljes UI-/függőségmentés.
- **Korábbi exportok:** [2026-10-22](<../../[99]%20archive/abap-2026-10-22/README.md>) és [2026-10-17](<../../[99]%20archive/abap-2026-10-17/README.md>), történeti összehasonlításhoz. A mai munkabázist nem helyettesítik.
- 01_SOURCES/ — eredeti dokumentumok, tábladefiníciók, QU5/DHC-referenciák és SCI/Onapsis-bemenetek.
- 02_NOTES/ — korábbi naplózási és DOC_STATUS-elemzések, valamint a DC ZZ-kód szerepének jegyzete. A korábbi hibalisták a mai exporttal újra ellenőrizendők.
- [Régi draftok szerepe és összevetése](03_DRAFTS/README.md) — történeti referenciák; új javítás a mai exportból indul.
- [Cockpit WIP](03_DRAFTS/2026-10-16_cockpit_WIP/README.md) — C01-adapter, DM/QM-integráció, kapcsolódó külön gomb-/képernyőjavítások.
- [RELEASE_STOCK_NEW riportváltozat](03_DRAFTS/2026-10-21_release-stock-new-riport_WIP/README.md) — a korábbi osztálybővítési irány helyett készült; a friss exportban már szereplő rutinnal összevetendő.
- [Lezárási naplózás](03_DRAFTS/2026-10-22_close-stock-naplo_WIP/README.md) — a DHC/100-ra igazított javaslatok és az átvezetési bizonyítékok is itt maradtak.
- [DC-keret átvitel](03_DRAFTS/2026-10-22_dc-frame-atvitel_WIP/README.md) — QU5 → DHC helyi WIP-forrás, szövegek és diffek.
- [DOC_STATUS CL → AD javaslat](03_DRAFTS/2026-10-22_doc-status-all-delivered_WIP/README.md) — korábbi csomag és háttérjob-útmutató; a [friss exportellenőrzés](02_NOTES/2026-10-22_doc-status-friss-export-ellenorzes_WIP.md) alapján használandó.
- [04_ASSETS/abap/](04_ASSETS/abap/README.md) — flow logic, üzenet-/textelemek, tesztinclude-ok, útmutatók és nyitott DOC_RIP QA-patch. A 04_ASSETS/mcp-export/ eszközei között a mai mentéshez külön offline ellenőrző készült; a letöltés a csatlakoztatott MCP-eszközökkel történt.
- [05_FINAL/TEST_DATA/](05_FINAL/TEST_DATA/2026-10-14_dcqm-exclude-tesztadatok_WIP.md) — megőrzött tesztadatok.
- [2026-10-26-i archívum](<../../[99]%20archive/tomeges-nyomtatas-endre/2026-10-26_projekttisztitas_ARCHIVED/README.md>) — felváltott lezárási változatok, tervek, általános sablonok, QA-skill projektmásolata és teljes előzménynapló; eredeti útvonal- és hash-leltárral.
- [2026-10-17-i archívum](<../../[99]%20archive/tomeges-nyomtatas-endre/2026-10-17_torteneti-anyagok_ARCHIVED/README.md>) — korábban archivált 127 történeti fájl.

A mai objektumlekérések sikeresek voltak, a forrás/definíció az export időpontjára igazolt. SAP-módosítás és futtatott SAP-teszt nem történt. Az első elérési hiba utáni azonnali leállás szabálya továbbra is érvényes.