class ZPR_CO_EON_FORMS_QUERY_DOC_DET definition
  public
  inheriting from CL_PROXY_CLIENT
  create public .

public section.

  methods CONSTRUCTOR
    importing
      !DESTINATION type ref to IF_PROXY_DESTINATION optional
      !LOGICAL_PORT_NAME type PRX_LOGICAL_PORT_NAME optional
    preferred parameter LOGICAL_PORT_NAME
    raising
      CX_AI_SYSTEM_FAULT .
  methods EON_FORMS_QUERY_DOC_DETAILS
    importing
      !INPUT type ZPR_EON_FORMS_QUERY_DOC_DETAI3
    exporting
      !OUTPUT type ZPR_EON_FORMS_QUERY_DOC_DETAI2
    raising
      CX_AI_SYSTEM_FAULT .
protected section.
private section.
ENDCLASS.



CLASS ZPR_CO_EON_FORMS_QUERY_DOC_DET IMPLEMENTATION.


  method CONSTRUCTOR.

  super->constructor(
    class_name          = 'ZPR_CO_EON_FORMS_QUERY_DOC_DET'
    logical_port_name   = logical_port_name
    destination         = destination
  ).

  endmethod.


  method EON_FORMS_QUERY_DOC_DETAILS.

  data(lt_parmbind) = value abap_parmbind_tab(
    ( name = 'INPUT' kind = '0' value = ref #( INPUT ) )
    ( name = 'OUTPUT' kind = '1' value = ref #( OUTPUT ) )
  ).
  if_proxy_client~execute(
    exporting
      method_name = 'EON_FORMS_QUERY_DOC_DETAILS'
    changing
      parmbind_tab = lt_parmbind
  ).

  endmethod.
ENDCLASS.
