"! Link of processed objects: per row via the process loader, so a class that
"! cannot be loaded leaves the row empty instead of aborting the list.
CLASS ltc_processed_object DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_original,
             factoryclassname            TYPE zr_prc_processedobject-FactoryClassName,
             externalprocessedobjectid   TYPE zr_prc_processedobject-ExternalProcessedObjectID,
             externalprocessedobjectuuid TYPE zr_prc_processedobject-ExternalProcessedObjectUUID,
           END OF ty_original,
           tt_original TYPE STANDARD TABLE OF ty_original WITH EMPTY KEY.
    TYPES: BEGIN OF ty_calculated,
             link TYPE string,
           END OF ty_calculated,
           tt_calculated TYPE STANDARD TABLE OF ty_calculated WITH EMPTY KEY.

    CONSTANTS co_unknown_class TYPE zprc_process_impl_class VALUE 'ZCL_PRC_DOES_NOT_EXIST'.

    DATA original   TYPE tt_original.
    DATA calculated TYPE tt_calculated.

    METHODS setup.
    METHODS link_per_row          FOR TESTING.
    METHODS link_requested_fields FOR TESTING.
ENDCLASS.


CLASS ltc_processed_object IMPLEMENTATION.

  METHOD setup.
    " Row 2 has a class that cannot be loaded (same path as a syntax error)
    original = VALUE #( ( factoryclassname = zcl_prc_test_proc_fixture=>co_factory externalprocessedobjectid = 'OBJ1' )
                        ( factoryclassname = co_unknown_class                      externalprocessedobjectid = 'OBJ2' )
                        ( factoryclassname = zcl_prc_test_proc_fixture=>co_factory externalprocessedobjectid = 'OBJ3' ) ).
    calculated = VALUE #( ( ) ( ) ( ) ).
  ENDMETHOD.


  METHOD link_per_row.
    TRY.
        CAST if_sadl_exit_calc_element_read( NEW zcl_prc_proc_obj_link( ) )->calculate(
          EXPORTING it_original_data           = original
                    it_requested_calc_elements = VALUE #( ( `LINK` ) )
          CHANGING  ct_calculated_data         = calculated ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = error->get_text( ) ).
    ENDTRY.

    cl_abap_unit_assert=>assert_equals( act = calculated[ 1 ]-link exp = `#PRC_Test-show?Object=OBJ1` ).
    cl_abap_unit_assert=>assert_initial( act = calculated[ 2 ]-link msg = 'Class cannot be loaded: no link, no dump' ).
    cl_abap_unit_assert=>assert_equals( act = calculated[ 3 ]-link exp = `#PRC_Test-show?Object=OBJ3`
                                        msg = 'Rows after a broken one still get their link' ).
  ENDMETHOD.


  METHOD link_requested_fields.
    DATA requested TYPE if_sadl_exit_calc_element_read=>tt_elements.
    TRY.
        CAST if_sadl_exit_calc_element_read( NEW zcl_prc_proc_obj_link( ) )->get_calculation_info(
          EXPORTING it_requested_calc_elements = VALUE #( ( `LINK` ) )
                    iv_entity                  = 'ZC_PRC_PROCESSEDOBJECTTP'
          IMPORTING et_requested_orig_elements = requested ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = error->get_text( ) ).
    ENDTRY.
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( requested[ table_line = `FACTORYCLASSNAME` ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( requested[ table_line = `EXTERNALPROCESSEDOBJECTID` ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( requested[ table_line = `EXTERNALPROCESSEDOBJECTUUID` ] ) ) ).
  ENDMETHOD.

ENDCLASS.


"! Message text in the logon language: from the message fields of a row, as persisted
"! for free text, and for processed objects from the header of the latest step.
CLASS ltc_message_text DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_message_row,
             messageclass     TYPE symsgid,
             messagenumber    TYPE symsgno,
             messagevariable1 TYPE symsgv,
             messagevariable2 TYPE symsgv,
             messagevariable3 TYPE symsgv,
             messagevariable4 TYPE symsgv,
             messagetext      TYPE zprc_message_text,
           END OF ty_message_row,
           tt_message_rows TYPE STANDARD TABLE OF ty_message_row WITH EMPTY KEY.
    TYPES: BEGIN OF ty_object_row,
             lateststepuuid TYPE sysuuid_x16,
             messagetext    TYPE zprc_message_text,
           END OF ty_object_row,
           tt_object_rows TYPE STANDARD TABLE OF ty_object_row WITH EMPTY KEY.
    TYPES: BEGIN OF ty_calculated,
             messagetexttranslated TYPE zprc_message_text,
           END OF ty_calculated,
           tt_calculated TYPE STANDARD TABLE OF ty_calculated WITH EMPTY KEY.

    METHODS teardown.
    METHODS translates_message_fields FOR TESTING.
    METHODS header_of_latest_step     FOR TESTING.
    METHODS requested_fields          FOR TESTING.

    METHODS calculate IMPORTING i_original          TYPE STANDARD TABLE
                      RETURNING VALUE(r_calculated) TYPE tt_calculated.
ENDCLASS.


CLASS ltc_message_text IMPLEMENTATION.

  METHOD teardown.
    zcl_prc_test_proc_fixture=>delete_own_data( ).
  ENDMETHOD.


  METHOD translates_message_fields.
    MESSAGE ID 'ZPRC_RUN' TYPE 'I' NUMBER '010' WITH 'TEMPLATE' INTO DATA(expected).

    DATA(calculated) = calculate( VALUE tt_message_rows(
        ( messageclass = 'ZPRC_RUN' messagenumber = '010' messagevariable1 = 'TEMPLATE' messagetext = 'Stored' )
        ( messageclass = 'SY'       messagenumber = '499' messagevariable1 = 'Free'     messagetext = 'Free text as stored' )
        ( messagetext = 'No message class' ) ) ).

    cl_abap_unit_assert=>assert_equals( act = calculated[ 1 ]-messagetexttranslated exp = expected
                                        msg = 'T100: text in the logon language' ).
    cl_abap_unit_assert=>assert_equals( act = calculated[ 2 ]-messagetexttranslated exp = 'Free text as stored' ).
    cl_abap_unit_assert=>assert_equals( act = calculated[ 3 ]-messagetexttranslated exp = 'No message class' ).
  ENDMETHOD.


  METHOD header_of_latest_step.
    " A failed object: its latest step has an error header
    zcl_prc_test_proc_fixture=>delete_own_data( ).
    DATA(fixture) = NEW zcl_prc_test_proc_fixture( ).
    fixture->insert_given( VALUE #(
        objects = VALUE #( ( ref = 'O1' state = 'START' step_total = 3 payload = `{"START":{"FAIL":"X"}}` ) ) ) ).
    fixture->run( ).
    DATA(object_uuid) = fixture->uuid( `O1` ).
    SELECT SINGLE latest_step_uuid FROM zprc_proc_object WHERE uuid = @object_uuid INTO @DATA(latest_step).

    DATA(calculated) = calculate( VALUE tt_object_rows(
        ( lateststepuuid = latest_step messagetext = 'Stored text of the object' )
        ( lateststepuuid = fixture->uuid( `NO_STEP` ) messagetext = 'Stored text of the object' ) ) ).

    cl_abap_unit_assert=>assert_not_initial( act = calculated[ 1 ]-messagetexttranslated ).
    cl_abap_unit_assert=>assert_differs( act = calculated[ 1 ]-messagetexttranslated exp = 'Stored text of the object'
                                         msg = 'Text of the header of the latest step' ).
    cl_abap_unit_assert=>assert_equals( act = calculated[ 2 ]-messagetexttranslated exp = 'Stored text of the object'
                                        msg = 'No header found: as stored' ).
  ENDMETHOD.


  METHOD requested_fields.
    DATA requested TYPE if_sadl_exit_calc_element_read=>tt_elements.
    DATA(exit) = CAST if_sadl_exit_calc_element_read( NEW zcl_prc_message_text( ) ).
    TRY.
        exit->get_calculation_info( EXPORTING it_requested_calc_elements = VALUE #( ( `MESSAGETEXTTRANSLATED` ) )
                                              iv_entity                  = 'ZC_PRC_PROCESSEDOBJECTTP'
                                    IMPORTING et_requested_orig_elements = requested ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( requested[ table_line = `LATESTSTEPUUID` ] ) )
                                          msg = 'Processed object: latest step' ).

        CLEAR requested.
        exit->get_calculation_info( EXPORTING it_requested_calc_elements = VALUE #( ( `MESSAGETEXTTRANSLATED` ) )
                                              iv_entity                  = 'ZC_PRC_MESSAGETP'
                                    IMPORTING et_requested_orig_elements = requested ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( requested[ table_line = `MESSAGECLASS` ] ) )
                                          msg = 'Other entities: message fields' ).
        cl_abap_unit_assert=>assert_false( xsdbool( line_exists( requested[ table_line = `LATESTSTEPUUID` ] ) ) ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD calculate.
    r_calculated = VALUE #( FOR i = 1 UNTIL i > lines( i_original ) ( ) ).
    TRY.
        CAST if_sadl_exit_calc_element_read( NEW zcl_prc_message_text( ) )->calculate(
          EXPORTING it_original_data           = i_original
                    it_requested_calc_elements = VALUE #( ( `MESSAGETEXTTRANSLATED` ) )
          CHANGING  ct_calculated_data         = r_calculated ).
      CATCH cx_root INTO DATA(error).
        cl_abap_unit_assert=>fail( msg = error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
