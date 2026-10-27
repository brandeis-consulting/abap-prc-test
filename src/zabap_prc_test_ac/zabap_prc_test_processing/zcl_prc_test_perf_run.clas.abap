"! <p class="shorttext synchronized">PRC Test: Performance measurement</p>
"!
"! Measures the framework with a process without logic (ZCL_PRC_TEST_PERF_PROC):
"! CO_COUNT objects are created (blocks of 10,000 with commit) and processed via
"! the same entry as the retry job. Output: durations, throughput, data volume.
"!
"! As classrun on purpose (not as application job), so the main session can be
"! traced (ABAP profiler). The isolated steps and the parallel packages run in
"! sessions of their own and are not part of that trace - their share is the
"! difference to the time of the main session.
"!
"! Set CO_COUNT to 1, 1000 or 100000. The dialog timeout applies to the classrun.
CLASS zcl_prc_test_perf_run DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
    "! Number of objects of the measurement
    CONSTANTS co_count   TYPE i VALUE 10000.
    "! Delete the objects of the measurement afterwards
    CONSTANTS co_cleanup TYPE abap_bool VALUE abap_true.
    CONSTANTS co_block   TYPE i VALUE 10000.

    METHODS cleanup.
    METHODS seconds IMPORTING i_from TYPE timestampl i_to TYPE timestampl
                    RETURNING VALUE(r_seconds) TYPE decfloat34.
ENDCLASS.



CLASS zcl_prc_test_perf_run IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA t_start     TYPE timestampl.
    DATA t_created   TYPE timestampl.
    DATA t_processed TYPE timestampl.

    DATA(api) = zcl_prc_processing_api=>get_instance( ).
    cleanup( ).

    " 1. Create
    GET TIME STAMP FIELD t_start.
    DATA(created) = 0.
    WHILE created < co_count.
      DATA(block_size) = nmin( val1 = co_block val2 = co_count - created ).
      api->create_processed_objects(
          i_create_processed_objects = VALUE #( FOR i = created + 1 UNTIL i > created + block_size
                                                ( processName      = zcl_prc_test_perf_proc=>co_process_name
                                                  factoryClassName = zcl_prc_test_perf_proc=>co_class_name
                                                  processedObject  = |PERF{ i WIDTH = 7 ALIGN = RIGHT PAD = '0' }| ) )
          i_perform_commit           = abap_true
          i_trigger_processing       = zcl_prc_processing_api=>execution_mode-no_execution ).
      created += block_size.
    ENDWHILE.
    GET TIME STAMP FIELD t_created.

    " 2. Process (same entry as the retry job)
    api->process_synchronously( VALUE #( ( selname = zcl_prc_retry_job=>c_process_name sign = 'I' option = 'EQ'
                                           low     = zcl_prc_test_perf_proc=>co_process_name ) ) ).
    GET TIME STAMP FIELD t_processed.

    " 3. Data volume
    SELECT COUNT(*) FROM zprc_proc_object
      WHERE process_name = @zcl_prc_test_perf_proc=>co_process_name
      INTO @DATA(objects).
    SELECT COUNT(*) FROM zprc_proc_object
      WHERE process_name = @zcl_prc_test_perf_proc=>co_process_name AND state = @zif_prc_process=>co_finished
      INTO @DATA(finished).
    SELECT COUNT(*) FROM zprc_proc_step
      WHERE processed_object_uuid IN ( SELECT uuid FROM zprc_proc_object
                                         WHERE process_name = @zcl_prc_test_perf_proc=>co_process_name )
      INTO @DATA(steps).
    SELECT COUNT(*) FROM zprc_proc_msg
      WHERE processed_object_uuid IN ( SELECT uuid FROM zprc_proc_object
                                         WHERE process_name = @zcl_prc_test_perf_proc=>co_process_name )
      INTO @DATA(messages).

    DATA(create_s)  = seconds( i_from = t_start   i_to = t_created ).
    DATA(process_s) = seconds( i_from = t_created i_to = t_processed ).

    out->write( |PRC performance, { co_count } object(s), process without logic| ).
    out->write( |  Create:   { create_s DECIMALS = 3 } s ({ COND decfloat34( WHEN co_count > 0 THEN create_s * 1000 / co_count ) DECIMALS = 3 } ms/object)| ).
    out->write( |  Process:  { process_s DECIMALS = 3 } s ({ COND decfloat34( WHEN co_count > 0 THEN process_s * 1000 / co_count ) DECIMALS = 3 } ms/object)| ).
    out->write( |  Total:    { create_s + process_s DECIMALS = 3 } s| ).
    out->write( |  Throughput processing: { COND decfloat34( WHEN process_s > 0 THEN finished / process_s ) DECIMALS = 1 } objects/s| ).
    out->write( |  Objects: { objects }, finished: { finished }| ).
    out->write( |  Steps: { steps }, messages: { messages } ({ COND decfloat34( WHEN objects > 0 THEN messages / objects ) DECIMALS = 2 } per object)| ).

    IF co_cleanup = abap_true.
      cleanup( ).
      out->write( |  Objects of the measurement deleted| ).
    ENDIF.
  ENDMETHOD.


  METHOD cleanup.
    DELETE FROM zprc_proc_msg
      WHERE processed_object_uuid IN ( SELECT uuid FROM zprc_proc_object
                                         WHERE process_name = @zcl_prc_test_perf_proc=>co_process_name ).
    DELETE FROM zprc_proc_step
      WHERE processed_object_uuid IN ( SELECT uuid FROM zprc_proc_object
                                         WHERE process_name = @zcl_prc_test_perf_proc=>co_process_name ).
    DELETE FROM zprc_proc_object WHERE process_name = @zcl_prc_test_perf_proc=>co_process_name.
    COMMIT WORK.
  ENDMETHOD.


  METHOD seconds.
    r_seconds = cl_abap_tstmp=>subtract( tstmp1 = i_to tstmp2 = i_from ).
  ENDMETHOD.

ENDCLASS.

