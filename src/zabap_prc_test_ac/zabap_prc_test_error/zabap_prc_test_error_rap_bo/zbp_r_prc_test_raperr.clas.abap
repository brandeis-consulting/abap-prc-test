"! <p class="shorttext synchronized">PRC Test: Behavior pool ZR_PRC_Test_RapErr</p>
"!
"! Returns the messages expected by the tests for each scenario:
"! <ul>
"! <li>noError: W + I (no errors)</li>
"! <li>modifyError: FAILED + 2 E + W + I directly in MODIFY</li>
"! <li>checkBeforeSaveError: FAILED + 2 E + W + I in the check_before_save phase</li>
"! <li>lateSaveError: 2 E + W + I as late messages in save_modified</li>
"! </ul>
CLASS zbp_r_prc_test_raperr DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zr_prc_test_raperr.
ENDCLASS.



CLASS zbp_r_prc_test_raperr IMPLEMENTATION.
ENDCLASS.
