"! <p class="shorttext synchronized">PRC Test: Process START -> FINISHED (bgPF)</p>
"!
"! Minimal test process: one single transition from START to FINISHED that does
"! nothing but report a "performed" message.
CLASS zcl_prc_test_bgpf_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prc_process.

    ALIASES tt_transition FOR zif_prc_process~tt_transition.

    CONSTANTS co_class_name   TYPE zprc_process_impl_class VALUE 'ZCL_PRC_TEST_BGPF_PROC'.
    CONSTANTS co_process_name TYPE zprc_process_name       VALUE 'TEST_BGPF_ADJ_NUM'.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_prc_test_bgpf_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE tt_transition( ( start_state = zif_prc_process~co_start
                                           end_state   = zif_prc_process~co_finished ) ).
  ENDMETHOD.


  METHOD zif_prc_process~get_transition_handler.
    CASE i_start_state.
      WHEN zif_prc_process~co_start.
        r_transition_handler = NEW lcl_start_to_finish( ).
      WHEN OTHERS.
        " FINISHED has no transition, anything else is unexpected
        ASSERT 1 = 2.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.

ENDCLASS.
