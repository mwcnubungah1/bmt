-- BMT 032 - cover foreign keys that do not already have a leading index.
-- Generated names are stable, bounded, and safe to re-run.

DO $$
DECLARE
    v_fk RECORD;
    v_index_name TEXT;
    v_columns TEXT;
BEGIN
    FOR v_fk IN
        WITH fk AS (
            SELECT con.oid, con.conrelid, con.conname,
                   n.nspname AS schema_name, c.relname AS table_name,
                   array_agg(att.attname ORDER BY u.ord) AS columns
            FROM pg_constraint con
            JOIN pg_class c ON c.oid = con.conrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            CROSS JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS u(attnum, ord)
            JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = u.attnum
            WHERE con.contype = 'f' AND n.nspname = 'bmt_db'
            GROUP BY con.oid, con.conrelid, con.conname, n.nspname, c.relname
        ), indexes AS (
            SELECT i.indrelid, array_agg(a.attname ORDER BY x.ord) AS columns
            FROM pg_index i
            CROSS JOIN LATERAL unnest(i.indkey) WITH ORDINALITY AS x(attnum, ord)
            JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = x.attnum
            WHERE x.ord <= i.indnkeyatts
            GROUP BY i.indexrelid, i.indrelid
        )
        SELECT fk.*
        FROM fk
        WHERE NOT EXISTS (
            SELECT 1 FROM indexes i
            WHERE i.indrelid = fk.conrelid
              AND i.columns[1:array_length(fk.columns, 1)] = fk.columns
        )
    LOOP
        SELECT string_agg(format('%I', column_name), ', ' ORDER BY ordinal)
          INTO v_columns
          FROM unnest(v_fk.columns) WITH ORDINALITY AS x(column_name, ordinal);

        v_index_name := 'ix_fk_' || substr(md5(v_fk.schema_name || '.' || v_fk.table_name || '.' || v_fk.conname), 1, 24);

        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON %I.%I (%s)',
            v_index_name,
            v_fk.schema_name,
            v_fk.table_name,
            v_columns
        );
    END LOOP;
END;
$$;

COMMENT ON SCHEMA bmt_db IS
'BMT Core Banking System - FK index coverage is enforced by forward-only migration 032.';
