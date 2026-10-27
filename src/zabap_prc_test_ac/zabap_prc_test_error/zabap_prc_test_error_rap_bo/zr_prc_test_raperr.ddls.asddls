@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PRC Test: RAP BO error scenarios'
define root view entity ZR_PRC_Test_RapErr
  as select from zprc_test_raperr
{
  key uuid                  as UUID,
      text                  as Text,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by       as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
