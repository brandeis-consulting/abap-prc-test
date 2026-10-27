"! <p class="shorttext synchronized">PRC Test: Fixture for processing tests</p>
"!
"! Pure mechanics, no expectations: delete own data, insert the given state
"! directly into the PRC tables, trigger the processing and read the actual
"! state completely.
"!
"! Given and actual use the same structure (TY_DATA), so a test compares the
"! complete actual state with one ASSERT_EQUALS. Only non-deterministic values
"! are mapped to stable ones:
"! <ul>
"! <li>UUIDs: references - objects by external ID (O1), steps per object in
"!     creation order (S1, S2, ...), runs by the given reference (R1)</li>
"! <li>Timestamps (retry, not before): seconds relative to the start of the run,
"!     rounded to full minutes ('+300', '-60'); initial = ''</li>
"! <li>Process name and factory class of the fixture (constructor): ''</li>
"! <li>Admin fields: '' = unchanged / set correctly, 'CHANGED', 'MODIFIED',
"!     'MISSING' or 'INVALID'</li>
"! </ul>
"! <p class="shorttext synchronized">PRC Test: Fixture for processing tests</p>
"!
"! Pure mechanics, no expectations: delete own data, insert the given state
"! directly into the PRC tables, trigger the processing and read the actual
"! state completely.
"!
"! Given and actual use the same structure (TY_DATA), so a test compares the
"! complete actual state with one ASSERT_EQUALS. Only non-deterministic values
"! are mapped to stable ones:
"! <ul>
"! <li>UUIDs: references - objects by external ID (O1), steps per object in
"!     creation order (S1, S2, ...), runs by the given reference (R1)</li>
"! <li>Timestamps (retry, not before): seconds relative to the start of the run,
"!     rounded to full minutes ('+300', '-60'); initial = ''</li>
"! <li>Process name and factory class of the fixture (constructor): ''</li>
"! <li>Admin fields: '' = unchanged / set correctly, 'CHANGED', 'MODIFIED',
"!     'MISSING' or 'INVALID'</li>
"! </ul>
CLASS zcl_prc_test_proc_fixture DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  FOR TESTING.

  PUBLIC SECTION.
    CONSTANTS co_process_name       TYPE zprc_process_name       VALUE 'PRC_TEST_PROC'.
    CONSTANTS co_other_process_name TYPE zprc_process_name       VALUE 'PRC_TEST_PROC_OTHER'.
    CONSTANTS co_factory            TYPE zprc_process_impl_class VALUE 'ZCL_PRC_TEST_PROC_PROCESS'.

    TYPES: BEGIN OF ty_object,
             ref          TYPE string,
             process_name TYPE zprc_process_name,
             factory      TYPE zprc_process_impl_class,
             state        TYPE zprc_state,
             payload      TYPE string,
             queue_id     TYPE string,
             queue_pos    TYPE int8,
             not_before   TYPE string,
             retry_count  TYPE i,
             retry        TYPE string,
             mail         TYPE string,
             run          TYPE string,
             step_total   TYPE int8,
             latest_step  TYPE string,
             "! '' = creation data and external IDs unchanged, else MODIFIED
             created      TYPE string,
             "! '' = unchanged, CHANGED = changed by current user, else INVALID
             changed      TYPE string,
             "! '' = unchanged, CHANGED = changed, else INVALID
             etag         TYPE string,
           END OF ty_object,
           tt_objects TYPE SORTED TABLE OF ty_object WITH UNIQUE KEY ref.

    TYPES: BEGIN OF ty_step,
             object        TYPE string,
             ref           TYPE string,
             "! Position of the step in creation order within its queue;
             "! an object without queue counts on its own (packages run in parallel)
             seq           TYPE i,
             start_state   TYPE zprc_state,
             end_state     TYPE zprc_state,
             msgid         TYPE symsgid,
             msgno         TYPE symsgno,
             msgty         TYPE symsgty,
             msgv1         TYPE symsgv,
             msgv2         TYPE symsgv,
             msgv3         TYPE symsgv,
             msgv4         TYPE symsgv,
             text          TYPE string,
             severity_code TYPE i,
             "! '' = created by/at set, else MISSING
             created       TYPE string,
           END OF ty_step,
           tt_steps TYPE SORTED TABLE OF ty_step WITH UNIQUE KEY object ref.

    TYPES: BEGIN OF ty_message,
             object        TYPE string,
             step          TYPE string,
             msgid         TYPE symsgid,
             msgno         TYPE symsgno,
             msgty         TYPE symsgty,
             msgv1         TYPE symsgv,
             msgv2         TYPE symsgv,
             msgv3         TYPE symsgv,
             msgv4         TYPE symsgv,
             text          TYPE string,
             severity_code TYPE i,
             "! '' = created by/at set, else MISSING
             created       TYPE string,
           END OF ty_message,
           "! Sorted by key: messages are compared as a set per step, their order
           "! of arrival is not checked (the persistence does not keep it)
           tt_messages TYPE SORTED TABLE OF ty_message
                       WITH NON-UNIQUE KEY object step msgid msgno msgty msgv1 msgv2 msgv3 msgv4 text.

    TYPES: BEGIN OF ty_data,
             objects  TYPE tt_objects,
             steps    TYPE tt_steps,
             messages TYPE tt_messages,
           END OF ty_data.

    "! Deletes all objects (incl. steps, messages, runs) of I_PROCESS_NAME,
    "! or of CO_PROCESS_NAME and CO_OTHER_PROCESS_NAME if not supplied
    CLASS-METHODS delete_own_data IMPORTING i_process_name TYPE zprc_process_name OPTIONAL.

    "! @parameter i_process_name | Default process name of given objects (shown as '' in actual)
    "! @parameter i_factory      | Default factory class of given objects (shown as '' in actual)
    METHODS constructor IMPORTING i_process_name TYPE zprc_process_name       DEFAULT co_process_name
                                  i_factory      TYPE zprc_process_impl_class DEFAULT co_factory.

    "! Inserts the given state directly into the PRC tables and commits
    METHODS insert_given IMPORTING i_given TYPE ty_data.

    "! Processes the given objects synchronously (selection restricted to their UUIDs)
    METHODS run IMPORTING i_ignore_restart TYPE abap_bool DEFAULT abap_false
                          i_process_name   TYPE zprc_process_name OPTIONAL.

    "! Complete actual state of the given objects
    METHODS read_actual RETURNING VALUE(r_actual) TYPE ty_data.

    "! UUID of a given object or run reference
    METHODS uuid IMPORTING i_ref         TYPE string
                 RETURNING VALUE(r_uuid) TYPE sysuuid_x16.

    "! Reference of a given object or run UUID
    METHODS ref IMPORTING i_uuid       TYPE sysuuid_x16
                RETURNING VALUE(r_ref) TYPE string.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES tt_uuid_range TYPE RANGE OF sysuuid_x16.

    TYPES: BEGIN OF ty_key,
             ref  TYPE string,
             uuid TYPE sysuuid_x16,
           END OF ty_key.

    TYPES: BEGIN OF ty_step_map,
             uuid   TYPE sysuuid_x16,
             object TYPE string,
             ref    TYPE string,
           END OF ty_step_map.

    TYPES: BEGIN OF ty_counter,
             object TYPE string,
             count  TYPE i,
           END OF ty_counter.

    DATA mv_process_name TYPE zprc_process_name.
    DATA mv_factory      TYPE zprc_process_impl_class.
    DATA mt_keys    TYPE SORTED TABLE OF ty_key WITH UNIQUE KEY ref
                         WITH UNIQUE SORTED KEY by_uuid COMPONENTS uuid.
    DATA mt_objects TYPE tt_uuid_range.
    DATA mt_given   TYPE SORTED TABLE OF zprc_proc_object WITH UNIQUE KEY uuid.
    DATA mv_given_at TYPE timestampl.
    DATA mv_run_at   TYPE timestampl.
    DATA mv_user     TYPE syuname.

    METHODS key_uuid IMPORTING i_ref         TYPE string
                     RETURNING VALUE(r_uuid) TYPE sysuuid_x16.

    METHODS to_timestamp IMPORTING i_relative         TYPE string
                                   i_base             TYPE timestampl
                         RETURNING VALUE(r_timestamp) TYPE timestampl.

    METHODS to_relative IMPORTING i_timestamp       TYPE timestampl
                                  i_base            TYPE timestampl
                        RETURNING VALUE(r_relative) TYPE string.
ENDCLASS.



CLASS zcl_prc_test_proc_fixture IMPLEMENTATION.

  METHOD constructor.
    mv_process_name = i_process_name.
    mv_factory      = i_factory.
  ENDMETHOD.


  METHOD delete_own_data.
    DATA lt_names TYPE RANGE OF zprc_process_name.
    " One PRC test run per system at a time: the tests share the objects of the test
    " processes, a second run would delete the data of the first one. The lock is kept
    " across COMMIT WORK until the end of the session (scope 1 = dialog owner) on a
    " UUID that is never a processed object.
    STATICS sv_test_run_locked TYPE abap_bool.
    CONSTANTS lc_test_run_lock TYPE sysuuid_x16 VALUE 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'.

    IF sv_test_run_locked = abap_false.
      DATA(lv_test_run_lock) = lc_test_run_lock.
      TRY.
          cl_abap_lock_object_factory=>get_instance( iv_name = CONV #( zcl_prc_object_lock=>co_lock_object )
            )->enqueue( it_parameter = VALUE #( ( name = 'UUID' value = REF #( lv_test_run_lock ) ) )
                        _scope       = '1'
                        _wait        = abap_true ).
          sv_test_run_locked = abap_true.
        CATCH cx_abap_foreign_lock INTO DATA(lx_foreign).
          cl_abap_unit_assert=>abort( msg  = |Another PRC test run is active ({ lx_foreign->get_text( ) }) - run the tests again when it has finished|
                                      quit = if_abap_unit_constant=>quit-test ).
        CATCH cx_abap_lock_failure ##NO_HANDLER.
          " Lock object not available: run without protection
      ENDTRY.
    ENDIF.

    " Discard RAP changes left over by a previous test, so they are not
    " committed (and their events raised) within the next test
    ROLLBACK ENTITIES.

    IF i_process_name IS SUPPLIED.
      lt_names = VALUE #( ( sign = 'I' option = 'EQ' low = i_process_name ) ).
    ELSE.
      lt_names = VALUE #( ( sign = 'I' option = 'EQ' low = co_process_name )
                          ( sign = 'I' option = 'EQ' low = co_other_process_name ) ).
    ENDIF.

    SELECT uuid, run_uuid FROM zprc_proc_object
      WHERE process_name IN @lt_names
      INTO TABLE @DATA(lt_own).
    IF lt_own IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_objects) = VALUE tt_uuid_range( FOR o IN lt_own ( sign = 'I' option = 'EQ' low = o-uuid ) ).
    DATA(lt_runs)    = VALUE tt_uuid_range( FOR o IN lt_own WHERE ( run_uuid IS NOT INITIAL )
                                            ( sign = 'I' option = 'EQ' low = o-run_uuid ) ).

    DELETE FROM zprc_proc_msg    WHERE processed_object_uuid IN @lt_objects.
    DELETE FROM zprc_proc_step   WHERE processed_object_uuid IN @lt_objects.
    DELETE FROM zprc_proc_object WHERE uuid                  IN @lt_objects.
    IF lt_runs IS NOT INITIAL.
      DELETE FROM zprc_run WHERE uuid IN @lt_runs.
    ENDIF.
    COMMIT WORK.
  ENDMETHOD.


  METHOD insert_given.
    DATA lt_runs     TYPE STANDARD TABLE OF zprc_run         WITH EMPTY KEY.
    DATA lt_objects  TYPE STANDARD TABLE OF zprc_proc_object WITH EMPTY KEY.
    DATA lt_steps    TYPE STANDARD TABLE OF zprc_proc_step   WITH EMPTY KEY.
    DATA lt_messages TYPE STANDARD TABLE OF zprc_proc_msg    WITH EMPTY KEY.

    GET TIME STAMP FIELD mv_given_at.
    mv_run_at = mv_given_at.
    mv_user   = cl_abap_context_info=>get_user_technical_name( ).

    " Runs referenced by the objects
    LOOP AT i_given-objects INTO DATA(ls_object) WHERE run IS NOT INITIAL.
      DATA(lv_run_uuid) = key_uuid( ls_object-run ).
      IF NOT line_exists( lt_runs[ uuid = lv_run_uuid ] ).
        APPEND VALUE #( uuid = lv_run_uuid created_by = mv_user ) TO lt_runs.
      ENDIF.
    ENDLOOP.

    " Steps in the order of SEQ, all older than the given objects
    DATA lt_steps_by_seq TYPE STANDARD TABLE OF ty_step WITH EMPTY KEY.
    lt_steps_by_seq = i_given-steps.
    SORT lt_steps_by_seq BY seq.
    DATA(lv_step_count) = lines( lt_steps_by_seq ).
    LOOP AT lt_steps_by_seq INTO DATA(ls_step).
      DATA(lv_index) = sy-tabix.
      APPEND VALUE #( step_uuid             = key_uuid( |{ ls_step-object }/{ ls_step-ref }| )
                      processed_object_uuid = key_uuid( ls_step-object )
                      start_state           = ls_step-start_state
                      end_state             = ls_step-end_state
                      created_by            = mv_user
                      created_at            = cl_abap_tstmp=>add( tstmp = mv_given_at
                                                                  secs  = ( lv_index - lv_step_count - 1 ) * 60 ) )
             TO lt_steps.
    ENDLOOP.

    " Messages of the given steps
    LOOP AT i_given-messages INTO DATA(ls_message).
      DATA(lv_step_uuid) = key_uuid( |{ ls_message-object }/{ ls_message-step }| ).
      APPEND VALUE #( uuid                  = key_uuid( |{ ls_message-object }/{ ls_message-step }/M{ sy-tabix }| )
                      processed_step_uuid   = lv_step_uuid
                      processed_object_uuid = key_uuid( ls_message-object )
                      message_text          = ls_message-text
                      msgid                 = ls_message-msgid
                      msgno                 = ls_message-msgno
                      msgty                 = ls_message-msgty
                      msgv1                 = ls_message-msgv1
                      msgv2                 = ls_message-msgv2
                      msgv3                 = ls_message-msgv3
                      msgv4                 = ls_message-msgv4
                      message_severity_code = ls_message-severity_code
                      created_by            = mv_user
                      created_at            = VALUE #( lt_steps[ step_uuid = lv_step_uuid ]-created_at OPTIONAL ) )
             TO lt_messages.
    ENDLOOP.

    " Step headers live in the message table (IsHeader = 'X'): the last given message of
    " the step equal to the header is marked, otherwise the header is added as own
    " message, created by 'PRC_FIXTURE' (READ_ACTUAL does not report those back)
    LOOP AT lt_steps_by_seq INTO ls_step WHERE msgid IS NOT INITIAL OR text IS NOT INITIAL.
      DATA(lv_header_step) = key_uuid( |{ ls_step-object }/{ ls_step-ref }| ).
      DATA(lv_header_index) = 0.
      LOOP AT lt_messages INTO DATA(ls_candidate) WHERE processed_step_uuid = lv_header_step
                                                    AND msgid               = ls_step-msgid
                                                    AND msgno               = ls_step-msgno
                                                    AND msgty               = ls_step-msgty
                                                    AND msgv1               = ls_step-msgv1
                                                    AND msgv2               = ls_step-msgv2
                                                    AND msgv3               = ls_step-msgv3
                                                    AND msgv4               = ls_step-msgv4
                                                    AND message_text        = ls_step-text.
        lv_header_index = sy-tabix.
      ENDLOOP.
      IF lv_header_index > 0.
        lt_messages[ lv_header_index ]-is_header = abap_true.
      ELSE.
        APPEND VALUE #( uuid                  = key_uuid( |{ ls_step-object }/{ ls_step-ref }/H| )
                        processed_step_uuid   = lv_header_step
                        processed_object_uuid = key_uuid( ls_step-object )
                        message_text          = ls_step-text
                        msgid                 = ls_step-msgid
                        msgno                 = ls_step-msgno
                        msgty                 = ls_step-msgty
                        msgv1                 = ls_step-msgv1
                        msgv2                 = ls_step-msgv2
                        msgv3                 = ls_step-msgv3
                        msgv4                 = ls_step-msgv4
                        message_severity_code = ls_step-severity_code
                        is_header             = abap_true
                        created_by            = 'PRC_FIXTURE'
                        created_at            = VALUE #( lt_steps[ step_uuid = lv_header_step ]-created_at OPTIONAL ) )
               TO lt_messages.
      ENDIF.
    ENDLOOP.

    " Objects
    LOOP AT i_given-objects INTO ls_object.
      DATA(lv_uuid) = key_uuid( ls_object-ref ).
      INSERT VALUE #( sign = 'I' option = 'EQ' low = lv_uuid ) INTO TABLE mt_objects.
      APPEND VALUE #( uuid                      = lv_uuid
                      latest_step_uuid          = COND #( WHEN ls_object-latest_step IS NOT INITIAL
                                                          THEN key_uuid( |{ ls_object-ref }/{ ls_object-latest_step }| ) )
                      process_name              = COND #( WHEN ls_object-process_name IS INITIAL
                                                          THEN mv_process_name
                                                          ELSE ls_object-process_name )
                      run_uuid                  = COND #( WHEN ls_object-run IS NOT INITIAL
                                                          THEN key_uuid( ls_object-run ) )
                      mail_address              = ls_object-mail
                      factory_class_name        = COND #( WHEN ls_object-factory IS INITIAL
                                                          THEN mv_factory
                                                          ELSE ls_object-factory )
                      ext_processed_object_id   = ls_object-ref
                      ext_processed_object_uuid = lv_uuid
                      payload_json              = ls_object-payload
                      state                     = ls_object-state
                      step_total                = ls_object-step_total
                      retry_datetime            = to_timestamp( i_relative = ls_object-retry      i_base = mv_given_at )
                      retry_count               = ls_object-retry_count
                      do_not_process_before     = to_timestamp( i_relative = ls_object-not_before i_base = mv_given_at )
                      queue_id                  = ls_object-queue_id
                      queue_pos                 = ls_object-queue_pos
                      created_by                = mv_user
                      created_at                = mv_given_at
                      last_changed_at           = mv_given_at
                      last_changed_by           = mv_user
                      local_last_changed_at     = mv_given_at )
             TO lt_objects.
    ENDLOOP.

    INSERT zprc_run         FROM TABLE @lt_runs.
    INSERT zprc_proc_step   FROM TABLE @lt_steps.
    INSERT zprc_proc_msg    FROM TABLE @lt_messages.
    INSERT zprc_proc_object FROM TABLE @lt_objects.
    mt_given = lt_objects.
    COMMIT WORK.
  ENDMETHOD.


  METHOD run.
    DATA lt_parameters TYPE if_apj_rt_exec_object=>tt_templ_val.

    LOOP AT mt_objects INTO DATA(ls_object).
      APPEND VALUE #( selname = zcl_prc_retry_job=>s_uuid
                      kind    = 'S'
                      sign    = 'I'
                      option  = 'EQ'
                      low     = ls_object-low ) TO lt_parameters.
    ENDLOOP.
    IF i_process_name IS NOT INITIAL.
      APPEND VALUE #( selname = zcl_prc_retry_job=>c_process_name
                      kind    = 'S'
                      sign    = 'I'
                      option  = 'EQ'
                      low     = i_process_name ) TO lt_parameters.
    ENDIF.
    IF i_ignore_restart = abap_true.
      APPEND VALUE #( selname = zcl_prc_retry_job=>p_ignore_restart
                      kind    = 'P'
                      low     = abap_true ) TO lt_parameters.
    ENDIF.

    GET TIME STAMP FIELD mv_run_at.
    zcl_prc_processing_api=>get_instance( )->process_synchronously( lt_parameters ).
  ENDMETHOD.


  METHOD read_actual.
    DATA lt_step_map    TYPE HASHED TABLE OF ty_step_map WITH UNIQUE KEY uuid.
    DATA lt_counter     TYPE SORTED TABLE OF ty_counter WITH UNIQUE KEY object.
    DATA lt_seq_counter TYPE SORTED TABLE OF ty_counter WITH UNIQUE KEY object.

    IF mt_objects IS INITIAL.
      RETURN.
    ENDIF.

    SELECT * FROM zprc_proc_object WHERE uuid IN @mt_objects
      INTO TABLE @DATA(lt_objects).

    DATA lt_steps TYPE STANDARD TABLE OF zprc_proc_step WITH EMPTY KEY.
    SELECT * FROM zprc_proc_step WHERE processed_object_uuid IN @mt_objects
      ORDER BY created_at, step_uuid
      INTO TABLE @lt_steps.

    " One save writes all its steps with the same time stamp (ZCL_PRC_DB_WRITER), so the
    " time stamp alone does not order them (sporadic failures of ORDER_BY_POSITION).
    " Ties: queue position of the object, then the state chain within the object
    " (a step starts where its predecessor of the same save ended).
    TYPES: BEGIN OF ty_sorted_step,
             created_at TYPE zprc_proc_step-created_at,
             queue_pos  TYPE zprc_proc_object-queue_pos,
             object     TYPE sysuuid_x16,
             chain      TYPE i,
             step       TYPE zprc_proc_step,
           END OF ty_sorted_step.
    DATA lt_sorted TYPE STANDARD TABLE OF ty_sorted_step WITH EMPTY KEY.
    LOOP AT lt_steps INTO DATA(ls_db_step).
      APPEND VALUE #( created_at = ls_db_step-created_at
                      queue_pos  = VALUE #( lt_objects[ uuid = ls_db_step-processed_object_uuid ]-queue_pos OPTIONAL )
                      object     = ls_db_step-processed_object_uuid
                      step       = ls_db_step ) TO lt_sorted.
    ENDLOOP.
    LOOP AT lt_sorted ASSIGNING FIELD-SYMBOL(<ls_sorted>).
      DATA(lv_start) = <ls_sorted>-step-start_state.
      DO lines( lt_sorted ) TIMES.
        DATA(lv_found) = abap_false.
        LOOP AT lt_sorted INTO DATA(ls_pred) WHERE object         = <ls_sorted>-object
                                               AND created_at     = <ls_sorted>-created_at
                                               AND step-end_state = lv_start
                                               AND step-step_uuid <> <ls_sorted>-step-step_uuid.
          " A step ending in its start state (failure) is never a predecessor
          IF ls_pred-step-start_state <> ls_pred-step-end_state.
            lv_found = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_found = abap_false.
          EXIT.
        ENDIF.
        <ls_sorted>-chain += 1.
        lv_start = ls_pred-step-start_state.
      ENDDO.
    ENDLOOP.
    SORT lt_sorted BY created_at queue_pos object chain.
    lt_steps = VALUE #( FOR ls_sorted IN lt_sorted ( ls_sorted-step ) ).

    SELECT * FROM zprc_proc_msg WHERE processed_object_uuid IN @mt_objects
      INTO TABLE @DATA(lt_messages).

    " Header of a step = its message with IS_HEADER = 'X'
    DATA lt_headers TYPE HASHED TABLE OF zprc_proc_msg WITH UNIQUE KEY processed_step_uuid.
    LOOP AT lt_messages INTO DATA(ls_header_message) WHERE is_header = abap_true.
      INSERT ls_header_message INTO TABLE lt_headers.
    ENDLOOP.

    " Steps: references per object in creation order
    LOOP AT lt_steps INTO DATA(ls_step).
      DATA(ls_owner)  = VALUE #( lt_objects[ uuid = ls_step-processed_object_uuid ] OPTIONAL ).
      DATA(lv_object) = CONV string( ls_owner-ext_processed_object_id ).
      READ TABLE lt_counter WITH TABLE KEY object = lv_object ASSIGNING FIELD-SYMBOL(<ls_counter>).
      IF sy-subrc <> 0.
        INSERT VALUE #( object = lv_object ) INTO TABLE lt_counter ASSIGNING <ls_counter>.
      ENDIF.
      <ls_counter>-count += 1.
      DATA(lv_ref) = |S{ <ls_counter>-count }|.
      INSERT VALUE #( uuid = ls_step-step_uuid object = lv_object ref = lv_ref ) INTO TABLE lt_step_map.

      " Order is defined within a queue only - queues and objects without queue
      " run in parallel. An object without queue counts on its own.
      DATA(lv_seq_group) = COND string( WHEN ls_owner-queue_id IS NOT INITIAL
                                        THEN |QUEUE/{ ls_owner-process_name }/{ ls_owner-queue_id }|
                                        ELSE |OBJECT/{ lv_object }| ).
      READ TABLE lt_seq_counter WITH TABLE KEY object = lv_seq_group ASSIGNING FIELD-SYMBOL(<ls_seq>).
      IF sy-subrc <> 0.
        INSERT VALUE #( object = lv_seq_group ) INTO TABLE lt_seq_counter ASSIGNING <ls_seq>.
      ENDIF.
      <ls_seq>-count += 1.

      DATA(ls_header) = VALUE #( lt_headers[ processed_step_uuid = ls_step-step_uuid ] OPTIONAL ).
      INSERT VALUE #( object        = lv_object
                      ref           = lv_ref
                      seq           = <ls_seq>-count
                      start_state   = ls_step-start_state
                      end_state     = ls_step-end_state
                      msgid         = ls_header-msgid
                      msgno         = ls_header-msgno
                      msgty         = ls_header-msgty
                      msgv1         = ls_header-msgv1
                      msgv2         = ls_header-msgv2
                      msgv3         = ls_header-msgv3
                      msgv4         = ls_header-msgv4
                      text          = ls_header-message_text
                      severity_code = ls_header-message_severity_code
                      created       = COND #( WHEN ls_step-created_by IS INITIAL OR ls_step-created_at IS INITIAL
                                              THEN `MISSING` ) )
             INTO TABLE r_actual-steps.
    ENDLOOP.

    " Messages; headers the fixture added for given steps are not reported back
    LOOP AT lt_messages INTO DATA(ls_message) WHERE created_by <> 'PRC_FIXTURE'.
      DATA(ls_map) = VALUE #( lt_step_map[ uuid = ls_message-processed_step_uuid ] OPTIONAL ).
      INSERT VALUE #( object        = VALUE string( lt_objects[ uuid = ls_message-processed_object_uuid ]-ext_processed_object_id OPTIONAL )
                      step          = COND #( WHEN ls_map IS NOT INITIAL THEN ls_map-ref ELSE `?` )
                      msgid         = ls_message-msgid
                      msgno         = ls_message-msgno
                      msgty         = ls_message-msgty
                      msgv1         = ls_message-msgv1
                      msgv2         = ls_message-msgv2
                      msgv3         = ls_message-msgv3
                      msgv4         = ls_message-msgv4
                      text          = ls_message-message_text
                      severity_code = ls_message-message_severity_code
                      created       = COND #( WHEN ls_message-created_by IS INITIAL OR ls_message-created_at IS INITIAL
                                              THEN `MISSING` ) )
             INTO TABLE r_actual-messages.
    ENDLOOP.

    LOOP AT lt_objects INTO DATA(ls_object).
      DATA(ls_given) = VALUE #( mt_given[ uuid = ls_object-uuid ] OPTIONAL ).
      INSERT VALUE #(
          ref          = ls_object-ext_processed_object_id
          process_name = COND #( WHEN ls_object-process_name <> mv_process_name THEN ls_object-process_name )
          factory      = COND #( WHEN ls_object-factory_class_name <> mv_factory THEN ls_object-factory_class_name )
          state        = ls_object-state
          payload      = ls_object-payload_json
          queue_id     = ls_object-queue_id
          queue_pos    = ls_object-queue_pos
          not_before   = to_relative( i_timestamp = ls_object-do_not_process_before i_base = mv_run_at )
          retry_count  = ls_object-retry_count
          retry        = to_relative( i_timestamp = ls_object-retry_datetime i_base = mv_run_at )
          mail         = ls_object-mail_address
          run          = COND #( WHEN ls_object-run_uuid IS NOT INITIAL THEN ref( ls_object-run_uuid ) )
          step_total   = ls_object-step_total
          latest_step  = COND #( WHEN ls_object-latest_step_uuid IS NOT INITIAL
                                 THEN VALUE #( lt_step_map[ uuid = ls_object-latest_step_uuid ]-ref DEFAULT `?` ) )
          created      = COND #( WHEN ls_object-created_by                <> ls_given-created_by
                                   OR ls_object-created_at                <> ls_given-created_at
                                   OR ls_object-ext_processed_object_uuid <> ls_given-ext_processed_object_uuid
                                 THEN `MODIFIED` )
          changed      = COND #( WHEN ls_object-last_changed_at = ls_given-last_changed_at
                                  AND ls_object-last_changed_by = ls_given-last_changed_by
                                 THEN ``
                                 WHEN ls_object-last_changed_at > ls_given-last_changed_at
                                  AND ls_object-last_changed_by = mv_user
                                 THEN `CHANGED`
                                 ELSE `INVALID` )
          etag         = COND #( WHEN ls_object-local_last_changed_at = ls_given-local_last_changed_at THEN ``
                                 WHEN ls_object-local_last_changed_at > ls_given-local_last_changed_at THEN `CHANGED`
                                 ELSE `INVALID` ) )
             INTO TABLE r_actual-objects.
    ENDLOOP.
  ENDMETHOD.


  METHOD uuid.
    r_uuid = VALUE #( mt_keys[ ref = i_ref ]-uuid OPTIONAL ).
  ENDMETHOD.


  METHOD ref.
    r_ref = VALUE #( mt_keys[ KEY by_uuid uuid = i_uuid ]-ref DEFAULT |?{ i_uuid }| ).
  ENDMETHOD.


  METHOD key_uuid.
    r_uuid = uuid( i_ref ).
    IF r_uuid IS NOT INITIAL.
      RETURN.
    ENDIF.
    TRY.
        r_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        cl_abap_unit_assert=>fail( msg = lx_uuid->get_text( ) ).
    ENDTRY.
    INSERT VALUE #( ref = i_ref uuid = r_uuid ) INTO TABLE mt_keys.
  ENDMETHOD.


  METHOD to_timestamp.
    IF i_relative IS INITIAL.
      RETURN.
    ENDIF.
    r_timestamp = cl_abap_tstmp=>add( tstmp = i_base
                                      secs  = CONV i( replace( val = i_relative sub = `+` with = `` ) ) ).
  ENDMETHOD.


  METHOD to_relative.
    IF i_timestamp IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_seconds) = cl_abap_tstmp=>subtract( tstmp1 = i_timestamp
                                                tstmp2 = i_base ).
    DATA(lv_rounded) = CONV i( round( val = lv_seconds / 60 dec = 0 ) ) * 60.
    r_relative = COND #( WHEN lv_rounded >= 0 THEN |+{ lv_rounded }| ELSE |{ lv_rounded }| ).
  ENDMETHOD.

ENDCLASS.
