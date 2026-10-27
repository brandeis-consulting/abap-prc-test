"! <p class="shorttext synchronized">PRC demo: prints result of a processed object</p>
"!
"! Shared by the error demos (ZCL_PRC_DEMO_ERR_*): prints state, retry data,
"! steps and messages of one processed object to the ADT console.
CLASS zcl_prc_demo_err_output DEFINITION PUBLIC FINAL CREATE PRIVATE.

  PUBLIC SECTION.
    "! @parameter i_process_name | Process of the processed object.
    "! @parameter i_external_id  | External ID of the processed object.
    "! @parameter i_out          | Console of the class run.
    CLASS-METHODS print IMPORTING i_process_name TYPE zprc_process_name
                                  i_external_id  TYPE zr_prc_processedobject-ExternalProcessedObjectID
                                  i_out          TYPE REF TO if_oo_adt_classrun_out.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_err_output IMPLEMENTATION.

  METHOD print.
    " Console output of the demos: not translated (##NO_TEXT)
    SELECT SINGLE FROM zr_prc_processedobject WITH PRIVILEGED ACCESS
      FIELDS UUID, State, RetryCount, RetryDateTime
      WHERE ProcessName               = @i_process_name
        AND ExternalProcessedObjectID = @i_external_id
      INTO @DATA(object).
    IF sy-subrc <> 0.
      i_out->write( |Processed object { i_external_id } of process { i_process_name } not found| ) ##NO_TEXT.
      RETURN.
    ENDIF.

    i_out->write( |Processed object { object-UUID }| ) ##NO_TEXT.
    i_out->write( |  State: { object-State }, retry count: { object-RetryCount }, next retry: { object-RetryDateTime }| ) ##NO_TEXT.

    SELECT FROM zr_prc_processedstep WITH PRIVILEGED ACCESS
      FIELDS StepUUID, StartState, EndState, MessageSeverity, MessageText, CreatedAt
      WHERE ProcessedObjectUUID = @object-UUID
      ORDER BY CreatedAt
      INTO TABLE @DATA(steps).

    LOOP AT steps INTO DATA(step).
      i_out->write( |  Step { sy-tabix }: { step-StartState } -> { step-EndState }, header { step-MessageSeverity }: { step-MessageText }| ) ##NO_TEXT.

      SELECT FROM zr_prc_processedmessage WITH PRIVILEGED ACCESS
        FIELDS MessageSeverity, MessageClass, MessageNumber, MessageText, CreatedAt
        WHERE ProcessedStepUUID = @step-StepUUID
        ORDER BY CreatedAt
        INTO TABLE @DATA(messages).
      LOOP AT messages INTO DATA(message).
        i_out->write( |    { message-MessageSeverity } { message-MessageClass }/{ message-MessageNumber }: { message-MessageText }| ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

