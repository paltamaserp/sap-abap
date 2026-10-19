# Messenger: SAP ADT MCP-ellenőrzés

Státusz: WIP. Dátum: 2026-10-13.

A felhasználó „Ellenőrizd mcp segítségével” kérése egy új elérési kísérletet engedélyezett a korábbi leállás után. A `GetTable(ZPR_SLOG_EMAIL, active)` sikeres volt, `success = true`, HTTP 200. Az alábbi adatelem-lekérések szintén sikeresek voltak. A `GetTypeInfo(ZPRT_SLOG_EMAIL, include_structure_fallback = false)` HTTP 422 hibával meghiúsult; ezután nem történt további SAP-hívás vagy más eszközös kerülőút.

## Igazolt objektumok a kapcsolt SAP-rendszerben

| Objektum / mező | Válaszból igazolt állapot |
|---|---|
| `ZPR_SLOG_EMAIL` | Aktív transzparens tábla, delivery class A, restricted maintenance |
| Kulcs | `MANDT` + `EXBILLDOCNO` |
| `EXBILLDOCNO` | `ZEBFD_PR_EXBILLDOCNO`, CHAR 20, domén CHAR20 |
| `TSTMP_PRINT` | `ZEBFD_PR_TMSTMP_PRINT`, CHAR 14, domén `ZEBFD_PR_TMSTMP` |
| `SENDING_STATUS` | `ZEBFD_SEND_STATUS`, CHAR 1, azonos nevű domén |
| `TSTMP_SENDING_STATUS` | `ZEBFD_PR_TMSTMP_SENDING_EMAIL`, CHAR 14, domén `ZEBFD_PR_TMSTMP` |
| `TSTMP_EMAIL_SENT` | `ZEBFD_PR_TMSTMP_EMAIL_SENT`, CHAR 14, domén `ZEBFD_PR_TMSTMP` |
| `ERROR_MESSAGE` | CHAR255 adatelem; a helyi új tábla CHAR 1000 feltételezésével eltérő |
| További üzleti mezők | `OPBEL`, `GPART`, `VKONT`, `EMAIL_ADDRESS` |

A sikeres adatelem-válaszok csomagja `ZECA_FUNC`. A válaszok nem közöltek SID-et vagy mandantot. A helyi `.mcp.json` SAP-szervernevei önmagukban nem igazolják az aktuális `sap_abap_adt` kapcsolat célrendszerét. **A táblameglét a kapcsolt rendszerben igazolt; a DHC-val való azonosság nem igazolt.**

Az időmezők típusa CHAR 14, nem DDIC TIMESTAMP. Az értékek tartalma, formátuma, időzónája és a `TSTMP_PRINT` üzleti jelentése a DDIC-típusból önmagában nem igazolt. Az ERROR_MESSAGE CHAR255 hivatkozását az aktív tábla válasza tartalmazza; a CHAR255 adatelem külön lekérése nem történt.

## Az aktív tábladefiníció visszakapott forrása

```abap
@EndUserText.label : 'ZPR_SLOG_EMAIL table type'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zpr_slog_email {

  key mandt            : mandt not null;
  key exbilldocno      : zebfd_pr_exbilldocno not null;
  opbel                : e_printdoc;
  tstmp_print          : zebfd_pr_tmstmp_print;
  gpart                : bu_partner;
  vkont                : vkont_kk;
  email_address        : ad_smtpadr;
  tstmp_email_sent     : zebfd_pr_tmstmp_email_sent;
  sending_status       : zebfd_send_status;
  tstmp_sending_status : zebfd_pr_tmstmp_sending_email;
  error_message        : char255;

}
```

## Sikertelen típuslekérés és fennmaradó ellenőrzések

A `ZPRT_SLOG_EMAIL` lekérés pontos visszajelzése:

```text
MCP error -32603: ADT error: AxiosError: Request failed with status code 422
```

A HTTP 422 nem HTTP 401, és nem igazolja, hogy a táblatípus hiányzik. A visszakapott hiba oka/szemantikája nem került külön megvizsgálásra. A további SAP-hívások leálltak; új ellenőrzési kísérlethez új kifejezett felhasználói kérés szükséges.

Még nincs ellenőrizve: `ZPRT_SLOG_EMAIL` definíciója, `EZPR_SLOG_EMAIL` és generált FM-jei, a consumer proxy és request/response típusai, SOAMANAGER logikai port, a naplótábla feltöltőprogramja és a kapcsolat célrendszer-azonossága.

## Következmény a helyi kódra az ellenőrzés idején

A meglévő `ZPR_SLOG_EMAIL` újrahasználata volt az elsődleges irány. Az ellenőrzés időpontjában a helyi WIP-riport még `ZPRT_MQ_EMAIL` nevekre és numerikus TIMESTAMP/CHAR 1000 mezőkre épült. Átvezetéskor a meglévő tábla teljes üzleti sorát meg kell tartani, és csak a státuszmezőket szabad frissíteni; a CHAR 14 időbélyegekhez explicit konverzió és megfelelő hibaág kell.

Ebben a körben a felhasználó ellenőrzést kért. ABAP-kód, aktív SAP-objektum vagy adat nem módosult. A jegyzet, az integrációs útmutató és a döntésnapló frissült. SAP-fordítás, ATC, ABAP Unit és funkcionális teszt nem történt.

A későbbi, azonos napi felhasználói kérésre a helyi kód már a `ZPR_SLOG_EMAIL` táblára és a létrehozott `ZPRB_SLOG_EMAIL` táblatípusra átvezetve. Aktuális állapot: [bemásolási útmutató](<../../../../../[03] projects/tomeges-nyomtatas-endre/04_ASSETS/abap/info.md/2026-10-13_messagequeue-dhc-bemasolas_WIP.md>). Ez nem jelent új SAP-ellenőrzést vagy új aktív visszaolvasást.
