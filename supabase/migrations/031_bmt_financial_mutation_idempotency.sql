-- BMT 031 - enforce idempotency at the public financial mutation boundary.
-- Existing two/three-argument functions remain internal compatibility helpers.

CREATE OR REPLACE FUNCTION bmt_db.post_journal(
    p_journal_id UUID,
    p_posted_by UUID,
    p_idempotency_key TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_claim RECORD;
BEGIN
    SELECT * INTO v_claim
    FROM bmt_db.claim_financial_mutation('post_journal', p_idempotency_key, p_journal_id::TEXT);

    IF NOT v_claim.is_new THEN
        IF v_claim.status = 'SUCCEEDED' THEN RETURN; END IF;
        RAISE EXCEPTION 'Mutation key is already in progress or failed';
    END IF;

    PERFORM bmt_db.post_journal(p_journal_id, p_posted_by);
    PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'SUCCEEDED', p_journal_id, 200);
END;
$$;

CREATE OR REPLACE FUNCTION bmt_db.mark_transaction_posted(
    p_transaction_id UUID,
    p_posted_by UUID,
    p_idempotency_key TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_claim RECORD;
BEGIN
    SELECT * INTO v_claim
    FROM bmt_db.claim_financial_mutation('mark_transaction_posted', p_idempotency_key, p_transaction_id::TEXT);

    IF NOT v_claim.is_new THEN
        IF v_claim.status = 'SUCCEEDED' THEN RETURN; END IF;
        RAISE EXCEPTION 'Mutation key is already in progress or failed';
    END IF;

    PERFORM bmt_db.mark_transaction_posted(p_transaction_id, p_posted_by);
    PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'SUCCEEDED', p_transaction_id, 200);
END;
$$;

CREATE OR REPLACE FUNCTION bmt_db.reverse_transaction(
    p_original_transaction_id UUID,
    p_reversed_by UUID,
    p_reason TEXT,
    p_idempotency_key TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_claim RECORD;
    v_result UUID;
BEGIN
    SELECT * INTO v_claim
    FROM bmt_db.claim_financial_mutation('reverse_transaction', p_idempotency_key, p_original_transaction_id::TEXT || ':' || p_reason);

    IF NOT v_claim.is_new THEN
        IF v_claim.status = 'SUCCEEDED' THEN RETURN v_claim.result_id; END IF;
        RAISE EXCEPTION 'Mutation key is already in progress or failed';
    END IF;

    v_result := bmt_db.reverse_transaction(p_original_transaction_id, p_reversed_by, p_reason);
    PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'SUCCEEDED', v_result, 200);
    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION bmt_db.post_journal(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.post_journal(UUID, UUID, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.mark_transaction_posted(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.mark_transaction_posted(UUID, UUID, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.reverse_transaction(UUID, UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.reverse_transaction(UUID, UUID, TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION bmt_db.post_journal(UUID, UUID, TEXT) IS
'Public idempotent journal-posting boundary. Retry with the same key returns success without posting twice.';
COMMENT ON FUNCTION bmt_db.mark_transaction_posted(UUID, UUID, TEXT) IS
'Public idempotent transaction-posting boundary.';
COMMENT ON FUNCTION bmt_db.reverse_transaction(UUID, UUID, TEXT, TEXT) IS
'Public idempotent reversal boundary.';
