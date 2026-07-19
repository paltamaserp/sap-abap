---
name: saphana-abap-hana-guidelines
description: Use for SAP ABAP, DDIC, CDS, AMDP, SQLScript, SAP HANA, and SAP ADT work in this SAPHANA workspace. Applies the local oneERP ABAP Development Guideline V22 PDF (in [02] context/) and any installed SAP skills.
---

# SAPHANA ABAP/HANA Skill Description

Use this project skill whenever the task involves SAP ABAP, SAP HANA, SAP ADT, DDIC tables, CDS views, AMDP, SQLScript, SALV, ABAP reports, ABAP classes, transports, activation, or SAP repository analysis.

## Installed Skills To Use

- `sap-abap`: Use for ABAP reports, classes, ABAP SQL, internal tables, structures, exception handling, RAP, EML, ABAP Unit, and general ABAP development.
- `sap-abap-cds`: Use for CDS views, CDS view entities, annotations, associations, DCL, CDS parameters, and CDS-backed Fiori data models.
- `sap-sqlscript`: Use for SAP HANA SQLScript, AMDP, table functions, stored procedures, HANA pushdown, and SQLScript performance tuning.
- `sap-hana-cli`: Use for HANA CLI workflows, HANA object inspection, HDI containers, HANA SQL commands, and HANA Cloud operations.

> Note: these are separate SAP skills. They are **not installed by default** in this Claude Code
> workspace. If needed, install them from the `secondsky/sap-skills` marketplace via
> `/plugin install <name>@sap-skills`. (The Codex path `C:\Users\devco\.codex\skills\` is not relevant here.)

## Project Guideline Source

Use this local PDF as the SAP development guideline source:

```text
[02] context/oneERP ABAP Development Guideline_V 22 00 published.pdf
```

This is the **oneERP ABAP Development Guideline, version 22.00** — the authoritative naming and coding standard for this workspace.

## Required Workflow

- Prefer `sap-abap-adt` MCP tools for SAP repository reads, updates, activation, DDIC changes, table changes, CDS reads, and verification.
- After changing a SAP repository object, read back or otherwise verify the active object state when feasible.
- Keep local `.abap` source copies synchronized with the active SAP object when the workspace contains such copies.
- Do not store SAP passwords, tokens, or other secrets in markdown files or repository source.
- Use conservative, SAP-compatible ABAP patterns unless the user asks for a newer syntax or a specific release target.

## ABAP Development Guideline — Summary

Quick-reference rules; the authoritative source is the oneERP V22 PDF above. Apply unless the user explicitly requests otherwise:

- Write performant, secure, robust, and maintainable SAP code.
- Use meaningful and descriptive English names for attributes, methods, events, types, and repository objects.
- Use only `A-Z`, `0-9`, and `_` in names; do not use hyphens; names must not begin with digits.
- Separate compound names with underscores.
- Prefer SAP standard or conventional names over invented terms.
- Use Pretty Printer-compatible formatting.
- Delete obsolete code instead of commenting it out.
- All comments should be in English for production-quality code.
- Use SALV where available instead of classic list reports.
- Provide feedback at the end of processing through ALV, log, success message, or error message.
- Selection-screen fields should have corresponding text elements for production-quality reports.
- Keep global data to a minimum.
- Prefer local classes over form routines for new non-trivial logic.
- Avoid database updates without proper SAP lock handling.
- Reports should have a transaction and an authorization check for production use.
- Use whitelists or regular expressions for external/user input where practical.
- Clear internal tables with high row counts after use when they are no longer needed.
- Sort an internal table before `READ TABLE ... BINARY SEARCH`.
- Use `ORDER BY` or explicit sorting whenever later logic depends on row order.
- For customizing tables, make them client-dependent; the first column must be the client field.
- For customizing tables, enable change logging when required.

## Naming Conventions

Follow the PDF naming pattern:

```text
<Data object> := <Scope><Type>_<Characters>
```

Scopes:

- `G`: global object
- `L`: local object
- `I`: importing/using parameter
- `E`: exporting parameter
- `C`: changing parameter
- `R`: returning parameter
- `T`: type

Types:

- `C`: constant
- `V`: general variable/data field
- `S`: structure or work area
- `T`: internal table
- `R`: object reference

Common prefixes:

- Global constants/data/structures/tables/references: `GC_`, `GV_`, `GS_`, `GT_`, `GR_`
- Local constants/data/structures/tables/references: `LC_`, `LV_`, `LS_`, `LT_`, `LR_`
- Parameters: `P_`
- Select-options: `S_`
- Importing parameters: `IV_`, `IS_`, `IT_`, `IR_`
- Exporting parameters: `EV_`, `ES_`, `ET_`, `ER_`
- Changing parameters: `CV_`, `CS_`, `CT_`, `CR_`
- Returning parameters: `RV_`, `RS_`, `RT_`, `RR_`
- Types: `TV_`, `TS_`, `TT_`, `TR_`
- Local classes: `LCL_<Characters>`
- Local methods: verb-based names such as `GET_<...>`, `SET_<...>`, `CALCULATE_<...>`
- Event methods: `ON_<Characters>`

## Report Structure

For ABAP reports, maintain a clear order:

1. Header and change history where appropriate
2. Type definitions
3. Global data and constants
4. Selection screen declarations
5. Events such as `INITIALIZATION`, `AT SELECTION-SCREEN`, `START-OF-SELECTION`
6. Implementation units such as local classes or forms

If a report becomes too large, split it into includes using the report naming pattern from the guideline, but prefer classes over shared includes.

## Current Workspace Notes

- Primary report currently worked on: `ZPT_AI_1`
- Local ABAP copies may exist in:
  - `ZPT_AI_1.abap`
  - `Teszt/ZPT_AI_1.abap`
- SAP connection is available through the configured `sap-abap-adt` MCP destination.
