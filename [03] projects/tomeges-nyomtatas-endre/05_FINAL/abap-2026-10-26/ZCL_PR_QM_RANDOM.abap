"! Valódi véletlenszám-szolgáltató a mintavételhez: a rendszer saját generátorát
"! használja. Külön osztály, hogy a mintavételi logika tesztben kiváltható legyen.
class ZCL_PR_QM_RANDOM definition
  public
  create public .

public section.

  interfaces ZIF_PR_QM_RANDOM .
protected section.
private section.
ENDCLASS.



CLASS ZCL_PR_QM_RANDOM IMPLEMENTATION.


  METHOD zif_pr_qm_random~get_int.
    " Minden híváshoz új generátort készítünk, mert a felső határ hívásonként
    " változik (a mintavétel során egyre kisebb a még hátralévő halmaz).
    DATA lv_error_text TYPE string.

    IF iv_max LT 1.
      RAISE EXCEPTION TYPE zcx_form_message_error
        MESSAGE e001(zpr_qm)
        WITH iv_max.
    ENDIF.

    TRY.
        DATA(lo_random) = cl_abap_random_int=>create(
                            seed = cl_abap_random=>seed( )
                            min  = 1
                            max  = iv_max ).
        rv_value = lo_random->get_next( ).
      CATCH cx_abap_random INTO DATA(lx_random).
        lv_error_text = lx_random->get_text( ).
        RAISE EXCEPTION TYPE zcx_form_message_error
          MESSAGE e002(zpr_qm)
          WITH lv_error_text.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.