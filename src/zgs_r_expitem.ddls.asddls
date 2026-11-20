@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expense Claim: Item View'
define view entity ZGS_R_ExpItem
  as select from zgs_exp_item
  association to parent ZGS_R_ExpClaim as _Claim
    on $projection.ClaimUUID = _Claim.ClaimUUID
{
  key item_uuid             as ItemUUID,
      claim_uuid            as ClaimUUID,
      expense_date          as ExpenseDate,
      category              as Category,
      description           as Description,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      amount                as Amount,
      currency_code         as CurrencyCode,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Claim
}
