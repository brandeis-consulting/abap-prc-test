"! Format and helpers shared by both notification processes.
CLASS ltc_format DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS payload_roundtrip         FOR TESTING.
    METHODS object_id_cut_to_50       FOR TESTING.
    METHODS html_escapes              FOR TESTING.
    METHODS link_without_url_is_text  FOR TESTING.
    METHODS uuid_text_hyphenated      FOR TESTING.
    METHODS run_notification_object   FOR TESTING.
ENDCLASS.


CLASS ltc_format IMPLEMENTATION.

  METHOD payload_roundtrip.
    DATA actual TYPE zcl_prc_notification=>ty_payload.
    DATA(given) = VALUE zcl_prc_notification=>ty_payload(
        process_name = 'PRC_X'
        mail_address = `someone.with.a.long.address@example.com`
        notification = VALUE #( recipient = `r@example.com` subject = `S` body_html = `<p>"x"</p>` ) ).

    DATA(success) = zcl_prc_notification=>payload_from_json( EXPORTING i_json    = zcl_prc_notification=>payload_to_json( given )
                                                             IMPORTING e_payload = actual ).
    cl_abap_unit_assert=>assert_true( success ).
    cl_abap_unit_assert=>assert_equals( act = actual exp = given ).
  ENDMETHOD.

  METHOD object_id_cut_to_50.
    DATA(id) = zcl_prc_notification=>object_id( |PRC_PROCESS / { repeat( val = `a` occ = 80 ) }@example.com| ).
    cl_abap_unit_assert=>assert_equals( act = strlen( id ) exp = 50 msg = 'Readable ID cut to 50 characters' ).
    cl_abap_unit_assert=>assert_true( xsdbool( id CP 'PRC_PROCESS / a*' ) ).
  ENDMETHOD.

  METHOD html_escapes.
    " text content: markup characters escaped
    cl_abap_unit_assert=>assert_equals( act = zcl_prc_notification=>html( `<b>&` )
                                        exp = `&lt;b&gt;&amp;` ).
    " attribute value: quotes escaped as well, the link is not broken
    cl_abap_unit_assert=>assert_char_np( act = zcl_prc_notification=>html_link( i_launchpad_url = `https://h/flp`
                                                                                i_intent        = `X-show`
                                                                                i_parameters    = `a="1"`
                                                                                i_text          = `T` )
                                         exp = '*a="1"*' ).
  ENDMETHOD.

  METHOD link_without_url_is_text.
    cl_abap_unit_assert=>assert_equals( act = zcl_prc_notification=>html_link( i_launchpad_url = ``
                                                                               i_intent        = `X-show`
                                                                               i_parameters    = `UUID=1`
                                                                               i_text          = `A<B` )
                                        exp = `A&lt;B` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_prc_notification=>html_link( i_launchpad_url = `https://h/flp`
                                                                               i_intent        = `X-show`
                                                                               i_parameters    = `a=1&b=2`
                                                                               i_text          = `T` )
                                        exp = `<a href="https://h/flp#X-show?a=1&amp;b=2">T</a>` ).
  ENDMETHOD.

  METHOD uuid_text_hyphenated.
    cl_abap_unit_assert=>assert_equals( act = zcl_prc_notification=>uuid_text( CONV sysuuid_x16( '5AF3C81B9D2E1FE1B3D5D4282B3DC069' ) )
                                        exp = `5af3c81b-9d2e-1fe1-b3d5-d4282b3dc069` ).
  ENDMETHOD.

  METHOD run_notification_object.
    DATA payload TYPE zcl_prc_notification=>ty_payload.
    DATA(run_uuid) = CONV sysuuid_x16( '5AF3C81B9D2E1FE1B3D5D4282B3DC069' ).
    DATA(objects) = zcl_prc_notif_run_proc=>create_notification( i_run_uuid         = run_uuid
                                                                 i_application_name = 'DEMO_APP'
                                                                 i_job_start        = '20261023065445' ).

    cl_abap_unit_assert=>assert_equals( act = lines( objects ) exp = 1 ).
    DATA(object) = objects[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = object-processName      exp = zcl_prc_notif_run_proc=>co_process_name ).
    cl_abap_unit_assert=>assert_equals( act = object-factoryClassName exp = zcl_prc_notif_run_proc=>co_class_name ).
    cl_abap_unit_assert=>assert_equals( act = object-processedObjectUUID exp = run_uuid msg = 'Group = run' ).
    cl_abap_unit_assert=>assert_char_cp( act = object-processedObject exp = 'DEMO_APP 2026-10-23T06:54:45*' ).
    zcl_prc_notification=>payload_from_json( EXPORTING i_json = object-payloadJson IMPORTING e_payload = payload ).
    cl_abap_unit_assert=>assert_equals( act = payload-run_uuid exp = run_uuid ).
  ENDMETHOD.
ENDCLASS.


"! Transitions of the notification processes, called directly (no engine, nothing sent).
CLASS ltc_transitions DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS co_mail       TYPE string VALUE `prc.notification.test@example.com`.
    CONSTANTS co_other_mail TYPE string VALUE `prc.other@example.com`.

    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.
    DATA handler TYPE REF TO zif_prc_message_handler.

    METHODS setup.
    METHODS teardown.

    METHODS error_prepare_builds_mail     FOR TESTING.
    METHODS error_prepare_nothing_left    FOR TESTING.
    METHODS error_prepare_invalid_payload FOR TESTING.
    METHODS run_prepare_run_not_found     FOR TESTING.
    METHODS send_without_notification     FOR TESTING.

    "! Runs the transition of I_PROCESS starting in I_STATE with C_PAYLOAD.
    "! E_FAILED = ABAP_TRUE if it raised; header and messages in HANDLER.
    METHODS transition IMPORTING i_process   TYPE REF TO zif_prc_process
                                 i_state     TYPE zif_prc_process=>ty_state
                       EXPORTING e_new_state TYPE zif_prc_process=>ty_state
                                 e_failed    TYPE abap_bool
                       CHANGING  c_payload   TYPE zprc_payload_json.

    "! Given object of the test process with header severity I_MSGTY and mail address I_MAIL
    METHODS given_object IMPORTING i_ref   TYPE string
                                   i_msgty TYPE symsgty
                                   i_mail  TYPE string
                         CHANGING  c_given TYPE zcl_prc_test_proc_fixture=>ty_data.
ENDCLASS.


CLASS ltc_transitions IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    fixture = NEW #( ).
  ENDMETHOD.

  METHOD teardown.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.

  METHOD transition.
    CLEAR: e_new_state, e_failed.
    handler = zcl_prc_message_handler=>create_message_handler( ).
    DATA(lo_transition) = i_process->get_transition_handler( i_start_state      = i_state
                                                             i_processed_object = 'TEST' ).
    lo_transition->initialize( i_process_name              = 'TEST'
                               i_processed_object_ext_id   = 'TEST'
                               i_processed_object_ext_uuid = VALUE #( )
                               i_message_handler           = handler ).
    TRY.
        e_new_state = lo_transition->perform_transition( EXPORTING i_start_state  = i_state
                                                         CHANGING  c_payload_json = c_payload ).
      CATCH zcx_prc_unit_of_work_failed.
        e_failed = abap_true.
      CATCH cx_root INTO DATA(lo_unexpected).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_unexpected->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD given_object.
    INSERT VALUE #( ref = i_ref state = zif_prc_process=>co_start mail = i_mail latest_step = |{ i_ref }S| )
           INTO TABLE c_given-objects.
    INSERT VALUE #( object = i_ref ref = |{ i_ref }S| seq = 1
                    start_state = zif_prc_process=>co_start end_state = zif_prc_process=>co_start
                    msgid = 'ZPRC_TEST_PROC' msgno = '001' msgty = i_msgty
                    text = |Header of { i_ref }| severity_code = COND #( WHEN i_msgty = 'E' THEN 1 ELSE 3 ) )
           INTO TABLE c_given-steps.
  ENDMETHOD.

  METHOD error_prepare_builds_mail.
    DATA given  TYPE zcl_prc_test_proc_fixture=>ty_data.
    DATA actual TYPE zcl_prc_notification=>ty_payload.
    given_object( EXPORTING i_ref = `NTF_E1`    i_msgty = 'E' i_mail = co_mail       CHANGING c_given = given ).
    given_object( EXPORTING i_ref = `NTF_E2`    i_msgty = 'E' i_mail = co_mail       CHANGING c_given = given ).
    given_object( EXPORTING i_ref = `NTF_OK`    i_msgty = 'S' i_mail = co_mail       CHANGING c_given = given ).
    given_object( EXPORTING i_ref = `NTF_OTHER` i_msgty = 'E' i_mail = co_other_mail CHANGING c_given = given ).
    fixture->insert_given( given ).

    DATA(payload) = zcl_prc_notification=>payload_to_json( VALUE #( process_name = zcl_prc_test_proc_fixture=>co_process_name
                                                                    mail_address = co_mail ) ).
    transition( EXPORTING i_process   = NEW zcl_prc_notif_error_proc( )
                          i_state     = zif_prc_process=>co_start
                IMPORTING e_new_state = DATA(new_state)
                          e_failed    = DATA(failed)
                CHANGING  c_payload   = payload ).

    cl_abap_unit_assert=>assert_false( act = failed msg = |Prepare failed: { handler->get_header( )-message_text }| ).
    cl_abap_unit_assert=>assert_equals( act = new_state exp = zcl_prc_notification=>co_prepared ).
    zcl_prc_notification=>payload_from_json( EXPORTING i_json = payload IMPORTING e_payload = actual ).
    cl_abap_unit_assert=>assert_equals( act = actual-notification-recipient exp = co_mail ).
    cl_abap_unit_assert=>assert_char_cp( act = actual-notification-subject exp = '*2 objects*' ).
    cl_abap_unit_assert=>assert_char_cp( act = actual-notification-body_html exp = '*Header of NTF_E1*' ).
    cl_abap_unit_assert=>assert_char_cp( act = actual-notification-body_html exp = '*Header of NTF_E2*' ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( actual-notification-body_html CS 'NTF_OK' )
                                       msg = 'Objects without error are not reported' ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( actual-notification-body_html CS 'NTF_OTHER' )
                                       msg = 'Objects of another mail address are not reported' ).
  ENDMETHOD.

  METHOD error_prepare_nothing_left.
    DATA given TYPE zcl_prc_test_proc_fixture=>ty_data.
    given_object( EXPORTING i_ref = `NTF_OK` i_msgty = 'S' i_mail = co_mail CHANGING c_given = given ).
    fixture->insert_given( given ).

    DATA(payload) = zcl_prc_notification=>payload_to_json( VALUE #( process_name = zcl_prc_test_proc_fixture=>co_process_name
                                                                    mail_address = co_mail ) ).
    transition( EXPORTING i_process   = NEW zcl_prc_notif_error_proc( )
                          i_state     = zif_prc_process=>co_start
                IMPORTING e_new_state = DATA(new_state)
                          e_failed    = DATA(failed)
                CHANGING  c_payload   = payload ).

    cl_abap_unit_assert=>assert_false( failed ).
    cl_abap_unit_assert=>assert_equals( act = new_state exp = zif_prc_process=>co_finished msg = 'Nothing to send' ).
  ENDMETHOD.

  METHOD error_prepare_invalid_payload.
    DATA(payload) = CONV zprc_payload_json( `{}` ).
    transition( EXPORTING i_process = NEW zcl_prc_notif_error_proc( )
                          i_state   = zif_prc_process=>co_start
                IMPORTING e_failed  = DATA(failed)
                CHANGING  c_payload = payload ).

    cl_abap_unit_assert=>assert_true( failed ).
    cl_abap_unit_assert=>assert_equals( act = handler->get_header( )-msgno exp = '007' ).
  ENDMETHOD.

  METHOD run_prepare_run_not_found.
    DATA(payload) = zcl_prc_notification=>payload_to_json( VALUE #( run_uuid = xco_cp=>uuid( )->value ) ).
    transition( EXPORTING i_process = NEW zcl_prc_notif_run_proc( )
                          i_state   = zif_prc_process=>co_start
                IMPORTING e_failed  = DATA(failed)
                CHANGING  c_payload = payload ).

    cl_abap_unit_assert=>assert_true( failed ).
    cl_abap_unit_assert=>assert_equals( act = handler->get_header( )-msgid exp = 'ZPRC_NOTIFICATION' ).
    cl_abap_unit_assert=>assert_equals( act = handler->get_header( )-msgno exp = '009' ).
  ENDMETHOD.

  METHOD send_without_notification.
    DATA(payload) = zcl_prc_notification=>payload_to_json( VALUE #( process_name = 'X' mail_address = co_mail ) ).
    transition( EXPORTING i_process = NEW zcl_prc_notif_error_proc( )
                          i_state   = zcl_prc_notification=>co_prepared
                IMPORTING e_failed  = DATA(failed)
                CHANGING  c_payload = payload ).

    cl_abap_unit_assert=>assert_true( act = failed msg = 'Nothing prepared, nothing sent' ).
    cl_abap_unit_assert=>assert_equals( act = handler->get_header( )-msgno exp = '007' ).
  ENDMETHOD.
ENDCLASS.


"! Prepare step of the run notification: mail address of the user who started the run.
"! Run, user and mail address are SQL test doubles (no data of real users needed).
CLASS ltc_run_prepare DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS co_user      TYPE syuname VALUE 'PRC_TEST_U1'.
    CONSTANTS co_mail      TYPE string  VALUE `prc.run.creator@example.com`.
    CONSTANTS co_person_id TYPE c LENGTH 10 VALUE '9999999901'.
    CONSTANTS co_addr_id   TYPE c LENGTH 10 VALUE '9999999902'.

    CLASS-DATA environment TYPE REF TO if_osql_test_environment.

    DATA run_uuid TYPE sysuuid_x16.
    DATA handler  TYPE REF TO zif_prc_message_handler.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS mail_of_run_creator  FOR TESTING.
    METHODS creator_without_mail FOR TESTING.

    "! Runs the prepare step for the given run; E_FAILED = ABAP_TRUE if it raised
    METHODS prepare EXPORTING e_new_state TYPE zif_prc_process=>ty_state
                              e_failed    TYPE abap_bool
                              e_payload   TYPE zcl_prc_notification=>ty_payload.
ENDCLASS.


CLASS ltc_run_prepare IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_osql_test_environment=>create(
        i_dependency_list = VALUE #( ( 'ZI_PRC_RUN' ) ( 'I_USER' ) ( 'I_ADDRCURDEFAULTEMAILADDRESS' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    DATA runs  TYPE STANDARD TABLE OF zi_prc_run WITH EMPTY KEY.
    DATA users TYPE STANDARD TABLE OF i_user WITH EMPTY KEY.

    environment->clear_doubles( ).
    run_uuid = xco_cp=>uuid( )->value.
    runs  = VALUE #( ( uuid = run_uuid applicationname = 'DEMO_APP' totalnumber = 2 numberofsuccess = 2
                       createdby = co_user ) ).
    users = VALUE #( ( userid = co_user addresspersonid = co_person_id addressid = co_addr_id ) ).
    environment->insert_test_data( runs ).
    environment->insert_test_data( users ).
  ENDMETHOD.

  METHOD prepare.
    CLEAR: e_new_state, e_failed, e_payload.
    handler = zcl_prc_message_handler=>create_message_handler( ).
    DATA(payload) = zcl_prc_notification=>payload_to_json( VALUE #( run_uuid = run_uuid ) ).
    DATA(lo_process) = CAST zif_prc_process( NEW zcl_prc_notif_run_proc( ) ).
    DATA(lo_transition) = lo_process->get_transition_handler( i_start_state      = zif_prc_process=>co_start
                                                              i_processed_object = 'TEST' ).
    lo_transition->initialize( i_process_name              = 'TEST'
                               i_processed_object_ext_id   = 'TEST'
                               i_processed_object_ext_uuid = VALUE #( )
                               i_message_handler           = handler ).
    TRY.
        e_new_state = lo_transition->perform_transition( EXPORTING i_start_state  = zif_prc_process=>co_start
                                                         CHANGING  c_payload_json = payload ).
      CATCH zcx_prc_unit_of_work_failed.
        e_failed = abap_true.
      CATCH cx_root INTO DATA(lo_unexpected).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_unexpected->get_text( ) }| ).
    ENDTRY.
    zcl_prc_notification=>payload_from_json( EXPORTING i_json = payload IMPORTING e_payload = e_payload ).
  ENDMETHOD.

  METHOD mail_of_run_creator.
    DATA mails TYPE STANDARD TABLE OF i_addrcurdefaultemailaddress WITH EMPTY KEY.
    mails = VALUE #( ( addressid = co_addr_id addresspersonid = co_person_id emailaddress = co_mail ) ).
    environment->insert_test_data( mails ).

    prepare( IMPORTING e_new_state = DATA(new_state)
                       e_failed    = DATA(failed)
                       e_payload   = DATA(payload) ).

    cl_abap_unit_assert=>assert_false( act = failed msg = |Prepare failed: { handler->get_header( )-message_text }| ).
    cl_abap_unit_assert=>assert_equals( act = new_state exp = zcl_prc_notification=>co_prepared ).
    cl_abap_unit_assert=>assert_equals( act = payload-notification-recipient exp = co_mail
                                        msg = 'Mail address of the user who started the run' ).
  ENDMETHOD.

  METHOD creator_without_mail.
    prepare( IMPORTING e_failed = DATA(failed) ).

    cl_abap_unit_assert=>assert_true( act = failed msg = 'No mail address, nothing to send' ).
    cl_abap_unit_assert=>assert_equals( act = handler->get_header( )-msgid exp = 'ZPRC_NOTIFICATION' ).
    cl_abap_unit_assert=>assert_equals( act = handler->get_header( )-msgno exp = '004' ).
  ENDMETHOD.
ENDCLASS.


"! Send step header (F45.5) and links into the launchpad (F45.6). Nothing is sent.
CLASS ltc_send_and_links DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS failure_names_recipient    FOR TESTING.
    METHODS failure_without_recipient  FOR TESTING.
    METHODS system_url_from_icm        FOR TESTING.
    METHODS launchpad_url_known        FOR TESTING.
ENDCLASS.


CLASS ltc_send_and_links IMPLEMENTATION.

  METHOD failure_names_recipient.
    " longer than one message variable: the address is spread over &1-&4
    DATA(recipient) = |{ repeat( val = `a` occ = 60 ) }@example.com|.
    DATA(message) = zcl_prc_notification=>send_failure_message( recipient ).

    cl_abap_unit_assert=>assert_equals( act = message-msgid exp = 'ZPRC_NOTIFICATION' ).
    cl_abap_unit_assert=>assert_equals( act = message-msgno exp = '011' msg = 'Notification to &1&2&3&4 could not be sent' ).
    cl_abap_unit_assert=>assert_equals( act = message-msgty exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = condense( val = |{ message-msgv1 }{ message-msgv2 }| del = ` ` )
                                        exp = recipient msg = 'Whole address in the variables' ).
  ENDMETHOD.

  METHOD failure_without_recipient.
    DATA(message) = zcl_prc_notification=>send_failure_message( `` ).
    cl_abap_unit_assert=>assert_equals( act = message-msgno exp = '006' msg = 'Notification could not be sent' ).
  ENDMETHOD.

  METHOD system_url_from_icm.
    " The Standard ABAP implementation (on premise / private cloud); missing on BTP - nothing to check there
    DATA lo_system_url TYPE REF TO zif_prc_system_url.
    TRY.
        CREATE OBJECT lo_system_url TYPE (zif_prc_system_url=>co_implementation).
      CATCH cx_sy_create_object_error.
        RETURN.
    ENDTRY.

    DATA(url) = lo_system_url->get_system_url( ).
    cl_abap_unit_assert=>assert_char_cp( act = url exp = 'http*://*' msg = |Protocol and host: { url }| ).
    cl_abap_unit_assert=>assert_char_np( act = url exp = '*/' msg = 'No trailing slash (the launchpad path follows)' ).
  ENDMETHOD.

  METHOD launchpad_url_known.
    " In this system (cloud URL or ICM) the mails get links: warning 008 does not apply
    DATA(url) = zcl_prc_notification=>launchpad_url( ).
    cl_abap_unit_assert=>assert_char_cp( act = url exp = |http*://*{ zcl_prc_notification=>co_launchpad_path }|
                                         msg = |Launchpad URL: { url }| ).
  ENDMETHOD.

ENDCLASS.
