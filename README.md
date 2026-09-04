# Task Empire

Task Empire is a Flutter calendar game: completing real tasks awards server-side
gold that can be spent on an isometric city.

The active application uses Supabase as the only source of truth. Tasks,
completion rewards, city buildings, passive income, and daily limits are stored
and calculated on the server. The client never chooses its own reward.

## Requirements

- Flutter 3.35 or newer
- Dart 3.9 or newer
- Supabase CLI and Docker for local backend development
- A Supabase project with Anonymous Sign-Ins enabled
- An OpenAI API model that supports the Responses API and structured outputs

## Local backend

Start Supabase and apply every migration:

```powershell
supabase start
supabase db reset
supabase status
```

Copy `supabase/.env.example` to `supabase/.env.local`, provide the OpenAI
settings, and serve the secured completion function:

```powershell
supabase functions serve complete_task_secure --env-file supabase/.env.local
```

The local `supabase/config.toml` enables anonymous sign-ins. Enable the same
authentication provider in the Supabase dashboard before deploying.

## Run Flutter

Use the API URL and publishable/anonymous key printed by `supabase status`:

```powershell
flutter pub get
flutter run -d chrome `
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_ANON_KEY
```

Production URLs must use HTTPS. Plain HTTP is accepted only for localhost and
loopback addresses.

## Deploy

Apply migrations before deploying the matching Edge Function:

```powershell
supabase db push
supabase secrets set OPENAI_API_KEY=YOUR_KEY OPENAI_MODEL=YOUR_MODEL_ID
supabase functions deploy complete_task_secure
```

The completion flow reserves a task before calling OpenAI. One user can start at
most 30 assessments per UTC day, and only the request holding the reservation
can award gold. Failed model calls release the reservation.

There is intentionally no paid store in the current build. Store products must
not be reintroduced until App Store or Google Play transactions are verified by
a trusted backend.

## Quality checks

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub
deno fmt --check supabase/functions
deno test supabase/functions/complete_task_secure/index_test.ts
supabase db lint --local --fail-on error
```

Flutter unit tests use repository interfaces and do not require a live
Supabase project. Database migrations and the Edge Function are checked
separately in CI.

## Blender city assets

The city scene supports dragging, pinch zoom, mouse-wheel zoom, camera
recentering, depth sorting, and transparent Blender renders. Until a matching
sprite exists, the application keeps using its vector fallback building.

Follow [docs/blender_asset_pipeline.md](docs/blender_asset_pipeline.md) to
create and export the first building. Blender renders placed in
`assets/city/buildings` are detected automatically.
