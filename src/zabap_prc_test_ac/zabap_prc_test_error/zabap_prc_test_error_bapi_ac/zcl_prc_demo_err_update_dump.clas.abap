"! <p class="shorttext synchronized">PRC demo: MESSAGE X in the update task</p>
"!
"! Scenario UPDATE_DUMP: the BAPI reports W + I and registers its update
"! function module, which raises MESSAGE X when it runs. 4-Commit sets the
"! local update task, so COMMIT WORK runs the module in the step session and
"! the dump aborts that session. 8-Isolation writes the failed step.
"!
"! Expected result: state START, retry 1, one step with exactly one message
"! SY/499 (generic abort text - the update message is only in ST22). The W and I
"! of the BAPI are lost with the session. Takes about 11 seconds.
"! <p class="shorttext synchronized">PRC demo: MESSAGE X in the update task</p>
"!
"! Scenario UPDATE_DUMP: the BAPI reports W + I and registers its update
"! function module, which raises MESSAGE X when it runs. 4-Commit sets the
"! local update task, so COMMIT WORK runs the module in the step session and
"! the dump aborts that session. 8-Isolation writes the failed step and finds
"! the short dump through the EPP identity the step session registered.
"!
"! Expected result: state START, retry 1, one step with
"! ZPRC_PROCESS_MESSAGE/011 (abort text "connection closed (no data)"),
"! 013 (MESSAGE_TYPE_X and program) and 014 (error analysis with the text of
"! the MESSAGE X). The W and I of the BAPI are lost with the session. Takes
"! about 11 seconds.
CLASS zcl_prc_demo_err_update_dump DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_err_update_dump IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Breakpoints - layers 7 to 1 and the process run in a session of their own:
    " use EXTERNAL (user) breakpoints there, debugging of RFC/background sessions on.
    "
    " 1. External: function module Z_PRC_TEST_BAPIERR_UPDATE (the MESSAGE X)
    " 2. External: ZCL_PRC_STEP_4_COMMIT, method ZIF_PRC_PROCESSING_STEP~EXECUTE,
    "    statement COMMIT WORK - the local update task starts here
    " 3. Normal (this session): ZCL_PRC_STEP_8_ISOLATION, method WRITE_ABORT -
    "    the abort text arrives in I_ABORT_MESSAGE
    DATA(uuid) = xco_cp=>uuid( )->value.

    zcl_prc_test_bapierr_proc=>start( i_uuid     = uuid
                                      i_scenario = zcl_prc_test_bapierr_proc=>scenario-update_dump ).

    zcl_prc_demo_err_output=>print( i_process_name = zcl_prc_test_bapierr_proc=>co_process_name
                                    i_external_id  = zcl_prc_test_bapierr_proc=>get_external_id( uuid )
                                    i_out          = out ).
  ENDMETHOD.

ENDCLASS.

