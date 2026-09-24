\set aid random(1, 12)
SELECT t.id, t.transaction_number, t.amount, t.status
FROM bmt_db.transactions t
WHERE t.customer_id = (SELECT id FROM bmt_db.customers ORDER BY id OFFSET :aid LIMIT 1)
ORDER BY t.transaction_date DESC, t.created_at DESC
LIMIT 50;

SELECT ls.id, ls.loan_account_id, ls.installment_no, ls.due_date, ls.status
FROM bmt_db.loan_schedules ls
JOIN bmt_db.loan_accounts la ON la.financial_account_id = ls.loan_account_id
ORDER BY ls.due_date, ls.installment_no
LIMIT 50;
