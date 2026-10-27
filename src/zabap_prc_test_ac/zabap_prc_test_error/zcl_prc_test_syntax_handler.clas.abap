"! <p class="shorttext synchronized">PRC Test: Transition handler for syntax error</p>
"!
"! Global handler of process PRC_TEST_SYNTAX_ERROR (START -> FINISHED). It uses the
"! data element ZPRC_TEST_SYNTAX_HANDLER: deleting it puts a syntax error into this
"! class only. The handler is loaded in the step session, the process class (also
"! loaded in the main session) stays intact. Manual test case 1, see
"! ZCL_PRC_TEST_SYNTAX_RUN.
CLASS zcl_prc_test_syntax_handler DEFINITION
  PUBLIC
  INHERITING FROM zcl_prc_transition_handlr_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS perform_transition REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_syntax_handler IMPLEMENTATION.

  METHOD perform_transition.
    " Uses the data element of test case 1 - nothing else to do
    DATA lv_marker TYPE zprc_test_syntax_handler.
    lv_marker = 'HANDLER'.
    CLEAR lv_marker.
  ENDMETHOD.

ENDCLASS.

