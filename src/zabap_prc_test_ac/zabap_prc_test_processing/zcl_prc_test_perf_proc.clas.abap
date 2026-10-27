"! <p class="shorttext synchronized">PRC Test: Process without logic (performance)</p>
"! One transition START -> FINISHED whose handler does nothing: measures the cost of
"! the framework alone (selection, packages, isolated step, writes, log, events).
"! Used by ZCL_PRC_TEST_PERF_RUN.
CLASS zcl_prc_test_perf_proc DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_prc_process.
    CONSTANTS co_process_name TYPE zprc_process_name VALUE 'PRC_TEST_PERFORMANCE'.
    CONSTANTS co_class_name   TYPE zprc_process_impl_class VALUE 'ZCL_PRC_TEST_PERF_PROC'.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_perf_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE #( ( start_state = zif_prc_process~co_start end_state = zif_prc_process~co_finished ) ).
  ENDMETHOD.

  METHOD zif_prc_process~get_transition_handler.
    IF i_start_state = zif_prc_process~co_start.
      r_transition_handler = NEW lcl_nothing( ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.

ENDCLASS.

