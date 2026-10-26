INTERFACE zif_pr_qm_random PUBLIC.

  METHODS get_int
    IMPORTING
      iv_max          TYPE i
    RETURNING
      VALUE(rv_value) TYPE i
    RAISING
      zcx_form_message_error.

ENDINTERFACE.