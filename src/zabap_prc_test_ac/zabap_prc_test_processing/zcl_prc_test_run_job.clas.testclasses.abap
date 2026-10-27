"! Test job: one select option S_ID; every value becomes one object of the test process.
"! The ID ABORT makes SELECT abort the run (ABORT_RUN, after the run was created).
"! No notification at the end of the run: it would leave an object of process
"! PRC_RUN_COMPLETED behind (the notification itself is tested in ZCL_PRC_TEST_NOTIFICATION).
CLASS lcl_test_job DEFINITION FINAL INHERITING FROM zcl_prc_run_job FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS co_ids   TYPE zif_prc_run=>ty_run_parameter VALUE 'S_ID'.
    CONSTANTS co_abort TYPE string VALUE `ABORT`.
    CONSTANTS co_token TYPE symsgv VALUE 'PRC_RUNJOB_TEST'.
    METHODS if_apj_dt_exec_object~get_parameters REDEFINITION.
  PROTECTED SECTION.
    METHODS select               REDEFINITION.
    METHODS get_process          REDEFINITION.
    METHODS get_application_name REDEFINITION.
    METHODS notify_on_completion REDEFINITION.
ENDCLASS.

CLASS lcl_test_job IMPLEMENTATION.
  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( ( selname = co_ids kind = if_apj_dt_exec_object=>select_option
                                  datatype = 'C' length = 30 param_text = 'IDs' ) ).
  ENDMETHOD.

  METHOD select.
    DATA ids TYPE RANGE OF za_prc_createprocessedobject-processedobject.
    get_range( EXPORTING i_select_options = i_select_options
                         i_name           = co_ids
               IMPORTING e_range          = ids ).
    IF line_exists( ids[ low = co_abort ] ).
      " Run &1 aborted, see the application log for details
      abort_run( VALUE #( msgid = 'ZPRC_RUN' msgno = '008' msgv1 = co_token ) ).
    ENDIF.
    r_objects = VALUE #( FOR i IN ids ( id = i-low ) ).
  ENDMETHOD.

  METHOD get_process.
    r_process = VALUE #( name          = zcl_prc_test_proc_fixture=>co_process_name
                         factory_class = zcl_prc_test_proc_fixture=>co_factory ).
  ENDMETHOD.

  METHOD get_application_name.
    rv_application_name = zif_prc_run=>co_application_names-demo_rate_adjustment.
  ENDMETHOD.

  METHOD notify_on_completion.
    r_notify = abap_false.
  ENDMETHOD.
ENDCLASS.


"! The framework part of a run job: run, total number, objects, processing, abort.
CLASS ltc_run_job DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS creates_run_and_processes FOR TESTING.
    METHODS unknown_parameter_aborts  FOR TESTING.
    METHODS abort_marks_run           FOR TESTING.
ENDCLASS.


CLASS ltc_run_job IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    " Aborted test runs have no objects: delete them by their token
    DELETE FROM zprc_run WHERE msgv1 = @lcl_test_job=>co_token.
    COMMIT WORK.
  ENDMETHOD.


  METHOD creates_run_and_processes.
    " Same entry point as the application job (runs in its own LUW, commits)
    TRY.
        NEW lcl_test_job( )->if_apj_rt_exec_object~execute(
            VALUE #( ( selname = lcl_test_job=>co_ids kind = 'S' sign = 'I' option = 'EQ' low = 'RUNJOB1' )
                     ( selname = lcl_test_job=>co_ids kind = 'S' sign = 'I' option = 'EQ' low = 'RUNJOB2' ) ) ).
      CATCH cx_root INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |Job failed: { lo_error->get_text( ) }| ).
    ENDTRY.

    SELECT ExternalProcessedObjectID, RunUUID, State
      FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name
      ORDER BY ExternalProcessedObjectID
      INTO TABLE @DATA(objects).

    cl_abap_unit_assert=>assert_equals( act = lines( objects ) exp = 2 msg = 'One object per selected ID' ).
    cl_abap_unit_assert=>assert_equals( act = objects[ 1 ]-ExternalProcessedObjectID exp = 'RUNJOB1' ).
    cl_abap_unit_assert=>assert_not_initial( act = objects[ 1 ]-RunUUID msg = 'Object belongs to the run' ).
    cl_abap_unit_assert=>assert_equals( act = objects[ 2 ]-RunUUID exp = objects[ 1 ]-RunUUID msg = 'Same run' ).
    LOOP AT objects INTO DATA(object).
      cl_abap_unit_assert=>assert_equals( act = object-State exp = zif_prc_process=>co_finished msg = 'Processed in the run' ).
    ENDLOOP.

    DATA(run_uuid) = objects[ 1 ]-RunUUID.
    SELECT SINGLE TotalNumber, ApplicationName, ExecutionStatus
      FROM zr_prc_run WITH PRIVILEGED ACCESS
      WHERE UUID = @run_uuid
      INTO @DATA(run).
    cl_abap_unit_assert=>assert_equals( act = run-TotalNumber exp = 2 msg = 'Total number set by the framework' ).
    cl_abap_unit_assert=>assert_equals( act = run-ApplicationName exp = zif_prc_run=>co_application_names-demo_rate_adjustment ).
    cl_abap_unit_assert=>assert_equals( act = run-ExecutionStatus exp = zif_prc_run=>co_execution_status-finished
                                        msg = 'Run finished and saved' ).
  ENDMETHOD.


  METHOD unknown_parameter_aborts.
    " Parameter not defined by the job: abort before a run exists (formerly ASSERT)
    TRY.
        NEW lcl_test_job( )->if_apj_rt_exec_object~execute(
            VALUE #( ( selname = 'S_XXX' kind = 'S' sign = 'I' option = 'EQ' low = 'X' ) ) ).
        cl_abap_unit_assert=>fail( msg = 'Job must be aborted' ).
      CATCH cx_apj_rt_content INTO DATA(lo_abort).
        cl_abap_unit_assert=>assert_equals( act = lo_abort->if_t100_message~t100key-msgid exp = 'ZPRC_RUN' ).
        cl_abap_unit_assert=>assert_equals( act = lo_abort->if_t100_message~t100key-msgno exp = '001'
                                            msg = 'Parameter is not defined in job' ).
    ENDTRY.
  ENDMETHOD.


  METHOD abort_marks_run.
    TRY.
        NEW lcl_test_job( )->if_apj_rt_exec_object~execute(
            VALUE #( ( selname = lcl_test_job=>co_ids kind = 'S' sign = 'I' option = 'EQ' low = lcl_test_job=>co_abort ) ) ).
        cl_abap_unit_assert=>fail( msg = 'Job must be aborted' ).
      CATCH cx_apj_rt_content INTO DATA(lo_abort).
        cl_abap_unit_assert=>assert_equals( act = lo_abort->if_t100_message~t100key-msgno exp = '008' ).
    ENDTRY.

    SELECT SINGLE ExecutionStatus, MessageClass, MessageNumber, MessageText, TotalNumber
      FROM zi_prc_run WITH PRIVILEGED ACCESS
      WHERE MessageVariable1 = @lcl_test_job=>co_token
      INTO @DATA(run).
    cl_abap_unit_assert=>assert_subrc( msg = 'Aborted run with its reason saved' ).
    cl_abap_unit_assert=>assert_equals( act = run-ExecutionStatus exp = zif_prc_run=>co_execution_status-aborted ).
    cl_abap_unit_assert=>assert_equals( act = run-MessageClass exp = 'ZPRC_RUN' ).
    cl_abap_unit_assert=>assert_equals( act = run-MessageNumber exp = '008' ).
    cl_abap_unit_assert=>assert_not_initial( act = run-MessageText msg = 'Text for search/fallback' ).
    cl_abap_unit_assert=>assert_initial( act = run-TotalNumber msg = 'Nothing after the abort was saved' ).
  ENDMETHOD.

ENDCLASS.


"! initiateRun of the run BO (Nr. 40.9). Template and parameters are checked before the run
"! is created: the save phase cannot change the run anymore, a run whose job cannot be
"! scheduled would stay "planned". Nothing is committed here, so no job is ever scheduled.
"! ZAJT_PRC_RETRY_JOB is a template of the core (the run job templates belong to the demos).
CLASS ltc_initiate_run DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS co_job_name         TYPE c LENGTH 120 VALUE 'PRC_INITIATE_RUN_TEST'.
    CONSTANTS co_unknown_template TYPE c LENGTH 30 VALUE 'ZPRC_DOES_NOT_EXIST'.
    CONSTANTS co_core_template    TYPE c LENGTH 30 VALUE 'ZAJT_PRC_RETRY_JOB'.

    DATA failed   TYPE RESPONSE FOR FAILED EARLY zr_prc_runtp.
    DATA reported TYPE RESPONSE FOR REPORTED EARLY zr_prc_runtp.
    DATA mapped   TYPE RESPONSE FOR MAPPED EARLY zr_prc_runtp.

    METHODS teardown.
    METHODS unknown_template_rejected   FOR TESTING.
    METHODS unknown_parameter_rejected  FOR TESTING.
    METHODS maps_new_run_to_cid         FOR TESTING.
    METHODS initiator_reports_rejection FOR TESTING.

    "! initiateRun with %cid INIT, not committed; fills failed/reported/mapped
    METHODS initiate
      IMPORTING i_template   TYPE csequence
                i_parameters TYPE cl_apj_rt_api=>tt_job_parameter_value OPTIONAL.
    "! Rejected: failed for INIT, the given message reported for INIT, no run created
    METHODS assert_rejected
      IMPORTING i_msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_initiate_run IMPLEMENTATION.

  METHOD teardown.
    ROLLBACK ENTITIES.
    " Safety net only: nothing is committed in these tests
    DELETE FROM zprc_run WHERE job_name = @co_job_name.
    COMMIT WORK.
  ENDMETHOD.


  METHOD initiate.
    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           EXECUTE initiateRun
           FROM VALUE #( ( %cid   = 'INIT'
                           %param = VALUE #( applicationName    = zif_prc_run=>co_application_names-demo_rate_adjustment
                                             jobName            = co_job_name
                                             jobTemplateName    = i_template
                                             selectOptionString = /ui2/cl_json=>serialize( data = i_parameters ) ) ) )
           FAILED failed
           REPORTED reported
           MAPPED mapped.
  ENDMETHOD.


  METHOD assert_rejected.
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( failed-run[ KEY cid %cid = 'INIT' ] ) )
                                      msg = 'initiateRun rejected' ).
    cl_abap_unit_assert=>assert_initial( act = mapped-run msg = 'No run created' ).

    DATA(found_message) = abap_false.
    LOOP AT reported-run INTO DATA(report) USING KEY cid WHERE %cid = 'INIT'.
      IF report-%msg IS INSTANCE OF if_t100_message.
        DATA(t100key) = CAST if_t100_message( report-%msg )->t100key.
        IF t100key-msgid = 'ZPRC_RUN' AND t100key-msgno = i_msgno.
          found_message = abap_true.
        ENDIF.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true( act = found_message msg = |Message ZPRC_RUN/{ i_msgno } reported for the caller's %cid| ).
  ENDMETHOD.


  METHOD unknown_template_rejected.
    initiate( co_unknown_template ).
    " Job template &1 does not exist or you are not authorized to schedule it
    assert_rejected( '010' ).
  ENDMETHOD.


  METHOD unknown_parameter_rejected.
    initiate( i_template   = co_core_template
              i_parameters = VALUE #( ( name    = 'S_XXX'
                                        t_value = VALUE #( ( sign = 'I' option = 'EQ' low = 'X' ) ) ) ) ).
    " Parameter &1 is not defined in job &2
    assert_rejected( '001' ).
  ENDMETHOD.


  METHOD maps_new_run_to_cid.
    initiate( co_core_template ).
    cl_abap_unit_assert=>assert_initial( act = failed msg = 'initiateRun accepted' ).

    DATA(run_uuid) = VALUE sysuuid_x16( mapped-run[ KEY cid %cid = 'INIT' ]-uuid OPTIONAL ).
    cl_abap_unit_assert=>assert_not_initial( act = run_uuid msg = 'New run mapped to the caller''s %cid' ).

    " The caller can address the new run (still in the transactional buffer)
    READ ENTITIES OF zr_prc_runtp
         ENTITY Run
         FIELDS ( JobName ExecutionStatus )
         WITH VALUE #( ( uuid = run_uuid ) )
         RESULT DATA(runs).
    cl_abap_unit_assert=>assert_equals( act = lines( runs ) exp = 1 msg = 'New run readable' ).
    cl_abap_unit_assert=>assert_equals( act = runs[ 1 ]-JobName exp = co_job_name ).
    cl_abap_unit_assert=>assert_equals( act = runs[ 1 ]-ExecutionStatus exp = zif_prc_run=>co_execution_status-planned ).
    " teardown: ROLLBACK ENTITIES - the job is never scheduled
  ENDMETHOD.


  METHOD initiator_reports_rejection.
    " ZCL_PRC_RUN_INITIATOR=>SCHEDULE_RUN (used by apps such as the demo contract app):
    " a rejected run comes back as messages instead of a short dump (formerly ASSERT)
    DATA lt_messages TYPE zcl_prc_run_initiator=>tt_messages.

    DATA(run_uuid) = zcl_prc_run_initiator=>get_instance( )->schedule_run(
      EXPORTING iv_selection_option_json = ``
                it_parameter_table       = VALUE #( ( name = 'S_XXX' value = `X` ) )
                iv_application_name      = zif_prc_run=>co_application_names-demo_rate_adjustment
                iv_job_name              = CONV #( co_job_name )
                iv_job_template_name     = co_core_template
      IMPORTING et_messages              = lt_messages ).

    cl_abap_unit_assert=>assert_initial( act = run_uuid msg = 'No run for a rejected request' ).
    DATA(found_message) = abap_false.
    LOOP AT lt_messages INTO DATA(lo_message).
      IF lo_message IS INSTANCE OF if_t100_message.
        DATA(t100key) = CAST if_t100_message( lo_message )->t100key.
        IF t100key-msgid = 'ZPRC_RUN' AND t100key-msgno = '001'.
          found_message = abap_true.
        ENDIF.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true( act = found_message msg = 'Reason ZPRC_RUN/001 passed to the caller' ).
  ENDMETHOD.

ENDCLASS.
