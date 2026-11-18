"! Records the scheduled bgPF processes
CLASS lcl_bgpf_double DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_prc_bgpf_scheduler.
    DATA calls TYPE STANDARD TABLE OF zif_prc_processing_engine=>tt_parameters WITH EMPTY KEY.
ENDCLASS.

CLASS lcl_bgpf_double IMPLEMENTATION.
  METHOD zif_prc_bgpf_scheduler~schedule.
    APPEND i_parameters TO calls.
  ENDMETHOD.
ENDCLASS.


"! Same pattern for every BO with an own buffer: action on A, ROLLBACK ENTITIES,
"! action on B, COMMIT ENTITIES - only B may get the side effect of the save.
"!
"! Given: objects O1 and O2, each with its own run (R1, R2) and its own
"! header message (group with variable 'A' resp. 'B').
CLASS ltc_after_rollback DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    TYPES ty_group_key TYPE STRUCTURE FOR KEY OF zr_prc_messagetp.

    CLASS-DATA go_environment TYPE REF TO if_rap_event_test_environment.
    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.
    DATA bgpf    TYPE REF TO lcl_bgpf_double.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    "! Processed object: resume of a rolled-back LUW must not be scheduled
    METHODS object_resume       FOR TESTING.
    "! Processed object: changed event of a rolled-back LUW must not be raised
    METHODS object_event        FOR TESTING.
    "! Run: changed event of a rolled-back LUW must not be raised
    METHODS run_event           FOR TESTING.
    "! Message group: changed event of a rolled-back LUW must not be raised
    METHODS message_event       FOR TESTING.

    METHODS resume_object  IMPORTING i_ref TYPE string.
    METHODS trigger_object IMPORTING i_ref TYPE string.
    METHODS trigger_run    IMPORTING i_ref TYPE string.
    METHODS trigger_group  IMPORTING i_variable TYPE symsgv.
    METHODS group          IMPORTING i_variable   TYPE symsgv
                           RETURNING VALUE(r_key) TYPE ty_group_key.

    "! References (O1, R1) or the given component of the raised events, sorted
    METHODS raised IMPORTING i_entity        TYPE abp_entity_name
                             i_event         TYPE abp_event_name
                             i_component     TYPE string DEFAULT `UUID`
                   RETURNING VALUE(r_values) TYPE string_table.
    "! Objects of all scheduled bgPF processes, sorted
    METHODS scheduled_objects RETURNING VALUE(r_refs) TYPE string_table.
ENDCLASS.


CLASS ltc_after_rollback IMPLEMENTATION.

  METHOD class_setup.
    go_environment = cl_rap_event_test_environment=>create(
        VALUE #( ( entity_name = 'ZR_PRC_PROCESSEDOBJECTTP' event_name = 'ZZ_OBJECTPROCESSEDTRANSITION' )
                 ( entity_name = 'ZR_PRC_RUNTP'             event_name = 'ZZ_RUNCHANGED' )
                 ( entity_name = 'ZR_PRC_MESSAGETP'         event_name = 'ZZ_MESSAGECHANGED' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_environment->destroy( ).
  ENDMETHOD.


  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    bgpf = NEW #( ).
    zcl_prc_bgpf_sched_injector=>inject( bgpf ).

    fixture = NEW #( ).
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 1 run = 'R1' latest_step = 'S1' )
                           ( ref = 'O2' state = 'START' step_total = 1 run = 'R2' latest_step = 'S1' ) )
        steps   = VALUE #( ( object = 'O1' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                             msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'A' text = 'Message A' severity_code = 1 )
                           ( object = 'O2' ref = 'S1' seq = 1 start_state = 'START' end_state = 'START'
                             msgid = 'ZPRC_TEST_MSG_HDLR' msgno = '001' msgty = 'E' msgv1 = 'B' text = 'Message B' severity_code = 1 ) ) ) ).

    " Clear after the given data, so only events of this test are collected
    go_environment->clear( ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    zcl_prc_bgpf_sched_injector=>reset( ).
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD object_resume.
    resume_object( `O1` ).
    ROLLBACK ENTITIES.
    resume_object( `O2` ).
    COMMIT ENTITIES RESPONSE OF zr_prc_processedobjecttp FAILED DATA(failed) REPORTED DATA(reported) ##NEEDED.

    cl_abap_unit_assert=>assert_initial( act = failed msg = 'Save of the resume' ).
    cl_abap_unit_assert=>assert_equals( act = scheduled_objects( ) exp = VALUE string_table( ( `O2` ) )
                                        msg = 'Only the object of the saved LUW is processed' ).
  ENDMETHOD.


  METHOD object_event.
    trigger_object( `O1` ).
    ROLLBACK ENTITIES.
    trigger_object( `O2` ).
    COMMIT ENTITIES.

    cl_abap_unit_assert=>assert_equals(
        act = raised( i_entity = 'ZR_PRC_PROCESSEDOBJECTTP' i_event = 'ZZ_OBJECTPROCESSEDTRANSITION' )
        exp = VALUE string_table( ( `O2` ) )
        msg = 'Only the object of the saved LUW raises its event' ).
  ENDMETHOD.


  METHOD run_event.
    trigger_run( `R1` ).
    ROLLBACK ENTITIES.
    trigger_run( `R2` ).
    COMMIT ENTITIES.

    cl_abap_unit_assert=>assert_equals(
        act = raised( i_entity = 'ZR_PRC_RUNTP' i_event = 'ZZ_RUNCHANGED' )
        exp = VALUE string_table( ( `R2` ) )
        msg = 'Only the run of the saved LUW raises its event' ).
  ENDMETHOD.


  METHOD message_event.
    trigger_group( 'A' ).
    ROLLBACK ENTITIES.
    trigger_group( 'B' ).
    COMMIT ENTITIES.

    cl_abap_unit_assert=>assert_equals(
        act = raised( i_entity = 'ZR_PRC_MESSAGETP' i_event = 'ZZ_MESSAGECHANGED' i_component = `MESSAGEVARIABLE1` )
        exp = VALUE string_table( ( `B` ) )
        msg = 'Only the message group of the saved LUW raises its event' ).
  ENDMETHOD.


  METHOD resume_object.
    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           EXECUTE resumeProcessing FROM VALUE #( ( %key-UUID = fixture->uuid( i_ref ) ) )
           FAILED DATA(failed)
           REPORTED DATA(reported) ##NEEDED.
    cl_abap_unit_assert=>assert_initial( act = failed msg = |Resume of { i_ref }| ).
  ENDMETHOD.


  METHOD trigger_object.
    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           EXECUTE triggerChangedEvent FROM VALUE #( ( %key-UUID = fixture->uuid( i_ref ) ) )
           FAILED DATA(failed)
           REPORTED DATA(reported) ##NEEDED.
    cl_abap_unit_assert=>assert_initial( act = failed msg = |Changed event of { i_ref }| ).
  ENDMETHOD.


  METHOD trigger_run.
    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           EXECUTE triggerChangedEvent FROM VALUE #( ( %key-uuid = fixture->uuid( i_ref ) ) )
           FAILED DATA(failed)
           REPORTED DATA(reported) ##NEEDED.
    cl_abap_unit_assert=>assert_initial( act = failed msg = |Changed event of { i_ref }| ).
  ENDMETHOD.


  METHOD trigger_group.
    MODIFY ENTITIES OF zr_prc_messagetp
           ENTITY Message
           EXECUTE triggerChangedEvent FROM VALUE #( ( %key = group( i_variable ) ) )
           FAILED DATA(failed)
           REPORTED DATA(reported) ##NEEDED.
    cl_abap_unit_assert=>assert_initial( act = failed msg = |Changed event of group { i_variable }| ).
  ENDMETHOD.


  METHOD group.
    SELECT SINGLE * FROM zr_prc_messagetp WITH PRIVILEGED ACCESS
      WHERE ProcessName      = @zcl_prc_test_proc_fixture=>co_process_name
        AND MessageVariable1 = @i_variable
      INTO @DATA(row).
    cl_abap_unit_assert=>assert_subrc( act = sy-subrc msg = |Message group { i_variable } given| ).
    r_key = CORRESPONDING #( row ).
  ENDMETHOD.


  METHOD raised.
    FIELD-SYMBOLS <lt_payload> TYPE ANY TABLE.

    DATA(lo_double) = go_environment->get_event( entity_name = i_entity event_name = i_event ).
    IF lo_double IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA(lr_payload) = lo_double->get_payload( ).
    IF lr_payload IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_payload->* TO <lt_payload>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT <lt_payload> ASSIGNING FIELD-SYMBOL(<ls_event>).
      ASSIGN COMPONENT i_component OF STRUCTURE <ls_event> TO FIELD-SYMBOL(<lv_value>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF i_component = `UUID`.
        APPEND fixture->ref( CONV #( <lv_value> ) ) TO r_values.
      ELSE.
        APPEND condense( CONV string( <lv_value> ) ) TO r_values.
      ENDIF.
    ENDLOOP.
    SORT r_values.
  ENDMETHOD.


  METHOD scheduled_objects.
    LOOP AT bgpf->calls INTO DATA(parameters).
      LOOP AT parameters INTO DATA(parameter) WHERE selname = zcl_prc_retry_job=>co_parameter-uuid.
        APPEND fixture->ref( CONV #( parameter-low ) ) TO r_refs.
      ENDLOOP.
    ENDLOOP.
    SORT r_refs.
  ENDMETHOD.

ENDCLASS.
