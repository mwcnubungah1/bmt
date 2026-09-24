# BMT production readiness

## Local/staging gate

Run from Command Prompt:

```cmd
cd /d D:\Server\apps\bmt
set SUPABASE_TELEMETRY_DISABLED=1
npx.cmd supabase test db
npm.cmd run typecheck
npm.cmd run lint
npm.cmd run build
```

Use the existing local BMT database; do not reset it for verification.
See IMPLEMENTATION_AUDIT.md for the latest localhost evidence and limitations.

The database test suite includes the onboarding/access regression tests and `production_readiness.sql`.

## Database query audit

After `supabase start` and with the database container running:

```cmd
docker cp supabase\audits\production_query_audit.sql supabase_db_bmt:/tmp/production_query_audit.sql
docker exec supabase_db_bmt psql -U postgres -d postgres -f /tmp/production_query_audit.sql
```

Review every row returned by the FK audit. Review `EXPLAIN (ANALYZE, BUFFERS)` for sequential scans, high shared reads, and unexpected RLS subplans.

## Deployment rules

- Never run `supabase db reset` against production.
- Apply migrations 001–036 forward-only through the deployment pipeline. Migration 032 closes the FK/index coverage gap found in staging; migration 033 adds authenticated applicant onboarding status to the customer portal; migration 034 persists the mandatory onboarding gender field in the draft RPC; migration 035 completes the customer form and private KTP storage policy; migration 036 provisions both private document/signature buckets and device signature storage policies.
- Run the database test gate against staging before production.
- Take a backup and perform a restore rehearsal before the first production migration.
- Store Supabase URL, publishable key, service-role key, database credentials, and JWT secrets outside the repository.
- Keep `analytics.enabled = false` for Windows local development unless Docker TCP exposure is intentionally configured.

## Remaining release evidence

Production approval requires a successful staging run of the query audit, an RLS role/branch matrix run, idempotency retry/concurrency evidence, backup/restore evidence, and a successful production frontend build on the deployment machine.
