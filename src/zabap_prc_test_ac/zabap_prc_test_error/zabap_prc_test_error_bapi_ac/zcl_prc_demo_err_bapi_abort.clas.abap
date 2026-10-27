"! <p class="shorttext synchronized">PRC demo: MESSAGE A in the BAPI</p>
"!
"! Scenario CALL_ABORT: the BAPI raises MESSAGE A instead of filling its return
"! table. The step session is aborted in the middle of the transition;
"! 8-Isolation writes the failed step.
"!
"! Expected result: state START, retry 1, one step with exactly one message
"! SY/499 whose text is the text of the MESSAGE A ("CALL_ABORT: MESSAGE A in
"! BAPI") - without message class and number.
"! <p class="shorttext synchronized">PRC demo: MESSAGE A in the BAPI</p>
"!
"! Scenario CALL_ABORT: the BAPI raises MESSAGE A instead of filling its return
"! table. The step session is aborted in the middle of the transition - without
"! a short dump; 8-Isolation writes the failed step.
"!
"! Expected result: state START, retry 1, one step with
"! ZPRC_PROCESS_MESSAGE/011 whose text is the text of the MESSAGE A
"! ("CALL_ABORT: MESSAGE A in BAPI") and 012, the hint where to look in ST22.
CLASS zcl_prc_demo_err_bapi_abort DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_err_bapi_abort IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Breakpoints - layers 7 to 1 and the process run in a session of their own:
    " use EXTERNAL (user) breakpoints there, debugging of RFC/background sessions on.
    "
    " 1. External: function module Z_PRC_TEST_BAPIERR (the MESSAGE A)
    " 2. External: ZCL_PRC_STEP_1_CORE, method ZIF_PRC_PROCESSING_STEP~EXECUTE,
    "    call of PERFORM_TRANSITION - the session never returns from it
    " 3. Normal (this session): ZCL_PRC_STEP_8_ISOLATION, method
    "    ZIF_PRC_PROCESSING_STEP~EXECUTE after RUN_INST - RESULTS has a MESSAGE
    "    and no INST; then WRITE_ABORT
    DATA(uuid) = xco_cp=>uuid( )->value.

    zcl_prc_test_bapierr_proc=>start( i_uuid     = uuid
                                      i_scenario = zcl_prc_test_bapierr_proc=>scenario-call_abort ).

    zcl_prc_demo_err_output=>print( i_process_name = zcl_prc_test_bapierr_proc=>co_process_name
                                    i_external_id  = zcl_prc_test_bapierr_proc=>get_external_id( uuid )
                                    i_out          = out ).
  ENDMETHOD.

ENDCLASS.

