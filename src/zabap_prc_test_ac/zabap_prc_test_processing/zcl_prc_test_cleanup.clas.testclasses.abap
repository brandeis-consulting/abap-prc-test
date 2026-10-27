"! Retention period 28 days: "old" = 40 days ago, "recent" = 1 day ago
CLASS ltc_cleanup DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.
    DATA mt_runs TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.
    DATA mv_old    TYPE timestampl.
    DATA mv_recent TYPE timestampl.

    METHODS setup.
    METHODS teardown.

    METHODS objects_without_run    FOR TESTING.
    METHODS complete_old_run       FOR TESTING.
    METHODS run_with_error_kept    FOR TESTING.
    METHODS late_change_keeps_run  FOR TESTING.
    METHODS running_run_kept       FOR TESTING.
    METHODS simulation_counts_only FOR TESTING.

    "! Objects processed to FINISHED (with steps and messages), or failed
    METHODS given IMPORTING i_finished TYPE string_table OPTIONAL
                            i_failed   TYPE string_table OPTIONAL.
    METHODS age IMPORTING i_ref TYPE string i_at TYPE timestampl.
    METHODS run IMPORTING i_status      TYPE zprc_run_execution_status DEFAULT zif_prc_run=>co_execution_status-finished
                          i_job_end     TYPE timestampl
                          i_objects     TYPE string_table
                RETURNING VALUE(r_uuid) TYPE sysuuid_x16.
    METHODS cleanup IMPORTING i_simulate      TYPE abap_bool DEFAULT abap_false
                    RETURNING VALUE(r_result) TYPE zcl_prc_cleanup_job=>ty_result.
    METHODS exists IMPORTING i_ref TYPE string RETURNING VALUE(r_exists) TYPE abap_bool.
    METHODS run_exists IMPORTING i_uuid TYPE sysuuid_x16 RETURNING VALUE(r_exists) TYPE abap_bool.
ENDCLASS.


CLASS ltc_cleanup IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    fixture = NEW #( ).
    GET TIME STAMP FIELD DATA(now).
    mv_old    = cl_abap_tstmp=>subtractsecs( tstmp = CONV timestampl( now ) secs = 40 * 86400 ).
    mv_recent = cl_abap_tstmp=>subtractsecs( tstmp = CONV timestampl( now ) secs = 86400 ).
  ENDMETHOD.


  METHOD teardown.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    LOOP AT mt_runs INTO DATA(run).
      DELETE FROM zprc_run_params WHERE job_uuid = @run.
      DELETE FROM zprc_run        WHERE uuid     = @run.
    ENDLOOP.
    COMMIT WORK.
  ENDMETHOD.


  METHOD given.
    DATA(objects) = VALUE zcl_prc_test_proc_fixture=>tt_objects(
        FOR f IN i_finished ( ref = f state = 'START' step_total = 3 ) ).
    " failed in the first step
    objects = VALUE #( BASE objects
        FOR e IN i_failed ( ref = e state = 'START' step_total = 3 payload = `{"START":{"FAIL":"X"}}` ) ).
    fixture->insert_given( VALUE #( objects = objects ) ).
    fixture->run( ).
  ENDMETHOD.


  METHOD age.
    DATA(uuid) = fixture->uuid( i_ref ).
    UPDATE zprc_proc_object SET last_changed_at = @i_at WHERE uuid = @uuid.
    COMMIT WORK.
  ENDMETHOD.


  METHOD run.
    r_uuid = xco_cp=>uuid( )->value.
    INSERT zprc_run FROM @( VALUE #( uuid             = r_uuid
                                     app_name         = zif_prc_run=>co_application_names-demo_rate_adjustment
                                     execution_status = i_status
                                     job_end          = i_job_end ) ).
    LOOP AT i_objects INTO DATA(ref).
      DATA(uuid) = fixture->uuid( ref ).
      UPDATE zprc_proc_object SET run_uuid = @r_uuid WHERE uuid = @uuid.
    ENDLOOP.
    COMMIT WORK.
    APPEND r_uuid TO mt_runs.
  ENDMETHOD.


  METHOD cleanup.
    r_result = NEW zcl_prc_cleanup_job( )->cleanup(
        i_process_names = VALUE #( ( sign = 'I' option = 'EQ' low = zcl_prc_test_proc_fixture=>co_process_name ) )
        i_simulate      = i_simulate ).
  ENDMETHOD.


  METHOD exists.
    DATA(uuid) = fixture->uuid( i_ref ).
    SELECT SINGLE @abap_true FROM zprc_proc_object WHERE uuid = @uuid INTO @r_exists.
  ENDMETHOD.


  METHOD run_exists.
    SELECT SINGLE @abap_true FROM zprc_run WHERE uuid = @i_uuid INTO @r_exists.
  ENDMETHOD.


  METHOD objects_without_run.
    given( i_finished = VALUE #( ( `OLD` ) ( `NEW` ) )
           i_failed   = VALUE #( ( `ERR` ) ) ).
    age( i_ref = `OLD` i_at = mv_old ).
    age( i_ref = `NEW` i_at = mv_recent ).
    age( i_ref = `ERR` i_at = mv_old ).
    DATA(old_uuid) = fixture->uuid( `OLD` ).

    DATA(result) = cleanup( ).

    cl_abap_unit_assert=>assert_equals( act = result-objects exp = 1 ).
    cl_abap_unit_assert=>assert_false( act = exists( `OLD` ) msg = 'Finished and old: deleted' ).
    cl_abap_unit_assert=>assert_true( act = exists( `NEW` ) msg = 'Finished, but recent: kept' ).
    cl_abap_unit_assert=>assert_true( act = exists( `ERR` ) msg = 'Errors are kept' ).
    SELECT COUNT(*) FROM zprc_proc_step WHERE processed_object_uuid = @old_uuid INTO @DATA(steps).
    SELECT COUNT(*) FROM zprc_proc_msg  WHERE processed_object_uuid = @old_uuid INTO @DATA(messages).
    cl_abap_unit_assert=>assert_equals( act = steps + messages exp = 0 msg = 'Steps and messages deleted with the object' ).
  ENDMETHOD.


  METHOD complete_old_run.
    given( i_finished = VALUE #( ( `R1` ) ( `R2` ) ) ).
    age( i_ref = `R1` i_at = mv_old ).
    age( i_ref = `R2` i_at = mv_old ).
    DATA(run) = run( i_job_end = mv_old i_objects = VALUE #( ( `R1` ) ( `R2` ) ) ).

    DATA(result) = cleanup( ).

    cl_abap_unit_assert=>assert_equals( act = result-runs exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result-objects exp = 2 ).
    cl_abap_unit_assert=>assert_false( act = run_exists( run ) msg = 'Run deleted' ).
    cl_abap_unit_assert=>assert_false( act = exists( `R1` ) msg = 'Objects go with their run' ).
  ENDMETHOD.


  METHOD run_with_error_kept.
    given( i_finished = VALUE #( ( `R1` ) ) i_failed = VALUE #( ( `R2` ) ) ).
    age( i_ref = `R1` i_at = mv_old ).
    age( i_ref = `R2` i_at = mv_old ).
    DATA(run) = run( i_job_end = mv_old i_objects = VALUE #( ( `R1` ) ( `R2` ) ) ).

    DATA(result) = cleanup( ).

    cl_abap_unit_assert=>assert_initial( act = result ).
    cl_abap_unit_assert=>assert_true( act = run_exists( run ) ).
    cl_abap_unit_assert=>assert_true( act = exists( `R1` ) msg = 'No own life cycle: kept with the run' ).
  ENDMETHOD.


  METHOD late_change_keeps_run.
    " E.g. resumed and finished recently: the latest change of all counts
    given( i_finished = VALUE #( ( `R1` ) ( `R2` ) ) ).
    age( i_ref = `R1` i_at = mv_old ).
    age( i_ref = `R2` i_at = mv_recent ).
    DATA(run) = run( i_job_end = mv_old i_objects = VALUE #( ( `R1` ) ( `R2` ) ) ).

    cleanup( ).

    cl_abap_unit_assert=>assert_true( act = run_exists( run ) ).
    cl_abap_unit_assert=>assert_true( act = exists( `R1` ) ).
  ENDMETHOD.


  METHOD running_run_kept.
    given( i_finished = VALUE #( ( `R1` ) ) ).
    age( i_ref = `R1` i_at = mv_old ).
    DATA(run) = run( i_status  = zif_prc_run=>co_execution_status-started
                     i_job_end = mv_old
                     i_objects = VALUE #( ( `R1` ) ) ).

    cleanup( ).

    cl_abap_unit_assert=>assert_true( act = run_exists( run ) msg = 'Only ended runs' ).
  ENDMETHOD.


  METHOD simulation_counts_only.
    given( i_finished = VALUE #( ( `OLD` ) ( `R1` ) ) ).
    age( i_ref = `OLD` i_at = mv_old ).
    age( i_ref = `R1`  i_at = mv_old ).
    DATA(run) = run( i_job_end = mv_old i_objects = VALUE #( ( `R1` ) ) ).

    DATA(result) = cleanup( i_simulate = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = result-runs exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result-objects exp = 2 ).
    cl_abap_unit_assert=>assert_true( act = exists( `OLD` ) msg = 'Simulation deletes nothing' ).
    cl_abap_unit_assert=>assert_true( act = run_exists( run ) ).
  ENDMETHOD.

ENDCLASS.
