*&---------------------------------------------------------------------*
*&  Include           ZBC_PR_MESSAGEQUEUE_MODULES
*&---------------------------------------------------------------------*
module d0100_pai input.
  case gv_okcode.
    when 'BACK' or 'EXIT' or 'CANC'.
      set screen 0.
      leave screen.
  endcase.
endmodule.                 " d0100_pai  INPUT

module d0100_pbo output.
  lcl_screen=>show( ir_slog_email = lr_slog_email ).
endmodule.