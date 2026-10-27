"! <p class="shorttext synchronized">PRC Test: Process for BAPI error scenarios</p>
"!
"! Minimal test process START -> FINISHED. The scenario is passed as PayloadJson
"! and tells the BAPI Z_PRC_TEST_BAPIERR how to behave.
CLASS zcl_prc_test_bapierr_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prc_process.

    ALIASES tt_transition FOR zif_prc_process~tt_transition.

    TYPES ty_scenario TYPE string.

    CONSTANTS co_class_name   TYPE zprc_process_impl_class VALUE 'ZCL_PRC_TEST_BAPIERR_PROC'.
    CONSTANTS co_process_name TYPE zprc_process_name       VALUE 'PRC_TEST_BAPI_ERROR'.

    CONSTANTS: BEGIN OF scenario,
                 no_error               TYPE ty_scenario VALUE `NO_ERROR`,
                 call_error             TYPE ty_scenario VALUE `CALL_ERROR`,
                 call_error_with_update TYPE ty_scenario VALUE `CALL_ERROR_WITH_UPDATE`,
                 call_message_e         TYPE ty_scenario VALUE `CALL_MESSAGE_E`,
                 call_exception         TYPE ty_scenario VALUE `CALL_EXCEPTION`,
                 call_abort             TYPE ty_scenario VALUE `CALL_ABORT`,
                 call_dump              TYPE ty_scenario VALUE `CALL_DUMP`,
                 update_error           TYPE ty_scenario VALUE `UPDATE_ERROR`,
                 update_abort           TYPE ty_scenario VALUE `UPDATE_ABORT`,
                 update_dump            TYPE ty_scenario VALUE `UPDATE_DUMP`,
               END OF scenario.

    "! Creates the processed object and processes it synchronously (direct_execution).
    "!
    "! @parameter i_uuid     | UUID of the processed object
    "! @parameter i_scenario | Scenario, see constants SCENARIO
    CLASS-METHODS start IMPORTING i_uuid     TYPE sysuuid_x16
                                  i_scenario TYPE ty_scenario.

    CLASS-METHODS get_external_id IMPORTING i_uuid          TYPE sysuuid_x16
                                  RETURNING VALUE(r_ext_id) TYPE zr_prc_processedobject-ExternalProcessedObjectID.

    CLASS-METHODS get_scenario IMPORTING i_payload         TYPE zprc_payload_json
                               RETURNING VALUE(r_scenario) TYPE ty_scenario.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_payload,
             scenario TYPE ty_scenario,
           END OF ty_payload.

ENDCLASS.



CLASS zcl_prc_test_bapierr_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE tt_transition( ( start_state = zif_prc_process~co_start
                                           end_state   = zif_prc_process~co_finished ) ).
  ENDMETHOD.


  METHOD zif_prc_process~get_transition_handler.
    ASSERT i_start_state = zif_prc_process~co_start.
    r_transition_handler = NEW lcl_start_to_finish( ).
  ENDMETHOD.


  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.


  METHOD start.
    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = VALUE #( ( processName         = co_process_name
                                                factoryClassName    = co_class_name
                                                processedObject     = get_external_id( i_uuid )
                                                processedObjectUUID = i_uuid
                                                payloadJson         = xco_cp_json=>data->from_abap(
                                                                        VALUE ty_payload( scenario = i_scenario ) )->to_string( ) ) )
        i_perform_commit           = abap_true
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-direct_execution ).
  ENDMETHOD.


  METHOD get_external_id.
    r_ext_id = |{ i_uuid }|.
  ENDMETHOD.


  METHOD get_scenario.
    DATA ls_payload TYPE ty_payload.
    TRY.
        xco_cp_json=>data->from_string( i_payload )->write_to( REF #( ls_payload ) ).
      CATCH cx_root ##CATCH_ALL ##NO_HANDLER.
    ENDTRY.
    r_scenario = ls_payload-scenario.
  ENDMETHOD.

ENDCLASS.
