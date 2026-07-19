# SYSTEM-RULES.md — a rendszer karbantartásának szabályai

> Míg a `RULES.md` azt mondja meg, **hogyan dolgozz**, ez azt, **hogyan tartsd karban magát a workspace-rendszert**.
> Akkor olvasd, ha a struktúrához nyúlsz (új projekt, átszervezés, új mappatípus).

---

## A négy vezérlőfájl viszonya

```
_START-HERE.md   → a TÉRKÉP (mi hol van, olvasási sorrend, aktív projektek)
   ├─ RULES.md       → VISELKEDÉS (hogyan dolgozz)
   ├─ NAMING.md      → FÁJLNEVEK (mikor · mi · státusz)
   └─ STATUS.md      → STÁTUSZ-SZÓTÁR (a 4 megengedett állapot)
```

Ezek a `[01] system/`-ben élnek, és **együtt** definiálják a rendszert. Ha egyiket módosítod, nézd meg, kell-e a többit is.

## Szabályok

1. **A térkép szent.** Ha mappát hozol létre/törölsz/átnevezel a workspace gyökerén vagy egy projekt vázán, **frissítsd a `_START-HERE.md`-t** (Térkép + „Jelenleg aktív projektek" tábla).
2. **Stabil top-szint.** A `[NN]` top-szintű kosarakat (`[00]…[99]`) ne bővítsd újjal a `_START-HERE.md` egyidejű frissítése nélkül. Ad-hoc gyökérmappa = szabálysértés.
3. **Egységes projektváz.** Minden új projekt a `[03] projects/_TEMPLATE/` **másolatával** induljon (`00_BRIEF.md`, `01_SOURCES/`, `02_NOTES/`, `03_DRAFTS/`, `04_ASSETS/`, `05_FINAL/`, `_LOG.md`).
4. **Egy projekt = egy `_LOG.md`.** Projektnapló soha nem a workspace gyökerében, hanem a projekt mappájában.
5. **A skillek külön rétegben élnek.** A Claude Code skillek a `.claude/skills/` alatt vannak, **nem** a `[NN]` tartalmi fában. Ne keverd a kettőt.
6. **Egy guideline-forrás.** A mérvadó ABAP-irányelv a `[02] context/` alatti **oneERP ABAP Development Guideline V22** PDF. Új helyen ne hivatkozz nem létező guideline-fájlra.
7. **Az inbox nem raktár.** A `[00] inbox/` tartalmát rendszeresen a helyére kell sorolni; tartós anyag nem maradhat ott.
8. **Visszafordíthatóság.** Átszervezéskor előnyben a mozgatás a törléssel szemben; ami elavul, az `[99] archive/`-ba megy, nem a kukába.
