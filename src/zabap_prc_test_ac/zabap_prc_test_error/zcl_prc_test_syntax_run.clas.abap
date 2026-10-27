"! <p class="shorttext synchronized">PRC Test: Manual syntax error test</p>
"!
"! Creates and/or processes objects of process PRC_TEST_SYNTAX_ERROR. No static
"! reference to the process or handler class, so this classrun stays runnable while
"! one of them has a syntax error. Choose the step with constant CO_MODE.
"!
"! Case 0 (all active, CREATE_AND_PROCESS): object FINISHED.
"! Case 1 (delete DTEL ZPRC_TEST_SYNTAX_HANDLER, CREATE_AND_PROCESS): syntax error in
"!   the handler, loaded in the step session - failed step with the abort text.
"! Case 2 (delete DTEL ZPRC_TEST_SYNTAX_PROCESS): syntax error in the process class,
"!   also loaded in this main session.
"!   2a CREATE_AND_PROCESS: creation itself (DB writer, step total)
"!   2b CREATE_ONLY with intact class, then delete the DTEL, then PROCESS_ONLY:
"!      processing of an existing object (main session of the engine)
"! Restore the data element after each case.
CLASS zcl_prc_test_syntax_run DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS co_process_name TYPE zprc_process_name VALUE 'PRC_TEST_SYNTAX_ERROR'.

    "! CREATE_AND_PROCESS | CREATE_ONLY | PROCESS_ONLY
    CONSTANTS co_mode TYPE string VALUE `CREATE_AND_PROCESS`.
ENDCLASS.



CLASS zcl_prc_test_syntax_run IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA(api) = zcl_prc_processing_api=>get_instance( ).

    TRY.
        IF co_mode = `PROCESS_ONLY`.
          " Same engine entry as the retry job: all due objects of the process
          api->process_synchronously( VALUE #( ( selname = zcl_prc_retry_job=>c_process_name
                                                 sign = 'I' option = 'EQ' low = co_process_name ) ) ).
        ELSE.
          DATA(uuid)   = xco_cp=>uuid( )->value.
          DATA(ext_id) = CONV zr_prc_processedobject-ExternalProcessedObjectID( |{ uuid }| ).
          api->create_processed_objects(
              i_create_processed_objects = VALUE #( ( processName         = co_process_name
                                                      factoryClassName    = 'ZCL_PRC_TEST_SYNTAX_PROC'
                                                      processedObject     = ext_id
                                                      processedObjectUUID = uuid ) )
              i_perform_commit           = abap_true
              i_trigger_processing       = COND #( WHEN co_mode = `CREATE_ONLY`
                                                   THEN zcl_prc_processing_api=>execution_mode-no_execution
                                                   ELSE zcl_prc_processing_api=>execution_mode-direct_execution ) ).
        ENDIF.
      CATCH cx_root INTO DATA(error).
        out->write( |Exception: { error->get_text( ) }| ).
    ENDTRY.

    out->write( |Mode { co_mode } done. Objects of { co_process_name }:| ).
    SELECT ExternalProcessedObjectID
      FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @co_process_name
      INTO TABLE @DATA(objects).
    LOOP AT objects INTO DATA(object).
      zcl_prc_demo_err_output=>print( i_process_name = co_process_name
                                      i_external_id  = object-ExternalProcessedObjectID
                                      i_out          = out ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

