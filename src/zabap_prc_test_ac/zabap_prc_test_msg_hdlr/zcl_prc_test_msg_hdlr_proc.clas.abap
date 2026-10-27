"! <p class="shorttext synchronized">PRC Test: Process calling the message handler API</p>
"!
"! Every state has exactly one transition to FINISHED. The transition calls the
"! message handler API in a fixed way per start state (see lcl_transition), so
"! each test starts in one state and checks exactly one way of using the API.
CLASS zcl_prc_test_msg_hdlr_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prc_process.

    CONSTANTS co_process_name TYPE zprc_process_name       VALUE 'PRC_TEST_MSG_HDLR'.
    CONSTANTS co_class_name   TYPE zprc_process_impl_class VALUE 'ZCL_PRC_TEST_MSG_HDLR_PROC'.

    CONSTANTS: BEGIN OF state,
                 sy_e                     TYPE zprc_state VALUE 'SY_E',
                 sy_a                     TYPE zprc_state VALUE 'SY_A',
                 sy_x                     TYPE zprc_state VALUE 'SY_X',
                 sy_w                     TYPE zprc_state VALUE 'SY_W',
                 sy_e_nofail              TYPE zprc_state VALUE 'SY_E_NOFAIL',
                 sy_a_nofail              TYPE zprc_state VALUE 'SY_A_NOFAIL',
                 sy_x_nofail              TYPE zprc_state VALUE 'SY_X_NOFAIL',
                 text_e                   TYPE zprc_state VALUE 'TEXT_E',
                 text_a                   TYPE zprc_state VALUE 'TEXT_A',
                 text_x                   TYPE zprc_state VALUE 'TEXT_X',
                 text_w                   TYPE zprc_state VALUE 'TEXT_W',
                 text_e_nofail            TYPE zprc_state VALUE 'TEXT_E_NOFAIL',
                 text_a_nofail            TYPE zprc_state VALUE 'TEXT_A_NOFAIL',
                 text_x_nofail            TYPE zprc_state VALUE 'TEXT_X_NOFAIL',
                 bapi_e                   TYPE zprc_state VALUE 'BAPI_E',
                 bapi_a                   TYPE zprc_state VALUE 'BAPI_A',
                 bapi_x                   TYPE zprc_state VALUE 'BAPI_X',
                 bapi_w                   TYPE zprc_state VALUE 'BAPI_W',
                 bapi_e_nofail            TYPE zprc_state VALUE 'BAPI_E_NOFAIL',
                 bapi_a_nofail            TYPE zprc_state VALUE 'BAPI_A_NOFAIL',
                 bapi_x_nofail            TYPE zprc_state VALUE 'BAPI_X_NOFAIL',
                 bapi_e_then_w            TYPE zprc_state VALUE 'BAPI_E_THEN_W',
                 bapi_e1_e2               TYPE zprc_state VALUE 'BAPI_E1_E2',
                 failure_header           TYPE zprc_state VALUE 'FAILURE_HEADER',
                 hdr_warning_before_error TYPE zprc_state VALUE 'HDR_WARNING_BEFORE_ERROR',
                 hdr_all_severities       TYPE zprc_state VALUE 'HDR_ALL_SEVERITIES',
                 hdr_abort_after_error    TYPE zprc_state VALUE 'HDR_ABORT_AFTER_ERROR',
                 hdr_set_failure_header   TYPE zprc_state VALUE 'HDR_SET_FAILURE_HEADER',
                 hdr_failed_without_error TYPE zprc_state VALUE 'HDR_FAILED_WITHOUT_ERROR',
                 unexpected_t100_chain    TYPE zprc_state VALUE 'UNEXPECTED_T100_CHAIN',
                 default_success          TYPE zprc_state VALUE 'DEFAULT_SUCCESS',
               END OF state.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_msg_hdlr_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    DATA(lo_states) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( state ) ).
    LOOP AT lo_states->components INTO DATA(ls_component).
      ASSIGN COMPONENT ls_component-name OF STRUCTURE state TO FIELD-SYMBOL(<lv_state>).
      INSERT VALUE #( start_state = <lv_state> end_state = zif_prc_process~co_finished ) INTO TABLE r_transitions.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_prc_process~get_transition_handler.
    r_transition_handler = COND #( WHEN i_start_state = state-default_success
                                   THEN NEW lcl_default_transition( )
                                   ELSE NEW lcl_transition( ) ).
  ENDMETHOD.


  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.

ENDCLASS.
