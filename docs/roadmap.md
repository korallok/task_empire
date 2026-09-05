# Task Empire 2.0 roadmap

Status is measured against a production definition of done, not merely a
working happy path.

| Phase | Current status | Exit condition |
| --- | --- | --- |
| Backup and Git | Complete | Verified archive, project-local repository, clean baseline commit |
| Core loop and economy | Foundation implemented | Three difficulties, server XP/gold, immutable ledger, duplicate protection |
| Visual direction | Working direction | Product owner approves screen compositions and final typography |
| Flutter design system | Foundation implemented | Shared theme/tokens used by all new screens; component catalog reviewed |
| Tasks | Core CRUD implemented | Add recurrence, integration/E2E coverage, notification behavior |
| Progression | Core implemented | Balance playtest, unlock curve, history and analytics |
| City | First free-build slice | Production assets, upgrades, delete flow, territory expansion, touch/desktop QA |
| Blender art | Pipeline only | Approve Town Hall I–III before mass production |
| Supabase | V2 migration implemented | Apply to local/staging DB, run SQL/RLS smoke suite, rehearse rollback |
| AI verification | Backend compatibility only | Evidence upload, privacy rules, quota UX, failure/retry flow |
| Release QA | Not started | Android/desktop toolchains, E2E suite, accessibility, performance and store checks |

## Next implementation order

1. Apply the v2 migration to a disposable local Supabase instance and run the
   transactional smoke test.
2. Exercise the full ordinary loop in the Flutter preview and against local
   Supabase.
3. Design and approve Town Hall levels I–III using the fixed Blender pipeline.
4. Add building upgrades and territory expansion against those approved assets.
5. Implement guest-account linking without changing the authenticated user id.
6. Build evidence storage and restore AI verification as an optional path.
7. Add integration tests for two-user RLS isolation and app restart restore.

Do not start social features until the task → reward → city loop passes release
QA on both mobile and desktop input modes.
