"! <p class="shorttext synchronized">PRC Test: Payload of the test process</p>
"!
"! The payload of ZCL_PRC_TEST_PROC_PROCESS is a plain JSON that defines per
"! start state what the transition does. Missing states or an empty/invalid
"! payload mean: succeed without further messages. Example:
"! {"A":{"MESSAGES":[{"TYPE":"W","V1":"w"}],"BAPI_MESSAGES":[{"TYPE":"E","V1":"e"}],
"!       "FAIL":"X","FAILURE_HEADER":"X","NEXT":"B2","NEW_PAYLOAD":"{}"}}
"! <ul>
"! <li>MESSAGES: messages ZPRC_TEST_PROC/001, each passed via ADD_MESSAGE_FROM_SY</li>
"! <li>BAPI_MESSAGES: messages ZPRC_TEST_PROC/001, passed together as one BAPI
"!     return table via ADD_BAPI_RESULT (after MESSAGES)</li>
"! <li>FAIL: "X" raises the error ZPRC_TEST_PROC/004 after the messages</li>
"! <li>FAILURE_HEADER: "X" returns ZPRC_TEST_PROC/003 as failure header</li>
"! <li>NEXT: proposed end state (state A: default B1)</li>
"! <li>NEW_PAYLOAD: replaces the payload of the processed object</li>
"! </ul>
"! <p class="shorttext synchronized">PRC Test: Payload of the test process</p>
"!
"! The payload of ZCL_PRC_TEST_PROC_PROCESS is a plain JSON that defines per
"! start state what the transition does. Missing states or an empty/invalid
"! payload mean: succeed without further messages. Example:
"! {"A":{"MESSAGES":[{"TYPE":"W","V1":"w"}],"BAPI_MESSAGES":[{"TYPE":"E","V1":"e"}],
"!       "FAIL":"X","FAILURE_HEADER":"X","NEXT":"B2","NEW_PAYLOAD":"{}"}}
"! <ul>
"! <li>MESSAGES: messages ZPRC_TEST_PROC/001, each passed via ADD_MESSAGE_FROM_SY</li>
"! <li>BAPI_MESSAGES: messages ZPRC_TEST_PROC/001, passed together as one BAPI
"!     return table via ADD_BAPI_RESULT (after MESSAGES)</li>
"! <li>TEXTS: plain texts without message class, each passed via ADD_MESSAGE_FROM_TEXT</li>
"! <li>FAIL: "X" raises the error ZPRC_TEST_PROC/004 after the messages</li>
"! <li>RAISE: "X" raises an unexpected exception (CX_SY_ZERODIVIDE) after the messages</li>
"! <li>FAILURE_HEADER: "X" returns ZPRC_TEST_PROC/003 as failure header</li>
"! <li>NEXT: proposed end state (state A: default B1)</li>
"! <li>NEW_PAYLOAD: replaces the payload of the processed object</li>
"! </ul>
CLASS zcl_prc_test_proc_payload DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_message,
             type TYPE symsgty,
             v1   TYPE symsgv,
             v2   TYPE symsgv,
             v3   TYPE symsgv,
             v4   TYPE symsgv,
           END OF ty_message,
           tt_messages TYPE STANDARD TABLE OF ty_message WITH EMPTY KEY.

    TYPES: BEGIN OF ty_text,
             type TYPE symsgty,
             text TYPE string,
           END OF ty_text,
           tt_texts TYPE STANDARD TABLE OF ty_text WITH EMPTY KEY.

    TYPES: BEGIN OF ty_behavior,
             messages       TYPE tt_messages,
             bapi_messages  TYPE tt_messages,
             texts          TYPE tt_texts,
             fail           TYPE abap_bool,
             raise          TYPE abap_bool,
             failure_header TYPE abap_bool,
             next           TYPE zif_prc_process=>ty_state,
             new_payload    TYPE string,
           END OF ty_behavior.

    TYPES: BEGIN OF ty_payload,
             start TYPE ty_behavior,
             a     TYPE ty_behavior,
             b1    TYPE ty_behavior,
             b2    TYPE ty_behavior,
           END OF ty_payload.

    "! Behavior of the transition starting in I_STATE
    CLASS-METHODS behavior_for IMPORTING i_payload         TYPE zprc_payload_json
                                         i_state           TYPE zif_prc_process=>ty_state
                               RETURNING VALUE(r_behavior) TYPE ty_behavior.

ENDCLASS.



CLASS zcl_prc_test_proc_payload IMPLEMENTATION.

  METHOD behavior_for.
    DATA ls_payload TYPE ty_payload.

    TRY.
        xco_cp_json=>data->from_string( i_payload )->write_to( REF #( ls_payload ) ).
      CATCH cx_root ##CATCH_ALL ##NO_HANDLER.
        " empty or foreign payload: default behavior
    ENDTRY.

    r_behavior = SWITCH #( i_state
                           WHEN 'START' THEN ls_payload-start
                           WHEN 'A'     THEN ls_payload-a
                           WHEN 'B1'    THEN ls_payload-b1
                           WHEN 'B2'    THEN ls_payload-b2 ).
  ENDMETHOD.

ENDCLASS.
