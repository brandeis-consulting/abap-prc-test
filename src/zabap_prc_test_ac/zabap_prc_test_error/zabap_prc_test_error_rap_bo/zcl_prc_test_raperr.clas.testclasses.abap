"! Base class: per test it deletes the results of the same scenario from a
"! previous run, creates a BO instance, starts the PRC for the scenario and
"! afterwards reads state and messages from the PRC persistence.
"! Only the first run is tested, not the retry.
"!
"! No teardown: the results stay visible in the Processing Center.
CLASS ltc_base DEFINITION ABSTRACT
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PROTECTED SECTION.
    TYPES: BEGIN OF ty_message,
             msgid TYPE symsgid,
             msgno TYPE symsgno,
             msgty TYPE symsgty,
           END OF ty_message,
           "! Sorted by key: comparison independent of the order of persistence
           tt_messages TYPE SORTED TABLE OF ty_message WITH NON-UNIQUE KEY msgid msgno msgty
                       WITH NON-UNIQUE SORTED KEY by_severity COMPONENTS msgty.

    CONSTANTS co_msgid       TYPE symsgid VALUE 'ZPRC_TEST_RAPERR'.
    "! Highest number of a BO message; 015-017 are headers of the transition
    CONSTANTS co_last_bo_msg TYPE symsgno VALUE '014'.

    DATA mv_bo_uuid TYPE sysuuid_x16.

    "! Scenario under test - provided by each concrete test class
    METHODS get_scenario ABSTRACT
      RETURNING VALUE(r_scenario) TYPE zcl_prc_test_raperr_proc=>ty_scenario.

    "! Starts the PRC for the BO instance and the scenario of the test class
    METHODS run_prc.

    METHODS get_state RETURNING VALUE(r_state) TYPE zif_prc_process=>ty_state.

    "! All persisted messages of the processed object (all message classes)
    METHODS get_persisted_messages RETURNING VALUE(r_messages) TYPE tt_messages.

    METHODS assert_state IMPORTING i_expected TYPE zif_prc_process=>ty_state.

    "! Expects exactly these BO messages (ZPRC_TEST_RAPERR 001-014) in the persistence
    METHODS assert_bo_messages IMPORTING i_expected TYPE tt_messages.

    "! Expected BO messages starting with i_first: with errors E, E, W, I - otherwise W, I
    METHODS expected_messages IMPORTING i_first           TYPE symsgno
                                        i_with_errors     TYPE abap_bool
                              RETURNING VALUE(r_messages) TYPE tt_messages.

  PRIVATE SECTION.
    METHODS setup.

    "! Deletes processed objects (incl. steps and messages) of this
    "! scenario from previous runs. Other scenarios are kept.
    METHODS delete_previous_results.

    METHODS create_bo_instance.
ENDCLASS.


CLASS ltc_base IMPLEMENTATION.

  METHOD setup.
    delete_previous_results( ).
    create_bo_instance( ).
  ENDMETHOD.


  METHOD delete_previous_results.
    DATA lt_delete TYPE TABLE FOR DELETE zr_prc_processedobjecttp.

    ROLLBACK ENTITIES.

    " Technical cleanup of test data: no authorization checks
    SELECT UUID, PayloadJson FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_raperr_proc=>co_process_name
      INTO TABLE @DATA(lt_objects).

    DATA(lv_scenario) = get_scenario( ).
    LOOP AT lt_objects INTO DATA(ls_object).
      IF zcl_prc_test_raperr_proc=>get_scenario( ls_object-PayloadJson ) = lv_scenario.
        INSERT VALUE #( %key-uuid = ls_object-UUID ) INTO TABLE lt_delete.
      ENDIF.
    ENDLOOP.

    IF lt_delete IS NOT INITIAL.
      MODIFY ENTITIES OF zr_prc_processedobjecttp PRIVILEGED
             ENTITY ProcessedObject
             DELETE FROM lt_delete.
      COMMIT ENTITIES.
      cl_abap_unit_assert=>assert_subrc( msg = 'Cleanup of the results of a previous run failed' ).
    ENDIF.
  ENDMETHOD.


  METHOD create_bo_instance.
    MODIFY ENTITIES OF zr_prc_test_raperr
           ENTITY RapErr
           CREATE FIELDS ( Text ) WITH VALUE #( ( %cid = 'TEST'  Text = 'NEW' ) )
           MAPPED DATA(ls_mapped)
           FAILED DATA(ls_failed)
           REPORTED DATA(ls_reported) ##NEEDED.
    cl_abap_unit_assert=>assert_initial( act = ls_failed
                                         msg = 'Creation of the test instance failed' ).

    COMMIT ENTITIES RESPONSE OF zr_prc_test_raperr
           FAILED DATA(ls_commit_failed)
           REPORTED DATA(ls_commit_reported) ##NEEDED.
    cl_abap_unit_assert=>assert_subrc( msg = 'COMMIT of the test instance failed' ).
    cl_abap_unit_assert=>assert_initial( act = ls_commit_failed
                                         msg = 'COMMIT of the test instance failed' ).

    mv_bo_uuid = ls_mapped-raperr[ 1 ]-UUID.
  ENDMETHOD.


  METHOD run_prc.
    zcl_prc_test_raperr_proc=>start( i_bo_uuid  = mv_bo_uuid
                                     i_scenario = get_scenario( ) ).
  ENDMETHOD.


  METHOD get_state.
    DATA(lv_ext_id) = zcl_prc_test_raperr_proc=>get_external_id( mv_bo_uuid ).
    SELECT SINGLE State FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName               = @zcl_prc_test_raperr_proc=>co_process_name
        AND ExternalProcessedObjectID = @lv_ext_id
      INTO @r_state.
  ENDMETHOD.


  METHOD get_persisted_messages.
    DATA(lv_ext_id) = zcl_prc_test_raperr_proc=>get_external_id( mv_bo_uuid ).
    SELECT FROM zr_prc_processedmessage AS msg
           INNER JOIN zr_prc_processedobject AS obj ON msg~ProcessedObjectUUID = obj~UUID
      FIELDS msg~MessageClass,
             msg~MessageNumber,
             msg~MessageSeverity
      WHERE obj~ProcessName               = @zcl_prc_test_raperr_proc=>co_process_name
        AND obj~ExternalProcessedObjectID = @lv_ext_id
      INTO TABLE @DATA(lt_raw)
      PRIVILEGED ACCESS.

    r_messages = VALUE #( FOR r IN lt_raw ( msgid = r-MessageClass
                                            msgno = CONV #( r-MessageNumber )
                                            msgty = r-MessageSeverity ) ).
  ENDMETHOD.


  METHOD assert_state.
    cl_abap_unit_assert=>assert_equals( act = get_state( )
                                        exp = i_expected
                                        msg = |Wrong state of the processed object| ).
  ENDMETHOD.


  METHOD assert_bo_messages.
    DATA(lt_all) = get_persisted_messages( ).
    DATA(lt_bo_messages) = VALUE tt_messages( FOR m IN lt_all
                                              WHERE ( msgid = co_msgid AND msgno <= co_last_bo_msg )
                                              ( m ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_bo_messages
                                        exp = i_expected
                                        msg = |BO messages not completely stored in the PRC persistence| ).
  ENDMETHOD.


  METHOD expected_messages.
    DATA lv_no TYPE symsgno.
    lv_no = i_first.

    IF i_with_errors = abap_true.
      INSERT VALUE #( msgid = co_msgid  msgno = lv_no  msgty = 'E' ) INTO TABLE r_messages.
      lv_no += 1.
      INSERT VALUE #( msgid = co_msgid  msgno = lv_no  msgty = 'E' ) INTO TABLE r_messages.
      lv_no += 1.
    ENDIF.
    INSERT VALUE #( msgid = co_msgid  msgno = lv_no  msgty = 'W' ) INTO TABLE r_messages.
    lv_no += 1.
    INSERT VALUE #( msgid = co_msgid  msgno = lv_no  msgty = 'I' ) INTO TABLE r_messages.
  ENDMETHOD.

ENDCLASS.


"! Scenario no_error: no errors, W + I from the action
CLASS ltc_no_error DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.

  PRIVATE SECTION.
    METHODS no_error FOR TESTING.
ENDCLASS.


CLASS ltc_no_error IMPLEMENTATION.

  METHOD get_scenario.
    r_scenario = zcl_prc_test_raperr_proc=>scenario-no_error.
  ENDMETHOD.


  METHOD no_error.
    run_prc( ).

    assert_state( zif_prc_process=>co_finished ).
    assert_bo_messages( expected_messages( i_first       = '001'
                                           i_with_errors = abap_false ) ).
  ENDMETHOD.

ENDCLASS.


"! Scenario modify_error: FAILED + 2 E + W + I directly in MODIFY
CLASS ltc_modify_error DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.

  PRIVATE SECTION.
    METHODS modify_error FOR TESTING.
ENDCLASS.


CLASS ltc_modify_error IMPLEMENTATION.

  METHOD get_scenario.
    r_scenario = zcl_prc_test_raperr_proc=>scenario-modify_error.
  ENDMETHOD.


  METHOD modify_error.
    run_prc( ).

    assert_state( zif_prc_process=>co_start ).
    assert_bo_messages( expected_messages( i_first       = '003'
                                           i_with_errors = abap_true ) ).
  ENDMETHOD.

ENDCLASS.


"! Scenario modify_lock_error: the test instance is locked by the test session.
"! The error comes from the RAP framework (standard behavior), the BO
"! itself does not raise any messages here.
CLASS ltc_modify_lock_error DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.

  PRIVATE SECTION.
    METHODS modify_lock_error FOR TESTING.
ENDCLASS.


CLASS ltc_modify_lock_error IMPLEMENTATION.

  METHOD get_scenario.
    r_scenario = zcl_prc_test_raperr_proc=>scenario-modify_lock_error.
  ENDMETHOD.


  METHOD modify_lock_error.
    " 1) Create the processed object without processing it: START commits, which
    "    would release a lock set before
    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = VALUE #( ( processName         = zcl_prc_test_raperr_proc=>co_process_name
                                                factoryClassName    = zcl_prc_test_raperr_proc=>co_class_name
                                                processedObject     = zcl_prc_test_raperr_proc=>get_external_id( mv_bo_uuid )
                                                processedObjectUUID = mv_bo_uuid
                                                payloadJson         = zcl_prc_test_raperr_proc=>build_payload( get_scenario( ) ) ) )
        i_perform_commit           = abap_true
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-no_execution ).

    DATA(lv_ext_id) = zcl_prc_test_raperr_proc=>get_external_id( mv_bo_uuid ).
    SELECT SINGLE UUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName               = @zcl_prc_test_raperr_proc=>co_process_name
        AND ExternalProcessedObjectID = @lv_ext_id
      INTO @DATA(lv_processed_object_uuid).

    " 2) The test session holds the lock itself. A lock holder started by
    "    CL_ABAP_PARALLEL would be a sibling of the isolated step of the engine,
    "    and sibling sessions of the same parent count as one lock owner.
    SET LOCKS OF zr_prc_test_raperr
        ENTITY RapErr
        FROM VALUE #( ( UUID = mv_bo_uuid ) )
        FAILED DATA(ls_lock_failed)
        REPORTED DATA(ls_lock_reported) ##NEEDED.
    cl_abap_unit_assert=>assert_initial( act = ls_lock_failed
                                         msg = 'Precondition: the test instance could not be locked' ).

    " 3) Process; the isolated step collides with the lock of this session
    zcl_prc_processing_api=>get_instance( )->process_synchronously(
        VALUE #( ( selname = zcl_prc_retry_job=>s_uuid sign = 'I' option = 'EQ' low = lv_processed_object_uuid ) ) ).
    ROLLBACK ENTITIES.

    " 4) Expectation
    DATA(lv_state) = get_state( ).
    cl_abap_unit_assert=>assert_equals( act = lv_state
                                        exp = zif_prc_process=>co_start
                                        msg = |State { lv_state } instead of START - the lock did not collide| ).

    " The lock error must be stored as a readable error message - no matter
    " whether it comes from the RAP framework or is created by the PRC from the fail cause
    DATA(lt_messages) = get_persisted_messages( ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_messages[ KEY by_severity msgty = 'E' ] ) )
                                      msg = 'No error message for the lock error in the PRC persistence' ).
  ENDMETHOD.

ENDCLASS.


"! Scenario check_before_save_error: FAILED + 2 E + W + I in the
"! check_before_save phase (on-save validation), detected via SIMULATE_SAVE
CLASS ltc_check_before_save_error DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.

  PRIVATE SECTION.
    METHODS check_before_save_error FOR TESTING.
ENDCLASS.


CLASS ltc_check_before_save_error IMPLEMENTATION.

  METHOD get_scenario.
    r_scenario = zcl_prc_test_raperr_proc=>scenario-check_before_save_error.
  ENDMETHOD.


  METHOD check_before_save_error.
    run_prc( ).

    assert_state( zif_prc_process=>co_start ).
    assert_bo_messages( expected_messages( i_first       = '007'
                                           i_with_errors = abap_true ) ).
  ENDMETHOD.

ENDCLASS.


"! Scenario late_save_messages: 2 E + W + I as late messages from save_modified,
"! without FAILED. RAP saves anyway, so the step succeeds - but the late
"! messages must not get lost.
CLASS ltc_late_save_messages DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.

  PRIVATE SECTION.
    METHODS late_messages_are_kept FOR TESTING.
ENDCLASS.


CLASS ltc_late_save_messages IMPLEMENTATION.

  METHOD get_scenario.
    r_scenario = zcl_prc_test_raperr_proc=>scenario-late_save_messages.
  ENDMETHOD.


  METHOD late_messages_are_kept.
    run_prc( ).

    assert_state( zif_prc_process=>co_finished ).
    assert_bo_messages( expected_messages( i_first       = '011'
                                           i_with_errors = abap_true ) ).
  ENDMETHOD.

ENDCLASS.


"! Scenario late_save_failed: FAILED + 2 E + W + I from save_modified
"! (CL_ABAP_BEHAVIOR_SAVER_FAILED). The commit fails, the step fails.
CLASS ltc_late_save_failed DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.

  PRIVATE SECTION.
    METHODS late_save_failed FOR TESTING.
ENDCLASS.


CLASS ltc_late_save_failed IMPLEMENTATION.

  METHOD get_scenario.
    r_scenario = zcl_prc_test_raperr_proc=>scenario-late_save_failed.
  ENDMETHOD.


  METHOD late_save_failed.
    run_prc( ).

    assert_state( zif_prc_process=>co_start ).
    assert_bo_messages( expected_messages( i_first       = '011'
                                           i_with_errors = abap_true ) ).
  ENDMETHOD.

ENDCLASS.
