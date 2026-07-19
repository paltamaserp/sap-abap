# CLAUDE.md — SAP ABAP workspace (ECC + CRM, on-premise, E.ON)

Magyar nyelven dolgozunk: válaszok és dokumentáció magyarul; kód-komment a kódbázis konvenciója szerint.

## Session indulásakor
1. Olvasd be a `_START-HERE.md`-t (térkép + olvasási sorrend).
2. Ha konkrét projekten dolgozunk, ELŐSZÖR olvasd be annak `00_BRIEF.md` és `_LOG.md`
   fájlját, és onnan folytasd.
   **IMPORTANT: a projekt állását soha ne találgasd — a `_LOG.md` az egyetlen forrás.**
3. A részletes konvenciókat csak akkor töltsd be, amikor kellenek:
   `[01] system/NAMING.md`, `[01] system/STATUS.md`, `[01] system/RULES.md`.

## Mindig érvényes szabályok
- **Fájlnév:** `ÉÉÉÉ-HH-NN_téma_STÁTUSZ.kiterjesztés`; a téma kötőjeles, ékezet nélkül.
- **Státusz kizárólag:** `WIP` · `REVIEW` · `FINAL` · `ARCHIVED`. Új fájl alapból `WIP`.
- **YOU MUST: `FINAL` fájlt soha ne írj felül csendben** — kérdezz rá, vagy nyiss új
  verziót új dátummal, a régit pedig told `ARCHIVED`-be.
- Döntés született? Írd be a projekt `_LOG.md`-jébe (a „Döntés:” szóval), és frissítsd
  a napló tetején a „Jelen állás” blokkot.
- Kész munka: `05_FINAL/` → jóváhagyás után `[04] outputs/`.
  Nyers/rendezetlen fájl a `[00] inbox/`-ba kerül, és nem marad ott.

## ABAP környezet
- Az ABAP objektumokat az ABAP ADT MCP-n (`fr0ster/mcp-abap-adt`) keresztül éred el
  (report, függvénymodul, osztály: olvasás/írás).
- ECC/CRM-kompatibilis kód: **nincs template string**, explicit típusozás, régebbi
  runtime — mindig a meglévő kódbázis stílusát kövesd.
- Meglévő funkció bővítésénél inkább bővítsd a logikát, mint átírd (kisebb regressziós
  kockázat).

## Térkép (rövid)
`[00] inbox` · `[01] system` · `[02] context` · `[03] projects` · `[04] outputs` · `[99] archive`
Részletek és olvasási sorrend: `_START-HERE.md`.


## A projekt áttekintése
Ez a munkaterület a **CS HANA ICP** projekt számára készült — ez egy SAP HANA-alapú ügyfélszolgálati / ICP-kezdeményezés, 
amely ABAP-fejlesztést alkalmaz.

ABAP-kód írásakor vagy ellenőrzésekor a névkonvenciók, kódolási szabványok és architektúra-minták
tekintetében olvasd el a `[02] context/oneERP ABAP Development Guideline_V 22 00 published.pdf` dokumentumot.

## Skillek
A `.claude/skills/` alatt két projekt-skill él (session-újraindítás után aktiválódnak):
- `saphana-abap-hana-guidelines` — általános ABAP / HANA / ADT munka, az oneERP guideline-nal.
- `sap-developer-skillset` — SAP Gateway / OData, CRM / IS-U kompetenciák és a portál-projekt konvenciói.