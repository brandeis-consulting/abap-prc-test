"! <p class="shorttext synchronized">PRC Test: Run job in Standard ABAP</p>
"!
"! A run job whose class, job catalog entry (ZAJC_PRC_TEST_NAC_RUN_JOB) and job template
"! (ZAJT_PRC_TEST_NAC_RUN_JOB) are Standard ABAP. Tested in ZCL_PRC_TEST_NAC_RUN:
"! it runs with ABAP-PRC, and a run app (ABAP Cloud, initiateRun) can schedule it.
"!
"! One select option S_ID; every value becomes one object of the test process.
"! No notification at the end of the run (would leave an object behind).
CLASS zcl_prc_test_nac_run_job DEFINITION
  PUBLIC
  INHERITING FROM zcl_prc_run_job
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS if_apj_dt_exec_object~get_parameters REDEFINITION.

    CONSTANTS co_ids          TYPE zif_prc_run=>ty_run_parameter     VALUE 'S_ID'.
    CONSTANTS co_job_template TYPE zif_prc_run=>ty_job_template_name VALUE 'ZAJT_PRC_TEST_NAC_RUN_JOB'.

  PROTECTED SECTION.
    METHODS select               REDEFINITION.
    METHODS get_process          REDEFINITION.
    METHODS get_application_name REDEFINITION.
    METHODS notify_on_completion REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_nac_run_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
        ( selname = co_ids kind = if_apj_dt_exec_object=>select_option
          datatype = 'C' length = 30 param_text = 'IDs' changeable_ind = abap_true )
        ( selname = zif_prc_run=>co_parameter-p_uuid kind = if_apj_dt_exec_object=>parameter
          datatype = 'C' length = 32 param_text = 'Run UUID' changeable_ind = abap_true ) ).
  ENDMETHOD.


  METHOD select.
    " Range typed in this Standard ABAP class, like a job of a user would do it
    DATA ids TYPE RANGE OF za_prc_createprocessedobject-processedobject.
    get_range( EXPORTING i_select_options = i_select_options
                         i_name           = co_ids
               IMPORTING e_range          = ids ).
    r_objects = VALUE #( FOR i IN ids ( id = i-low ) ).
  ENDMETHOD.


  METHOD get_process.
    " Values of ZCL_PRC_TEST_PROC_FIXTURE (a test class, not usable here)
    r_process = VALUE #( name          = 'TEST_PROC'
                         factory_class = 'ZCL_PRC_TEST_PROC_PROCESS' ).
  ENDMETHOD.


  METHOD get_application_name.
    " ZCL_PRC_TEST_PROC_FIXTURE=>CO_APPLICATION_NAME
    r_application_name = 'TEST_RUN'.
  ENDMETHOD.


  METHOD notify_on_completion.
    r_notify = abap_false.
  ENDMETHOD.

ENDCLASS.
