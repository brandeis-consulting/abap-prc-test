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
                           %param = VALUE #( applicationName    = zif_prc_run=>co_application_names-demo_rate_adjustment
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


"! Asynchronous processing via application job (processing API)
CLASS ltc_api_job DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA double TYPE REF TO lcl_scheduler_double.

    METHODS setup.
    METHODS teardown.
    METHODS schedules_retry_job FOR TESTING.
    METHODS error_is_tolerated  FOR TESTING.

    METHODS create RETURNING VALUE(r_uuid) TYPE sysuuid_x16.
ENDCLASS.


CLASS ltc_api_job IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    double = NEW #( ).
    zcl_prc_job_scheduler_injector=>inject( double ).
  ENDMETHOD.


  METHOD teardown.
    zcl_prc_job_scheduler_injector=>reset( ).
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD create.
    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = VALUE #( ( processName      = zcl_prc_test_proc_fixture=>co_process_name
                                                factoryClassName = zcl_prc_test_proc_fixture=>co_factory
                                                processedObject  = 'JOB1' ) )
        i_perform_commit           = abap_true
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-appl_job_execution ).
    SELECT SINGLE UUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name AND ExternalProcessedObjectID = 'JOB1'
      INTO @r_uuid.
  ENDMETHOD.


  METHOD schedules_retry_job.
    DATA(uuid) = create( ).

    cl_abap_unit_assert=>assert_equals( act = lines( double->calls ) exp = 1 ).
    DATA(call) = double->calls[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = call-template exp = zcl_prc_retry_job=>c_apj_template_name
                                        msg = 'The retry job processes the new objects' ).
    DATA(s_uuid) = VALUE #( call-parameters[ name = zcl_prc_retry_job=>s_uuid ]-t_value[ 1 ]-low OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = CONV sysuuid_x16( s_uuid ) exp = uuid msg = 'Restricted to the new objects' ).
  ENDMETHOD.


  METHOD error_is_tolerated.
    " Best effort: the object is created and stays due for the periodic retry job
    double->fail = abap_true.
    DATA(uuid) = create( ).
    cl_abap_unit_assert=>assert_not_initial( act = uuid msg = 'Object created although no job could be scheduled' ).
    SELECT SINGLE state FROM zprc_proc_object WHERE uuid = @uuid INTO @DATA(state).
    cl_abap_unit_assert=>assert_equals( act = state exp = zif_prc_process=>co_start ).
  ENDMETHOD.

ENDCLASS.
