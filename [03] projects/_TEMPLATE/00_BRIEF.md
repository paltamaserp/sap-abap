# 00_BRIEF — <projekt-név>

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

- `01_SOURCES/` — bemenetek (dump-ok, ADT export, dokumentáció).
- `02_NOTES/` — munkajegyzetek.
- `03_DRAFTS/` — WIP verziók, iterációk.
- `04_ASSETS/abap/` — WIP `.abap` export.
- `04_ASSETS/playwright/` — automatizált OData API-tesztek.
- `04_ASSETS/rest-client/` — kézi `.http` hívások.
- `05_FINAL/` — kész eredmény (mielőtt `[04] outputs/`-ba kerül).
- `_LOG.md` — döntésnapló (ezt olvasd a folytatáshoz).
