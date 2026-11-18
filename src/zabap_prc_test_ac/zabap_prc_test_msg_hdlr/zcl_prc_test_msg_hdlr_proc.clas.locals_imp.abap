"! Unexpected exception with a T100 key - not the PRC failure signal, so it is
"! caught by the step layer for unexpected errors
CLASS lcx_unexpected DEFINITION INHERITING FROM cx_no_check FINAL.
  PUBLIC SECTION.
    INTERFACES if_t100_dyn_msg.
    METHODS constructor IMPORTING textid   LIKE if_t100_message=>t100key OPTIONAL
                                  previous LIKE previous OPTIONAL.
ENDCLASS.


CLASS lcx_unexpected IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


"! Minimal transition: does nothing and redefines neither the success nor the
"! failure message - so the defaults of the base class apply
CLASS lcl_default_transition DEFINITION INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition REDEFINITION.
ENDCLASS.


CLASS lcl_default_transition IMPLEMENTATION.
  METHOD perform_transition ##NEEDED.
    " nothing to do
  ENDMETHOD.
ENDCLASS.


"! Calls the message handler API in a fixed way per start state
CLASS lcl_transition DEFINITION INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition  REDEFINITION.
    METHODS get_success_message REDEFINITION.
    METHODS get_failure_message REDEFINITION.

  PRIVATE SECTION.
    TYPES ty_state TYPE zif_prc_process=>ty_state.

    " Non-initial FAILED response without any message (failure signal only)
    TYPES: BEGIN OF ty_failed_only,
             failed TYPE abap_bool,
           END OF ty_failed_only.

    DATA mv_start_state TYPE ty_state.

    "! ADD_MESSAGE_FROM_SY with ZPRC_TEST_MSG_HDLR/001
    METHODS via_sy   IMPORTING i_type      TYPE symsgty
                               i_v1        TYPE symsgv
                               i_fail_step TYPE abap_bool DEFAULT abap_true
                     RAISING   zcx_prc_unit_of_work_failed.

    "! ADD_MESSAGE_FROM_TEXT
    METHODS via_text IMPORTING i_type TYPE symsgty
                               i_text TYPE string
                     RAISING   zcx_prc_unit_of_work_failed.

    "! One BAPI return line ZPRC_TEST_MSG_HDLR/001 (for ADD_BAPI_RESULT)
    METHODS bapi_line IMPORTING i_type        TYPE symsgty
                                i_v1          TYPE symsgv
                      RETURNING VALUE(r_line) TYPE bapiret2.

    "! Raises LCX_UNEXPECTED ZPRC_TEST_MSG_HDLR/001 'outer' with the cause 'inner'
    METHODS raise_unexpected_chain.
ENDCLASS.


CLASS lcl_transition IMPLEMENTATION.

  METHOD perform_transition.
    DATA(state) = zcl_prc_test_msg_hdlr_proc=>state.
    DATA(handler) = get_message_handler( ).
    mv_start_state = i_start_state.

    CASE i_start_state.
      " ADD_MESSAGE_FROM_SY
      WHEN state-sy_e.          via_sy( i_type = 'E' i_v1 = 'e' ).
      WHEN state-sy_a.          via_sy( i_type = 'A' i_v1 = 'a' ).
      WHEN state-sy_x.          via_sy( i_type = 'X' i_v1 = 'x' ).
      WHEN state-sy_w.          via_sy( i_type = 'W' i_v1 = 'w' ).

      " ADD_MESSAGE_FROM_TEXT
      WHEN state-text_e.        via_text( i_type = 'E' i_text = `Text e` ).
      WHEN state-text_a.        via_text( i_type = 'A' i_text = `Text a` ).
      WHEN state-text_x.        via_text( i_type = 'X' i_text = `Text x` ).
      WHEN state-text_w.        via_text( i_type = 'W' i_text = `Text w` ).

      " ADD_BAPI_RESULT
      WHEN state-bapi_e.        handler->add_bapi_result( VALUE #( ( bapi_line( i_type = 'E' i_v1 = 'e' ) ) ) ).
      WHEN state-bapi_a.        handler->add_bapi_result( VALUE #( ( bapi_line( i_type = 'A' i_v1 = 'a' ) ) ) ).
      WHEN state-bapi_x.        handler->add_bapi_result( VALUE #( ( bapi_line( i_type = 'X' i_v1 = 'x' ) ) ) ).
      WHEN state-bapi_w.        handler->add_bapi_result( VALUE #( ( bapi_line( i_type = 'W' i_v1 = 'w' ) ) ) ).
      WHEN state-bapi_e_then_w. handler->add_bapi_result( VALUE #( ( bapi_line( i_type = 'E' i_v1 = 'e' ) )
                                                                   ( bapi_line( i_type = 'W' i_v1 = 'w' ) ) ) ).
      WHEN state-bapi_e1_e2.    handler->add_bapi_result( VALUE #( ( bapi_line( i_type = 'E' i_v1 = 'e1' ) )
                                                                   ( bapi_line( i_type = 'E' i_v1 = 'e2' ) ) ) ).

      " Headers
      WHEN state-failure_header.
        via_sy( i_type = 'W' i_v1 = 'w' ).
        via_sy( i_type = 'E' i_v1 = 'e' ).
      WHEN state-hdr_warning_before_error.
        handler->add_bapi_result( VALUE #( ( bapi_line( i_type = 'W' i_v1 = 'w' ) )
                                           ( bapi_line( i_type = 'E' i_v1 = 'e' ) ) ) ).
      WHEN state-hdr_all_severities.
        handler->add_bapi_result( VALUE #( ( bapi_line( i_type = 'I' i_v1 = 'i' ) )
                                           ( bapi_line( i_type = 'S' i_v1 = 's' ) )
                                           ( bapi_line( i_type = 'W' i_v1 = 'w' ) )
                                           ( bapi_line( i_type = 'E' i_v1 = 'e' ) ) ) ).
      WHEN state-hdr_abort_after_error.
        handler->add_bapi_result( VALUE #( ( bapi_line( i_type = 'E' i_v1 = 'e' ) )
                                           ( bapi_line( i_type = 'A' i_v1 = 'a' ) ) ) ).
      WHEN state-hdr_set_failure_header.
        " The failure header is declared by GET_FAILURE_MESSAGE of this transition
        via_sy( i_type = 'W' i_v1 = 'w' ).
        via_sy( i_type = 'E' i_v1 = 'e' ).
      WHEN state-hdr_failed_without_error.
        via_sy( i_type = 'W' i_v1 = 'w' ).
        via_sy( i_type = 'I' i_v1 = 'i' ).
        handler->add_eml_modify_result( i_failed = VALUE ty_failed_only( failed = abap_true ) ).

      " Success message of another type (see GET_SUCCESS_MESSAGE)
      WHEN state-success_type_i OR state-success_type_e.
        via_sy( i_type = 'W' i_v1 = 'w' ).

      " Unexpected errors
      WHEN state-unexpected_t100_chain.
        raise_unexpected_chain( ).

      " Findings (I_FAIL_STEP = ABAP_FALSE): through SY and a BAPI result, back to the start state.
      " GET_FAILURE_MESSAGE declares 003 for FINDINGS - it must not become the header.
      WHEN state-findings.
        via_sy( i_type = 'W' i_v1 = 'w' ).
        via_sy( i_type = 'E' i_v1 = 'e1' i_fail_step = abap_false ).
        handler->add_bapi_result( i_bapiret   = VALUE #( ( bapi_line( i_type = 'E' i_v1 = 'e2' ) ) )
                                  i_fail_step = abap_false ).
        r_new_state = i_start_state.
      " Findings, but the transition goes on to FINISHED: program error 024
      WHEN state-findings_wrong_end.
        via_sy( i_type = 'E' i_v1 = 'e' i_fail_step = abap_false ).
      " A finding, then a real error: the step fails as usual, the finding is kept
      WHEN state-findings_then_failure.
        via_sy( i_type = 'E' i_v1 = 'e1' i_fail_step = abap_false ).
        via_sy( i_type = 'E' i_v1 = 'e2' ).
    ENDCASE.
  ENDMETHOD.


  METHOD get_success_message.
    CASE mv_start_state.
      WHEN zcl_prc_test_msg_hdlr_proc=>state-success_type_i.
        " Kept: I is a valid type of a success message
        MESSAGE i002(zprc_test_msg_hdlr) WITH mv_start_state INTO DATA(lv_dummy) ##NEEDED.
      WHEN zcl_prc_test_msg_hdlr_proc=>state-success_type_e.
        " Program error: a success message of type E fails the step
        MESSAGE e002(zprc_test_msg_hdlr) WITH mv_start_state INTO lv_dummy.
      WHEN OTHERS.
        MESSAGE s002(zprc_test_msg_hdlr) WITH mv_start_state INTO lv_dummy.
    ENDCASE.
    r_message = sy_message( ).
  ENDMETHOD.


  METHOD get_failure_message.
    CASE mv_start_state.
      WHEN zcl_prc_test_msg_hdlr_proc=>state-failure_header
        OR zcl_prc_test_msg_hdlr_proc=>state-findings.
        MESSAGE e003(zprc_test_msg_hdlr) WITH mv_start_state INTO DATA(lv_dummy) ##NEEDED.
        r_message = sy_message( ).
      WHEN zcl_prc_test_msg_hdlr_proc=>state-hdr_set_failure_header.
        " The declared failure header of the transition
        MESSAGE e004(zprc_test_msg_hdlr) WITH 'f' INTO lv_dummy.
        r_message = sy_message( ).
    ENDCASE.
  ENDMETHOD.


  METHOD via_sy.
    MESSAGE ID 'ZPRC_TEST_MSG_HDLR' TYPE i_type NUMBER '001' WITH i_v1 INTO DATA(lv_dummy) ##NEEDED.
    get_message_handler( )->add_message_from_sy( i_fail_step ).
  ENDMETHOD.


  METHOD via_text.
    get_message_handler( )->add_message_from_text( i_message_text     = i_text
                                                   i_message_severity = i_type ).
  ENDMETHOD.


  METHOD bapi_line.
    MESSAGE ID 'ZPRC_TEST_MSG_HDLR' TYPE i_type NUMBER '001' WITH i_v1 INTO DATA(lv_text).
    r_line = VALUE #( type = i_type id = 'ZPRC_TEST_MSG_HDLR' number = '001' message_v1 = i_v1 message = lv_text ).
  ENDMETHOD.


  METHOD raise_unexpected_chain.
    TRY.
        RAISE EXCEPTION TYPE lcx_unexpected MESSAGE ID 'ZPRC_TEST_MSG_HDLR' TYPE 'E' NUMBER '001' WITH 'inner'.
      CATCH lcx_unexpected INTO DATA(inner).
        RAISE EXCEPTION TYPE lcx_unexpected MESSAGE ID 'ZPRC_TEST_MSG_HDLR' TYPE 'E' NUMBER '001' WITH 'outer'
              EXPORTING previous = inner.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
