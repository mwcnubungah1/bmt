# BMT NU Bungah

React 19, TypeScript, Vite 8, Tailwind 4, Supabase Auth/Postgres/Storage.
Database schema: bmt_db. Actual generated types: src/types/database.ts.

## Localhost

Use the existing Supabase BMT instance on port 54321. Configure
VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in .env.local.
Only anon JWT or publishable keys are accepted by the frontend.

```sh
npm ci
npm test
npm run build
npm run preview -- --host 127.0.0.1 --port 4173 --strictPort
```

Open http://127.0.0.1:4173. Development server: npm run dev (5173).
Vite preview is for local verification, not public production hosting.
Future public hosting should serve dist with HTTPS and an index.html fallback
for application routes; configure Supabase redirects for the actual domain.

## Verification

```sh
npm run typecheck
npm run lint
npm run test:db
python -m pip install playwright
python -m playwright install chromium
# Keep preview running on 4173:
npm run test:browser
```

Tests cover 360/768/1440 px. Public tests use local Auth for invalid login.
Dashboard/onboarding tests mock API responses, while SQL tests separately
exercise database workflow and RLS. Screenshots are in test-results.

Regenerate types after intentional schema changes:
`npx supabase gen types typescript --local --schema bmt_db > src/types/database.ts`

Do not reset the database or apply migrations just to start the frontend.
See IMPLEMENTATION_AUDIT.md for flows, evidence and remaining limitations.
