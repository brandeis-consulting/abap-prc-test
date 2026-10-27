"! Creating objects through the processing API, without processing them.
CLASS ltc_create DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS derived_fields_are_set FOR TESTING.
ENDCLASS.


CLASS ltc_create IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD derived_fields_are_set.
    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = VALUE #( ( processName      = zcl_prc_test_proc_fixture=>co_process_name
                                                factoryClassName = zcl_prc_test_proc_fixture=>co_factory
                                                processedObject  = 'APICREATE1' ) )
        i_perform_commit           = abap_true
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-no_execution ).

    SELECT SINGLE State, StepTotal, CreatedBy, CreatedAt, LastChangedAt, LocalLastChangedAt
      FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName               = @zcl_prc_test_proc_fixture=>co_process_name
        AND ExternalProcessedObjectID = 'APICREATE1'
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

ENDCLASS.
