"! Behavior message double: T100 based or free text, any severity
CLASS lcx_behv_message DEFINITION INHERITING FROM cx_no_check FINAL.
  PUBLIC SECTION.
    INTERFACES if_abap_behv_message.
    METHODS constructor IMPORTING i_severity TYPE if_abap_behv_message=>t_severity
                                  i_t100key  TYPE scx_t100key OPTIONAL
                                  i_v1       TYPE symsgv OPTIONAL
                                  i_text     TYPE string OPTIONAL.
    METHODS if_message~get_text REDEFINITION.
  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.

CLASS lcx_behv_message IMPLEMENTATION.
  METHOD constructor.
    super->constructor( ).
    if_abap_behv_message~m_severity = i_severity.
    if_t100_message~t100key         = i_t100key.
    if_t100_dyn_msg~msgv1           = i_v1.
    mv_text                         = i_text.
  ENDMETHOD.

  METHOD if_message~get_text.
    result = mv_text.
  ENDMETHOD.
ENDCLASS.


"! ZCL_PRC_MESSAGE_MAPPER: REPORTED/FAILED of MODIFY ENTITIES (BO specific structure)
"! and of the dynamic form (ABP_BEHV_RESPONSE_TAB), severities, free texts, BAPI texts.
CLASS ltc_mapper DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA reported TYPE RESPONSE FOR REPORTED EARLY zr_prc_runtp.
    DATA failed   TYPE RESPONSE FOR FAILED EARLY zr_prc_runtp.

    METHODS setup.
    METHODS reported_structure        FOR TESTING.
    METHODS reported_response_tab     FOR TESTING.
    METHODS free_text_becomes_sy_499  FOR TESTING.
    METHODS severities                FOR TESTING.
    METHODS failed_structure          FOR TESTING.
    METHODS failed_response_tab       FOR TESTING.
    METHODS bapiret_without_id        FOR TESTING.

    "! The two messages of SETUP, converted
    METHODS assert_setup_messages IMPORTING i_messages TYPE zcl_prc_message_mapper=>tt_messages.
ENDCLASS.


CLASS ltc_mapper IMPLEMENTATION.

  METHOD setup.
    " One T100 error and one free text warning, as an EML statement could report them
    reported-run = VALUE #(
        ( %cid = 'A' %msg = NEW lcx_behv_message( i_severity = if_abap_behv_message=>severity-error
                                                  i_t100key  = VALUE #( msgid = 'ZPRC_RUN' msgno = '010' )
                                                  i_v1       = 'TEMPLATE' ) )
        ( %cid = 'B' %msg = NEW lcx_behv_message( i_severity = if_abap_behv_message=>severity-warning
                                                  i_text     = `Free text from the BO` ) )
        " A row without message (e.g. a state message slot) is skipped
        ( %cid = 'C' ) ).
  ENDMETHOD.


  METHOD reported_structure.
    assert_setup_messages( zcl_prc_message_mapper=>from_reported( reported ) ).
  ENDMETHOD.


  METHOD reported_response_tab.
    " Shape of the dynamic COMMIT ENTITIES: entry tables behind data references
    " (sorted by root and entity name); an unbound entry is skipped
    DATA(responses) = VALUE abp_behv_response_tab(
        ( root_name = 'ZR_PRC_RUNTP' entity_name = 'RUN'       entries = REF #( reported-run ) )
        ( root_name = 'ZR_PRC_RUNTP' entity_name = 'PARAMETER' ) ).
    assert_setup_messages( zcl_prc_message_mapper=>from_reported( responses ) ).
  ENDMETHOD.


  METHOD free_text_becomes_sy_499.
    DATA(message) = zcl_prc_message_mapper=>from_text( text  = `Short text`
                                                       msgty = 'I' ).
    cl_abap_unit_assert=>assert_equals( act = message-msgid exp = 'SY' ).
    cl_abap_unit_assert=>assert_equals( act = message-msgno exp = '499' ).
    cl_abap_unit_assert=>assert_equals( act = message-msgty exp = 'I' ).
    cl_abap_unit_assert=>assert_equals( act = message-msgv1 exp = 'Short text' ).
  ENDMETHOD.


  METHOD severities.
    reported-run = VALUE #(
        ( %cid = 'S' %msg = NEW lcx_behv_message( i_severity = if_abap_behv_message=>severity-success
                                                  i_t100key  = VALUE #( msgid = 'ZPRC_RUN' msgno = '001' ) ) )
        ( %cid = 'I' %msg = NEW lcx_behv_message( i_severity = if_abap_behv_message=>severity-information
                                                  i_t100key  = VALUE #( msgid = 'ZPRC_RUN' msgno = '001' ) ) )
        ( %cid = 'N' %msg = NEW lcx_behv_message( i_severity = if_abap_behv_message=>severity-none
                                                  i_t100key  = VALUE #( msgid = 'ZPRC_RUN' msgno = '001' ) ) ) ).

    DATA(messages) = zcl_prc_message_mapper=>from_reported( reported ).

    cl_abap_unit_assert=>assert_equals( act = lines( messages ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-msgty exp = 'S' ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 2 ]-msgty exp = 'I' ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 3 ]-msgty exp = 'I' msg = 'Unknown severity maps to I' ).
  ENDMETHOD.


  METHOD failed_structure.
    cl_abap_unit_assert=>assert_false( zcl_prc_message_mapper=>is_failed( failed ) ).
    failed-run = VALUE #( ( %cid = 'A' ) ).
    cl_abap_unit_assert=>assert_true( zcl_prc_message_mapper=>is_failed( failed ) ).
  ENDMETHOD.


  METHOD failed_response_tab.
    DATA(responses) = VALUE abp_behv_response_tab(
        ( root_name = 'ZR_PRC_RUNTP' entity_name = 'RUN'       entries = REF #( failed-run ) )
        ( root_name = 'ZR_PRC_RUNTP' entity_name = 'PARAMETER' ) ).
    cl_abap_unit_assert=>assert_false( act = zcl_prc_message_mapper=>is_failed( responses )
                                       msg = 'Empty entry tables and unbound entries' ).

    failed-run = VALUE #( ( %cid = 'A' ) ).
    cl_abap_unit_assert=>assert_true( zcl_prc_message_mapper=>is_failed( responses ) ).
  ENDMETHOD.


  METHOD bapiret_without_id.
    DATA(messages) = zcl_prc_message_mapper=>from_bapiret(
        VALUE #( ( type = 'E' message = 'Text of a BAPI without message class' )
                 ( type = 'S' id = 'ZPRC_RUN' number = '001' message_v1 = 'V1' ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( messages ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-msgid exp = 'SY' msg = 'Text only: SY 499' ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-msgty exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 2 ]-msgid exp = 'ZPRC_RUN' ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 2 ]-msgv1 exp = 'V1' ).
  ENDMETHOD.


  METHOD assert_setup_messages.
    cl_abap_unit_assert=>assert_equals( act = lines( i_messages ) exp = 2 msg = 'Rows without %MSG are skipped' ).

    cl_abap_unit_assert=>assert_equals( act = i_messages[ 1 ]-msgty exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = i_messages[ 1 ]-msgid exp = 'ZPRC_RUN' ).
    cl_abap_unit_assert=>assert_equals( act = i_messages[ 1 ]-msgno exp = '010' ).
    cl_abap_unit_assert=>assert_equals( act = i_messages[ 1 ]-msgv1 exp = 'TEMPLATE' ).

    cl_abap_unit_assert=>assert_equals( act = i_messages[ 2 ]-msgty exp = 'W' ).
    cl_abap_unit_assert=>assert_equals( act = i_messages[ 2 ]-msgid exp = 'SY' msg = 'Free text: SY 499' ).
    cl_abap_unit_assert=>assert_equals( act = i_messages[ 2 ]-msgv1 exp = 'Free text from the BO' ).
  ENDMETHOD.

ENDCLASS.


"! Message handler: EML results and plain texts
CLASS ltc_handler DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA handler TYPE REF TO zif_prc_message_handler.

    METHODS setup.
    METHODS eml_failed_fails_step         FOR TESTING.
    METHODS eml_error_without_failed      FOR TESTING.
    METHODS eml_error_fails_if_requested  FOR TESTING.
    METHODS text_error_fails_step         FOR TESTING.
    METHODS text_warning_is_collected     FOR TESTING.
ENDCLASS.


CLASS ltc_handler IMPLEMENTATION.

  METHOD setup.
    handler = zcl_prc_message_handler=>create_message_handler( ).
  ENDMETHOD.


  METHOD eml_failed_fails_step.
    DATA failed TYPE RESPONSE FOR FAILED EARLY zr_prc_runtp.
    failed-run = VALUE #( ( %cid = 'A' ) ).
    TRY.
        handler->add_eml_modify_result( i_failed = failed ).
        cl_abap_unit_assert=>fail( msg = 'FAILED must fail the step' ).
      CATCH zcx_prc_unit_of_work_failed ##NO_HANDLER.
    ENDTRY.
    cl_abap_unit_assert=>assert_true( handler->has_errors( ) ).
  ENDMETHOD.


  METHOD eml_error_without_failed.
    " Default: an E message without FAILED (state message, other instance) is only collected
    DATA reported TYPE RESPONSE FOR REPORTED EARLY zr_prc_runtp.
    DATA failed   TYPE RESPONSE FOR FAILED EARLY zr_prc_runtp.
    reported-run = VALUE #( ( %cid = 'A' %msg = NEW lcx_behv_message( i_severity = if_abap_behv_message=>severity-error
                                                                     i_t100key  = VALUE #( msgid = 'ZPRC_RUN' msgno = '010' ) ) ) ).
    TRY.
        handler->add_eml_modify_result( i_failed   = failed
                                        i_reported = reported ).
      CATCH zcx_prc_unit_of_work_failed.
        cl_abap_unit_assert=>fail( msg = 'No FAILED: the step goes on' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_false( handler->has_errors( ) ).
    DATA(messages) = handler->get_messages( ).
    cl_abap_unit_assert=>assert_equals( act = lines( messages ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-msgno exp = '010' ).
  ENDMETHOD.


  METHOD eml_error_fails_if_requested.
    DATA reported TYPE RESPONSE FOR REPORTED EARLY zr_prc_runtp.
    reported-run = VALUE #( ( %cid = 'A' %msg = NEW lcx_behv_message( i_severity = if_abap_behv_message=>severity-error
                                                                     i_t100key  = VALUE #( msgid = 'ZPRC_RUN' msgno = '010' ) ) ) ).
    TRY.
        handler->add_eml_modify_result( i_reported              = reported
                                        i_fail_on_error_message = abap_true ).
        cl_abap_unit_assert=>fail( msg = 'E message must fail the step when requested' ).
      CATCH zcx_prc_unit_of_work_failed ##NO_HANDLER.
    ENDTRY.
    cl_abap_unit_assert=>assert_true( handler->has_errors( ) ).
  ENDMETHOD.


  METHOD text_error_fails_step.
    TRY.
        handler->add_message_from_text( i_message_text     = `Something went wrong`
                                        i_message_severity = 'E' ).
        cl_abap_unit_assert=>fail( msg = 'Error text must fail the step' ).
      CATCH zcx_prc_unit_of_work_failed ##NO_HANDLER.
    ENDTRY.
    cl_abap_unit_assert=>assert_true( handler->has_errors( ) ).
    DATA(header) = handler->get_header( ).
    cl_abap_unit_assert=>assert_equals( act = header-msgid exp = 'SY' ).
    cl_abap_unit_assert=>assert_equals( act = header-msgno exp = '499' ).
  ENDMETHOD.


  METHOD text_warning_is_collected.
    TRY.
        handler->add_message_from_text( i_message_text     = `Just a hint`
                                        i_message_severity = 'W' ).
      CATCH zcx_prc_unit_of_work_failed.
        cl_abap_unit_assert=>fail( msg = 'A warning does not fail' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_false( handler->has_errors( ) ).
    DATA(messages) = handler->get_messages( ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-msgty exp = 'W' ).
  ENDMETHOD.

ENDCLASS.
