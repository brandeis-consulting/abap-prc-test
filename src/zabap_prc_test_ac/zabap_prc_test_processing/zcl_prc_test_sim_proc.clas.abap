"! <p class="shorttext synchronized">PRC Test: Process that allows simulation</p>
"!
"! States START and FINISHED only: START to FINISHED, or START to START with
"! findings. Every transition writes a marker row (ZPRC_TEST_BGPF, ID
"! CO_MARKER_ID) as business change - a simulation must roll it back. The
"! external ID decides the outcome: prefix CO_PREFIX_ERROR fails the step,
"! CO_PREFIX_FINDING ends with a finding, anything else succeeds.
CLASS zcl_prc_test_sim_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prc_process.

    CONSTANTS co_class_name     TYPE zprc_process_impl_class VALUE 'ZCL_PRC_TEST_SIM_PROC'.
    CONSTANTS co_process_name   TYPE zprc_process_name       VALUE 'TEST_SIMULATION'.
    CONSTANTS co_marker_id      TYPE n LENGTH 10             VALUE '9999999028'.
    CONSTANTS co_prefix_error   TYPE string                  VALUE `SIM_ERR`.
    CONSTANTS co_prefix_finding TYPE string                  VALUE `SIM_FIND`.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_sim_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE #( ( start_state = zif_prc_process~co_start end_state = zif_prc_process~co_start )
                             ( start_state = zif_prc_process~co_start end_state = zif_prc_process~co_finished ) ).
  ENDMETHOD.


  METHOD zif_prc_process~get_transition_handler.
    IF i_start_state = zif_prc_process~co_start.
      r_transition_handler = NEW lcl_transition( ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.


  METHOD zif_prc_process~supports_simulation.
    r_result = abap_true.
  ENDMETHOD.

ENDCLASS.
