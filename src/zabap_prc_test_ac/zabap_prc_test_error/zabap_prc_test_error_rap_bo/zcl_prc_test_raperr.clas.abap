"! <p class="shorttext synchronized">PRC Test: Unit tests for RAP BO error scenarios</p>
"!
"! Carrier for the unit tests (see local test classes).
"! The tests define the target behavior of the Processing Center for
"! errors coming from a RAP BO: state after the run and complete transfer
"! of all BO messages into the message persistence.
"!
"! There is no teardown on purpose: the processed objects and messages stay
"! in the Processing Center after the run. Each test only deletes the results
"! of its own scenario from a previous run in its setup.
CLASS zcl_prc_test_raperr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_raperr IMPLEMENTATION.
ENDCLASS.
