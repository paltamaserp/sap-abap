# Egyszeri MCP-újrapróbálás - 2026-10-28

A felhasználó a korábbi EACCES és a kifejezett újrapróbálási kérés szükségességének ismertetése után ezt kérte: „DEllenőrizd újra, és ne a lokális adatokból indulj ki, hanem az ellenöző programból”. Ezt az érintett kapcsolat egyszeri újrapróbálására és siker esetén az ellenőrző program olvasási felderítésére szóló kérésként kezeljük.

Hatókör: MCP stdio, csak olvasás. Első művelet: az ellenőrző objektumok repository-felderítése TADIR SELECT-tel. A korábbi STOP-bizonyíték megmarad. Új kapcsolati/hitelesítési hiba vagy timeout esetén ismét leállás következik. Nincs SAP-írás, aktiválás, kérelemelengedés vagy új QA-futtatás.
