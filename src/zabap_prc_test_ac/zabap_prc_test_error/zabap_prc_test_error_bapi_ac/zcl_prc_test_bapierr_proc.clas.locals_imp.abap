"! Single transition START -> FINISHED: calls the test BAPI with the scenario
"! from the payload and passes its return table to the message handler.
CLASS lcl_start_to_finish DEFINITION INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition  REDEFINITION.
    METHODS get_success_message REDEFINITION.

  PRIVATE SECTION.
    DATA mv_scenario TYPE zcl_prc_test_bapierr_proc=>ty_scenario.
ENDCLASS.


CLASS lcl_start_to_finish IMPLEMENTATION.

  METHOD perform_transition.
    mv_scenario = zcl_prc_test_bapierr_proc=>get_scenario( c_payload_json ).

    DATA(lt_return) = zcl_prc_test_bapierr_wrap=>call_bapi( i_uuid     = i_processed_object_ext_uuid
                                                            i_scenario = mv_scenario ).

    get_message_handler( )->add_bapi_result( CORRESPONDING #( lt_return ) ).
  ENDMETHOD.


  METHOD get_success_message.
    MESSAGE s020(zprc_test_bapierr) WITH mv_scenario i_processed_object_ext_id INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

ENDCLASS.
