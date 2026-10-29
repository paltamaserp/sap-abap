class ZCL_PR_ADDRESS definition
  public
  create public .

public section.

  interfaces ZIF_PR_CONSTANTS .

  aliases C_CHANNEL
    for ZIF_PR_CONSTANTS~CHANNEL .
  aliases C_ERROR_TYPE
    for ZIF_PR_CONSTANTS~ERROR_TYPE .
  aliases C_PRINTER
    for ZIF_PR_CONSTANTS~PRINTER .
  aliases C_PRIORITY
    for ZIF_PR_CONSTANTS~PRIORITY .
  aliases C_XML
    for ZIF_PR_CONSTANTS~XML .

  data GS_CUSTOMER_ADDRESS type ZPRS_ADDRESS_DATA .
  data GS_POSTAL_ADDRESS type ZPRS_ADDRESS_DATA .
  data GS_PAYER_ADDRESS type ZPRS_ADDRESS_DATA .

  class-methods GET_CUSTOMER_ADDR
    importing
      !IV_PARTNER type BU_PARTNER
    returning
      value(RS_ADDRESS_DATA) type ZPRS_ADDRESS_DATA .
  class-methods GET_PREMISE_ADDR
    importing
      !IV_VSTELLE type VSTELLE
    returning
      value(RV_ADDR) type STRING .
  methods CONSTRUCTOR
    importing
      value(IS_FKKVKP) type FKKVKP
      value(IS_METADATA) type ZPRS_METADATA .
  methods GET_FORMED_CUSTOMER_ADDR
    returning
      value(RS_ADDR) type ZPRS_ADDRESS .
  methods GET_FORMED_PAYER_ADDR
    returning
      value(RS_ADDR) type ZPRS_ADDRESS .
  methods GET_FORMED_POSTAL_ADDR
    returning
      value(RS_ADDR) type ZPRS_ADDRESS .
  methods GET_CUSTOMER_ADDRESS
    returning
      value(RS_ADDR) type ZPRS_ADDRESS_DATA .
  methods GET_ONLY_CUSTOMER_ADDR
    returning
      value(RV_ADDR) type ZPRD_CUST_ADDR .
protected section.


  class-data GV_DUMMY_MESSAGE type CHAR1 .
  data GS_FKKVKP type FKKVKP .
  data GS_META_DATA type ZPRS_METADATA .

  class-methods GET_HOUSENUM_EXT
    importing
      !IS_ADDRESS_DATA type ZPRT_I_DEFAULT_BP_ADDRESS
    returning
      value(RV_HNUM_EXT) type ZPRD_HNUM_EXTENSION .
  class-methods GET_NAME
    importing
      !IS_ADDRESS_DATA type ZPRT_I_DEFAULT_BP_ADDRESS
    returning
      value(RV_NAME) type AD_NAMETXT .
  class-methods GET_STREET_AND_HOUSENUM
    importing
      !IS_ADDRESS_DATA type ZPRT_I_DEFAULT_BP_ADDRESS
    returning
      value(RV_STREET_AND_HNUM) type ZPRD_STREET_AND_HNUM .
  methods CREATE_PAYER_ADDR
    returning
      value(RS_ADDR) type ZPRS_ADDRESS_DATA .
  methods CREATE_POSTAL_ADDR
    returning
      value(RS_ADDR) type ZPRS_ADDRESS_DATA .
  methods FORMAT_ADDRLINES
    importing
      !IS_ADDRESS type ZPRS_ADDRESS_DATA
      !IV_HUNGARY type ABAP_BOOL
    changing
      !CS_ADDR type ZPRS_ADDRESS .
private section.
ENDCLASS.



CLASS ZCL_PR_ADDRESS IMPLEMENTATION.


  METHOD get_customer_addr.
*---------------------------------------------------------------*
* Rövid leírás: A vevő címe (BP default cím)
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
*---------------------------------------------------------------*
* Deklaráció
    DATA ls_address TYPE zprt_i_default_bp_address.

*---------------------------------------------------------------*
* Alapértelmezett cím CDS olvasása
    SELECT SINGLE *
      INTO CORRESPONDING FIELDS OF @ls_address
      FROM zprt_i_default_bp_address
      WHERE bp = @iv_partner.
    IF sy-subrc <> 0.
      MESSAGE e008 WITH iv_partner INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error USING MESSAGE.
    ENDIF.

*---------------------------------------------------------------*
* Név meghatározása
    rs_address_data-name_text = get_name( ls_address ).

*---------------------------------------------------------------*
* Utca és házszám
    rs_address_data-street_and_hnum = get_street_and_housenum( ls_address ).

*---------------------------------------------------------------*
* Házszám kiegészítés
    rs_address_data-hnum_extension = get_housenum_ext( ls_address ).

*---------------------------------------------------------------*
* Egyéb mezők
    rs_address_data-po_box    = ls_address-pobox.
    rs_address_data-country   = ls_address-country.
    rs_address_data-city      = ls_address-city.
    rs_address_data-bp        = ls_address-bp.
    rs_address_data-addr_id   = ls_address-addr_id.

*---------------------------------------------------------------*
* Irányítószám
    IF ls_address-pobox IS INITIAL.
      rs_address_data-post_code = ls_address-postalcode.
    ELSE.
      rs_address_data-post_code = ls_address-postalcode2.
    ENDIF.

  ENDMETHOD.


  METHOD get_housenum_ext.
*---------------------------------------------------------------*
* Rövid leírás: Nyomtatás
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
*---------------------------------------------------------------*
* Épület
    IF is_address_data-building IS NOT INITIAL.
      CONCATENATE is_address_data-building
                  'ép.'
                  INTO rv_hnum_ext SEPARATED BY space.
    ENDIF.

*---------------------------------------------------------------*
* Lépcsőház
    IF is_address_data-additionalstreetprefixname IS NOT INITIAL.
      CONCATENATE rv_hnum_ext
                  is_address_data-additionalstreetprefixname
                  'lh.'
                  INTO rv_hnum_ext SEPARATED BY space.
    ENDIF.

*---------------------------------------------------------------*
* Emelet
    IF is_address_data-floor IS NOT INITIAL.
      IF is_address_data-floor CO ' 0123456789'.
        CONCATENATE rv_hnum_ext
                    is_address_data-floor
                    'em.'
                    INTO rv_hnum_ext SEPARATED BY space.
      ELSE.
        CONCATENATE rv_hnum_ext
                    is_address_data-floor
                    INTO rv_hnum_ext SEPARATED BY space.
      ENDIF.
    ENDIF.

*---------------------------------------------------------------*
* Ajtó
    IF is_address_data-roomnumber IS NOT INITIAL.
      CONCATENATE rv_hnum_ext
                  is_address_data-roomnumber
                  'a.'
                  INTO rv_hnum_ext SEPARATED BY space.
    ENDIF.

  ENDMETHOD.


  METHOD get_name.
*---------------------------------------------------------------*
* Rövid leírás: Nyomtatás
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
*---------------------------------------------------------------*
* Deklaráció
    DATA lv_prefix_txt TYPE ad_prefixt.

*---------------------------------------------------------------*
* Prefix meghatározása ha van
    IF is_address_data-lastnameprefix IS NOT INITIAL.
      SELECT SINGLE prefix_txt
        INTO lv_prefix_txt
        FROM tsad4
        WHERE prefix_key = is_address_data-lastnameprefix.
    ENDIF.

*---------------------------------------------------------------*
* Név összeállítása partner típus alapján
    CASE is_address_data-type.
      WHEN 1.
        CONCATENATE lv_prefix_txt
                    is_address_data-academictitlename
                    is_address_data-lastname
                    is_address_data-middlename
                    is_address_data-firstname
                    INTO rv_name SEPARATED BY space.
      WHEN 2.
        CONCATENATE is_address_data-organizationbpname1
                    is_address_data-organizationbpname2
                    is_address_data-organizationbpname3
                    is_address_data-organizationbpname4
                    INTO rv_name SEPARATED BY space.
      WHEN 3.
        CONCATENATE is_address_data-groupbusinesspartnername1
                    is_address_data-groupbusinesspartnername2
                    INTO rv_name SEPARATED BY space.
    ENDCASE.

*---------------------------------------------------------------*
* Fölösleges spacek eltávolítása
    SHIFT rv_name LEFT DELETING LEADING space.

  ENDMETHOD.


  METHOD get_street_and_housenum.
*---------------------------------------------------------------*
* Rövid leírás: Utca és házszám
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
*---------------------------------------------------------------*
* Deklaráció
    DATA lv_street_type TYPE text30.

*---------------------------------------------------------------*
* Utcatípus meghatározása
    SELECT SINGLE strtype
      INTO lv_street_type
      FROM adrstrtypt
      WHERE langu     = sy-langu
      AND   country   = is_address_data-country
      AND   strtypeab = is_address_data-streetabbr.

*---------------------------------------------------------------*
* Utca, utcatípus, házszám
    CONCATENATE is_address_data-streetname
                lv_street_type
                is_address_data-housenumber
                INTO rv_street_and_hnum SEPARATED BY space.

  ENDMETHOD.


  METHOD constructor.
*---------------------------------------------------------------*
* Rövid leírás: Konstruktor
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
*---------------------------------------------------------------*
* Globális változó beállítása: szfsz és metadatok
    MOVE-CORRESPONDING is_fkkvkp TO gs_fkkvkp.
    MOVE-CORRESPONDING is_metadata TO gs_meta_data.

  ENDMETHOD.


  METHOD create_payer_addr.
*---------------------------------------------------------------*
* Rövid leírás: Fizető cím
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
*---------------------------------------------------------------*
* Deklaráció
    DATA ls_address TYPE zprt_i_default_bp_address.

*---------------------------------------------------------------*
* Eltérő fizető neve és címe
    CLEAR rs_addr.
    IF gs_fkkvkp-abwre IS NOT INITIAL.
      rs_addr = get_customer_addr( gs_fkkvkp-abwre ).
    ENDIF.

*---------------------------------------------------------------*
* Ha az eltérő fizető cím nem azonos az eltérő fizető címével
    IF gs_fkkvkp-adrre IS NOT INITIAL.
      SELECT SINGLE *
        INTO CORRESPONDING FIELDS OF @ls_address
        FROM zprt_i_default_bp_address
        WHERE addr_id = @gs_fkkvkp-adrre.
      IF sy-subrc <> 0.
        MESSAGE e008 WITH gs_fkkvkp-adrra INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error USING MESSAGE.
      ENDIF.

*---------------------------------------------------------------*
* Utca és házszám
      rs_addr-street_and_hnum = get_street_and_housenum( ls_address ).

*---------------------------------------------------------------*
* Házszám kiegészítés
      rs_addr-hnum_extension = get_housenum_ext( ls_address ).

*---------------------------------------------------------------*
* Egyéb mezők
      rs_addr-po_box    = ls_address-pobox.
      rs_addr-country   = ls_address-country.
      rs_addr-city      = ls_address-city.
      rs_addr-bp        = ls_address-bp.
      rs_addr-addr_id   = ls_address-addr_id.

*---------------------------------------------------------------*
* Irányítószám
      IF ls_address-pobox IS INITIAL.
        rs_addr-post_code = ls_address-postalcode.
      ELSE.
        rs_addr-post_code = ls_address-postalcode2.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  method CREATE_POSTAL_ADDR.
*---------------------------------------------------------------*
* Rövid leírás: Postázási cím előállítása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
*---------------------------------------------------------------*
* Alapértelmezett cím
    MOVE-CORRESPONDING gs_customer_address to rs_addr.

  endmethod.


  METHOD format_addrlines.
*---------------------------------------------------------------*
* Rövid leírás: Címsorok előállítása (utcás és postafiókos cím)
* Projekt:      CSHANA 2026
* Fejlesztő:    X0086 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.10.23.   X0086         Létrehozva (ECH-19109)
*---------------------------------------------------------------*
* Utcás cím: a címsorok az eddigiek szerint készülnek
    IF is_address-po_box IS INITIAL.
      IF iv_hungary EQ abap_true.
        cs_addr-addrline1 = is_address-city.
        cs_addr-addrline2 = is_address-street_and_hnum.
        cs_addr-addrline3 = is_address-hnum_extension.
        cs_addr-addrline4 = is_address-post_code.
      ELSE.
        cs_addr-addrline1 = is_address-street_and_hnum.
        cs_addr-addrline2 = is_address-hnum_extension.
        CONCATENATE is_address-city is_address-post_code INTO cs_addr-addrline3.
        cs_addr-addrline4 = space.
      ENDIF.

*---------------------------------------------------------------*
* Postafiókos cím: az utca és a házszám nem jelenik meg, a címzés
* a postafiókot és a postafiók irányítószámát mutatja
    ELSE.
      IF iv_hungary EQ abap_true.
        cs_addr-addrline1 = is_address-city.
        CONCATENATE 'Postafiók'(001) is_address-po_box INTO cs_addr-addrline2 SEPARATED BY space.
        cs_addr-addrline3 = space.
        cs_addr-addrline4 = is_address-post_code.
      ELSE.
        CONCATENATE 'Postafiók'(001) is_address-po_box INTO cs_addr-addrline1 SEPARATED BY space.
        cs_addr-addrline2 = space.
        CONCATENATE is_address-city is_address-post_code INTO cs_addr-addrline3.
        cs_addr-addrline4 = space.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD GET_FORMED_CUSTOMER_ADDR.
*---------------------------------------------------------------*
* Rövid leírás: Formázott vevői cím
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
* 2026.10.23.   X0086         Címsorok a FORMAT_ADDRLINES-ból,
*                             postafiókos cím (ECH-19109)
*---------------------------------------------------------------*
* Deklaráció
    DATA lv_hungary TYPE abap_bool.

*---------------------------------------------------------------*
* Címke
    rs_addr-mc_name1 = 'Vevő neve, címe:'.

*---------------------------------------------------------------*
* Címzett neve
    rs_addr-name_text = gs_customer_address-name_text.

*---------------------------------------------------------------*
* Címsor előállítása (a magyar/külföldi ágat a postai cím országa dönti el)
    IF gs_postal_address-country = 'HU'.
      lv_hungary = abap_true.
    ENDIF.

    format_addrlines(
      EXPORTING
        is_address = gs_customer_address
        iv_hungary = lv_hungary
      CHANGING
        cs_addr    = rs_addr ).

  ENDMETHOD.


  METHOD get_formed_payer_addr.
*---------------------------------------------------------------*
* Rövid leírás: Formázott fizetői cím
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
* 2026.10.23.   X0086         Címsorok a FORMAT_ADDRLINES-ból,
*                             postafiókos cím (ECH-19109)
*---------------------------------------------------------------*
* Deklaráció
    DATA lv_hungary TYPE abap_bool.

*---------------------------------------------------------------*
* Van eltérő fizető?
    if gs_payer_address is INITIAL.
      exit.
    endif.

*---------------------------------------------------------------*
* Címke
    rs_addr-mc_name1 = 'Számlafizető:'.

*---------------------------------------------------------------*
* Címzett neve
    rs_addr-name_text = gs_payer_address-name_text.

*---------------------------------------------------------------*
* Címsor előállítása
    IF gs_payer_address-country = 'HU'.
      lv_hungary = abap_true.
    ENDIF.

    format_addrlines(
      EXPORTING
        is_address = gs_payer_address
        iv_hungary = lv_hungary
      CHANGING
        cs_addr    = rs_addr ).

  ENDMETHOD.


  METHOD get_formed_postal_addr.
*---------------------------------------------------------------*
* Rövid leírás: Formázott postai cím
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
* 2026.10.23.   X0086         Címsorok a FORMAT_ADDRLINES-ból,
*                             postafiókos cím (ECH-19109)
*---------------------------------------------------------------*
* Deklaráció
    DATA lv_hungary TYPE abap_bool.

*---------------------------------------------------------------*
* Címzett neve
    rs_addr-name_text = gs_postal_address-name_text.

*---------------------------------------------------------------*
* Címsor előállítása
    IF gs_postal_address-country = 'HU'.
      lv_hungary = abap_true.
    ENDIF.

    format_addrlines(
      EXPORTING
        is_address = gs_postal_address
        iv_hungary = lv_hungary
      CHANGING
        cs_addr    = rs_addr ).

  ENDMETHOD.


  METHOD get_premise_addr.
*---------------------------------------------------------------*
* Rövid leírás: Fogyasztási hely címe
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
*---------------------------------------------------------------*
* Deklaráció
    DATA ls_addr         TYPE eadrdat.
    DATA ls_address_data TYPE zprs_address_data.
    DATA ls_cds_addr     TYPE zprt_i_default_bp_address.

*---------------------------------------------------------------*
* Fogyasztási hely cím kiolvasása
    CALL FUNCTION 'ISU_ADDRESS_PROVIDE'
      EXPORTING
        x_address_type             = 'P'
        x_vstelle                  = iv_vstelle
      IMPORTING
        y_eadrdat                  = ls_addr
      EXCEPTIONS
        not_found                  = 1
        parameter_error            = 2
        object_not_given           = 3
        address_inconsistency      = 4
        installation_inconsistency = 5
        OTHERS                     = 6.
    IF sy-subrc <> 0.
      MESSAGE e016 WITH iv_vstelle INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error USING MESSAGE.
    ENDIF.

*---------------------------------------------------------------*
* Utca és házszám
    ls_cds_addr-streetname  = ls_addr-street.
    ls_cds_addr-streetabbr  = ls_addr-streetabbr.
    ls_cds_addr-housenumber = ls_addr-house_num1.
    ls_cds_addr-country     = ls_addr-country.
    ls_address_data-street_and_hnum = get_street_and_housenum( ls_cds_addr ).

*---------------------------------------------------------------*
* Házszám kiegészítés
    ls_cds_addr-building    = ls_addr-haus_num2_vbs.
    ls_cds_addr-additionalstreetprefixname = ls_addr-str_erg2_vbs.
    ls_cds_addr-floor      = ls_addr-floor_vbs.
    ls_cds_addr-roomnumber = ls_addr-roomnumber_vbs.
    ls_address_data-hnum_extension = get_housenum_ext( ls_cds_addr ).

*---------------------------------------------------------------*
* Cím összefűzése
    CONCATENATE ls_addr-post_code1 ls_addr-city1
                ls_address_data-street_and_hnum ls_address_data-hnum_extension
                ls_addr-lagevbszus
                INTO rv_addr SEPARATED BY space.
*CSO  Irányítószám: Irányítószám (ADRC-POST_CODE1 CHAR10) (Kötelezően töltendő mező)
*CSO  Helység: Helység (ADRC-CITY1 CHAR 40) (Kötelezően töltendő mező)
*CSO  Helységrész/Városrész (ADRSTREET-CITY_PCODE CHAR8)!!!!!!!!
*CSO  Utca: Közterület megnevezése (ADRC-STREET CHAR60) (Kötelezően töltendő mező)
*CSO  Közterület típus szöveg (ADRC-STRTYPE CHAR30)
*CSO  Házszám: Házszám (ADRC-HOUSE_NUM1 CHAR10)
*CSO  Hrsz. (4.utca ADRC-STR_SUPPL3 CHAR40)
*FH	Kiegészítés: Kiegészítés a házszámhoz (ADRC-HAUS_NUM2 CHAR10)
* Az S/4 HANA felületen átnevezzük „Épület”
*FH	Utca: kieg 1. (Felkerül a számla POD részletezőn a fogyasztási hely címe elé.)
*(3. utca EVBS-STR_ERG2 TEXT40) Az S/4 HANA felületen átnevezzük „Lépcsőház”
*FH	Utca: kieg 2. (5. utca) (EVBS-STR_ERG4 TEXT40)
*FH	Emelet: Emelet (EVBS-FLOOR CHAR10)
*FH	Szobaszám: Ajtó (EVBS-ROOMNUMBER CHAR10)
*
*
*További általános megjegyzés:
*Az emelet mezőjének értékkészletébe, vannak további nem szám jellegű mezők, amelyeknél szintén nem feltétlenül kellene majd kiírni utána, hogy „em.”
*Ezek az Alagsor, Fsz, Félemelet, Mfsz, Pince, Tetőtér.. Ezeket egy beállító táblában elmentjük és amennyiben egyezés van, akkor nem írjuk ki az emelet számot.
*
*Amennyiben az alábbi mezők töltve vannak, akkor az idézőjel közötti részt fűzzük az értékhez.
*Épület kódja „ ép.”, Lépcsőház „ lh.”, Emelet „ em.”, Ajtó „ a.”.

  ENDMETHOD.


  method GET_CUSTOMER_ADDRESS.
*---------------------------------------------------------------*
* Rövid leírás: A már előállított vevői cím kinyerése
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
*---------------------------------------------------------------*
    MOVE-CORRESPONDING gs_customer_address to rs_addr.

  endmethod.


  METHOD get_only_customer_addr.
*---------------------------------------------------------------*
* Rövid leírás: Formázott vevői cím
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.08.   X0097         Létrehozva
*---------------------------------------------------------------*
* Címsor előállítása
    IF gs_postal_address-country = 'HU'.
      CONCATENATE gs_customer_address-city
                  gs_customer_address-street_and_hnum
      gs_customer_address-hnum_extension
      gs_customer_address-post_code
      INTO rv_addr SEPARATED BY space.
    ELSE.
      CONCATENATE       gs_customer_address-street_and_hnum
      gs_customer_address-hnum_extension
      gs_customer_address-city
      gs_customer_address-post_code
      INTO rv_addr SEPARATED BY space.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
