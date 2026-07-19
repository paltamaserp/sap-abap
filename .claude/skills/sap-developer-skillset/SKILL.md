---
name: sap-developer-skillset
description: SAP developer competency map and project reference for the EON CS HANA project (IKT-18 – Ügyfélportál OData Szervizek). Use for SAP Gateway / OData V2 work (SEGW, DPC_EXT, provider classes), CRM IS-U development, RAP/ABAP on HANA, and the project's conventions — naming, transport DHCK901206, package ZEPT_GW, and the specific portal services (PT_xxx).
---

# SAP Developer Skillset – EON CS HANA

Reference skill describing the SAP development competencies relevant to this project, plus the concrete project-specific conventions for the **IKT-18 – Ügyfélportál OData Szervizek** work.

## When to use this skill

Activate whenever a task touches:

- **SAP Gateway / OData V2**: SEGW service modeling, `DPC_EXT` data provider class extension, provider classes, `$expand` / `$batch` / `$filter` / Deep Insert / e-Tags, MERGE/PATCH handlers, stream (`$value`) endpoints.
- **CRM / IS-U**: Business Partner, Interaction Records (ÜK), BOL/GENIL, CRM Web UI, middleware/BDOC, IS-U reader function modules.
- **ABAP on HANA / RAP**: CDS-based OData, push-down logic, clean-core development.
- Any object using this project's naming or transport conventions (`ZPORTAL_DPC_EXT`, `ZCL_PTxxx_..._PROVIDER`, transport `DHCK901206`, package `ZEPT_GW`).

For general ABAP coding standards and naming (DGL 7.0), also apply [[saphana-abap-hana-guidelines]].

---

## 1. ABAP Fejlesztő – Alapkompetenciák

### Technikai (Hard) Skillek

| Skill | Leírás |
|---|---|
| **ABAP OOP** | Objektumorientált ABAP (interfészek, osztályok, öröklés) |
| **SAP S/4HANA & ABAP on HANA** | Adatintenzív logika adatbázisrétegbe tolása, CDS nézetek |
| **BAPI / BADI** | Function module hívások és SAP enhancement pontok implementálása |
| **Web Dynpro ABAP** | Web alapú SAP alkalmazások fejlesztése NetWeaver platformon |
| **Smart Forms / Adobe Forms** | SAP nyomtatványok fejlesztése grafikus eszközökkel |
| **SAP modul ismeret** | FICO, MM, SD, HR, IS-U – üzleti folyamatok ismerete |
| **Debugging** | ABAP debugger, rendszerintegráció hibakeresés, ST22, SLG1 |
| **RAP (RESTful ABAP)** | Modern ABAP fejlesztési modell S/4HANA clean core elvekhez |
| **SAP BTP** | Side-by-side extension, Event Mesh, API Management, CPI |
| **DevOps / CI-CD** | GitHub, CTS+, Jenkins, transport pipeline kezelés |

### Soft Skillek
- Analitikus gondolkodás, cross-funkcionális csapatmunka
- Írásos és szóbeli kommunikáció (spec írás, review)
- Változáskövetés, alkalmazkodás új technológiákhoz

### Releváns Tanúsítványok
- SAP Certified Development Associate – ABAP with SAP NetWeaver
- SAP S/4HANA Development / Fiori/UI5 / SAP Cloud Platform

---

## 2. SAP Gateway / OData Fejlesztő – Kompetenciák

### OData & REST Alapok

| Skill | Leírás |
|---|---|
| **OData V2 protokoll** | EntitySet, EntityType, NavigationProperty, Association definíció |
| **REST elvek** | HTTP metódusok (GET, POST, MERGE/PATCH, DELETE), státuszkódok |
| **SEGW (Service Builder)** | Adatmodell, CRUD műveletek, kód-generálás, RFC/BOR generator |
| **DPC_EXT adapter** | Data Provider Class kiterjesztés – kulcskiolvasás, provider hívás, response mapping |
| **CDS alapú OData** | CDS nézetek publikálása Gateway szervizként, RAP/OData integráció |
| **Haladó OData műveletek** | `$expand`, Deep Insert, `$batch`, e-Tags, `$filter`, `$orderby` |
| **SAPUI5 / Fiori** | OData-t fogyasztó frontend alkalmazások fejlesztése |
| **SAP BAS** | SAP Business Application Studio, Fiori app fejlesztés |

### Architektúra & Üzemeltetés

| Terület | Eszköz / Tudás |
|---|---|
| Service regisztráció | `/IWFND/MAINT_SERVICE` |
| Hibaelemzés | `/IWFND/ERROR_LOG`, `/IWBEP/ERROR_LOG`, `ST22` |
| Gateway telepítés | Embedded deployment (S/4HANA), Fiori Frontend Server |
| Biztonság | OData autentikáció, szerepkör-kezelés |

### Tanulási Útvonal
- **GW100** – SAP Gateway: Building OData Services (SAP Learning)
- SAP S/4HANA 2023+ alapú frissített tartalom

---

## 3. SAP IS-U / CRM Fejlesztő – Kompetenciák

### Technikai Skillek

| Skill | Leírás |
|---|---|
| **CRM adatmodell** | Business Partner, tranzakciókezelés, tevékenységkezelés |
| **IS-U integráció** | IS-U – CRM adatkapcsolat, energia számlázási folyamatok |
| **BOL/GENIL** | Business Object Layer, Generic Interaction Layer modell |
| **CRM Web UI** | UI komponensek, Presentation/Business Layer, Enhancement Tool |
| **CRM middleware** | Queue és BDOC debug, middleware fejlesztés és karbantartás |
| **Interaction Records (ÜK)** | Ügyfél kontaktus rögzítés: Mdt, Osztály, Fajta beállítások |
| **Integráció** | IDoc, BAPI, Web Service (SOAP/REST) integrációs technikák |
| **Custom Adapter Objects** | Egyedi CRM adapter objektumok fejlesztése |

### Tesztelés & Dokumentáció
- Technikai specifikáció írás (high-level és részletes)
- Unit, system, integrációs és elfogadási tesztek
- Transport request kezelés, coding standards betartása

### Tanúsítványok
- SAP CRM / C/4HANA / S/4HANA tanúsítványok
- SAP ABAP / NetWeaver Development Associate

---

## 4. Projekt-specifikus Skillset (EON CS HANA)

A jelen projekt (**IKT-18 – Ügyfélportál OData Szervizek**) szempontjából kiemelt kompetenciák:

| Kompetencia | Hol szükséges |
|---|---|
| OData V2 modellezés (SEGW) | Minden szerviz – EntityType, EntitySet, Association |
| DPC_EXT adapter implementáció | `ZPORTAL_DPC_EXT` – minden HTTP metódus handler |
| Provider osztály fejlesztés | `ZCL_PTxxx_..._PROVIDER` – üzleti logika elkülönítése |
| CRM Interaction Record rögzítés | PT_007, PT_029 és minden ÜK-t rögzítő szerviz |
| IS-U olvasó FM hívások | Installation, Premises, MeterReadingList, Meterread |
| MERGE / PATCH implementáció | AccountAddressUsages, CAEmails, ContractAccounts, Notification |
| PDF stream kezelés | InvoicePDFs – `HasStream=true`, `$value` endpoint |
| Navigációs lekérdezés | Accounts → BankAccounts, AccountAddress → UsageTypes |
| Hibakeresés / logging | `/IWFND/ERROR_LOG`, `/IWBEP/ERROR_LOG`, `ST22` |
| Transport & csomag kezelés | DHCK901206 transport, `ZEPT_GW` csomag |

---

## 5. Hasznos Források

- [SAP Developer Center](https://developers.sap.com/)
- [Building OData Services with SAP Gateway – SAP Learning](https://learning.sap.com/courses/building-odata-services-with-sap-gateway)
- [SAP Gateway and OData – SAP PRESS](https://www.sap-press.com/sap-gateway-and-odata_5759/)
- [SAP ABAP on HANA: Skills You Must Learn in 2026](https://technicalgyanguru.com/sap-abap-on-hana-skills-2026/)
- [SAP ABAP Developer Skills – iMocha](https://www.imocha.io/skill-mapping/skills-required-for-sap-abap-developer)
- [SAP IS-U/CRM Developer – British Gas job description](https://en.wizbii.com/company/british-gas/job/bgis31530-sap-isu-crm-developer)
- [What is an SAP CRM Developer – Teamcubate](https://teamcubate.com/blogs/what-is-an-sap-crm-developer)
