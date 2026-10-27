"! The transition does nothing: only the framework is measured
CLASS lcl_nothing DEFINITION FINAL INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition REDEFINITION.
ENDCLASS.

CLASS lcl_nothing IMPLEMENTATION.
  METHOD perform_transition.
    RETURN.
  ENDMETHOD.
ENDCLASS.
