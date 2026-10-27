"! <p class="shorttext synchronized">PRC Test: Unit tests locked processed objects</p>
"!
"! Carrier for the unit tests (see local test classes). A processed object
"! locked by another session must be skipped completely. Separate from
"! ZCL_PRC_TEST_PROCESSING because the test uses a parallel session and a
"! termination here must not affect the other processing tests.
CLASS zcl_prc_test_proc_locking DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_proc_locking IMPLEMENTATION.
ENDCLASS.
