"! Runs the isolated step of the engine in this session and reads the outcome
CLASS lcl_runner DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_outcome,
             state       TYPE zif_prc_processing_engine=>ty_state,
             wrote_step  TYPE abap_bool,
             header_id   TYPE zi_prc_processedmessage-MessageClass,
             header_no   TYPE zi_prc_processedmessage-MessageNumber,
             header_type TYPE zi_prc_processedmessage-MessageSeverity,
           END OF ty_outcome.

    "! Reads the object, executes IF_ABAP_PARALLEL~DO of the isolation task directly
    CLASS-METHODS run IMPORTING i_uuid           TYPE sysuuid_x16
                                i_state          TYPE zif_prc_processing_engine=>ty_state OPTIONAL
                      RETURNING VALUE(r_outcome) TYPE ty_outcome.

    "! Messages of the latest step of the object (message class, number, type)
    CLASS-METHODS messages_of_step IMPORTING i_step_uuid       TYPE sysuuid_x16
                                   RETURNING VALUE(r_messages) TYPE string_table.
ENDCLASS.

CLASS lcl_runner IMPLEMENTATION.
  METHOD run.
    DATA(state) = i_state.
    IF state IS INITIAL.
      SELECT SINGLE * FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
        WHERE UUID = @i_uuid
        INTO @state.
    ENDIF.

    DATA(task) = NEW zcl_prc_step_8_isolation_task( i_state  = state
                                                    i_marker = xco_cp=>uuid( )->value ).
    task->if_abap_parallel~do( ).

    r_outcome-state      = task->get_result( ).
    r_outcome-wrote_step = xsdbool( r_outcome-state-LatestStepUUID <> state-LatestStepUUID ).

    SELECT SINGLE MessageClass, MessageNumber, MessageSeverity
      FROM zi_prc_processedmessage WITH PRIVILEGED ACCESS
      WHERE ProcessedStepUUID = @r_outcome-state-LatestStepUUID
        AND IsHeader          = @abap_true
      INTO (@r_outcome-header_id, @r_outcome-header_no, @r_outcome-header_type).
  ENDMETHOD.

  METHOD messages_of_step.
    SELECT MessageClass, MessageNumber, MessageSeverity
      FROM zi_prc_processedmessage WITH PRIVILEGED ACCESS
      WHERE ProcessedStepUUID = @i_step_uuid
      INTO TABLE @DATA(messages).
    r_messages = VALUE #( FOR m IN messages ( |{ m-MessageClass }/{ m-MessageNumber }/{ m-MessageSeverity }| ) ).
  ENDMETHOD.
ENDCLASS.


"! Layers 7-Lock to 1-Core with the generic test process (payload = behavior)
CLASS ltc_test_process DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.

    METHODS setup.
    METHODS teardown.

    METHODS success                  FOR TESTING.
    METHODS warnings_do_not_fail     FOR TESTING.
    METHODS business_error           FOR TESTING.
    METHODS failure_header           FOR TESTING.
    METHODS bapi_error               FOR TESTING.
    METHODS free_texts               FOR TESTING.
    METHODS free_text_error          FOR TESTING.
    METHODS unexpected_exception     FOR TESTING.
    METHODS branch_by_proposal       FOR TESTING.
    METHODS undefined_end_state      FOR TESTING.
    METHODS new_payload_persisted    FOR TESTING.
    METHODS changed_in_the_meantime  FOR TESTING.

    "! Inserts one object in I_STATE with I_PAYLOAD and runs the isolated step
    METHODS run IMPORTING i_payload        TYPE string
                          i_state          TYPE zif_prc_process=>ty_state DEFAULT 'START'
                RETURNING VALUE(r_outcome) TYPE lcl_runner=>ty_outcome.
ENDCLASS.


CLASS ltc_test_process IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    fixture = NEW #( ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD run.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = i_state step_total = 3 payload = i_payload ) ) ) ).
    r_outcome = lcl_runner=>run( fixture->uuid( `O1` ) ).
  ENDMETHOD.


  METHOD success.
    DATA(outcome) = run( `{}` ).
    cl_abap_unit_assert=>assert_true( outcome-wrote_step ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = 'A' ).
    cl_abap_unit_assert=>assert_equals( act = outcome-header_type exp = 'S' ).
    cl_abap_unit_assert=>assert_equals( act = outcome-header_no exp = '002' msg = 'Success message of the handler' ).
  ENDMETHOD.


  METHOD warnings_do_not_fail.
    DATA(outcome) = run( `{"START":{"MESSAGES":[{"TYPE":"W","V1":"w"},{"TYPE":"I","V1":"i"}]}}` ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = 'A' ).
    DATA(messages) = lcl_runner=>messages_of_step( outcome-state-LatestStepUUID ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( messages[ table_line = `ZPRC_TEST_PROC/001/W` ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( messages[ table_line = `ZPRC_TEST_PROC/001/I` ] ) ) ).
  ENDMETHOD.


  METHOD business_error.
    DATA(outcome) = run( `{"START":{"FAIL":"X"}}` ).
    cl_abap_unit_assert=>assert_true( outcome-wrote_step ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = 'START' msg = 'Failed: state unchanged' ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-RetryCount exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = outcome-header_type exp = 'E' ).
  ENDMETHOD.


  METHOD failure_header.
    DATA(outcome) = run( `{"START":{"FAIL":"X","FAILURE_HEADER":"X"}}` ).
    cl_abap_unit_assert=>assert_equals( act = outcome-header_id exp = 'ZPRC_TEST_PROC' ).
    cl_abap_unit_assert=>assert_equals( act = outcome-header_no exp = '003' msg = 'Failure header of the handler' ).
  ENDMETHOD.


  METHOD bapi_error.
    DATA(outcome) = run( `{"START":{"BAPI_MESSAGES":[{"TYPE":"W","V1":"w"},{"TYPE":"E","V1":"e"}]}}` ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = 'START' ).
    cl_abap_unit_assert=>assert_equals( act = outcome-header_type exp = 'E' ).
  ENDMETHOD.


  METHOD free_texts.
    DATA(outcome) = run( `{"START":{"TEXTS":[{"TYPE":"W","TEXT":"A plain hint"}]}}` ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = 'A' ).
    DATA(messages) = lcl_runner=>messages_of_step( outcome-state-LatestStepUUID ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = `SY/499/W` ] ) )
                                      msg = 'Plain text stored as SY/499' ).
  ENDMETHOD.


  METHOD free_text_error.
    DATA(outcome) = run( `{"START":{"TEXTS":[{"TYPE":"E","TEXT":"A plain error"}]}}` ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = 'START' msg = 'Error text fails the step' ).
    cl_abap_unit_assert=>assert_equals( act = outcome-header_type exp = 'E' ).
  ENDMETHOD.


  METHOD unexpected_exception.
    DATA(outcome) = run( `{"START":{"MESSAGES":[{"TYPE":"W","V1":"before"}],"RAISE":"X"}}` ).
    cl_abap_unit_assert=>assert_true( act = outcome-wrote_step msg = 'Failed step written' ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = 'START' ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-RetryCount exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = outcome-header_type exp = 'E' ).
  ENDMETHOD.


  METHOD branch_by_proposal.
    DATA(outcome) = run( i_payload = `{"A":{"NEXT":"B2"}}`
                         i_state   = 'A' ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = 'B2' msg = 'Proposed end state' ).
  ENDMETHOD.


  METHOD undefined_end_state.
    " A proposal without a transition is a programming error of the process
    DATA(outcome) = run( i_payload = `{"A":{"NEXT":"XX"}}`
                         i_state   = 'A' ).
    cl_abap_unit_assert=>assert_true( outcome-wrote_step ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = 'A' msg = 'No undefined transition' ).
    cl_abap_unit_assert=>assert_equals( act = outcome-header_type exp = 'E' ).
  ENDMETHOD.


  METHOD new_payload_persisted.
    DATA(outcome) = run( `{"START":{"NEW_PAYLOAD":"{\"MARK\":\"NEW\"}"}}` ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = 'A' ).
    DATA(uuid) = fixture->uuid( `O1` ).
    SELECT SINGLE payload_json FROM zprc_proc_object WHERE uuid = @uuid INTO @DATA(payload).
    cl_abap_unit_assert=>assert_char_cp( act = payload exp = '*MARK*NEW*' ).
  ENDMETHOD.


  METHOD changed_in_the_meantime.
    " The list read the object before another run processed it: nothing happens
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 ) ) ) ).
    DATA(uuid) = fixture->uuid( `O1` ).
    SELECT SINGLE * FROM zr_prc_processedobject WITH PRIVILEGED ACCESS WHERE UUID = @uuid INTO @DATA(state).
    state-State = 'A'.

    DATA(outcome) = lcl_runner=>run( i_uuid = uuid i_state = state ).

    cl_abap_unit_assert=>assert_false( act = outcome-wrote_step msg = 'No step for a changed object' ).
    SELECT COUNT(*) FROM zprc_proc_step WHERE processed_object_uuid = @uuid INTO @DATA(steps).
    cl_abap_unit_assert=>assert_equals( act = steps exp = 0 ).
  ENDMETHOD.

ENDCLASS.


"! Layers 2-Simulation and 4-Commit with a real RAP BO: messages and failures from
"! MODIFY, from the check before save (simulation) and from the save (late messages)
CLASS ltc_rap_bo DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    DATA mt_created TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    METHODS teardown.

    METHODS no_error              FOR TESTING.
    METHODS modify_error          FOR TESTING.
    METHODS check_before_save     FOR TESTING.
    METHODS late_save_messages    FOR TESTING.
    METHODS late_save_failed      FOR TESTING.

    METHODS run IMPORTING i_scenario       TYPE zcl_prc_test_raperr_proc=>ty_scenario
                RETURNING VALUE(r_outcome) TYPE lcl_runner=>ty_outcome.
ENDCLASS.


CLASS ltc_rap_bo IMPLEMENTATION.

  METHOD teardown.
    ROLLBACK ENTITIES.
    IF mt_created IS NOT INITIAL.
      DATA lt_delete TYPE TABLE FOR DELETE zr_prc_processedobjecttp.
      lt_delete = VALUE #( FOR u IN mt_created ( %key-UUID = u ) ).
      MODIFY ENTITIES OF zr_prc_processedobjecttp PRIVILEGED
             ENTITY ProcessedObject DELETE FROM lt_delete.
      COMMIT ENTITIES.
    ENDIF.
  ENDMETHOD.


  METHOD run.
    " BO instance of the scenario
    MODIFY ENTITIES OF zr_prc_test_raperr
           ENTITY RapErr
           CREATE FIELDS ( Text ) WITH VALUE #( ( %cid = 'TEST' Text = 'NEW' ) )
           MAPPED DATA(ls_mapped)
           FAILED DATA(ls_failed) ##NEEDED
           REPORTED DATA(ls_reported) ##NEEDED.
    COMMIT ENTITIES.
    DATA(bo_uuid) = ls_mapped-raperr[ 1 ]-UUID.

    " Processed object, not processed yet
    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = VALUE #( ( processName         = zcl_prc_test_raperr_proc=>co_process_name
                                                factoryClassName    = zcl_prc_test_raperr_proc=>co_class_name
                                                processedObject     = zcl_prc_test_raperr_proc=>get_external_id( bo_uuid )
                                                processedObjectUUID = bo_uuid
                                                payloadJson         = zcl_prc_test_raperr_proc=>build_payload( i_scenario ) ) )
        i_perform_commit           = abap_true
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-no_execution ).

    DATA(ext_id) = zcl_prc_test_raperr_proc=>get_external_id( bo_uuid ).
    SELECT SINGLE UUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName               = @zcl_prc_test_raperr_proc=>co_process_name
        AND ExternalProcessedObjectID = @ext_id
      INTO @DATA(uuid).
    APPEND uuid TO mt_created.

    r_outcome = lcl_runner=>run( uuid ).
  ENDMETHOD.


  METHOD no_error.
    DATA(outcome) = run( zcl_prc_test_raperr_proc=>scenario-no_error ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = zif_prc_process=>co_finished ).
  ENDMETHOD.


  METHOD modify_error.
    DATA(outcome) = run( zcl_prc_test_raperr_proc=>scenario-modify_error ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = zif_prc_process=>co_start ).
    cl_abap_unit_assert=>assert_equals( act = outcome-header_type exp = 'E' ).
  ENDMETHOD.


  METHOD check_before_save.
    DATA(outcome) = run( zcl_prc_test_raperr_proc=>scenario-check_before_save_error ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = zif_prc_process=>co_start
                                        msg = 'Detected by the simulation of the save' ).
  ENDMETHOD.


  METHOD late_save_messages.
    DATA(outcome) = run( zcl_prc_test_raperr_proc=>scenario-late_save_messages ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = zif_prc_process=>co_finished ).
    DATA(messages) = lcl_runner=>messages_of_step( outcome-state-LatestStepUUID ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = `ZPRC_TEST_RAPERR/011/E` ] ) )
                                      msg = 'Late messages of the save are kept' ).
  ENDMETHOD.


  METHOD late_save_failed.
    DATA(outcome) = run( zcl_prc_test_raperr_proc=>scenario-late_save_failed ).
    cl_abap_unit_assert=>assert_equals( act = outcome-state-State exp = zif_prc_process=>co_start ).
  ENDMETHOD.

ENDCLASS.
