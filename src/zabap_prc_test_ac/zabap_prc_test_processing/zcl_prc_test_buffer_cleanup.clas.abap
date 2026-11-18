"! <p class="shorttext synchronized">PRC Test: Cleanup of BO buffers after rollback</p>
"!
"! Carrier for the unit tests (see local test classes). Several BOs remember in a
"! static table what has to be done in the save (resume via bgPF, changed events).
"! The tests define that such entries do not survive a ROLLBACK ENTITIES: a later
"! save in the same session must only act on the instances of its own LUW.
CLASS zcl_prc_test_buffer_cleanup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_buffer_cleanup IMPLEMENTATION.
ENDCLASS.
