CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calcTotal FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calcTotal.
    METHODS validateAmount FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateAmount.
    METHODS validateDate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateDate.

ENDCLASS.

CLASS lhc_item IMPLEMENTATION.

  METHOD calcTotal.

    " 1. Claims of created or changed items: from RAP's buffer
    READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Item BY \_Claim
        FIELDS ( ClaimUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(claims).

    " 2. Claims of deleted items: from the database
    SELECT FROM zgs_exp_item
      FIELDS claim_uuid
      FOR ALL ENTRIES IN @keys
      WHERE item_uuid = @keys-ItemUUID
      INTO TABLE @DATA(db_claims).

    LOOP AT db_claims INTO DATA(db_claim).
      APPEND VALUE #( ClaimUUID = db_claim-claim_uuid ) TO claims.
    ENDLOOP.

    SORT claims BY ClaimUUID.
    DELETE ADJACENT DUPLICATES FROM claims COMPARING ClaimUUID.
    CHECK claims IS NOT INITIAL.

    " 3. Ask each claim to recalculate itself
    MODIFY ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        EXECUTE recalcTotal FROM CORRESPONDING #( claims ).
  ENDMETHOD.


  METHOD validateAmount.
  READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Item
        FIELDS ( Amount ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    " 2. Check each item
    LOOP AT items INTO DATA(item).
      IF item-Amount <= 0.

        " 3. Tell RAP: this item failed
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.

        " 4. Tell the user why, on the Amount field
        APPEND VALUE #( %tky            = item-%tky
                        %msg            = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = 'Amount must be greater than zero' )
                        %element-Amount = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDate.
  READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Item
        FIELDS ( ExpenseDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    " 2. Today's date
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    " 3. Check each item
    LOOP AT items INTO DATA(item).
      IF item-ExpenseDate IS INITIAL OR item-ExpenseDate > today.

        APPEND VALUE #( %tky = item-%tky ) TO failed-item.

        APPEND VALUE #( %tky                 = item-%tky
                        %msg                 = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = 'Expense date must not be empty or in the future' )
                        %element-ExpenseDate = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lhc_Claim DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Claim RESULT result.
    METHODS setstatusopen FOR DETERMINE ON MODIFY
      IMPORTING keys FOR claim~setstatusopen.
    METHODS setclaimid FOR DETERMINE ON SAVE
      IMPORTING keys FOR claim~setclaimid.
    METHODS validateemployee FOR VALIDATE ON SAVE
      IMPORTING keys FOR claim~validateemployee.
    METHODS submit FOR MODIFY
      IMPORTING keys FOR ACTION claim~submit RESULT result.
    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION claim~approve RESULT result.
    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION claim~reject RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR claim RESULT result.
    METHODS validatecurrency FOR VALIDATE ON SAVE
      IMPORTING keys FOR claim~validatecurrency.
    METHODS recalctotal FOR MODIFY
      IMPORTING keys FOR ACTION claim~recalctotal.
    METHODS copyclaim FOR MODIFY
      IMPORTING keys FOR ACTION claim~copyclaim.
    METHODS approveallsubmitted FOR MODIFY
      IMPORTING keys FOR ACTION claim~approveallsubmitted.

ENDCLASS.

CLASS lhc_Claim IMPLEMENTATION.

  METHOD get_instance_authorizations.
    result = VALUE #( FOR key IN keys
                      ( %tky    = key-%tky
                        %update = if_abap_behv=>auth-allowed
                        %delete = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD setStatusOpen.
  READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(claims).

    " 2. Only claims without a status
    DELETE claims WHERE Status IS NOT INITIAL.
    CHECK claims IS NOT INITIAL.

    " 3. Set status O
    MODIFY ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR claim IN claims ( %tky   = claim-%tky
                                            Status = 'O' ) ).

  ENDMETHOD.

  METHOD setClaimID.
  READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        FIELDS ( ClaimID ) WITH CORRESPONDING #( keys )
      RESULT DATA(claims).

    " 2. Only claims that don't have a number yet
    DELETE claims WHERE ClaimID IS NOT INITIAL.
    CHECK claims IS NOT INITIAL.

    " 3. Get one number per claim from the number range object
    DATA updates TYPE TABLE FOR UPDATE zgs_r_expclaim\\Claim.

    LOOP AT claims INTO DATA(claim).
      TRY.
          cl_numberrange_runtime=>number_get(
            EXPORTING
              nr_range_nr = '01'
              object      = 'ZGS_EXPCL'
            IMPORTING
              number      = DATA(number) ).

          DATA(counter) = CONV i( number ).
          APPEND VALUE #( %tky    = claim-%tky
                          ClaimID = |EXP{ counter WIDTH = 7 ALIGN = RIGHT PAD = '0' }| )
                 TO updates.

        CATCH cx_nr_object_not_found cx_number_ranges INTO DATA(nr_error).
          APPEND VALUE #( %tky = claim-%tky
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = nr_error->get_text( ) ) ) TO reported-claim.
      ENDTRY.
    ENDLOOP.

    " 4. Write the numbers into the claims (in the buffer)
    MODIFY ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        UPDATE FIELDS ( ClaimID ) WITH updates.


  ENDMETHOD.

  METHOD validateEmployee.
  READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        FIELDS ( Employee ) WITH CORRESPONDING #( keys )
      RESULT DATA(claims).

    " 2. Check each claim
    LOOP AT claims INTO DATA(claim).
      IF claim-Employee IS INITIAL.

        " 3. Tell RAP: this claim failed
        APPEND VALUE #( %tky = claim-%tky ) TO failed-claim.

        " 4. Tell the user why, on the Employee field
        APPEND VALUE #( %tky              = claim-%tky
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'Enter an employee' )
                        %element-Employee = if_abap_behv=>mk-on ) TO reported-claim.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD submit.
  MODIFY ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky   = key-%tky
                                        Status = 'S' ) ).

    " 2. Read the changed claims
    READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(claims).

    result = VALUE #( FOR claim IN claims ( %tky   = claim-%tky
                                            %param = claim ) ).

  ENDMETHOD.

  METHOD approve.
  MODIFY ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky   = key-%tky
                                        Status = 'A' ) ).

    READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(claims).

    result = VALUE #( FOR claim IN claims ( %tky   = claim-%tky
                                            %param = claim ) ).
  ENDMETHOD.

  METHOD reject.
  MODIFY ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        UPDATE FIELDS ( Status RejectionReason )
        WITH VALUE #( FOR key IN keys ( %tky            = key-%tky
                                        Status          = 'R'
                                        RejectionReason = key-%param-RejectionReason ) ).

    " 2. Read the changed claims
    READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(claims).

    " 3. Return them to the UI
    result = VALUE #( FOR claim IN claims ( %tky   = claim-%tky
                                            %param = claim ) ).
  ENDMETHOD.

  METHOD get_instance_features.
  READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(claims)
      FAILED failed.


    result = VALUE #( FOR claim IN claims
      LET editable  = COND #( WHEN claim-Status = 'S' OR claim-Status = 'A'
                              THEN if_abap_behv=>fc-o-disabled
                              ELSE if_abap_behv=>fc-o-enabled )
          decidable = COND #( WHEN claim-Status = 'S'
                              THEN if_abap_behv=>fc-o-enabled
                              ELSE if_abap_behv=>fc-o-disabled )
      IN ( %tky           = claim-%tky
           %update         = editable
           %delete         = editable
           %action-submit  = editable
           %action-approve = decidable
           %action-reject  = decidable ) ).

  ENDMETHOD.

  METHOD validateCurrency.
  READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        FIELDS ( CurrencyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(claims).

    LOOP AT claims INTO DATA(claim).
      IF claim-CurrencyCode IS INITIAL.
        APPEND VALUE #( %tky = claim-%tky ) TO failed-claim.
        APPEND VALUE #( %tky                  = claim-%tky
                        %msg                  = new_message_with_text(
                                                  severity = if_abap_behv_message=>severity-error
                                                  text     = 'Enter a currency' )
                        %element-CurrencyCode = if_abap_behv=>mk-on ) TO reported-claim.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD recalcTotal.
  READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim BY \_Item
        FIELDS ( Amount ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    " 2. Sum per claim
    DATA updates TYPE TABLE FOR UPDATE zgs_r_expclaim\\Claim.

    LOOP AT keys INTO DATA(key).
      DATA(total) = VALUE zgs_exp_claim-total_amount( ).
      LOOP AT items INTO DATA(item) WHERE ClaimUUID = key-ClaimUUID.
        total += item-Amount.
      ENDLOOP.
      APPEND VALUE #( %tky = key-%tky TotalAmount = total ) TO updates.
    ENDLOOP.

    " 3. Write the totals
    MODIFY ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        UPDATE FIELDS ( TotalAmount ) WITH updates.
  ENDMETHOD.

  METHOD copyClaim.
  DATA new_claims TYPE TABLE FOR CREATE zgs_r_expclaim\\Claim.
    DATA new_items  TYPE TABLE FOR CREATE zgs_r_expclaim\\Claim\_Item.

    " 1. Read the template claims and their items
    READ ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(claims)
      ENTITY Claim BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    LOOP AT keys INTO DATA(key).
      READ TABLE claims INTO DATA(claim) WITH KEY ClaimUUID = key-ClaimUUID.
      CHECK sy-subrc = 0.

      " 2. The new claim, with a temporary name: key-%cid
      APPEND VALUE #( %cid         = key-%cid
                      Employee     = claim-Employee
                      Description  = |Copy of { claim-Description }|
                      CurrencyCode = claim-CurrencyCode ) TO new_claims.

      " 3. Its items, created THROUGH the new claim (%cid_ref = the claim's temporary name)
      APPEND VALUE #( %cid_ref = key-%cid ) TO new_items ASSIGNING FIELD-SYMBOL(<new>).

      LOOP AT items INTO DATA(item) WHERE ClaimUUID = claim-ClaimUUID.
        APPEND VALUE #( %cid         = |{ key-%cid }_{ sy-tabix }|
                        ExpenseDate  = item-ExpenseDate
                        Category     = item-Category
                        Description  = item-Description
                        Amount       = item-Amount
                        CurrencyCode = item-CurrencyCode ) TO <new>-%target.
      ENDLOOP.
    ENDLOOP.

    " 4. Create claim and items in one step
    MODIFY ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        CREATE FIELDS ( Employee Description CurrencyCode )
          WITH new_claims
        CREATE BY \_Item FIELDS ( ExpenseDate Category Description Amount CurrencyCode )
          WITH new_items
      MAPPED DATA(mapped_new).

    " 5. Tell RAP (and the UI) which real key each new claim got
    mapped-claim = mapped_new-claim.
  ENDMETHOD.

  METHOD approveAllSubmitted.
  SELECT ClaimUUID
      FROM zgs_r_expclaim
      WHERE Status = 'S'
      INTO TABLE @DATA(submitted).

    IF submitted IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Reuse the existing approve action for each claim
    MODIFY ENTITIES OF zgs_r_expclaim IN LOCAL MODE
      ENTITY Claim
        EXECUTE approve
          FROM VALUE #( FOR s IN submitted ( %tky-ClaimUUID = s-ClaimUUID ) )
      FAILED   DATA(approve_failed)
      REPORTED DATA(approve_reported).
  ENDMETHOD.

ENDCLASS.
