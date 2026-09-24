# P0–P2 implementation status

## Implemented

- Payment and staff-decision confirmation dialogs; cancellation sends no mutation.
- Required manager rejection reason; product submission lock and role-specific visibility.
- Explicit onboarding document context, complete identity/address/employment review, history and teller checklist.
- Onboarding four-step form, server draft save, timestamp, field errors and focus on invalid step.
- Stable upload paths based on content hash, existing-file verification, existing document lookup, saved application ID retained for retries. These reduce duplicate uploads but do not provide atomic cross-tab submission.
- URL-backed staff search/status/pagination, role-specific initial section, localized status badges.
- Mobile bottom navigation with expanded menu, narrower desktop sidebar, improved text contrast.
- Marketing follow-ups for existing assignments, due/completed states, in-app reminders.
- Customer onboarding status notices refreshed every minute while visible.
- Server-side RLS-filtered counts via workbench_summary; not totals calculated from a paginated list.

## Database

Migrations 053 and 054 were applied to local container supabase_db_bmt only. Apply them through the normal migration pipeline for other environments; do not replay blindly on this local database. They add customer_followups, enforce active MARKETING assignment for insertion, and expose an invoker summary RPC. Frontend uses the existing public client.

workbench_access.sql passed with transaction rollback: unassigned insert rejected, assigned insert allowed, owner completion allowed, ownership changes rejected, unrelated user read denied, anonymous access denied.

## Verification scope

Type-check, lint and production build passed. Browser workbench tests use mocked API responses for four roles at 360/768/1440px; database authorization was checked independently. This is not an authenticated end-to-end production transaction test.

## Outstanding release work

- Durable multi-tab/concurrent onboarding idempotency and orphan-upload cleanup still need a server transaction/recovery contract and concurrency tests.
- Signed storage upload through final onboarding approval has not been exercised end-to-end with real test accounts in this run.
- User confirmed in-app notifications only; email/WhatsApp/push are outside the agreed scope.
- Marketing lead pipeline, assignment administration and advanced financial/SLA reports are not implemented; current follow-ups require existing assignments and reports are counts only.
- Follow-up lists and assignment choices currently load at most 100 records; large datasets need pagination/search.
- PNG/JPG signature upload provides an alternative to drawing. Comprehensive screen-reader testing remains outstanding.

Final browser regression: workbench four roles × three viewport sizes, dashboard three sizes, onboarding three sizes, public login/register three sizes passed. In-app notification scope confirmed by user. CSV export contains the same RLS-filtered aggregate counts shown on screen.

Do not describe all P0–P2 as completed or this build as production-approved until the outstanding items are resolved.
