"! <p class="shorttext synchronized">PRC Test: Abstract process class</p>
"! Implements ZIF_PRC_PROCESS but cannot be instantiated: RTTI describes it, CREATE
"! OBJECT fails. Used by the tests of ZCL_PRC_PROCESS_LOADER.
CLASS zcl_prc_test_abstract_proc DEFINITION PUBLIC ABSTRACT CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_prc_process.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_abstract_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE #( ( start_state = zif_prc_process~co_start end_state = zif_prc_process~co_finished ) ).
  ENDMETHOD.

  METHOD zif_prc_process~get_transition_handler.
    CLEAR r_transition_handler.
  ENDMETHOD.

  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.

ENDCLASS.

