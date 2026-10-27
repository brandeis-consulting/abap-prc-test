"! ZCL_PRC_PROCESS_LOADER: an instance for a loadable process class, otherwise no
"! instance but ZPRC_PROCESS_MESSAGE/021 with the class - never a short dump.
CLASS ltc_loader DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS loads_process_class       FOR TESTING.
    METHODS unknown_class_reported    FOR TESTING.
    METHODS class_without_interface   FOR TESTING.
    METHODS interface_is_no_class     FOR TESTING.
    METHODS buffered_per_session      FOR TESTING.

    METHODS assert_not_loaded
      IMPORTING i_class_name TYPE csequence.
ENDCLASS.


CLASS ltc_loader IMPLEMENTATION.

  METHOD loads_process_class.
    DATA error TYPE symsg.
    DATA(process) = zcl_prc_process_loader=>get_process( EXPORTING i_class_name = zcl_prc_test_proc_fixture=>co_factory
                                                         IMPORTING e_error      = error ).
    cl_abap_unit_assert=>assert_bound( act = process msg = 'Instance of a loadable process class' ).
    cl_abap_unit_assert=>assert_initial( act = error ).
    cl_abap_unit_assert=>assert_not_initial( act = process->get_transitions( ) msg = 'A usable instance' ).
  ENDMETHOD.


  METHOD unknown_class_reported.
    assert_not_loaded( 'ZCL_PRC_DOES_NOT_EXIST' ).
  ENDMETHOD.


  METHOD class_without_interface.
    " Exists, but is no process class
    assert_not_loaded( 'ZCL_PRC_PROCESSING_API' ).
  ENDMETHOD.


  METHOD interface_is_no_class.
    assert_not_loaded( 'ZIF_PRC_PROCESS' ).
  ENDMETHOD.


  METHOD buffered_per_session.
    " Lower case and blanks lead to the same buffered class
    DATA(first)  = zcl_prc_process_loader=>get_process( zcl_prc_test_proc_fixture=>co_factory ).
    DATA(second) = zcl_prc_process_loader=>get_process( to_lower( |  { zcl_prc_test_proc_fixture=>co_factory }| ) ).
    cl_abap_unit_assert=>assert_bound( act = second ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( first = second ) msg = 'A new instance per call' ).
  ENDMETHOD.


  METHOD assert_not_loaded.
    DATA error TYPE symsg.
    DATA(process) = zcl_prc_process_loader=>get_process( EXPORTING i_class_name = i_class_name
                                                         IMPORTING e_error      = error ).
    cl_abap_unit_assert=>assert_not_bound( act = process msg = |No instance for { i_class_name }| ).
    cl_abap_unit_assert=>assert_equals( act = error-msgid exp = 'ZPRC_PROCESS_MESSAGE' ).
    cl_abap_unit_assert=>assert_equals( act = error-msgno exp = '021' msg = 'Process class &1 cannot be loaded' ).
    cl_abap_unit_assert=>assert_equals( act = error-msgty exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = error-msgv1 exp = i_class_name msg = 'Names the class' ).
    cl_abap_unit_assert=>assert_not_initial( act = error-msgv2 msg = 'Gives a reason' ).
  ENDMETHOD.

ENDCLASS.
