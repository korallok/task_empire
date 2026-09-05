# Task Empire 2.0 — foundation decisions

This document records the first production-oriented vertical slice. It is the
contract between Flutter, Supabase, tests, and future art assets.

## Product loop in this slice

```text
Create a real task
  -> complete it
  -> receive server-calculated XP and gold
  -> enter city edit mode
  -> place a building on the hidden grid
  -> reload and see the same city
```

The task remains the primary source of progress. Reading the city no longer
settles passive income, and Flutter never mutates XP or gold locally.

## Economy v2

| Difficulty | XP | Gold |
| --- | ---: | ---: |
| Easy | 10 | 5 |
| Normal | 25 | 15 |
| Hard | 50 | 30 |

Player level is derived on the server. The initial transparent curve is one
level per 100 XP. It can be rebalanced later without changing task records or
the reward ledger.

Every completion produces one `task_completions` row and one immutable
`reward_ledger` row. Their uniqueness constraints are the final protection
against duplicate rewards; UI debouncing is only a convenience.

## Task boundaries

The task model owns planning data only:

- title and description;
- one of four initial categories;
- one of three difficulties;
- scheduled day and optional deadline;
- pending/completed status;
- optional verification mode.

Progression, city state, verification results, and analytics are deliberately
kept outside this model. Recurrence will be introduced later as templates and
occurrences rather than fields that overload a single task row.

## City placement contract

The user sees free placement, while the implementation snaps the footprint
origin to an integer grid. A definition supplies width and height; 90° and 270°
rotations swap them. Both Flutter and PostgreSQL evaluate the same rectangular
rules:

1. every footprint cell must be inside the current map;
2. the footprint must not overlap another user building;
3. the definition must be unlocked for the current player level;
4. the server must observe enough gold at the moment it locks the profile.

Flutter's green/red preview is explanatory. Only the atomic RPC can approve a
purchase or move.

Legacy `buildings` rows are copied idempotently into `user_buildings` during
the migration. Their ids, owners, levels, and original 8×8 tile coordinates
are retained. They use internal one-tile `legacy_*` definitions so an old
adjacent layout cannot become invalid when v2 introduces larger footprints;
those definitions render with the canonical Town Hall/Market art but cannot be
purchased through the v2 catalog or RPC.

## Architecture boundary

```text
presentation widgets
  -> feature BLoC
  -> repository interface
  -> Supabase implementation
  -> RLS + security-definer RPC
  -> immutable ledger / persisted city
```

Widgets receive data and callbacks. Reward calculation, balance changes,
ownership checks, unlocks, map bounds, and collision authority remain on the
server.

## Deferred deliberately

- evidence upload and the final AI-verification UX;
- recurrence templates and occurrences;
- account-linking screens;
- territory purchases and new districts;
- building upgrades with level-specific art;
- production Blender renders;
- social city sharing.

These are not represented as working controls in the foundation UI. The
existing AI path remains backend-compatible, but the ordinary task loop has no
OpenAI dependency.

## Acceptance checks

- A normal task awards exactly 25 XP and 15 gold.
- Repeating completion awards zero additional currency.
- A house costs 15 gold and has a 2×2 footprint.
- Overlap and out-of-bounds placement are rejected locally and by PostgreSQL.
- Moving a building never changes the balance.
- Reloading `get_city_state_v2` restores coordinates and rotation.
- RLS hides tasks, ledgers, cities, and buildings owned by another user.
