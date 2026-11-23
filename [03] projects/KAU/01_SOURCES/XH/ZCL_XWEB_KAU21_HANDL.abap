class ZCL_XWEB_KAU21_HANDL definition
  public
  create public .

public section.

  interfaces IF_HTTP_EXTENSION .
protected section.
private section.

  data GT_HEADER type TIHTTPNVP .
  data GV_ID type STRING .
  data GV_GUID type SYSUUID_C .

  methods RFC_CONNECT_CHECK
    returning
      value(RV_OK) type ABAP_BOOL .
  methods GET_HEADER_DATA
    importing
      !IV_NAME type STRING
    exporting
      !EV_VALUE type ANY .
  methods GET_AUTHNREQUEST
    returning
      value(RV_REQUEST) type STRING .
  methods GET_RESPONSE
    importing
      !IV_SAML_RESPONSE type STRING optional
      value(IS_SESSION) type ZWB5T_SESSION optional
    exporting
      !EV_OK type XFELD
      !EV_MYRESPONSE type STRING
      !EV_UK_AZON type ZXWEBD_KAU_ID .
ENDCLASS.



CLASS ZCL_XWEB_KAU21_HANDL IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_XWEB_KAU21_HANDL->GET_AUTHNREQUEST
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RV_REQUEST                     TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD get_authnrequest.
******************************************************************
*
* Projekt:   KAU
* Fejleszto: Pal Tamas
* Change history:
* Date                  User    Reason
*---------------------------------------------------------------*
* 30.11.2021 11:02:01   X0134	  Létrehozva
*---------------------------------------------------------------*

  DATA lv_request_xml     TYPE string.
  DATA lv_certificate     TYPE string.
  DATA lv_current_timestamp TYPE xsddatetime_z.
  DATA lv_longdatetime    TYPE string.
  DATA lv_digestvalue     TYPE string.
  DATA lv_signaturevalue  TYPE string.
  DATA lv_callbac_url     TYPE string.
  DATA lv_eles            TYPE xfeld.
  DATA lv_tzon            TYPE timezone VALUE 'UTC+2'.
  DATA lv_current_timestamp_utc TYPE char15. "xsddatetime_z.
  DATA lv_paramnev        TYPE string.
  DATA lv_paramertek      TYPE string.
  DATA lv_retcode         TYPE char3.
  DATA lv_xml_signed      TYPE string.
  DATA lv_ok              TYPE abap_bool.
  DATA lv_rfc_dest        TYPE rfc_dest.

  DATA ls_line            TYPE tline.
  DATA ls_log             TYPE zxweb_kau_log.

  DATA lt_lines           TYPE TABLE OF tline.

  DATA lr_cx_root         TYPE REF TO cx_root.



* Teszt vagy éles KAU hívása
  IF sy-sysid = 'PXH'.
    lv_eles = 'X'.

  ELSE.
*kiolvasni a felhasználónak be van -e állítva az éles elérés?
*    SELECT SINGLE kau_eles
*    INTO lv_eles
*    FROM         "ZUSZ2_WEB_FELH
*      WHERE  = .
*
*    IF sy-subrc <> 0.
*      CLEAR lv_eles.
*    ENDIF.
  ENDIF.


  TRY.

      CALL FUNCTION 'READ_TEXT'
        EXPORTING
*         CLIENT                  = SY-MANDT
          id                      = 'ST'
          language                = 'H'
          name                    = 'ZSAML2_KAU_REQUEST'  "'ZSAML2_AUTHN_REQUEST_NOSIGN'
          object                  = 'TEXT'
*         ARCHIVE_HANDLE          = 0
*         LOCAL_CAT               = ' '
*       IMPORTING
*         HEADER                  = HEADER
*         OLD_LINE_COUNTER        = OLD_LINE_COUNTER
        TABLES
          lines                   = lt_lines
        EXCEPTIONS
          id                      = 1
          language                = 2
          name                    = 3
          not_found               = 4
          object                  = 5
          reference_check         = 6
          wrong_access_to_archive = 7
          OTHERS                  = 8.

      IF sy-subrc <> 0.
* Implement suitable error handling here

      ENDIF.

      CLEAR lv_request_xml.
      LOOP AT lt_lines INTO ls_line.
        lv_request_xml = |{ lv_request_xml }{ ls_line-tdline }|.

      ENDLOOP.


*     Destination
      CALL METHOD zcl_xweb_utils=>get_global_data
        EXPORTING
          iv_paramname = 'KAU_DEST' "'URL_KAU_DEST_EUGY'
          "iv_defertek  = 'https://kau.teszt.gov.hu/proxy/saml/authnrequest?lang=HU'
        RECEIVING
          rv_value     = lv_paramertek.

      REPLACE `[DEST]` IN lv_request_xml WITH lv_paramertek.

*[SRVURL] call back service
*     URL paraméter olvasása
      CALL METHOD zcl_xweb_utils=>get_global_data
        EXPORTING
          iv_paramname = 'KAU_LOGIN_URL'   "'URL_KAU_LOGIN_EUGY'
          "iv_defertek  = 'https://dev-e-portal.eon-hungaria.com/ugyintezes/kau/back?'
        RECEIVING
          rv_value     = lv_paramertek.

      lv_callbac_url = |{ lv_paramertek }loginguid={ gv_guid }|.
**      lv_callbac_url = |https://.hu/ugyintezes/kau/back?guid={ gv_id }|.
**TODO: Átadható -e valami paraméter ami alapján tudjuk ki jött vissza???

      REPLACE `[SRVURL]` IN lv_request_xml WITH lv_callbac_url.
*[ID]
      REPLACE ALL OCCURRENCES OF `[ID]` IN lv_request_xml WITH gv_id. "`c77424e1-5ac2-4ea6-b0f2-0c284810f23e`.

*[LONGTIME]
      GET TIME STAMP FIELD lv_current_timestamp.
      lv_longdatetime = |{ lv_current_timestamp TIMESTAMP = ISO }|.
      lv_longdatetime = |{ lv_longdatetime(19) }.000Z|.

      REPLACE `[LONGTIME]` IN lv_request_xml WITH lv_longdatetime. "`2018-03-01T18:47:06.360Z`.

*Sign XML
      lv_rfc_dest = zcl_xweb_utils=>get_global_data( iv_paramname = 'XMLSIGN_RFC' ).
      CALL FUNCTION 'ZXWEB_ELO_EUGY_XMLSIGN_JAVA'
      DESTINATION lv_rfc_dest
        EXPORTING
          iv_xml     = lv_request_xml
*         iv_mod     = 's'             " Egykarakteres kód
          iv_eles    = lv_eles          " Éles vagy teszt?
        IMPORTING
          ev_xml     = lv_xml_signed
          ev_retcode = lv_retcode.
      .

      lv_xml_signed = |<?xml version="1.0" encoding="UTF-8"?>{ lv_xml_signed }|.
      rv_request = cl_http_utility=>encode_base64( lv_xml_signed ).

*     Log
      CLEAR ls_log.

      ls_log-id = gv_id.
      ls_log-datum = sy-datum.
      ls_log-ido   = sy-uzeit.
      ls_log-reqresp = lv_xml_signed.
      ls_log-reqresp = lv_request_xml.

      CALL FUNCTION 'ZXWEB_SAVE_KAU_LOG'
        EXPORTING
          ls_log = ls_log
        IMPORTING
          ev_ok  = lv_ok.


    CATCH cx_root INTO lr_cx_root.

  ENDTRY.


ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_XWEB_KAU21_HANDL->GET_HEADER_DATA
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_NAME                        TYPE        STRING
* | [<---] EV_VALUE                       TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD get_header_data.
******************************************************************
*
* Projekt:   DÜK OTP Simple
* Fejleszto: Pál Tamás /X0134 /ERP
*
* Release:  SAP NetWeaver 7.3
*
* Change history:
* Date                  User    Reason
*---------------------------------------------------------------*
* 27.10.2021 12:46:28   X0134	  Létrehozva
*---------------------------------------------------------------*

  DATA ls_header_method TYPE ihttpnvp.
  DATA lv_get_data      TYPE string.

  lv_get_data = iv_name.
  TRANSLATE lv_get_data TO LOWER CASE.

  READ TABLE gt_header INTO ls_header_method
  WITH KEY name = lv_get_data.
  IF sy-subrc NE 0.
*   Error, request method read
    CLEAR ev_value.

  ELSE.
    ev_value = ls_header_method-value.

  ENDIF.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_XWEB_KAU21_HANDL->GET_RESPONSE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_SAML_RESPONSE               TYPE        STRING(optional)
* | [--->] IS_SESSION                     TYPE        ZWB5T_SESSION(optional)
* | [<---] EV_OK                          TYPE        XFELD
* | [<---] EV_MYRESPONSE                  TYPE        STRING
* | [<---] EV_UK_AZON                     TYPE        ZXWEBD_KAU_ID
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD get_response.
******************************************************************
*
* Projekt:   KAU
* Fejleszto: Pal Tamas
* Change history:
* Date                  User    Reason
*---------------------------------------------------------------*
* 30.11.2021 11:55:40   X0134   Létrehozva
*---------------------------------------------------------------*

  DATA lv_x_saml_resp_base64 TYPE xstring.
  DATA lv_len                TYPE i.
  DATA lv_resp_xmls          TYPE string.
  DATA lv_retcode            TYPE char3.
  DATA lv_xml_decoded        TYPE string.
  DATA lv_id                 TYPE zxwebd_saml2_id.
  DATA lv_id_req             TYPE zxwebd_saml2_id.
  DATA lv_destination        TYPE rfcdest.
  DATA lv_eles               TYPE xfeld.
  DATA lv_off                TYPE i.
  DATA lv_ok                 TYPE abap_bool.
  DATA  lv_naid              TYPE string VALUE '<saml2:NameID Format="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent" SPNameQualifier="urn:eksz.gov.hu:1.0:uktkk">'.
  DATA  lv_sein              TYPE string VALUE '<ds:Reference URI="'.
  DATA  lv_off1              TYPE i.
  DATA  lv_len1              TYPE i.
  DATA lv_sessionindex       TYPE zxwebd_sessionindex.
  DATA lv_nameid             TYPE zxwebd_nameid.
  DATA lv_rfc_dest           TYPE rfc_dest.

  DATA lr_obj                TYPE REF TO cl_abap_conv_in_ce.

  DATA ls_log                TYPE zxweb_kau_log.



  CALL FUNCTION 'SSFC_BASE64_DECODE'
    EXPORTING
      b64data                  = iv_saml_response
      b_check                  = abap_true
    IMPORTING
      bindata                  = lv_x_saml_resp_base64
    EXCEPTIONS
      ssf_krn_error            = 1
      ssf_krn_noop             = 2
      ssf_krn_nomemory         = 3
      ssf_krn_opinv            = 4
      ssf_krn_input_data_error = 5
      ssf_krn_invalid_par      = 6
      ssf_krn_invalid_parlen   = 7
      OTHERS                   = 8.

  IF sy-subrc <> 0.
*TODO:
  ENDIF.

  TRY.

      CALL METHOD cl_abap_conv_in_ce=>create
        EXPORTING
          input       = lv_x_saml_resp_base64
          encoding    = 'UTF-8'
          replacement = ''
        RECEIVING
          conv        = lr_obj.

    CATCH cx_parameter_invalid_range .

    CATCH cx_sy_codepage_converter_init .

  ENDTRY.


  lv_len = xstrlen( lv_x_saml_resp_base64 ).


  TRY.
      CALL METHOD lr_obj->read
        EXPORTING
          n    = lv_len
        IMPORTING
          data = lv_resp_xmls.

    CATCH cx_sy_conversion_codepage .

    CATCH cx_sy_codepage_converter_init .

    CATCH cx_parameter_invalid_type .

    CATCH cx_parameter_invalid_range .

  ENDTRY.


* TESZT:
  EXPORT lv_resp_xmls FROM lv_resp_xmls TO DATABASE indx(zz) ID 'KAU'.


*  IF sy-sysid = 'PXH'.
*    lv_destination = 'PXH_XMLSIGN'.
*    lv_eles = 'X'.
*
*  ELSE.
*    lv_eles = ls_felh-kau_eles.
*    lv_destination = ''.
*
*  ENDIF.

* Felhasználó törzs olvasása
*  SELECT SINGLE *
*    INTO ls_felh
*    FROM zusz2_web_felh
*   WHERE bname = me->uname.
*  IF sy-subrc <> 0.
*    CLEAR ls_felh.
*    ls_felh-bname = me->uname.
*  ENDIF.



* Aláírás ellenőrzés és titkosítás visszafejtése
  lv_rfc_dest = zcl_xweb_utils=>get_global_data( iv_paramname = 'XMLSIGN_RFC' ).
  CALL FUNCTION 'ZXWEB_ELO_EUGY_XMLSIGN_JAVA'
    DESTINATION lv_rfc_dest
    EXPORTING
      iv_xml     = lv_resp_xmls
      iv_mod     = 'v'  "Aláíráa ellenőrzés és visszafejtés
      iv_eles    = lv_eles
    IMPORTING
      ev_xml     = lv_xml_decoded
      ev_retcode = lv_retcode.

  IF lv_retcode = 'OK' AND NOT lv_xml_decoded IS INITIAL.

*   ID olvasása
    FIND 'ID="' IN lv_xml_decoded MATCH OFFSET lv_off.

    IF sy-subrc = 0.
      lv_off = lv_off + 7.
      lv_id = lv_xml_decoded+lv_off(36).

    ENDIF.

    FIND 'InResponseTo="' IN lv_xml_decoded MATCH OFFSET lv_off.
    IF sy-subrc = 0.
      lv_off = lv_off + 17.
      lv_id_req = lv_xml_decoded+lv_off(36).

    ENDIF.


*---------Menteni a kilépéshez
*   NameID
    FIND lv_naid IN lv_xml_decoded MATCH OFFSET lv_off1.
    lv_off1 = lv_off1 + 120.
    FIND '<' IN lv_xml_decoded+lv_off1 MATCH OFFSET lv_len1.
    lv_nameid = lv_xml_decoded+lv_off1(lv_len1).


*   SessionIndex
    FIND lv_sein IN lv_xml_decoded MATCH OFFSET lv_off1.
    lv_off1 = lv_off1 + 20.
    FIND '">' IN lv_xml_decoded+lv_off1 MATCH OFFSET lv_len1.
    lv_sessionindex = lv_xml_decoded+lv_off1(lv_len1).

*   Log írása
    CLEAR ls_log.

    ls_log-id = lv_id.
    ls_log-id_req = lv_id_req.
    ls_log-datum = sy-datum.
    ls_log-ido   = sy-uzeit.
    ls_log-reqresp = lv_xml_decoded.


*   KAU válasz feldolgozása
    CALL FUNCTION 'ZXWEB_ELO_EUGY_RESP_XML_PROCES'
      EXPORTING
        iv_xml    = lv_xml_decoded    " XML data
      IMPORTING
        ev_kau_id = ev_uk_azon. " Központi Azonosítási Ügynök ID

    ls_log-uk_azon = ev_uk_azon.

*   Mentés
    IF is_session-username IS INITIAL
      AND ev_uk_azon IS NOT INITIAL.

      is_session-authid = 'L000'.

      SELECT SINGLE username
      into is_session-username
      from zvpin_user_h
        WHERE authid EQ 'L000'
          AND kau_id eq ev_uk_azon.

    ENDIF.

    IF is_session-username IS NOT INITIAL.

      UPDATE zvpin_user_h
      SET nameid = lv_nameid
          sessionindex = lv_sessionindex
          ldate = sy-datum
          ltime = sy-uzeit
      WHERE authid   EQ is_session-authid
        AND username EQ is_session-username.

      IF sy-subrc = 0.
        COMMIT WORK.

      ELSE.
        ROLLBACK WORK.

      ENDIF.

    ENDIF.


    CALL FUNCTION 'ZXWEB_SAVE_KAU_LOG'
      EXPORTING
        ls_log = ls_log
      IMPORTING
        ev_ok  = lv_ok.

    ev_myresponse = ''.
    ev_ok = abap_true.

  ELSE.  "lv_retcode = 'OK' AND NOT lv_xml_decoded IS INITIAL.
*   Nem sikerült a KAU belépés adatainak feldolgozása

    ev_myresponse = ''.
    ev_ok = abap_false.
  ENDIF.  "lv_retcode = 'OK' AND NOT lv_xml_decoded IS INITIAL.


*a kikalkulát 4T adat xml-be és bae64-e menne a form-adatban!!
*  lv_response = cl_http_utility=>encode_base64( lv_response_xml ).

*  ev_myresponse = lv_resp_xmls.
*  ev_myresponse = lv_xml_decoded.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_XWEB_KAU21_HANDL->IF_HTTP_EXTENSION~HANDLE_REQUEST
* +-------------------------------------------------------------------------------------------------+
* | [--->] SERVER                         TYPE REF TO IF_HTTP_SERVER
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD if_http_extension~handle_request.
******************************************************************
*
* Projekt:   KAÜ
* Fejleszto: Pál Tamás /X0134 /ERP
*
* Release:  SAP NetWeaver 7.3
*
* Change history:
* Date                  User    Reason
*---------------------------------------------------------------*
* 27.10.2021 10:50:57   X0134	  Létrehozva
* 09.03.2023 16:34:20   X0134   INC2655320 – KAÜ módosítás
* 02.11.2023 15:05:51   X0134   INC3119967 - E.ON - Online ügyfélszolgálat felirat
*---------------------------------------------------------------*
  DATA lv_html_send         TYPE string.
  DATA lv_inactiv           TYPE sy-subrc.
  DATA lv_kau_ulr           TYPE string.
  DATA lv_script            TYPE string.
  DATA lv_script2           TYPE string.
  DATA lv_page_head         TYPE string.
  DATA lv_page_body         TYPE string.
  DATA lv_path              TYPE string.
  DATA lv_error             TYPE abap_bool VALUE abap_false.
  DATA lv_username          TYPE zeiu_username.
  DATA lv_guid              TYPE string.
  DATA lv_kauguid           TYPE string.
  DATA lv_cookie_guid       TYPE sysuuid_c32.
  DATA lv_ok                TYPE xfeld.
  DATA lv_last_partner      TYPE bu_partner.
  DATA lv_kau_dest          TYPE string.
  DATA lv_authnrequest      TYPE string.
  DATA lv_uk_azon           TYPE zxwebd_kau_id.
  DATA lv_relaystate        TYPE string.
  DATA lv_url_decode        TYPE saml2_boolean VALUE abap_false.
  DATA lv_respstring        TYPE string.
  DATA lv_myresponse        TYPE string.
  DATA lv_googletagmanager  TYPE string.
  DATA lv_message           TYPE string.
  DATA lv_empty             TYPE zxwebd_kau_id.

*  DATA ls_token             TYPE ihttpnvp.
  DATA ls_fields            TYPE ihttpnvp.
  DATA ls_session           TYPE zwb5t_session.
  DATA ls_form_field        TYPE ihttpnvp.
  DATA ls_cookie            TYPE ihttpcki.

  DATA lt_fields            TYPE tihttpnvp.
  DATA lt_form_fields       TYPE tihttpnvp.
  DATA lt_cookie            TYPE tihttpcki.

  DATA lr_request           TYPE REF TO if_http_request.



  IF zcl_xweb_utils=>get_global_data( iv_paramname = 'INAKTIV' ) EQ 'X'.
    lv_inactiv = 4.

  ELSE.
    IF me->rfc_connect_check( ) = abap_false.
      lv_inactiv = 4.

    ELSE.
      IF zcl_xweb_utils=>get_global_data( iv_paramname = 'KAU_AKTIV' ) NE 'X'.
        lv_inactiv = 4.

      ENDIF.

    ENDIF.

  ENDIF.


  CALL METHOD server->request->if_http_entity~get_cookies
    CHANGING
      cookies = lt_cookie.

  CALL METHOD server->request->if_http_entity~get_header_fields
    CHANGING
      fields = gt_header.

  server->request->get_form_fields(
*    EXPORTING
*      formfield_encoding = 0
    CHANGING
      fields             = lt_fields
  ).

  me->get_header_data(
   EXPORTING
     iv_name  = '~path'
   IMPORTING
     ev_value = lv_path ).
  TRANSLATE lv_path TO UPPER CASE.

*check path
  CASE lv_path.
    WHEN '/UGYINTEZES/KAU/LOGIN'.
      IF gv_id IS INITIAL .
        gv_id = cl_saml_util=>generate_id(  ).
      ENDIF.


    WHEN '/UGYINTEZES/KAU/BACK'.

      READ TABLE lt_fields
      INTO ls_fields
      WITH KEY name = 'samlresponse'.

      IF sy-subrc NE 0.
        lv_error = abap_true.

      ENDIF.
    WHEN OTHERS.
      lv_error = abap_true.

  ENDCASE.


*Hiba történt
  IF lv_inactiv EQ 4
    OR lv_error EQ abap_true.

    RETURN.
  ENDIF.


  CASE lv_path.

    WHEN '/UGYINTEZES/KAU/LOGIN'.

      CALL METHOD zcl_xweb_utils=>get_global_data
        EXPORTING
          iv_paramname = 'KAU_DEST' "'URL_KAU_DEST_EUGY'
          "iv_defertek  = 'https://kau.teszt.gov.hu/proxy/saml/authnrequest?lang=HU'
        RECEIVING
          rv_value     = lv_kau_ulr.

      READ TABLE lt_fields INTO ls_fields
      WITH KEY name = 'guid'.
      IF sy-subrc EQ 0.
        gv_guid = ls_fields-value.
        lv_kau_ulr = |{ lv_kau_ulr }&guid={ ls_fields-value }|.
      ENDIF.

*      lv_authnrequest = get_authnrequest( ).

      CALL FUNCTION 'ZXWEB_ELO_EUGY_KAU_XML'
        EXPORTING
*         iv_minta       = 'ZSAML2_KAU_REQUEST' " Név
*         iv_destination = iv_destination       " Destination
*         iv_issuer      = 'eon.hu'             " 20 karakteres szöveg
*         iv_cel  = iv_cel               " 20 karakteres szöveg
*         iv_jogalap     = iv_jogalap           " 20 karakteres szöveg
*         iv_szervezet   = iv_szervezet         " 20 karakteres szöveg
*         iv_adatigenylo = iv_adatigenylo       " 20 karakteres szöveg
*         iv_felhasznalo = iv_felhasznalo       " 20 karakteres szöveg
*         iv_muveletkod  = iv_muveletkod        " 20 karakteres szöveg
*         iv_letolt      = iv_letolt            " Jelölőmező
          iv_id   = gv_id
          iv_guid = gv_guid
        IMPORTING
          ev_xml  = lv_authnrequest
*         ev_retcode     = ev_retcode           " ZUSZ_RETCODE
        .


      lv_page_head = |<!DOCTYPE html><html lang="hu">| &
      |<head>| &
      |<title>E.ON - Online ügyfélszolgálat</title>| &
      |<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">| &
      |<meta http-equiv="X-UA-Compatible" content="IE=edge">| &
      |<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">| &
      |<meta name="content-language" content="hu, hun, hungarian">| &
      |<meta http-equiv="Pragma" content="no-cache">| &
      |<meta http-equiv="expires" content="0">| &
      |<meta http-equiv="Cache-Control" content="no-cache, must-revalidate, no-store">| &
      |<meta name="description" content="Megújul E.ON! Megújult vállalati jövőképpel és a jövő energiaszolgáltatási trendjeit alakító, aktív jelenléttel indult el az új E.ON">| &

      |<link rel="icon" type="image/vnd.microsoft.icon" href="https://www.eon.hu/content/dam/eon/eon-hungary/images/icons/favico/favico.ico">| &
      |<link rel="icon" type="image/vnd.microsoft.icon" href="https://www.eon.hu/content/dam/eon/eon-hungary/images/icons/favico/favico.ico">| &
      |<link rel="stylesheet" href="/sap/bc/bsp/sap/zwb5_ugyint/main.css" />| &

      |</head>|.

      lv_page_body =
        |<body onload="document.getElementById('redirectForm').hidden = true;document.getElementById('redirectForm').submit();">| &
*        |<body>| &

        |<form id="redirectForm" action="| &
        |{ lv_kau_ulr }| &
        |" method="post">| &

        |<input type="hidden" name="SAMLRequest"  value="| &
        |{ lv_authnrequest }| &
        |"/>| &

        |<input type="hidden" name="RelayState" value="QXV0aG5SZXF1ZXN0IFJlbGF5U3RhdGUgZm9yIA=="/>| &

        |<table width="100%" height="100%" cellspacing="0" cellpadding="0" border="0">| &
        |<tr><td align="center">| &
        |Ha látja ezt a feliratot, kérem| &
        |<input type="submit" value="nyomja meg a gombot!"/>| &
        |</td></tr>| &
        |</table>| &

        |</form>| &

        |<table width="100%" height="100%" cellspacing="0" cellpadding="0" border="0">| &
        |<tr><td align="center">| &
        |<span style="font-family:Arial;font-size:x-small">Átirányítás folyamatban!</span>| &
        |</td></tr>| &
        |</table>| &

        |</body>| &
        |</html>|.


    WHEN '/UGYINTEZES/KAU/BACK'.

      READ TABLE lt_fields INTO ls_fields
      WITH KEY name = 'samlresponse'.

      lv_relaystate = server->request->get_form_field_cs(
                      cl_http_saml20=>co_relay_state ).

      IF lv_url_decode EQ abap_true.
        lv_respstring = cl_http_utility=>unescape_url( ls_form_field-value ).
      ELSE.
        lv_respstring = ls_fields-value.
      ENDIF.

      CLEAR: ls_cookie, ls_session.
      READ TABLE lt_cookie INTO ls_cookie
      WITH KEY name = 'guid'.

      IF sy-subrc EQ 0.
        SELECT SINGLE *
        INTO ls_session
        FROM zwb5t_session
          WHERE guid EQ ls_cookie-value.

      ELSE.
        READ TABLE lt_fields INTO ls_fields
        WITH KEY name = 'guid'.
        IF sy-subrc EQ 0.
          SELECT SINGLE *
          INTO ls_session
          FROM zwb5t_session
            WHERE guid EQ ls_fields-value.

        ENDIF.
      ENDIF.

      CALL METHOD get_response
        EXPORTING
          iv_saml_response = lv_respstring      " SAML response
          is_session       = ls_session         " Session
        IMPORTING
          ev_ok            = lv_ok              " Jelölőmező
          ev_myresponse    = lv_myresponse      " Response
          ev_uk_azon       = lv_uk_azon.       " Központi Azonosítási Ügynök ID

      IF lv_ok NE abap_true OR lv_uk_azon EQ lv_empty OR lv_uk_azon IS INITIAL.
        IF ls_cookie-value IS NOT INITIAL.
          lv_kau_ulr = '/ugyintezes/accountsettings'.
          lv_guid = ls_cookie-value.
          cl_wd_utilities=>get_otr_text_by_alias(
            EXPORTING
              alias      = 'ZWEB/KAU_NO_IDENTIFI'
*             language   = language
            RECEIVING
              alias_text = lv_message
          ).
*          lv_message = 'Nem történt beazonosítás a KAÜ bejelentkezésnél!'.
          WAIT UP TO 3 SECONDS.

        ELSE.
          lv_kau_ulr = '/ugyintezes/login'.
          cl_wd_utilities=>get_otr_text_by_alias(
            EXPORTING
              alias      = 'ZWEB/KAU_NO_IDENTIFI'
*             language   = language
            RECEIVING
              alias_text = lv_message
          ).
*         lv_message = 'Nem történt beazonosítás a KAÜ bejelentkezésnél!'.
          WAIT UP TO 3 SECONDS.

        ENDIF.

      ELSE.

        SELECT SINGLE username last_partner
        INTO (lv_username, lv_last_partner)
        FROM zvpin_user_h
          WHERE kau_id EQ lv_uk_azon.

        IF sy-subrc NE 0.

          IF ls_session-username IS NOT INITIAL
            AND lv_uk_azon IS NOT INITIAL.
*SAVE
            UPDATE zvpin_user_h
            SET kau_id = lv_uk_azon
            WHERE authid   EQ 'L000'
              AND username EQ ls_session-username.

            lv_guid = ls_fields-value.
            lv_kau_ulr = '/ugyintezes/accountsettings'.

          ELSE.
            lv_kau_ulr = '/ugyintezes/kauparing'.

          ENDIF.


          IF lv_kau_ulr = '/ugyintezes/kauparing'.

            TRY.
                lv_cookie_guid = cl_system_uuid=>create_uuid_c32_static( ).
                lv_kauguid = lv_cookie_guid.

              CATCH cx_uuid_error.

            ENDTRY.

            cl_bsp_server_side_cookie=>set_server_cookie(
                name                  = 'KAUPARING'
                application_name      = 'KAUPARING'
                application_namespace = 'KAU'
                username              = 'KAU'
                session_id            = lv_kauguid
                data_value            = |{ lv_uk_azon }|
                data_name             = 'KAUGUID'
*                expiry_time_abs       = expiry_time_abs
*                expiry_date_abs       = expiry_date_abs
                expiry_time_rel       = 3600   "egy óra
*                expiry_date_rel       = expiry_date_rel
                   ).

          ENDIF.


        ELSE.
*login - guid-al?
          lv_kau_ulr = '/ugyintezes/home'.

*check is used
          IF lv_username NE ls_session-username.

            IF ls_session-username IS NOT INITIAL.
              lv_message = 'KAÜ bejelentkezésadatok már felhasználva!'.
              lv_kau_ulr = '/ugyintezes/accountsettings'.
            ENDIF.

            SELECT SINGLE guid
            INTO lv_guid
            FROM zwb5t_session
            WHERE authid   EQ 'L000'
              AND username EQ ls_session-username.

           IF sy-subrc NE 0.

              CLEAR ls_session.
              ls_session-mandt = sy-mandt.
              ls_session-guid  = zcl_wb5_utilities=>get_guid( ).
              ls_session-authid   = 'L000'.
              ls_session-username = lv_username.

              IF lv_last_partner IS NOT INITIAL.
                ls_session-partner = lv_last_partner.

              ELSE.
                SELECT SINGLE partner
                INTO ls_session-partner
                FROM zvpin_user
                WHERE username_usr EQ ls_session-username.

              ENDIF.

              zcl_wb5_utilities=>set_session(
                EXPORTING
                  is_session = ls_session " Session
               IMPORTING
*             es_session = es_session " Session
                  ev_ok      = lv_ok      " Jelölőmező
              ).

              IF lv_ok EQ abap_true.
                lv_guid = ls_session-guid.

              ENDIF.

            ENDIF.

          ELSE.

            SELECT SINGLE guid
            INTO lv_guid
            FROM zwb5t_session
            WHERE authid   EQ 'L000'
              AND username EQ lv_username.

*TODO: nincs meg akkor klszíteni kell egy újja!!
            IF sy-subrc NE 0.

              CLEAR ls_session.
              ls_session-mandt = sy-mandt.
              ls_session-guid  = zcl_wb5_utilities=>get_guid( ).
              ls_session-authid   = 'L000'.
              ls_session-username = lv_username.

              IF lv_last_partner IS NOT INITIAL.
                ls_session-partner = lv_last_partner.

              ELSE.
                SELECT SINGLE partner
                INTO ls_session-partner
                FROM zvpin_user
                WHERE username_usr EQ ls_session-username.

              ENDIF.

              zcl_wb5_utilities=>set_session(
                EXPORTING
                  is_session = ls_session " Session
               IMPORTING
*             es_session = es_session " Session
                  ev_ok      = lv_ok      " Jelölőmező
              ).

              IF lv_ok EQ abap_true.
                lv_guid = ls_session-guid.

              ENDIF.

            ENDIF.
          ENDIF.

        ENDIF.

      ENDIF.


      CONCATENATE
          `<!-- Google Tag Manager -->`
          `<script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':`
          `   new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],`
          `   j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=`
          `   'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);`
          ` })(window,document,'script','dataLayer','GTM-TD7WLX7');</script>`
          `<!-- End Google Tag Manager -->`
         INTO lv_googletagmanager.

      CONCATENATE
      `function setCookie(cname, cvalue, exdays) {`
        `var d = new Date();`
        `d.setTime(d.getTime() + (exdays*24*60*60*1000));`
        `var expires = "expires="+ d.toGMTString();`
        `document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/";`
      `}`
      INTO lv_script2.

      lv_page_head = |<!DOCTYPE html><html lang="hu">| &
        |<head>| &
        |<title>E.ON - Online ügyfélszolgálat</title>| &
        |<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">| &
        |<meta http-equiv="X-UA-Compatible" content="IE=edge">| &
        |<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">| &
        |<meta name="content-language" content="hu, hun, hungarian">| &
        |<meta http-equiv="Pragma" content="no-cache">| &
        |<meta http-equiv="expires" content="0">| &
        |<meta http-equiv="Cache-Control" content="no-cache, must-revalidate, no-store">| &
        |<meta name="description" content="Megújul E.ON! Megújult vállalati jövőképpel és a jövő energiaszolgáltatási trendjeit alakító, aktív jelenléttel indult el az új E.ON">| &

        |{ lv_googletagmanager }| &

        |<script >| &
        |{ lv_script2 }| &
        |</script>| &

        |<link rel="icon" type="image/vnd.microsoft.icon" href="https://www.eon.hu/content/dam/eon/eon-hungary/images/icons/favico/favico.ico">| &
        |<link rel="icon" type="image/vnd.microsoft.icon" href="https://www.eon.hu/content/dam/eon/eon-hungary/images/icons/favico/favico.ico">| &
        |<link rel="stylesheet" href="/sap/bc/bsp/sap/zwb5_ugyint/main.css" />| &
        |</head>|.


      lv_page_body = |<body>| &
        |<NoScript>| &
        |<div>| &
        |<h5>It looks like this page does not have JavaScript enabled.</h5>| &
        |</div>| &
        |</NoScript>| &
        |<div id="app"></div>| &

        |<script >| &
        |setCookie("goto", "{ lv_kau_ulr }", 30); | &
        |setCookie("guid", "{ lv_guid }", 30); | &
        |setCookie("kauguid", "{ lv_kauguid }", 30); | &
        |setCookie("system", "{ sy-sysid }", 30); | &
        |setCookie("message", "{ lv_message }", 30); | &
        |</script >| &
        |<script src="/sap/bc/bsp/sap/zwb5_ugyint/bundle.js"></script>| &
        |</body>| &
        |</html>|.

  ENDCASE.



  lv_html_send = |{ lv_page_head }{ lv_page_body }|.

* A válasz
  if_http_extension~flow_rc = if_http_extension=>co_flow_ok.
  server->response->set_status( code = '200' reason = 'OK' ).
  server->response->set_header_field( name = if_http_header_fields=>content_type
                                      value = 'text/html' ).
  server->response->set_cdata( lv_html_send ).

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_XWEB_KAU21_HANDL->RFC_CONNECT_CHECK
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RV_OK                          TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD rfc_connect_check.
******************************************************************
*
* Projekt:   KAÜ
* Fejleszto: Pál Tamás /X0134 /ERP
*
* Release:  SAP NetWeaver 7.3
*
* Change history:
* Date                  User    Reason
*---------------------------------------------------------------*
* 11.01.2018 13:16:26   X0134	  Létrehozva
*---------------------------------------------------------------*
  DATA lv_dest        TYPE rfcdest.
  DATA lv_rfcmess     TYPE text100.
  DATA lv_empty_prtip TYPE zeiu_partner_tip.

  DATA ls_rfc_dest    TYPE rfcdest.
  DATA lt_rfc_dest    TYPE TABLE OF rfcdest.


  SELECT rfcdest
  INTO TABLE lt_rfc_dest
  FROM zinetugyfsz_rfc
    WHERE systemid  EQ sy-sysid
    AND mandant     EQ sy-mandt
    AND partner_tip NE lv_empty_prtip.

  IF sy-subrc EQ 0.

    SORT lt_rfc_dest.
    DELETE ADJACENT DUPLICATES FROM lt_rfc_dest.

    LOOP AT lt_rfc_dest INTO ls_rfc_dest.

      CALL FUNCTION 'RFCPING'
        DESTINATION ls_rfc_dest
        EXCEPTIONS
          system_failure        = 1 MESSAGE lv_rfcmess
          communication_failure = 2 MESSAGE lv_rfcmess.

      CASE sy-subrc.
        WHEN 0.

        WHEN 1.
*    Hiba - system_failure
          rv_ok = abap_false.
          EXIT.
        WHEN 2.
*    Hiba - communication_failure
          rv_ok = abap_false.
          EXIT.
      ENDCASE.

    ENDLOOP.

  ENDIF.

  rv_ok = 'X'.

ENDMETHOD.
ENDCLASS.