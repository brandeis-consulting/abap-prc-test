"! A processed object locked by someone else is skipped completely:
"! no transition, no step, no message, no change. Other objects are processed.
"!
"! The test session holds the BO lock itself. A lock holder started by
"! CL_ABAP_PARALLEL would be a sibling of the isolated steps of the engine, and
"! sibling sessions of the same parent count as one lock owner - the lock would
"! not collide. The isolated step is a child of the test session, which does
"! collide, just like a Fiori user or another job against a running engine.
CLASS ltc_lock DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    TYPES ty_data TYPE zcl_prc_test_proc_fixture=>ty_data.

    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.

    METHODS setup.
    METHODS teardown.
    METHODS locked_object_is_skipped FOR TESTING.
ENDCLASS.


CLASS ltc_lock IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    fixture = NEW #( ).
  ENDMETHOD.


  METHOD teardown.
    " Releases the lock should the run not have done it
    ROLLBACK ENTITIES.
  ENDMETHOD.


  METHOD locked_object_is_skipped.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 )
                           ( ref = 'O2' state = 'START' step_total = 3 ) ) ) ).

    " O1 is locked by the test session during the run
    SET LOCKS OF zr_prc_processedobjecttp
        ENTITY ProcessedObject
        FROM VALUE #( ( uuid = fixture->uuid( `O1` ) ) )
        FAILED DATA(failed)
        REPORTED DATA(reported) ##NEEDED.
    cl_abap_unit_assert=>assert_initial( act = failed msg = 'Precondition: O1 could not be locked' ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 )
                            ( ref = 'O2' state = 'FINISHED' step_total = 3 latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O2' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O2' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O2' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O2' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O2' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O2' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.

ENDCLASS.
