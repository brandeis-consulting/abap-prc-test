"! <p class="shorttext synchronized">PRC Test: Simulation runs</p>
"!
"! Carrier for the unit tests of simulation runs (see local test classes): the
"! rule (ZCL_PRC_SIMULATION), the engine (rollback, FINISHED without retry,
"! process not allowed), the run job (abort before any object) and the run
"! notification ([SIMULATION], abort reason).
CLASS zcl_prc_test_simulation DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_simulation IMPLEMENTATION.
ENDCLASS.
