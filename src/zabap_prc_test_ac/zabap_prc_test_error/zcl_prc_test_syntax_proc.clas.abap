"! <p class="shorttext synchronized">PRC Test: Process for syntax error</p>
"!
"! Minimal process START -> FINISHED for the manual syntax error tests.
"! Uses the data element ZPRC_TEST_SYNTAX_PROCESS: deleting it puts a syntax error
"! into the process class (test case 2). The handler is created dynamically, so a
"! syntax error in the handler (test case 1) does not reach this class.
CLASS zcl_prc_test_syntax_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prc_process.
  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS co_handler_class TYPE string VALUE `ZCL_PRC_TEST_SYNTAX_HANDLER`.
ENDCLASS.



CLASS zcl_prc_test_syntax_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    " Uses the data element of test case 2
    DATA lv_marker TYPE zprc_test_syntax_process.
    lv_marker = 'PROCESS'.
    CLEAR lv_marker.
    r_transitions = VALUE #( ( start_state = zif_prc_process~co_start
                               end_state   = zif_prc_process~co_finished ) ).
  ENDMETHOD.


  METHOD zif_prc_process~get_transition_handler.
    IF i_start_state = zif_prc_process~co_start.
      " Dynamic on purpose: no static dependency on the handler class
      CREATE OBJECT r_transition_handler TYPE (co_handler_class).
    ENDIF.
  ENDMETHOD.


  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.

ENDCLASS.

