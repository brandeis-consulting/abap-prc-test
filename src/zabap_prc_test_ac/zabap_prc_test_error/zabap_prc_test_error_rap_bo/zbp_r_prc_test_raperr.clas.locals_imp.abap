"! Buffer shared by handler and saver: remembers for which instance messages
"! have to be raised in the check_before_save phase or in save_modified.
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS co_msgid TYPE symsgid VALUE 'ZPRC_TEST_RAPERR'.

    CONSTANTS: BEGIN OF phase,
                 check_before_save  TYPE c LENGTH 4 VALUE 'CBS',
                 late_save_messages TYPE c LENGTH 4 VALUE 'LMSG',
                 late_save_failed   TYPE c LENGTH 4 VALUE 'LFAI',
               END OF phase.

    TYPES: BEGIN OF ty_todo,
             uuid  TYPE sysuuid_x16,
             phase TYPE c LENGTH 4,
           END OF ty_todo,
           tt_todo     TYPE SORTED TABLE OF ty_todo WITH UNIQUE KEY uuid phase,
           tt_messages TYPE STANDARD TABLE OF REF TO if_abap_behv_message WITH EMPTY KEY,
           tt_uuid     TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    CLASS-DATA mt_todo TYPE tt_todo.
ENDCLASS.


CLASS lcl_buffer IMPLEMENTATION.
ENDCLASS.


CLASS lhc_raperr DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR RapErr RESULT result.

    METHODS noerror FOR MODIFY
      IMPORTING keys FOR ACTION RapErr~noError.

    METHODS modifyerror FOR MODIFY
      IMPORTING keys FOR ACTION RapErr~modifyError.

    METHODS checkbeforesaveerror FOR MODIFY
      IMPORTING keys FOR ACTION RapErr~checkBeforeSaveError.

    METHODS latesavemessages FOR MODIFY
      IMPORTING keys FOR ACTION RapErr~lateSaveMessages.

    METHODS latesavefailed FOR MODIFY
      IMPORTING keys FOR ACTION RapErr~lateSaveFailed.

    METHODS checkbeforesave FOR VALIDATE ON SAVE
      IMPORTING keys FOR RapErr~checkBeforeSave.

    "! Creates the messages of a scenario starting with number i_first_number:
    "! with errors E, E, W, I - otherwise only W, I.
    METHODS build_messages
      IMPORTING i_first_number    TYPE symsgno
                i_with_errors     TYPE abap_bool
      RETURNING VALUE(r_messages) TYPE lcl_buffer=>tt_messages.

    "! Changes the instances, so save_modified is called for them, and remembers the phase.
    METHODS remember_for_save
      IMPORTING i_uuids TYPE lcl_buffer=>tt_uuid
                i_text  TYPE zr_prc_test_raperr-Text
                i_phase TYPE lcl_buffer=>ty_todo-phase.
ENDCLASS.


CLASS lhc_raperr IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Test object: everything is allowed
    result = VALUE #( %create                      = if_abap_behv=>auth-allowed
                      %update                      = if_abap_behv=>auth-allowed
                      %delete                      = if_abap_behv=>auth-allowed
                      %action-noError              = if_abap_behv=>auth-allowed
                      %action-modifyError          = if_abap_behv=>auth-allowed
                      %action-checkBeforeSaveError = if_abap_behv=>auth-allowed
                      %action-lateSaveMessages     = if_abap_behv=>auth-allowed
                      %action-lateSaveFailed       = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD noerror.
    MODIFY ENTITIES OF zr_prc_test_raperr IN LOCAL MODE
           ENTITY RapErr
           UPDATE FIELDS ( Text )
           WITH VALUE #( FOR k IN keys ( %tky = k-%tky  Text = 'NO_ERROR' ) ).

    DATA(lt_messages) = build_messages( i_first_number = '001'
                                        i_with_errors  = abap_false ).
    LOOP AT keys INTO DATA(ls_key).
      LOOP AT lt_messages INTO DATA(lo_message).
        APPEND VALUE #( %tky = ls_key-%tky  %msg = lo_message ) TO reported-raperr.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD modifyerror.
    " No change - the action fails immediately
    DATA(lt_messages) = build_messages( i_first_number = '003'
                                        i_with_errors  = abap_true ).
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky        = ls_key-%tky
                      %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-raperr.
      LOOP AT lt_messages INTO DATA(lo_message).
        APPEND VALUE #( %tky = ls_key-%tky  %msg = lo_message ) TO reported-raperr.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD checkbeforesaveerror.
    " The change triggers the on-save validation; the error is raised there
    MODIFY ENTITIES OF zr_prc_test_raperr IN LOCAL MODE
           ENTITY RapErr
           UPDATE FIELDS ( Text )
           WITH VALUE #( FOR k IN keys ( %tky = k-%tky  Text = 'CHECK_BEFORE_SAVE_ERROR' ) ).

    LOOP AT keys INTO DATA(ls_key).
      INSERT VALUE #( uuid  = ls_key-UUID
                      phase = lcl_buffer=>phase-check_before_save ) INTO TABLE lcl_buffer=>mt_todo.
    ENDLOOP.
  ENDMETHOD.


  METHOD latesavemessages.
    remember_for_save( i_uuids = VALUE #( FOR k IN keys ( k-UUID ) )
                       i_text  = 'LATE_SAVE_MESSAGES'
                       i_phase = lcl_buffer=>phase-late_save_messages ).
  ENDMETHOD.


  METHOD latesavefailed.
    remember_for_save( i_uuids = VALUE #( FOR k IN keys ( k-UUID ) )
                       i_text  = 'LATE_SAVE_FAILED'
                       i_phase = lcl_buffer=>phase-late_save_failed ).
  ENDMETHOD.


  METHOD remember_for_save.
    MODIFY ENTITIES OF zr_prc_test_raperr IN LOCAL MODE
           ENTITY RapErr
           UPDATE FIELDS ( Text )
           WITH VALUE #( FOR u IN i_uuids ( UUID = u  Text = i_text ) ).

    LOOP AT i_uuids INTO DATA(lv_uuid).
      INSERT VALUE #( uuid  = lv_uuid
                      phase = i_phase ) INTO TABLE lcl_buffer=>mt_todo.
    ENDLOOP.
  ENDMETHOD.


  METHOD checkbeforesave.
    " Runs in the check_before_save phase (also for COMMIT ENTITIES IN SIMULATION MODE)
    DATA(lt_messages) = build_messages( i_first_number = '007'
                                        i_with_errors  = abap_true ).
    LOOP AT keys INTO DATA(ls_key).
      CHECK line_exists( lcl_buffer=>mt_todo[ uuid  = ls_key-UUID
                                              phase = lcl_buffer=>phase-check_before_save ] ).
      APPEND VALUE #( %tky = ls_key-%tky ) TO failed-raperr.
      LOOP AT lt_messages INTO DATA(lo_message).
        APPEND VALUE #( %tky = ls_key-%tky  %msg = lo_message ) TO reported-raperr.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD build_messages.
    DATA lv_number TYPE symsgno.
    lv_number = i_first_number.

    IF i_with_errors = abap_true.
      APPEND new_message( id       = lcl_buffer=>co_msgid
                          number   = lv_number
                          severity = if_abap_behv_message=>severity-error ) TO r_messages.
      lv_number += 1.
      APPEND new_message( id       = lcl_buffer=>co_msgid
                          number   = lv_number
                          severity = if_abap_behv_message=>severity-error ) TO r_messages.
      lv_number += 1.
    ENDIF.

    APPEND new_message( id       = lcl_buffer=>co_msgid
                        number   = lv_number
                        severity = if_abap_behv_message=>severity-warning ) TO r_messages.
    lv_number += 1.
    APPEND new_message( id       = lcl_buffer=>co_msgid
                        number   = lv_number
                        severity = if_abap_behv_message=>severity-information ) TO r_messages.
  ENDMETHOD.

ENDCLASS.


"! Saver that may report FAILED in save_modified (late failure)
CLASS lsc_zr_prc_test_raperr DEFINITION INHERITING FROM cl_abap_behavior_saver_failed.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

  PRIVATE SECTION.
    "! Creates E, E, W, I starting with number i_first_number.
    METHODS build_messages
      IMPORTING i_first_number    TYPE symsgno
      RETURNING VALUE(r_messages) TYPE lcl_buffer=>tt_messages.
ENDCLASS.


CLASS lsc_zr_prc_test_raperr IMPLEMENTATION.

  METHOD save_modified.
    " Same messages for both scenarios; only late_save_failed reports FAILED.
    " Only for instances that are actually updated in this save.
    DATA(lt_messages) = build_messages( '011' ).

    LOOP AT update-raperr INTO DATA(ls_update).
      IF line_exists( lcl_buffer=>mt_todo[ uuid  = ls_update-UUID
                                           phase = lcl_buffer=>phase-late_save_failed ] ).
        APPEND VALUE #( UUID        = ls_update-UUID
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-raperr.
      ELSEIF NOT line_exists( lcl_buffer=>mt_todo[ uuid  = ls_update-UUID
                                                   phase = lcl_buffer=>phase-late_save_messages ] ).
        CONTINUE.
      ENDIF.
      LOOP AT lt_messages INTO DATA(lo_message).
        APPEND VALUE #( UUID = ls_update-UUID  %msg = lo_message ) TO reported-raperr.
      ENDLOOP.
    ENDLOOP.

    " cleanup cannot be redefined in a managed BO - so the buffer is cleared here
    CLEAR lcl_buffer=>mt_todo.
  ENDMETHOD.


  METHOD build_messages.
    DATA lv_number TYPE symsgno.
    lv_number = i_first_number.

    APPEND new_message( id       = lcl_buffer=>co_msgid
                        number   = lv_number
                        severity = if_abap_behv_message=>severity-error ) TO r_messages.
    lv_number += 1.
    APPEND new_message( id       = lcl_buffer=>co_msgid
                        number   = lv_number
                        severity = if_abap_behv_message=>severity-error ) TO r_messages.
    lv_number += 1.
    APPEND new_message( id       = lcl_buffer=>co_msgid
                        number   = lv_number
                        severity = if_abap_behv_message=>severity-warning ) TO r_messages.
    lv_number += 1.
    APPEND new_message( id       = lcl_buffer=>co_msgid
                        number   = lv_number
                        severity = if_abap_behv_message=>severity-information ) TO r_messages.
  ENDMETHOD.

ENDCLASS.
