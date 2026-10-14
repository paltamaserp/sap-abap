# Messenger proxy és logikai port: MCP-visszaolvasás

Státusz: WIP. Dátum: 2026-10-13.

A felhasználó kifejezett új ellenőrzési kérésére a SAP ADT MCP-elérés sikeres volt. Repository-keresés és az aktív proxyosztály visszaolvasása után kizárólag SELECT lekérdezésekkel vizsgáltuk a DDIC-metaadatot és a port-hozzárendelést. Minden SAP-hívás sikeres volt ebben a körben; új kapcsolati hiba és automatikus jóváhagyási elutasítás nem történt.

## Igazolt generált objektumnevek

| Elem | Aktív proxyosztályból visszaolvasott név |
|---|---|
| Consumer proxy | `ZPR_CO_EON_QUERY_MESSENGER_STA` |
| Metódus | `EON_QUERY_MESSENGER_STATUS` |
| INPUT típusa | `ZPR_EON_QUERY_MESSENGER_STATU2` |
| OUTPUT típusa | `ZPR_EON_QUERY_MESSENGER_STATU1` |
| Deklarált kivétel | `CX_AI_SYSTEM_FAULT` |

A konstruktor `LOGICAL_PORT_NAME TYPE PRX_LOGICAL_PORT_NAME` opcionális paramétert fogad. Az osztály `CL_PROXY_CLIENT` leszármazott, a metódus a proxy runtime execute hívását végzi. A request/response belső komponenseit ebben a körben nem olvastuk vissza.

## Port-hozzárendelések

A DD03L meződefiníciói alapján az SRT_CFG_CLI_ASGN táblában olvastuk ki a névhez tartozó hozzárendeléseket. A lekérdezés kizárólag CLIENT, LP_NAME, PROXY_CLASS, PROTOCOL, HOST, PORT mezőket választott ki. Hitelesítési adat vagy jelszó nem lett lekérdezve/tárolva.

| Mandant | Logikai port | Beállított host | Protokoll | Tárolt port |
|---|---|---|---|---|
| 100 | `LOGPORT_QMS_SBOX` | `qms-scaler-sbox.apps.eon.com` | https | 00080 |
| 100 | `LOGPORT_QMS_DEV` | `qms-scaler-dev.apps.eon.com` | https | 00080 |
| 100 | `LOGPORT_QMS_QA` | `qms-scaler-qa.apps.eon.com` | https | 00080 |
| 100 | `LOGPORT_QMS_UAT` | `qms-scaler-uat.apps.eon.com` | https | 00080 |

Mind a négy rekord a `ZPR_CO_EON_QUERY_MESSENGER_STA` proxyosztályhoz tartozik. A sikeres szűrt lekérdezés total_rows értéke 4, a visszaadott sorlimit 20; a lista ebben a szűrésben nem csonkolt.

```abap
SELECT client, lp_name, proxy_class, protocol, host, port
  FROM srt_cfg_cli_asgn
  WHERE proxy_class = 'ZPR_CO_EON_QUERY_MESSENGER_STA'
```

A tárolt hozzárendelés nem bizonyítja az Inspire-végpont aktuális elérhetőségét, a teljes SOAMANAGER-konfiguráció aktív/default állapotát vagy a hitelesítés működését. Ezeket nem teszteltük. A SID-et a visszakapott válaszok nem közölték; a portok a kapcsolt SAP-rendszer 100-as mandantjához igazoltak.

## Következmény

A P_LPORT értéke a négy tényleges portnév közül a használni kívánt Inspire-környezetnek megfelelő név legyen. A korábbi javasolt `ZPR_MQ_QUERY` portnévhez ezen a proxyn nincs visszaadott hozzárendelés; `LOGPORT` nevű sor sem szerepel ebben a lekérdezésben. A név alapján SBOX, DEV, QA és UAT külön környezetekre utalnak, de a felhasználó célkörnyezetét nem választottuk ki automatikusan.

A helyi ZPR_MQ_PROXY deklarációi ebben a kizárólag ellenőrzési körben nem változtak; a korábbi feltételezett nevek helyett a fenti aktív proxy/request/response nevekre kell majd átvezetni őket, a komponensszerkezet egyeztetésével. SAP-objektum/adat módosítása, riportfuttatás és Inspire-hívás nem történt.
