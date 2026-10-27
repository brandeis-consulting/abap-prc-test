"! <p class="shorttext synchronized">PRC Test: Configurable test process</p>
"!
"! Transitions: START -> A, A -> B1, A -> B2, B1 -> FINISHED, B2 -> FINISHED.
"! What each transition does is read from the payload,
"! see ZCL_PRC_TEST_PROC_PAYLOAD.
CLASS zcl_prc_test_proc_process DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prc_process.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_proc_process IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE #( ( start_state = zif_prc_process~co_start end_state = 'A' )
                             ( start_state = 'A'                      end_state = 'B1' )
                             ( start_state = 'A'                      end_state = 'B2' )
                             ( start_state = 'B1'                     end_state = zif_prc_process~co_finished )
                             ( start_state = 'B2'                     end_state = zif_prc_process~co_finished ) ).
  ENDMETHOD.


  METHOD zif_prc_process~get_transition_handler.
    r_transition_handler = NEW lcl_transition( ).
  ENDMETHOD.


  METHOD zif_prc_process~get_url_for_processed_object.
    " Recognizable link for the tests of the link exit (ZCL_PRC_PROC_OBJ_LINK)
    r_relative_url = |#PRC_Test-show?Object={ i_processed_object }|.
  ENDMETHOD.

ENDCLASS.
