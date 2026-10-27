"! <p class="shorttext synchronized">PRC Test: Unit tests application log of processing</p>
"!
"! Carrier for the unit tests (see local test classes). The tests define what
"! the processing writes into the application log: every message of every
"! written step, with a prefix, into the log of the run (external ID = run UUID).
CLASS zcl_prc_test_proc_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_proc_log IMPLEMENTATION.
ENDCLASS.
