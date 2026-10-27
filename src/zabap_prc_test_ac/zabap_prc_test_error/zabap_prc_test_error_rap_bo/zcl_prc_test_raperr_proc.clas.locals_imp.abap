"! Single transition START -> FINISHED: reads the scenario from the payload
"! and calls the matching action of the test BO. All messages of the BO are
"! passed to the message handler via ADD_EML_MODIFY_RESULT; the check_before_save
"! phase is checked afterwards by the base class via SIMULATE_SAVE.
CLASS lcl_start_to_finish DEFINITION INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition  REDEFINITION.
    METHODS get_success_message REDEFINITION.
    METHODS get_failure_message REDEFINITION.

  PRIVATE SECTION.
    DATA mv_scenario TYPE zcl_prc_test_raperr_proc=>ty_scenario.
ENDCLASS.


CLASS lcl_start_to_finish IMPLEMENTATION.

  METHOD perform_transition.
    DATA lt_failed   TYPE RESPONSE FOR FAILED EARLY zr_prc_test_raperr.
    DATA lt_reported TYPE RESPONSE FOR REPORTED EARLY zr_prc_test_raperr.

    mv_scenario = zcl_prc_test_raperr_proc=>get_scenario( c_payload_json ).
    DATA(lv_uuid) = i_processed_object_ext_uuid.

    CASE mv_scenario.
      WHEN zcl_prc_test_raperr_proc=>scenario-no_error
        OR zcl_prc_test_raperr_proc=>scenario-modify_lock_error.
        " modify_lock_error: the instance is locked by the test session,
        " the error comes from the RAP framework itself (standard behavior)
        MODIFY ENTITIES OF zr_prc_test_raperr
               ENTITY RapErr
               EXECUTE noError FROM VALUE #( ( UUID = lv_uuid ) )
               FAILED lt_failed
               REPORTED lt_reported.

      WHEN zcl_prc_test_raperr_proc=>scenario-modify_error.
        MODIFY ENTITIES OF zr_prc_test_raperr
               ENTITY RapErr
               EXECUTE modifyError FROM VALUE #( ( UUID = lv_uuid ) )
               FAILED lt_failed
               REPORTED lt_reported.

      WHEN zcl_prc_test_raperr_proc=>scenario-check_before_save_error.
        MODIFY ENTITIES OF zr_prc_test_raperr
               ENTITY RapErr
               EXECUTE checkBeforeSaveError FROM VALUE #( ( UUID = lv_uuid ) )
               FAILED lt_failed
               REPORTED lt_reported.

      WHEN zcl_prc_test_raperr_proc=>scenario-late_save_messages.
        MODIFY ENTITIES OF zr_prc_test_raperr
               ENTITY RapErr
               EXECUTE lateSaveMessages FROM VALUE #( ( UUID = lv_uuid ) )
               FAILED lt_failed
               REPORTED lt_reported.

      WHEN zcl_prc_test_raperr_proc=>scenario-late_save_failed.
        MODIFY ENTITIES OF zr_prc_test_raperr
               ENTITY RapErr
               EXECUTE lateSaveFailed FROM VALUE #( ( UUID = lv_uuid ) )
               FAILED lt_failed
               REPORTED lt_reported.

      WHEN OTHERS.
        MESSAGE e017(zprc_test_raperr) WITH mv_scenario INTO DATA(lv_dummy_message) ##NEEDED.
        get_message_handler( )->add_message_from_sy( ).
    ENDCASE.

    get_message_handler( )->add_eml_modify_result( i_failed   = lt_failed
                                                   i_reported = lt_reported ).
  ENDMETHOD.


  METHOD get_success_message.
    MESSAGE s015(zprc_test_raperr) WITH mv_scenario i_processed_object_ext_id INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.


  METHOD get_failure_message.
    get_processed_object( IMPORTING e_processed_object_ext_id = DATA(lv_ext_id) ).
    MESSAGE e016(zprc_test_raperr) WITH mv_scenario lv_ext_id INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

ENDCLASS.
