CREATE TABLE IF NOT EXISTS bmt_db.daily_reconciliation_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), run_date DATE NOT NULL, run_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  transaction_count BIGINT NOT NULL, posted_amount NUMERIC(18,2) NOT NULL, debit_total NUMERIC(18,2) NOT NULL,
  credit_total NUMERIC(18,2) NOT NULL, variance NUMERIC(18,2) NOT NULL, status TEXT NOT NULL, notes TEXT
);
CREATE INDEX IF NOT EXISTS idx_daily_reconciliation_date ON bmt_db.daily_reconciliation_runs(run_date DESC);
CREATE OR REPLACE FUNCTION bmt_db.run_daily_reconciliation(p_run_date DATE DEFAULT CURRENT_DATE)
RETURNS bmt_db.daily_reconciliation_runs LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r bmt_db.daily_reconciliation_runs;
BEGIN
 INSERT INTO bmt_db.daily_reconciliation_runs(run_date,transaction_count,posted_amount,debit_total,credit_total,variance,status,notes)
 SELECT p_run_date, count(t.id), coalesce(sum(t.amount),0), coalesce(sum(j.debit_total),0), coalesce(sum(j.credit_total),0), coalesce(sum(j.debit_total-j.credit_total),0),
   CASE WHEN coalesce(sum(j.debit_total-j.credit_total),0)=0 THEN 'BALANCED' ELSE 'EXCEPTION' END,
   CASE WHEN coalesce(sum(j.debit_total-j.credit_total),0)=0 THEN NULL ELSE 'Journal debit/credit tidak seimbang' END
 FROM bmt_db.transactions t LEFT JOIN (SELECT transaction_id, sum(debit_amount) debit_total, sum(credit_amount) credit_total FROM bmt_db.journal_lines GROUP BY transaction_id) j ON j.transaction_id=t.id
 WHERE t.status='POSTED' AND t.posted_at::date=p_run_date RETURNING * INTO r;
 RETURN r;
END; $$;
REVOKE ALL ON FUNCTION bmt_db.run_daily_reconciliation(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.run_daily_reconciliation(date) TO authenticated;
