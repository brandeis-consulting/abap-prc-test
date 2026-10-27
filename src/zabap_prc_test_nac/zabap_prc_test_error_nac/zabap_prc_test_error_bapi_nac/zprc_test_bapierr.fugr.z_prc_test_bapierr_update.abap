FUNCTION Z_PRC_TEST_BAPIERR_UPDATE.
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_UUID) TYPE  SYSUUID_X16
*"     VALUE(IV_MSGTY) TYPE  SYMSGTY
*"----------------------------------------------------------------------
  CASE iv_msgty.
    WHEN 'E'.
      MESSAGE e017(zprc_test_bapierr).
    WHEN 'A'.
      MESSAGE a018(zprc_test_bapierr).
    WHEN 'X'.
      MESSAGE x019(zprc_test_bapierr).
  ENDCASE.

  INSERT zprc_test_bapier FROM @( VALUE #( uuid = iv_uuid ) ).
ENDFUNCTION.
