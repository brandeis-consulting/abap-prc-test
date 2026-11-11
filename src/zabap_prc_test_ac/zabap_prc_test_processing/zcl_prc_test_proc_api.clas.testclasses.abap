"! Creating objects through the processing API: only create, create and process.
CLASS ltc_create DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS co_external_id TYPE c LENGTH 10 VALUE 'APICREATE1'.

    METHODS setup.
    METHODS teardown.
    METHODS derived_fields_are_set      FOR TESTING.
    METHODS create_does_not_commit      FOR TESTING.
    METHODS create_and_process_commits  FOR TESTING.

    METHODS to_create RETURNING VALUE(r_objects) TYPE zcl_prc_processing_api=>tt_create_processed_objects.
ENDCLASS.


CLASS ltc_create IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK WORK.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD to_create.
    r_objects = VALUE #( ( processName      = zcl_prc_test_proc_fixture=>co_process_name
                           factoryClassName = zcl_prc_test_proc_fixture=>co_factory
                           processedObject  = co_external_id ) ).
  ENDMETHOD.


  METHOD derived_fields_are_set.
    zcl_prc_processing_api=>get_instance( )->create( to_create( ) ).
    COMMIT WORK.

    SELECT SINGLE State, StepTotal, CreatedBy, CreatedAt, LastChangedAt, LocalLastChangedAt
      FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName               = @zcl_prc_test_proc_fixture=>co_process_name
        AND ExternalProcessedObjectID = @co_external_id
      INTO @DATA(object).

    cl_abap_unit_assert=>assert_subrc( msg = 'Object created' ).
    cl_abap_unit_assert=>assert_equals( act = object-State exp = zif_prc_process=>co_start ).
    " Derived by the DB writer from the transitions of the process class (longest path)
    cl_abap_unit_assert=>assert_equals( act = object-StepTotal exp = 3 msg = 'StepTotal derived as for the BO' ).
    cl_abap_unit_assert=>assert_not_initial( act = object-CreatedBy          msg = 'CreatedBy' ).
    cl_abap_unit_assert=>assert_not_initial( act = object-CreatedAt          msg = 'CreatedAt' ).
    cl_abap_unit_assert=>assert_not_initial( act = object-LastChangedAt      msg = 'LastChangedAt' ).
    cl_abap_unit_assert=>assert_not_initial( act = object-LocalLastChangedAt msg = 'LocalLastChangedAt (ETag)' ).
  ENDMETHOD.


  METHOD create_does_not_commit.
    " The caller's LUW decides: after a rollback nothing is left
    zcl_prc_processing_api=>get_instance( )->create( to_create( ) ).
    ROLLBACK WORK.

    SELECT SINGLE @abap_true FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName               = @zcl_prc_test_proc_fixture=>co_process_name
        AND ExternalProcessedObjectID = @co_external_id
      INTO @DATA(exists).
    cl_abap_unit_assert=>assert_initial( act = exists msg = 'Not committed by the API' ).
  ENDMETHOD.


  METHOD create_and_process_commits.
    " Processing needs committed objects (own step sessions): committed and processed
    zcl_prc_processing_api=>get_instance( )->create_and_process( to_create( ) ).
    ROLLBACK WORK.

    SELECT SINGLE LatestStepUUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName               = @zcl_prc_test_proc_fixture=>co_process_name
        AND ExternalProcessedObjectID = @co_external_id
      INTO @DATA(latest_step).
    cl_abap_unit_assert=>assert_subrc( msg = 'Committed by the API' ).
    cl_abap_unit_assert=>assert_not_initial( act = latest_step msg = 'Processed (at least one step)' ).
  ENDMETHOD.

ENDCLASS.
