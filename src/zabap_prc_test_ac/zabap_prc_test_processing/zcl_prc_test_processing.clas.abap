"! <p class="shorttext synchronized">PRC Test: Unit tests processing behavior</p>
"!
"! Carrier for the unit tests (see local test classes). The tests define the
"! expected processing behavior of the Processing Center: selection, queues,
"! transitions, payload, retry, messages, attributes and locks.
"!
"! Each test shows the complete given state, triggers the processing and
"! compares the complete actual state (objects, steps, messages) with one
"! ASSERT_EQUALS. Mechanics: ZCL_PRC_TEST_PROC_FIXTURE, test process:
"! ZCL_PRC_TEST_PROC_PROCESS (behavior from the payload, see
"! ZCL_PRC_TEST_PROC_PAYLOAD).
CLASS zcl_prc_test_processing DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_processing IMPLEMENTATION.
ENDCLASS.
