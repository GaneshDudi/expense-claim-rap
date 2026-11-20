@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expense Item: Projection'
@Metadata.allowExtensions: true
define view entity ZGS_C_ExpItem
  as projection on ZGS_R_ExpItem
{
  key ItemUUID,
      ClaimUUID,
      ExpenseDate,
      Category,
      Description,
      Amount,
      CurrencyCode,
      LocalLastChangedAt,

      _Claim : redirected to parent ZGS_C_ExpClaim
}
