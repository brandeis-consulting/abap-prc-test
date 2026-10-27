"! Package task and bgPF operation, called directly instead of in a new session
CLASS ltc_entries DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.
    METHODS setup.
    METHODS teardown.
    METHODS package_task FOR TESTING.
    METHODS bgpf_operation FOR TESTING.
    METHODS state_of IMPORTING i_ref TYPE string RETURNING VALUE(r_state) TYPE zprc_state.
ENDCLASS.

CLASS ltc_entries IMPLEMENTATION.
  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    fixture = NEW #( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.

  METHOD state_of.
    DATA(uuid) = fixture->uuid( i_ref ).
    SELECT SINGLE state FROM zprc_proc_object WHERE uuid = @uuid INTO @r_state.
  ENDMETHOD.

  METHOD package_task.
    " One queue with two objects: one package, processed in queue order
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'P1' state = 'START' step_total = 3 queue_id = 'QT' queue_pos = 1 )
                           ( ref = 'P2' state = 'START' step_total = 3 queue_id = 'QT' queue_pos = 2 ) ) ) ).
    DATA(uuid1) = fixture->uuid( `P1` ).
    DATA(uuid2) = fixture->uuid( `P2` ).
    SELECT * FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE UUID = @uuid1 OR UUID = @uuid2
      ORDER BY QueuePosition
      INTO TABLE @DATA(states).

    DATA(task) = NEW zcl_prc_list_package_task( CORRESPONDING #( states ) ).
    task->if_abap_parallel~do( ).

    cl_abap_unit_assert=>assert_equals( act = lines( task->get_result( ) ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = state_of( `P1` ) exp = zif_prc_process=>co_finished ).
    cl_abap_unit_assert=>assert_equals( act = state_of( `P2` ) exp = zif_prc_process=>co_finished ).
  ENDMETHOD.

  METHOD bgpf_operation.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'B1' state = 'START' step_total = 3 ) ) ) ).

    TRY.
        CAST if_bgmc_op_single_tx_uncontr( NEW zcl_prc_bgpf(
            VALUE #( ( selname = zcl_prc_retry_job=>s_uuid sign = 'I' option = 'EQ' low = fixture->uuid( `B1` ) ) ) )
          )->execute( ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = error->get_text( ) ).
    ENDTRY.

    cl_abap_unit_assert=>assert_equals( act = state_of( `B1` ) exp = zif_prc_process=>co_finished ).
  ENDMETHOD.
ENDCLASS.


"! Run job without notification, to get a finished run for the notification test
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
                                  datatype = 'C' length = 30 param_text = 'IDs' ) ).
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


"! Prepare step of the run notification in this session
CLASS ltc_run_notification DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    DATA mv_run_uuid          TYPE sysuuid_x16.
    DATA mv_notification_uuid TYPE sysuuid_x16.
    METHODS setup.
    METHODS teardown.
    METHODS prepare_in_session FOR TESTING.
ENDCLASS.

CLASS ltc_run_notification IMPLEMENTATION.
  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    IF mv_notification_uuid IS NOT INITIAL.
      DELETE FROM zprc_proc_msg    WHERE processed_object_uuid = @mv_notification_uuid.
      DELETE FROM zprc_proc_step   WHERE processed_object_uuid = @mv_notification_uuid.
      DELETE FROM zprc_proc_object WHERE uuid                  = @mv_notification_uuid.
    ENDIF.
    IF mv_run_uuid IS NOT INITIAL.
      DELETE FROM zprc_run_params WHERE job_uuid = @mv_run_uuid.
      DELETE FROM zprc_run        WHERE uuid     = @mv_run_uuid.
    ENDIF.
    COMMIT WORK.
  ENDMETHOD.

  METHOD prepare_in_session.
    " A finished run with one object
    TRY.
        NEW lcl_plain_job( )->if_apj_rt_exec_object~execute(
            VALUE #( ( selname = lcl_plain_job=>co_ids kind = 'S' sign = 'I' option = 'EQ' low = 'RUNNOTE1' ) ) ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = |Job failed: { error->get_text( ) }| ).
    ENDTRY.
    SELECT SINGLE RunUUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name
      INTO @mv_run_uuid.

    " Notification object of the run, not processed yet
    DATA(ext_uuid) = xco_cp=>uuid( )->value.
    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = VALUE #(
            ( processName         = zcl_prc_notif_run_proc=>co_process_name
              factoryClassName    = zcl_prc_notif_run_proc=>co_class_name
              processedObject     = 'PRC_TEST_RUN_NOTE'
              processedObjectUUID = ext_uuid
              payloadJson         = zcl_prc_notification=>payload_to_json( VALUE #( run_uuid = mv_run_uuid ) ) ) )
        i_perform_commit           = abap_true
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-no_execution ).
    SELECT SINGLE * FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_notif_run_proc=>co_process_name AND ExternalProcessedObjectUUID = @ext_uuid
      INTO @DATA(before).
    mv_notification_uuid = before-UUID.

    DATA(task) = NEW zcl_prc_step_8_isolation_task( i_state = before i_marker = xco_cp=>uuid( )->value ).
    task->if_abap_parallel~do( ).
    DATA(after) = task->get_result( ).

    cl_abap_unit_assert=>assert_differs( act = after-LatestStepUUID exp = before-LatestStepUUID msg = 'Prepare step written' ).
    DATA payload TYPE zcl_prc_notification=>ty_payload.
    SELECT SINGLE payload_json FROM zprc_proc_object WHERE uuid = @mv_notification_uuid INTO @DATA(json).
    zcl_prc_notification=>payload_from_json( EXPORTING i_json = json IMPORTING e_payload = payload ).
    cl_abap_unit_assert=>assert_char_cp( act = payload-notification-subject exp = '*completed*'
                                         msg = 'Mail of the run prepared' ).
  ENDMETHOD.
ENDCLASS.


"! Loader and API edge cases
CLASS ltc_edges DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS abstract_process_class FOR TESTING.
    METHODS create_nothing         FOR TESTING.
ENDCLASS.

CLASS ltc_edges IMPLEMENTATION.
  METHOD abstract_process_class.
    " Described by RTTI, but CREATE OBJECT fails: reported, no dump
    DATA error TYPE symsg.
    cl_abap_unit_assert=>assert_not_bound( zcl_prc_process_loader=>get_process( EXPORTING i_class_name = 'ZCL_PRC_TEST_ABSTRACT_PROC'
                                                                                IMPORTING e_error      = error ) ).
    cl_abap_unit_assert=>assert_equals( act = error-msgno exp = '021' ).
    cl_abap_unit_assert=>assert_not_initial( act = error-msgv2 msg = 'Reason of CREATE OBJECT' ).
  ENDMETHOD.

  METHOD create_nothing.
    " An empty list is no error and writes nothing
    TRY.
        zcl_prc_processing_api=>get_instance( )->create_processed_objects(
            i_create_processed_objects = VALUE #( )
            i_perform_commit           = abap_false
            i_trigger_processing       = zcl_prc_processing_api=>execution_mode-direct_execution ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
