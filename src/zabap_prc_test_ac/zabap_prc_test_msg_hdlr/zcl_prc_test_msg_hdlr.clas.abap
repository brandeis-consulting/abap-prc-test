"! <p class="shorttext synchronized">PRC Test: Unit tests message handler API</p>
"!
"! Carrier for the unit tests (see local test classes). The tests define the
"! expected behavior of the message handler API end-to-end through a real
"! processing run: which messages fail a transition, how they are stored and
"! which message becomes the step header.
"!
"! Rules: A, E and X are treated identically - they fail the transition (unless
"! I_FAIL_ON_ERROR_MESSAGE = abap_false) and are stored as E (severity code 1).
"! Step header: success message, own failure message or the first error.
"!
"! Each test starts in one state of ZCL_PRC_TEST_MSG_HDLR_PROC; the transition
"! of that state calls the API in exactly one way.
CLASS zcl_prc_test_msg_hdlr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_msg_hdlr IMPLEMENTATION.
ENDCLASS.
