FUNCTION zxweb_elo_eugy_xmlsign_java.
*"----------------------------------------------------------------------
*"*"Lokális interfész:
*"  IMPORTING
*"     VALUE(IV_XML) TYPE  STRING
*"     VALUE(IV_MOD) TYPE  CHAR1 DEFAULT 's'
*"  EXPORTING
*"     VALUE(EV_XML) TYPE  STRING
*"     VALUE(EV_RETCODE) TYPE  CHAR3
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
* 05.03.2025 14:23:00   X0134   INC3905087
*----------------------------------------------------------------*

  DATA lv_additional_params TYPE char255.
  DATA lv_status            TYPE extcmdexex-status.
  DATA lv_exitcode          TYPE extcmdexex-exitcode.
  DATA lv_input_file        TYPE string.
  DATA lv_guid              TYPE guid_32.
  DATA lv_output_file       TYPE string.
  DATA lv_line              TYPE string.
  DATA lv_mess              TYPE string.
  DATA lv_cmdname           TYPE sxpgcolist-name.
  DATA lv_system            TYPE syst_sysid.

  DATA lt_exec_protocol     TYPE TABLE OF btcxpm WITH HEADER LINE.

  lv_system  = sy-sysid.
  lv_cmdname = 'ZXMLSIGN'.

  CLEAR: ev_retcode, ev_xml.

  lv_guid =  cl_system_uuid=>create_uuid_c32_static( ).

*  Globals tábla
  CASE iv_mod.
    WHEN 's'.  "Aláírás
      CONCATENATE '/usr/sap/' lv_system '/xmlsign/XMLSign/work/' lv_guid '_req.xml' INTO lv_input_file.
      CONCATENATE '/usr/sap/' lv_system '/xmlsign/XMLSign/work/' lv_guid '_req_signed.xml' INTO lv_output_file.

    WHEN 'v'.  "Aláírás ellenőrzés és titkosítás visszafejtése
      CONCATENATE '/usr/sap/' lv_system '/xmlsign/XMLSign/work/' lv_guid '_res.xml' INTO lv_input_file.
      CONCATENATE '/usr/sap/' lv_system '/xmlsign/XMLSign/work/' lv_guid '_res_decrypted.xml' INTO lv_output_file.

    WHEN 'QA'.
      CONCATENATE '/usr/sap/' lv_system '/xmlsign/XMLSign/work/' lv_guid '_req.xml' INTO lv_input_file.
      CONCATENATE '/usr/sap/' lv_system '/xmlsign/XMLSign/work/' lv_guid '_req_signed.xml' INTO lv_output_file.
      CONCATENATE '/usr/sap/' lv_system '/xmlsign/XMLSign/work/' lv_guid '_res.xml' INTO lv_input_file.
      CONCATENATE '/usr/sap/' lv_system '/xmlsign/XMLSign/work/' lv_guid '_res_decrypted.xml' INTO lv_output_file.

    WHEN OTHERS.
  ENDCASE.

* Fájl megnyitása írásra
  OPEN DATASET lv_input_file FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.

  IF sy-subrc <> 0.
    ev_retcode = 'MC1'.  "Fájl megnyitása sikertelen
    RETURN.

  ENDIF.

* Sorok kiírása
  TRANSFER iv_xml TO lv_input_file NO END OF LINE.

  IF sy-subrc <> 0.
    ev_retcode = 'MC2'.  "Fájl írása sikertelen
    CLOSE DATASET lv_input_file.
    RETURN.

  ENDIF.

* Fájl lezárása írásra
  CLOSE DATASET lv_input_file.

  CLEAR lv_additional_params.
  CONCATENATE '-' iv_mod INTO lv_additional_params.
  CONCATENATE lv_additional_params lv_input_file INTO lv_additional_params SEPARATED BY space.

  CALL FUNCTION 'SXPG_COMMAND_EXECUTE'
    EXPORTING
      commandname                   = lv_cmdname "'ZXMLSIGN'
      additional_parameters         = lv_additional_params
      operatingsystem               = sy-opsys
*     targetsystem                  = sy-host
*     destination                   = destination
      stdout                        = 'X'
      stderr                        = 'X'
      terminationwait               = 'X'
*     trace                         = trace
*     dialog                        = dialog
    IMPORTING
      status                        = lv_status
      exitcode                      = lv_exitcode
    TABLES
      exec_protocol                 = lt_exec_protocol
    EXCEPTIONS
      no_permission                 = 1
      command_not_found             = 2
      parameters_too_long           = 3
      security_risk                 = 4
      wrong_check_call_interface    = 5
      program_start_error           = 6
      program_termination_error     = 7
      x_error                       = 8
      parameter_expected            = 9
      too_many_parameters           = 10
      illegal_command               = 11
      wrong_asynchronous_parameters = 12
      cant_enq_tbtco_entry          = 13
      jobcount_generation_error     = 14
      OTHERS                        = 15.

  IF sy-subrc <> 0.
*   Implement suitable error handling here
    ev_retcode = 'MC3'.
    DELETE DATASET lv_input_file.
    DELETE DATASET lv_output_file.
    RETURN.

  ENDIF.


  IF lv_status = 'E' OR lv_exitcode <> 0.
    ev_retcode = 'MC4'.
    DELETE DATASET lv_input_file.
    DELETE DATASET lv_output_file.
    RETURN.

  ENDIF.

  OPEN DATASET lv_output_file FOR INPUT IN LEGACY TEXT MODE MESSAGE lv_mess. "ENCODING DEFAULT.
  IF sy-subrc = 0.
    DO.
      READ DATASET lv_output_file INTO lv_line.
      IF sy-subrc = 0.
        CONCATENATE ev_xml lv_line INTO ev_xml.

      ELSE.

        EXIT.
      ENDIF.
    ENDDO.

  ENDIF.

  CLOSE DATASET lv_output_file.

  DELETE DATASET lv_input_file.
  DELETE DATASET lv_output_file.

  ev_retcode = 'OK'.

ENDFUNCTION.