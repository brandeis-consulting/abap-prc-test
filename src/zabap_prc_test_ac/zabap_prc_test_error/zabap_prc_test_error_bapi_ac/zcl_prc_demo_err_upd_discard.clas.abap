"! <p class="shorttext synchronized">PRC demo: registered update discarded</p>
"!
"! Scenario CALL_ERROR_WITH_UPDATE: the BAPI registers its update function
"! module first and reports 2 E + W + I afterwards. The handler fails the step,
"! 5-Expected rolls back - and with it the registered update, which never runs.
"!
"! Expected result: state START, retry 1, the four BAPI messages in the step,
"! no marker row in table ZPRC_TEST_BAPIER for this UUID (nothing was posted).
CLASS zcl_prc_demo_err_upd_discard DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_err_upd_discard IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Breakpoints - layers 7 to 1 and the process run in a session of their own:
    " use EXTERNAL (user) breakpoints there, debugging of RFC/background sessions on.
    "
    " 1. External: function module Z_PRC_TEST_BAPIERR - the update is registered,
    "    then the errors go into the return table
    " 2. External: ZCL_PRC_STEP_5_EXPECTED, method ZIF_PRC_PROCESSING_STEP~EXECUTE,
    "    statement ROLLBACK ENTITIES - discards the registered update as well
    " 3. External: function module Z_PRC_TEST_BAPIERR_UPDATE - is never reached
    DATA(uuid) = xco_cp=>uuid( )->value.

    zcl_prc_test_bapierr_proc=>start( i_uuid     = uuid
                                      i_scenario = zcl_prc_test_bapierr_proc=>scenario-call_error_with_update ).

    zcl_prc_demo_err_output=>print( i_process_name = zcl_prc_test_bapierr_proc=>co_process_name
                                    i_external_id  = zcl_prc_test_bapierr_proc=>get_external_id( uuid )
                                    i_out          = out ).

    SELECT SINGLE @abap_true FROM ZI_PRC_TEST_BAPIER WHERE uuid = @uuid INTO @DATA(posted).
    out->write( |  Update task posted: { COND #( WHEN posted = abap_true THEN `yes` ELSE `no` ) }| ) ##NO_TEXT.
  ENDMETHOD.

ENDCLASS.

