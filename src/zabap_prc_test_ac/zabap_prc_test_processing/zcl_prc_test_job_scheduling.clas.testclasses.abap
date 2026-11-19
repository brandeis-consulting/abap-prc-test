"! Records the scheduled jobs; fails on request like the job framework would
CLASS lcl_scheduler_double DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_prc_job_scheduler.
    TYPES: BEGIN OF ty_call,
             template   TYPE cl_apj_rt_api=>ty_template_name,
             text       TYPE cl_apj_rt_api=>ty_job_text,
             parameters TYPE cl_apj_rt_api=>tt_job_parameter_value,
           END OF ty_call,
           tt_calls TYPE STANDARD TABLE OF ty_call WITH EMPTY KEY.
    DATA calls TYPE tt_calls.
    DATA fail  TYPE abap_bool.
ENDCLASS.

CLASS lcl_scheduler_double IMPLEMENTATION.
  METHOD zif_prc_job_scheduler~schedule_immediately.
    IF fail = abap_true.
      RAISE EXCEPTION NEW cx_apj_rt( ).
    ENDIF.
    APPEND VALUE #( template = i_template_name text = i_job_text parameters = i_parameters ) TO calls.
  ENDMETHOD.

  METHOD zif_prc_job_scheduler~can_schedule.
    " The checks of initiateRun are tested with the real job framework (ZCL_PRC_TEST_RUN_JOB)
    r_can_schedule = abap_true.
  ENDMETHOD.

  METHOD zif_prc_job_scheduler~get_template_parameters.
    " Not supported: initiateRun skips the parameter check
    CLEAR: e_supported, e_names.
  ENDMETHOD.
ENDCLASS.


"! Records the scheduled bgPF processes; fails on request like the bgPF framework would
CLASS lcl_bgpf_double DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_prc_bgpf_scheduler.
    DATA calls TYPE STANDARD TABLE OF zif_prc_processing_engine=>tt_parameters WITH EMPTY KEY.
    DATA fail  TYPE abap_bool.
ENDCLASS.

CLASS lcl_bgpf_double IMPLEMENTATION.
  METHOD zif_prc_bgpf_scheduler~schedule.
    IF fail = abap_true.
      RAISE EXCEPTION NEW cx_bgmc_operation( ).
    ENDIF.
    APPEND i_parameters TO calls.
  ENDMETHOD.
ENDCLASS.


"! Helpers for the processing API tests: one test object of the fixture process
CLASS lcl_object DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS co_external_id TYPE c LENGTH 10 VALUE 'SCHED1'.
    CLASS-METHODS to_create RETURNING VALUE(r_objects) TYPE zcl_prc_processing_api=>tt_create_processed_objects.
    CLASS-METHODS read_uuid RETURNING VALUE(r_uuid) TYPE sysuuid_x16.
    CLASS-METHODS read_state RETURNING VALUE(r_state) TYPE zr_prc_processedobject-State.
ENDCLASS.

CLASS lcl_object IMPLEMENTATION.
  METHOD to_create.
    r_objects = VALUE #( ( processName      = zcl_prc_test_proc_fixture=>co_process_name
                           factoryClassName = zcl_prc_test_proc_fixture=>co_factory
                           processedObject  = co_external_id ) ).
  ENDMETHOD.

  METHOD read_uuid.
    SELECT SINGLE UUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name AND ExternalProcessedObjectID = @co_external_id
      INTO @r_uuid.
  ENDMETHOD.

  METHOD read_state.
    SELECT SINGLE State FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name AND ExternalProcessedObjectID = @co_external_id
      INTO @r_state.
  ENDMETHOD.
ENDCLASS.


"! initiateRun and the save of the run BO
CLASS ltc_run_app_save DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    CONSTANTS co_job_name TYPE c LENGTH 120 VALUE 'PRC_SCHEDULING_TEST'.
    CONSTANTS co_template TYPE c LENGTH 30 VALUE 'ZAJT_PRC_RETRY_JOB'.

    DATA double TYPE REF TO lcl_scheduler_double.

    METHODS setup.
    METHODS teardown.
    METHODS commit_schedules_job       FOR TESTING.
    METHODS scheduling_error_reported  FOR TESTING.
    METHODS rolled_back_not_scheduled  FOR TESTING.

    METHODS initiate RETURNING VALUE(r_run_uuid) TYPE sysuuid_x16.
    METHODS delete_runs.
ENDCLASS.


CLASS ltc_run_app_save IMPLEMENTATION.

  METHOD setup.
    double = NEW #( ).
    zcl_prc_job_scheduler_injector=>inject( double ).
    delete_runs( ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_job_scheduler_injector=>reset( ).
    delete_runs( ).
  ENDMETHOD.


  METHOD initiate.
    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           EXECUTE initiateRun
           FROM VALUE #( ( %cid   = 'INIT'
                           %param = VALUE #( applicationName    = zcl_prc_test_proc_fixture=>co_application_name
                                             jobName            = co_job_name
                                             jobTemplateName    = co_template
                                             selectOptionString = `[]` ) ) )
           MAPPED DATA(mapped)
           FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( act = failed msg = 'initiateRun accepted' ).
    r_run_uuid = mapped-run[ 1 ]-uuid.
  ENDMETHOD.


  METHOD commit_schedules_job.
    DATA(run_uuid) = initiate( ).
    COMMIT ENTITIES RESPONSE OF zr_prc_runtp FAILED DATA(failed) REPORTED DATA(reported) ##NEEDED.

    cl_abap_unit_assert=>assert_initial( act = failed msg = 'Saved' ).
    cl_abap_unit_assert=>assert_equals( act = lines( double->calls ) exp = 1 msg = 'One job scheduled with the commit' ).
    DATA(call) = double->calls[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = call-template exp = co_template ).
    cl_abap_unit_assert=>assert_equals( act = condense( CONV string( call-text ) ) exp = condense( CONV string( co_job_name ) ) ).

    " The job finds its run via P_UUID
    DATA(p_uuid) = VALUE #( call-parameters[ name = zif_prc_run=>co_parameter-p_uuid ]-t_value[ 1 ]-low OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = CONV sysuuid_x16( p_uuid ) exp = run_uuid msg = 'P_UUID is the new run' ).

    SELECT SINGLE execution_status FROM zprc_run WHERE uuid = @run_uuid INTO @DATA(status).
    cl_abap_unit_assert=>assert_equals( act = status exp = zif_prc_run=>co_execution_status-planned ).
  ENDMETHOD.


  METHOD scheduling_error_reported.
    double->fail = abap_true.
    DATA(run_uuid) = initiate( ).
    COMMIT ENTITIES RESPONSE OF zr_prc_runtp FAILED DATA(failed) ##NEEDED REPORTED DATA(reported).

    " Job template &1 could not be scheduled: &2&3&4
    DATA(found) = abap_false.
    LOOP AT reported-%other INTO DATA(message).
      IF message IS INSTANCE OF if_t100_message.
        DATA(key) = CAST if_t100_message( message )->t100key.
        IF key-msgid = 'ZPRC_RUN' AND key-msgno = '009'.
          found = abap_true.
        ENDIF.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true( act = found msg = 'Caller is told why no job runs (ZPRC_RUN/009)' ).

    " The run is saved anyway and stays planned
    SELECT SINGLE execution_status FROM zprc_run WHERE uuid = @run_uuid INTO @DATA(status).
    cl_abap_unit_assert=>assert_equals( act = status exp = zif_prc_run=>co_execution_status-planned ).
  ENDMETHOD.


  METHOD rolled_back_not_scheduled.
    " A rolled-back initiateRun leaves its job parameters behind - they must not lead to a job
    initiate( ).
    ROLLBACK ENTITIES.
    initiate( ).
    COMMIT ENTITIES.

    cl_abap_unit_assert=>assert_equals( act = lines( double->calls ) exp = 1 msg = 'Only the job of the saved run' ).
  ENDMETHOD.


  METHOD delete_runs.
    SELECT uuid FROM zprc_run WHERE job_name = @co_job_name INTO TABLE @DATA(runs).
    LOOP AT runs INTO DATA(run).
      DELETE FROM zprc_run_params WHERE job_uuid = @run-uuid.
    ENDLOOP.
    DELETE FROM zprc_run WHERE job_name = @co_job_name.
    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.


"! Processing API: create and schedule as application job
CLASS ltc_api_job DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA double TYPE REF TO lcl_scheduler_double.

    METHODS setup.
    METHODS teardown.
    METHODS schedules_retry_job        FOR TESTING RAISING cx_apj_rt.
    METHODS no_commit_by_the_api       FOR TESTING RAISING cx_apj_rt.
    METHODS error_reaches_caller       FOR TESTING.
    METHODS deprecated_tolerates_error FOR TESTING.
ENDCLASS.


CLASS ltc_api_job IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    double = NEW #( ).
    zcl_prc_job_scheduler_injector=>inject( double ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK WORK.
    zcl_prc_job_scheduler_injector=>reset( ).
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD schedules_retry_job.
    zcl_prc_processing_api=>get_instance( )->create_and_schedule_job( lcl_object=>to_create( ) ).
    DATA(uuid) = lcl_object=>read_uuid( ).

    cl_abap_unit_assert=>assert_equals( act = lines( double->calls ) exp = 1 ).
    DATA(call) = double->calls[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = call-template exp = zcl_prc_retry_job=>co_apj_template_name
                                        msg = 'The retry job processes the new objects' ).
    DATA(scheduled_uuid) = VALUE #( call-parameters[ name = zcl_prc_retry_job=>co_parameter-uuid ]-t_value[ 1 ]-low OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = CONV sysuuid_x16( scheduled_uuid ) exp = uuid
                                        msg = 'Restricted to the new objects' ).
  ENDMETHOD.


  METHOD no_commit_by_the_api.
    " The caller's LUW decides: after a rollback nothing is left
    zcl_prc_processing_api=>get_instance( )->create_and_schedule_job( lcl_object=>to_create( ) ).
    ROLLBACK WORK.
    cl_abap_unit_assert=>assert_initial( act = lcl_object=>read_uuid( ) msg = 'Not committed by the API' ).
  ENDMETHOD.


  METHOD error_reaches_caller.
    " The caller asked for a job explicitly - a scheduling error must reach him
    double->fail = abap_true.
    TRY.
        zcl_prc_processing_api=>get_instance( )->create_and_schedule_job( lcl_object=>to_create( ) ).
        cl_abap_unit_assert=>fail( 'CX_APJ_RT expected' ).
      CATCH cx_apj_rt ##NO_HANDLER.
        " expected
    ENDTRY.
    " Written, not committed: the caller can roll back
    ROLLBACK WORK.
    cl_abap_unit_assert=>assert_initial( act = lcl_object=>read_uuid( ) msg = 'Nothing committed' ).
  ENDMETHOD.


  METHOD deprecated_tolerates_error.
    " Unchanged behaviour of the deprecated method: created, committed, stays due for the retry job
    double->fail = abap_true.
    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = lcl_object=>to_create( )
        i_perform_commit           = abap_true
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-appl_job_execution ).
    cl_abap_unit_assert=>assert_equals( act = lcl_object=>read_state( ) exp = zif_prc_process=>co_start ).
  ENDMETHOD.

ENDCLASS.


"! Processing API: create and schedule via bgPF
CLASS ltc_api_bgpf DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA double TYPE REF TO lcl_bgpf_double.

    METHODS setup.
    METHODS teardown.
    METHODS schedules_new_objects      FOR TESTING RAISING cx_bgmc.
    METHODS no_commit_by_the_api       FOR TESTING RAISING cx_bgmc.
    METHODS error_reaches_caller       FOR TESTING.
    METHODS deprecated_tolerates_error FOR TESTING.
ENDCLASS.


CLASS ltc_api_bgpf IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    double = NEW #( ).
    zcl_prc_bgpf_sched_injector=>inject( double ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK WORK.
    zcl_prc_bgpf_sched_injector=>reset( ).
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD schedules_new_objects.
    zcl_prc_processing_api=>get_instance( )->create_and_schedule_bgpf( lcl_object=>to_create( ) ).
    DATA(uuid) = lcl_object=>read_uuid( ).

    cl_abap_unit_assert=>assert_equals( act = lines( double->calls ) exp = 1 msg = 'One bgPF process' ).
    DATA(parameters) = double->calls[ 1 ].
    DATA(scheduled_uuid) = VALUE #( parameters[ selname = zcl_prc_retry_job=>co_parameter-uuid ]-low OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = CONV sysuuid_x16( scheduled_uuid ) exp = uuid
                                        msg = 'Restricted to the new objects' ).
  ENDMETHOD.


  METHOD no_commit_by_the_api.
    " The caller's LUW decides: after a rollback nothing is left
    zcl_prc_processing_api=>get_instance( )->create_and_schedule_bgpf( lcl_object=>to_create( ) ).
    ROLLBACK WORK.
    cl_abap_unit_assert=>assert_initial( act = lcl_object=>read_uuid( ) msg = 'Not committed by the API' ).
  ENDMETHOD.


  METHOD error_reaches_caller.
    " The caller asked for bgPF explicitly - a scheduling error must reach him
    double->fail = abap_true.
    TRY.
        zcl_prc_processing_api=>get_instance( )->create_and_schedule_bgpf( lcl_object=>to_create( ) ).
        cl_abap_unit_assert=>fail( 'CX_BGMC expected' ).
      CATCH cx_bgmc ##NO_HANDLER.
        " expected
    ENDTRY.
    " Written, not committed: the caller can roll back
    ROLLBACK WORK.
    cl_abap_unit_assert=>assert_initial( act = lcl_object=>read_uuid( ) msg = 'Nothing committed' ).
  ENDMETHOD.


  METHOD deprecated_tolerates_error.
    " Unchanged behaviour of the deprecated method: created, committed, stays due for the retry job
    double->fail = abap_true.
    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = lcl_object=>to_create( )
        i_perform_commit           = abap_true
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-bgpf_execution ).
    cl_abap_unit_assert=>assert_equals( act = lcl_object=>read_state( ) exp = zif_prc_process=>co_start ).
  ENDMETHOD.

ENDCLASS.


"! Resume of the processed object BO: the buffer of resumeProcessing is cleared by CLEANUP,
"! so a rolled-back resume does not reach a later save in the same session
CLASS ltc_resume_rollback DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA double TYPE REF TO lcl_bgpf_double.

    METHODS setup.
    METHODS teardown.
    METHODS resume.
    METHODS rolled_back_resume_once FOR TESTING.
ENDCLASS.


CLASS ltc_resume_rollback IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    double = NEW #( ).
    zcl_prc_bgpf_sched_injector=>inject( double ).
    zcl_prc_processing_api=>get_instance( )->create( lcl_object=>to_create( ) ).
    COMMIT WORK.
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_bgpf_sched_injector=>reset( ).
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD resume.
    MODIFY ENTITIES OF zr_prc_processedobjecttp PRIVILEGED
           ENTITY ProcessedObject
           EXECUTE resumeProcessing FROM VALUE #( ( %key-uuid = lcl_object=>read_uuid( ) ) )
           FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( act = failed msg = 'Resume accepted' ).
  ENDMETHOD.


  METHOD rolled_back_resume_once.
    " The second save changes the same object, so the filter on changed objects in
    " SAVE_MODIFIED lets a left-over entry through - only CLEANUP prevents it
    resume( ).
    ROLLBACK ENTITIES.
    resume( ).
    COMMIT ENTITIES.

    cl_abap_unit_assert=>assert_equals( act = lines( double->calls ) exp = 1 msg = 'One bgPF process' ).
    DATA(scheduled) = REDUCE i( INIT count = 0
                                FOR parameter IN double->calls[ 1 ]
                                WHERE ( selname = zcl_prc_retry_job=>co_parameter-uuid )
                                NEXT count = count + 1 ).
    cl_abap_unit_assert=>assert_equals( act = scheduled exp = 1
                                        msg = 'Scheduled once - nothing of the rolled-back resume' ).
  ENDMETHOD.

ENDCLASS.
