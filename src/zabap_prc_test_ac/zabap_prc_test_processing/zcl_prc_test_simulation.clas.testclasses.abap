"! Process double for the rule: allows simulation or not, with a given graph.
CLASS lcl_process DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_prc_process.
    METHODS constructor IMPORTING i_supported   TYPE abap_bool
                                  i_transitions TYPE zif_prc_process=>tt_transition.
  PRIVATE SECTION.
    DATA supported   TYPE abap_bool.
    DATA transitions TYPE zif_prc_process=>tt_transition.
ENDCLASS.

CLASS lcl_process IMPLEMENTATION.
  METHOD constructor.
    supported   = i_supported.
    transitions = i_transitions.
  ENDMETHOD.

  METHOD zif_prc_process~get_transitions.
    r_transitions = transitions.
  ENDMETHOD.

  METHOD zif_prc_process~get_transition_handler.
    CLEAR r_transition_handler.
  ENDMETHOD.

  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.

  METHOD zif_prc_process~supports_simulation.
    r_result = supported.
  ENDMETHOD.
ENDCLASS.


"! Process without SUPPORTS_SIMULATION: the DEFAULT IGNORE of the interface applies.
CLASS lcl_process_silent DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_prc_process.
ENDCLASS.

CLASS lcl_process_silent IMPLEMENTATION.
  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE #( ( start_state = zif_prc_process~co_start end_state = zif_prc_process~co_finished ) ).
  ENDMETHOD.

  METHOD zif_prc_process~get_transition_handler.
    CLEAR r_transition_handler.
  ENDMETHOD.

  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.
ENDCLASS.


"! ZCL_PRC_SIMULATION=>CHECK: consent of the process and the states START and FINISHED only.
CLASS ltc_rule DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS co_class TYPE zprc_process_impl_class VALUE 'LCL_PROCESS'.

    METHODS without_implementation_denied FOR TESTING.
    METHODS not_supported_denied          FOR TESTING.
    METHODS unbound_denied                FOR TESTING.
    METHODS one_step_allowed              FOR TESTING.
    METHODS findings_graph_allowed        FOR TESTING.
    METHODS further_state_denied          FOR TESTING.

    METHODS assert_denied IMPORTING i_message TYPE symsg
                                    i_msgno   TYPE symsgno.
ENDCLASS.


CLASS ltc_rule IMPLEMENTATION.

  METHOD assert_denied.
    cl_abap_unit_assert=>assert_equals( act = i_message-msgid exp = 'ZPRC_PROCESS_MESSAGE' ).
    cl_abap_unit_assert=>assert_equals( act = i_message-msgno exp = i_msgno ).
    cl_abap_unit_assert=>assert_equals( act = i_message-msgty exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = i_message-msgv1 exp = co_class msg = 'Class of the process named' ).
  ENDMETHOD.


  METHOD without_implementation_denied.
    assert_denied( i_message = zcl_prc_simulation=>check( i_process    = NEW lcl_process_silent( )
                                                          i_class_name = co_class )
                   i_msgno   = '026' ).
  ENDMETHOD.


  METHOD not_supported_denied.
    DATA(process) = NEW lcl_process(
        i_supported   = abap_false
        i_transitions = VALUE #( ( start_state = zif_prc_process=>co_start end_state = zif_prc_process=>co_finished ) ) ).
    assert_denied( i_message = zcl_prc_simulation=>check( i_process = process i_class_name = co_class )
                   i_msgno   = '026' ).
  ENDMETHOD.


  METHOD unbound_denied.
    assert_denied( i_message = zcl_prc_simulation=>check( i_process = VALUE #( ) i_class_name = co_class )
                   i_msgno   = '026' ).
  ENDMETHOD.


  METHOD one_step_allowed.
    DATA(process) = NEW lcl_process(
        i_supported   = abap_true
        i_transitions = VALUE #( ( start_state = zif_prc_process=>co_start end_state = zif_prc_process=>co_finished ) ) ).
    cl_abap_unit_assert=>assert_initial( zcl_prc_simulation=>check( i_process = process i_class_name = co_class ) ).
  ENDMETHOD.


  METHOD findings_graph_allowed.
    DATA(process) = NEW lcl_process(
        i_supported   = abap_true
        i_transitions = VALUE #( ( start_state = zif_prc_process=>co_start end_state = zif_prc_process=>co_start )
                                 ( start_state = zif_prc_process=>co_start end_state = zif_prc_process=>co_finished ) ) ).
    cl_abap_unit_assert=>assert_initial( zcl_prc_simulation=>check( i_process = process i_class_name = co_class ) ).
  ENDMETHOD.


  METHOD further_state_denied.
    DATA(process) = NEW lcl_process(
        i_supported   = abap_true
        i_transitions = VALUE #( ( start_state = zif_prc_process=>co_start end_state = 'A' )
                                 ( start_state = 'A'                       end_state = zif_prc_process=>co_finished ) ) ).
    assert_denied( i_message = zcl_prc_simulation=>check( i_process = process i_class_name = co_class )
                   i_msgno   = '027' ).
  ENDMETHOD.

ENDCLASS.


"! Engine: objects of a simulation run. The transition of ZCL_PRC_TEST_SIM_PROC writes a
"! marker row; a simulation rolls it back and saves the step only.
CLASS ltc_engine DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_result,
             state          TYPE zprc_proc_object-state,
             retry_count    TYPE zprc_proc_object-retry_count,
             retry_datetime TYPE zprc_proc_object-retry_datetime,
             simulation     TYPE abap_boolean,
             header         TYPE zprc_proc_msg,
             has_info_028   TYPE abap_bool,
             marker_saved   TYPE abap_bool,
           END OF ty_result.

    DATA run_uuid TYPE sysuuid_x16.

    METHODS setup.
    METHODS teardown.

    METHODS success_saves_step_only     FOR TESTING.
    METHODS error_finished_no_retry     FOR TESTING.
    METHODS finding_finished_no_retry   FOR TESTING.
    METHODS denied_process_not_called   FOR TESTING.
    METHODS without_simulation_saves    FOR TESTING.

    "! Creates a run with the given simulation flag (committed)
    METHODS given_run IMPORTING i_simulation TYPE abap_boolean.
    "! Creates and processes one object of the run
    METHODS process IMPORTING i_id    TYPE csequence
                              i_class TYPE zprc_process_impl_class DEFAULT zcl_prc_test_sim_proc=>co_class_name.
    METHODS result IMPORTING i_id            TYPE csequence
                   RETURNING VALUE(r_result) TYPE ty_result.
ENDCLASS.


CLASS ltc_engine IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( zcl_prc_test_sim_proc=>co_process_name ).
    DELETE FROM zprc_test_bgpf WHERE id = @zcl_prc_test_sim_proc=>co_marker_id.
    COMMIT WORK.
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( zcl_prc_test_sim_proc=>co_process_name ).
    DELETE FROM zprc_run WHERE uuid = @run_uuid.
    DELETE FROM zprc_test_bgpf WHERE id = @zcl_prc_test_sim_proc=>co_marker_id.
    COMMIT WORK.
  ENDMETHOD.


  METHOD given_run.
    run_uuid = xco_cp=>uuid( )->value.
    INSERT zprc_run FROM @( VALUE #( uuid             = run_uuid
                                     app_name         = zcl_prc_test_proc_fixture=>co_application_name
                                     job_name         = 'PRC_SIMULATION_TEST'
                                     execution_status = zif_prc_run=>co_execution_status-started
                                     created_by       = sy-uname
                                     simulation       = i_simulation ) ).
    COMMIT WORK.
  ENDMETHOD.


  METHOD process.
    zcl_prc_processing_api=>get_instance( )->create_and_process(
        VALUE #( ( processedObject  = i_id
                   runUUID          = run_uuid
                   processName      = zcl_prc_test_sim_proc=>co_process_name
                   factoryClassName = i_class ) ) ).
  ENDMETHOD.


  METHOD result.
    SELECT SINGLE uuid, state, retry_count, retry_datetime, latest_step_uuid
      FROM zprc_proc_object
      WHERE process_name            = @zcl_prc_test_sim_proc=>co_process_name
        AND ext_processed_object_id = @i_id
      INTO @DATA(object).
    cl_abap_unit_assert=>assert_subrc( msg = |Object { i_id } exists| ).

    SELECT SINGLE Simulation FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE UUID = @object-uuid
      INTO @r_result-simulation.

    SELECT * FROM zprc_proc_msg
      WHERE processed_step_uuid = @object-latest_step_uuid
      INTO TABLE @DATA(messages).

    r_result-state          = object-state.
    r_result-retry_count    = object-retry_count.
    r_result-retry_datetime = object-retry_datetime.
    r_result-header         = VALUE #( messages[ is_header = abap_true ] OPTIONAL ).
    r_result-has_info_028   = xsdbool( line_exists( messages[ msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '028' ] ) ).

    SELECT SINGLE @abap_true FROM zprc_test_bgpf
      WHERE id = @zcl_prc_test_sim_proc=>co_marker_id
      INTO @r_result-marker_saved.
  ENDMETHOD.


  METHOD success_saves_step_only.
    given_run( abap_true ).
    process( 'SIM_OK' ).

    DATA(result) = result( 'SIM_OK' ).
    cl_abap_unit_assert=>assert_equals( act = result-simulation exp = abap_true msg = 'Flag of the run at the object' ).
    cl_abap_unit_assert=>assert_equals( act = result-state exp = zif_prc_process=>co_finished ).
    cl_abap_unit_assert=>assert_equals( act = result-header-msgty exp = 'S' msg = 'Success header' ).
    cl_abap_unit_assert=>assert_true( act = result-has_info_028 msg = 'Step says: simulation, nothing saved' ).
    cl_abap_unit_assert=>assert_false( act = result-marker_saved msg = 'Change of the transition rolled back' ).
  ENDMETHOD.


  METHOD error_finished_no_retry.
    given_run( abap_true ).
    process( 'SIM_ERR1' ).

    DATA(result) = result( 'SIM_ERR1' ).
    cl_abap_unit_assert=>assert_equals( act = result-state exp = zif_prc_process=>co_finished
                                        msg = 'A simulation is over after one step' ).
    cl_abap_unit_assert=>assert_initial( act = result-retry_count msg = 'No retry' ).
    cl_abap_unit_assert=>assert_initial( act = result-retry_datetime msg = 'No retry' ).
    cl_abap_unit_assert=>assert_equals( act = result-header-msgty exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = result-header-msgid exp = 'ZPRC_TEST_PROC' ).
    cl_abap_unit_assert=>assert_equals( act = result-header-msgno exp = '004' ).
    cl_abap_unit_assert=>assert_true( act = result-has_info_028 ).
    cl_abap_unit_assert=>assert_false( act = result-marker_saved ).
  ENDMETHOD.


  METHOD finding_finished_no_retry.
    given_run( abap_true ).
    process( 'SIM_FIND1' ).

    DATA(result) = result( 'SIM_FIND1' ).
    cl_abap_unit_assert=>assert_equals( act = result-state exp = zif_prc_process=>co_finished ).
    cl_abap_unit_assert=>assert_initial( act = result-retry_count ).
    cl_abap_unit_assert=>assert_equals( act = result-header-msgty exp = 'E' msg = 'Finding as header' ).
    cl_abap_unit_assert=>assert_true( act = result-has_info_028 ).
    cl_abap_unit_assert=>assert_false( act = result-marker_saved ).
  ENDMETHOD.


  METHOD denied_process_not_called.
    " ZCL_PRC_TEST_BGPF_PROC does not implement SUPPORTS_SIMULATION
    given_run( abap_true ).
    process( i_id = 'SIM_DENIED' i_class = zcl_prc_test_bgpf_proc=>co_class_name ).

    DATA(result) = result( 'SIM_DENIED' ).
    cl_abap_unit_assert=>assert_equals( act = result-state exp = zif_prc_process=>co_finished ).
    cl_abap_unit_assert=>assert_initial( act = result-retry_count ).
    cl_abap_unit_assert=>assert_equals( act = result-header-msgid exp = 'ZPRC_PROCESS_MESSAGE' ).
    cl_abap_unit_assert=>assert_equals( act = result-header-msgno exp = '026' msg = 'Process does not allow simulation' ).
  ENDMETHOD.


  METHOD without_simulation_saves.
    " Control: the same transition outside a simulation saves its change
    given_run( abap_false ).
    process( 'SIM_OK' ).

    DATA(result) = result( 'SIM_OK' ).
    cl_abap_unit_assert=>assert_false( act = result-simulation ).
    cl_abap_unit_assert=>assert_equals( act = result-state exp = zif_prc_process=>co_finished ).
    cl_abap_unit_assert=>assert_false( act = result-has_info_028 ).
    cl_abap_unit_assert=>assert_true( act = result-marker_saved msg = 'Change of the transition saved' ).
  ENDMETHOD.

ENDCLASS.


"! Run job with a simulation run (as created by initiateRun): one select option S_ID, P_UUID.
CLASS lcl_job DEFINITION FINAL INHERITING FROM zcl_prc_run_job FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS co_ids TYPE zif_prc_run=>ty_run_parameter VALUE 'S_ID'.
    CLASS-DATA process_class TYPE zprc_process_impl_class.
    METHODS if_apj_dt_exec_object~get_parameters REDEFINITION.
  PROTECTED SECTION.
    METHODS select               REDEFINITION.
    METHODS get_process          REDEFINITION.
    METHODS get_application_name REDEFINITION.
    METHODS notify_on_completion REDEFINITION.
ENDCLASS.

CLASS lcl_job IMPLEMENTATION.
  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( ( selname = co_ids kind = if_apj_dt_exec_object=>select_option
                                  datatype = 'C' length = 30 param_text = 'IDs' )
                                ( selname = zif_prc_run=>co_parameter-p_uuid kind = if_apj_dt_exec_object=>parameter
                                  datatype = 'C' length = 32 param_text = 'Run UUID' ) ).
  ENDMETHOD.

  METHOD select.
    DATA ids TYPE RANGE OF za_prc_createprocessedobject-processedobject.
    get_range( EXPORTING i_select_options = i_select_options
                         i_name           = co_ids
               IMPORTING e_range          = ids ).
    r_objects = VALUE #( FOR i IN ids ( id = i-low ) ).
  ENDMETHOD.

  METHOD get_process.
    r_process = VALUE #( name = zcl_prc_test_sim_proc=>co_process_name factory_class = process_class ).
  ENDMETHOD.

  METHOD get_application_name.
    r_application_name = zcl_prc_test_proc_fixture=>co_application_name.
  ENDMETHOD.

  METHOD notify_on_completion.
    " The notification is tested in LTC_RUN_NOTIFICATION
    r_notify = abap_false.
  ENDMETHOD.
ENDCLASS.


"! Run job: a simulation run is processed; with a process that does not allow it, the run
"! is aborted before any object exists.
CLASS ltc_run_job DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    DATA run_uuid TYPE sysuuid_x16.

    METHODS setup.
    METHODS teardown.

    METHODS simulation_run_processed    FOR TESTING.
    METHODS denied_process_aborts_run   FOR TESTING.

    METHODS execute RAISING cx_apj_rt_content.
ENDCLASS.


CLASS ltc_run_job IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( zcl_prc_test_sim_proc=>co_process_name ).
    DELETE FROM zprc_test_bgpf WHERE id = @zcl_prc_test_sim_proc=>co_marker_id.

    " The run as initiateRun creates it: planned, simulation
    run_uuid = xco_cp=>uuid( )->value.
    INSERT zprc_run FROM @( VALUE #( uuid             = run_uuid
                                     app_name         = zcl_prc_test_proc_fixture=>co_application_name
                                     job_name         = 'PRC_SIMULATION_TEST'
                                     execution_status = zif_prc_run=>co_execution_status-planned
                                     simulation       = abap_true ) ).
    COMMIT WORK.
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( zcl_prc_test_sim_proc=>co_process_name ).
    DELETE FROM zprc_run_params WHERE job_uuid = @run_uuid.
    DELETE FROM zprc_run WHERE uuid = @run_uuid.
    DELETE FROM zprc_test_bgpf WHERE id = @zcl_prc_test_sim_proc=>co_marker_id.
    COMMIT WORK.
  ENDMETHOD.


  METHOD execute.
    NEW lcl_job( )->if_apj_rt_exec_object~execute(
        VALUE #( ( selname = lcl_job=>co_ids kind = 'S' sign = 'I' option = 'EQ' low = 'SIMJOB1' )
                 ( selname = lcl_job=>co_ids kind = 'S' sign = 'I' option = 'EQ' low = 'SIMJOB2' )
                 ( selname = zif_prc_run=>co_parameter-p_uuid kind = 'P' sign = 'I' option = 'EQ'
                   low = |{ run_uuid }| ) ) ).
  ENDMETHOD.


  METHOD simulation_run_processed.
    lcl_job=>process_class = zcl_prc_test_sim_proc=>co_class_name.
    TRY.
        execute( ).
      CATCH cx_apj_rt_content INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = |Job aborted: { error->get_text( ) }| ).
    ENDTRY.

    SELECT ExecutionStatus, Simulation, TotalNumber FROM zi_prc_run WITH PRIVILEGED ACCESS
      WHERE UUID = @run_uuid
      INTO TABLE @DATA(runs).
    cl_abap_unit_assert=>assert_equals( act = runs[ 1 ]-ExecutionStatus exp = zif_prc_run=>co_execution_status-finished ).
    cl_abap_unit_assert=>assert_equals( act = runs[ 1 ]-Simulation exp = abap_true msg = 'Run keeps the flag' ).
    cl_abap_unit_assert=>assert_equals( act = runs[ 1 ]-TotalNumber exp = 2 ).

    SELECT State, Simulation FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE RunUUID = @run_uuid
      INTO TABLE @DATA(objects).
    cl_abap_unit_assert=>assert_equals( act = lines( objects ) exp = 2 ).
    LOOP AT objects INTO DATA(object).
      cl_abap_unit_assert=>assert_equals( act = object-State exp = zif_prc_process=>co_finished ).
      cl_abap_unit_assert=>assert_equals( act = object-Simulation exp = abap_true ).
    ENDLOOP.

    SELECT SINGLE @abap_true FROM zprc_test_bgpf
      WHERE id = @zcl_prc_test_sim_proc=>co_marker_id
      INTO @DATA(marker_saved).
    cl_abap_unit_assert=>assert_false( act = marker_saved msg = 'Nothing saved by the transitions' ).
  ENDMETHOD.


  METHOD denied_process_aborts_run.
    " ZCL_PRC_TEST_BGPF_PROC does not implement SUPPORTS_SIMULATION
    lcl_job=>process_class = zcl_prc_test_bgpf_proc=>co_class_name.
    TRY.
        execute( ).
        cl_abap_unit_assert=>fail( msg = 'Job must be aborted' ).
      CATCH cx_apj_rt_content INTO DATA(abort).
        cl_abap_unit_assert=>assert_equals( act = abort->if_t100_message~t100key-msgid exp = 'ZPRC_PROCESS_MESSAGE' ).
        cl_abap_unit_assert=>assert_equals( act = abort->if_t100_message~t100key-msgno exp = '026' ).
    ENDTRY.

    SELECT SINGLE ExecutionStatus, MessageNumber FROM zi_prc_run WITH PRIVILEGED ACCESS
      WHERE UUID = @run_uuid
      INTO @DATA(run).
    cl_abap_unit_assert=>assert_equals( act = run-ExecutionStatus exp = zif_prc_run=>co_execution_status-aborted ).
    cl_abap_unit_assert=>assert_equals( act = run-MessageNumber exp = '026' msg = 'Reason at the run' ).

    SELECT COUNT(*) FROM zprc_proc_object WHERE run_uuid = @run_uuid INTO @DATA(count).
    cl_abap_unit_assert=>assert_equals( act = count exp = 0 msg = 'No object created' ).
  ENDMETHOD.

ENDCLASS.


"! Run notification: [SIMULATION] and the reason of an aborted run. Run, user and mail
"! address are SQL test doubles; the prepare step is called directly, nothing is sent.
CLASS ltc_run_notification DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS co_user      TYPE syuname VALUE 'PRC_TEST_U2'.
    CONSTANTS co_mail      TYPE string  VALUE `prc.simulation@example.com`.
    CONSTANTS co_person_id TYPE c LENGTH 10 VALUE '9999999911'.
    CONSTANTS co_addr_id   TYPE c LENGTH 10 VALUE '9999999912'.

    CLASS-DATA environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS simulation_marked    FOR TESTING.
    METHODS abort_reason_shown   FOR TESTING.
    METHODS normal_run_unchanged FOR TESTING.

    "! Prepare step for a run with the given fields; returns the notification
    METHODS prepare IMPORTING i_run                 TYPE zi_prc_run
                    RETURNING VALUE(r_notification) TYPE zcl_prc_notification=>ty_payload-notification.
ENDCLASS.


CLASS ltc_run_notification IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_osql_test_environment=>create(
        i_dependency_list = VALUE #( ( 'ZI_PRC_RUN' ) ( 'I_USER' ) ( 'I_ADDRCURDEFAULTEMAILADDRESS' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    environment->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA users TYPE STANDARD TABLE OF i_user WITH EMPTY KEY.
    DATA mails TYPE STANDARD TABLE OF i_addrcurdefaultemailaddress WITH EMPTY KEY.

    environment->clear_doubles( ).
    users = VALUE #( ( userid = co_user addresspersonid = co_person_id addressid = co_addr_id ) ).
    mails = VALUE #( ( addressid = co_addr_id addresspersonid = co_person_id emailaddress = co_mail ) ).
    environment->insert_test_data( users ).
    environment->insert_test_data( mails ).
  ENDMETHOD.


  METHOD prepare.
    DATA runs    TYPE STANDARD TABLE OF zi_prc_run WITH EMPTY KEY.
    DATA payload TYPE zcl_prc_notification=>ty_payload.

    runs = VALUE #( ( i_run ) ).
    environment->insert_test_data( runs ).

    DATA(payload_json) = zcl_prc_notification=>payload_to_json( VALUE #( run_uuid = i_run-uuid ) ).
    DATA(process) = CAST zif_prc_process( NEW zcl_prc_notif_run_proc( ) ).
    DATA(transition_handler) = process->get_transition_handler( i_start_state      = zif_prc_process=>co_start
                                                                i_processed_object = 'TEST' ).
    transition_handler->initialize( i_process_name              = 'TEST'
                                    i_processed_object_ext_id   = 'TEST'
                                    i_processed_object_ext_uuid = VALUE #( )
                                    i_message_handler           = zcl_prc_msg_handler_for_test=>create( ) ).
    TRY.
        transition_handler->perform_transition( EXPORTING i_start_state  = zif_prc_process=>co_start
                                                CHANGING  c_payload_json = payload_json ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = |Prepare failed: { error->get_text( ) }| ).
    ENDTRY.
    zcl_prc_notification=>payload_from_json( EXPORTING i_json = payload_json IMPORTING e_payload = payload ).
    r_notification = payload-notification.
  ENDMETHOD.


  METHOD simulation_marked.
    DATA(notification) = prepare( VALUE #( uuid            = xco_cp=>uuid( )->value
                                           applicationname = 'DEMO_APP'
                                           executionstatus = zif_prc_run=>co_execution_status-finished
                                           simulation      = abap_true
                                           totalnumber     = 2
                                           numberofsuccess = 2
                                           createdby       = co_user ) ).
    cl_abap_unit_assert=>assert_char_cp( act = notification-subject exp = '[SIMULATION] *completed successfully*' ).
    cl_abap_unit_assert=>assert_char_cp( act = notification-body_html exp = '*nothing was saved*' ).
  ENDMETHOD.


  METHOD abort_reason_shown.
    DATA(notification) = prepare( VALUE #( uuid            = xco_cp=>uuid( )->value
                                           applicationname = 'DEMO_APP'
                                           executionstatus = zif_prc_run=>co_execution_status-aborted
                                           simulation      = abap_true
                                           messagetext     = 'Process class X does not allow simulation'
                                           createdby       = co_user ) ).
    cl_abap_unit_assert=>assert_char_cp( act = notification-subject exp = '[SIMULATION] *was aborted' ).
    cl_abap_unit_assert=>assert_char_cp( act = notification-body_html exp = '*does not allow simulation*' ).
  ENDMETHOD.


  METHOD normal_run_unchanged.
    DATA(notification) = prepare( VALUE #( uuid            = xco_cp=>uuid( )->value
                                           applicationname = 'DEMO_APP'
                                           executionstatus = zif_prc_run=>co_execution_status-finished
                                           totalnumber     = 1
                                           numberofsuccess = 1
                                           createdby       = co_user ) ).
    cl_abap_unit_assert=>assert_equals( act = notification-subject
                                        exp = `ABAP Processing Center: run of DEMO_APP completed successfully` ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( notification-body_html CS 'nothing was saved' ) ).
  ENDMETHOD.

ENDCLASS.
