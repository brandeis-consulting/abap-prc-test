"! <p class="shorttext synchronized">PRC Test: Process for RAP BO error scenarios</p>
"!
"! Minimal test process START -> FINISHED. The scenario is passed as PayloadJson
"! and determines which action of the test BO ZR_PRC_Test_RapErr is executed.
"! <p class="shorttext synchronized">PRC Test: Process for RAP BO error scenarios</p>
"!
"! Minimal test process START -> FINISHED. The scenario is passed as PayloadJson
"! and determines which action of the test BO ZR_PRC_Test_RapErr is executed.
"! <p class="shorttext synchronized">PRC Test: Process for RAP BO error scenarios</p>
"!
"! Minimal test process START -> FINISHED. The scenario is passed as PayloadJson
"! and determines which action of the test BO ZR_PRC_Test_RapErr is executed.
CLASS zcl_prc_test_raperr_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prc_process.

    ALIASES tt_transition FOR zif_prc_process~tt_transition.

    TYPES ty_scenario TYPE string.

    CONSTANTS co_class_name   TYPE zprc_process_impl_class VALUE 'ZCL_PRC_TEST_RAPERR_PROC'.
    CONSTANTS co_process_name TYPE zprc_process_name       VALUE 'PRC_TEST_RAP_ERROR'.

    CONSTANTS: BEGIN OF scenario,
                 no_error                TYPE ty_scenario VALUE `NO_ERROR`,
                 modify_error            TYPE ty_scenario VALUE `MODIFY_ERROR`,
                 modify_lock_error       TYPE ty_scenario VALUE `MODIFY_LOCK_ERROR`,
                 check_before_save_error TYPE ty_scenario VALUE `CHECK_BEFORE_SAVE_ERROR`,
                 late_save_messages      TYPE ty_scenario VALUE `LATE_SAVE_MESSAGES`,
                 late_save_failed        TYPE ty_scenario VALUE `LATE_SAVE_FAILED`,
               END OF scenario.

    "! Creates the processed object and processes it synchronously (direct_execution).
    "!
    "! @parameter i_bo_uuid  | UUID of the ZR_PRC_Test_RapErr instance
    "! @parameter i_scenario | Scenario, see constants SCENARIO
    CLASS-METHODS start IMPORTING i_bo_uuid  TYPE sysuuid_x16
                                  i_scenario TYPE ty_scenario.

    "! External ID of the processed object for a BO instance.
    CLASS-METHODS get_external_id IMPORTING i_bo_uuid       TYPE sysuuid_x16
                                  RETURNING VALUE(r_ext_id) TYPE zr_prc_processedobject-ExternalProcessedObjectID.

    CLASS-METHODS build_payload IMPORTING i_scenario       TYPE ty_scenario
                                RETURNING VALUE(r_payload) TYPE zprc_payload_json.

    CLASS-METHODS get_scenario IMPORTING i_payload         TYPE zprc_payload_json
                               RETURNING VALUE(r_scenario) TYPE ty_scenario.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_payload,
             scenario TYPE ty_scenario,
           END OF ty_payload.

ENDCLASS.



CLASS zcl_prc_test_raperr_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE tt_transition( ( start_state = zif_prc_process~co_start
                                           end_state   = zif_prc_process~co_finished ) ).
  ENDMETHOD.


  METHOD zif_prc_process~get_transition_handler.
    CASE i_start_state.
      WHEN zif_prc_process~co_start.
        r_transition_handler = NEW lcl_start_to_finish( ).
      WHEN OTHERS.
        " FINISHED has no transition, anything else is unexpected
        ASSERT 1 = 2.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.


  METHOD start.
    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = VALUE #( ( processName         = co_process_name
                                                factoryClassName    = co_class_name
                                                processedObject     = get_external_id( i_bo_uuid )
                                                processedObjectUUID = i_bo_uuid
                                                payloadJson         = build_payload( i_scenario ) ) )
        " Commit before processing: a ROLLBACK ENTITIES in the error case
        " must not roll back the processed object itself
        i_perform_commit           = abap_true
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-direct_execution ).
  ENDMETHOD.


  METHOD get_external_id.
    r_ext_id = |{ i_bo_uuid }|.
  ENDMETHOD.


  METHOD build_payload.
    r_payload = xco_cp_json=>data->from_abap( VALUE ty_payload( scenario = i_scenario ) )->to_string( ).
  ENDMETHOD.


  METHOD get_scenario.
    DATA ls_payload TYPE ty_payload.
    TRY.
        xco_cp_json=>data->from_string( i_payload )->write_to( REF #( ls_payload ) ).
      CATCH cx_root ##CATCH_ALL ##NO_HANDLER.
        " empty scenario -> reported as unknown by the transition
    ENDTRY.
    r_scenario = ls_payload-scenario.
  ENDMETHOD.

ENDCLASS.
