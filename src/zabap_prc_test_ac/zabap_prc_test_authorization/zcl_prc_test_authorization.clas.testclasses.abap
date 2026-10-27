"! Restricts the authorizations of the current user in the test session
CLASS lcl_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    "! Only this one authorization remains for the given object
    CLASS-METHODS restrict
      IMPORTING i_object   TYPE csequence
                i_field    TYPE csequence
                i_value    TYPE csequence
                i_activity TYPE csequence.

    CLASS-METHODS reset.
ENDCLASS.


CLASS lcl_auth IMPLEMENTATION.
  METHOD restrict.
    DATA(authorization) = VALUE cl_aunit_auth_check_types_def=>authorization(
        ( fieldname = i_field fieldvalues = VALUE #( ( lower_value = i_value ) ) )
        ( fieldname = 'ACTVT' fieldvalues = VALUE #( ( lower_value = i_activity ) ) ) ).

    DATA(role) = VALUE cl_aunit_auth_check_types_def=>role_auth_objects(
        ( object = i_object authorizations = VALUE #( ( authorization ) ) ) ).

    DATA(auth_objset) = cl_aunit_authority_check=>create_auth_object_set(
        VALUE #( ( role_authorizations = role
                   users               = VALUE #( ( sy-uname ) ) ) ) ).

    TRY.
        cl_aunit_authority_check=>get_controller( )->restrict_authorizations_to( auth_objset ).
      CATCH cx_abap_auth_check_exception INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = |Restricting authorizations failed: { error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD reset.
    cl_aunit_authority_check=>get_controller( )->reset( ).
  ENDMETHOD.
ENDCLASS.


"! Processed object BO: precheck (01), update (02), delete (06), resume (16)
"! and privileged mode. Nothing is committed.
CLASS ltc_processed_object DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_allowed     TYPE zprc_process_name VALUE 'ZPRC_AUTH_TEST_A'.
    CONSTANTS c_not_allowed TYPE zprc_process_name VALUE 'ZPRC_AUTH_TEST_B'.
    CONSTANTS c_factory     TYPE string            VALUE 'ZCL_PRC_TEST_PROC_PROCESS'.

    METHODS teardown.

    METHODS create_unauthorized FOR TESTING.
    METHODS create_authorized   FOR TESTING.
    METHODS create_privileged   FOR TESTING.
    METHODS update_unauthorized FOR TESTING.
    METHODS update_authorized   FOR TESTING.
    METHODS delete_unauthorized FOR TESTING.
    METHODS delete_authorized   FOR TESTING.
    METHODS resume_unauthorized FOR TESTING.
    METHODS resume_authorized   FOR TESTING.

    "! Creates a processed object in privileged mode (transactional buffer only)
    METHODS _create_privileged
      IMPORTING i_process_name TYPE zprc_process_name
      RETURNING VALUE(r_uuid)  TYPE sysuuid_x16.
ENDCLASS.


CLASS ltc_processed_object IMPLEMENTATION.
  METHOD teardown.
    ROLLBACK ENTITIES.
    lcl_auth=>reset( ).
  ENDMETHOD.

  METHOD _create_privileged.
    MODIFY ENTITIES OF zr_prc_processedobjecttp PRIVILEGED
           ENTITY ProcessedObject
           EXECUTE createProcessedObject
           FROM VALUE #( ( %cid   = 'CID'
                           %param = VALUE #( processName      = i_process_name
                                             factoryClassName = c_factory
                                             processedObject  = 'AUTH_TEST' ) ) )
           MAPPED DATA(mapped)
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = 'Privileged create failed' ).
    r_uuid = mapped-processedobject[ 1 ]-uuid.
  ENDMETHOD.

  METHOD create_unauthorized.
    lcl_auth=>restrict( i_object = 'ZPRC_PROC' i_field = 'ZPRCNAME' i_value = c_allowed i_activity = '01' ).

    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           EXECUTE createProcessedObject
           FROM VALUE #( ( %cid   = 'CID'
                           %param = VALUE #( processName      = c_not_allowed
                                             factoryClassName = c_factory
                                             processedObject  = 'AUTH_TEST' ) ) )
           MAPPED DATA(mapped)
           FAILED DATA(failed)
           REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial( act = failed-processedobject
                                             msg = 'Create must fail without ZPRC_PROC 01' ).
    cl_abap_unit_assert=>assert_initial( act = mapped-processedobject
                                         msg = 'No instance expected' ).
    cl_abap_unit_assert=>assert_equals( act = reported-processedobject[ 1 ]-%msg->if_t100_message~t100key-msgno
                                        exp = '004'
                                        msg = 'Message ZPRC_PROCESS_MESSAGE/004 expected' ).
  ENDMETHOD.

  METHOD create_authorized.
    lcl_auth=>restrict( i_object = 'ZPRC_PROC' i_field = 'ZPRCNAME' i_value = c_allowed i_activity = '01' ).

    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           EXECUTE createProcessedObject
           FROM VALUE #( ( %cid   = 'CID'
                           %param = VALUE #( processName      = c_allowed
                                             factoryClassName = c_factory
                                             processedObject  = 'AUTH_TEST' ) ) )
           MAPPED DATA(mapped)
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = 'Create must succeed with ZPRC_PROC 01' ).
    cl_abap_unit_assert=>assert_not_initial( act = mapped-processedobject
                                             msg = 'Instance expected' ).
  ENDMETHOD.

  METHOD create_privileged.
    " Restricted to display of another process, still created: ZPRC_PROC is in the authorization context
    lcl_auth=>restrict( i_object = 'ZPRC_PROC' i_field = 'ZPRCNAME' i_value = c_allowed i_activity = '03' ).

    cl_abap_unit_assert=>assert_not_initial( act = _create_privileged( c_not_allowed )
                                             msg = 'Privileged create must succeed without authorization' ).
  ENDMETHOD.

  METHOD update_unauthorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_PROC' i_field = 'ZPRCNAME' i_value = c_allowed i_activity = '03' ).

    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           UPDATE FIELDS ( MailAddress )
           WITH VALUE #( ( uuid = uuid MailAddress = 'auth@test.de' ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-processedobject
                                             msg = 'Update must fail without ZPRC_PROC 02' ).
  ENDMETHOD.

  METHOD update_authorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_PROC' i_field = 'ZPRCNAME' i_value = c_allowed i_activity = '02' ).

    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           UPDATE FIELDS ( MailAddress )
           WITH VALUE #( ( uuid = uuid MailAddress = 'auth@test.de' ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = 'Update must succeed with ZPRC_PROC 02' ).
  ENDMETHOD.

  METHOD delete_unauthorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_PROC' i_field = 'ZPRCNAME' i_value = c_allowed i_activity = '03' ).

    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           DELETE FROM VALUE #( ( uuid = uuid ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-processedobject
                                             msg = 'Delete must fail without ZPRC_PROC 06' ).
  ENDMETHOD.

  METHOD delete_authorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_PROC' i_field = 'ZPRCNAME' i_value = c_allowed i_activity = '06' ).

    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           DELETE FROM VALUE #( ( uuid = uuid ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = 'Delete must succeed with ZPRC_PROC 06' ).
  ENDMETHOD.

  METHOD resume_unauthorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_PROC' i_field = 'ZPRCNAME' i_value = c_allowed i_activity = '03' ).

    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           EXECUTE resumeProcessing
           FROM VALUE #( ( uuid = uuid ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-processedobject
                                             msg = 'Resume must fail without ZPRC_PROC 16' ).
  ENDMETHOD.

  METHOD resume_authorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_PROC' i_field = 'ZPRCNAME' i_value = c_allowed i_activity = '16' ).

    MODIFY ENTITIES OF zr_prc_processedobjecttp
           ENTITY ProcessedObject
           EXECUTE resumeProcessing
           FROM VALUE #( ( uuid = uuid ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = 'Resume must succeed with ZPRC_PROC 16' ).
  ENDMETHOD.
ENDCLASS.


"! Run BO: precheck (01) for create and initiateRun, update and
"! triggerChangedEvent (02), delete (06) and privileged mode. Nothing is committed.
CLASS ltc_run DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_allowed     TYPE zprc_run_app_name VALUE 'ZPRC_AUTH_APP_A'.
    CONSTANTS c_not_allowed TYPE zprc_run_app_name VALUE 'ZPRC_AUTH_APP_B'.

    METHODS teardown.

    METHODS create_unauthorized        FOR TESTING.
    METHODS create_authorized          FOR TESTING.
    METHODS create_privileged          FOR TESTING.
    METHODS initiate_unauthorized      FOR TESTING.
    METHODS update_unauthorized        FOR TESTING.
    METHODS update_authorized          FOR TESTING.
    METHODS trigger_event_unauthorized FOR TESTING.
    METHODS delete_unauthorized        FOR TESTING.
    METHODS delete_authorized          FOR TESTING.

    "! Creates a run in privileged mode (transactional buffer only)
    METHODS _create_privileged
      IMPORTING i_application_name TYPE zprc_run_app_name
      RETURNING VALUE(r_uuid)      TYPE sysuuid_x16.
ENDCLASS.


CLASS ltc_run IMPLEMENTATION.
  METHOD teardown.
    ROLLBACK ENTITIES.
    lcl_auth=>reset( ).
  ENDMETHOD.

  METHOD _create_privileged.
    MODIFY ENTITIES OF zr_prc_runtp PRIVILEGED
           ENTITY Run
           CREATE FIELDS ( ApplicationName JobName )
           WITH VALUE #( ( %cid = 'CID' ApplicationName = i_application_name JobName = 'AUTH_TEST' ) )
           MAPPED DATA(mapped)
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = 'Privileged create failed' ).
    r_uuid = mapped-run[ 1 ]-uuid.
  ENDMETHOD.

  METHOD create_unauthorized.
    lcl_auth=>restrict( i_object = 'ZPRC_RUN' i_field = 'ZPRCRUNAPP' i_value = c_allowed i_activity = '01' ).

    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           CREATE FIELDS ( ApplicationName JobName )
           WITH VALUE #( ( %cid = 'CID' ApplicationName = c_not_allowed JobName = 'AUTH_TEST' ) )
           MAPPED DATA(mapped)
           FAILED DATA(failed)
           REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial( act = failed-run
                                             msg = 'Create must fail without ZPRC_RUN 01' ).
    cl_abap_unit_assert=>assert_initial( act = mapped-run
                                         msg = 'No instance expected' ).
    cl_abap_unit_assert=>assert_equals( act = reported-run[ 1 ]-%msg->if_t100_message~t100key-msgno
                                        exp = '003'
                                        msg = 'Message ZPRC_PROCESS_MESSAGE/003 expected' ).
  ENDMETHOD.

  METHOD create_authorized.
    lcl_auth=>restrict( i_object = 'ZPRC_RUN' i_field = 'ZPRCRUNAPP' i_value = c_allowed i_activity = '01' ).

    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           CREATE FIELDS ( ApplicationName JobName )
           WITH VALUE #( ( %cid = 'CID' ApplicationName = c_allowed JobName = 'AUTH_TEST' ) )
           MAPPED DATA(mapped)
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = 'Create must succeed with ZPRC_RUN 01' ).
    cl_abap_unit_assert=>assert_not_initial( act = mapped-run
                                             msg = 'Instance expected' ).
  ENDMETHOD.

  METHOD create_privileged.
    lcl_auth=>restrict( i_object = 'ZPRC_RUN' i_field = 'ZPRCRUNAPP' i_value = c_allowed i_activity = '03' ).

    cl_abap_unit_assert=>assert_not_initial( act = _create_privileged( c_not_allowed )
                                             msg = 'Privileged create must succeed without authorization' ).
  ENDMETHOD.

  METHOD initiate_unauthorized.
    " Only the negative case: a successful initiateRun registers a job for the save phase
    lcl_auth=>restrict( i_object = 'ZPRC_RUN' i_field = 'ZPRCRUNAPP' i_value = c_allowed i_activity = '01' ).

    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           EXECUTE initiateRun
           FROM VALUE #( ( %cid   = 'CID'
                           %param = VALUE #( applicationName    = c_not_allowed
                                             jobName            = 'AUTH_TEST'
                                             jobTemplateName    = 'AUTH_TEST'
                                             selectOptionString = '[]' ) ) )
           MAPPED DATA(mapped)
           FAILED DATA(failed)
           REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial( act = failed-run
                                             msg = 'initiateRun must fail without ZPRC_RUN 01' ).
    cl_abap_unit_assert=>assert_initial( act = mapped-run
                                         msg = 'No instance expected' ).
    cl_abap_unit_assert=>assert_equals( act = reported-run[ 1 ]-%msg->if_t100_message~t100key-msgno
                                        exp = '003'
                                        msg = 'Message ZPRC_PROCESS_MESSAGE/003 expected' ).
  ENDMETHOD.

  METHOD update_unauthorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_RUN' i_field = 'ZPRCRUNAPP' i_value = c_allowed i_activity = '03' ).

    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           UPDATE FIELDS ( JobName )
           WITH VALUE #( ( uuid = uuid JobName = 'CHANGED' ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-run
                                             msg = 'Update must fail without ZPRC_RUN 02' ).
  ENDMETHOD.

  METHOD update_authorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_RUN' i_field = 'ZPRCRUNAPP' i_value = c_allowed i_activity = '02' ).

    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           UPDATE FIELDS ( JobName )
           WITH VALUE #( ( uuid = uuid JobName = 'CHANGED' ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = 'Update must succeed with ZPRC_RUN 02' ).
  ENDMETHOD.

  METHOD trigger_event_unauthorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_RUN' i_field = 'ZPRCRUNAPP' i_value = c_allowed i_activity = '03' ).

    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           EXECUTE triggerChangedEvent
           FROM VALUE #( ( uuid = uuid ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-run
                                             msg = 'triggerChangedEvent must fail without ZPRC_RUN 02' ).
  ENDMETHOD.

  METHOD delete_unauthorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_RUN' i_field = 'ZPRCRUNAPP' i_value = c_allowed i_activity = '03' ).

    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           DELETE FROM VALUE #( ( uuid = uuid ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-run
                                             msg = 'Delete must fail without ZPRC_RUN 06' ).
  ENDMETHOD.

  METHOD delete_authorized.
    DATA(uuid) = _create_privileged( c_allowed ).
    lcl_auth=>restrict( i_object = 'ZPRC_RUN' i_field = 'ZPRCRUNAPP' i_value = c_allowed i_activity = '06' ).

    MODIFY ENTITIES OF zr_prc_runtp
           ENTITY Run
           DELETE FROM VALUE #( ( uuid = uuid ) )
           FAILED DATA(failed).

    cl_abap_unit_assert=>assert_initial( act = failed
                                         msg = 'Delete must succeed with ZPRC_RUN 06' ).
  ENDMETHOD.
ENDCLASS.


"! DCL of the runs: only runs of authorized applications are visible
CLASS ltc_dcl_run DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA environment TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS only_authorized_application FOR TESTING.
    METHODS no_authorization_no_runs    FOR TESTING.

    METHODS _enable_access_control
      IMPORTING i_application_name TYPE csequence
                i_activity         TYPE csequence.
ENDCLASS.


CLASS ltc_dcl_run IMPLEMENTATION.
  METHOD class_setup.
    " The base view of all run views, it reads ZPRC_RUN directly
    environment = cl_cds_test_environment=>create( i_for_entity = 'ZI_PRC_RUN' ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    environment->get_access_control_double( )->disable_access_control( ).

    DATA lt_run TYPE STANDARD TABLE OF zprc_run WITH EMPTY KEY.
    lt_run = VALUE #( ( uuid = '000000000000000000000000000000A1' app_name = 'ZPRC_AUTH_APP_A' )
                      ( uuid = '000000000000000000000000000000B1' app_name = 'ZPRC_AUTH_APP_B' ) ).
    environment->insert_test_data( lt_run ).
  ENDMETHOD.

  METHOD _enable_access_control.
    environment->get_access_control_double( )->enable_access_control(
        cl_cds_test_data=>create_access_control_data(
            VALUE #( ( object         = 'ZPRC_RUN'
                       authorizations = VALUE #(
                           ( VALUE #( ( fieldname   = 'ZPRCRUNAPP'
                                        fieldvalues = VALUE #( ( lower_value = i_application_name ) ) )
                                      ( fieldname   = 'ACTVT'
                                        fieldvalues = VALUE #( ( lower_value = i_activity ) ) ) ) ) ) ) ) ) ).
  ENDMETHOD.

  METHOD only_authorized_application.
    _enable_access_control( i_application_name = 'ZPRC_AUTH_APP_A' i_activity = '03' ).

    SELECT ApplicationName FROM zi_prc_run INTO TABLE @DATA(lt_result).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_result )
                                        exp = 1
                                        msg = 'Only the run of the authorized application expected' ).
    cl_abap_unit_assert=>assert_equals( act = lt_result[ 1 ]-ApplicationName
                                        exp = 'ZPRC_AUTH_APP_A'
                                        msg = 'Wrong application' ).
  ENDMETHOD.

  METHOD no_authorization_no_runs.
    " Delete (06) does not grant display (03)
    _enable_access_control( i_application_name = 'ZPRC_AUTH_APP_A' i_activity = '06' ).

    SELECT ApplicationName FROM zi_prc_run INTO TABLE @DATA(lt_result).

    cl_abap_unit_assert=>assert_initial( act = lt_result
                                         msg = 'No run expected without ZPRC_RUN 03' ).
  ENDMETHOD.
ENDCLASS.
