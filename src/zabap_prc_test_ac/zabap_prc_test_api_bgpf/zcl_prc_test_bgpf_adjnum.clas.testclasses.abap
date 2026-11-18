"! adjust_numbers calls the API directly (phase SAVE, no classified call in between).
"! Expected: green.
CLASS ltc_adjust_numbers_bgpf DEFINITION FINAL
  FOR TESTING RISK LEVEL harmless DURATION MEDIUM.

  PRIVATE SECTION.
    TYPES ty_id     TYPE zr_prc_test_bgpf-ID.
    TYPES ty_ext_id TYPE zr_prc_processedobject-ExternalProcessedObjectID.

    DATA created_ids TYPE STANDARD TABLE OF ty_id WITH EMPTY KEY.

    METHODS teardown.

    METHODS instance_processed_via_bgpf FOR TESTING.
ENDCLASS.


"! Control: the same API call in bgPF mode, but outside the RAP save sequence.
CLASS ltc_control_bgpf_direct DEFINITION FINAL
  FOR TESTING RISK LEVEL harmless DURATION MEDIUM.

  PRIVATE SECTION.
    METHODS teardown.
    METHODS processed_via_bgpf_directly FOR TESTING.
ENDCLASS.


"! Helpers shared by both test classes
CLASS lcl_helper DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES ty_id     TYPE zr_prc_test_bgpf-ID.
    TYPES ty_ext_id TYPE zr_prc_processedobject-ExternalProcessedObjectID.
    TYPES tt_id     TYPE STANDARD TABLE OF ty_id WITH EMPTY KEY.

    CONSTANTS co_max_wait_cycles TYPE i VALUE 20.   " 20 x 0.5 s = 10 s

    "! Creates an instance of ZR_PRC_Test_Bgpf via EML and commits.
    CLASS-METHODS create_instance
      RETURNING VALUE(r_id) TYPE ty_id.

    "! Checks: instance saved, processed object FINISHED, message "performed" exists.
    CLASS-METHODS assert_instance_processed
      IMPORTING i_id TYPE ty_id.

    CLASS-METHODS wait_for_finished
      IMPORTING i_ext_id       TYPE ty_ext_id
                i_max_cycles   TYPE i DEFAULT co_max_wait_cycles
      RETURNING VALUE(r_state) TYPE zif_prc_process=>ty_state.

    CLASS-METHODS assert_performed_message
      IMPORTING i_ext_id TYPE ty_ext_id.

    "! Waits for the bgPF processing, then deletes BO instances and processed objects.
    CLASS-METHODS cleanup
      IMPORTING i_ids TYPE tt_id OPTIONAL.
ENDCLASS.


CLASS lcl_helper IMPLEMENTATION.

  METHOD create_instance.
    MODIFY ENTITIES OF zr_prc_test_bgpf
           ENTITY TestBgpf
           CREATE FROM VALUE #( ( %cid = 'NEW_1' ) )
           MAPPED DATA(mapped)
           FAILED DATA(failed)
           REPORTED DATA(reported) ##NEEDED.

    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = 'CREATE failed' ).

    DATA(pid) = mapped-testbgpf[ 1 ]-%pid.
    DATA final_key TYPE STRUCTURE FOR KEY OF zr_prc_test_bgpf.

    COMMIT ENTITIES BEGIN
           RESPONSE OF zr_prc_test_bgpf
           FAILED DATA(commit_failed)
           REPORTED DATA(commit_reported) ##NEEDED.

      CONVERT KEY OF zr_prc_test_bgpf
              FROM pid
              TO final_key.

    COMMIT ENTITIES END.

    cl_abap_unit_assert=>assert_initial( act = commit_failed
                                         msg = 'COMMIT ENTITIES failed' ).

    r_id = final_key-ID.
  ENDMETHOD.

  METHOD assert_instance_processed.
    cl_abap_unit_assert=>assert_not_initial( act = i_id
                                             msg = 'No final ID from adjust_numbers' ).
    SELECT SINGLE @abap_true FROM zr_prc_test_bgpf WHERE ID = @i_id INTO @DATA(exists).
    cl_abap_unit_assert=>assert_true( act = exists
                                      msg = |BO instance { i_id } was not saved| ).

    DATA(ext_id) = CONV ty_ext_id( i_id ).
    DATA(state) = wait_for_finished( ext_id ).

    cl_abap_unit_assert=>assert_equals( act = state
                                        exp = zif_prc_process=>co_finished
                                        msg = |Processed object { ext_id } not FINISHED (state: { state })| ).

    assert_performed_message( ext_id ).
  ENDMETHOD.

  METHOD wait_for_finished.
    DO i_max_cycles TIMES.
      SELECT SINGLE State FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
        WHERE ProcessName               = @zcl_prc_test_bgpf_proc=>co_process_name
          AND ExternalProcessedObjectID = @i_ext_id
        INTO @r_state.
      IF r_state = zif_prc_process=>co_finished.
        RETURN.
      ENDIF.
      WAIT UP TO '0.5' SECONDS.
    ENDDO.
  ENDMETHOD.

  METHOD assert_performed_message.
    SELECT SINGLE UUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName               = @zcl_prc_test_bgpf_proc=>co_process_name
        AND ExternalProcessedObjectID = @i_ext_id
      INTO @DATA(uuid).

    SELECT COUNT( * ) FROM zr_prc_processedmessage WITH PRIVILEGED ACCESS
      WHERE ProcessedObjectUUID = @uuid
        AND MessageClass        = 'ZPRC_TEST_BGPF'
        AND MessageNumber       = '001'
      INTO @DATA(count).

    cl_abap_unit_assert=>assert_differs( act = count
                                         exp = 0
                                         msg = |Message ZPRC_TEST_BGPF/001 (performed) missing for { i_ext_id }| ).
  ENDMETHOD.

  METHOD cleanup.
    IF i_ids IS NOT INITIAL.
      " Wait for the bgPF processing first: otherwise the unit later runs on a
      " deleted processed object and dumps in the bgRFC session (ASSERTION_FAILED)
      LOOP AT i_ids INTO DATA(id).
        wait_for_finished( CONV #( id ) ).
      ENDLOOP.

      MODIFY ENTITIES OF zr_prc_test_bgpf
             ENTITY TestBgpf
             DELETE FROM VALUE #( FOR del IN i_ids ( ID = del ) ).
      COMMIT ENTITIES.
    ENDIF.

    " Technical cleanup of the test data: without authorization check
    SELECT UUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_bgpf_proc=>co_process_name
      INTO TABLE @DATA(existing).
    IF existing IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_prc_processedobjecttp PRIVILEGED
           ENTITY ProcessedObject
           DELETE FROM VALUE #( FOR k IN existing ( %key-uuid = k-uuid ) ).
    COMMIT ENTITIES.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_adjust_numbers_bgpf IMPLEMENTATION.

  METHOD instance_processed_via_bgpf.
    DATA(id) = lcl_helper=>create_instance( ).
    INSERT id INTO TABLE created_ids.

    lcl_helper=>assert_instance_processed( id ).
  ENDMETHOD.

  METHOD teardown.
    lcl_helper=>cleanup( created_ids ).
    CLEAR created_ids.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_control_bgpf_direct IMPLEMENTATION.

  METHOD processed_via_bgpf_directly.
    GET TIME STAMP FIELD DATA(timestamp).
    DATA(ext_id) = CONV lcl_helper=>ty_ext_id( |CTRL{ timestamp }| ).

    TRY.
        zcl_prc_processing_api=>get_instance( )->create_and_schedule_bgpf(
            VALUE #( ( processName      = zcl_prc_test_bgpf_proc=>co_process_name
                       factoryClassName = zcl_prc_test_bgpf_proc=>co_class_name
                       processedObject  = ext_id ) ) ).
      CATCH cx_bgmc INTO DATA(bgmc_error).
        cl_abap_unit_assert=>fail( |bgPF not scheduled: { bgmc_error->get_text( ) }| ).
    ENDTRY.
    COMMIT WORK AND WAIT.

    DATA(state) = lcl_helper=>wait_for_finished( ext_id ).

    cl_abap_unit_assert=>assert_equals( act = state
                                        exp = zif_prc_process=>co_finished
                                        msg = |Control: { ext_id } not FINISHED (state: { state })| ).

    lcl_helper=>assert_performed_message( ext_id ).
  ENDMETHOD.

  METHOD teardown.
    lcl_helper=>cleanup( ).
  ENDMETHOD.

ENDCLASS.
