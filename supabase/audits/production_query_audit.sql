-- Run against the local/staging database with psql.
-- This is intentionally not a migration or pg_prove test: EXPLAIN ANALYZE executes queries.

\set ON_ERROR_STOP on

\echo '=== FK columns without a leading matching index ==='
WITH fk AS (
    SELECT con.oid, con.conrelid, con.conname,
           array_agg(att.attname ORDER BY u.ord) AS columns
    FROM pg_constraint con
    CROSS JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS u(attnum, ord)
    JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = u.attnum
    WHERE con.contype = 'f'
      AND con.connamespace = 'bmt_db'::regnamespace
    GROUP BY con.oid, con.conrelid, con.conname
), indexes AS (
    SELECT i.indrelid, array_agg(a.attname ORDER BY x.ord) AS columns
    FROM pg_index i
    CROSS JOIN LATERAL unnest(i.indkey) WITH ORDINALITY AS x(attnum, ord)
    JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = x.attnum
    WHERE x.ord <= i.indnkeyatts
    GROUP BY i.indexrelid, i.indrelid
)
SELECT fk.conname, fk.columns
FROM fk
WHERE NOT EXISTS (
    SELECT 1 FROM indexes i
    WHERE i.indrelid = fk.conrelid
      AND i.columns[1:array_length(fk.columns, 1)] = fk.columns
)
ORDER BY fk.conname;

\echo '=== Portal transactions ==='
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM bmt_db.portal_get_transactions(50, 0);

\echo '=== Portal loan schedules ==='
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM bmt_db.portal_get_loan_schedules(50, 0);

\echo '=== Dashboard transactions ==='
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT t.id, t.transaction_number, t.amount, t.status
FROM bmt_db.transactions t
WHERE t.branch_id = '00000000-0000-0000-0000-000000000000'::uuid
ORDER BY t.transaction_date DESC, t.created_at DESC
LIMIT 50;

\echo '=== Ledger journal lines ==='
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT jl.*
FROM bmt_db.journal_lines jl
JOIN bmt_db.journal_entries je ON je.id = jl.journal_entry_id
WHERE je.status = 'POSTED'
ORDER BY je.journal_date DESC, jl.line_no
LIMIT 100;
