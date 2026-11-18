"! Raised events per test, as references of the given objects and runs
"! in the order they were raised.
CLASS ltc_events DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_events,
             object_processed TYPE string_table,
             run_changed      TYPE string_table,
           END OF ty_events.

    CLASS-DATA go_environment TYPE REF TO if_rap_event_test_environment.
    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS raised_events RETURNING VALUE(r_events) TYPE ty_events.
    METHODS raised IMPORTING i_entity      TYPE abp_entity_name
                             i_event       TYPE abp_event_name
                   RETURNING VALUE(r_refs) TYPE string_table.
    METHODS trigger_object_event IMPORTING i_ref TYPE string.
    METHODS trigger_run_event IMPORTING i_ref TYPE string.

    METHODS chain_raises_per_step     FOR TESTING.
    METHODS failure_raises_events     FOR TESTING.
    METHODS unprocessed_raises_none   FOR TESTING.
    METHODS object_event_once         FOR TESTING.
    METHODS run_event_once            FOR TESTING.
ENDCLASS.


CLASS ltc_events IMPLEMENTATION.

  METHOD class_setup.
    go_environment = cl_rap_event_test_environment=>create(
        VALUE #( ( entity_name = 'ZR_PRC_PROCESSEDOBJECTTP' event_name = 'ZZ_OBJECTPROCESSEDTRANSITION' )
                 ( entity_name = 'ZR_PRC_RUNTP'             event_name = 'ZZ_RUNCHANGED' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_environment->destroy( ).
  ENDMETHOD.


  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    " Clear after the cleanup, so only events of this test are collected
    go_environment->clear( ).
    fixture = NEW #( ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.


  METHOD chain_raises_per_step.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 run = 'R1' ) ) ) ).

    fixture->run( ).

    " Object event per step, run event per object
    cl_abap_unit_assert=>assert_equals( act = raised_events( ) exp = VALUE ty_events(
        object_processed = VALUE #( ( `O1` ) ( `O1` ) ( `O1` ) )
        run_changed      = VALUE #( ( `R1` ) ) ) ).
  ENDMETHOD.


  METHOD failure_raises_events.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 run = 'R1' payload = `{"START":{"FAIL":"X"}}` ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = raised_events( ) exp = VALUE ty_events(
        object_processed = VALUE #( ( `O1` ) )
        run_changed      = VALUE #( ( `R1` ) ) ) ).
  ENDMETHOD.


  METHOD unprocessed_raises_none.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 run = 'R1' ) ) ) ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_equals( act = raised_events( ) exp = VALUE ty_events( ) ).
  ENDMETHOD.


  METHOD object_event_once.
    " The buffer of triggerChangedEvent is cleared by CLEANUP: nothing of the
    " rolled-back LUW reaches the next save in the same session
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 ) ) ) ).

    trigger_object_event( `O1` ).
    ROLLBACK ENTITIES.
    trigger_object_event( `O1` ).
    COMMIT ENTITIES.

    cl_abap_unit_assert=>assert_equals( act = raised_events( )-object_processed exp = VALUE string_table( ( `O1` ) )
                                        msg = 'One event - nothing of the rolled-back LUW' ).
  ENDMETHOD.


  METHOD run_event_once.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 run = 'R1' ) ) ) ).

    trigger_run_event( `R1` ).
    ROLLBACK ENTITIES.
    trigger_run_event( `R1` ).
    COMMIT ENTITIES.

    cl_abap_unit_assert=>assert_equals( act = raised_events( )-run_changed exp = VALUE string_table( ( `R1` ) )
                                        msg = 'One event - nothing of the rolled-back LUW' ).
  ENDMETHOD.


  METHOD trigger_object_event.
    MODIFY ENTITIES OF zr_prc_processedobjecttp PRIVILEGED
           ENTITY ProcessedObject
           EXECUTE triggerChangedEvent FROM VALUE #( ( %key-uuid = fixture->uuid( i_ref ) ) )
           FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( act = failed msg = 'Event triggered' ).
  ENDMETHOD.


  METHOD trigger_run_event.
    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           EXECUTE triggerChangedEvent FROM VALUE #( ( %key-uuid = fixture->uuid( i_ref ) ) )
           FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( act = failed msg = 'Event triggered' ).
  ENDMETHOD.


  METHOD raised_events.
    r_events = VALUE #( object_processed = raised( i_entity = 'ZR_PRC_PROCESSEDOBJECTTP' i_event = 'ZZ_OBJECTPROCESSEDTRANSITION' )
                        run_changed      = raised( i_entity = 'ZR_PRC_RUNTP'             i_event = 'ZZ_RUNCHANGED' ) ).
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
      ASSIGN COMPONENT 'UUID' OF STRUCTURE <ls_event> TO FIELD-SYMBOL(<lv_uuid>).
      IF sy-subrc = 0.
        APPEND fixture->ref( CONV #( <lv_uuid> ) ) TO r_refs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
