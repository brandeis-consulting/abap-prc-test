"! <p class="shorttext synchronized">PRC Test: C1 wrapper for BAPI Z_PRC_TEST_BAPIERR</p>
"!
"! Tier-2 wrapper: makes the classic test BAPI (Standard ABAP, update task)
"! usable from ABAP Cloud. Intentionally thin - no EXCEPTIONS addition, so
"! MESSAGE E/A/X and runtime errors of the BAPI reach the caller unchanged.
"! That behaviour is exactly what the PRC error handling tests verify.
CLASS zcl_prc_test_bapierr_wrap DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES tt_return TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY.

    "! Calls BAPI Z_PRC_TEST_BAPIERR.
    "!
    "! @parameter i_uuid     | UUID of the processed object, used as marker key
    "! @parameter i_scenario | Scenario, see ZCL_PRC_TEST_BAPIERR_PROC=&gt;SCENARIO
    "! @parameter r_return   | BAPI return table
    CLASS-METHODS call_bapi IMPORTING i_uuid          TYPE sysuuid_x16
                                      i_scenario      TYPE string
                            RETURNING VALUE(r_return) TYPE tt_return.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_bapierr_wrap IMPLEMENTATION.

  METHOD call_bapi.
    DATA lt_return TYPE bapiret2_t.

    CALL FUNCTION 'Z_PRC_TEST_BAPIERR'
      EXPORTING iv_uuid     = i_uuid
                iv_scenario = i_scenario
      IMPORTING et_return   = lt_return.

    r_return = lt_return.
  ENDMETHOD.

ENDCLASS.
