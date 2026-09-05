# Task Empire 2.0

Task Empire turns real productivity into a city the user builds personally:

```text
task -> server reward -> XP + gold -> free city building
```

The Flutter client owns presentation and interaction. Supabase remains the
authority for task completion, rewards, balance, unlocks, map bounds, building
collisions, and persistence.

## Foundation included

- Russian Flutter UI with four destinations: Today, Calendar, City, Profile.
- Easy, normal, and hard tasks with fixed visible reward expectations.
- Task title, description, category, scheduled day, optional deadline, edit,
  reschedule, delete, completion, loading, empty, and error states.
- Server-owned XP, level, gold, completion history, and immutable reward ledger.
- Optional AI verification data model; ordinary completion has no OpenAI
  dependency. The final evidence-upload UI is deliberately deferred.
- Isometric city with pan/zoom, explicit edit mode, hidden-grid snapping,
  footprint-aware preview, rotation, overlap/bounds checks, server purchase,
  move, coordinate restore, and base-coordinate depth sorting.
- Seven initial building definitions: Town Hall, House, Library, Workshop,
  Market, Tower, and Garden.
- Anonymous first launch. Permanent account linking remains a release-roadmap
  item; the profile screen labels guest state explicitly.

Product and implementation decisions are recorded in
[`docs/task_empire_2_foundation.md`](docs/task_empire_2_foundation.md). The
working visual language is recorded in
[`docs/design_system.md`](docs/design_system.md), and remaining work is tracked
in [`docs/roadmap.md`](docs/roadmap.md).

## Requirements

- Flutter 3.35 or newer
- Dart 3.9 or newer
- Supabase CLI and Docker for local backend development
- A Supabase project with Anonymous Sign-Ins enabled
- Deno for Edge Function checks

OpenAI credentials are needed only when exercising the optional AI completion
path.

## Local backend

Start Supabase and apply every migration:

```powershell
supabase start
supabase db reset
supabase status
```

Run the v2 transactional security/economy smoke test with the database URL from
`supabase status`:

```powershell
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 `
  -f supabase/tests/task_empire_2_foundation_smoke.sql
```

For optional AI verification, copy `supabase/.env.example` to an ignored local
environment file, provide the OpenAI settings, and serve the function:

```powershell
supabase functions serve complete_task_secure `
  --env-file supabase/.env.local
```

## Run Flutter

Use the local API URL and publishable key printed by `supabase status`:

```powershell
flutter pub get
flutter run -d edge `
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_ANON_KEY
```

Production URLs must use HTTPS. Plain HTTP is accepted only for localhost and
loopback addresses.

The backend-free visual fixture is available through:

```powershell
flutter run -d edge -t tool/design_preview.dart
```

## Quality checks

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub
deno fmt --check supabase/functions
deno test supabase/functions/complete_task_secure/index_test.ts
supabase db lint --local --fail-on error
```

Flutter unit and widget tests use repository interfaces and do not require a
live Supabase project. Database authority, RLS isolation, reward idempotency,
building overlap, bounds, debit, and move invariants are checked separately by
the SQL smoke test.

## Deploy

Apply migrations before deploying the matching Edge Function:

```powershell
supabase db push
supabase secrets set OPENAI_API_KEY=YOUR_KEY OPENAI_MODEL=YOUR_MODEL_ID
supabase functions deploy complete_task_secure
```

Deploy to a disposable or staging project first. The v2 migration preserves the
legacy task and building data while moving active Flutter flows to the new RPCs.

## Blender assets

The city renders vector fallbacks until a matching transparent WebP/PNG asset
exists. All assets must share camera, light, scale, origin, and footprint rules.
Approve Town Hall levels I–III before mass-producing the rest of the catalog.
See [`docs/blender_asset_pipeline.md`](docs/blender_asset_pipeline.md).
