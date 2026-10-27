"! <p class="shorttext synchronized">PRC Test: Lock holder for processed objects</p>
"!
"! Started in its own session via CL_ABAP_PARALLEL->FORK_INST. Locks a
"! processed object there via SET LOCKS and keeps the lock for I_HOLD_SECONDS.
"!
"! Global instead of local, because the instance is serialized and
"! re-created in the new session.
CLASS zcl_prc_test_proc_lock DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_abap_parallel.

    METHODS constructor IMPORTING i_processed_object_uuid TYPE sysuuid_x16
                                  i_hold_seconds          TYPE i DEFAULT 10.

    DATA mv_processed_object_uuid TYPE sysuuid_x16 READ-ONLY.
    DATA mv_hold_seconds          TYPE i           READ-ONLY.
    "! ABAP_TRUE if the lock could be set in the parallel session
    DATA mv_lock_acquired         TYPE abap_bool   READ-ONLY.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_test_proc_lock IMPLEMENTATION.

  METHOD constructor.
    mv_processed_object_uuid = i_processed_object_uuid.
    mv_hold_seconds          = i_hold_seconds.
  ENDMETHOD.


  METHOD if_abap_parallel~do.
    SET LOCKS OF zr_prc_processedobjecttp
        ENTITY ProcessedObject
        FROM VALUE #( ( uuid = mv_processed_object_uuid ) )
        FAILED DATA(ls_failed)
        REPORTED DATA(ls_reported) ##NEEDED.

    mv_lock_acquired = xsdbool( ls_failed IS INITIAL ).
    IF mv_lock_acquired = abap_false.
      RETURN.
    ENDIF.

    " Busy wait instead of WAIT UP TO: no implicit DB commit, so the lock is kept for sure
    DATA(lv_until) = utclong_add( val     = utclong_current( )
                                  seconds = mv_hold_seconds ).
    WHILE utclong_current( ) < lv_until.
    ENDWHILE.

    ROLLBACK ENTITIES.
  ENDMETHOD.

ENDCLASS.
