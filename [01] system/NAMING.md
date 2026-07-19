# NAMING.md — elnevezési konvenció

> Cél: a név önmagában megmondja, **mikor · mi · milyen státuszban**. Kevesebb ok a találgatásra.

---

## Fájlnév-séma (leszállítmányok, draftok)

```
ÉÉÉÉ-HH-NN_téma_STÁTUSZ.kiterjesztés
```

Példák:

```
2026-06-29_crm-uk-history-orgeh-filter_WIP.abap
2026-06-30_workspace-atrendezes-terv_WIP.md
2026-06-29_funkcio-interface-export_FINAL.md
2026-03-12_regi-riport_ARCHIVED.md
```

- **Dátum** elöl → kronologikus rendezés és kereshetőség.
- **Téma** kebab-case-ben (`a-z`, `0-9`, `-`).
- **STÁTUSZ** csak a négy megengedett egyike (lásd `STATUS.md`): `WIP` · `REVIEW` · `FINAL` · `ARCHIVED`.

## Számozás = sorrend

- `[NN]` → **workspace-szintű** mappák sorrendje: `[00] inbox`, `[01] system`, `[02] context`, `[03] projects`, `[04] outputs`, `[99] archive`.
- `NN_` → **projekt-workflow** sorrendje: `00_BRIEF`, `01_SOURCES`, `02_NOTES`, `03_DRAFTS`, `04_ASSETS`, `05_FINAL`.

## Projekt- és mappanevek

- Projektmappa: **kebab-case**, beszédes név (pl. `crm-uk-history-szurok`, `portal-odata-ic-szervizek`).
- Ahol van, a ClickUp-kód kerüljön a `00_BRIEF.md`-be és a `_START-HERE.md` táblába (pl. CS_013).

## Kivétel: SAP-objektumok

A SAP-ból tükrözött forrásfájlok a **SAP objektumnevet** viselik, és **nem** a dátum-sémát:

```
ZCL_EPT_INTERACTION_DAO.abap
ZXWEB_ELO_BCONTACT_CREATE.abap
ZEPTS_INTERACTION_RECORD.abap
```

Indok: ezeknek egyezniük kell az ADT-objektummal. A dátum/státusz az ilyen fájloknál a `_LOG.md`-ben és a mappa-elhelyezésben él (`01_SOURCES` vs `03_DRAFTS` vs `05_FINAL`).

## ABAP belső elnevezés

ABAP-objektumon belüli nevekre (változók, metódusok, struktúrák) az **oneERP ABAP Development Guideline** érvényes — forrás: [`[02] context/oneERP ABAP Development Guideline_V 22 00 published.pdf`](../[02]%20context/oneERP%20ABAP%20Development%20Guideline_V%2022%2000%20published.pdf).
