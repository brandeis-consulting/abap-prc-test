"! <p class="shorttext synchronized">PRC Test: Unit tests events of processing</p>
"!
"! Carrier for the unit tests (see local test classes). The tests define which
"! RAP events the processing raises: ZR_PRC_ProcessedObject~zz_objectProcessedTransition
"! per persisted step and ZR_PRC_Run~zz_runChanged once per processed object.
"! Events are captured with CL_RAP_EVENT_TEST_ENVIRONMENT.
CLASS zcl_prc_test_proc_event DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_proc_event IMPLEMENTATION.
ENDCLASS.
