# Frontend/Supabase audit — 2026-09-22

## Structure

React 19, React Router 7, TypeScript, Vite 8, Tailwind 4. Supabase local BMT
on port 54321, schema bmt_db, migrations 001–037. Actual database introspection
produced src/types/database.ts. No schema, migrations or RLS policies changed.
Typed client uses anon/publishable credentials and signed-in user JWTs.
Secret/non-anon JWT keys are rejected. Existing authenticated portal RPCs and
server authorization remain authoritative; route guards are an additional UX gate.

## Pages and flows

| Route | Flow |
| --- | --- |
| /login | Email/password, toggle visibility, validation, error |
| /daftar | Registration, result, return to login |
| / | Staff-role redirect or customer onboarding entry; retry failures |
| /nasabah/formulir | Own draft, returned corrections, active DB products, KTP/signature, submit |
| /nasabah | Profile, onboarding status, savings, deposits, loans, installments, transactions |
| /teller | Existing staff data; signed review or return |
| /manager | Existing staff data; signed approval and CIF finalization |
| /marketing | Read access permitted by existing branch RLS |
| /superadmin | Staff data and permitted onboarding workflow |

Database flow: DRAFT/RETURNED → TELLER_REVIEW → MANAGER_REVIEW → APPROVED → COMPLETED.
Removed wording that incorrectly described a separate marketing approval stage.

## Changes

- Stable staff pagination by primary key, 25 rows plus lookahead; retain IDs.
- Data hook rejects stale responses; loading/empty/error/retry feedback.
- Typed review service uploads real PNG/JPEG staff signatures under the current
  user's storage folder; checks type/size and requires a return reason.
- Inactive/missing profile gate and staff route role checks.
- Own saved draft/address/employment/product loaded into onboarding; active
  product choices from database; submitted application shows status.
- Required validation, future-date rejection, document validation, disable submit
  after success. Signature image encoding moved to pointer release.
- Mobile cards, wrapped pagination/upload controls, 16px form text, keyboard
  focus, reduced motion and Indonesian labels for common columns.
- Lazy dashboard/form routes, separate Supabase chunk; logo 745KB → 11KB.

## Evidence

- Type-check, ESLint, npm test: PASS.
- Build: PASS, no size warnings. Main JS 285.80KB (90.91KB gzip), Supabase
  214.54KB (55.04KB gzip), dashboard 14.16KB, onboarding 14.73KB. Both main
  chunks are needed at login; splitting improves caching, not total code size.
- Supabase: six test files, 19 TAP assertions PASS, plus SQL onboarding assertions.
- Query audit: no missing leading FK indexes. Portal probes about 3–4.5ms with
  zero rows and no customer context; not a production-load benchmark.
- Browser 360/768/1440px: public login/register/protected routes, real local Auth
  rejection, password toggle, no horizontal overflow.
- Mocked API dashboard: pagination, details, empty, error/retry, required signature.
- Mocked API onboarding: saved draft, products, return reason, required validation.
- Screenshots inspected and retained in test-results.
- Mobile skill script: PASS but zero substantive passed checks; rely on browser
  testing for responsive evidence. Bundle skill: success / zero findings.
- Legacy .claude lint/type/i18n scripts unavailable; used project checks.

## Remaining production limits

- Deployment target is localhost; no public deployment performed.
- No staging credentials supplied. Complete browser success paths against real
  Auth/storage (registration, upload, review, CIF) remain unverified. SQL tests
  independently cover database workflow and RLS.
- Upload/document/signature/submission are multiple requests, not an atomic
  transaction. Interrupted retries can leave orphan uploads/document rows.
  Durable retry deduplication and cleanup require a server contract beyond this
  schema-preserving change.
- Staff details use existing dashboard fields. Full KYC document viewing needs
  authorized storage access; storage policies were not broadened.
- Migration 038 adds authorized document/signature storage reads and the
  customer-owned `portal_get_onboarding_documents` RPC. The detail panel now
  lists documents and opens five-minute signed download URLs.
- Real-device accessibility tests, production-volume profiling, authenticated
  query benchmarks and backup/restore rehearsal remain release work.
