"! Error notification prepared by the job, then its send step run in this session
CLASS ltc_send_step DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    CONSTANTS co_mail TYPE string VALUE `prc-unit-test@example.com`.

    METHODS setup.
    METHODS teardown.
    METHODS send_or_readable_error FOR TESTING.

    METHODS delete_notifications.
ENDCLASS.


CLASS ltc_send_step IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    delete_notifications( ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    delete_notifications( ).
  ENDMETHOD.


  METHOD send_or_readable_error.
    " A failed object with address, the job prepares the notification
    DATA(fixture) = NEW zcl_prc_test_proc_fixture( ).
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'SEND1' state = 'START' step_total = 3 mail = co_mail payload = `{"START":{"FAIL":"X"}}` ) ) ) ).
    fixture->run( ).
    NEW zcl_prc_error_mail_job( )->execute_synchronously(
        VALUE #( ( selname = zcl_prc_error_mail_job=>c_process_name kind = 'S' sign = 'I' option = 'EQ'
                   low     = zcl_prc_test_proc_fixture=>co_process_name ) ) ).

    DATA(pattern) = |{ zcl_prc_test_proc_fixture=>co_process_name } /%|.
    SELECT SINGLE * FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName                = @zcl_prc_notif_error_proc=>co_process_name
        AND ExternalProcessedObjectID LIKE @pattern
      INTO @DATA(before).
    cl_abap_unit_assert=>assert_subrc( msg = 'Notification created by the job' ).
    cl_abap_unit_assert=>assert_differs( act = before-State exp = zif_prc_process=>co_start msg = 'Mail prepared' ).

    IF before-State = zif_prc_process=>co_finished.
      " Sent already in the isolated session (SMTP configured): nothing left to test here
      RETURN.
    ENDIF.

    " The send step, in this session
    DATA(task) = NEW zcl_prc_step_8_isolation_task( i_state  = before
                                                    i_marker = xco_cp=>uuid( )->value ).
    task->if_abap_parallel~do( ).
    DATA(after) = task->get_result( ).

    cl_abap_unit_assert=>assert_differs( act = after-LatestStepUUID exp = before-LatestStepUUID msg = 'Step written' ).

    IF after-State = zif_prc_process=>co_finished.
      RETURN. " sent
    ENDIF.

    " Not sent: the step names the recipient, the reasons of the mail API follow
    SELECT MessageClass, MessageNumber, MessageSeverity, IsHeader
      FROM zi_prc_processedmessage WITH PRIVILEGED ACCESS
      WHERE ProcessedStepUUID = @after-LatestStepUUID
      INTO TABLE @DATA(messages).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( line_exists( messages[ MessageClass = 'ZPRC_NOTIFICATION' MessageNumber = '011' IsHeader = abap_true ] ) )
        msg = 'Header: notification to ... could not be sent' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lines( messages ) > 1 ) msg = 'Reason of the mail API kept' ).
  ENDMETHOD.


  METHOD delete_notifications.
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
