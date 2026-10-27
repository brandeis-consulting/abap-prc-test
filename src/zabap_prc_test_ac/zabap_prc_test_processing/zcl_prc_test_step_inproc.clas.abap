"! <p class="shorttext synchronized">PRC Test: Isolated step in the test session</p>
"!
"! The engine runs every step in a session of its own (CL_ABAP_PARALLEL). ABAP Unit
"! measures only the test session, so the layers 7-Lock to 1-Core, the transition
"! handlers, the message handler and the mapper show no coverage, although the
"! integration tests (ZCL_PRC_TEST_PROCESSING, ZCL_PRC_TEST_RAPERR, ...) run them.
"!
"! These tests execute the task of the isolation layer directly in the test session
"! (IF_ABAP_PARALLEL~DO without CL_ABAP_PARALLEL): same code, same database, same
"! commits - but measured. Short dumps cannot be tested this way; they stay with the
"! tests that use the real isolation.
CLASS zcl_prc_test_step_inproc DEFINITION PUBLIC FINAL CREATE PUBLIC FOR TESTING.
  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_step_inproc IMPLEMENTATION.
ENDCLASS.

