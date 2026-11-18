CLASS lhc_testbgpf DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR TestBgpf RESULT result.
ENDCLASS.


CLASS lhc_testbgpf IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Test object: everything is allowed
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

ENDCLASS.


"! Saver: assigns the final ID in the late numbering exit and then calls the
"! processing API in bgPF mode for the new instances.
CLASS lsc_zr_prc_test_bgpf DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS adjust_numbers REDEFINITION.
ENDCLASS.


CLASS lsc_zr_prc_test_bgpf IMPLEMENTATION.

  METHOD adjust_numbers.
    CHECK mapped-testbgpf IS NOT INITIAL.

    " 1) Assign the final ID (MAX + 1 is enough for the test)
    SELECT MAX( id ) FROM zprc_test_bgpf INTO @DATA(max_id).
    DATA(next_id) = CONV int8( max_id ).

    LOOP AT mapped-testbgpf ASSIGNING FIELD-SYMBOL(<mapped>).
      next_id += 1.
      <mapped>-ID = next_id.
    ENDLOOP.

    " 2) Call the processing API in bgPF mode - this is what the test is about.
    "    No commit: not allowed in the save sequence.
    TRY.
        zcl_prc_processing_api=>get_instance( )->create_and_schedule_bgpf(
            VALUE #( FOR new IN mapped-testbgpf
                     ( processName      = zcl_prc_test_bgpf_proc=>co_process_name
                       factoryClassName = zcl_prc_test_bgpf_proc=>co_class_name
                       processedObject  = new-ID ) ) ).
      CATCH cx_bgmc.
        " The test waits for the processed object to be finished - without bgPF it fails there
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
