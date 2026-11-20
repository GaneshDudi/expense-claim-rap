# Expense Claim App (RAP, Managed)

A complete Expense Claim application built step by step with the ABAP RESTful Application Programming Model (RAP) on SAP S/4HANA 2023.

An employee creates a claim with expense items, submits it, and a manager approves or rejects it with a reason.

## Features

| Feature | RAP concept |
|---|---|
| Claim header with expense items | Composition (root and child entity) |
| Claim number EXP0000001, EXP0000002... | Determination on save + number range object |
| Status set to Open on create | Determination on modify |
| Total amount recalculated when items change | Determination calling an internal action |
| Employee, currency, amount and date checks | Validations |
| Employee required at create, read-only on edit | mandatory:create, readonly:update |
| Submit, Approve, Reject (with reason) | Instance actions, action with parameter |
| Buttons enabled only in the right status | Instance feature control |
| Copy claim with all items | Factory action |
| Approve all submitted claims | Static action |

## Objects

| Type | Objects |
|---|---|
| Tables | ZGS_EXP_CLAIM, ZGS_EXP_ITEM |
| CDS views | ZGS_R_ExpClaim, ZGS_R_ExpItem (base), ZGS_C_ExpClaim, ZGS_C_ExpItem (projection) |
| Abstract entity | ZGS_A_RejectReason |
| Metadata extensions | ZGS_C_ExpClaim, ZGS_C_ExpItem |
| Behavior definitions | ZGS_R_EXPCLAIM (base), ZGS_C_EXPCLAIM (projection) |
| Behavior pool | ZBP_GS_R_EXPCLAIM |
| Service | ZGS_UI_EXPCLAIM (definition), ZGS_UI_EXPCLAIM_O4 (binding, OData V2 UI) |
| Number range object | ZGS_EXPCL |

## Prerequisites

- SAP S/4HANA 2023 (ABAP Platform 2023) or later. Older releases may fail on strict ( 2 ) and newer RAP syntax.
- abapGit installed (standalone report ZABAPGIT_STANDALONE): https://docs.abapgit.org
- ADT (Eclipse) to view and test the objects.
- No objects named ZGS_EXP* or ZGS_*EXPCLAIM* already in your system.

## How to import

1. Create a local package, for example $ZEXPCLAIM (or a transportable one).
2. Open abapGit.
   - System with internet: New Online, URL https://github.com/GaneshDudi/expense-claim-rap, your package, then Pull.
   - System without internet: on GitHub click Code, Download ZIP. In abapGit choose New Offline with your package, then Import zip, then Pull.
3. Activate all objects if anything stays inactive.

## After import

1. Number range: open SNRO, object ZGS_EXPCL, and create interval 01 (for example 0000001 to 9999999) if it does not exist. Intervals are client data and may not come with the import.
2. Service binding: open ZGS_UI_EXPCLAIM_O4 in ADT and click Publish.
3. Test: select the entity ExpenseClaim in the binding and click Preview.
4. Test data: create claims in the app itself. Table contents are not part of the repository.

## Author

Dudi Sai Ganesh, SAP ABAP Technical Consultant 
