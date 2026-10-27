"! The job as the application job runs it (in this session). Sending fails without
"! SMTP configuration; the prepared mail is in the payload either way.
CLASS ltc_error_mail_job DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    CONSTANTS co_mail TYPE string VALUE `prc-unit-test@example.com`.

    TYPES: BEGIN OF ty_notification,
             uuid    TYPE sysuuid_x16,
             payload TYPE zcl_prc_notification=>ty_payload,
           END OF ty_notification,
           tt_notifications TYPE STANDARD TABLE OF ty_notification WITH EMPTY KEY.

    METHODS setup.
    METHODS teardown.
    METHODS one_notification_per_group FOR TESTING.
    METHODS nothing_without_errors     FOR TESTING.

    METHODS run_job.
    "! Notification objects of the test process (object ID starts with its name)
    METHODS read_notifications RETURNING VALUE(r_notifications) TYPE tt_notifications.
    METHODS delete_notifications.
ENDCLASS.


CLASS ltc_error_mail_job IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    delete_notifications( ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    delete_notifications( ).
  ENDMETHOD.


  METHOD one_notification_per_group.
    " Two failed objects with the same address, one finished: one mail with two rows
    DATA(fixture) = NEW zcl_prc_test_proc_fixture( ).
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'MAIL1' state = 'START' step_total = 3 mail = co_mail payload = `{"START":{"FAIL":"X"}}` )
                           ( ref = 'MAIL2' state = 'START' step_total = 3 mail = co_mail payload = `{"START":{"FAIL":"X"}}` )
                           ( ref = 'MAIL3' state = 'START' step_total = 3 mail = co_mail ) ) ) ).
    fixture->run( ).

    run_job( ).

    DATA(notifications) = read_notifications( ).
    cl_abap_unit_assert=>assert_equals( act = lines( notifications ) exp = 1 msg = 'One per process and address' ).

    DATA(payload) = notifications[ 1 ]-payload.
    cl_abap_unit_assert=>assert_equals( act = payload-process_name exp = zcl_prc_test_proc_fixture=>co_process_name ).
    cl_abap_unit_assert=>assert_equals( act = condense( payload-notification-recipient ) exp = co_mail ).
    cl_abap_unit_assert=>assert_not_initial( act = payload-notification-subject msg = 'Mail prepared' ).

    DATA(body) = payload-notification-body_html.
    cl_abap_unit_assert=>assert_true( act = xsdbool( body CS '>MAIL1<' ) msg = 'Failed object 1 listed' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( body CS '>MAIL2<' ) msg = 'Failed object 2 listed' ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( body CS 'MAIL3' ) msg = 'Finished objects are not listed' ).

    " Links into the Processing Center wherever the system URL is known:
    " one per object (object page) and one to all objects with errors of the process
    DATA(launchpad) = zcl_prc_notification=>launchpad_url( ).
    IF launchpad IS NOT INITIAL.
      DATA(object_uuid) = zcl_prc_notification=>uuid_text( fixture->uuid( `MAIL1` ) ).
      cl_abap_unit_assert=>assert_true(
          act = xsdbool( body CS |<a href="{ launchpad }#ABAP_PRC_ProcessedObject-show?UUID={ object_uuid }">MAIL1</a>| )
          msg = 'Link to the object page of the object' ).
      cl_abap_unit_assert=>assert_true(
          act = xsdbool( body CS |#ABAP_PRC_ProcessedObject-show?ProcessName={ zcl_prc_test_proc_fixture=>co_process_name }&amp;MessageSeverity=E| )
          msg = 'Link to all objects with errors of the process' ).
    ENDIF.
  ENDMETHOD.


  METHOD nothing_without_errors.
    DATA(fixture) = NEW zcl_prc_test_proc_fixture( ).
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'MAIL1' state = 'START' step_total = 3 mail = co_mail ) ) ) ).
    fixture->run( ).

    run_job( ).

    cl_abap_unit_assert=>assert_initial( act = read_notifications( ) msg = 'No error, no mail' ).
  ENDMETHOD.


  METHOD run_job.
    NEW zcl_prc_error_mail_job( )->execute_synchronously(
        VALUE #( ( selname = zcl_prc_error_mail_job=>c_process_name kind = 'S' sign = 'I' option = 'EQ'
                   low     = zcl_prc_test_proc_fixture=>co_process_name ) ) ).
  ENDMETHOD.


  METHOD read_notifications.
    DATA(pattern) = |{ zcl_prc_test_proc_fixture=>co_process_name } /%|.
    SELECT uuid, payload_json FROM zprc_proc_object
      WHERE process_name             = @zcl_prc_notif_error_proc=>co_process_name
        AND ext_processed_object_id LIKE @pattern
      INTO TABLE @DATA(objects).
    LOOP AT objects INTO DATA(object).
      APPEND INITIAL LINE TO r_notifications ASSIGNING FIELD-SYMBOL(<notification>).
      <notification>-uuid = object-uuid.
      zcl_prc_notification=>payload_from_json( EXPORTING i_json    = object-payload_json
                                               IMPORTING e_payload = <notification>-payload ).
    ENDLOOP.
  ENDMETHOD.


  METHOD delete_notifications.
    " Only the notifications this test creates - other notifications of the system stay
    DATA lt_uuids TYPE RANGE OF sysuuid_x16.
    DATA(pattern) = |{ zcl_prc_test_proc_fixture=>co_process_name } /%|.
    SELECT uuid FROM zprc_proc_object
      WHERE process_name             = @zcl_prc_notif_error_proc=>co_process_name
        AND ext_processed_object_id LIKE @pattern
      INTO TABLE @DATA(objects).
    IF objects IS INITIAL.
      RETURN.
    ENDIF.
    lt_uuids = VALUE #( FOR o IN objects ( sign = 'I' option = 'EQ' low = o-uuid ) ).
    DELETE FROM zprc_proc_msg    WHERE processed_object_uuid IN @lt_uuids.
    DELETE FROM zprc_proc_step   WHERE processed_object_uuid IN @lt_uuids.
    DELETE FROM zprc_proc_object WHERE uuid                  IN @lt_uuids.
    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
