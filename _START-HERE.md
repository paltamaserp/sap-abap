# \_START-HERE.md — a workspace bejárata

> Ezt olvasd el **ELŐSZÖR**, minden session elején. Itt a térkép és az olvasási sorrend.
> Ha bármit átszervezel a workspace-ben, **ezt a fájlt is frissítsd.**

---

## Mi ez a workspace

SAP ABAP fejlesztés (ECC + CRM, on-premise, E.ON) Claude-dal támogatva.
Az ABAP objektumokat az **ABAP ADT MCP** (`fr0ster/mcp-abap-adt`) szerveren keresztül éred el — innen olvasol/írsz reportokat, függvénymodulokat, osztályokat. A feladatkövetés **ClickUp**-ban van.

**Nyelv:** minden interakció és dokumentáció magyarul. Kód-kommentek a kódbázis konvenciója szerint.

---

## Olvasási sorrend (mindig ebben)

1. `[01] system/RULES.md` → kötelező viselkedési szabályok
2. `[01] system/NAMING.md` → fájlnév-konvenció (mikor · mi · státusz)
3. `[01] system/STATUS.md` → a 4 megengedett státusz
4. `[02] context/` → háttértudás, **csak ha kell** (könyvtárként, nem végig)
5. A konkrét projekt `00_BRIEF.md` és `_LOG.md` fájlja → mit csinálunk és hol tartunk

---

## Térkép

```
[00] inbox/     → nyers, rendezetlen drop. SEMMI nem marad itt tartósan.
[01] system/    → szabályok + konvenciók (kövesd)
[02] context/   → stabil, újrahasznosítható tudás (könyvtár)
[03] projects/  → aktív munka, projektenként számozott vázzal
[04] outputs/   → kész leszállítmányok (ÉÉÉÉ-HH-NN_téma_STÁTUSZ.kiterjesztés)
[99] archive/   → régi, de kereshető
```

Egy projekt belső váza:

```
[03] projects/<projekt>/
├── README.md       → hogyan indíts új projektet (checklist)
├── 00_BRIEF.md     → cél · miért · „kész” kritérium  (ezt olvasd elsőként)
├── 01_SOURCES/     → bemenetek: dump-ok, ADT export, jegyzetek
├── 02_NOTES/       → munkajegyzetek
├── 03_DRAFTS/      → WIP verziók, iterációk
├── 04_ASSETS/      → mellékletek + teszt-eszközök
│   ├── abap/         → WIP .abap export
│   ├── playwright/   → automatizált OData API-tesztek
│   └── rest-client/  → kézi .http hívások
├── 05_FINAL/       → kész eredmény, mielőtt outputs-ba kerül
└── _LOG.md         → döntésnapló — EZT olvasd, hogy folytatni tudd a munkát
```

Teszt- és review-eszközök: `[01] system/TESTING-TOOLS.md`.

---

## Aranyszabály

- **Markdown** az utasításnak
- **Számok** a sorrendnek (`[NN]` workspace szint, `NN_` projekt-workflow)
- **Nevek** a jelentésnek
- **Dátumok** a kereséshez
- **Inbox** a káosznak
- **Napló** a folytatáshoz

Adj kevesebb okot a találgatásra. Ennyi az egész.

---

## Jelenleg aktív projektek

## Státuszok: REVIEW, WIP, FINAL,

| Projekt        | Státusz | ClickUp |
| -------------- | ------- | ------- |
| `_TEMPLATE` () | WIP     |         |

> Tartsd ezt a táblát naprakészen — ez a leggyorsabb áttekintés rólad és Claude-nak is.
