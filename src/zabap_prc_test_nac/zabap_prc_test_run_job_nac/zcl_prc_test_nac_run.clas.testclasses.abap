"! Helpers: objects and runs of these tests
CLASS lcl_data DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS co_job_name TYPE c LENGTH 120 VALUE 'PRC_NAC_RUN_JOB_TEST'.

    "! State of one object of the test process
    CLASS-METHODS read_state IMPORTING i_id           TYPE csequence
                             RETURNING VALUE(r_state) TYPE zr_prc_processedobject-State.
    "! Deletes the objects of the test process and the runs of CO_JOB_NAME
    CLASS-METHODS delete.
    "! Select options of the job for the given IDs, as JSON for initiateRun
    CLASS-METHODS selection IMPORTING i_ids         TYPE string_table
                            RETURNING VALUE(r_json) TYPE string.
ENDCLASS.

CLASS lcl_data IMPLEMENTATION.
  METHOD read_state.
    SELECT SINGLE State FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name
        AND ExternalProcessedObjectID = @i_id
      INTO @r_state.
  ENDMETHOD.

  METHOD delete.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    SELECT uuid FROM zprc_run WHERE job_name = @co_job_name INTO TABLE @DATA(runs).
    LOOP AT runs INTO DATA(run).
      DELETE FROM zprc_run_params WHERE job_uuid = @run-uuid.
    ENDLOOP.
    DELETE FROM zprc_run WHERE job_name = @co_job_name.
    COMMIT WORK.
  ENDMETHOD.

  METHOD selection.
    DATA parameters TYPE cl_apj_rt_api=>tt_job_parameter_value.
    parameters = VALUE #( ( name    = zcl_prc_test_nac_run_job=>co_ids
                            t_value = VALUE #( FOR id IN i_ids ( sign = 'I' option = 'EQ' low = id ) ) ) ).
    r_json = /ui2/cl_json=>serialize( data = parameters ).
  ENDMETHOD.
ENDCLASS.


"! The job itself: Standard ABAP job class, processed with ABAP-PRC (same entry point as
"! the application job framework, synchronous)
CLASS ltc_execute DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS runs_with_prc FOR TESTING.
ENDCLASS.


CLASS ltc_execute IMPLEMENTATION.

  METHOD setup.
    lcl_data=>delete( ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    lcl_data=>delete( ).
  ENDMETHOD.


  METHOD runs_with_prc.
    TRY.
        NEW zcl_prc_test_nac_run_job( )->if_apj_rt_exec_object~execute(
            VALUE #( ( selname = zcl_prc_test_nac_run_job=>co_ids kind = 'S' sign = 'I' option = 'EQ' low = 'NACRUN1' )
                     ( selname = zcl_prc_test_nac_run_job=>co_ids kind = 'S' sign = 'I' option = 'EQ' low = 'NACRUN2' ) ) ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = |Job failed: { error->get_text( ) }| ).
    ENDTRY.

    SELECT ExternalProcessedObjectID, RunUUID, State
      FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name
      ORDER BY ExternalProcessedObjectID
      INTO TABLE @DATA(objects).

    cl_abap_unit_assert=>assert_equals( act = lines( objects ) exp = 2 msg = 'One object per selected ID' ).
    LOOP AT objects INTO DATA(object).
      cl_abap_unit_assert=>assert_equals( act = object-State exp = zif_prc_process=>co_finished
                                          msg = 'Processed in the run' ).
    ENDLOOP.

    DATA(run_uuid) = objects[ 1 ]-RunUUID.
    SELECT SINGLE ExecutionStatus FROM zr_prc_run WITH PRIVILEGED ACCESS
      WHERE UUID = @run_uuid
      INTO @DATA(status).
    cl_abap_unit_assert=>assert_equals( act = status exp = zif_prc_run=>co_execution_status-finished
                                        msg = 'Run finished' ).
    " Runs of the synchronous job carry no job name: delete this one by its UUID
    DELETE FROM zprc_run WHERE uuid = @run_uuid.
    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.


"! The run app (initiateRun of the ABAP Cloud run BO) with the Standard ABAP job template,
"! scheduled by the real application job framework.
"! HARMLESS like the other tests of the PRC that commit: the job and the run it leaves
"! behind belong to the test and are deleted in the teardown.
CLASS ltc_run_app DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION LONG.
  PRIVATE SECTION.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED EARLY zr_prc_runtp.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED EARLY zr_prc_runtp.

    "! Seconds to wait for the scheduled job. The job scheduler picks it up with a delay
    "! (measured: about 55 s on A4H), so generously above that.
    CONSTANTS co_timeout TYPE i VALUE 180.

    METHODS setup.
    METHODS teardown.
    METHODS template_accepted    FOR TESTING.
    METHODS job_runs_via_run_app FOR TESTING.

    METHODS initiate IMPORTING i_ids             TYPE string_table
                     EXPORTING e_failed          TYPE ty_failed
                               e_reported        TYPE ty_reported
                     RETURNING VALUE(r_run_uuid) TYPE sysuuid_x16.
    METHODS messages IMPORTING i_reported    TYPE ty_reported
                     RETURNING VALUE(r_text) TYPE string.
    "! Texts of the application logs assigned to the job of the run, once the job has ended
    METHODS job_log_texts IMPORTING i_run_uuid     TYPE sysuuid_x16
                          RETURNING VALUE(r_texts) TYPE string_table.
ENDCLASS.


CLASS ltc_run_app IMPLEMENTATION.

  METHOD setup.
    " The production scheduler, no test double
    zcl_prc_job_scheduler_injector=>reset( ).
    lcl_data=>delete( ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    lcl_data=>delete( ).
  ENDMETHOD.


  METHOD initiate.
    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           EXECUTE initiateRun
           FROM VALUE #( ( %cid   = 'INIT'
                           %param = VALUE #( applicationName    = zcl_prc_test_proc_fixture=>co_application_name
                                             jobName            = lcl_data=>co_job_name
                                             jobTemplateName    = zcl_prc_test_nac_run_job=>co_job_template
                                             selectOptionString = lcl_data=>selection( i_ids ) ) ) )
           MAPPED DATA(mapped)
           FAILED e_failed
           REPORTED e_reported.
    r_run_uuid = VALUE #( mapped-run[ KEY cid %cid = 'INIT' ]-uuid OPTIONAL ).
  ENDMETHOD.


  METHOD messages.
    LOOP AT i_reported-run INTO DATA(report) WHERE %msg IS BOUND.
      r_text = |{ r_text } { report-%msg->if_message~get_text( ) }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD job_log_texts.
    SELECT SINGLE job_id, job_count FROM zprc_run WHERE uuid = @i_run_uuid INTO @DATA(job) BYPASSING BUFFER.

    " The job may still be ending after the run is finished
    DO co_timeout TIMES.
      TRY.
          cl_apj_rt_api=>get_job_status( EXPORTING iv_jobname    = job-job_id
                                                   iv_jobcount   = job-job_count
                                         IMPORTING ev_job_status = DATA(job_status) ).
        CATCH cx_apj_rt.
          CLEAR job_status.
      ENDTRY.
      IF job_status = 'F' OR job_status = 'A'.
        EXIT.
      ENDIF.
      WAIT UP TO 1 SECONDS.
    ENDDO.

    " Logs assigned to the job: job context, value '<step> <log handle>'
    " (APJ_V_JR_LOG_INF cuts the handle to 21 characters, not loadable)
    SELECT ctxtval FROM tbtccntxt
      WHERE jobname  = @job-job_id
        AND jobcount = @job-job_count
        AND ctxttype = 'BTC_APPLOG_HANDLE'
      INTO TABLE @DATA(contexts).
    LOOP AT contexts INTO DATA(context).
      TRY.
          DATA(log) = cl_bali_log_db=>get_instance( )->load_log(
                          CONV #( segment( val = condense( context-ctxtval ) index = 2 sep = ` ` ) ) ).
          LOOP AT log->get_all_items( ) INTO DATA(item).
            APPEND item-item->get_message_text( ) TO r_texts.
          ENDLOOP.
        CATCH cx_bali_runtime cx_sy_strg_par_val ##NO_HANDLER.
          " Not readable: counts as missing
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD template_accepted.
    " initiateRun checks the template before the run exists (CAN_SCHEDULE_JOB, parameters)
    initiate( EXPORTING i_ids      = VALUE #( ( `NACRUN3` ) )
              IMPORTING e_failed   = DATA(failed)
                        e_reported = DATA(reported) ).
    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = |Standard ABAP template rejected:{ messages( reported ) }| ).
    " teardown: ROLLBACK ENTITIES - no job
  ENDMETHOD.


  METHOD job_runs_via_run_app.
    DATA failed   TYPE ty_failed.
    DATA reported TYPE ty_reported.

    DATA(run_uuid) = initiate( EXPORTING i_ids      = VALUE #( ( `NACRUN4` ) )
                               IMPORTING e_failed   = failed
                                         e_reported = reported ).
    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = |Standard ABAP template rejected:{ messages( reported ) }| ).

    COMMIT ENTITIES RESPONSE OF zr_prc_runtp FAILED DATA(commit_failed) REPORTED DATA(commit_reported).
    cl_abap_unit_assert=>assert_initial( act = commit_failed msg = 'Run saved' ).

    " Scheduling errors of the save come as messages without an instance (ZPRC_RUN/009)
    DATA(save_messages) = ``.
    LOOP AT commit_reported-%other INTO DATA(other).
      save_messages = |{ save_messages } { other->if_message~get_text( ) }|.
    ENDLOOP.
    cl_abap_unit_assert=>assert_initial( act = save_messages msg = |Job not scheduled:{ save_messages }| ).

    " The job runs asynchronously: wait for the run to finish
    DATA status TYPE zprc_run-execution_status.
    DO co_timeout TIMES.
      SELECT SINGLE execution_status FROM zprc_run WHERE uuid = @run_uuid INTO @status BYPASSING BUFFER.
      IF status = zif_prc_run=>co_execution_status-finished OR status = zif_prc_run=>co_execution_status-aborted.
        EXIT.
      ENDIF.
      WAIT UP TO 1 SECONDS.
    ENDDO.

    cl_abap_unit_assert=>assert_equals( act = status exp = zif_prc_run=>co_execution_status-finished
                                        msg = |Run of the scheduled job not finished within { co_timeout } s| ).
    cl_abap_unit_assert=>assert_equals( act = lcl_data=>read_state( `NACRUN4` ) exp = zif_prc_process=>co_finished
                                        msg = 'Object processed by the job' ).

    " The whole log is at the job: also the messages of the objects (step log of the packages)
    DATA(texts) = job_log_texts( run_uuid ).
    DATA(object_messages) = REDUCE i( INIT n = 0 FOR t IN texts WHERE ( table_line CS `NACRUN4` ) NEXT n = n + 1 ).
    cl_abap_unit_assert=>assert_differs( act = object_messages exp = 0
                                         msg = |Job log without the messages of the objects ({ lines( texts ) } items)| ).
  ENDMETHOD.

ENDCLASS.
