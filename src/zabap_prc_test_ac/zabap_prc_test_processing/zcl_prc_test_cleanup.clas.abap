"! <p class="shorttext synchronized">PRC Test: Cleanup job (data retention)</p>
"! Rules of ZCL_PRC_CLEANUP_JOB, always restricted to the test process so no other
"! data of the system is touched.
CLASS zcl_prc_test_cleanup DEFINITION PUBLIC FINAL CREATE PUBLIC FOR TESTING.
  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_cleanup IMPLEMENTATION.
ENDCLASS.

