"! Base class: deletes the data of the test process before each test.
"! Every state has one transition to FINISHED, so StepTotal is always 1.
"! No teardown: the results stay visible in the Processing Center.
"!
"! Messages of a step are compared as a SORTED table (key: message ID, number,
"! severity, variables - see ZCL_PRC_TEST_PROC_FIXTURE=>TT_MESSAGES). Their
"! order of arrival is NOT checked here; the expectations are written in that
"! sorted order. The order of the handler is tested in LTC_ADD_EXCEPTION and
"! LTC_HEADER_RULES.
CLASS ltc_base DEFINITION ABSTRACT
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PROTECTED SECTION.
    TYPES ty_data TYPE zcl_prc_test_proc_fixture=>ty_data.
    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.

  PRIVATE SECTION.
    METHODS setup.
ENDCLASS.


CLASS ltc_base IMPLEMENTATION.
  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( zcl_prc_test_msg_hdlr_proc=>co_process_name ).
    fixture = NEW #( i_process_name = zcl_prc_test_msg_hdlr_proc=>co_process_name
                     i_factory      = zcl_prc_test_msg_hdlr_proc=>co_class_name ).
  ENDMETHOD.
ENDCLASS.


"! ADD_MESSAGE_FROM_SY
CLASS ltc_from_sy DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS error_fails              FOR TESTING.
    METHODS abort_fails              FOR TESTING.
    METHODS termination_fails        FOR TESTING.
    METHODS warning_succeeds         FOR TESTING.
    METHODS error_no_fail            FOR TESTING.
    METHODS abort_no_fail            FOR TESTING.
    METHODS termination_no_fail      FOR TESTING.
ENDCLASS.


CLASS ltc_from_sy IMPLEMENTATION.

  METHOD error_fails.
    " Own decision to fail - MESSAGE e... + ADD_MESSAGE_FROM_SY: the message fails the step and is the header
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'SY_E' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'SY_E' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'SY_E' end_state = 'SY_E'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD abort_fails.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'SY_A' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'SY_A' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'SY_A' end_state = 'SY_A'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD termination_fails.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'SY_X' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'SY_X' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'SY_X' end_state = 'SY_X'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'x' text = 'Message x' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'x' text = 'Message x' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD warning_succeeds.
    " W does not fail: the step succeeds, the success message of the transition is the header
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'SY_W' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'SY_W' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'SY_W' text = 'Transition from SY_W successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'SY_W' text = 'Transition from SY_W successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD error_no_fail.
    " I_FAIL_ON_ERROR_MESSAGE = abap_false: the error is stored, the transition succeeds
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'SY_E_NOFAIL' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'SY_E_NOFAIL' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'SY_E_NOFAIL' text = 'Transition from SY_E_NOFAIL successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'SY_E_NOFAIL' text = 'Transition from SY_E_NOFAIL successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD abort_no_fail.
    " A behaves like E: with I_FAIL_ON_ERROR_MESSAGE = abap_false it is stored as E, the transition succeeds
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'SY_A_NOFAIL' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'SY_A_NOFAIL' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'SY_A_NOFAIL' text = 'Transition from SY_A_NOFAIL successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'SY_A_NOFAIL' text = 'Transition from SY_A_NOFAIL successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD termination_no_fail.
    " X behaves like E: with I_FAIL_ON_ERROR_MESSAGE = abap_false it is stored as E, the transition succeeds
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'SY_X_NOFAIL' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'SY_X_NOFAIL' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'SY_X_NOFAIL' text = 'Transition from SY_X_NOFAIL successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'x' text = 'Message x' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'SY_X_NOFAIL' text = 'Transition from SY_X_NOFAIL successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! ADD_MESSAGE_FROM_TEXT - stored as SY/499 with the text in the variables
CLASS ltc_from_text DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS error_fails              FOR TESTING.
    METHODS abort_fails              FOR TESTING.
    METHODS termination_fails        FOR TESTING.
    METHODS warning_succeeds         FOR TESTING.
    METHODS error_no_fail            FOR TESTING.
    METHODS abort_no_fail            FOR TESTING.
    METHODS termination_no_fail      FOR TESTING.
ENDCLASS.


CLASS ltc_from_text IMPLEMENTATION.

  METHOD error_fails.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'TEXT_E' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'TEXT_E' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'TEXT_E' end_state = 'TEXT_E'
                              msgid = 'SY' msgno = '499' msgty = 'E' msgv1 = 'Text e' text = 'Text e' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'SY' msgno = '499' msgty = 'E' msgv1 = 'Text e' text = 'Text e' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD abort_fails.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'TEXT_A' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'TEXT_A' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'TEXT_A' end_state = 'TEXT_A'
                              msgid = 'SY' msgno = '499' msgty = 'E' msgv1 = 'Text a' text = 'Text a' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'SY' msgno = '499' msgty = 'E' msgv1 = 'Text a' text = 'Text a' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD termination_fails.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'TEXT_X' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'TEXT_X' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'TEXT_X' end_state = 'TEXT_X'
                              msgid = 'SY' msgno = '499' msgty = 'E' msgv1 = 'Text x' text = 'Text x' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'SY' msgno = '499' msgty = 'E' msgv1 = 'Text x' text = 'Text x' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD warning_succeeds.
    " W does not fail: the step succeeds, the text is kept as SY/499 W
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'TEXT_W' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'TEXT_W' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'TEXT_W' text = 'Transition from TEXT_W successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'SY' msgno = '499' msgty = 'W' msgv1 = 'Text w' text = 'Text w' severity_code = 2 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'TEXT_W' text = 'Transition from TEXT_W successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD error_no_fail.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'TEXT_E_NOFAIL' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'TEXT_E_NOFAIL' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'TEXT_E_NOFAIL' text = 'Transition from TEXT_E_NOFAIL successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'SY' msgno = '499' msgty = 'E' msgv1 = 'Text e' text = 'Text e' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'TEXT_E_NOFAIL' text = 'Transition from TEXT_E_NOFAIL successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD abort_no_fail.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'TEXT_A_NOFAIL' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'TEXT_A_NOFAIL' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'TEXT_A_NOFAIL' text = 'Transition from TEXT_A_NOFAIL successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'SY' msgno = '499' msgty = 'E' msgv1 = 'Text a' text = 'Text a' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'TEXT_A_NOFAIL' text = 'Transition from TEXT_A_NOFAIL successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD termination_no_fail.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'TEXT_X_NOFAIL' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'TEXT_X_NOFAIL' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'TEXT_X_NOFAIL' text = 'Transition from TEXT_X_NOFAIL successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'SY' msgno = '499' msgty = 'E' msgv1 = 'Text x' text = 'Text x' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'TEXT_X_NOFAIL' text = 'Transition from TEXT_X_NOFAIL successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! ADD_BAPI_RESULT
CLASS ltc_bapi_result DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS error_fails              FOR TESTING.
    METHODS abort_fails              FOR TESTING.
    METHODS termination_fails        FOR TESTING.
    METHODS warning_succeeds         FOR TESTING.
    METHODS error_no_fail            FOR TESTING.
    METHODS abort_no_fail            FOR TESTING.
    METHODS termination_no_fail      FOR TESTING.
ENDCLASS.


CLASS ltc_bapi_result IMPLEMENTATION.

  METHOD error_fails.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'BAPI_E' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'BAPI_E' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'BAPI_E' end_state = 'BAPI_E'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD abort_fails.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'BAPI_A' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'BAPI_A' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'BAPI_A' end_state = 'BAPI_A'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD termination_fails.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'BAPI_X' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'BAPI_X' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'BAPI_X' end_state = 'BAPI_X'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'x' text = 'Message x' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'x' text = 'Message x' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD warning_succeeds.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'BAPI_W' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'BAPI_W' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'BAPI_W' text = 'Transition from BAPI_W successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'BAPI_W' text = 'Transition from BAPI_W successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD error_no_fail.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'BAPI_E_NOFAIL' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'BAPI_E_NOFAIL' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'BAPI_E_NOFAIL' text = 'Transition from BAPI_E_NOFAIL successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'BAPI_E_NOFAIL' text = 'Transition from BAPI_E_NOFAIL successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD abort_no_fail.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'BAPI_A_NOFAIL' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'BAPI_A_NOFAIL' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'BAPI_A_NOFAIL' text = 'Transition from BAPI_A_NOFAIL successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'BAPI_A_NOFAIL' text = 'Transition from BAPI_A_NOFAIL successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.


  METHOD termination_no_fail.
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'BAPI_X_NOFAIL' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'BAPI_X_NOFAIL' end_state = 'FINISHED'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'BAPI_X_NOFAIL' text = 'Transition from BAPI_X_NOFAIL successful' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'x' text = 'Message x' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '002' msgty = 'S' msgv1 = 'BAPI_X_NOFAIL' text = 'Transition from BAPI_X_NOFAIL successful' severity_code = 3 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! Step header end-to-end, read from the persistence.
"! Rules: success / failure message of the transition always win; otherwise the
"! last message of the highest severity: E (incl. A, X) > S > W > I.
"! A failure without any error message gets the PRC message
"! ZPRC_PROCESS_MESSAGE/002 'Transition failed without error message'.
"! What is checked here is the header (STEPS) and the set of messages - not their order.
CLASS ltc_header DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS error_before_warning       FOR TESTING.
    METHODS warning_before_error       FOR TESTING.
    METHODS last_of_two_errors         FOR TESTING.
    METHODS abort_after_error          FOR TESTING.
    METHODS all_severities             FOR TESTING.
    METHODS own_failure_message        FOR TESTING.
    METHODS declared_failure_header    FOR TESTING.
    METHODS failed_without_error       FOR TESTING.
ENDCLASS.


CLASS ltc_header IMPLEMENTATION.

  METHOD error_before_warning.
    " BAPI return E, then W: the error is the step header
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'BAPI_E_THEN_W' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'BAPI_E_THEN_W' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'BAPI_E_THEN_W' end_state = 'BAPI_E_THEN_W'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 ) ) ) ).
  ENDMETHOD.


  METHOD warning_before_error.
    " BAPI return W, then E: the error is the step header
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'HDR_WARNING_BEFORE_ERROR' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'HDR_WARNING_BEFORE_ERROR' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'HDR_WARNING_BEFORE_ERROR' end_state = 'HDR_WARNING_BEFORE_ERROR'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 ) ) ) ).
  ENDMETHOD.


  METHOD last_of_two_errors.
    " BAPI return E1, then E2: the last error is the step header
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'BAPI_E1_E2' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'BAPI_E1_E2' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'BAPI_E1_E2' end_state = 'BAPI_E1_E2'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e2' text = 'Message e2' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e1' text = 'Message e1' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e2' text = 'Message e2' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD abort_after_error.
    " BAPI return E, then A: A is an error like E, so the last error (A, stored as E) is the step header
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'HDR_ABORT_AFTER_ERROR' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'HDR_ABORT_AFTER_ERROR' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'HDR_ABORT_AFTER_ERROR' end_state = 'HDR_ABORT_AFTER_ERROR'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'a' text = 'Message a' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD all_severities.
    " BAPI return I, S, W, E: the error is the step header
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'HDR_ALL_SEVERITIES' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'HDR_ALL_SEVERITIES' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'HDR_ALL_SEVERITIES' end_state = 'HDR_ALL_SEVERITIES'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'I' msgv1 = 'i' text = 'Message i' severity_code = 5 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'S' msgv1 = 's' text = 'Message s' severity_code = 3 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 ) ) ) ).
  ENDMETHOD.


  METHOD own_failure_message.
    " W, then E fails; GET_FAILURE_MESSAGE declares 003: the failure message is the step header,
    " all messages of the handler are kept as details
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'FAILURE_HEADER' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FAILURE_HEADER' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'FAILURE_HEADER' end_state = 'FAILURE_HEADER'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '003' msgty = 'E' msgv1 = 'FAILURE_HEADER' text = 'Transition from FAILURE_HEADER failed' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '003' msgty = 'E' msgv1 = 'FAILURE_HEADER' text = 'Transition from FAILURE_HEADER failed' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD declared_failure_header.
    " Same rule as OWN_FAILURE_MESSAGE with a failure message that has a variable (004 'f'):
    " W, then E fails; the declared failure message is the step header
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'HDR_SET_FAILURE_HEADER' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'HDR_SET_FAILURE_HEADER' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'HDR_SET_FAILURE_HEADER' end_state = 'HDR_SET_FAILURE_HEADER'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '004' msgty = 'E' msgv1 = 'f' text = 'Declared failure header f' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' text = 'Message e' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '004' msgty = 'E' msgv1 = 'f' text = 'Declared failure header f' severity_code = 1 ) ) ) ).
  ENDMETHOD.


  METHOD failed_without_error.
    " W, I, then FAILED without any message: a failed step never gets an S/W/I header -
    " the PRC adds its own error message, which is the step header
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'HDR_FAILED_WITHOUT_ERROR' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'HDR_FAILED_WITHOUT_ERROR' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'HDR_FAILED_WITHOUT_ERROR' end_state = 'HDR_FAILED_WITHOUT_ERROR'
                              msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '002' msgty = 'E' text = 'Transition failed without error message' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '002' msgty = 'E' text = 'Transition failed without error message' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'I' msgv1 = 'i' text = 'Message i' severity_code = 5 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' text = 'Message w' severity_code = 2 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! Header rules on the message handler API directly (no processing, no persistence).
"! Needed for S > W > I and "last of the same severity" for S, W and I: in a
"! processing run these are always covered by the success / failure / error header.
"! All messages are added with I_FAIL_ON_ERROR_MESSAGE = abap_false.
CLASS ltc_header_rules DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES ty_header TYPE zif_prc_message_handler=>ty_message_details.

    DATA handler TYPE REF TO zif_prc_message_handler.

    METHODS setup.

    "! MESSAGE ZPRC_TEST_MSG_HDLR/001 of type I_TYPE + ADD_MESSAGE_FROM_SY without failing
    METHODS add IMPORTING i_type TYPE symsgty
                          i_v1   TYPE symsgv
                RAISING   cx_static_check.

    METHODS info_then_warning              FOR TESTING RAISING cx_static_check.
    METHODS warning_then_info              FOR TESTING RAISING cx_static_check.
    METHODS warning_then_success           FOR TESTING RAISING cx_static_check.
    METHODS success_then_warning           FOR TESTING RAISING cx_static_check.
    METHODS success_then_error             FOR TESTING RAISING cx_static_check.
    METHODS last_of_two_infos              FOR TESTING RAISING cx_static_check.
    METHODS last_of_two_warnings           FOR TESTING RAISING cx_static_check.
    METHODS last_of_two_successes          FOR TESTING RAISING cx_static_check.
    METHODS last_of_two_errors             FOR TESTING RAISING cx_static_check.
    METHODS abort_after_error              FOR TESTING RAISING cx_static_check.
    METHODS termination_then_warning       FOR TESTING RAISING cx_static_check.
    METHODS success_does_not_replace_error FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_header_rules IMPLEMENTATION.

  METHOD setup.
    handler = zcl_prc_message_handler=>create_message_handler( ).
  ENDMETHOD.


  METHOD add.
    MESSAGE ID 'ZPRC_TEST_MSG_HDLR' TYPE i_type NUMBER '001' WITH i_v1 INTO DATA(lv_dummy) ##NEEDED.
    handler->add_message_from_sy( i_fail_on_error_message = abap_false ).
  ENDMETHOD.


  METHOD info_then_warning.
    add( i_type = 'I' i_v1 = 'i' ).
    add( i_type = 'W' i_v1 = 'w' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' message_text = 'Message w' ) ).
  ENDMETHOD.


  METHOD warning_then_info.
    add( i_type = 'W' i_v1 = 'w' ).
    add( i_type = 'I' i_v1 = 'i' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' message_text = 'Message w' ) ).
  ENDMETHOD.


  METHOD warning_then_success.
    add( i_type = 'W' i_v1 = 'w' ).
    add( i_type = 'S' i_v1 = 's' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'S' msgv1 = 's' message_text = 'Message s' ) ).
  ENDMETHOD.


  METHOD success_then_warning.
    add( i_type = 'S' i_v1 = 's' ).
    add( i_type = 'W' i_v1 = 'w' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'S' msgv1 = 's' message_text = 'Message s' ) ).
  ENDMETHOD.


  METHOD success_then_error.
    add( i_type = 'S' i_v1 = 's' ).
    add( i_type = 'E' i_v1 = 'e' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' message_text = 'Message e' ) ).
  ENDMETHOD.


  METHOD last_of_two_infos.
    add( i_type = 'I' i_v1 = 'i1' ).
    add( i_type = 'I' i_v1 = 'i2' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'I' msgv1 = 'i2' message_text = 'Message i2' ) ).
  ENDMETHOD.


  METHOD last_of_two_warnings.
    add( i_type = 'W' i_v1 = 'w1' ).
    add( i_type = 'W' i_v1 = 'w2' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w2' message_text = 'Message w2' ) ).
  ENDMETHOD.


  METHOD last_of_two_successes.
    add( i_type = 'S' i_v1 = 's1' ).
    add( i_type = 'S' i_v1 = 's2' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'S' msgv1 = 's2' message_text = 'Message s2' ) ).
  ENDMETHOD.


  METHOD last_of_two_errors.
    add( i_type = 'E' i_v1 = 'e1' ).
    add( i_type = 'E' i_v1 = 'e2' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e2' message_text = 'Message e2' ) ).
  ENDMETHOD.


  METHOD abort_after_error.
    " A is an error like E: the later abort (stored as E) wins
    add( i_type = 'E' i_v1 = 'e' ).
    add( i_type = 'A' i_v1 = 'a' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'a' message_text = 'Message a' ) ).
  ENDMETHOD.


  METHOD termination_then_warning.
    " X is an error like E: it outranks the later warning
    add( i_type = 'X' i_v1 = 'x' ).
    add( i_type = 'W' i_v1 = 'w' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'x' message_text = 'Message x' ) ).
  ENDMETHOD.


  METHOD success_does_not_replace_error.
    " In the handler a later S does not replace an E: the error stays the header.
    " (The success header of a step comes from the transition, not from the handler.)
    add( i_type = 'E' i_v1 = 'e' ).
    add( i_type = 'S' i_v1 = 's' ).

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'e' message_text = 'Message e' ) ).
  ENDMETHOD.

ENDCLASS.


"! Severity rules on the message handler API directly (no processing, no persistence).
CLASS ltc_severity_rules DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS bapi_blank_type_is_error FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_severity_rules IMPLEMENTATION.

  METHOD bapi_blank_type_is_error.
    " A BAPI return line without type is not W, I or S: it is stored as E and fails the handler
    DATA(handler) = zcl_prc_message_handler=>create_message_handler( ).

    TRY.
        handler->add_bapi_result( VALUE #( ( type = space id = 'ZPRC_TEST_MSG_HDLR' number = '001' message_v1 = 'blank' ) ) ).
        cl_abap_unit_assert=>fail( 'A BAPI return line without type must fail the handler' ).
      CATCH zcx_prc_unit_of_work_failed ##NO_HANDLER.
        " expected
    ENDTRY.

    DATA(header) = handler->get_header( ).
    cl_abap_unit_assert=>assert_equals(
        act = VALUE symsg( msgid = header-msgid msgno = header-msgno msgty = header-msgty msgv1 = header-msgv1 )
        exp = VALUE symsg( msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'blank' ) ).
    cl_abap_unit_assert=>assert_true( handler->has_errors( ) ).
  ENDMETHOD.

ENDCLASS.


"! Test exception with a T100 key; raised with RAISE EXCEPTION ... MESSAGE
CLASS lcx_dyn DEFINITION INHERITING FROM cx_static_check FINAL.
  PUBLIC SECTION.
    INTERFACES if_t100_dyn_msg.
    METHODS constructor IMPORTING textid   LIKE if_t100_message=>t100key OPTIONAL
                                  previous LIKE previous OPTIONAL.
ENDCLASS.


CLASS lcx_dyn IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


"! Test exception without a T100 key: only a text
CLASS lcx_plain DEFINITION INHERITING FROM cx_static_check FINAL.
  PUBLIC SECTION.
    METHODS if_message~get_text REDEFINITION.
ENDCLASS.


CLASS lcx_plain IMPLEMENTATION.
  METHOD if_message~get_text.
    result = `Plain text`.
  ENDMETHOD.
ENDCLASS.


"! ADD_EXCEPTION on the message handler API directly (no processing, no persistence).
"! Here the order of the messages IS checked (handler, not persistence).
CLASS ltc_add_exception DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES ty_header TYPE zif_prc_message_handler=>ty_message_details.

    DATA handler TYPE REF TO zif_prc_message_handler.

    METHODS setup.

    "! Exception ZPRC_TEST_MSG_HDLR/001 with I_V1, of type I_TYPE, optionally with a previous one
    METHODS t100_exception IMPORTING i_type             TYPE symsgty DEFAULT 'E'
                                     i_v1               TYPE symsgv
                                     i_previous         TYPE REF TO cx_root OPTIONAL
                           RETURNING VALUE(r_exception) TYPE REF TO cx_root.

    METHODS t100_exception_keeps_key      FOR TESTING RAISING cx_static_check.
    METHODS plain_exception_as_text       FOR TESTING RAISING cx_static_check.
    METHODS chain_outer_is_header         FOR TESTING RAISING cx_static_check.
    METHODS no_fail_keeps_handler_open    FOR TESTING RAISING cx_static_check.
    METHODS dyn_msg_warning_does_not_fail FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_add_exception IMPLEMENTATION.

  METHOD setup.
    handler = zcl_prc_message_handler=>create_message_handler( ).
  ENDMETHOD.


  METHOD t100_exception.
    TRY.
        RAISE EXCEPTION TYPE lcx_dyn MESSAGE ID 'ZPRC_TEST_MSG_HDLR' TYPE i_type NUMBER '001' WITH i_v1
              EXPORTING previous = i_previous.
      CATCH lcx_dyn INTO DATA(error).
        r_exception = error.
    ENDTRY.
  ENDMETHOD.


  METHOD t100_exception_keeps_key.
    " An exception with T100 key keeps message class, number and variable; it fails the handler
    TRY.
        handler->add_exception( t100_exception( i_v1 = 'x1' ) ).
        cl_abap_unit_assert=>fail( 'An error exception must fail the handler' ).
      CATCH zcx_prc_unit_of_work_failed ##NO_HANDLER.
        " expected
    ENDTRY.

    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'x1' message_text = 'Message x1' ) ).
    cl_abap_unit_assert=>assert_true( handler->has_errors( ) ).
  ENDMETHOD.


  METHOD plain_exception_as_text.
    " An exception without T100 key is stored with its text as SY/499
    TRY.
        RAISE EXCEPTION TYPE lcx_plain.
      CATCH lcx_plain INTO DATA(error).
    ENDTRY.

    handler->add_exception( i_exception = error i_fail_on_error_message = abap_false ).

    DATA(header) = handler->get_header( ).
    cl_abap_unit_assert=>assert_equals(
        act = VALUE ty_header( msgid = header-msgid msgno = header-msgno msgty = header-msgty message_text = header-message_text )
        exp = VALUE ty_header( msgid = 'SY' msgno = '499' msgty = 'E' message_text = 'Plain text' ) ).
  ENDMETHOD.


  METHOD chain_outer_is_header.
    " The cause comes first, the exception itself last - so the outer one is the header
    handler->add_exception( i_exception             = t100_exception( i_v1       = 'outer'
                                                                      i_previous = t100_exception( i_v1 = 'inner' ) )
                            i_fail_on_error_message = abap_false ).

    cl_abap_unit_assert=>assert_equals(
        act = VALUE string_table( FOR m IN handler->get_messages( ) ( CONV #( m-msgv1 ) ) )
        exp = VALUE string_table( ( `inner` ) ( `outer` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = handler->get_header( )-msgv1 exp = 'outer' ).
  ENDMETHOD.


  METHOD no_fail_keeps_handler_open.
    " I_FAIL_ON_ERROR_MESSAGE = abap_false: the error is stored, the handler does not fail
    handler->add_exception( i_exception             = t100_exception( i_v1 = 'e' )
                            i_fail_on_error_message = abap_false ).

    cl_abap_unit_assert=>assert_false( handler->has_errors( ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( handler->get_messages( ) ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = handler->get_header( )-msgty exp = 'E' ).
  ENDMETHOD.


  METHOD dyn_msg_warning_does_not_fail.
    " The severity of IF_T100_DYN_MSG is kept: a warning does not fail the handler
    handler->add_exception( t100_exception( i_type = 'W' i_v1 = 'w' ) ).

    cl_abap_unit_assert=>assert_false( handler->has_errors( ) ).
    cl_abap_unit_assert=>assert_equals( act = handler->get_header( ) exp = VALUE ty_header(
        msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'W' msgv1 = 'w' message_text = 'Message w' ) ).
  ENDMETHOD.

ENDCLASS.


"! Unexpected errors end-to-end (step layer 6), read from the persistence.
CLASS ltc_unexpected DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS t100_chain_keeps_key FOR TESTING.
ENDCLASS.


CLASS ltc_unexpected IMPLEMENTATION.

  METHOD t100_chain_keeps_key.
    " The transition raises an unexpected exception with T100 key ('outer') and a cause ('inner'):
    " the step fails, both are stored with their message key (not as SY/499), the outer one is the header
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'UNEXPECTED_T100_CHAIN' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'UNEXPECTED_T100_CHAIN' step_total = 1 latest_step = 'S1' retry_count = 1 retry = '+300'
                              changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'UNEXPECTED_T100_CHAIN' end_state = 'UNEXPECTED_T100_CHAIN'
                              msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'outer' text = 'Message outer' severity_code = 1 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'inner' text = 'Message inner' severity_code = 1 )
                            ( object = 'O1' step = 'S1' msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'outer' text = 'Message outer' severity_code = 1 ) ) ) ).
  ENDMETHOD.

ENDCLASS.


"! Defaults of the transition base class end-to-end, read from the persistence.
CLASS ltc_default_success DEFINITION INHERITING FROM ltc_base FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS default_success_message FOR TESTING.
ENDCLASS.


CLASS ltc_default_success IMPLEMENTATION.

  METHOD default_success_message.
    " A transition that redefines no success message: the step header is the
    " default of the base class ZPRC_PROCESS_MESSAGE/017 with the start state
    fixture->insert_given( VALUE #( objects = VALUE #( ( ref = 'O1' state = 'DEFAULT_SUCCESS' step_total = 1 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = fixture->read_actual( ) exp = VALUE ty_data(
        objects  = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 1 latest_step = 'S1' changed = 'CHANGED' etag = 'CHANGED' ) )
        steps    = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'DEFAULT_SUCCESS' end_state = 'FINISHED'
                              msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '017' msgty = 'S' msgv1 = 'DEFAULT_SUCCESS'
                              text = 'Transition from state DEFAULT_SUCCESS completed successfully' severity_code = 3 ) )
        messages = VALUE #( ( object = 'O1' step = 'S1' msgid = 'ZPRC_PROCESS_MESSAGE' msgno = '017' msgty = 'S' msgv1 = 'DEFAULT_SUCCESS'
                              text = 'Transition from state DEFAULT_SUCCESS completed successfully' severity_code = 3 ) ) ) ).
  ENDMETHOD.

ENDCLASS.
