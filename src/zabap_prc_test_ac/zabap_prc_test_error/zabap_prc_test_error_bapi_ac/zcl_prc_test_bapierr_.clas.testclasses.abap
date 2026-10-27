"! Base class: per test it deletes the results of the same scenario from a
"! previous run, starts the PRC for the scenario with a fresh UUID and
"! afterwards reads state and messages from the PRC persistence.
"! Only the first run is tested, not the retry.
"!
"! Messages are validated completely: every expected message must be persisted
"! and no other message (of any message class) may exist.
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
           tt_messages TYPE SORTED TABLE OF ty_message WITH NON-UNIQUE KEY msgid msgno msgty.

    CONSTANTS co_msgid TYPE symsgid VALUE 'ZPRC_TEST_BAPIERR'.

    DATA mv_uuid TYPE sysuuid_x16.

    "! Scenario under test - provided by each concrete test class
    METHODS get_scenario ABSTRACT
      RETURNING VALUE(r_scenario) TYPE zcl_prc_test_bapierr_proc=>ty_scenario.

    METHODS run_prc.

    METHODS get_state RETURNING VALUE(r_state) TYPE zif_prc_process=>ty_state.

    "! All persisted messages of the processed object (all message classes)
    METHODS get_persisted_messages RETURNING VALUE(r_messages) TYPE tt_messages.

    METHODS assert_state IMPORTING i_expected TYPE zif_prc_process=>ty_state.

    "! Expects exactly these messages in the persistence - nothing missing, nothing else
    METHODS assert_messages IMPORTING i_expected TYPE tt_messages.

    "! Expects that the update task did (not) post its marker row
    METHODS assert_posted IMPORTING i_expected TYPE abap_bool.

    "! Shortcut for one expected message of ZPRC_TEST_BAPIERR
    METHODS msg IMPORTING i_msgno          TYPE symsgno
                          i_msgty          TYPE symsgty
                RETURNING VALUE(r_message) TYPE ty_message.

  PRIVATE SECTION.
    METHODS setup.

    "! Deletes processed objects (incl. steps and messages) of this
    "! scenario from previous runs. Other scenarios are kept.
    METHODS delete_previous_results.
ENDCLASS.


CLASS ltc_base IMPLEMENTATION.

  METHOD setup.
*    delete_previous_results( ).
    TRY.
        mv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        cl_abap_unit_assert=>fail( msg = lx_uuid->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD delete_previous_results.
    DATA lt_delete TYPE TABLE FOR DELETE zr_prc_processedobjecttp.

    ROLLBACK ENTITIES.

    " Technical cleanup of test data: no authorization checks
    SELECT UUID, PayloadJson FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_bapierr_proc=>co_process_name
      INTO TABLE @DATA(lt_objects).

    DATA(lv_scenario) = get_scenario( ).
    LOOP AT lt_objects INTO DATA(ls_object).
      IF zcl_prc_test_bapierr_proc=>get_scenario( ls_object-PayloadJson ) = lv_scenario.
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


  METHOD run_prc.
    zcl_prc_test_bapierr_proc=>start( i_uuid     = mv_uuid
                                      i_scenario = get_scenario( ) ).
  ENDMETHOD.


  METHOD get_state.
    DATA(lv_ext_id) = zcl_prc_test_bapierr_proc=>get_external_id( mv_uuid ).
    SELECT SINGLE State FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName               = @zcl_prc_test_bapierr_proc=>co_process_name
        AND ExternalProcessedObjectID = @lv_ext_id
      INTO @r_state.
  ENDMETHOD.


  METHOD get_persisted_messages.
    DATA(lv_ext_id) = zcl_prc_test_bapierr_proc=>get_external_id( mv_uuid ).
    SELECT FROM zr_prc_processedmessage AS msg
           INNER JOIN zr_prc_processedobject AS obj ON msg~ProcessedObjectUUID = obj~UUID
      FIELDS msg~MessageClass,
             msg~MessageNumber,
             msg~MessageSeverity
      WHERE obj~ProcessName               = @zcl_prc_test_bapierr_proc=>co_process_name
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


  METHOD assert_messages.
    cl_abap_unit_assert=>assert_equals( act = get_persisted_messages( )
                                        exp = i_expected
                                        msg = |Persisted messages differ from the expected ones| ).
  ENDMETHOD.


  METHOD assert_posted.
    SELECT SINGLE @abap_true FROM ZI_PRC_TEST_BAPIER WHERE uuid = @mv_uuid INTO @DATA(lv_posted).
    cl_abap_unit_assert=>assert_equals( act = lv_posted
                                        exp = i_expected
                                        msg = |Update task posted: { lv_posted }, expected: { i_expected }| ).
  ENDMETHOD.


  METHOD msg.
    r_message = VALUE #( msgid = co_msgid  msgno = i_msgno  msgty = i_msgty ).
  ENDMETHOD.

ENDCLASS.


"! Scenario no_error: W + I + S from the BAPI plus the success header 020,
"! update task posts
CLASS ltc_no_error DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.
  PRIVATE SECTION.
    METHODS no_error FOR TESTING.
ENDCLASS.

CLASS ltc_no_error IMPLEMENTATION.
  METHOD get_scenario.
    r_scenario = zcl_prc_test_bapierr_proc=>scenario-no_error.
  ENDMETHOD.

  METHOD no_error.
    run_prc( ).
    assert_state( zif_prc_process=>co_finished ).
    assert_messages( VALUE #( ( msg( i_msgno = '001' i_msgty = 'W' ) )
                              ( msg( i_msgno = '002' i_msgty = 'I' ) )
                              ( msg( i_msgno = '003' i_msgty = 'S' ) )
                              ( msg( i_msgno = '020' i_msgty = 'S' ) ) ) ).
    assert_posted( abap_true ).
  ENDMETHOD.
ENDCLASS.


"! Scenario call_error: 2 E + W + I in the BAPI return table
CLASS ltc_call_error DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.
  PRIVATE SECTION.
    METHODS call_error FOR TESTING.
ENDCLASS.

CLASS ltc_call_error IMPLEMENTATION.
  METHOD get_scenario.
    r_scenario = zcl_prc_test_bapierr_proc=>scenario-call_error.
  ENDMETHOD.

  METHOD call_error.
    run_prc( ).
    assert_state( zif_prc_process=>co_start ).
    assert_messages( VALUE #( ( msg( i_msgno = '004' i_msgty = 'E' ) )
                              ( msg( i_msgno = '005' i_msgty = 'E' ) )
                              ( msg( i_msgno = '006' i_msgty = 'W' ) )
                              ( msg( i_msgno = '007' i_msgty = 'I' ) ) ) ).
  ENDMETHOD.
ENDCLASS.


"! Scenario call_error_with_update: the BAPI registers its update and then
"! reports 2 E + W + I. Expected: the already registered update is discarded
"! together with the failed unit of work - nothing is posted (no marker row),
"! the state stays START and exactly the four BAPI messages are persisted.
"! The current PRC fulfils this; the test protects it against regressions,
"! e.g. if the rollback of a failed transition is changed.
CLASS ltc_call_error_with_update DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.
  PRIVATE SECTION.
    METHODS call_error_with_update FOR TESTING.
ENDCLASS.

CLASS ltc_call_error_with_update IMPLEMENTATION.
  METHOD get_scenario.
    r_scenario = zcl_prc_test_bapierr_proc=>scenario-call_error_with_update.
  ENDMETHOD.

  METHOD call_error_with_update.
    run_prc( ).
    assert_state( zif_prc_process=>co_start ).
    assert_messages( VALUE #( ( msg( i_msgno = '008' i_msgty = 'E' ) )
                              ( msg( i_msgno = '009' i_msgty = 'E' ) )
                              ( msg( i_msgno = '010' i_msgty = 'W' ) )
                              ( msg( i_msgno = '011' i_msgty = 'I' ) ) ) ).
    assert_posted( abap_false ).
  ENDMETHOD.
ENDCLASS.


"! Scenario call_message_e: MESSAGE E inside the BAPI instead of the return table
CLASS ltc_call_message_e DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.
  PRIVATE SECTION.
    METHODS call_message_e FOR TESTING.
ENDCLASS.

CLASS ltc_call_message_e IMPLEMENTATION.
  METHOD get_scenario.
    r_scenario = zcl_prc_test_bapierr_proc=>scenario-call_message_e.
  ENDMETHOD.

  METHOD call_message_e.
    " MESSAGE E without EXCEPTIONS aborts the isolated session without a short
    " dump: the messages of that session are lost, the step carries the abort
    " text (the text of the MESSAGE E) as header for the end user
    run_prc( ).
    assert_state( zif_prc_process=>co_start ).
    assert_messages( VALUE #( ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '019' msgty = 'E' ) ) ).
  ENDMETHOD.
ENDCLASS.


"! Scenario call_exception: unhandled exception (zero divide) inside the BAPI.
"! The message text of the exception is not known in advance. Target behavior:
"! state START, at least one message, and all persisted messages are errors
"! (E/A/X) - no BAPI message and no success header.
CLASS ltc_call_exception DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.
  PRIVATE SECTION.
    METHODS call_exception FOR TESTING.
ENDCLASS.

CLASS ltc_call_exception IMPLEMENTATION.
  METHOD get_scenario.
    r_scenario = zcl_prc_test_bapierr_proc=>scenario-call_exception.
  ENDMETHOD.

  METHOD call_exception.
    " The message text of the exception is not known in advance. Expected:
    " state START, at least one message, all persisted messages are errors
    " (stored as E) - no BAPI message and no success header
    run_prc( ).
    assert_state( zif_prc_process=>co_start ).

    DATA(lt_messages) = get_persisted_messages( ).
    cl_abap_unit_assert=>assert_not_initial(
        act = lt_messages
        msg = 'No error message for the exception in the PRC persistence' ).

    LOOP AT lt_messages INTO DATA(ls_message).
      cl_abap_unit_assert=>assert_true(
          act = xsdbool( ls_message-msgty = 'E' AND ls_message-msgid <> co_msgid )
          msg = |Unexpected message { ls_message-msgid } { ls_message-msgno } { ls_message-msgty }| ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


"! Scenario call_abort: MESSAGE A inside the BAPI
CLASS ltc_call_abort DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.
  PRIVATE SECTION.
    METHODS call_abort FOR TESTING.
ENDCLASS.

CLASS ltc_call_abort IMPLEMENTATION.
  METHOD get_scenario.
    r_scenario = zcl_prc_test_bapierr_proc=>scenario-call_abort.
  ENDMETHOD.

  METHOD call_abort.
    " MESSAGE A aborts the isolated session without a short dump: the messages
    " of that session are lost, the step carries the abort text as header
    run_prc( ).
    assert_state( zif_prc_process=>co_start ).
    assert_messages( VALUE #( ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '019' msgty = 'E' ) ) ).
  ENDMETHOD.
ENDCLASS.


"! Scenario call_dump: MESSAGE X inside the BAPI
CLASS ltc_call_dump DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.
  PRIVATE SECTION.
    METHODS call_dump FOR TESTING.
ENDCLASS.

CLASS ltc_call_dump IMPLEMENTATION.
  METHOD get_scenario.
    r_scenario = zcl_prc_test_bapierr_proc=>scenario-call_dump.
  ENDMETHOD.

  METHOD call_dump.
    " MESSAGE X dumps the isolated session: the messages of that session are
    " lost, the step carries the program error as header, the abort text and
    " the short dump, found by the EPP identity of the session, as information
    run_prc( ).
    assert_state( zif_prc_process=>co_start ).
    assert_messages( VALUE #( ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '011' msgty = 'I' )
                              ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '013' msgty = 'I' )
                              ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '014' msgty = 'I' )
                              ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '018' msgty = 'E' ) ) ).

    " The dump of this step, not of another one
    DATA(lv_ext_id) = zcl_prc_test_bapierr_proc=>get_external_id( mv_uuid ).
    SELECT SINGLE FROM zr_prc_processedmessage AS msg
           INNER JOIN zr_prc_processedobject AS obj ON msg~ProcessedObjectUUID = obj~UUID
      FIELDS msg~MessageText
      WHERE obj~ProcessName               = @zcl_prc_test_bapierr_proc=>co_process_name
        AND obj~ExternalProcessedObjectID = @lv_ext_id
        AND msg~MessageClass              = 'ZPRC_PROCESS_MESSAGE'
        AND msg~MessageNumber             = '014'
      INTO @DATA(lv_analysis)
      PRIVILEGED ACCESS.
    cl_abap_unit_assert=>assert_char_cp( act = lv_analysis exp = '*CALL_DUMP*' msg = 'Short dump of another step' ).
  ENDMETHOD.
ENDCLASS.


"! Scenario update_error: W + I from the BAPI, MESSAGE E in the update task
CLASS ltc_update_error DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.
  PRIVATE SECTION.
    METHODS update_error FOR TESTING.
ENDCLASS.

CLASS ltc_update_error IMPLEMENTATION.
  METHOD get_scenario.
    r_scenario = zcl_prc_test_bapierr_proc=>scenario-update_error.
  ENDMETHOD.

  METHOD update_error.
    " MESSAGE E in the local update task aborts the isolated session without a
    " short dump: the W and I of the BAPI are lost, the step carries the abort
    " text (the update message) as header
    run_prc( ).
    assert_state( zif_prc_process=>co_start ).
    assert_messages( VALUE #( ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '019' msgty = 'E' ) ) ).
  ENDMETHOD.
ENDCLASS.


"! Scenario update_abort: W + I from the BAPI, MESSAGE A in the update task
CLASS ltc_update_abort DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.
  PRIVATE SECTION.
    METHODS update_abort FOR TESTING.
ENDCLASS.

CLASS ltc_update_abort IMPLEMENTATION.
  METHOD get_scenario.
    r_scenario = zcl_prc_test_bapierr_proc=>scenario-update_abort.
  ENDMETHOD.

  METHOD update_abort.
    " MESSAGE A in the local update task aborts the isolated session without a
    " short dump: the W and I of the BAPI are lost, the step carries the abort
    " text (the update message) as header
    run_prc( ).
    assert_state( zif_prc_process=>co_start ).
    assert_messages( VALUE #( ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '019' msgty = 'E' ) ) ).
  ENDMETHOD.
ENDCLASS.


"! Scenario update_dump: W + I from the BAPI, MESSAGE X in the update task
CLASS ltc_update_dump DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PROTECTED SECTION.
    METHODS get_scenario REDEFINITION.
  PRIVATE SECTION.
    METHODS update_dump FOR TESTING.
ENDCLASS.

CLASS ltc_update_dump IMPLEMENTATION.
  METHOD get_scenario.
    r_scenario = zcl_prc_test_bapierr_proc=>scenario-update_dump.
  ENDMETHOD.

  METHOD update_dump.
    " MESSAGE X in the local update task dumps the isolated session: the W and I
    " of the BAPI are lost, the step carries the program error as header, the
    " abort text ("connection closed") and the short dump, found by the EPP
    " identity of the session, as information
    run_prc( ).
    assert_state( zif_prc_process=>co_start ).
    assert_messages( VALUE #( ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '011' msgty = 'I' )
                              ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '013' msgty = 'I' )
                              ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '014' msgty = 'I' )
                              ( msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '018' msgty = 'E' ) ) ).

    " The dump of this step, not of another one
    DATA(lv_ext_id) = zcl_prc_test_bapierr_proc=>get_external_id( mv_uuid ).
    SELECT SINGLE FROM zr_prc_processedmessage AS msg
           INNER JOIN zr_prc_processedobject AS obj ON msg~ProcessedObjectUUID = obj~UUID
      FIELDS msg~MessageText
      WHERE obj~ProcessName               = @zcl_prc_test_bapierr_proc=>co_process_name
        AND obj~ExternalProcessedObjectID = @lv_ext_id
        AND msg~MessageClass              = 'ZPRC_PROCESS_MESSAGE'
        AND msg~MessageNumber             = '014'
      INTO @DATA(lv_analysis)
      PRIVILEGED ACCESS.
    cl_abap_unit_assert=>assert_char_cp( act = lv_analysis exp = '*UPDATE_DUMP*' msg = 'Short dump of another step' ).
  ENDMETHOD.
ENDCLASS.
