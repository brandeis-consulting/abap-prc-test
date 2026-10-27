"! Minimal transition: only PERFORM_TRANSITION, everything else from the base class
CLASS lcl_minimal_transition DEFINITION FINAL INHERITING FROM zcl_prc_transition_handlr_base FOR TESTING.
  PUBLIC SECTION.
    DATA seen_ext_id   TYPE zr_prc_processedobject-ExternalProcessedObjectID.
    DATA seen_ext_uuid TYPE zr_prc_processedobject-ExternalProcessedObjectUUID.
    DATA seen_message  TYPE symsg.
  PROTECTED SECTION.
    METHODS perform_transition REDEFINITION.
ENDCLASS.

CLASS lcl_minimal_transition IMPLEMENTATION.
  METHOD perform_transition.
    " The helpers of the base class for code that is not handed the parameters
    get_processed_object( IMPORTING e_processed_object_ext_id   = seen_ext_id
                                    e_processed_object_ext_uuid = seen_ext_uuid ).
    MESSAGE w001(zprc_run) WITH 'V1' 'V2' INTO DATA(dummy) ##NEEDED.
    seen_message = sy_message( ).
    get_message_handler( )->add_message_from_sy( ).
  ENDMETHOD.
ENDCLASS.


"! Defaults of the base class: success header, no failure header, no log prefix
CLASS ltc_handler_base DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS defaults FOR TESTING.
ENDCLASS.

CLASS ltc_handler_base IMPLEMENTATION.
  METHOD defaults.
    DATA(handler) = CAST zif_prc_transition_handler( NEW lcl_minimal_transition( ) ).
    DATA(messages) = zcl_prc_message_handler=>create_message_handler( ).
    DATA(ext_uuid) = xco_cp=>uuid( )->value.
    DATA payload TYPE zprc_payload_json.

    handler->initialize( i_process_name                = 'PRC_TEST_BASE'
                         i_processed_object_ext_id   = 'OBJ'
                         i_processed_object_ext_uuid = ext_uuid
                         i_message_handler           = messages ).
    TRY.
        handler->perform_transition( EXPORTING i_start_state  = 'START'
                                     CHANGING  c_payload_json = payload ).
      CATCH zcx_prc_unit_of_work_failed.
        cl_abap_unit_assert=>fail( msg = 'A warning does not fail' ).
    ENDTRY.

    DATA(transition) = CAST lcl_minimal_transition( handler ).
    cl_abap_unit_assert=>assert_equals( act = transition->seen_ext_id exp = 'OBJ' ).
    cl_abap_unit_assert=>assert_equals( act = transition->seen_ext_uuid exp = ext_uuid ).
    cl_abap_unit_assert=>assert_equals( act = transition->seen_message
                                        exp = VALUE symsg( msgty = 'W' msgid = 'ZPRC_RUN' msgno = '001'
                                                           msgv1 = 'V1' msgv2 = 'V2' ) ).

    " Default success header: 'Transition from state &1 completed successfully'
    DATA(success) = handler->get_success_message( ).
    cl_abap_unit_assert=>assert_equals( act = success-msgid exp = 'ZPRC_PROCESS_MESSAGE' ).
    cl_abap_unit_assert=>assert_equals( act = success-msgno exp = '017' ).
    cl_abap_unit_assert=>assert_equals( act = success-msgty exp = 'S' ).

    cl_abap_unit_assert=>assert_initial( act = handler->get_failure_message( )
                                         msg = 'No failure header by default: the last error is the header' ).
    cl_abap_unit_assert=>assert_initial( act = handler->get_message_prefix_for_log( )
                                         msg = 'Default prefix comes from the engine' ).
  ENDMETHOD.
ENDCLASS.


"! The retry job as the application job framework calls it
CLASS ltc_retry_job DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS processes_due_objects FOR TESTING.
ENDCLASS.

CLASS ltc_retry_job IMPLEMENTATION.
  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.

  METHOD teardown.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.

  METHOD processes_due_objects.
    DATA(fixture) = NEW zcl_prc_test_proc_fixture( ).
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'R1' state = 'START' step_total = 3 ) ) ) ).

    TRY.
        NEW zcl_prc_retry_job( )->if_apj_rt_exec_object~execute(
            VALUE #( ( selname = zcl_prc_retry_job=>c_process_name kind = 'S' sign = 'I' option = 'EQ'
                       low     = zcl_prc_test_proc_fixture=>co_process_name ) ) ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = error->get_text( ) ).
    ENDTRY.

    DATA(uuid) = fixture->uuid( `R1` ).
    SELECT SINGLE state FROM zprc_proc_object WHERE uuid = @uuid INTO @DATA(state).
    cl_abap_unit_assert=>assert_equals( act = state exp = zif_prc_process=>co_finished msg = 'Processed by the job' ).
  ENDMETHOD.
ENDCLASS.


"! Run job that notifies the creator of the run at the end
CLASS lcl_notifying_job DEFINITION FINAL INHERITING FROM zcl_prc_run_job FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS co_ids TYPE zif_prc_run=>ty_run_parameter VALUE 'S_ID'.
    METHODS if_apj_dt_exec_object~get_parameters REDEFINITION.
  PROTECTED SECTION.
    METHODS select               REDEFINITION.
    METHODS get_process          REDEFINITION.
    METHODS get_application_name REDEFINITION.
ENDCLASS.

CLASS lcl_notifying_job IMPLEMENTATION.
  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( ( selname = co_ids kind = if_apj_dt_exec_object=>select_option
                                  datatype = 'C' length = 30 param_text = 'IDs' ) ).
  ENDMETHOD.

  METHOD select.
    DATA ids TYPE RANGE OF za_prc_createprocessedobject-processedobject.
    get_range( EXPORTING i_select_options = i_select_options
                         i_name           = co_ids
               IMPORTING e_range          = ids ).
    r_objects = VALUE #( FOR i IN ids ( id = i-low ) ).
  ENDMETHOD.

  METHOD get_process.
    r_process = VALUE #( name          = zcl_prc_test_proc_fixture=>co_process_name
                         factory_class = zcl_prc_test_proc_fixture=>co_factory ).
  ENDMETHOD.

  METHOD get_application_name.
    rv_application_name = zif_prc_run=>co_application_names-demo_rate_adjustment.
  ENDMETHOD.
  " NOTIFY_ON_COMPLETION is not redefined: the default notifies
ENDCLASS.


"! The run notification is created and prepared at the end of the run
CLASS ltc_run_notification DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    DATA mv_run_uuid TYPE sysuuid_x16.
    DATA mt_notifications TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    METHODS setup.
    METHODS teardown.
    METHODS notifies_at_the_end FOR TESTING.
ENDCLASS.

CLASS ltc_run_notification IMPLEMENTATION.
  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.

  METHOD teardown.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    IF mt_notifications IS NOT INITIAL.
      DATA lt_uuids TYPE RANGE OF sysuuid_x16.
      lt_uuids = VALUE #( FOR n IN mt_notifications ( sign = 'I' option = 'EQ' low = n ) ).
      DELETE FROM zprc_proc_msg    WHERE processed_object_uuid IN @lt_uuids.
      DELETE FROM zprc_proc_step   WHERE processed_object_uuid IN @lt_uuids.
      DELETE FROM zprc_proc_object WHERE uuid                  IN @lt_uuids.
    ENDIF.
    IF mv_run_uuid IS NOT INITIAL.
      DELETE FROM zprc_run_params WHERE job_uuid = @mv_run_uuid.
      DELETE FROM zprc_run        WHERE uuid     = @mv_run_uuid.
    ENDIF.
    COMMIT WORK.
  ENDMETHOD.

  METHOD notifies_at_the_end.
    GET TIME STAMP FIELD DATA(started).

    TRY.
        NEW lcl_notifying_job( )->if_apj_rt_exec_object~execute(
            VALUE #( ( selname = lcl_notifying_job=>co_ids kind = 'S' sign = 'I' option = 'EQ' low = 'NOTIFY1' ) ) ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = |Job failed: { error->get_text( ) }| ).
    ENDTRY.

    SELECT SINGLE RunUUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name
      INTO @mv_run_uuid.
    cl_abap_unit_assert=>assert_not_initial( act = mv_run_uuid msg = 'Run created' ).

    " Notification objects of this run (payload carries the run)
    SELECT uuid, payload_json FROM zprc_proc_object
      WHERE process_name = @zcl_prc_notif_run_proc=>co_process_name
        AND created_at  >= @started
      INTO TABLE @DATA(candidates).
    LOOP AT candidates INTO DATA(candidate).
      DATA payload TYPE zcl_prc_notification=>ty_payload.
      zcl_prc_notification=>payload_from_json( EXPORTING i_json    = candidate-payload_json
                                               IMPORTING e_payload = payload ).
      IF payload-run_uuid = mv_run_uuid.
        APPEND candidate-uuid TO mt_notifications.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_equals( act = lines( mt_notifications ) exp = 1 msg = 'One notification for the run' ).
  ENDMETHOD.
ENDCLASS.
