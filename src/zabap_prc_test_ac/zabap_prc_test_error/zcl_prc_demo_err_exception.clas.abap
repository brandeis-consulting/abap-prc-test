"! <p class="shorttext synchronized">PRC demo: unhandled exception in the BAPI</p>
"!
"! Scenario CALL_EXCEPTION: a division by zero inside the BAPI raises
"! CX_SY_ZERODIVIDE. No dump: 6-Unexpected catches it, rolls back and writes
"! the failed step with the exception text.
"!
"! Expected result: state START, retry 1, one step with an error message
"! SY/499 carrying the exception text; no BAPI message, no success header.
CLASS zcl_prc_demo_err_exception DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_err_exception IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Breakpoints - layers 7 to 1 and the process run in a session of their own:
    " use EXTERNAL (user) breakpoints there, debugging of RFC/background sessions on.
    "
    " 1. External: function module Z_PRC_TEST_BAPIERR (the division by zero)
    " 2. External: ZCL_PRC_STEP_6_UNEXPECTED, method ZIF_PRC_PROCESSING_STEP~EXECUTE,
    "    CATCH cx_root - ERROR holds the CX_SY_ZERODIVIDE
    " 3. Normal (this session): ZCL_PRC_STEP_9_EVENT - the step arrives as a
    "    normal result, the event is raised
    DATA(uuid) = xco_cp=>uuid( )->value.

    zcl_prc_test_bapierr_proc=>start( i_uuid     = uuid
                                      i_scenario = zcl_prc_test_bapierr_proc=>scenario-call_exception ).

    zcl_prc_demo_err_output=>print( i_process_name = zcl_prc_test_bapierr_proc=>co_process_name
                                    i_external_id  = zcl_prc_test_bapierr_proc=>get_external_id( uuid )
                                    i_out          = out ).
  ENDMETHOD.

ENDCLASS.

