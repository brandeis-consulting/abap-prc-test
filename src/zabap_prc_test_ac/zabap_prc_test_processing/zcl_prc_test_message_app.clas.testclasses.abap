"! Restricts the authorizations of the current user in the test session
CLASS lcl_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CLASS-METHODS restrict IMPORTING i_value TYPE csequence i_activity TYPE csequence.
    CLASS-METHODS reset.
ENDCLASS.

CLASS lcl_auth IMPLEMENTATION.
  METHOD restrict.
    DATA(authorization) = VALUE cl_aunit_auth_check_types_def=>authorization(
        ( fieldname = 'ZPRCNAME' fieldvalues = VALUE #( ( lower_value = i_value ) ) )
        ( fieldname = 'ACTVT'    fieldvalues = VALUE #( ( lower_value = i_activity ) ) ) ).
    DATA(auth_objset) = cl_aunit_authority_check=>create_auth_object_set(
        VALUE #( ( role_authorizations = VALUE #( ( object = 'ZPRC_PROC' authorizations = VALUE #( ( authorization ) ) ) )
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


"! Two objects failing with the same error form one message group.
"! Nothing of the resume is committed.
CLASS ltc_message_group DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.

  PRIVATE SECTION.
    DATA fixture TYPE REF TO zcl_prc_test_proc_fixture.
    DATA group   TYPE STRUCTURE FOR KEY OF zr_prc_messagetp.

    METHODS setup.
    METHODS teardown.

    METHODS group_counts_objects     FOR TESTING.
    METHODS group_remains_without_objects FOR TESTING.
    METHODS resume_resets_retry      FOR TESTING.
    METHODS resume_unauthorized      FOR TESTING.
    METHODS permission_from_objects  FOR TESTING.
ENDCLASS.


CLASS ltc_message_group IMPLEMENTATION.

  METHOD setup.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    fixture = NEW #( ).
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"FAIL":"X"}}` )
                           ( ref = 'O2' state = 'START' step_total = 3 payload = `{"START":{"FAIL":"X"}}` ) ) ) ).
    fixture->run( ).

    SELECT SINGLE * FROM zr_prc_messagetp WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name
      INTO @DATA(row).
    group = CORRESPONDING #( row ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
    lcl_auth=>reset( ).
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD group_counts_objects.
    SELECT ProcessName, MessageSeverity, AffectedObjectCount, HasAffectedObjects
      FROM zr_prc_messagetp WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name
      INTO TABLE @DATA(groups).

    cl_abap_unit_assert=>assert_equals( act = lines( groups ) exp = 1 msg = 'Same error, one group' ).
    cl_abap_unit_assert=>assert_equals( act = groups[ 1 ]-AffectedObjectCount exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = groups[ 1 ]-MessageSeverity exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = groups[ 1 ]-HasAffectedObjects exp = abap_true ).
  ENDMETHOD.


  METHOD group_remains_without_objects.
    " As after a resume: the error is no longer the header of the latest step of any
    " object. The group must stay readable (the event side effect re-reads it), with 0.
    DATA lv_other_step TYPE sysuuid_x16.
    lv_other_step = fixture->uuid( `OTHER_STEP` ).
    DATA(lv_o1) = fixture->uuid( `O1` ).
    DATA(lv_o2) = fixture->uuid( `O2` ).
    UPDATE zprc_proc_object SET latest_step_uuid = @lv_other_step
      WHERE uuid = @lv_o1 OR uuid = @lv_o2.

    SELECT AffectedObjectCount, HasAffectedObjects
      FROM zr_prc_messagetp WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_proc_fixture=>co_process_name
      INTO TABLE @DATA(groups).

    cl_abap_unit_assert=>assert_equals( act = lines( groups ) exp = 1 msg = 'Group must not vanish' ).
    cl_abap_unit_assert=>assert_equals( act = groups[ 1 ]-AffectedObjectCount exp = 0 ).
    cl_abap_unit_assert=>assert_initial( act = groups[ 1 ]-HasAffectedObjects msg = 'Hidden by the default filter' ).
  ENDMETHOD.


  METHOD resume_resets_retry.
    MODIFY ENTITIES OF zr_prc_messagetp
           ENTITY Message
           EXECUTE resumeProcessing FROM VALUE #( ( %key = group ) )
           FAILED DATA(failed)
           REPORTED DATA(reported) ##NEEDED.
    cl_abap_unit_assert=>assert_initial( act = failed msg = 'Resume of the group must succeed' ).

    READ ENTITIES OF zr_prc_processedobjecttp
         ENTITY ProcessedObject FIELDS ( RetryCount )
         WITH VALUE #( ( UUID = fixture->uuid( `O1` ) ) ( UUID = fixture->uuid( `O2` ) ) )
         RESULT DATA(objects).
    cl_abap_unit_assert=>assert_equals( act = lines( objects ) exp = 2 ).
    LOOP AT objects INTO DATA(object).
      cl_abap_unit_assert=>assert_equals( act = object-RetryCount exp = 0 msg = 'Every object of the group resumed' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD resume_unauthorized.
    " Display (03) of the process, but no resume (16)
    lcl_auth=>restrict( i_value = zcl_prc_test_proc_fixture=>co_process_name i_activity = '03' ).

    MODIFY ENTITIES OF zr_prc_messagetp
           ENTITY Message
           EXECUTE resumeProcessing FROM VALUE #( ( %key = group ) )
           FAILED DATA(failed)
           REPORTED DATA(reported) ##NEEDED.

    cl_abap_unit_assert=>assert_not_initial( act = failed-message msg = 'Resume must fail without ZPRC_PROC 16' ).
  ENDMETHOD.


  METHOD permission_from_objects.
    " Display (03) of the process, but no resume (16)
    lcl_auth=>restrict( i_value = zcl_prc_test_proc_fixture=>co_process_name i_activity = '03' ).

    GET PERMISSIONS ONLY INSTANCE AUTHORIZATION ENTITY zr_prc_messagetp
        FROM VALUE #( ( %key = group ) )
        REQUEST VALUE #( %action-resumeProcessing = if_abap_behv=>mk-on )
        RESULT DATA(permissions)
        FAILED DATA(failed) ##NEEDED
        REPORTED DATA(reported) ##NEEDED.

    " GET PERMISSIONS answers with perm-o-*, not with auth-*
    cl_abap_unit_assert=>assert_equals( act = permissions-instances[ 1 ]-%action-resumeProcessing
                                        exp = if_abap_behv=>perm-o-unauthorized
                                        msg = 'Group permission comes from its objects' ).
  ENDMETHOD.

ENDCLASS.
