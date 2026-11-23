FUNCTION zxweb_elo_eugy_resp_xml_proces.
*"----------------------------------------------------------------------
*"*"Lokális interfész:
*"  IMPORTING
*"     REFERENCE(IV_XML) TYPE  STRING
*"  EXPORTING
*"     REFERENCE(EV_KAU_ID) TYPE  ZXWEBD_KAU_ID
*"----------------------------------------------------------------------

  DATA lr_xml       TYPE REF TO cl_xml_document.
  DATA lr_root      TYPE REF TO if_ixml_node.
  DATA lr_node      TYPE REF TO if_ixml_node.
  DATA lv_name      TYPE string.
  DATA lv_attr      TYPE string.
  DATA lr_child     TYPE REF TO if_ixml_node.
  DATA lv_value_b64 TYPE string.
  DATA lv_retcode   TYPE sysubrc.
  DATA lv_value     TYPE string.


* XML parse
  CREATE OBJECT lr_xml.
  CALL METHOD lr_xml->parse_string
    EXPORTING
      stream = iv_xml.

* Titkosított blokkok feldolgozása
*  CALL METHOD lr_xml->get_first_node
*    RECEIVING
*      node   = lr_root.

  CALL METHOD lr_xml->find_node
    EXPORTING
      name = '/saml2p:Response/saml2p:Extensions/saml2:AttributeStatement' "/saml2:Attribute/saml2:AttributeValue'
*     root =
    RECEIVING
      node = lr_root.

  IF NOT lr_root IS INITIAL.

    lr_node = lr_root->get_first_child( ).
    WHILE NOT lr_node IS INITIAL.
      CALL METHOD lr_xml->get_node_name
        EXPORTING
          node  = lr_node
        RECEIVING
          value = lv_name.

      IF lv_name = 'Attribute'.

        CALL METHOD lr_xml->get_node_attribute
          EXPORTING
            node  = lr_node
            name  = 'Name'
          RECEIVING
            value = lv_attr.

        CASE lv_attr.

*-----------4T----
*QS: jelenleg nem kell, de később kelleni fog.
          WHEN 'urn:eksz.gov.hu:1.0:4t'.
*        lr_child = lr_node->get_first_child( ).
*        CLEAR lv_value_b64.
*
*        CALL METHOD lr_xml->get_node_data
*          EXPORTING
*            node       = lr_child
*          IMPORTING
*            dataobject = lv_value_b64
*            retcode    = lv_retcode.
*
*        CLEAR lv_value.
*
*        CALL FUNCTION 'Z_EUGY_B64_DECODE'
*          EXPORTING
*            iv_b64     = lv_value_b64
*          IMPORTING
*            ev_decoded = lv_value.
*
*        CALL FUNCTION 'Z_EUGY_RESP_XML_4T'
*          EXPORTING
*            iv_xml       = lv_value
*          CHANGING
*            cs_uk_adatok = es_uk_adatok.


          WHEN 'urn:eksz.gov.hu:1.0:felhasznalo_azonosito'.
            lr_child = lr_node->get_first_child( ).
            CLEAR lv_value_b64.
            CALL METHOD lr_xml->get_node_value
              EXPORTING
                node  = lr_child
              RECEIVING
                value = lv_value_b64.

*          lv_value_b64 = cl_http_utility=>decode_base64( encoded = lv_value_b64 ).
            ev_kau_id = lv_value_b64.

*-----------KUNYTKK----
*QS: jelenleg nem kell,
*      WHEN 'urn:eksz.gov.hu:1.0:kunytkk'.
*        lr_child = lr_node->get_first_child( ).
*        CLEAR lv_value_b64.
*        CALL METHOD lr_xml->get_node_value
*          EXPORTING
*            node  = lr_child
*          RECEIVING
*            value = lv_value_b64.

*         lv_value_b64 = CL_HTTP_UTILITY=>decode_base64( encoded = lv_value_b64 ).
*        es_uk_adatok-kunytkk = lv_value_b64.


*-----------RENDELKEZÉS----
*QS: jelenleg nem kell,
*      WHEN 'urn:eksz.gov.hu:1.0:rendelkezes'.
*        lr_child = lr_node->get_first_child( ).
*        WHILE NOT lr_child IS INITIAL.
*          CLEAR lv_value_b64.
*          CALL METHOD lr_xml->get_node_data
*            EXPORTING
*              node       = lr_child
*            IMPORTING
*              dataobject = lv_value_b64
*              retcode    = lv_retcode.
*          CLEAR lv_value.
*
*          CALL FUNCTION 'Z_EUGY_B64_DECODE'
*            EXPORTING
*              iv_b64     = lv_value_b64
*            IMPORTING
*              ev_decoded = lv_value.
*         lv_value_b64 = CL_HTTP_UTILITY=>decode_base64( encoded = lv_value_b64 ).

*          CALL FUNCTION 'Z_EUGY_RESP_XML_RENDELKEZES'
*            EXPORTING
*              iv_xml       = lv_value
*              is_uk_adatok = es_uk_adatok
*            IMPORTING
*              es_mh        = ls_mh.
*          IF NOT ls_mh IS INITIAL.
**           Elfogadott meghatalmazás típusok ellenőrzése
*            SELECT SINGLE COUNT(*)
*              FROM zeugy_rny_mhtip
*             WHERE rny_kat_kod = ls_mh-rny_kat_kod.
*            IF sy-subrc NE 0.
*              lr_child = lr_child->get_next( ) .
*              CONTINUE.
*            ENDIF.
**           Rendelkezés azonosító duplikáció ellenőrzése
*            READ TABLE et_mh WITH KEY rny_azon = ls_mh-rny_azon
*                 TRANSPORTING NO FIELDS.
*            IF sy-subrc = 0.
*              lr_child = lr_child->get_next( ) .
*              CONTINUE.
*            ENDIF.
*            APPEND ls_mh TO et_mh.
*          ENDIF.
*
*          lr_child = lr_child->get_next( ) .
*        ENDWHILE.

        ENDCASE.

      ENDIF.

      lr_node = lr_node->get_next( ) .
    ENDWHILE.

  ENDIF.


ENDFUNCTION.