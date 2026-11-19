"! <p class="shorttext synchronized">PRC Test: Run job in Standard ABAP</p>
"! Run job ZCL_PRC_TEST_NAC_RUN_JOB, whose class, job catalog entry and job template are
"! Standard ABAP: it runs with ABAP-PRC, and the run app (ABAP Cloud) schedules it with the
"! real application job framework - no test double, so the check of the language version
"! by the job framework is part of the test.
CLASS zcl_prc_test_nac_run DEFINITION PUBLIC FINAL CREATE PUBLIC FOR TESTING.
  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_nac_run IMPLEMENTATION.
ENDCLASS.
