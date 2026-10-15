class ZCL_PR_OUTPUT_MANAGEMENT definition
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

  types:
    begin of typ_s_task,
       id     TYPE char8,
       doc_no TYPE ZPRD_DOC_NO,
    end of typ_s_task .
  types:
    typ_t_tasks type table of typ_s_task .

  methods CONSTRUCTOR
    importing
      !IS_ITCPO type ITCPO .
  methods CREATE_OUTPUT
    importing
      !IS_DATA type ANY
      !IS_DOC_LOG type ZPRT_DOC_LOG optional
      !IS_DOC_DB type ZPRS_DB optional
      !IV_DOC_TYPE type ZPRD_DOC_TYPE
      !IS_META_DATA type ZPRS_METADATA
      !IS_ENVELOPE type ZPRT_ENVELOPE optional
      !IV_TEST type FLAG optional
    raising
      ZCX_FORM_MESSAGE_ERROR .
  methods CREATE_MARKETING_BLOCK_SAMPLE
    importing
      !IS_DATA type STRING
    exporting
      !EV_PDF type XSTRING
      !EV_MESSAGE type STRING .
  methods DISPLAY_PDF .
  class-methods GET_LOGICAL_PORT_NAME
    returning
      value(RV_LOGICAL_PORT_NAME) type PRX_LOGICAL_PORT_NAME .
  methods PRINT_TO_LOCAL_PRINTER .
  class-methods SET_RUN_STATE
    importing
      !P_TASK type CLIKE .
  methods RESEND_XML
    importing
      !IV_XML type STRING .
protected section.

  data GS_DOC type ZPRC_DOC .
  data GS_ITCPO type ITCPO .
  data GS_METADATA type ZPRS_METADATA .
  data GS_DOC_LOG type ZPRT_DOC_LOG .
  data GV_DUMMY_MESSAGE type CHAR1 .
  data GV_JSON type STRING .
  data GV_PDF type XSTRING .
  data GV_XML type STRING .
  class-data GT_TASKS type TYP_T_TASKS .
  data GV_SPOOL_ON type ABAP_BOOL .
  data GS_ENVELOPE type ZPRT_ENVELOPE .
  data GS_DOC_DB type ZPRS_DB .

  methods CREATE_PDF .
  methods CREATE_XML
    importing
      !IS_DATA type ANY .
  methods SAVE_DATA .
  methods CHECK_PRINT_PARAMS .
  methods CREATE_DOC_ATTRIBUTES
    importing
      !IV_DOC_TYPE type ZPRD_DOC_TYPE .
  methods WRITE_ARCHIVE_LINK .
  methods SAVE_ARCHIVE_LINK .
  methods CALL_INSPIRE .
  methods SHOW_XML .
  methods APPLY_CHEQUE_RULE
    changing
      !CS_DATA type ANY
      !CS_METADATA type ZPRS_METADATA .
private section.
ENDCLASS.



CLASS ZCL_PR_OUTPUT_MANAGEMENT IMPLEMENTATION.


  METHOD constructor.
*----------------------------------------------------------------*
* Rövid leírás: Konstruktor
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
* ---------------------------------------------------------------*
* Globális változók beállítása
    MOVE-CORRESPONDING is_itcpo    TO gs_itcpo.

* ---------------------------------------------------------------*
* Spoolkérelembe is írunk?
    gv_spool_on = zcl_pr_admin=>get_parameter_value( 'SPOOL_ON' ).

  ENDMETHOD.


  METHOD create_output.
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
* 2026.06.20.   X0097         Létrehozva
* 2026.10.14.   X0086         Egységes csekk-szabály az XML előtt
*---------------------------------------------------------------*
* Deklaráció
    DATA lr_data TYPE REF TO data.
    FIELD-SYMBOLS <ls_data> TYPE any.

*---------------------------------------------------------------*
* Dokumentum típushoz
    create_doc_attributes( iv_doc_type ).

*---------------------------------------------------------------*
* Naplózandó adatok
    MOVE-CORRESPONDING is_doc_log TO gs_doc_log.
    TRY.
        gs_doc_log-guid = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid_error).
        MESSAGE e094 WITH gs_metadata-exbilldocno.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
    ENDTRY.
    MOVE-CORRESPONDING is_doc_db TO gs_doc_db.
    gs_doc_db-guid = gs_doc_log-guid.

*---------------------------------------------------------------*
* Metadatok beállítása
    MOVE-CORRESPONDING is_meta_data TO gs_metadata.

*---------------------------------------------------------------*
* Boriték beállítása
    MOVE-CORRESPONDING is_envelope TO gs_envelope.

*---------------------------------------------------------------*
* Nyomtatási paraméterek ellenőrzése
*    check_print_params(  ).

*---------------------------------------------------------------*
* Csekk-szabály: az IS_DATA nem módosítható, ezért helyi másolaton dolgozunk
    CREATE DATA lr_data LIKE is_data.
    ASSIGN lr_data->* TO <ls_data>.
    IF sy-subrc EQ 0.
      <ls_data> = is_data.
      apply_cheque_rule(
        CHANGING
          cs_data     = <ls_data>
          cs_metadata = gs_metadata ).

*---------------------------------------------------------------*
* XML előállítása
      create_xml( <ls_data> ).
    ELSE.
* Ha a másolat nem jön létre, az XML az eredeti adatból készül, a szabály nélkül
      create_xml( is_data ).
    ENDIF.

*---------------------------------------------------------------*
* Tesztelés
    IF iv_test EQ abap_true.
      show_xml( ).
      RETURN.
    ENDIF.

*---------------------------------------------------------------*
* Kimeneti csatornától függően eltérő a nyomtatási folyamatot
    CASE gs_metadata-destination.
      WHEN c_channel-preview.
        create_pdf(  ).
        display_pdf(  ).
      WHEN c_channel-paper_loc.
* Az Inspire-hívást a create_pdf is elvégzi, ezért bekapcsolt spoolnál
* nem hívjuk újra: egy nyomtatáshoz egyszer történjen a renderelés.
        IF gv_spool_on = abap_true.
          create_pdf(  ).
          print_to_local_printer(  ).
        ELSE.
          call_inspire(   ).
        ENDIF.
        save_data(  ).
        write_archive_link(  ).
      WHEN c_channel-email_loc OR c_channel-portal_loc OR c_channel-sftp_loc.
        call_inspire(   ).
        save_data(  ).
        write_archive_link(  ).
      WHEN c_channel-email_mass OR c_channel-portal_mass
        OR c_channel-sftp_mass OR c_channel-print_shop.
        save_data(  ).
        save_archive_link(  ).
      WHEN c_channel-base_printout.
        save_data(  ).
      WHEN OTHERS.
        MESSAGE e073 WITH gs_metadata-destination INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
    ENDCASE.

  ENDMETHOD.


  METHOD create_pdf.
* ---------------------------------------------------------------*
* Rövid leírás: PDF előállítása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*----------------------------------------------------------------*
* Deklaráció
    DATA lv_logical_port_name TYPE prx_logical_port_name.
    DATA lv_xmlx              TYPE xstring.
    DATA lv_base64            TYPE string.
    DATA ls_input	            TYPE zpr_eon_render_forms_to_pdfre1.
    DATA ls_output            TYPE zpr_eon_render_forms_to_pdfres.
    DATA lo_pr                TYPE REF TO zpr_co_eon_render_forms_to_pdf.
    DATA ls_result_pdf        TYPE LINE OF zpr_teon_render_forms_to_p_tab.

* ---------------------------------------------------------------*
* XML konverzió
    lv_xmlx   = zcl_pr_file_converter=>convert_string_to_xstring( gv_xml ).
    lv_base64 = zcl_pr_file_converter=>encode_xtring_to_base64( lv_xmlx ).

* ---------------------------------------------------------------*
* Logikai port előállítása
    lv_logical_port_name = get_logical_port_name(  ).

* ---------------------------------------------------------------*
* Proxy objektum létrehozása
    TRY.
        CREATE OBJECT lo_pr
          EXPORTING
*           destination       = lo_destination
            logical_port_name = get_logical_port_name( ). "lv_logical_port_name.
      CATCH cx_ai_system_fault INTO DATA(lx_system_fault). " Application Integration: Technical Error
        MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
    ENDTRY.

* ---------------------------------------------------------------*
* Inspire hívás felparaméterezése
    ls_input-sap_system       = sy-sysid.
    ls_input-sap_mandant      = sy-mandt.
    ls_input-priority         = c_priority-val_50.
    ls_input-concat_docs      = abap_false.
    ls_input-eon_forms-base64 = abap_true.
    APPEND lv_base64 TO ls_input-eon_forms-xml_contents.

* ---------------------------------------------------------------*
* PDF lekérése az Inspire-tól
    TRY.
        lo_pr->eon_render_forms_to_pdf(
          EXPORTING
            input  = ls_input
          IMPORTING
            output = ls_output ).
      CATCH cx_ai_system_fault INTO lx_system_fault.
        MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      CATCH cx_ai_application_fault INTO DATA(lx_application_fault).
        MESSAGE e000 WITH lx_application_fault->get_text(  ) INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
    ENDTRY.

* ---------------------------------------------------------------*
* Hibakezelés
    IF ls_output-parameters-success <> abap_true.
      IF ls_output-parameters-info IS INITIAL.
        MESSAGE e003 INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      ELSE.
        MESSAGE e000 WITH ls_output-parameters-info INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      ENDIF.
    ENDIF.

* ---------------------------------------------------------------*
* PDF dekódolása
    READ TABLE ls_output-parameters-pdfdata-pdfdocument INTO  ls_result_pdf  INDEX 1.
    IF sy-subrc = 0.
      gv_pdf   = zcl_pr_file_converter=>decode_base64_to_str( ls_result_pdf-base64doc ).
    ELSE.
      MESSAGE e003 INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.

  ENDMETHOD.


  METHOD create_xml.
* ---------------------------------------------------------------*
* Rövid leírás: XML előállítása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*----------------------------------------------------------------*
* Bejövő adatok XML konverziója
    gv_xml = zcl_pr_file_converter=>convert_data_to_xml( is_data ).

  ENDMETHOD.


  METHOD print_to_local_printer.
*----------------------------------------------------------------*
* Rövid leírás: Lokális nyomtatás
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*----------------------------------------------------------------*
* Deklaráció
    DATA lv_pages TYPE i.
    DATA lv_title TYPE rspotitle.
    DATA lv_text  TYPE text30.

*----------------------------------------------------------------*
* ADS nyomtatás előkészítése
    lv_pages = 1.
    IF gs_doc_log-opbel IS NOT INITIAL.
      lv_title = gs_doc_log-opbel.
    ELSE.
      lv_title = gs_metadata-exbilldocno.
    ENDIF.
    SELECT SINGLE text30
      INTO lv_text
      FROM zprc_doc_typet
      WHERE spras = sy-langu
      AND doc_type = gs_doc_log-doc_type.
    IF sy-subrc = 0.
      CONCATENATE lv_text lv_title INTO lv_title SEPARATED BY space.
    ENDIF.

*----------------------------------------------------------------*
* ADS nyomtatás
    CALL FUNCTION 'ADS_CREATE_PDF_SPOOLJOB'
      EXPORTING
*       PRINTER           =
        dest              = gs_itcpo-tddest
        pages             = lv_pages
        pdf_data          = gv_pdf
*       name              =
        suffix1           = gs_itcpo-tdsuffix1
        suffix2           = gs_itcpo-tdsuffix2
*       COPIES            =
*       PRIO              =
        immediate_print   = 'X'   "gs_itcpo-tdimmed
        auto_delete       = space "gs_itcpo-tddelete
        titleline         = lv_title
        receiver          = sy-uname
*       DIVISION          =
*       AUTHORITY         =
*       LIFETIME          = '0'
* IMPORTING
*       SPOOLID           =
      EXCEPTIONS
        no_data           = 1
        not_pdf           = 2
        wrong_devtype     = 3
        operation_failed  = 4
        cannot_write_file = 5
        device_missing    = 6
        no_such_device    = 7
        OTHERS            = 8.
    IF sy-subrc <> 0.
      MESSAGE e008 WITH gs_metadata-exbilldocno INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.

  ENDMETHOD.


  METHOD save_data.
* ---------------------------------------------------------------*
* Rövid leírás: Adatok mentése
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*----------------------------------------------------------------*
* Deklaráció
    DATA ls_doc_data TYPE zprt_doc_data.
    DATA ls_doc_log  TYPE zprt_doc_log.
    DATA ls_doc_dcqm TYPE zprt_dcqm.

*----------------------------------------------------------------*
* Az előnézet nem kerül tárolásra, hiába hívják a mentést
    IF gs_metadata-destination EQ c_channel-preview.
      RETURN.
    ENDIF.

*----------------------------------------------------------------*
* Üzleti adatok mentése
    MOVE-CORRESPONDING gs_doc_db TO ls_doc_log.
    MOVE-CORRESPONDING zcl_pr_admin=>get_create_data(   ) TO ls_doc_log.
* A ZPRS_DB nem tartalmazza az üzleti kulcsmezőket, ezért a naplóból pótoljuk.
    ls_doc_log-vkont = gs_doc_log-vkont.
    ls_doc_log-gpart = gs_doc_log-gpart.
    ls_doc_log-bukrs = gs_doc_log-bukrs.
    ls_doc_log-opbel = gs_doc_log-opbel.
    ls_doc_log-sparte = gs_doc_log-sparte.
    INSERT INTO zprt_doc_log VALUES ls_doc_log.
    IF sy-subrc <> 0.
*      ROLLBACK WORK.
      MESSAGE e004 INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.

*----------------------------------------------------------------*
* XML mentése
    ls_doc_data-data   = gv_xml.
    ls_doc_data-guid   = ls_doc_log-guid.
    ls_doc_data-doc_no = ls_doc_log-doc_no.
    MOVE-CORRESPONDING gs_doc_db TO ls_doc_data.
    MOVE-CORRESPONDING zcl_pr_admin=>get_create_data(   ) TO ls_doc_data.
    SELECT SINGLE struc_name
  INTO ls_doc_data-struc_name
    FROM zprc_doc_admin
    WHERE doc_type = gs_doc_db-doc_type.
    IF sy-subrc <> 0.
*      ROLLBACK WORK.
      MESSAGE e095 WITH gs_doc_db-doc_type INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.
    INSERT INTO zprt_doc_data VALUES ls_doc_data.
    IF sy-subrc <> 0.
*      ROLLBACK WORK.
      MESSAGE e005 INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.

*----------------------------------------------------------------*
* Tömeges esetén
    IF gs_doc_log-printer = c_printer-mass.
      ls_doc_dcqm-guid   = ls_doc_log-guid.
      ls_doc_dcqm-doc_no = ls_doc_log-doc_no.
      MOVE-CORRESPONDING gs_doc_db TO ls_doc_dcqm.
      MOVE-CORRESPONDING zcl_pr_admin=>get_create_data(   ) TO ls_doc_dcqm.
      INSERT INTO zprt_dcqm VALUES ls_doc_dcqm.
      IF sy-subrc <> 0.
*        ROLLBACK WORK.
        MESSAGE e005 INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      ENDIF.
    ENDIF.

*----------------------------------------------------------------*
* Boritékolás mentése
    IF gs_envelope IS NOT INITIAL.
      INSERT INTO zprt_envelope VALUES gs_envelope.
      IF sy-subrc <> 0.
*        ROLLBACK WORK.
        MESSAGE e040 INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      ENDIF.
    ENDIF.

*----------------------------------------------------------------*
* Ha minden módosítás sikerült, akkor AB commit
*    COMMIT WORK.

  ENDMETHOD.


  METHOD get_logical_port_name.
* ---------------------------------------------------------------*
* Rövid leírás: Logikai port meghatározása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*----------------------------------------------------------------*
* Deklaráció
    DATA lv_dummy_message TYPE char1.

*----------------------------------------------------------------*
* Port olvasása
    SELECT SINGLE log_port_name
      INTO rv_logical_port_name
      FROM zprc_log_port_nm
      WHERE sys_id = sy-sysid.
    IF sy-subrc <> 0.
      MESSAGE e006 WITH sy-sysid sy-mandt INTO lv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.

  ENDMETHOD.


  METHOD display_pdf.
* ---------------------------------------------------------------*
* Rövid leírás: Preview
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*----------------------------------------------------------------*
    DATA ls_task TYPE typ_s_task.

*----------------------------------------------------------------*
* Párhuzamosítási paraméterek feltöltése
    CLEAR ls_task.
    ls_task-id    = sy-uzeit.
    ls_task-doc_no = gs_metadata-exbilldocno.
    APPEND ls_task TO gt_tasks.

*----------------------------------------------------------------*
* Független taskban hívjuk meg a megjelenítőt
    CALL FUNCTION 'Z_PR_DISPLAY_PDF'
      STARTING NEW TASK ls_task-id
      CALLING set_run_state ON END OF TASK
      EXPORTING
        iv_pdf = gv_pdf.

  ENDMETHOD.


  METHOD set_run_state.
*----------------------------------------------------------------------
* Rövid leírás: PDF megjelenítése
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*----------------------------------------------------------------------
* 2026.07.12.   X0097         Létrehozva
*----------------------------------------------------------------------
* Globális állapot aktualizálása
    DELETE gt_tasks WHERE doc_no = p_task.

*----------------------------------------------------------------------
* Párhuzamos RFC session zárása
    CALL FUNCTION 'RFC_CONNECTION_CLOSE'
      EXPORTING
*       DESTINATION          =
        taskname             = p_task
      EXCEPTIONS
        destination_not_open = 1
        OTHERS               = 2.
    if sy-subrc <> 0.
    endif.

  ENDMETHOD.


  METHOD check_print_params.
*----------------------------------------------------------------*
* Rövid leírás: Nyomtatási paraméterek ellenőrzése
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*----------------------------------------------------------------*
* Ha nem preview a nyomtató csak Inspire-hez dedikált nyomtató lehet
    IF gs_itcpo-tdpreview <> abap_true.
      IF NOT ( gs_itcpo-tddest = c_printer-local OR
               gs_itcpo-tddest = c_printer-mass ).
        MESSAGE e014 WITH gs_itcpo-tddest INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      ENDIF.
    ENDIF.

*----------------------------------------------------------------*
* Metadatok nem lehet üres
    IF gs_metadata IS INITIAL.
      MESSAGE e002 INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.

*----------------------------------------------------------------*
* Tömeges nyomtatóra csak tömeges nyomtatvány küldhetünk
    IF gs_itcpo-tdpreview <> abap_true.
      IF ( gs_doc-printing_mode = 'M' AND gs_itcpo-tddest <> c_printer-mass ).
        MESSAGE e015 WITH gs_itcpo-tddest INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      ENDIF.
    ENDIF.
*----------------------------------------------------------------*
* Lokális nyomtatóra csak tömeges nyomtatvány küldhetünk
    IF gs_itcpo-tdpreview <> abap_true.
      IF ( gs_doc-printing_mode = 'L' AND gs_itcpo-tddest <> c_printer-local ).
        MESSAGE e015 WITH gs_itcpo-tddest INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD create_doc_attributes.
*----------------------------------------------------------------*
* Rövid leírás: Nyomtatást vezérlő paraméterek olvasása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
* ---------------------------------------------------------------*
* Dokumentum típushoz tartozó nyomtatás vezérlő paraméterek
    SELECT SINGLE *
      INTO gs_doc
      FROM zprc_doc
      WHERE doc_type = iv_doc_type.
    IF sy-subrc <> 0.
      MESSAGE e001 WITH iv_doc_type INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.

  ENDMETHOD.


  METHOD save_archive_link.
*---------------------------------------------------------------*
* Rövid leírás: Archív link írása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.13.   X0097         Létrehozva
*---------------------------------------------------------------*
* Deklaráció
    DATA ls_arch_link TYPE zprt_arch_link.

*---------------------------------------------------------------*
* Adatok feltöltése
    ls_arch_link-doc_no           = gs_metadata-exbilldocno.
    ls_arch_link-opbel            = gs_doc_log-opbel.
    ls_arch_link-xsapobject       = gs_metadata-xsapobject.
    ls_arch_link-xsapdocumenttype = gs_metadata-xsapdocumenttype.
    ls_arch_link-xsapobjectid     = gs_metadata-xsapobjectid.
    ls_arch_link-xsapdocid        = gs_metadata-xsapdocid.

*---------------------------------------------------------------*
* AB írása
    MODIFY zprt_arch_link FROM ls_arch_link.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      MESSAGE e041 INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.
  ENDMETHOD.


  METHOD write_archive_link.
*---------------------------------------------------------------*
* Rövid leírás: Archív link írása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.07.13.   X0097         Létrehozva
*---------------------------------------------------------------*
* Archív link írása
    CALL FUNCTION 'ARCHIV_CONNECTION_INSERT'
      EXPORTING
        arc_doc_id            = gs_metadata-xsapdocid
        ar_object             = gs_metadata-xsapdocumenttype
        object_id             = gs_metadata-xsapobjectid
        sap_object            = gs_metadata-xsapobject
      EXCEPTIONS
        error_connectiontable = 1.

* Ha az archív kapcsolat nem jön létre, hibával megállunk.
    IF sy-subrc NE 0.
      MESSAGE e074(zpr) WITH gs_metadata-xsapobjectid INTO gv_dummy_message.
      RAISE EXCEPTION TYPE zcx_form_message_error
        EXPORTING
          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.

  ENDMETHOD.


  method CALL_INSPIRE.
* ---------------------------------------------------------------*
* Rövid leírás: PDF előállítása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*----------------------------------------------------------------*
* Deklaráció
    DATA lv_logical_port_name TYPE prx_logical_port_name.
    DATA lv_xmlx              TYPE xstring.
    DATA lv_base64            TYPE string.
    DATA ls_input	            TYPE zpr_eon_render_forms_to_pdfre1.
    DATA ls_output            TYPE zpr_eon_render_forms_to_pdfres.
    DATA lo_pr                TYPE REF TO zpr_co_eon_render_forms_to_pdf.
    DATA ls_result_pdf        TYPE LINE OF zpr_teon_render_forms_to_p_tab.

* ---------------------------------------------------------------*
* XML konverzió
    lv_xmlx   = zcl_pr_file_converter=>convert_string_to_xstring( gv_xml ).
    lv_base64 = zcl_pr_file_converter=>encode_xtring_to_base64( lv_xmlx ).

* ---------------------------------------------------------------*
* Logikai port előállítása
    lv_logical_port_name = get_logical_port_name(  ).

* ---------------------------------------------------------------*
* Proxy objektum létrehozása
    TRY.
        CREATE OBJECT lo_pr
          EXPORTING
*           destination       = lo_destination
            logical_port_name = get_logical_port_name( ). "lv_logical_port_name.
      CATCH cx_ai_system_fault INTO DATA(lx_system_fault). " Application Integration: Technical Error
        MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
    ENDTRY.

* ---------------------------------------------------------------*
* Inspire hívás felparaméterezése
    ls_input-sap_system       = sy-sysid.
    ls_input-sap_mandant      = sy-mandt.
    ls_input-priority         = c_priority-val_50.
    ls_input-concat_docs      = abap_false.
    ls_input-eon_forms-base64 = abap_true.
    APPEND lv_base64 TO ls_input-eon_forms-xml_contents.

* ---------------------------------------------------------------*
* Inspire meghívása (ugyanaz, mint a PDF előállító)
    TRY.
        lo_pr->eon_render_forms_to_pdf(
          EXPORTING
            input  = ls_input
          IMPORTING
            output = ls_output ).
      CATCH cx_ai_system_fault INTO lx_system_fault.
        MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      CATCH cx_ai_application_fault INTO DATA(lx_application_fault).
        MESSAGE e000 WITH lx_application_fault->get_text(  ) INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
    ENDTRY.

* ---------------------------------------------------------------*
* Hibakezelés
    IF ls_output-parameters-success <> abap_true.
      IF ls_output-parameters-info IS INITIAL.
        MESSAGE e003 INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      ELSE.
        MESSAGE e000 WITH ls_output-parameters-info INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      ENDIF.
    ENDIF.

  endmethod.


  METHOD create_marketing_block_sample.
* ---------------------------------------------------------------*
* Rövid leírás: PDF előállítása
* Projekt:      CSHANA 2026
* Fejlesztő:    Németh Endre / X0097 / ERP
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
* ---------------------------------------------------------------*
* 2026.06.20.   X0097         Létrehozva
*----------------------------------------------------------------*
* Deklaráció
    DATA lv_logical_port_name TYPE prx_logical_port_name.
    DATA lv_xmlx              TYPE xstring.
    DATA lv_base64            TYPE string.
    DATA ls_input	            TYPE zpr_eon_get_inspire_formatted1.
    DATA ls_output            TYPE zpr_eon_get_inspire_formatted.
    DATA lo_pr                TYPE REF TO zpr_co_eon_get_inspire_formatt.
    DATA ls_result_pdf        TYPE string.

* ---------------------------------------------------------------*
* BASE64 konverzió
    lv_xmlx   = zcl_pr_file_converter=>convert_string_to_xstring( is_data ).
    lv_base64 = zcl_pr_file_converter=>encode_xtring_to_base64( lv_xmlx ).

* ---------------------------------------------------------------*
* Logikai port előállítása
    lv_logical_port_name = get_logical_port_name(  ).

* ---------------------------------------------------------------*
* Proxy objektum létrehozása
    TRY.
        CREATE OBJECT lo_pr
          EXPORTING
*           destination       = lo_destination
            logical_port_name = get_logical_port_name( ). "lv_logical_port_name.
      CATCH cx_ai_system_fault INTO DATA(lx_system_fault). " Application Integration: Technical Error
        MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO ev_message.
        RETURN.

*        RAISE EXCEPTION TYPE zcx_form_message_error
*          EXPORTING
*            textid = zcl_pr_admin=>get_system_message( ).
    ENDTRY.

* ---------------------------------------------------------------*
* Inspire hívás felparaméterezése
    ls_input-sap_system       = sy-sysid.
    ls_input-sap_mandant      = sy-mandt.
*    ls_input-priority         = c_priority-val_50.
*    ls_input-concat_docs      = abap_false.
*    ls_input-eon_forms-base64 = abap_true.
    MOVE lv_base64 TO ls_input-vf_code_b64.

* ---------------------------------------------------------------*
* PDF lekérése az Inspire-tól
    TRY.
        lo_pr->eon_get_inspire_formatted_samp(
          EXPORTING
            input  = ls_input
          IMPORTING
            output = ls_output ).
      CATCH cx_ai_system_fault INTO lx_system_fault.
*        MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO ev_message.   " MAX 50 characters!
        ev_message = lx_system_fault->get_text(  ).
        RETURN.

*        RAISE EXCEPTION TYPE zcx_form_message_error
*          EXPORTING
*            textid = zcl_pr_admin=>get_system_message( ).
      CATCH cx_ai_application_fault INTO DATA(lx_application_fault).
*        MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO ev_message.   " MAX 50 characters!
        ev_message = lx_system_fault->get_text(  ).
        RETURN.

*        RAISE EXCEPTION TYPE zcx_form_message_error
*          EXPORTING
*            textid = zcl_pr_admin=>get_system_message( ).
    ENDTRY.

* ---------------------------------------------------------------*
* Hibakezelés
    IF ls_output-parameters-success <> abap_true.
      IF ls_output-parameters-info IS INITIAL.
        MESSAGE e003 INTO ev_message.
        RETURN.

*        RAISE EXCEPTION TYPE zcx_form_message_error
*          EXPORTING
*            textid = zcl_pr_admin=>get_system_message( ).
      ELSE.
*        MESSAGE e000 WITH ls_output-parameters-info INTO ev_message.
        ev_message = ls_output-parameters-info .
        RETURN.

*        RAISE EXCEPTION TYPE zcx_form_message_error
*          EXPORTING
*            textid = zcl_pr_admin=>get_system_message( ).
      ENDIF.
    ENDIF.

* ---------------------------------------------------------------*
* PDF dekódolása
    MOVE ls_output-parameters-base64doc TO  ls_result_pdf.
    IF sy-subrc = 0.
      gv_pdf   = zcl_pr_file_converter=>decode_base64_to_str( ls_result_pdf ).
    ELSE.
      MESSAGE e000 WITH lx_system_fault->get_text(  ) INTO ev_message.   " MAX 50 characters!
*               ev_message =  lx_system_fault->get_text(  ).

      RETURN.
*      RAISE EXCEPTION TYPE zcx_form_message_error
*        EXPORTING
*          textid = zcl_pr_admin=>get_system_message( ).
    ENDIF.

* ---------------------------------------------------------------*
* PDF vissza    "megjelenítése
    ev_pdf = gv_pdf.
*    display_pdf(  ).

  ENDMETHOD.


  METHOD show_xml.
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
* 2026.06.20.   X0097         Létrehozva
*---------------------------------------------------------------*
* Deklaráció
    DATA xml_document TYPE REF TO cl_xml_document.
    DATA subrc TYPE sysubrc.
    DATA lv_exit_xml_screen    TYPE c.

*---------------------------------------------------------------*
* XML megjelenítése
    CREATE OBJECT xml_document.
    subrc = xml_document->parse_string( gv_xml ).
    CALL METHOD cl_plm_audit_if_services=>display_xml_document
      EXPORTING
*       it_wff_xml         =                  " XML Document as Table
*       iv_xml_as_xstring  =
        iv_xml_as_string   = gv_xml "lv_message
*       ir_document        =                  " IF_IXML_DOCUMENT
*       iv_screen_title    =                  " Screens, Title Text
      IMPORTING
        ev_exit_xml_screen = lv_exit_xml_screen.                 " Screen Exiting Triggered

  ENDMETHOD.


  METHOD resend_xml.

    MOVE iv_xml TO gv_xml.
    call_inspire(  ).

  ENDMETHOD.


  METHOD apply_cheque_rule.
*---------------------------------------------------------------*
* Rövid leírás: Egységes csekk-szabály
* Projekt:      CSHANA 2026
* Fejlesztő:    X0086
*
* Release:      S4HANA
*
* Módosítás történet:
* Dátum         Felhasználó   Ok(Leírás+CR/ORDER/TICKET ID)
*---------------------------------------------------------------*
* 2026.10.14.   X0086         Létrehozva
*---------------------------------------------------------------*
* Csekk-jelző (CHQK) és alapnyomat (BASEPRINT) az XML képzése előtt:
* csekk-jelző W, ha az adat csekk-táblája nem üres, különben B.
* A cs_data szerkezet METADATA komponensét módosítja; ugyanazt az
* értéket a cs_metadata (a gs_metadata) is megkapja.
*---------------------------------------------------------------*
* Deklaráció
    DATA lv_type      TYPE c LENGTH 1.
    DATA lv_chqk_new  TYPE zprs_metadata-chqk.
    DATA lv_baseprint TYPE zprs_metadata-baseprint.
    FIELD-SYMBOLS <ls_metadata>  TYPE any.
    FIELD-SYMBOLS <lt_cheque>    TYPE ANY TABLE.
    FIELD-SYMBOLS <lv_chqk>      TYPE any.
    FIELD-SYMBOLS <lv_baseprint> TYPE any.
    FIELD-SYMBOLS <lv_form>      TYPE any.

*---------------------------------------------------------------*
* Csak szerkezeten értelmezett a szabály
    DESCRIBE FIELD cs_data TYPE lv_type.
    IF lv_type NE 'u' AND lv_type NE 'v'.
      RETURN.
    ENDIF.

*---------------------------------------------------------------*
* Nincs METADATA komponens: nincs teendő
    ASSIGN COMPONENT 'METADATA' OF STRUCTURE cs_data TO <ls_metadata>.
    IF sy-subrc NE 0.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT 'CHQK' OF STRUCTURE <ls_metadata> TO <lv_chqk>.
    IF sy-subrc NE 0.
      RETURN.
    ENDIF.

* Üres csekk-jelző: szándékosan nem csekkes űrlap, változatlan marad
    IF <lv_chqk> IS INITIAL.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT 'BASEPRINT' OF STRUCTURE <ls_metadata> TO <lv_baseprint>.
    IF sy-subrc NE 0.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT 'FORM' OF STRUCTURE <ls_metadata> TO <lv_form>.
    IF sy-subrc NE 0.
      RETURN.
    ENDIF.

*---------------------------------------------------------------*
* Csekk-jelző: W, ha van nem üres csekk-tábla, különben B
    lv_chqk_new = 'B'.
    ASSIGN COMPONENT 'CHEQUEDATA_TAB' OF STRUCTURE cs_data TO <lt_cheque>.
    IF sy-subrc EQ 0 AND <lt_cheque> IS NOT INITIAL.
      lv_chqk_new = 'W'.
    ENDIF.

* Ha a csekk-jelző nem változott, az alapnyomat is érintetlen marad
    IF lv_chqk_new EQ <lv_chqk>.
      RETURN.
    ENDIF.

*---------------------------------------------------------------*
* Receptúra: ugyanaz a sorrend, mint a CREATE_METADATA-ban
    SELECT SINGLE baseprint
      INTO lv_baseprint
      FROM zprc_recept_chq
      WHERE chqk EQ lv_chqk_new.
    IF sy-subrc NE 0.
      SELECT SINGLE baseprint
        INTO lv_baseprint
        FROM zprc_receptura
        WHERE form EQ <lv_form>
        AND chqk EQ lv_chqk_new.
      IF sy-subrc NE 0.
        MESSAGE e011(zpr) WITH lv_chqk_new <lv_form> INTO gv_dummy_message.
        RAISE EXCEPTION TYPE zcx_form_message_error
          EXPORTING
            textid = zcl_pr_admin=>get_system_message( ).
      ENDIF.
    ENDIF.

*---------------------------------------------------------------*
* Új érték az XML-adatba és a gs_metadata-ba is
    <lv_chqk>            = lv_chqk_new.
    <lv_baseprint>       = lv_baseprint.
    cs_metadata-chqk      = lv_chqk_new.
    cs_metadata-baseprint = lv_baseprint.

  ENDMETHOD.
ENDCLASS.
