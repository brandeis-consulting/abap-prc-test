"! Application log of the processing: one log per run and package, every
"! message of every written step, each with a prefix.
CLASS ltc_log DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.

    METHODS setup.
    METHODS teardown.

    "! Texts and severities of all log items with the external ID of the run
    METHODS log_items IMPORTING i_run          TYPE string
                      RETURNING VALUE(r_items) TYPE string_table.
    METHODS delete_logs IMPORTING i_run TYPE string.
    "! Number of messages written for the object
    METHODS message_count IMPORTING i_object       TYPE string
                          RETURNING VALUE(r_count) TYPE i.

    METHODS chain_logs_every_message   FOR TESTING.
    METHODS failure_logs_error         FOR TESTING.
    METHODS unprocessed_logs_nothing   FOR TESTING.
ENDCLASS.


CLASS ltc_log IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    fixture = NEW #( ).
  ENDMETHOD.


  METHOD teardown.
    delete_logs( 'R1' ).
  ENDMETHOD.


  METHOD chain_logs_every_message.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 run = 'R1' ) ) ) ).
    delete_logs( 'R1' ).

    fixture->run( ).

    DATA(items) = log_items( 'R1' ).
    cl_abap_unit_assert=>assert_equals( act = lines( items )
                                        exp = message_count( 'O1' )
                                        msg = 'Every message of every step in the log of the run' ).
    LOOP AT items INTO DATA(item).
      cl_abap_unit_assert=>assert_char_cp( act = item
                                           exp = |+:{ zcl_prc_test_proc_fixture=>co_process_name } / O1 / * -> *: *|
                                           msg = 'Default prefix: process / object / states' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD failure_logs_error.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 run = 'R1' payload = `{"START":{"FAIL":"X"}}` ) ) ) ).
    delete_logs( 'R1' ).

    fixture->run( ).

    DATA(items) = log_items( 'R1' ).
    cl_abap_unit_assert=>assert_equals( act = lines( items )
                                        exp = message_count( 'O1' ) ).
    DATA(errors) = REDUCE i( INIT n = 0 FOR i IN items WHERE ( table_line CP 'E:*' ) NEXT n = n + 1 ).
    cl_abap_unit_assert=>assert_differs( act = errors
                                         exp = 0
                                         msg = 'The failed step is logged as error' ).
  ENDMETHOD.


  METHOD unprocessed_logs_nothing.
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'FINISHED' step_total = 3 run = 'R1' ) ) ) ).
    delete_logs( 'R1' ).

    fixture->run( ).

    cl_abap_unit_assert=>assert_initial( act = log_items( 'R1' ) ).
  ENDMETHOD.


  METHOD log_items.
    DATA(external_id) = CONV cl_bali_header_setter=>ty_external_id( |{ fixture->uuid( i_run ) }| ).
    TRY.
        DATA(logs) = cl_bali_log_db=>get_instance( )->load_logs_via_filter(
                         cl_bali_log_filter=>create( )->set_descriptor( object      = zcl_prc_step_log=>co_log_object
                                                                        external_id = external_id ) ).
        LOOP AT logs INTO DATA(log).
          LOOP AT log->get_all_items( ) INTO DATA(item).
            APPEND |{ item-item->severity }:{ item-item->get_message_text( ) }| TO r_items.
          ENDLOOP.
        ENDLOOP.
      CATCH cx_bali_runtime ##NO_HANDLER.
        " No log found
    ENDTRY.
  ENDMETHOD.


  METHOD delete_logs.
    DATA(external_id) = CONV cl_bali_header_setter=>ty_external_id( |{ fixture->uuid( i_run ) }| ).
    TRY.
        DATA(logs) = cl_bali_log_db=>get_instance( )->load_logs_via_filter(
                         cl_bali_log_filter=>create( )->set_descriptor( object      = zcl_prc_step_log=>co_log_object
                                                                        external_id = external_id ) ).
        LOOP AT logs INTO DATA(log).
          cl_bali_log_db=>get_instance( )->delete_log( log ).
        ENDLOOP.
        COMMIT WORK.
      CATCH cx_bali_runtime ##NO_HANDLER.
        " No log found
    ENDTRY.
  ENDMETHOD.


  METHOD message_count.
    DATA(object_uuid) = fixture->uuid( i_object ).
    SELECT COUNT( * ) FROM zr_prc_processedmessage WITH PRIVILEGED ACCESS
      WHERE ProcessedObjectUUID = @object_uuid
      INTO @r_count.
  ENDMETHOD.

ENDCLASS.
