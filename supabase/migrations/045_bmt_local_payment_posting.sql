BEGIN;

-- Atomically post an online installment payment from the customer's savings
-- account. This is the local operational path and is deliberately server-side:
-- the browser supplies only the schedule, amount and retry key.
CREATE OR REPLACE FUNCTION bmt_db.customer_request_installment_payment(
    p_loan_schedule_id UUID,
    p_amount NUMERIC,
    p_idempotency_key TEXT
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_customer bmt_db.customers%ROWTYPE;
    v_schedule bmt_db.loan_schedules%ROWTYPE;
    v_loan bmt_db.loan_accounts%ROWTYPE;
    v_fa bmt_db.financial_accounts%ROWTYPE;
    v_savings bmt_db.savings_accounts%ROWTYPE;
    v_claim RECORD;
    v_tx UUID;
    v_journal UUID;
    v_period UUID;
    v_branch_code TEXT;
    v_tx_number TEXT;
    v_remaining NUMERIC;
    v_principal NUMERIC := 0;
    v_margin NUMERIC := 0;
    v_penalty NUMERIC := 0;
    v_other NUMERIC := 0;
    v_left NUMERIC;
    v_new_balance NUMERIC;
    v_savings_coa UUID;
    v_receivable_coa UUID;
    v_margin_coa UUID;
    v_penalty_coa UUID;
    v_loan_product UUID;
    v_journal_number TEXT;
BEGIN
    IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    IF p_amount <= 0 OR NULLIF(btrim(p_idempotency_key), '') IS NULL THEN
      RAISE EXCEPTION 'Amount and idempotency key are required';
    END IF;

    SELECT * INTO v_customer FROM bmt_db.customers WHERE auth_user_id = v_user FOR SHARE;
    SELECT * INTO v_schedule FROM bmt_db.loan_schedules WHERE id = p_loan_schedule_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Installment not found'; END IF;
    SELECT * INTO v_loan FROM bmt_db.loan_accounts WHERE financial_account_id = v_schedule.loan_account_id FOR SHARE;
    SELECT la.loan_product_id INTO v_loan_product
      FROM bmt_db.loan_applications la
     WHERE la.id = v_loan.application_id;
    SELECT * INTO v_fa FROM bmt_db.financial_accounts WHERE id = v_loan.savings_account_id FOR SHARE;
    SELECT * INTO v_savings FROM bmt_db.savings_accounts WHERE financial_account_id = v_loan.savings_account_id FOR UPDATE;
    IF v_customer.id IS NULL OR v_fa.customer_id <> v_customer.id THEN RAISE EXCEPTION 'Schedule is not owned by the customer'; END IF;

    v_remaining := v_schedule.total_due - v_schedule.principal_paid - v_schedule.margin_paid - v_schedule.penalty_paid - v_schedule.other_paid;
    IF v_remaining <= 0 THEN RAISE EXCEPTION 'Installment is already paid'; END IF;
    IF p_amount > v_remaining THEN RAISE EXCEPTION 'Payment exceeds remaining installment'; END IF;
    IF p_amount > v_savings.available_balance THEN RAISE EXCEPTION 'Insufficient available balance'; END IF;

    SELECT * INTO v_claim FROM bmt_db.claim_financial_mutation('customer_post_installment_payment', p_idempotency_key, concat(p_loan_schedule_id, ':', p_amount));
    IF NOT v_claim.is_new THEN
      IF v_claim.status = 'SUCCEEDED' THEN RETURN v_claim.result_id; END IF;
      RAISE EXCEPTION 'Request is already being processed or failed';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtext('installment-post:' || p_loan_schedule_id::TEXT));
    IF EXISTS (
      SELECT 1 FROM bmt_db.installment_payments ip
      WHERE ip.loan_schedule_id = p_loan_schedule_id
        AND ip.transaction_id IS NOT NULL
        AND EXISTS (SELECT 1 FROM bmt_db.transactions t WHERE t.id = ip.transaction_id AND t.status IN ('DRAFT','APPROVED','POSTED'))
    ) THEN RAISE EXCEPTION 'Installment payment is already posted or pending'; END IF;

    v_left := p_amount;
    v_principal := LEAST(v_left, v_schedule.principal_due - v_schedule.principal_paid); v_left := v_left - v_principal;
    v_margin := LEAST(v_left, v_schedule.margin_due - v_schedule.margin_paid); v_left := v_left - v_margin;
    v_penalty := LEAST(v_left, GREATEST(v_schedule.penalty_paid - v_schedule.penalty_paid, 0)); v_left := v_left - v_penalty;
    v_other := v_left;

    SELECT b.code INTO v_branch_code FROM bmt_db.branches b WHERE b.id = v_fa.branch_id;
    v_tx_number := 'PAY-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8);
    INSERT INTO bmt_db.transactions(transaction_number, branch_id, transaction_type, customer_id, financial_account_id, amount, status, channel, description, created_by)
    VALUES (v_tx_number, v_fa.branch_id, 'INSTALLMENT_PAYMENT', v_customer.id, v_loan.savings_account_id, p_amount, 'DRAFT', 'ONLINE', 'Pembayaran angsuran dari saldo tabungan', v_user)
    RETURNING id INTO v_tx;

    UPDATE bmt_db.savings_accounts
       SET current_balance = current_balance - p_amount,
           available_balance = available_balance - p_amount,
           last_transaction_at = now(), updated_at = now()
     WHERE financial_account_id = v_loan.savings_account_id
     RETURNING available_balance INTO v_new_balance;

    INSERT INTO bmt_db.installment_payments(loan_schedule_id, transaction_id, principal_amount, margin_amount, penalty_amount, other_amount, created_by)
    VALUES (p_loan_schedule_id, v_tx, v_principal, v_margin, v_penalty, v_other, v_user);

    UPDATE bmt_db.loan_schedules
       SET principal_paid = principal_paid + v_principal,
           margin_paid = margin_paid + v_margin,
           penalty_paid = penalty_paid + v_penalty,
           other_paid = other_paid + v_other,
           paid_at = CASE WHEN principal_paid + v_principal + margin_paid + v_margin + penalty_paid + v_penalty + other_paid + v_other >= total_due THEN now() ELSE paid_at END,
           status = CASE WHEN principal_paid + v_principal + margin_paid + v_margin + penalty_paid + v_penalty + other_paid + v_other >= total_due THEN 'PAID'::bmt_db.installment_status ELSE 'PARTIAL'::bmt_db.installment_status END,
           updated_at = now()
     WHERE id = p_loan_schedule_id;

    INSERT INTO bmt_db.savings_ledger(account_id, transaction_id, entry_date, value_date, entry_type, amount, balance_after, description)
    VALUES (v_loan.savings_account_id, v_tx, CURRENT_DATE, CURRENT_DATE, 'DEBIT', p_amount, v_new_balance, 'Pembayaran angsuran');
    INSERT INTO bmt_db.loan_ledger(loan_account_id, transaction_id, entry_date, value_date, component, entry_type, amount, balance_after, description)
    VALUES (v_schedule.loan_account_id, v_tx, CURRENT_DATE, CURRENT_DATE, 'PRINCIPAL', 'CREDIT', v_principal, GREATEST(v_schedule.opening_principal - v_schedule.principal_paid - v_principal, 0), 'Pembayaran pokok');
    IF v_margin > 0 THEN
      INSERT INTO bmt_db.loan_ledger(loan_account_id, transaction_id, entry_date, value_date, component, entry_type, amount, balance_after, description)
      VALUES (v_schedule.loan_account_id, v_tx, CURRENT_DATE, CURRENT_DATE, 'MARGIN', 'CREDIT', v_margin, v_margin, 'Pembayaran margin');
    END IF;

    SELECT sp.liability_coa_id INTO v_savings_coa FROM bmt_db.savings_products sp WHERE sp.product_id = v_fa.product_id;
    SELECT lp.receivable_coa_id, lp.margin_income_coa_id, lp.penalty_income_coa_id INTO v_receivable_coa, v_margin_coa, v_penalty_coa
    FROM bmt_db.loan_products lp WHERE lp.product_id = v_loan_product;
    IF v_savings_coa IS NULL OR v_receivable_coa IS NULL OR (v_margin > 0 AND v_margin_coa IS NULL) THEN RAISE EXCEPTION 'Accounting mappings are incomplete'; END IF;

    v_period := bmt_db.require_open_fiscal_period(CURRENT_DATE);
    v_journal_number := 'JV-' || v_branch_code || '-' || to_char(CURRENT_DATE, 'YYYYMMDD') || '-' || bmt_db.next_sequence(v_fa.branch_id, 'JOURNAL'::bmt_db.sequence_type, '', '', CURRENT_DATE, 'DAILY'::bmt_db.sequence_reset_policy, 6);
    INSERT INTO bmt_db.journal_entries(journal_number, transaction_id, branch_id, fiscal_period_id, journal_date, description, status, created_by)
    VALUES (v_journal_number, v_tx, v_fa.branch_id, v_period, CURRENT_DATE, 'Pembayaran angsuran ' || v_tx_number, 'DRAFT', v_user)
    RETURNING id INTO v_journal;
    INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description)
    VALUES (v_journal, 1, v_savings_coa, v_customer.id, v_loan.savings_account_id, p_amount, 0, 'Pengurangan kewajiban tabungan');
    INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description)
    VALUES (v_journal, 2, v_receivable_coa, v_customer.id, v_schedule.loan_account_id, 0, v_principal, 'Pelunasan pokok');
    IF v_margin > 0 THEN
      INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description)
      VALUES (v_journal, 3, v_margin_coa, v_customer.id, v_schedule.loan_account_id, 0, v_margin, 'Pendapatan margin');
    END IF;
    IF v_penalty > 0 THEN
      IF v_penalty_coa IS NULL THEN RAISE EXCEPTION 'Penalty accounting mapping is incomplete'; END IF;
      INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description)
      VALUES (v_journal, 4, v_penalty_coa, v_customer.id, v_schedule.loan_account_id, 0, v_penalty, 'Pendapatan denda');
    END IF;
    PERFORM bmt_db.post_journal(v_journal, v_user);
    PERFORM bmt_db.mark_transaction_posted(v_tx, v_user);
    INSERT INTO bmt_db.transaction_receipts(transaction_id, receipt_number)
    VALUES (v_tx, 'RCPT-' || replace(v_tx_number, 'PAY-', ''));
    INSERT INTO bmt_db.audit_logs(user_id, branch_id, action, entity_type, entity_id, transaction_id, metadata)
    VALUES (v_user, v_fa.branch_id, 'INSTALLMENT_PAYMENT_POSTED', 'LOAN_SCHEDULE', p_loan_schedule_id, v_tx,
            jsonb_build_object('amount', p_amount, 'principal', v_principal, 'margin', v_margin, 'remaining_balance', v_new_balance));
    PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'SUCCEEDED', v_tx, 201);
    RETURN v_tx;
EXCEPTION WHEN OTHERS THEN
    IF FOUND AND v_claim.request_id IS NOT NULL THEN PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'FAILED', NULL, 400); END IF;
    RAISE;
END;
$$;

COMMIT;
