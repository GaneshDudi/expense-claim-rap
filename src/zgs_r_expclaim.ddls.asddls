@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expense Claim: Root View'
define root view entity ZGS_R_ExpClaim
  as select from zgs_exp_claim
  composition [0..*] of ZGS_R_ExpItem as _Item
{
  key claim_uuid            as ClaimUUID,
      claim_id              as ClaimID,
      employee              as Employee,
      description           as Description,
      status                as Status,
      rejection_reason      as RejectionReason,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_amount          as TotalAmount,
      currency_code         as CurrencyCode,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Item
}
