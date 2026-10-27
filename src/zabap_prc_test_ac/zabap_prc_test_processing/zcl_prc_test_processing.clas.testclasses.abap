"! Base class: deletes the data of the test process names before each test.
"! No teardown: the results stay visible in the Processing Center.
"!
"! Test process: START -> A -> B1 (default) or B2 -> FINISHED.
"! StepTotal = number of steps incl. the current one + longest remaining path,
"! recalculated whenever the state changes.
"! Errors: A, E and X are treated the same and stored as E (severity code 1).
"! Locked objects: see ZCL_PRC_TEST_PROC_LOCKING, events: ZCL_PRC_TEST_PROC_EVENT.
CLASS ltc_base DEFINITION ABSTRACT
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PROTECTED SECTION.
    TYPES ty_data TYPE zcl_prc_test_proc_fixture=>ty_data.
    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.

  PRIVATE SECTION.
    METHODS setup.
ENDCLASS.


CLASS ltc_base IMPLEMENTATION.
  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    fixture = NEW #( ).
  ENDMETHOD.
ENDCLASS.


"! Which processed objects are selected for processing
CLASS ltc_selection DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    METHODS finished_is_not_processed       FOR TESTING.
    METHODS not_before_in_future            FOR TESTING.
    METHODS not_before_in_past              FOR TESTING.
    METHODS not_before_initial              FOR TESTING.
    METHODS error_retry_pending             FOR TESTING.
    METHODS error_retry_due                 FOR TESTING.
    METHODS error_retry_exhausted           FOR TESTING.
    METHODS info_ignores_retry_time         FOR TESTING.
    METHODS abort_respects_retry_time       FOR TESTING.
    METHODS dump_respects_retry_time        FOR TESTING.
    METHODS ignore_restart_pending          FOR TESTING.
    METHODS ignore_restart_exhausted        FOR TESTING.
    METHODS selection_by_process_name       FOR TESTING.
ENDCLASS.


CLASS ltc_selection IMPLEMENTATION.

  METHOD finished_is_not_processed.
    DATA(given) = VALUE ty_data(
        objects = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 ) ) ).
    fixture->insert_given( given ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = given ).
  ENDMETHOD.


  METHOD not_before_in_future.
    DATA(given) = VALUE ty_data(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 not_before = '+3600' ) ) ).
    fixture->insert_given( given ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = given ).
  ENDMETHOD.


  METHOD not_before_in_past.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 not_before = '-3600' ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 not_before = '-3600' latest_step = 'S3'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD not_before_initial.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD error_retry_pending.
    DATA(given) = VALUE ty_data(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 latest_step = 'S2' retry_count = 1 retry = '+300' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ).
    fixture->insert_given( given ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = given ).
  ENDMETHOD.


  METHOD error_retry_due.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 latest_step = 'S2' retry_count = 1 retry = '-60' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S4' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S4' seq = 4 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S4' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD error_retry_exhausted.
    DATA(given) = VALUE ty_data(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 latest_step = 'S2' retry_count = 99999 ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ).
    fixture->insert_given( given ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = given ).
  ENDMETHOD.


  METHOD info_ignores_retry_time.
    " Latest step is not an error - the retry time does not apply
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 latest_step = 'S2' retry_count = 1 retry = '+300' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'I' msgv1 = 'i' text = 'Message i' severity_code = 5 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S4' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'I' msgv1 = 'i' text = 'Message i' severity_code = 5 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S4' seq = 4 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S4' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD abort_respects_retry_time.
    " An abort (A) fails the transition like E and is stored as E - so the
    " retry time applies: the second run must not process the object again
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"MESSAGES":[{"TYPE":"A","V1":"a"}]}}` ) ) ) ).

    fixture->run( ).
    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"MESSAGES":[{"TYPE":"A","V1":"a"}]}}`
                              latest_step = 'S1' retry_count = 1 retry = '+300' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                              msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD dump_respects_retry_time.
    " A termination message (X) fails the transition like E and is stored as E - so
    " the retry time applies: the second run must not process the object again
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"MESSAGES":[{"TYPE":"X","V1":"x"}]}}` ) ) ) ).

    fixture->run( ).
    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"MESSAGES":[{"TYPE":"X","V1":"x"}]}}`
                              latest_step = 'S1' retry_count = 1 retry = '+300' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                              msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'E' msgv1 = 'x' text = 'Message x' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'E' msgv1 = 'x' text = 'Message x' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD ignore_restart_pending.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 latest_step = 'S2' retry_count = 1 retry = '+300' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).

    fixture->run( i_ignore_restart = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S4' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S4' seq = 4 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S4' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD ignore_restart_exhausted.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 latest_step = 'S2' retry_count = 99999 ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).

    fixture->run( i_ignore_restart = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S4' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S4' seq = 4 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S4' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD selection_by_process_name.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 )
                           ( ref = 'O2' state = 'START' step_total = 3 process_name = 'PRC_TEST_PROC_OTHER' ) ) ) ).

    fixture->run( i_process_name = zcl_prc_test_proc_fixture=>co_process_name ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' )
                            ( ref = 'O2' state = 'START' step_total = 3 process_name = 'PRC_TEST_PROC_OTHER' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! Processing order and blocking within queues
CLASS ltc_queue DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    METHODS order_by_position          FOR TESTING.
    METHODS failure_blocks_queue       FOR TESTING.
    METHODS blocked_across_runs        FOR TESTING.
    METHODS other_queue_not_blocked    FOR TESTING.
    METHODS without_queue_not_blocked  FOR TESTING.
ENDCLASS.


CLASS ltc_queue IMPLEMENTATION.

  METHOD order_by_position.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 1 )
                           ( ref = 'O2' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 2 )
                           ( ref = 'O3' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 queue_id = 'Q1' queue_pos = 1 latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' )
                            ( ref = 'O2' state = 'FINISHED' step_total = 3 queue_id = 'Q1' queue_pos = 2 latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' )
                            ( ref = 'O3' state = 'FINISHED' step_total = 3 queue_id = 'Q1' queue_pos = 3 latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 )
                            ( object = 'O2' ref = 'S1' seq = 4 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O2' ref = 'S2' seq = 5 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O2' ref = 'S3' seq = 6 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 )
                            ( object = 'O3' ref = 'S1' seq = 7 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O3' ref = 'S2' seq = 8 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O3' ref = 'S3' seq = 9 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 )
                            ( object = 'O2' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O2' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O2' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 )
                            ( object = 'O3' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O3' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O3' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD failure_blocks_queue.
    " O1 fails. O2 (previously failed, retry due) and O3 are blocked: nothing is
    " done with them at all - no transition, no step, no change of retry data
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 1 payload = `{"START":{"FAIL":"X"}}` )
                           ( ref = 'O2' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 2 latest_step = 'S1' retry_count = 1 retry = '-60' )
                           ( ref = 'O3' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 3 ) )
        steps   = VALUE #( ( object = 'O2' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 1 payload = `{"START":{"FAIL":"X"}}`
                              latest_step = 'S1' retry_count = 1 retry = '+300' changed = 'CHANGED' etag = 'CHANGED' )
                            ( ref = 'O2' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 2 latest_step = 'S1' retry_count = 1 retry = '-60' )
                            ( ref = 'O3' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 3 ) )
        steps    = VALUE #( ( object = 'O2' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 )
                            ( object = 'O1' ref = 'S1' seq = 2 start_state = 'START' end_state = 'START'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD blocked_across_runs.
    " O1 failed in an earlier run and waits for its retry time, so it is not selected.
    " O2 behind it in the same queue must not overtake it: both stay unchanged
    DATA(given) = VALUE ty_data(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 1 latest_step = 'S1' retry_count = 1 retry = '+300' )
                           ( ref = 'O2' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 2 ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 ) ) ).
    fixture->insert_given( given ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = given ).
  ENDMETHOD.


  METHOD other_queue_not_blocked.
    " Q1 and Q2 run in parallel: SEQ counts within each queue only
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 1 payload = `{"START":{"FAIL":"X"}}` )
                           ( ref = 'O2' state = 'START' step_total = 3 queue_id = 'Q2' queue_pos = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 queue_id = 'Q1' queue_pos = 1 payload = `{"START":{"FAIL":"X"}}`
                              latest_step = 'S1' retry_count = 1 retry = '+300' changed = 'CHANGED' etag = 'CHANGED' )
                            ( ref = 'O2' state = 'FINISHED' step_total = 3 queue_id = 'Q2' queue_pos = 1
                              latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 )
                            ( object = 'O2' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O2' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O2' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 )
                            ( object = 'O2' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O2' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O2' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD without_queue_not_blocked.
    " Objects without queue run in parallel: SEQ counts per object only
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 queue_pos = 1 payload = `{"START":{"FAIL":"X"}}` )
                           ( ref = 'O2' state = 'START' step_total = 3 queue_pos = 2 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 queue_pos = 1 payload = `{"START":{"FAIL":"X"}}`
                              latest_step = 'S1' retry_count = 1 retry = '+300' changed = 'CHANGED' etag = 'CHANGED' )
                            ( ref = 'O2' state = 'FINISHED' step_total = 3 queue_pos = 2
                              latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 )
                            ( object = 'O2' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O2' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O2' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 )
                            ( object = 'O2' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O2' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O2' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! Results of transitions: single step, chain, branch, failure within a chain
CLASS ltc_transition DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    METHODS last_step_to_finished   FOR TESTING.
    METHODS chain_in_one_run        FOR TESTING.
    METHODS branch_by_proposal      FOR TESTING.
    METHODS failure_within_chain    FOR TESTING.
ENDCLASS.


CLASS ltc_transition IMPLEMENTATION.

  METHOD last_step_to_finished.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S2' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD chain_in_one_run.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD branch_by_proposal.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"A":{"NEXT":"B2"}}` ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 payload = `{"A":{"NEXT":"B2"}}` latest_step = 'S3'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B2'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B2' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B2' text = 'Transition from B2 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B2' text = 'Transition from B2 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD failure_within_chain.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"A":{"FAIL":"X"}}` ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S2'
                              retry_count = 1 retry = '+300' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! Payload changes made by a transition
CLASS ltc_payload DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    METHODS persisted_on_success   FOR TESTING.
    METHODS discarded_on_failure   FOR TESTING.
ENDCLASS.


CLASS ltc_payload IMPLEMENTATION.

  METHOD persisted_on_success.
    " START replaces the payload; the following transitions read the new payload (default behavior)
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"NEW_PAYLOAD":"{\"MARK\":\"1\"}"}}` ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 payload = `{"MARK":"1"}` latest_step = 'S3'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD discarded_on_failure.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"NEW_PAYLOAD":"{\"MARK\":\"1\"}","FAIL":"X"}}` ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"NEW_PAYLOAD":"{\"MARK\":\"1\"}","FAIL":"X"}}`
                              latest_step = 'S1' retry_count = 1 retry = '+300' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! Retry data after failures and successes
"! Retry schedule: +5 min, +55 min, +23 h, +6 d, then maximum (99999) without retry time
CLASS ltc_retry DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    METHODS first_failure                  FOR TESTING.
    METHODS second_failure                 FOR TESTING.
    METHODS third_failure                  FOR TESTING.
    METHODS fourth_failure                 FOR TESTING.
    METHODS fifth_failure                  FOR TESTING.
    METHODS success_after_retry            FOR TESTING.
    METHODS ignore_restart_restarts_count  FOR TESTING.
ENDCLASS.


CLASS ltc_retry IMPLEMENTATION.

  METHOD first_failure.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"FAIL":"X"}}` ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"FAIL":"X"}}` latest_step = 'S1'
                              retry_count = 1 retry = '+300' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'START' text = 'Forced error in START' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD second_failure.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S2' retry_count = 1 retry = '-60' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S3'
                              retry_count = 2 retry = '+3300' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD third_failure.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S2' retry_count = 2 retry = '-60' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S3'
                              retry_count = 3 retry = '+82800' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD fourth_failure.
    " Fourth retry interval: +6 days (518400 s)
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S2' retry_count = 3 retry = '-60' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S3'
                              retry_count = 4 retry = '+518400' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD fifth_failure.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S2' retry_count = 4 retry = '-60' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S3'
                              retry_count = 99999 changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD success_after_retry.
    " Failed attempts do not count as steps of the process: StepTotal stays 3
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 latest_step = 'S2' retry_count = 2 retry = '-60' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S4' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S4' seq = 4 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S4' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD ignore_restart_restarts_count.
    " A manual restart starts a new retry cycle
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S2' retry_count = 3 retry = '+300' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).

    fixture->run( i_ignore_restart = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'A' step_total = 3 payload = `{"A":{"FAIL":"X"}}` latest_step = 'S3'
                              retry_count = 1 retry = '+300' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'A' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'A' text = 'Forced error in A' severity_code = 1 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! Messages, severity codes and step headers (start in B1: one step to FINISHED)
"! Severity codes: E = 1, W = 2, S = 3, I = 5. A and X are stored as E.
"! Step header rules in detail: see ZCL_PRC_TEST_MSG_HDLR.
CLASS ltc_messages DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    METHODS warning_info_success              FOR TESTING.
    METHODS error_message                     FOR TESTING.
    METHODS abort_message                     FOR TESTING.
    METHODS termination_message               FOR TESTING.
    METHODS message_variables                 FOR TESTING.
    METHODS failure_header                    FOR TESTING.
    METHODS failure_without_header            FOR TESTING.
ENDCLASS.


CLASS ltc_messages IMPLEMENTATION.

  METHOD warning_info_success.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S2'
                             payload = `{"B1":{"MESSAGES":[{"TYPE":"W","V1":"w"},{"TYPE":"I","V1":"i"},{"TYPE":"S","V1":"s"}]}}` ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED'
                              payload = `{"B1":{"MESSAGES":[{"TYPE":"W","V1":"w"},{"TYPE":"I","V1":"i"},{"TYPE":"S","V1":"s"}]}}` ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'I' msgv1 = 'i' text = 'Message i' severity_code = 5 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'S' msgv1 = 's' text = 'Message s' severity_code = 3 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD error_message.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S2'
                             payload = `{"B1":{"MESSAGES":[{"TYPE":"E","V1":"e"}]}}` ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S3' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' payload = `{"B1":{"MESSAGES":[{"TYPE":"E","V1":"e"}]}}` ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD abort_message.
    " An abort (A) fails the transition and is stored as E
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S2'
                             payload = `{"B1":{"MESSAGES":[{"TYPE":"A","V1":"a"}]}}` ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S3' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' payload = `{"B1":{"MESSAGES":[{"TYPE":"A","V1":"a"}]}}` ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD termination_message.
    " A termination message (X) fails the transition like E and A and is stored as E
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S2'
                             payload = `{"B1":{"MESSAGES":[{"TYPE":"X","V1":"x"}]}}` ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S3' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' payload = `{"B1":{"MESSAGES":[{"TYPE":"X","V1":"x"}]}}` ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'E' msgv1 = 'x' text = 'Message x' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'E' msgv1 = 'x' text = 'Message x' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD message_variables.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S2'
                             payload = `{"B1":{"MESSAGES":[{"TYPE":"W","V1":"one","V2":"two","V3":"three","V4":"four"}]}}` ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED'
                              payload = `{"B1":{"MESSAGES":[{"TYPE":"W","V1":"one","V2":"two","V3":"three","V4":"four"}]}}` ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'W'
                              msgv1 = 'one' msgv2 = 'two' msgv3 = 'three' msgv4 = 'four' text = 'Message one two three four' severity_code = 2 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD failure_header.
    " Own failure message is the step header; all detail messages are kept
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S2'
                             payload = `{"B1":{"MESSAGES":[{"TYPE":"W","V1":"w"}],"FAIL":"X","FAILURE_HEADER":"X"}}` ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S3' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' payload = `{"B1":{"MESSAGES":[{"TYPE":"W","V1":"w"}],"FAIL":"X","FAILURE_HEADER":"X"}}` ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '003' msgty = 'E' msgv1 = 'B1' text = 'Transition from B1 failed' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'B1' text = 'Forced error in B1' severity_code = 1 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '003' msgty = 'E' msgv1 = 'B1' text = 'Transition from B1 failed' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD failure_without_header.
    " Without own failure message the error message is the step header
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S2'
                             payload = `{"B1":{"MESSAGES":[{"TYPE":"W","V1":"w"}],"FAIL":"X"}}` ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                           ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                             msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'B1' step_total = 3 latest_step = 'S3' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' payload = `{"B1":{"MESSAGES":[{"TYPE":"W","V1":"w"}],"FAIL":"X"}}` ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'B1' text = 'Forced error in B1' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '004' msgty = 'E' msgv1 = 'B1' text = 'Forced error in B1' severity_code = 1 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! Master data stays untouched, admin data is maintained
CLASS ltc_attributes DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    METHODS master_data_unchanged FOR TESTING.
ENDCLASS.


CLASS ltc_attributes IMPLEMENTATION.

  METHOD master_data_unchanged.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 mail = 'prc.test@example.com'
                             queue_id = 'QA' queue_pos = 7 not_before = '-3600' run = 'R1' ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 mail = 'prc.test@example.com'
                              queue_id = 'QA' queue_pos = 7 not_before = '-3600' run = 'R1'
                              latest_step = 'S3' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'A'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S2' seq = 2 start_state = 'A' end_state = 'B1'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' ref = 'S3' seq = 3 start_state = 'B1' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'START' text = 'Transition from START successful' severity_code = 3 )
                            ( object = 'O1' step = 'S2' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'A' text = 'Transition from A successful' severity_code = 3 )
                            ( object = 'O1' step = 'S3' msgid = 'ZPRC_TEST_PROC' msgno = '002' msgty = 'S' msgv1 = 'B1' text = 'Transition from B1 successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.

ENDCLASS.
