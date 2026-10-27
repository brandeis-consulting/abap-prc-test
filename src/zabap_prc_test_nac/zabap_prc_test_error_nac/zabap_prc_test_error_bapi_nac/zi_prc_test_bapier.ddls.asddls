@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ZI_PRC_TEST_BAPIER'

define view entity ZI_PRC_TEST_BAPIER
  as select from zprc_test_bapier

{
  key uuid as Uuid
}
