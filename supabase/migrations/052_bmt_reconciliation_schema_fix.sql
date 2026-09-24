CREATE OR REPLACE FUNCTION bmt_db.run_daily_reconciliation(p_run_date DATE DEFAULT CURRENT_DATE)
RETURNS bmt_db.daily_reconciliation_runs LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r bmt_db.daily_reconciliation_runs;
BEGIN
 INSERT INTO bmt_db.daily_reconciliation_runs(run_date,transaction_count,posted_amount,debit_total,credit_total,variance,status,notes)
 SELECT p_run_date, count(DISTINCT t.id), coalesce(sum(DISTINCT t.amount),0), coalesce(sum(j.debit_total),0), coalesce(sum(j.credit_total),0), coalesce(sum(j.debit_total-j.credit_total),0),
   CASE WHEN coalesce(sum(j.debit_total-j.credit_total),0)=0 THEN 'BALANCED' ELSE 'EXCEPTION' END,
   CASE WHEN coalesce(sum(j.debit_total-j.credit_total),0)=0 THEN NULL ELSE 'Journal debit/credit tidak seimbang' END
 FROM bmt_db.transactions t
 LEFT JOIN (SELECT je.transaction_id, sum(jl.debit) debit_total, sum(jl.credit) credit_total FROM bmt_db.journal_entries je JOIN bmt_db.journal_lines jl ON jl.journal_entry_id=je.id GROUP BY je.transaction_id) j ON j.transaction_id=t.id
 WHERE t.status='POSTED' AND t.posted_at::date=p_run_date RETURNING * INTO r;
 RETURN r;
END; $$;
