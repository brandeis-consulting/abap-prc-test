"! Header message of every written step: exactly one, equal to the step header.
CLASS ltc_header DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.

    METHODS setup.

    "! Asserts for every step of the object: one header message, equal to the step header.
    "! Returns the number of steps.
    METHODS assert_one_header_per_step IMPORTING i_object       TYPE string
                                       RETURNING VALUE(r_steps) TYPE i.

    METHODS chain_marks_each_header FOR TESTING.
    METHODS failure_marks_error     FOR TESTING.
ENDCLASS.


CLASS ltc_header IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    fixture = NEW #( ).
  ENDMETHOD.


  METHOD chain_marks_each_header.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = assert_one_header_per_step( 'O1' )
                                        exp = 3
                                        msg = 'Three steps written' ).
  ENDMETHOD.


  METHOD failure_marks_error.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"FAIL":"X"}}` ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = assert_one_header_per_step( 'O1' )
                                        exp = 1
                                        msg = 'One failed step written' ).

    DATA(object_uuid) = fixture->uuid( 'O1' ).
    SELECT SINGLE MessageSeverity FROM zr_prc_processedmessage WITH PRIVILEGED ACCESS
      WHERE ProcessedObjectUUID = @object_uuid
        AND IsHeader            = @abap_true
      INTO @DATA(severity).
    cl_abap_unit_assert=>assert_equals( act = severity exp = 'E' msg = 'Header of a failed step is an error' ).
  ENDMETHOD.


  METHOD assert_one_header_per_step.
    DATA(object_uuid) = fixture->uuid( i_object ).
    SELECT StepUUID, MessageClass, MessageNumber, MessageSeverity, MessageText
      FROM zr_prc_processedstep WITH PRIVILEGED ACCESS
      WHERE ProcessedObjectUUID = @object_uuid
      INTO TABLE @DATA(steps).

    LOOP AT steps INTO DATA(step).
      SELECT MessageClass, MessageNumber, MessageSeverity, MessageText
        FROM zr_prc_processedmessage WITH PRIVILEGED ACCESS
        WHERE ProcessedStepUUID = @step-StepUUID
          AND IsHeader          = @abap_true
        INTO TABLE @DATA(headers).

      cl_abap_unit_assert=>assert_equals( act = lines( headers )
                                          exp = 1
                                          msg = |Step { step-MessageText }: exactly one header message| ).
      cl_abap_unit_assert=>assert_equals( act = headers[ 1 ]
                                          exp = VALUE #( BASE headers[ 1 ]
                                                         MessageClass    = step-MessageClass
                                                         MessageNumber   = step-MessageNumber
                                                         MessageSeverity = step-MessageSeverity
                                                         MessageText     = step-MessageText )
                                          msg = 'Header message equals the step header' ).
    ENDLOOP.
    r_steps = lines( steps ).
  ENDMETHOD.

ENDCLASS.
