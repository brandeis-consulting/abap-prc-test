"! Isolated step in this session (see ZCL_PRC_TEST_STEP_INPROC)
CLASS lcl_step DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CLASS-METHODS run IMPORTING i_uuid         TYPE sysuuid_x16
                      RETURNING VALUE(r_state) TYPE zif_prc_processing_engine=>ty_state.
    CLASS-METHODS header IMPORTING i_state         TYPE zif_prc_processing_engine=>ty_state
                         RETURNING VALUE(r_header) TYPE symsg.
ENDCLASS.

CLASS lcl_step IMPLEMENTATION.
  METHOD run.
    SELECT SINGLE * FROM zr_prc_processedobject WITH PRIVILEGED ACCESS WHERE UUID = @i_uuid INTO @DATA(state).
    DATA(task) = NEW zcl_prc_step_8_isolation_task( i_state = state i_marker = xco_cp=>uuid( )->value ).
    task->if_abap_parallel~do( ).
    r_state = task->get_result( ).
  ENDMETHOD.

  METHOD header.
    SELECT SINGLE MessageClass, MessageNumber, MessageSeverity
      FROM zi_prc_processedmessage WITH PRIVILEGED ACCESS
      WHERE ProcessedStepUUID = @i_state-LatestStepUUID AND IsHeader = @abap_true
      INTO @DATA(message).
    r_header = VALUE #( msgid = message-MessageClass msgno = message-MessageNumber msgty = message-MessageSeverity ).
  ENDMETHOD.
ENDCLASS.


"! Retry ladder: every failure increases the counter and schedules the next retry
"! later; after the last retry no new retry time is set
CLASS ltc_retry_ladder DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS each_failure_is_scheduled FOR TESTING.
    METHODS fail_with_count IMPORTING i_count        TYPE i
                            RETURNING VALUE(r_state) TYPE zif_prc_processing_engine=>ty_state.
ENDCLASS.

CLASS ltc_retry_ladder IMPLEMENTATION.
  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.

  METHOD fail_with_count.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    DATA(fixture) = NEW zcl_prc_test_proc_fixture( ).
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'L1' state = 'START' step_total = 3 retry_count = i_count
                             payload = `{"START":{"FAIL":"X"}}` ) ) ) ).
    r_state = lcl_step=>run( fixture->uuid( `L1` ) ).
  ENDMETHOD.

  METHOD each_failure_is_scheduled.
    " Ladder: 5 minutes, 55 minutes, 23 hours, 6 days - then no automatic retry
    TYPES tt_delays TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA(delays) = VALUE tt_delays( ( 5 * 60 ) ( 55 * 60 ) ( 23 * 3600 ) ( 6 * 86400 ) ).

    LOOP AT delays INTO DATA(delay).
      DATA(count) = sy-tabix - 1.
      GET TIME STAMP FIELD DATA(before).
      DATA(state) = fail_with_count( count ).
      GET TIME STAMP FIELD DATA(after).

      cl_abap_unit_assert=>assert_equals( act = state-RetryCount exp = count + 1 msg = |Counter after failure { count + 1 }| ).
      DATA(earliest) = cl_abap_tstmp=>add( tstmp = before secs = delay ).
      DATA(latest)   = cl_abap_tstmp=>add( tstmp = after  secs = delay ).
      cl_abap_unit_assert=>assert_true( act = xsdbool( state-RetryDateTime >= earliest AND state-RetryDateTime <= latest )
                                        msg = |Retry { count + 1 } after { delay } seconds| ).
    ENDLOOP.

    " The fifth failure: marked as exhausted, no retry time - only a resume helps
    DATA(last) = fail_with_count( 4 ).
    cl_abap_unit_assert=>assert_equals( act = last-RetryCount exp = zif_prc_process=>co_max_retry ).
    cl_abap_unit_assert=>assert_initial( act = last-RetryDateTime ).
  ENDMETHOD.
ENDCLASS.


"! The job continues a run that initiateRun planned (parameter P_UUID)
CLASS lcl_plain_job DEFINITION FINAL INHERITING FROM zcl_prc_run_job FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS co_ids TYPE zif_prc_run=>ty_run_parameter VALUE 'S_ID'.
    METHODS if_apj_dt_exec_object~get_parameters REDEFINITION.
  PROTECTED SECTION.
    METHODS select               REDEFINITION.
    METHODS get_process          REDEFINITION.
    METHODS get_application_name REDEFINITION.
    METHODS notify_on_completion REDEFINITION.
ENDCLASS.

CLASS lcl_plain_job IMPLEMENTATION.
  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( ( selname = co_ids kind = if_apj_dt_exec_object=>select_option
                                  datatype = 'C' length = 30 param_text = 'IDs' )
                                ( selname = zif_prc_run=>co_parameter-p_uuid kind = if_apj_dt_exec_object=>parameter
                                  datatype = 'C' length = 32 param_text = 'Run' ) ).
  ENDMETHOD.

  METHOD select.
    DATA ids TYPE RANGE OF za_prc_createprocessedobject-processedobject.
    get_range( EXPORTING i_select_options = i_select_options i_name = co_ids IMPORTING e_range = ids ).
    r_objects = VALUE #( FOR i IN ids ( id = i-low ) ).
  ENDMETHOD.

  METHOD get_process.
    r_process = VALUE #( name = zcl_prc_test_proc_fixture=>co_process_name factory_class = zcl_prc_test_proc_fixture=>co_factory ).
  ENDMETHOD.

  METHOD get_application_name.
    rv_application_name = zif_prc_run=>co_application_names-demo_rate_adjustment.
  ENDMETHOD.

  METHOD notify_on_completion.
    r_notify = abap_false.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_continue_run DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    DATA mv_run_uuid TYPE sysuuid_x16.
    METHODS setup.
    METHODS teardown.
    METHODS planned_run_is_continued FOR TESTING.
    METHODS unknown_run_aborts       FOR TESTING.
ENDCLASS.

CLASS ltc_continue_run IMPLEMENTATION.
  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    mv_run_uuid = xco_cp=>uuid( )->value.
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    DELETE FROM zprc_run_params WHERE job_uuid = @mv_run_uuid.
    DELETE FROM zprc_run        WHERE uuid     = @mv_run_uuid.
    COMMIT WORK.
  ENDMETHOD.

  METHOD planned_run_is_continued.
    " As initiateRun leaves it: planned, application name set
    INSERT zprc_run FROM @( VALUE #( uuid             = mv_run_uuid
                                     app_name         = zif_prc_run=>co_application_names-demo_rate_adjustment
                                     execution_status = zif_prc_run=>co_execution_status-planned ) ).
    COMMIT WORK.

    TRY.
        NEW lcl_plain_job( )->if_apj_rt_exec_object~execute(
            VALUE #( ( selname = lcl_plain_job=>co_ids kind = 'S' sign = 'I' option = 'EQ' low = 'CONT1' )
                     ( selname = zif_prc_run=>co_parameter-p_uuid kind = 'P' low = CONV #( mv_run_uuid ) ) ) ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = |Job failed: { error->get_text( ) }| ).
    ENDTRY.

    SELECT SINGLE execution_status, total_number FROM zprc_run WHERE uuid = @mv_run_uuid INTO @DATA(run).
    cl_abap_unit_assert=>assert_equals( act = run-execution_status exp = zif_prc_run=>co_execution_status-finished
                                        msg = 'The planned run itself was continued' ).
    cl_abap_unit_assert=>assert_equals( act = run-total_number exp = 1 ).
    SELECT COUNT(*) FROM zprc_run_params WHERE job_uuid = @mv_run_uuid INTO @DATA(parameters).
    cl_abap_unit_assert=>assert_equals( act = parameters exp = 1 msg = 'Parameters stored, P_UUID itself not' ).
  ENDMETHOD.

  METHOD unknown_run_aborts.
    TRY.
        NEW lcl_plain_job( )->if_apj_rt_exec_object~execute(
            VALUE #( ( selname = zif_prc_run=>co_parameter-p_uuid kind = 'P' low = CONV #( mv_run_uuid ) ) ) ).
        cl_abap_unit_assert=>fail( msg = 'A run that does not exist cannot be continued' ).
      CATCH cx_apj_rt_content INTO DATA(abort).
        cl_abap_unit_assert=>assert_equals( act = abort->if_t100_message~t100key-msgid exp = 'ZPRC_RUN' ).
        cl_abap_unit_assert=>assert_equals( act = abort->if_t100_message~t100key-msgno exp = '003'
                                            msg = 'Unexpected error while updating run' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.


"! Prepare steps of the notifications in this session, process classes, job interface
CLASS ltc_notifications DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    CONSTANTS co_mail TYPE string VALUE `prc-unit-test@example.com`.
    METHODS setup.
    METHODS teardown.
    METHODS error_prepare_in_session FOR TESTING.
    METHODS process_classes          FOR TESTING.
    METHODS job_interface            FOR TESTING.
    METHODS invalid_payload          FOR TESTING.
    METHODS delete_notifications.
ENDCLASS.

CLASS ltc_notifications IMPLEMENTATION.
  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    delete_notifications( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    delete_notifications( ).
  ENDMETHOD.

  METHOD error_prepare_in_session.
    DATA(fixture) = NEW zcl_prc_test_proc_fixture( ).
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'PREP1' state = 'START' step_total = 3 mail = co_mail payload = `{"START":{"FAIL":"X"}}` ) ) ) ).
    fixture->run( ).

    " Notification object as the job creates it, but not processed yet
    DATA(uuid) = xco_cp=>uuid( )->value.
    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = VALUE #(
            ( processName         = zcl_prc_notif_error_proc=>co_process_name
              factoryClassName    = zcl_prc_notif_error_proc=>co_class_name
              processedObject     = zcl_prc_notification=>object_id( |{ zcl_prc_test_proc_fixture=>co_process_name } / { co_mail }| )
              processedObjectUUID = uuid
              payloadJson         = zcl_prc_notification=>payload_to_json(
                                        VALUE #( process_name = zcl_prc_test_proc_fixture=>co_process_name
                                                 mail_address = co_mail ) ) ) )
        i_perform_commit           = abap_true
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-no_execution ).

    DATA(pattern) = |{ zcl_prc_test_proc_fixture=>co_process_name } /%|.
    SELECT SINGLE UUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_notif_error_proc=>co_process_name AND ExternalProcessedObjectID LIKE @pattern
      INTO @DATA(object_uuid).

    DATA(state) = lcl_step=>run( object_uuid ).

    cl_abap_unit_assert=>assert_differs( act = state-State exp = zif_prc_process=>co_start msg = 'Mail prepared' ).
    cl_abap_unit_assert=>assert_equals( act = lcl_step=>header( state )-msgty exp = 'S'
                                        msg = 'Success header of the prepare step' ).
  ENDMETHOD.

  METHOD process_classes.
    " Notification objects have no app of their own: no link
    DATA(uuid) = xco_cp=>uuid( )->value.
    cl_abap_unit_assert=>assert_initial( NEW zcl_prc_notif_error_proc( )->zif_prc_process~get_url_for_processed_object(
                                           i_processed_object = 'X' i_processed_object_uuid = uuid ) ).
    cl_abap_unit_assert=>assert_initial( NEW zcl_prc_notif_run_proc( )->zif_prc_process~get_url_for_processed_object(
                                           i_processed_object = 'X' i_processed_object_uuid = uuid ) ).
  ENDMETHOD.

  METHOD job_interface.
    DATA definitions TYPE if_apj_dt_exec_object=>tt_templ_def.
    DATA values      TYPE if_apj_dt_exec_object=>tt_templ_val.
    DATA(job) = NEW zcl_prc_error_mail_job( ).
    job->if_apj_dt_exec_object~get_parameters( IMPORTING et_parameter_def = definitions
                                                         et_parameter_val = values ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( definitions[ selname = zcl_prc_error_mail_job=>c_process_name ] ) ) ).

    " Entry point of the application job: nothing with errors, nothing to do
    TRY.
        job->if_apj_rt_exec_object~execute(
            VALUE #( ( selname = zcl_prc_error_mail_job=>c_process_name kind = 'S' sign = 'I' option = 'EQ'
                       low     = zcl_prc_test_proc_fixture=>co_process_name ) ) ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD invalid_payload.
    DATA payload TYPE zcl_prc_notification=>ty_payload.
    cl_abap_unit_assert=>assert_false( zcl_prc_notification=>payload_from_json( EXPORTING i_json    = `no json at all {`
                                                                                IMPORTING e_payload = payload ) ).
    cl_abap_unit_assert=>assert_initial( payload ).
  ENDMETHOD.

  METHOD delete_notifications.
    DATA lt_uuids TYPE RANGE OF sysuuid_x16.
    DATA(pattern) = |{ zcl_prc_test_proc_fixture=>co_process_name } /%|.
    SELECT uuid FROM zprc_proc_object
      WHERE process_name = @zcl_prc_notif_error_proc=>co_process_name AND ext_processed_object_id LIKE @pattern
      INTO TABLE @DATA(objects).
    IF objects IS INITIAL.
      RETURN.
    ENDIF.
    lt_uuids = VALUE #( FOR o IN objects ( sign = 'I' option = 'EQ' low = o-uuid ) ).
    DELETE FROM zprc_proc_msg    WHERE processed_object_uuid IN @lt_uuids.
    DELETE FROM zprc_proc_step   WHERE processed_object_uuid IN @lt_uuids.
    DELETE FROM zprc_proc_object WHERE uuid                  IN @lt_uuids.
    COMMIT WORK.
  ENDMETHOD.
ENDCLASS.


"! Smaller error branches: loader without name, create with a class that cannot be
"! loaded (precheck of the BO action)
CLASS ltc_error_branches DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS teardown.
    METHODS loader_without_name      FOR TESTING.
    METHODS create_with_broken_class FOR TESTING.
ENDCLASS.

CLASS ltc_error_branches IMPLEMENTATION.
  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

  METHOD loader_without_name.
    DATA error TYPE symsg.
    cl_abap_unit_assert=>assert_not_bound( zcl_prc_process_loader=>get_process( EXPORTING i_class_name = ``
                                                                                IMPORTING e_error      = error ) ).
    cl_abap_unit_assert=>assert_equals( act = error-msgno exp = '021' ).
  ENDMETHOD.

  METHOD create_with_broken_class.
    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           EXECUTE createProcessedObject
           FROM VALUE #( ( %cid   = 'C1'
                           %param = VALUE #( processName      = zcl_prc_test_proc_fixture=>co_process_name
                                             factoryClassName = 'ZCL_PRC_DOES_NOT_EXIST'
                                             processedObject  = 'BROKEN' ) ) )
           FAILED DATA(failed)
           REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial( act = failed-processedobject msg = 'Rejected in the precheck' ).
    DATA(found) = abap_false.
    LOOP AT reported-processedobject INTO DATA(report) WHERE %msg IS BOUND.
      IF report-%msg IS INSTANCE OF if_t100_message
         AND CAST if_t100_message( report-%msg )->t100key-msgno = '021'.
        found = abap_true.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true( act = found msg = 'Process class ... cannot be loaded (021)' ).
  ENDMETHOD.
ENDCLASS.
