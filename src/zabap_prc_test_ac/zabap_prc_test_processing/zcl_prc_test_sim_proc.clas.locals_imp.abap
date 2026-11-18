CLASS lcl_transition DEFINITION INHERITING FROM zcl_prc_transition_handlr_base FINAL.
  PROTECTED SECTION.
    METHODS perform_transition  REDEFINITION.
    METHODS get_success_message REDEFINITION.
ENDCLASS.


CLASS lcl_transition IMPLEMENTATION.

  METHOD perform_transition.
    " The business change a simulation has to undo
    MODIFY zprc_test_bgpf FROM @( VALUE #( id = zcl_prc_test_sim_proc=>co_marker_id ) ).

    IF i_processed_object_ext_id CP |{ zcl_prc_test_sim_proc=>co_prefix_error }*|.
      " Forced error in &1
      MESSAGE e004(zprc_test_proc) WITH i_processed_object_ext_id INTO DATA(error) ##NEEDED.
      get_message_handler( )->add_message_from_sy( ).
    ENDIF.

    IF i_processed_object_ext_id CP |{ zcl_prc_test_sim_proc=>co_prefix_finding }*|.
      MESSAGE e004(zprc_test_proc) WITH i_processed_object_ext_id INTO DATA(finding) ##NEEDED.
      get_message_handler( )->add_message_from_sy( i_fail_step = abap_false ).
      r_new_state = zif_prc_process=>co_start.
      RETURN.
    ENDIF.

    r_new_state = zif_prc_process=>co_finished.
  ENDMETHOD.


  METHOD get_success_message.
    " Transition from &1 successful
    MESSAGE s002(zprc_test_proc) WITH zif_prc_process=>co_start INTO DATA(success) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

ENDCLASS.
