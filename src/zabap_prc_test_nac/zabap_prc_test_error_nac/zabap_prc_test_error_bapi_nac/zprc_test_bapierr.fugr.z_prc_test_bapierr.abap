FUNCTION Z_PRC_TEST_BAPIERR.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_UUID) TYPE  SYSUUID_X16
*"     VALUE(IV_SCENARIO) TYPE  STRING
*"  EXPORTING
*"     REFERENCE(ET_RETURN) TYPE  BAPIRET2_T
*"----------------------------------------------------------------------
  CONSTANTS lc_id TYPE symsgid VALUE 'ZPRC_TEST_BAPIERR'.
  DATA lv_zero TYPE i.

  CLEAR et_return.

  CASE iv_scenario.
    WHEN 'NO_ERROR'.
      et_return = VALUE #( ( type = 'W' id = lc_id number = '001' )
                           ( type = 'I' id = lc_id number = '002' )
                           ( type = 'S' id = lc_id number = '003' ) ).
      CALL FUNCTION 'Z_PRC_TEST_BAPIERR_UPDATE' IN UPDATE TASK
        EXPORTING iv_uuid = iv_uuid iv_msgty = space.

    WHEN 'CALL_ERROR'.
      et_return = VALUE #( ( type = 'E' id = lc_id number = '004' )
                           ( type = 'E' id = lc_id number = '005' )
                           ( type = 'W' id = lc_id number = '006' )
                           ( type = 'I' id = lc_id number = '007' ) ).

    WHEN 'CALL_ERROR_WITH_UPDATE'.
      " Update already registered, then a business error occurs
      CALL FUNCTION 'Z_PRC_TEST_BAPIERR_UPDATE' IN UPDATE TASK
        EXPORTING iv_uuid = iv_uuid iv_msgty = space.
      et_return = VALUE #( ( type = 'E' id = lc_id number = '008' )
                           ( type = 'E' id = lc_id number = '009' )
                           ( type = 'W' id = lc_id number = '010' )
                           ( type = 'I' id = lc_id number = '011' ) ).

    WHEN 'CALL_MESSAGE_E'.
      MESSAGE e012(zprc_test_bapierr).

    WHEN 'CALL_EXCEPTION'.
      lv_zero = 1 / lv_zero.

    WHEN 'CALL_ABORT'.
      MESSAGE a013(zprc_test_bapierr).

    WHEN 'CALL_DUMP'.
      MESSAGE x014(zprc_test_bapierr).

    WHEN 'UPDATE_ERROR' OR 'UPDATE_ABORT' OR 'UPDATE_DUMP'.
      et_return = VALUE #( ( type = 'W' id = lc_id number = '015' )
                           ( type = 'I' id = lc_id number = '016' ) ).
      CALL FUNCTION 'Z_PRC_TEST_BAPIERR_UPDATE' IN UPDATE TASK
        EXPORTING iv_uuid  = iv_uuid
                  iv_msgty = SWITCH symsgty( iv_scenario
                                             WHEN 'UPDATE_ERROR' THEN 'E'
                                             WHEN 'UPDATE_ABORT' THEN 'A'
                                             ELSE 'X' ).
  ENDCASE.
ENDFUNCTION.
