FUNCTION zxweb_elo_eugy_kau_xml.
*"----------------------------------------------------------------------
*"*"Lokális interfész:
*"  IMPORTING
*"     REFERENCE(IV_MINTA) TYPE  TDOBNAME DEFAULT 'ZSAML2_KAU_REQUEST'
*"     REFERENCE(IV_DESTINATION) TYPE  TEXT80 OPTIONAL
*"     VALUE(IV_ISSUER) TYPE  TEXT20 OPTIONAL
*"     VALUE(IV_CEL) TYPE  TEXT20 OPTIONAL
*"     VALUE(IV_JOGALAP) TYPE  TEXT20 OPTIONAL
*"     VALUE(IV_SZERVEZET) TYPE  TEXT20 OPTIONAL
*"     VALUE(IV_ADATIGENYLO) TYPE  TEXT20 OPTIONAL
*"     VALUE(IV_FELHASZNALO) TYPE  TEXT20 OPTIONAL
*"     VALUE(IV_MUVELETKOD) TYPE  TEXT20 OPTIONAL
*"     REFERENCE(IV_LETOLT) TYPE  XFELD OPTIONAL
*"     REFERENCE(IV_ID) TYPE  STRING
*"     REFERENCE(IV_GUID) TYPE  SYSUUID_C
*"  EXPORTING
*"     REFERENCE(EV_XML) TYPE  STRING
*"     REFERENCE(EV_RETCODE) TYPE  CHAR3
*"----------------------------------------------------------------------
******************************************************************
*
* Projekt:   2021 KAÜ e-ügyintézés
* Fejleszto: Pál Tamás
*
* Release:  SAP NetWeaver 7.3
*
* Change history:
* Date                  User    Reason
* ---------------------------------------------------------------*
* 28.11.2021 14:08:21   X0134   Létrehozva
*----------------------------------------------------------------*

  DATA lr_cx_root     TYPE REF TO cx_root.

  DATA lt_lines       TYPE TABLE OF tline.
  DATA lt_xml         TYPE TABLE OF text100.

  DATA ls_line        TYPE tline.
  DATA ls_log         TYPE zxweb_kau_log.

  DATA: lv_xml        TYPE string.
  DATA: lv_signed     TYPE string.
  DATA: lv_retcode    TYPE char3.             "zusz_retcode.
  DATA: lv_eles       TYPE xfeld.
  DATA: lv_paramertek TYPE string.
*  DATA: lv_id         TYPE string.
  DATA: lv_tzone      TYPE timezone VALUE 'UTC+2'.
  DATA: lv_current_timestamp_utc TYPE char15. "xsddatetime_z.
  DATA: lv_longdatetime          TYPE string.
  DATA: lv_current_timestamp     TYPE xsddatetime_z.
  DATA: lv_file       TYPE string.
  DATA: lv_path       TYPE string.
  DATA: lv_name       TYPE string.
  DATA: lv_len        TYPE i.
  DATA: lv_regex      TYPE char30.
  DATA lv_ok          TYPE abap_bool.
  DATA lv_callbac_url TYPE string.
  DATA lv_rfc_dest    TYPE rfc_dest.

  CLEAR: ev_xml, ev_retcode.


* Feldolgozás try
  TRY.

*   XML minta olvasása
      CALL FUNCTION 'READ_TEXT'
        EXPORTING
*         CLIENT                  = SY-MANDT
          id                      = 'ST'
          language                = 'H'
          name                    = iv_minta
          object                  = 'TEXT'
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
      IF sy-subrc <> 0 OR lt_lines IS INITIAL.
        ev_retcode = 'EX1'.  "Minta olvasása sikertelen!
        RETURN.

      ENDIF.


*   XML minta feldolgozása
      CLEAR lv_xml.
      LOOP AT lt_lines INTO ls_line.
        lv_xml = |{ lv_xml }{ ls_line-tdline }|.

      ENDLOOP.


*   Paraméterek olvaása
      IF iv_issuer IS INITIAL.
        CALL METHOD zcl_xweb_utils=>get_global_data
          EXPORTING
            iv_paramname = 'EU_JKU_ISSUER'
            "i_defertek   = ''
          RECEIVING
            rv_value     = lv_paramertek.
        iv_issuer = lv_paramertek.

      ENDIF.

      IF iv_cel IS INITIAL.
        CALL METHOD zcl_xweb_utils=>get_global_data
          EXPORTING
            iv_paramname = 'EU_ONY_CEL'
            "i_defertek   = ''
          RECEIVING
            rv_value     = lv_paramertek.
        iv_cel = lv_paramertek.

      ENDIF.

      IF iv_jogalap IS INITIAL.
        CALL METHOD zcl_xweb_utils=>get_global_data
          EXPORTING
            iv_paramname = 'EU_ONY_JOGALAP'
            "i_defertek   = ''
          RECEIVING
            rv_value     = lv_paramertek.
        iv_jogalap = lv_paramertek.

      ENDIF.

      IF iv_szervezet IS INITIAL.
        CALL METHOD zcl_xweb_utils=>get_global_data
          EXPORTING
            iv_paramname = 'EU_ONY_SZERVEZETKOD'
            "i_defertek   = ''
          RECEIVING
            rv_value     = lv_paramertek.
        iv_szervezet = lv_paramertek.

      ENDIF.

      IF iv_adatigenylo IS INITIAL.
        CALL METHOD zcl_xweb_utils=>get_global_data
          EXPORTING
            iv_paramname = 'EU_ONY_ADATIGENYLO'
            "i_defertek   = ''
          RECEIVING
            rv_value     = lv_paramertek.
        iv_adatigenylo = lv_paramertek.

      ENDIF.

      IF iv_felhasznalo IS INITIAL.
        CALL METHOD zcl_xweb_utils=>get_global_data
          EXPORTING
            iv_paramname = 'EU_ONY_FELHASZNALO'
            "i_defertek   = ''
          RECEIVING
            rv_value     = lv_paramertek.
        iv_felhasznalo = lv_paramertek.

      ENDIF.

      IF iv_muveletkod IS INITIAL.
        CALL METHOD zcl_xweb_utils=>get_global_data
          EXPORTING
            iv_paramname = 'EU_ONY_MUVELETKOD'
            "i_defertek   = '
          RECEIVING
            rv_value     = lv_paramertek.
        iv_muveletkod = lv_paramertek.

      ENDIF.

*----my---add
*     Destination
      CALL METHOD zcl_xweb_utils=>get_global_data
        EXPORTING
          iv_paramname = 'KAU_DEST' "'URL_KAU_DEST_EUGY'
          "default ertek  = 'https://kau.teszt.gov.hu/proxy/saml/authnrequest?lang=HU'
        RECEIVING
          rv_value     = lv_paramertek.

      REPLACE `[DEST]` IN lv_xml WITH lv_paramertek.

*[SRVURL] call back service
*     URL paraméter olvasása
      CALL METHOD zcl_xweb_utils=>get_global_data
        EXPORTING
          iv_paramname = 'KAU_LOGIN_URL'   "'URL_KAU_LOGIN_EUGY'
          "defasult ertek  = 'https://dev-e-portal.eon-hungaria.com/ugyintezes/kau/back?'
        RECEIVING
          rv_value     = lv_paramertek.

      lv_callbac_url = |{ lv_paramertek }|.

      IF iv_guid IS NOT INITIAL.
        lv_callbac_url = |{ lv_paramertek }?guid={ iv_guid }|.
*ha mégis íg akkor a headerben
*~request_uri	/ugyintezes/kau/back?guid=bvOn6O2-TIXHgyK5dKDcHwGE0iOJ15dM
*~query_string  guid=bvOn6O2-TIXHgyK5dKDcHwGE0iOJ15dM
      ENDIF.
      REPLACE `[SRVURL]` IN lv_xml WITH lv_callbac_url.
*---------


*   Paraméterek kitöltése
*   [ID]
*      lv_id = cl_saml_util=>generate_id(  ).
      REPLACE ALL OCCURRENCES OF `[ID]` IN lv_xml WITH iv_id.

*   [LONGTIME]
      GET TIME STAMP FIELD lv_current_timestamp.
      lv_longdatetime = |{ lv_current_timestamp TIMESTAMP = ISO }|.
      lv_longdatetime = |{ lv_longdatetime(19) }.000Z|.

      REPLACE `[LONGTIME]`    IN lv_xml WITH lv_longdatetime. "`2018-03-01T18:47:06.360Z`.

      REPLACE `[ISSUER]`      IN lv_xml WITH iv_issuer.

      REPLACE `[CEL]`         IN lv_xml WITH iv_cel.

      REPLACE `[JOGALAP]`     IN lv_xml WITH iv_jogalap.

      REPLACE `[SZERVEZETKOD]`   IN lv_xml WITH iv_szervezet.

      REPLACE `[ADATIGENYLO]` IN lv_xml WITH iv_adatigenylo.

      REPLACE `[FELHASZNALO]` IN lv_xml WITH iv_felhasznalo.

      REPLACE `[MUVELETKOD]`  IN lv_xml WITH iv_muveletkod.

*   Sign XML
      lv_rfc_dest = zcl_xweb_utils=>get_global_data( iv_paramname = 'XMLSIGN_RFC' ).
      CALL FUNCTION 'ZXWEB_ELO_EUGY_XMLSIGN_JAVA'
      DESTINATION lv_rfc_dest
        EXPORTING
          iv_xml     = lv_xml
          iv_eles    = lv_eles
        IMPORTING
          ev_xml     = lv_signed
          ev_retcode = lv_retcode.

       lv_signed = |<?xml version="1.0" encoding="UTF-8"?>{ lv_signed }|.
       ev_xml = cl_http_utility=>encode_base64( lv_signed ).
*      ev_xml = lv_signed.

*     Log
      CLEAR ls_log.

      ls_log-id    = iv_id.
      ls_log-datum = sy-datum.
      ls_log-ido   = sy-uzeit.
      ls_log-reqresp = lv_signed.

      CALL FUNCTION 'ZXWEB_SAVE_KAU_LOG'
        EXPORTING
          ls_log = ls_log
        IMPORTING
          ev_ok  = lv_ok.


    CATCH cx_root INTO lr_cx_root.

  ENDTRY.


* Letöltés
  IF NOT iv_letolt IS INITIAL AND NOT ev_xml IS INITIAL.
    CALL FUNCTION 'SCMS_STRING_TO_FTEXT'
      EXPORTING
        text      = ev_xml
      IMPORTING
        length    = lv_len
      TABLES
        ftext_tab = lt_xml.

    lv_file = iv_letolt.

    CALL METHOD cl_gui_frontend_services=>file_save_dialog
*      EXPORTING
*        window_title              =
*        default_extension         =
*        default_file_name         =
*        with_encoding             =
*        file_filter               =
*        initial_directory         =
*        prompt_on_overwrite       = 'X'
      CHANGING
        filename = lv_name
        path     = lv_path
        fullpath = lv_file
*       user_action               =
*       file_encoding             =
      EXCEPTIONS
        cntl_error                = 1
        error_no_gui              = 2
        not_supported_by_gui      = 3
        invalid_default_file_name = 4
        OTHERS   = 5.

    IF sy-subrc EQ 0 AND lv_file IS NOT INITIAL.
      CALL METHOD cl_gui_frontend_services=>gui_download
        EXPORTING
*         bin_filesize              =
          filename = lv_file
*         filetype = 'ASC'
*        IMPORTING
*         filelength                =
        CHANGING
          data_tab = lt_xml
        EXCEPTIONS
          OTHERS   = 24.

    ENDIF.

  ENDIF.


ENDFUNCTION.