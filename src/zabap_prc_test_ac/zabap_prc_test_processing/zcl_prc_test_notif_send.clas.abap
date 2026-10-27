"! <p class="shorttext synchronized">PRC Test: Send step of notifications</p>
"! The send step (ZCL_PRC_NOTIF_SEND_STEP) and the mail channel run in the isolated
"! step session; here the isolation task is executed directly in the test session.
"! Without SMTP configuration the send fails with a readable error, with it succeeds.
CLASS zcl_prc_test_notif_send DEFINITION PUBLIC FINAL CREATE PUBLIC FOR TESTING.
  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_notif_send IMPLEMENTATION.
ENDCLASS.

