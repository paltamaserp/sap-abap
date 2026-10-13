*&---------------------------------------------------------------------*
*& Report ZEBF_PR_QMMH
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZPR_QMMH MESSAGE-ID zebf_pr_trigger.

INCLUDE zpr_trigger_qmhh_top.

RANGES gr_waers FOR zprt_pr_dcqm-waers.
DATA ls_waers LIKE LINE OF gr_waers.
*--------------------------------------------------------------------*
*SELECTION-SCREEN
*--------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-b01.
SELECT-OPTIONS:
              s_exbiln          FOR _app-s_exbilldocno    ,
              s_envelo          FOR _app-s_envelope       ,
              s_vkont           FOR _app-s_vkont          ,
              s_pymet           FOR _app-s_pymet          ,
              s_erdat           FOR _app-s_erdat          ,
              s_ertim           FOR _app-s_ertim          ,
              s_ernam           FOR _app-s_ernam          ,
              s_postcd          FOR _app-s_post_code1     ,
              s_bukrs           FOR _app-s_bukrs          ,
              s_doc_ty          FOR _app-s_doc_type       ,
              s_doc_c           FOR _app-s_doc_cat        ,
              s_opbel           FOR _app-s_opbel          ,
              s_amnt            FOR _app-s_amnt           .
PARAMETERS    p_waers TYPE waers.
SELECT-OPTIONS:
              s_dest            FOR _app-s_destination    ,
              s_copri           FOR _app-s_copri          ,
              s_gpart           FOR _app-s_gpart          ,
              s_dudate          FOR _app-s_duedate        ,
              s_bankac          FOR _app-s_bankaccountnum ,
              s_giro            FOR _app-s_giro           ,
              s_name1           FOR _app-s_name1          ,
              s_sysid           FOR _app-s_sysid          ,
              s_land1           FOR _app-s_land1          ,
              s_ab              FOR _app-s_ab             ,
              s_bis             FOR _app-s_bis            ,
              s_tarift          FOR _app-s_tariftyp       ,
              s_aklass          FOR _app-s_aklasse        ,
              s_sparte          FOR _app-s_sparte         ,
              s_mahns           FOR _app-s_mahns          ,
              s_mahnv           FOR _app-s_mahnv          ,
              s_zbizc           FOR _app-s_zbizcat        ,
              s_form            FOR _app-s_form           ,
              s_cotyp           FOR _app-s_cotyp          ,
              s_filen           FOR _app-s_filename       ,
              s_envkey          FOR _app-s_envkey         ,
              s_chenum          FOR _app-s_chenum         ,
              s_blckdc          FOR _app-s_block_dc       ,
              s_blckqm          FOR _app-s_block_qm       .

SELECTION-SCREEN END OF BLOCK b1.

*--------------------------------------------------------------------*
*INITIALIZATION
*--------------------------------------------------------------------*

INITIALIZATION.

*--------------------------------------------------------------------*
*AT SELECTION-SCREEN
*--------------------------------------------------------------------*

AT SELECTION-SCREEN.

  IF NOT ( s_amnt-option EQ 'EQ' AND s_amnt-low EQ 0 AND s_amnt-high EQ 0 ).
    IF s_amnt[] IS NOT INITIAL
       AND p_waers IS INITIAL.
      MESSAGE e057(zebf_pr).
*   Ha megadott összeget, akkor adjon meg pénznemet is.
    ENDIF.
  ENDIF.


*--------------------------------------------------------------------*
*START-OF-SELECTION
*--------------------------------------------------------------------*

START-OF-SELECTION.

*Pénznem szelekció. Tizedejegy korrekció
  DATA lv_faktor TYPE i.
  DATA ls_tcurx TYPE tcurx.
  SELECT SINGLE * FROM tcurx INTO ls_tcurx
    WHERE currkey EQ p_waers.
  IF sy-subrc NE 0.
    ls_tcurx-currdec = 2.
  ENDIF.
  lv_faktor = 2 - ls_tcurx-currdec.

  LOOP AT s_amnt.
    s_amnt-low = s_amnt-low / ( 10 ** lv_faktor ).
    s_amnt-high = s_amnt-high / ( 10 ** lv_faktor ).
    MODIFY s_amnt.
  ENDLOOP.
  IF p_waers IS NOT INITIAL.
    CLEAR ls_waers.
    ls_waers-sign = 'I'.
    ls_waers-option = 'EQ'.
    ls_waers-low = p_waers.
    APPEND ls_waers TO gr_waers.
  ENDIF.

  SELECT * FROM zprt_pr_dcqm
    INTO CORRESPONDING FIELDS OF TABLE gt_zprt_pr_dcqm
    WHERE exbilldocno         IN  s_exbiln
*duplán van...
*          AND envelope        IN  s_envelo
          AND envelope        IN  s_envelo
          AND vkont           IN  s_vkont
          AND pymet           IN  s_pymet
          AND erdat           IN  s_erdat
          AND ertim           IN  s_ertim
          AND ernam           IN  s_ernam
          AND post_code1      IN  s_postcd
          AND bukrs           IN  s_bukrs
          AND doc_type        IN  s_doc_ty
          AND doc_cat         IN  s_doc_c
          AND opbel           IN  s_opbel
          AND amnt            IN  s_amnt
          AND waers           IN  gr_waers
          AND destination     IN  s_dest
          AND copri           IN  s_copri
          AND gpart           IN  s_gpart
          AND duedate         IN  s_dudate
          AND bankaccountnum  IN  s_bankac
          AND giro            IN  s_giro
          AND name1           IN  s_name1
          AND sysid           IN  s_sysid
          AND land1           IN  s_land1
          AND ab              IN  s_ab
          AND bis             IN  s_bis
          AND tariftyp        IN  s_tarift
          AND aklasse         IN  s_aklass
          AND sparte          IN  s_sparte
          AND mahns           IN  s_mahns
          AND mahnv           IN  s_mahnv
          AND zbizcat         IN  s_zbizc
          AND form            IN  s_form
          AND cotyp           IN  s_cotyp
          AND filename        IN  s_filen
          AND envkey          IN  s_envkey
          AND cheqnumbr       IN  s_chenum
          AND block_dc        IN  s_blckdc
          AND block_qm        IN  s_blckqm.
    if sy-subrc <> 0. message e000(zpr) into data(lv_error). endif.

*--------------------------------------------------------------------*
*END-OF-SELECTION
*--------------------------------------------------------------------*

END-OF-SELECTION.

  IF gt_zprt_pr_dcqm IS NOT INITIAL.
    CALL FUNCTION 'REUSE_ALV_FIELDCATALOG_MERGE'
     EXPORTING
       i_program_name               = sy-repid
       i_structure_name             = 'zprt_pr_dcqm'
      CHANGING
        ct_fieldcat                  = gt_fieldcatalog
     EXCEPTIONS
       inconsistent_interface       = 1
       program_error                = 2
       OTHERS                       = 3.
    IF sy-subrc = 0.
      CALL FUNCTION 'REUSE_ALV_LIST_DISPLAY'
       EXPORTING
         i_callback_program             = sy-repid
         it_fieldcat                    = gt_fieldcatalog
         i_save                         = 'A'
       TABLES
          t_outtab                       = gt_zprt_pr_dcqm
       EXCEPTIONS
         program_error                  = 1
         OTHERS                         = 2.
      IF sy-subrc = 0.
        MESSAGE s009.
      ELSE.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
    ELSE.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDIF.