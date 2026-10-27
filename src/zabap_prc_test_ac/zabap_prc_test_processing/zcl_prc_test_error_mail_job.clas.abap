"! <p class="shorttext synchronized">PRC Test: Error notification job</p>
"! End-to-end test of ZCL_PRC_ERROR_MAIL_JOB: failed objects with a mail address
"! lead to one notification object per process and address, whose payload holds the
"! prepared mail including the links into the Processing Center.
CLASS zcl_prc_test_error_mail_job DEFINITION PUBLIC FINAL CREATE PUBLIC FOR TESTING.
  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_error_mail_job IMPLEMENTATION.
ENDCLASS.

