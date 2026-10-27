"! Generic transition: behaves as defined in the payload for its start state
CLASS lcl_transition DEFINITION INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition  REDEFINITION.
    METHODS get_success_message REDEFINITION.
    METHODS get_failure_message REDEFINITION.

  PRIVATE SECTION.
    DATA mv_start_state TYPE zif_prc_process=>ty_state.
    DATA ms_behavior    TYPE zcl_prc_test_proc_payload=>ty_behavior.
ENDCLASS.


CLASS lcl_transition IMPLEMENTATION.

  METHOD perform_transition.
    mv_start_state = i_start_state.
    ms_behavior    = zcl_prc_test_proc_payload=>behavior_for( i_payload = c_payload_json
                                                              i_state   = i_start_state ).

    LOOP AT ms_behavior-messages INTO DATA(ls_message).
      MESSAGE ID 'ZPRC_TEST_PROC' TYPE ls_message-type NUMBER '001'
              WITH ls_message-v1 ls_message-v2 ls_message-v3 ls_message-v4
              INTO DATA(lv_dummy) ##NEEDED.
      get_message_handler( )->add_message_from_sy( ).
    ENDLOOP.

    IF ms_behavior-bapi_messages IS NOT INITIAL.
      DATA lt_return TYPE zif_prc_message_handler=>tt_bapiret2.
      LOOP AT ms_behavior-bapi_messages INTO ls_message.
        MESSAGE ID 'ZPRC_TEST_PROC' TYPE ls_message-type NUMBER '001'
                WITH ls_message-v1 ls_message-v2 ls_message-v3 ls_message-v4
                INTO DATA(lv_text).
        APPEND VALUE #( type       = ls_message-type
                        id         = 'ZPRC_TEST_PROC'
                        number     = '001'
                        message    = lv_text
                        message_v1 = ls_message-v1
                        message_v2 = ls_message-v2
                        message_v3 = ls_message-v3
                        message_v4 = ls_message-v4 ) TO lt_return.
      ENDLOOP.
      get_message_handler( )->add_bapi_result( lt_return ).
    ENDIF.

    " Plain texts without message class (not translatable)
    LOOP AT ms_behavior-texts INTO DATA(ls_text).
      get_message_handler( )->add_message_from_text( i_message_text     = ls_text-text
                                                     i_message_severity = ls_text-type ).
    ENDLOOP.

    IF ms_behavior-new_payload IS NOT INITIAL.
      c_payload_json = ms_behavior-new_payload.
    ENDIF.

    IF ms_behavior-fail = abap_true.
      MESSAGE e004(zprc_test_proc) WITH i_start_state INTO lv_dummy.
      get_message_handler( )->add_message_from_sy( ).
    ENDIF.

    " An exception the transition does not handle (programming error)
    IF ms_behavior-raise = abap_true.
      RAISE EXCEPTION NEW cx_sy_zerodivide( ).
    ENDIF.

    r_new_state = COND #( WHEN ms_behavior-next IS NOT INITIAL THEN ms_behavior-next
                          WHEN i_start_state = 'A'             THEN 'B1' ).
  ENDMETHOD.


  METHOD get_success_message.
    MESSAGE s002(zprc_test_proc) WITH mv_start_state INTO DATA(lv_dummy) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.


  METHOD get_failure_message.
    IF ms_behavior-failure_header = abap_true.
      MESSAGE e003(zprc_test_proc) WITH mv_start_state INTO DATA(lv_dummy) ##NEEDED.
      r_message = sy_message( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
