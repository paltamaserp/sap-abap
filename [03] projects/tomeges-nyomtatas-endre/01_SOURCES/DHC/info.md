1. **Melyik táblán dolgozunk?** DHC-ban két, mezőre azonos tábla van: `ZPRT_DCQM` és `ZPRT_PR_DCQM`. A doksi a `ZPRT_DCQM`-et nevezi meg, a jelenlegi kód is ezt használja. \
   Ez léezik már a DHC-be.
2. EZPRT\_STOCK zárolás nincs,&#x20;
3. **Kell-e a teljes keretprogram?** QU5-ben négy funkció van: kizárás, megtekintés, DC engedélyezés, engedélyezés visszavétele. Vagy elég a kizárás és a megtekintés?\
   csak aa kizárás kell elsőre.
4. A `ZEBFC_PR_DDCODE a nem létezik DC-be`
5. **Kell-e a hosszú szöveg?** QU5-ben a kizárás oka a `ZEBFT_PR_DCQMLT` táblába kerül. Ennek DHC-ban nincs párja. Új tábla legyen (pl. `ZPRT_DCQMLT`)\
   Maradjon ahogy az DU5-be nvan, minden kell.
6. **Mi legyen az összegző oszlop?** Maradjon ahogy az DU5-be nvan, minden kell.

