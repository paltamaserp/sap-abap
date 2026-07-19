# STATUS.md — a státusz-szótár

> A fájlnevek és a `_LOG.md` **csak ezt a négy státuszt** használhatják.
> Cél: ha mindenki (te és Claude is) ugyanazt a négy szót használja, a keresés és
> a folytatás mindig egyértelmű. Nincs „final_v2”, „final_REAL”, „kesz_igazi”.

---

## A négy státusz

| Státusz | Mit jelent | Tipikus hely |
|---|---|---|
| **WIP** | Aktív, még alakul. Kéz alatt van, ne hivatkozz rá véglegesként. | `03_DRAFTS/` |
| **REVIEW** | Kész, de jóváhagyásra / átnézésre / tesztre vár. Tartalmilag teljes. | `03_DRAFTS/` vagy `05_FINAL/` |
| **FINAL** | Végleges, leszállítható. Nem nyúlunk hozzá új igény nélkül. | `05_FINAL/` → `[04] outputs/` |
| **ARCHIVED** | Régi/lezárt, de kereshető marad. Nem aktív. | `[99] archive/` |

---

## Hogy néz ki a fájlnévben

```
2026-06-29_crm-uk-history-szurok_WIP.md
2026-06-29_funkcio-interface-export_FINAL.md
2026-03-12_regi-riport_ARCHIVED.md
```

Séma: `ÉÉÉÉ-HH-NN_téma_STÁTUSZ.kiterjesztés` (lásd `NAMING.md`).

---

## Az állapotok útja (csak előre)

```
WIP  ──►  REVIEW  ──►  FINAL  ──►  ARCHIVED
 │                                    ▲
 └──────────── (elvetve) ─────────────┘
```

- **WIP → REVIEW:** tartalmilag kész, mehet átnézésre.
- **REVIEW → FINAL:** jóváhagyva. Ekkor másold/told `[04] outputs/`-ba.
- **FINAL → ARCHIVED:** lezárult, vagy újabb verzió váltotta fel → `[99] archive/`.
- Visszalépés FINAL-ból ritka: ha valódi újranyitás van, **inkább új fájl** új dátummal, és a régit ARCHIVED-be.

---

## Szabályok Claude-nak

1. Új fájl alapból **WIP**, hacsak nem mondom, hogy kész.
2. Státuszt **csak akkor** léptess, ha kimondom, vagy a brief „kész” kritériuma teljesül.
3. Státuszváltáskor írj egy sort a projekt `_LOG.md`-jébe (mi és miért váltott).
4. FINAL fájlt soha ne írj felül csendben — kérdezz rá, vagy nyiss új verziót.
