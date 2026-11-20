@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expense Claim: Projection'
@Metadata.allowExtensions: true
define root view entity ZGS_C_ExpClaim
  provider contract transactional_query
  as projection on ZGS_R_ExpClaim
{
  key ClaimUUID,
      ClaimID,
      Employee,
      Description,
      Status,
      RejectionReason,
      TotalAmount,
      CurrencyCode,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Item : redirected to composition child ZGS_C_ExpItem
}
