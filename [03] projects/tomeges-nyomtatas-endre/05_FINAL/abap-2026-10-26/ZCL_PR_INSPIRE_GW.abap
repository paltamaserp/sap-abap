"! Az Inspire webszolgáltatásainak (feltöltés, stock-feladás, minta-PDF,
"! kizárás közlése) vékony burka: a proxyk hívását és a proxy-kivételek
"! ZCX_FORM_MESSAGE_ERROR-ra fordítását végzi. Nem ír adatbázist, nem commitol,
"! de a szinkron proxyhívás maga commitolja a hívás előtti módosításokat.
CLASS zcl_pr_inspire_gw DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zif_pr_inspire_gw .
  PROTECTED SECTION.

    METHODS raise_proxy_error
      IMPORTING
        !ix_fault TYPE REF TO cx_root
      RAISING
        zcx_form_message_error .
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_PR_INSPIRE_GW IMPLEMENTATION.


  METHOD zif_pr_inspire_gw~upload_files.
    " Minden fájlt a régi (DU5) feltöltéssel azonos módon készítünk elő: az XML
    " egy ZIP-archívumba kerül, amelyben a bejegyzés neve maga a fájlnév, majd
    " base64 kódoljuk. Az Inspire az archívumot kicsomagolja, és a bejegyzés
    " nevén teszi a bemeneti könyvtárába; a stock-feladás erre a névre hivatkozik.
    " A hívás előtt a hívó nem tarthat függő adatbázis-módosítást, mert a
    " proxyhívás commitol.
    DATA ls_input TYPE zpr_eon_forms_uploader_reques2.
    DATA ls_output TYPE zpr_eon_forms_uploader_respons.
    DATA lo_proxy TYPE REF TO zpr_co_eon_forms_uploader_port.
    DATA lo_zip TYPE REF TO cl_abap_zip.

    IF it_file IS INITIAL.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e029(zpr_qm).
    ENDIF.

    " A küldő rendszert és mandantot a régi (DU5) feltöltés is megadta; a többi
    " Inspire-híváshoz hasonlóan itt is a bejelentkezési környezetből jön.
    ls_input-sap_system  = sy-sysid.
    ls_input-sap_mandant = sy-mandt.

    LOOP AT it_file ASSIGNING FIELD-SYMBOL(<ls_file>).
      DATA(lv_xml) = zcl_pr_file_converter=>convert_string_to_xstring( <ls_file>-xml ).
      lo_zip = NEW #( ).
      lo_zip->add( name    = <ls_file>-file_name
                   content = lv_xml ).
      DATA(lv_base64) = zcl_pr_file_converter=>encode_xtring_to_base64( lo_zip->save( ) ).

      APPEND VALUE #( file_name     = <ls_file>-file_name
                      zipped        = abap_true
                      base64        = abap_true
                      file_contents = lv_base64 )
        TO ls_input-eon_forms-xmlfile.
    ENDLOOP.

    TRY.
        lo_proxy = NEW #( logical_port_name = zcl_pr_output_management=>get_logical_port_name( ) ).
        lo_proxy->eon_forms_uploader( EXPORTING input  = ls_input
                                      IMPORTING output = ls_output ).
      CATCH cx_ai_system_fault cx_ai_application_fault INTO DATA(lx_fault).
        raise_proxy_error( lx_fault ).
    ENDTRY.

    rv_success = xsdbool( ls_output-parameters-success EQ abap_true ).
  ENDMETHOD.


  METHOD zif_pr_inspire_gw~trigger_stock_completion.
    " A kérés a spec. 3.4. szerint épül: a rendszer és a mandant a bejelentkezési
    " környezetből jön, a csoportok pedig a hívó által megadott sorrendben mennek ki.
    DATA ls_input TYPE zpr_eon_trigger_stock_complet4.
    DATA ls_output TYPE zpr_eon_trigger_stock_complet3.
    DATA lo_proxy TYPE REF TO zpr_co_eon_trigger_stock_compl.

    ls_input-sap_system                    = sy-sysid.
    ls_input-sap_mandant                   = sy-mandt.
    ls_input-stock_id                      = CONV string( iv_stock_id ).
    ls_input-priority                      = CONV i( iv_priority ).
    ls_input-enforce_clean_address_display = iv_notest.
    ls_input-files-name                    = it_file_name.
    ls_input-docs-group = VALUE #( FOR ls_group IN it_group
                                   ( sample_id = ls_group-sample_id
                                     id        = ls_group-id ) ).

    TRY.
        lo_proxy = NEW #( logical_port_name = zcl_pr_output_management=>get_logical_port_name( ) ).
        lo_proxy->eon_trigger_stock_completion( EXPORTING input  = ls_input
                                                IMPORTING output = ls_output ).
      CATCH cx_ai_system_fault cx_ai_application_fault INTO DATA(lx_fault).
        raise_proxy_error( lx_fault ).
    ENDTRY.

    rs_response = VALUE #( success    = xsdbool( ls_output-parameters-success EQ abap_true )
                           info       = ls_output-parameters-info
                           error_code = ls_output-parameters-error_code ).
  ENDMETHOD.


  METHOD zif_pr_inspire_gw~get_sample_pdf.
    " Az Inspire a PDF-et base64 kódolva adja vissza; sikeres válasznál itt
    " alakítjuk bináris tartalommá, hogy a hívónak ne kelljen vele foglalkoznia.
    DATA ls_input        TYPE zpr_eon_get_sample_pdfrequest.
    DATA ls_output       TYPE zpr_eon_get_sample_pdfresponse.
    DATA lo_proxy        TYPE REF TO zpr_co_eon_get_sample_pdfport.

    ls_input-sap_system  = sy-sysid.
    ls_input-sap_mandant = sy-mandt.
    ls_input-stock_id    = CONV string( iv_stock_id ).
    ls_input-sample_id   = iv_qm_cat.

    TRY.
        lo_proxy = NEW #( logical_port_name = zcl_pr_output_management=>get_logical_port_name( ) ).
        lo_proxy->eon_get_sample_pdf( EXPORTING input  = ls_input
                                      IMPORTING output = ls_output ).
      CATCH cx_ai_system_fault cx_ai_application_fault INTO DATA(lx_fault).
        raise_proxy_error( lx_fault ).
    ENDTRY.

    rs_pdf-success    = xsdbool( ls_output-parameters-success EQ abap_true ).
    rs_pdf-info       = ls_output-parameters-info.
    rs_pdf-error_code = ls_output-parameters-error_code.

    IF rs_pdf-success EQ abap_true AND ls_output-parameters-base64doc IS NOT INITIAL.
      TRY.
          rs_pdf-content = zcl_pr_file_converter=>decode_base64_to_str( ls_output-parameters-base64doc ).
        CATCH cx_sy_conversion_error INTO DATA(lx_conversion).
          RAISE EXCEPTION TYPE zcx_form_message_error
            EXPORTING
              iv_text = lx_conversion->get_text( ).
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD zif_pr_inspire_gw~dcqm_completed.
    " A kizárt borítékokat az Inspire a REASON nélkül kapja (az indok üres),
    " ahogyan a régi rendszer is küldte.
    DATA ls_input TYPE zpr_eon_dcqmcompleted_request2.
    DATA ls_output TYPE zpr_eon_dcqmcompleted_response.
    DATA lo_proxy TYPE REF TO zpr_co_eon_dcqmcompleted_port.

    ls_input-sap_system  = sy-sysid.
    ls_input-sap_mandant = sy-mandt.
    ls_input-stock_id    = CONV string( iv_stock_id ).
    ls_input-priority    = CONV i( iv_priority ).
    ls_input-exclude_envelopes-envelope = VALUE #( FOR lv_envelope IN it_envelope
                                                   ( envelope_id = CONV string( lv_envelope ) ) ).

    TRY.
        lo_proxy = NEW #( logical_port_name = zcl_pr_output_management=>get_logical_port_name( ) ).
        lo_proxy->eon_dcqmcompleted( EXPORTING input  = ls_input
                                     IMPORTING output = ls_output ).
      CATCH cx_ai_system_fault cx_ai_application_fault INTO DATA(lx_fault).
        raise_proxy_error( lx_fault ).
    ENDTRY.

    rs_response = VALUE #( success    = xsdbool( ls_output-parameters-success EQ abap_true )
                           info       = ls_output-parameters-info
                           error_code = ls_output-parameters-error_code ).
  ENDMETHOD.


  METHOD raise_proxy_error.
    " A proxy-kivétel teljes szövege kerül a kivételbe, csonkolás nélkül.
    RAISE EXCEPTION TYPE zcx_form_message_error
      EXPORTING
        iv_text = ix_fault->get_text( ).
  ENDMETHOD.
ENDCLASS.