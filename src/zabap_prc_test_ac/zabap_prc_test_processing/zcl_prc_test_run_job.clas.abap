"! <p class="shorttext synchronized">PRC Test: Unit tests run job</p>
"!
"! Carrier for the unit tests (see local test classes). A run job implements
"! SELECT and GET_PROCESS only; ZCL_PRC_RUN_JOB creates the run, sets the total
"! number, creates the objects with the run and processes them.
CLASS zcl_prc_test_run_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_run_job IMPLEMENTATION.
ENDCLASS.
