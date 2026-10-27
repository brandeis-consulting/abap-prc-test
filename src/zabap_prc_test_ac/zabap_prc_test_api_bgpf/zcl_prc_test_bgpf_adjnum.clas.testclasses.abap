"! adjust_numbers ruft die API direkt (Phase SAVE, kein klassifizierter Aufruf dazwischen).
"! Erwartet: gruen.
CLASS ltc_adjust_numbers_bgpf DEFINITION FINAL
  FOR TESTING RISK LEVEL harmless DURATION MEDIUM.

  PRIVATE SECTION.
    TYPES ty_id     TYPE zr_prc_test_bgpf-ID.
    TYPES ty_ext_id TYPE zr_prc_processedobject-ExternalProcessedObjectID.

    DATA mt_created_ids TYPE STANDARD TABLE OF ty_id WITH EMPTY KEY.

    METHODS teardown.

    METHODS instance_processed_via_bgpf FOR TESTING.
ENDCLASS.


"! Kontrolle: derselbe API-Aufruf im bgPF-Modus, aber ausserhalb der RAP-Save-Sequenz.
CLASS ltc_control_bgpf_direct DEFINITION FINAL
  FOR TESTING RISK LEVEL harmless DURATION MEDIUM.

  PRIVATE SECTION.
    METHODS teardown.
    METHODS processed_via_bgpf_directly FOR TESTING.
ENDCLASS.


"! Gemeinsame Hilfsroutinen
CLASS lcl_helper DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES ty_id     TYPE zr_prc_test_bgpf-ID.
    TYPES ty_ext_id TYPE zr_prc_processedobject-ExternalProcessedObjectID.
    TYPES tt_id     TYPE STANDARD TABLE OF ty_id WITH EMPTY KEY.

    CONSTANTS c_max_wait_cycles TYPE i VALUE 20.   " 20 x 0,5 s = 10 s

    "! Legt per EML eine Instanz von ZR_PRC_Test_Bgpf an und committet.
    CLASS-METHODS create_instance
      RETURNING VALUE(r_id) TYPE ty_id.

    "! Prueft: Instanz gespeichert, Processed Object FINISHED, Nachricht "performed" vorhanden.
    CLASS-METHODS assert_instance_processed
      IMPORTING i_id TYPE ty_id.

    CLASS-METHODS wait_for_finished
      IMPORTING i_ext_id       TYPE ty_ext_id
                i_max_cycles   TYPE i DEFAULT c_max_wait_cycles
      RETURNING VALUE(r_state) TYPE zif_prc_process=>ty_state.

    CLASS-METHODS assert_performed_message
      IMPORTING i_ext_id TYPE ty_ext_id.

    "! Wartet auf die bgPF-Verarbeitung und loescht dann BO-Instanzen und Processed Objects.
    CLASS-METHODS cleanup
      IMPORTING it_ids TYPE tt_id OPTIONAL.
ENDCLASS.


CLASS lcl_helper IMPLEMENTATION.

  METHOD create_instance.
    MODIFY ENTITIES OF zr_prc_test_bgpf
           ENTITY TestBgpf
           CREATE FROM VALUE #( ( %cid = 'NEW_1' ) )
           MAPPED DATA(ls_mapped)
           FAILED DATA(ls_failed)
           REPORTED DATA(ls_reported) ##NEEDED.

    cl_abap_unit_assert=>assert_initial( act = ls_failed
                                         msg = 'CREATE fehlgeschlagen' ).

    DATA(lv_pid) = ls_mapped-testbgpf[ 1 ]-%pid.
    DATA ls_final_key TYPE STRUCTURE FOR KEY OF zr_prc_test_bgpf.

    COMMIT ENTITIES BEGIN
           RESPONSE OF zr_prc_test_bgpf
           FAILED DATA(ls_commit_failed)
           REPORTED DATA(ls_commit_reported) ##NEEDED.

      CONVERT KEY OF zr_prc_test_bgpf
              FROM lv_pid
              TO ls_final_key.

    COMMIT ENTITIES END.

    cl_abap_unit_assert=>assert_initial( act = ls_commit_failed
                                         msg = 'COMMIT ENTITIES fehlgeschlagen' ).

    r_id = ls_final_key-ID.
  ENDMETHOD.

  METHOD assert_instance_processed.
    cl_abap_unit_assert=>assert_not_initial( act = i_id
                                             msg = 'Keine finale ID aus adjust_numbers erhalten' ).
    SELECT SINGLE @abap_true FROM zr_prc_test_bgpf WHERE ID = @i_id INTO @DATA(lv_exists).
    cl_abap_unit_assert=>assert_true( act = lv_exists
                                      msg = |BO-Instanz { i_id } wurde nicht gespeichert| ).

    DATA(lv_ext_id) = CONV ty_ext_id( i_id ).
    DATA(lv_state) = wait_for_finished( lv_ext_id ).

    cl_abap_unit_assert=>assert_equals( act = lv_state
                                        exp = zif_prc_process=>co_finished
                                        msg = |Processed Object { lv_ext_id } nicht FINISHED (Status: { lv_state })| ).

    assert_performed_message( lv_ext_id ).
  ENDMETHOD.

  METHOD wait_for_finished.
    DO i_max_cycles TIMES.
      SELECT SINGLE State FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
        WHERE ProcessName               = @zcl_prc_test_bgpf_proc=>co_process_name
          AND ExternalProcessedObjectID = @i_ext_id
        INTO @r_state.
      IF r_state = zif_prc_process=>co_finished.
        RETURN.
      ENDIF.
      WAIT UP TO '0.5' SECONDS.
    ENDDO.
  ENDMETHOD.

  METHOD assert_performed_message.
    SELECT SINGLE UUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName               = @zcl_prc_test_bgpf_proc=>co_process_name
        AND ExternalProcessedObjectID = @i_ext_id
      INTO @DATA(lv_uuid).

    SELECT COUNT( * ) FROM zr_prc_processedmessage WITH PRIVILEGED ACCESS
      WHERE ProcessedObjectUUID = @lv_uuid
        AND MessageClass        = 'ZPRC_TEST_BGPF'
        AND MessageNumber       = '001'
      INTO @DATA(lv_count).

    cl_abap_unit_assert=>assert_differs( act = lv_count
                                         exp = 0
                                         msg = |Nachricht ZPRC_TEST_BGPF/001 (performed) fehlt fuer { i_ext_id }| ).
  ENDMETHOD.

  METHOD cleanup.
    IF it_ids IS NOT INITIAL.
      " Erst auf die bgPF-Verarbeitung warten, sonst laeuft die Unit spaeter auf ein
      " geloeschtes Processed Object und dumpt in der bgRFC-Session (ASSERTION_FAILED)
      LOOP AT it_ids INTO DATA(lv_id).
        wait_for_finished( CONV #( lv_id ) ).
      ENDLOOP.

      MODIFY ENTITIES OF zr_prc_test_bgpf
             ENTITY TestBgpf
             DELETE FROM VALUE #( FOR lv_del IN it_ids ( ID = lv_del ) ).
      COMMIT ENTITIES.
    ENDIF.

    " Technisches Aufraeumen der Testdaten: ohne Berechtigungspruefung
    SELECT UUID FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      WHERE ProcessName = @zcl_prc_test_bgpf_proc=>co_process_name
      INTO TABLE @DATA(lt_existing).
    CHECK lt_existing IS NOT INITIAL.

    MODIFY ENTITIES OF zr_prc_processedobjecttp PRIVILEGED
           ENTITY ProcessedObject
           DELETE FROM VALUE #( FOR k IN lt_existing ( %key-uuid = k-uuid ) ).
    COMMIT ENTITIES.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_adjust_numbers_bgpf IMPLEMENTATION.

  METHOD instance_processed_via_bgpf.
    DATA(lv_id) = lcl_helper=>create_instance( ).
    INSERT lv_id INTO TABLE mt_created_ids.

    lcl_helper=>assert_instance_processed( lv_id ).
  ENDMETHOD.

  METHOD teardown.
    lcl_helper=>cleanup( mt_created_ids ).
    CLEAR mt_created_ids.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_control_bgpf_direct IMPLEMENTATION.

  METHOD processed_via_bgpf_directly.
    GET TIME STAMP FIELD DATA(lv_ts).
    DATA(lv_ext_id) = CONV lcl_helper=>ty_ext_id( |CTRL{ lv_ts }| ).

    zcl_prc_processing_api=>get_instance( )->create_processed_objects(
        i_create_processed_objects = VALUE #( ( processName      = zcl_prc_test_bgpf_proc=>co_process_name
                                                factoryClassName = zcl_prc_test_bgpf_proc=>co_class_name
                                                processedObject  = lv_ext_id ) )
        i_perform_commit           = abap_false
        i_trigger_processing       = zcl_prc_processing_api=>execution_mode-bgpf_execution ).
    COMMIT WORK AND WAIT.

    DATA(lv_state) = lcl_helper=>wait_for_finished( lv_ext_id ).

    cl_abap_unit_assert=>assert_equals( act = lv_state
                                        exp = zif_prc_process=>co_finished
                                        msg = |Kontrolle: { lv_ext_id } nicht FINISHED (Status: { lv_state })| ).

    lcl_helper=>assert_performed_message( lv_ext_id ).
  ENDMETHOD.

  METHOD teardown.
    lcl_helper=>cleanup( ).
  ENDMETHOD.

ENDCLASS.
