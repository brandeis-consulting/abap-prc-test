"! <p class="shorttext synchronized">PRC demo: on-save validation fails the simulation</p>
"!
"! Scenario CHECK_BEFORE_SAVE_ERROR: the transition changes the test BO; its
"! on-save validation reports FAILED plus E, E, W, I. 2-Simulation finds it with
"! COMMIT ENTITIES IN SIMULATION MODE - before anything is written or committed.
"!
"! Expected result: state START, retry 1, messages ZPRC_TEST_RAPERR/007-010 and
"! the failure message 016 of the transition as step header.
CLASS zcl_prc_demo_err_check_save DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS create_bo_instance RETURNING VALUE(r_uuid) TYPE sysuuid_x16.
ENDCLASS.



CLASS zcl_prc_demo_err_check_save IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Breakpoints - layers 7 to 1, the process and the BO run in a session of their
    " own: use EXTERNAL (user) breakpoints there, debugging of RFC/background sessions on.
    "
    " 1. External: ZBP_R_PRC_TEST_RAPERR, local class LHC_RAPERR, method
    "    CHECKBEFORESAVE - the validation reports FAILED
    " 2. External: ZCL_PRC_STEP_2_SIMULATION, method ZIF_PRC_PROCESSING_STEP~EXECUTE,
    "    after COMMIT ENTITIES IN SIMULATION MODE - SY-SUBRC <> 0
    " 3. External: ZCL_PRC_STEP_3_RESULT - is never reached, nothing is written
    DATA(bo_uuid) = create_bo_instance( ).
    IF bo_uuid IS INITIAL.
      out->write( `Test BO instance could not be created - nothing started` ) ##NO_TEXT.
      RETURN.
    ENDIF.

    zcl_prc_test_raperr_proc=>start( i_bo_uuid  = bo_uuid
                                     i_scenario = zcl_prc_test_raperr_proc=>scenario-check_before_save_error ).

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

