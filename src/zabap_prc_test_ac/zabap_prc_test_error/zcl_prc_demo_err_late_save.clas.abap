"! <p class="shorttext synchronized">PRC demo: FAILED in the late save of a RAP BO</p>
"!
"! Scenario LATE_SAVE_FAILED: the transition calls action lateSaveFailed of the
"! test BO ZR_PRC_Test_RapErr. Its saver (CL_ABAP_BEHAVIOR_SAVER_FAILED) reports
"! FAILED plus E, E, W, I in SAVE_MODIFIED. The simulation passes - the save
"! phase is not part of it - but COMMIT ENTITIES in 4-Commit fails;
"! 5-Expected rolls back and writes the failed step.
"!
"! Expected result: state START, retry 1, messages ZPRC_TEST_RAPERR/011-014 and
"! the failure message 016 of the transition as step header.
CLASS zcl_prc_demo_err_late_save DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS create_bo_instance RETURNING VALUE(r_uuid) TYPE sysuuid_x16.
ENDCLASS.



CLASS zcl_prc_demo_err_late_save IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Breakpoints - layers 7 to 1, the process and the BO run in a session of their
    " own: use EXTERNAL (user) breakpoints there, debugging of RFC/background sessions on.
    "
    " 1. External: ZBP_R_PRC_TEST_RAPERR, local class LSC_ZR_PRC_TEST_RAPERR,
    "    method SAVE_MODIFIED - FAILED is reported here
    " 2. External: ZCL_PRC_STEP_4_COMMIT, method ZIF_PRC_PROCESSING_STEP~EXECUTE,
    "    after COMMIT ENTITIES - SY-SUBRC <> 0, FAILED and REPORTED filled
    " 3. External: ZCL_PRC_STEP_5_EXPECTED, method ADD_FAILURE_MESSAGE - the failure
    "    message of the transition becomes the step header
    DATA(bo_uuid) = create_bo_instance( ).
    IF bo_uuid IS INITIAL.
      out->write( `Test BO instance could not be created - nothing started` ) ##NO_TEXT.
      RETURN.
    ENDIF.

    zcl_prc_test_raperr_proc=>start( i_bo_uuid  = bo_uuid
                                     i_scenario = zcl_prc_test_raperr_proc=>scenario-late_save_failed ).

    zcl_prc_demo_err_output=>print( i_process_name = zcl_prc_test_raperr_proc=>co_process_name
                                    i_external_id  = zcl_prc_test_raperr_proc=>get_external_id( bo_uuid )
                                    i_out          = out ).
  ENDMETHOD.


  METHOD create_bo_instance.
    MODIFY ENTITIES OF zr_prc_test_raperr
           ENTITY RapErr
           CREATE FIELDS ( Text ) WITH VALUE #( ( %cid = 'DEMO'  Text = 'NEW' ) )
           MAPPED DATA(mapped)
           FAILED DATA(failed) ##NEEDED
           REPORTED DATA(reported) ##NEEDED.
    COMMIT ENTITIES.
    IF sy-subrc <> 0 OR mapped-raperr IS INITIAL.
      RETURN.  " r_uuid initial: the caller stops
    ENDIF.
    r_uuid = mapped-raperr[ 1 ]-UUID.
  ENDMETHOD.

ENDCLASS.

