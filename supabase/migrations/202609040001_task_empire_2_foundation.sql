-- Task Empire 2.0: tasks, progression, rewards, and the first free-build city.
--
-- This is intentionally a forward migration. The legacy tables and RPCs remain
-- in place for data retention, but authenticated clients are moved to the v2
-- RPCs below. All dates used for streaks and compatibility counters use UTC.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Progression
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists xp integer;

alter table public.profiles
  add column if not exists player_level integer;

update public.profiles
set xp = coalesce(xp, 0),
    player_level = coalesce(player_level, 1)
where xp is null
   or player_level is null;

alter table public.profiles
  alter column xp set default 0,
  alter column xp set not null,
  alter column player_level set default 1,
  alter column player_level set not null;

alter table public.profiles
  drop constraint if exists profiles_xp_non_negative,
  drop constraint if exists profiles_player_level_positive;

alter table public.profiles
  add constraint profiles_xp_non_negative check (xp >= 0),
  add constraint profiles_player_level_positive check (player_level >= 1);

create or replace function private.player_level_for_xp_v2(p_xp integer)
returns integer
language sql
immutable
strict
set search_path = ''
as $$
  -- V2 deliberately starts with a transparent curve: every 100 XP is a level.
  select greatest(1, (greatest(p_xp, 0) / 100) + 1);
$$;

update public.profiles
set player_level = private.player_level_for_xp_v2(xp)
where player_level is distinct from private.player_level_for_xp_v2(xp);

-- ---------------------------------------------------------------------------
-- Tasks
-- ---------------------------------------------------------------------------

alter table public.tasks
  drop constraint if exists tasks_difficulty_valid;

-- character(1) cannot hold the v2 values, so transform while changing type.
-- Collapse the six legacy ranks into three adjacent pairs. This matches the
-- Flutter compatibility parser: E/D -> easy, C/B -> normal, A/S -> hard.
alter table public.tasks
  alter column difficulty drop default,
  alter column difficulty type text
  using (
    case lower(btrim(difficulty::text))
      when 'e' then 'easy'
      when 'easy' then 'easy'
      when 'd' then 'easy'
      when 'c' then 'normal'
      when 'normal' then 'normal'
      when 'b' then 'normal'
      when 'a' then 'hard'
      when 's' then 'hard'
      when 'hard' then 'hard'
      else 'normal'
    end
  );

alter table public.tasks
  alter column difficulty set default 'normal',
  alter column difficulty set not null,
  add column if not exists description text,
  add column if not exists category text,
  add column if not exists scheduled_date date,
  add column if not exists status text,
  add column if not exists verification_mode text;

update public.tasks
set description = coalesce(description, ''),
    category = coalesce(category, 'personal'),
    scheduled_date = coalesce(
      scheduled_date,
      timezone('utc', created_at)::date
    ),
    status = case when is_completed then 'completed' else 'pending' end,
    verification_mode = coalesce(verification_mode, 'none');

alter table public.tasks
  alter column description set default '',
  alter column description set not null,
  alter column category set default 'personal',
  alter column category set not null,
  alter column scheduled_date set default (timezone('utc', now())::date),
  alter column scheduled_date set not null,
  alter column status set default 'pending',
  alter column status set not null,
  alter column verification_mode set default 'none',
  alter column verification_mode set not null;

alter table public.tasks
  drop constraint if exists tasks_difficulty_v2_valid,
  drop constraint if exists tasks_category_v2_valid,
  drop constraint if exists tasks_status_v2_valid,
  drop constraint if exists tasks_verification_mode_v2_valid,
  drop constraint if exists tasks_description_v2_length;

alter table public.tasks
  add constraint tasks_difficulty_v2_valid check (
    difficulty in ('easy', 'normal', 'hard')
  ),
  add constraint tasks_category_v2_valid check (
    category in ('study', 'work', 'personal', 'health')
  ),
  add constraint tasks_status_v2_valid check (
    status in ('pending', 'completed')
  ),
  add constraint tasks_verification_mode_v2_valid check (
    verification_mode in ('none', 'ai')
  ),
  add constraint tasks_description_v2_length check (
    char_length(description) <= 4000
  );

-- Keep the legacy compatibility columns coherent. New clients cannot write
-- status/is_completed/completed_at; trusted completion RPCs update them.
create or replace function private.sync_task_compatibility_v2()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.has_deadline := new.deadline is not null;

  if tg_op = 'INSERT' then
    if new.status = 'completed' or new.is_completed then
      new.status := 'completed';
      new.is_completed := true;
    else
      new.status := 'pending';
      new.is_completed := false;
    end if;
  elsif new.status is distinct from old.status then
    new.is_completed := new.status = 'completed';
  elsif new.is_completed is distinct from old.is_completed then
    new.status := case when new.is_completed then 'completed' else 'pending' end;
  else
    new.is_completed := new.status = 'completed';
  end if;

  if new.status = 'completed' then
    if tg_op = 'INSERT' then
      new.completed_at := coalesce(new.completed_at, now());
    else
      new.completed_at := coalesce(new.completed_at, old.completed_at, now());
    end if;
    new.assessment_status := 'completed';
    new.assessment_started_at := null;
    new.assessment_token := null;
  else
    new.completed_at := null;
    if new.assessment_status = 'completed' then
      new.assessment_status := 'idle';
      new.assessment_started_at := null;
      new.assessment_token := null;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_task_compatibility_v2 on public.tasks;
create trigger sync_task_compatibility_v2
  before insert or update on public.tasks
  for each row execute function private.sync_task_compatibility_v2();

create index if not exists tasks_user_scheduled_v2_idx
  on public.tasks (user_id, scheduled_date, created_at desc);

create index if not exists tasks_user_status_v2_idx
  on public.tasks (user_id, status, scheduled_date);

-- Supports a composite owner FK from task_completions, ensuring a completion
-- cannot pair one user's id with another user's task.
create unique index if not exists tasks_id_user_v2_uidx
  on public.tasks (id, user_id);

-- ---------------------------------------------------------------------------
-- Immutable completion and economy history
-- ---------------------------------------------------------------------------

create table if not exists public.task_completions (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  task_id uuid not null,
  xp_awarded integer not null,
  gold_awarded integer not null,
  completed_at timestamp with time zone not null default now(),

  constraint task_completions_task_owner_fk
    foreign key (task_id, user_id)
    references public.tasks (id, user_id)
    on delete cascade,
  constraint task_completions_one_per_task unique (task_id),
  constraint task_completions_user_task_unique unique (user_id, task_id),
  constraint task_completions_xp_non_negative check (xp_awarded >= 0),
  constraint task_completions_gold_non_negative check (gold_awarded >= 0)
);

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.task_completions'::regclass
      and conname = 'task_completions_task_owner_fk'
  ) then
    alter table public.task_completions
      add constraint task_completions_task_owner_fk
      foreign key (task_id, user_id)
      references public.tasks (id, user_id)
      on delete cascade;
  end if;
end;
$$;

create table if not exists public.reward_ledger (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  source_type text not null,
  source_id uuid not null,
  xp_delta integer not null default 0,
  gold_delta integer not null default 0,
  created_at timestamp with time zone not null default now(),

  constraint reward_ledger_source_not_blank check (
    char_length(btrim(source_type)) between 1 and 100
  ),
  constraint reward_ledger_source_unique unique (
    user_id,
    source_type,
    source_id
  )
);

create index if not exists task_completions_user_completed_idx
  on public.task_completions (user_id, completed_at desc);

create index if not exists reward_ledger_user_created_idx
  on public.reward_ledger (user_id, created_at desc);

-- Historical completed tasks have already received their legacy gold. Record
-- zero-delta completion facts so they can never be rewarded again by v2.
insert into public.task_completions (
  user_id,
  task_id,
  xp_awarded,
  gold_awarded,
  completed_at
)
select
  task.user_id,
  task.id,
  0,
  0,
  task.completed_at
from public.tasks as task
where task.status = 'completed'
on conflict (task_id) do nothing;

insert into public.reward_ledger (
  user_id,
  source_type,
  source_id,
  xp_delta,
  gold_delta,
  created_at
)
select
  completion.user_id,
  'task_completion',
  completion.task_id,
  completion.xp_awarded,
  completion.gold_awarded,
  completion.completed_at
from public.task_completions as completion
on conflict (user_id, source_type, source_id) do nothing;

-- Internal completion primitive. The profile is always locked before the task,
-- matching city purchase lock order. Repeated calls return zero deltas and the
-- current profile, making retries safe without ever issuing a second reward.
create or replace function private.complete_task_for_user_v2(
  p_task_id uuid,
  p_user_id uuid,
  p_allow_ai boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_task public.tasks%rowtype;
  v_xp_delta integer;
  v_gold_delta integer;
  v_total_xp integer;
  v_total_gold integer;
  v_level integer;
  v_completed_at timestamp with time zone;
  v_today date := timezone('utc', now())::date;
begin
  if p_user_id is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;
  if p_task_id is null then
    raise exception using errcode = 'P0001', message = 'INVALID_TASK_ID';
  end if;

  insert into public.profiles (id)
  values (p_user_id)
  on conflict (id) do nothing;

  select profile.*
  into v_profile
  from public.profiles as profile
  where profile.id = p_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'PROFILE_NOT_FOUND';
  end if;

  select task.*
  into v_task
  from public.tasks as task
  where task.id = p_task_id
    and task.user_id = p_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'TASK_NOT_FOUND';
  end if;

  if v_task.status = 'completed' then
    insert into public.task_completions (
      user_id,
      task_id,
      xp_awarded,
      gold_awarded,
      completed_at
    )
    values (
      p_user_id,
      p_task_id,
      0,
      0,
      v_task.completed_at
    )
    on conflict (task_id) do nothing;

    insert into public.reward_ledger (
      user_id,
      source_type,
      source_id,
      xp_delta,
      gold_delta,
      created_at
    )
    values (
      p_user_id,
      'task_completion',
      p_task_id,
      0,
      0,
      v_task.completed_at
    )
    on conflict (user_id, source_type, source_id) do nothing;

    return jsonb_build_object(
      'task_id', v_task.id,
      'status', 'completed',
      'completed_at', v_task.completed_at,
      'reward', jsonb_build_object(
        'xp_delta', 0,
        'gold_delta', 0
      ),
      'profile', jsonb_build_object(
        'xp', v_profile.xp,
        'gold', v_profile.gold,
        'level', v_profile.player_level
      )
    );
  end if;

  if v_task.verification_mode = 'ai' and not coalesce(p_allow_ai, false) then
    raise exception using
      errcode = 'P0001',
      message = 'TASK_REQUIRES_AI_VERIFICATION';
  end if;

  select rewards.xp_delta, rewards.gold_delta
  into v_xp_delta, v_gold_delta
  from (
    values
      ('easy'::text, 10, 5),
      ('normal'::text, 25, 15),
      ('hard'::text, 50, 30)
  ) as rewards(difficulty, xp_delta, gold_delta)
  where rewards.difficulty = v_task.difficulty;

  if not found then
    raise exception using errcode = 'P0001', message = 'INVALID_DIFFICULTY';
  end if;

  v_completed_at := now();
  v_total_xp := v_profile.xp + v_xp_delta;
  v_total_gold := v_profile.gold + v_gold_delta;
  v_level := private.player_level_for_xp_v2(v_total_xp);

  update public.tasks as task
  set status = 'completed',
      is_completed = true,
      completed_at = v_completed_at,
      assessment_status = 'completed',
      assessment_started_at = null,
      assessment_token = null
  where task.id = p_task_id;

  update public.profiles as profile
  set xp = v_total_xp,
      gold = v_total_gold,
      player_level = v_level,
      daily_gold_earned = case
        when profile.last_calc_date = v_today
          then profile.daily_gold_earned + v_gold_delta
        else v_gold_delta
      end,
      last_calc_date = v_today
  where profile.id = p_user_id;

  insert into public.task_completions (
    user_id,
    task_id,
    xp_awarded,
    gold_awarded,
    completed_at
  )
  values (
    p_user_id,
    p_task_id,
    v_xp_delta,
    v_gold_delta,
    v_completed_at
  );

  insert into public.reward_ledger (
    user_id,
    source_type,
    source_id,
    xp_delta,
    gold_delta,
    created_at
  )
  values (
    p_user_id,
    'task_completion',
    p_task_id,
    v_xp_delta,
    v_gold_delta,
    v_completed_at
  );

  return jsonb_build_object(
    'task_id', p_task_id,
    'status', 'completed',
    'completed_at', v_completed_at,
    'reward', jsonb_build_object(
      'xp_delta', v_xp_delta,
      'gold_delta', v_gold_delta
    ),
    'profile', jsonb_build_object(
      'xp', v_total_xp,
      'gold', v_total_gold,
      'level', v_level
    )
  );
end;
$$;

-- JSON contract:
-- {
--   "task_id": uuid, "status": "completed", "completed_at": timestamptz,
--   "reward": {"xp_delta": int, "gold_delta": int},
--   "profile": {"xp": int, "gold": int, "level": int}
-- }
create or replace function public.complete_task_v2(p_task_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;

  return private.complete_task_for_user_v2(p_task_id, v_user_id, false);
end;
$$;

-- JSON contract:
-- {xp, gold, level, xp_into_level, xp_for_next_level, completed_tasks, streak}
-- A streak remains alive when its last UTC completion day is today or yesterday.
create or replace function public.get_progression_state_v2()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_completed_tasks integer;
  v_streak integer := 0;
  v_most_recent_day date;
  v_today date := timezone('utc', now())::date;
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;

  insert into public.profiles (id)
  values (v_user_id)
  on conflict (id) do nothing;

  select profile.*
  into v_profile
  from public.profiles as profile
  where profile.id = v_user_id
  for share;

  select count(*)::integer
  into v_completed_tasks
  from public.task_completions as completion
  where completion.user_id = v_user_id;

  select max(timezone('utc', completion.completed_at)::date)
  into v_most_recent_day
  from public.task_completions as completion
  where completion.user_id = v_user_id;

  if v_most_recent_day >= v_today - 1 then
    with completion_days as (
      select distinct timezone('utc', completion.completed_at)::date as day
      from public.task_completions as completion
      where completion.user_id = v_user_id
    ),
    numbered_days as (
      select
        day,
        row_number() over (order by day desc) - 1 as days_back
      from completion_days
      where day <= v_most_recent_day
    )
    select count(*)::integer
    into v_streak
    from numbered_days
    where day = v_most_recent_day - days_back::integer;
  end if;

  return jsonb_build_object(
    'xp', v_profile.xp,
    'gold', v_profile.gold,
    'level', v_profile.player_level,
    'xp_into_level', v_profile.xp % 100,
    'xp_for_next_level', 100,
    'completed_tasks', v_completed_tasks,
    'streak', v_streak
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- City v2
-- ---------------------------------------------------------------------------

create table if not exists public.cities (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null unique references public.profiles (id) on delete cascade,
  map_level integer not null default 1,
  map_width integer not null default 16,
  map_height integer not null default 16,
  created_at timestamp with time zone not null default now(),

  constraint cities_id_user_unique unique (id, user_id),
  constraint cities_map_level_positive check (map_level >= 1),
  constraint cities_map_width_positive check (map_width >= 1),
  constraint cities_map_height_positive check (map_height >= 1)
);

create table if not exists public.building_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null,
  name text not null,
  level integer not null default 1,
  price integer not null,
  required_player_level integer not null default 1,
  sprite text not null,
  footprint_width integer not null,
  footprint_height integer not null,
  prosperity integer not null default 0,
  created_at timestamp with time zone not null default now(),

  constraint building_definitions_code_level_unique unique (code, level),
  constraint building_definitions_code_not_blank check (
    char_length(btrim(code)) between 1 and 100
  ),
  constraint building_definitions_name_not_blank check (
    char_length(btrim(name)) between 1 and 200
  ),
  constraint building_definitions_level_positive check (level >= 1),
  constraint building_definitions_price_non_negative check (price >= 0),
  constraint building_definitions_required_level_positive check (
    required_player_level >= 1
  ),
  constraint building_definitions_footprint_positive check (
    footprint_width >= 1 and footprint_height >= 1
  ),
  constraint building_definitions_prosperity_non_negative check (
    prosperity >= 0
  )
);

create table if not exists public.user_buildings (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  city_id uuid not null,
  building_definition_id uuid not null references public.building_definitions (id),
  position_x integer not null,
  position_y integer not null,
  rotation smallint not null default 0,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint user_buildings_city_owner_fk
    foreign key (city_id, user_id)
    references public.cities (id, user_id)
    on delete cascade,
  constraint user_buildings_position_non_negative check (
    position_x >= 0 and position_y >= 0
  ),
  constraint user_buildings_rotation_valid check (
    rotation in (0, 90, 180, 270)
  )
);

create index if not exists user_buildings_user_idx
  on public.user_buildings (user_id);

create index if not exists user_buildings_city_idx
  on public.user_buildings (city_id);

create index if not exists user_buildings_definition_idx
  on public.user_buildings (building_definition_id);

insert into public.building_definitions (
  code,
  name,
  level,
  price,
  required_player_level,
  sprite,
  footprint_width,
  footprint_height,
  prosperity
)
values
  ('town_hall', 'Ратуша', 1, 60, 1, 'assets/city/buildings/town_hall_level_1.webp', 4, 4, 40),
  ('house', 'Дом', 1, 15, 1, 'assets/city/buildings/house_level_1.webp', 2, 2, 10),
  ('library', 'Библиотека', 1, 45, 2, 'assets/city/buildings/library_level_1.webp', 3, 3, 25),
  ('workshop', 'Мастерская', 1, 60, 3, 'assets/city/buildings/workshop_level_1.webp', 3, 2, 30),
  ('market', 'Рынок', 1, 75, 4, 'assets/city/buildings/market_level_1.webp', 3, 3, 35),
  ('tower', 'Башня', 1, 100, 5, 'assets/city/buildings/tower_level_1.webp', 2, 2, 45),
  ('garden', 'Сад', 1, 10, 1, 'assets/city/buildings/garden_level_1.webp', 2, 2, 8)
on conflict (code, level) do update
set name = excluded.name,
    price = excluded.price,
    required_player_level = excluded.required_player_level,
    sprite = excluded.sprite,
    footprint_width = excluded.footprint_width,
    footprint_height = excluded.footprint_height,
    prosperity = excluded.prosperity;

-- Legacy city buildings occupied exactly one tile. Keep separate, non-buildable
-- definitions so adjacent layouts and upgraded levels survive the v2 rollout
-- without being reinterpreted as the larger v2 footprints. Their sprite paths
-- still point at the canonical art names used by the renderer.
insert into public.building_definitions (
  code,
  name,
  level,
  price,
  required_player_level,
  sprite,
  footprint_width,
  footprint_height,
  prosperity
)
values
  ('legacy_town_hall', 'Ратуша', 1, 0, 1, 'assets/city/buildings/town_hall_level_1.webp', 1, 1, 40),
  ('legacy_town_hall', 'Ратуша', 2, 0, 1, 'assets/city/buildings/town_hall_level_2.webp', 1, 1, 80),
  ('legacy_town_hall', 'Ратуша', 3, 0, 1, 'assets/city/buildings/town_hall_level_3.webp', 1, 1, 120),
  ('legacy_town_hall', 'Ратуша', 4, 0, 1, 'assets/city/buildings/town_hall_level_4.webp', 1, 1, 160),
  ('legacy_town_hall', 'Ратуша', 5, 0, 1, 'assets/city/buildings/town_hall_level_5.webp', 1, 1, 200),
  ('legacy_market', 'Рынок', 1, 0, 1, 'assets/city/buildings/market_level_1.webp', 1, 1, 15),
  ('legacy_market', 'Рынок', 2, 0, 1, 'assets/city/buildings/market_level_2.webp', 1, 1, 30),
  ('legacy_market', 'Рынок', 3, 0, 1, 'assets/city/buildings/market_level_3.webp', 1, 1, 45),
  ('legacy_market', 'Рынок', 4, 0, 1, 'assets/city/buildings/market_level_4.webp', 1, 1, 60),
  ('legacy_market', 'Рынок', 5, 0, 1, 'assets/city/buildings/market_level_5.webp', 1, 1, 75)
on conflict (code, level) do update
set name = excluded.name,
    price = excluded.price,
    required_player_level = excluded.required_player_level,
    sprite = excluded.sprite,
    footprint_width = excluded.footprint_width,
    footprint_height = excluded.footprint_height,
    prosperity = excluded.prosperity;

-- A normal task awards 15 gold, exactly the level-1 house price.

create or replace function private.create_city_for_profile_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.cities (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists create_city_for_profile_v2 on public.profiles;
create trigger create_city_for_profile_v2
  after insert on public.profiles
  for each row execute function private.create_city_for_profile_v2();

insert into public.cities (user_id)
select profile.id
from public.profiles as profile
on conflict (user_id) do nothing;

-- Copy legacy one-tile buildings into the free-build model with the same id,
-- owner, tile, and level. Keeping this idempotent also gives the smoke suite a
-- direct way to exercise the upgrade path after inserting a legacy fixture.
create or replace function private.migrate_legacy_city_buildings_v2()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_inserted integer;
begin
  insert into public.user_buildings (
    id,
    user_id,
    city_id,
    building_definition_id,
    position_x,
    position_y,
    rotation
  )
  select
    legacy.id,
    legacy.user_id,
    city.id,
    definition.id,
    legacy.iso_x,
    legacy.iso_y,
    0
  from public.buildings as legacy
  join public.cities as city
    on city.user_id = legacy.user_id
  join public.building_definitions as definition
    on definition.code = 'legacy_' || legacy.type
   and definition.level = legacy.level
  on conflict (id) do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

select private.migrate_legacy_city_buildings_v2();

-- Shared renderer for all city v2 RPCs. It performs no settlement and awards no
-- passive income. Its share locks follow the same profile -> city order as all
-- writers, so balances and placed buildings come from one coherent state.
-- Catalog rows deliberately include null placement keys so the client can
-- consume one stable row shape for catalog and placed buildings.
-- JSON contract:
-- {
--   "profile": {"gold": int, "xp": int, "level": int, "prosperity": int},
--   "city": {"map_level": int, "map_width": int, "map_height": int},
--   "buildings": [{"id","code","name","level","position_x","position_y",
--                   "rotation","price","required_player_level","sprite",
--                   "footprint_width","footprint_height","prosperity"}],
--   "catalog": [same keys; id is definition id and placement keys are null]
-- }
create or replace function private.city_state_for_user_v2(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_city public.cities%rowtype;
  v_prosperity integer;
  v_buildings jsonb;
  v_catalog jsonb;
begin
  select profile.*
  into v_profile
  from public.profiles as profile
  where profile.id = p_user_id
  for share;

  if not found then
    raise exception using errcode = 'P0001', message = 'PROFILE_NOT_FOUND';
  end if;

  select city.*
  into v_city
  from public.cities as city
  where city.user_id = p_user_id
  for share;

  if not found then
    raise exception using errcode = 'P0001', message = 'CITY_NOT_FOUND';
  end if;

  select coalesce(sum(definition.prosperity), 0)::integer
  into v_prosperity
  from public.user_buildings as building
  join public.building_definitions as definition
    on definition.id = building.building_definition_id
  where building.user_id = p_user_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', building.id,
        'code', definition.code,
        'name', definition.name,
        'level', definition.level,
        'position_x', building.position_x,
        'position_y', building.position_y,
        'rotation', building.rotation,
        'price', definition.price,
        'required_player_level', definition.required_player_level,
        'sprite', definition.sprite,
        'footprint_width', definition.footprint_width,
        'footprint_height', definition.footprint_height,
        'prosperity', definition.prosperity
      )
      order by
        building.position_x + building.position_y,
        building.position_y,
        building.position_x,
        building.id
    ),
    '[]'::jsonb
  )
  into v_buildings
  from public.user_buildings as building
  join public.building_definitions as definition
    on definition.id = building.building_definition_id
  where building.user_id = p_user_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', definition.id,
        'code', definition.code,
        'name', definition.name,
        'level', definition.level,
        'position_x', null,
        'position_y', null,
        'rotation', null,
        'price', definition.price,
        'required_player_level', definition.required_player_level,
        'sprite', definition.sprite,
        'footprint_width', definition.footprint_width,
        'footprint_height', definition.footprint_height,
        'prosperity', definition.prosperity
      )
      order by definition.required_player_level, definition.price, definition.code
    ),
    '[]'::jsonb
  )
  into v_catalog
  from public.building_definitions as definition
  where left(definition.code, 7) <> 'legacy_';

  return jsonb_build_object(
    'profile', jsonb_build_object(
      'gold', v_profile.gold,
      'xp', v_profile.xp,
      'level', v_profile.player_level,
      'prosperity', v_prosperity
    ),
    'city', jsonb_build_object(
      'map_level', v_city.map_level,
      'map_width', v_city.map_width,
      'map_height', v_city.map_height
    ),
    'buildings', v_buildings,
    'catalog', v_catalog
  );
end;
$$;

create or replace function public.get_city_state_v2()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;

  insert into public.profiles (id)
  values (v_user_id)
  on conflict (id) do nothing;

  insert into public.cities (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  return private.city_state_for_user_v2(v_user_id);
end;
$$;

-- Purchases lock profile -> city, validate the rotated rectangular footprint,
-- debit once, insert once, and write the debit to reward_ledger atomically.
-- Returns the complete get_city_state_v2 JSON contract.
drop function if exists public.build_city_building_v2(
  text,
  integer,
  integer,
  integer
);

create function public.build_city_building_v2(
  p_code text,
  p_position_x integer,
  p_position_y integer,
  p_rotation integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_city public.cities%rowtype;
  v_definition public.building_definitions%rowtype;
  v_width integer;
  v_height integer;
  v_building_id uuid;
  v_prosperity integer;
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;
  if p_code is null or btrim(p_code) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_BUILDING_CODE';
  end if;
  if p_position_x is null or p_position_y is null then
    raise exception using errcode = 'P0001', message = 'INVALID_POSITION';
  end if;
  if p_rotation is null or p_rotation not in (0, 90, 180, 270) then
    raise exception using errcode = 'P0001', message = 'INVALID_ROTATION';
  end if;

  insert into public.profiles (id)
  values (v_user_id)
  on conflict (id) do nothing;

  select profile.*
  into v_profile
  from public.profiles as profile
  where profile.id = v_user_id
  for update;

  insert into public.cities (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select city.*
  into v_city
  from public.cities as city
  where city.user_id = v_user_id
  for update;

  select definition.*
  into v_definition
  from public.building_definitions as definition
  where definition.code = lower(btrim(p_code))
    and left(definition.code, 7) <> 'legacy_'
    and definition.level = 1;

  if not found then
    raise exception using errcode = 'P0001', message = 'BUILDING_NOT_FOUND';
  end if;
  if v_profile.player_level < v_definition.required_player_level then
    raise exception using errcode = 'P0001', message = 'BUILDING_LOCKED';
  end if;

  v_width := case
    when p_rotation in (90, 270) then v_definition.footprint_height
    else v_definition.footprint_width
  end;
  v_height := case
    when p_rotation in (90, 270) then v_definition.footprint_width
    else v_definition.footprint_height
  end;

  if p_position_x < 0
     or p_position_y < 0
     or p_position_x + v_width > v_city.map_width
     or p_position_y + v_height > v_city.map_height then
    raise exception using errcode = 'P0001', message = 'OUT_OF_BOUNDS';
  end if;

  if exists (
    select 1
    from public.user_buildings as building
    join public.building_definitions as definition
      on definition.id = building.building_definition_id
    where building.city_id = v_city.id
      and p_position_x < building.position_x + case
        when building.rotation in (90, 270) then definition.footprint_height
        else definition.footprint_width
      end
      and p_position_x + v_width > building.position_x
      and p_position_y < building.position_y + case
        when building.rotation in (90, 270) then definition.footprint_width
        else definition.footprint_height
      end
      and p_position_y + v_height > building.position_y
  ) then
    raise exception using errcode = 'P0001', message = 'BUILDING_OVERLAP';
  end if;

  if v_profile.gold < v_definition.price then
    raise exception using errcode = 'P0001', message = 'INSUFFICIENT_GOLD';
  end if;

  insert into public.user_buildings (
    user_id,
    city_id,
    building_definition_id,
    position_x,
    position_y,
    rotation
  )
  values (
    v_user_id,
    v_city.id,
    v_definition.id,
    p_position_x,
    p_position_y,
    p_rotation
  )
  returning id into v_building_id;

  select coalesce(sum(definition.prosperity), 0)::integer
  into v_prosperity
  from public.user_buildings as building
  join public.building_definitions as definition
    on definition.id = building.building_definition_id
  where building.user_id = v_user_id;

  update public.profiles as profile
  set gold = profile.gold - v_definition.price,
      prosperity = v_prosperity
  where profile.id = v_user_id;

  insert into public.reward_ledger (
    user_id,
    source_type,
    source_id,
    xp_delta,
    gold_delta
  )
  values (
    v_user_id,
    'building_purchase',
    v_building_id,
    0,
    -v_definition.price
  );

  return private.city_state_for_user_v2(v_user_id);
end;
$$;

-- Moving owns no economy side effect: it locks the city/building, repeats the
-- same bounds and overlap checks, updates placement, and returns full city state.
drop function if exists public.move_city_building_v2(
  uuid,
  integer,
  integer,
  integer
);

create function public.move_city_building_v2(
  p_building_id uuid,
  p_position_x integer,
  p_position_y integer,
  p_rotation integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_city public.cities%rowtype;
  v_building public.user_buildings%rowtype;
  v_definition public.building_definitions%rowtype;
  v_width integer;
  v_height integer;
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;
  if p_building_id is null then
    raise exception using errcode = 'P0001', message = 'INVALID_BUILDING_ID';
  end if;
  if p_position_x is null or p_position_y is null then
    raise exception using errcode = 'P0001', message = 'INVALID_POSITION';
  end if;
  if p_rotation is null or p_rotation not in (0, 90, 180, 270) then
    raise exception using errcode = 'P0001', message = 'INVALID_ROTATION';
  end if;

  insert into public.profiles (id)
  values (v_user_id)
  on conflict (id) do nothing;

  select profile.*
  into v_profile
  from public.profiles as profile
  where profile.id = v_user_id
  for update;

  insert into public.cities (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select city.*
  into v_city
  from public.cities as city
  where city.user_id = v_user_id
  for update;

  select building.*
  into v_building
  from public.user_buildings as building
  where building.id = p_building_id
    and building.user_id = v_user_id
    and building.city_id = v_city.id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'BUILDING_NOT_FOUND';
  end if;

  select definition.*
  into v_definition
  from public.building_definitions as definition
  where definition.id = v_building.building_definition_id;

  v_width := case
    when p_rotation in (90, 270) then v_definition.footprint_height
    else v_definition.footprint_width
  end;
  v_height := case
    when p_rotation in (90, 270) then v_definition.footprint_width
    else v_definition.footprint_height
  end;

  if p_position_x < 0
     or p_position_y < 0
     or p_position_x + v_width > v_city.map_width
     or p_position_y + v_height > v_city.map_height then
    raise exception using errcode = 'P0001', message = 'OUT_OF_BOUNDS';
  end if;

  if exists (
    select 1
    from public.user_buildings as other_building
    join public.building_definitions as other_definition
      on other_definition.id = other_building.building_definition_id
    where other_building.city_id = v_city.id
      and other_building.id <> p_building_id
      and p_position_x < other_building.position_x + case
        when other_building.rotation in (90, 270)
          then other_definition.footprint_height
        else other_definition.footprint_width
      end
      and p_position_x + v_width > other_building.position_x
      and p_position_y < other_building.position_y + case
        when other_building.rotation in (90, 270)
          then other_definition.footprint_width
        else other_definition.footprint_height
      end
      and p_position_y + v_height > other_building.position_y
  ) then
    raise exception using errcode = 'P0001', message = 'BUILDING_OVERLAP';
  end if;

  update public.user_buildings as building
  set position_x = p_position_x,
      position_y = p_position_y,
      rotation = p_rotation,
      updated_at = now()
  where building.id = p_building_id;

  return private.city_state_for_user_v2(v_user_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Keep the existing AI Edge Function service RPC compatible with v2.
-- ---------------------------------------------------------------------------
-- It accepts both legacy E-S ranks and v2 names so the database can be deployed
-- before the updated Edge Function. The legacy daily counter remains in the
-- returned row as a rollout-only compatibility field; it does not cap rewards.

drop function if exists public.complete_task_award(uuid, uuid, uuid, text);

create function public.complete_task_award(
  p_task_id uuid,
  p_user_id uuid,
  p_request_id uuid,
  p_approved_difficulty text
)
returns table (
  task_id uuid,
  approved_difficulty text,
  xp_awarded integer,
  gold_awarded integer,
  total_xp integer,
  total_gold integer,
  daily_gold_earned integer,
  player_level integer,
  completed_at timestamp with time zone
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_task public.tasks%rowtype;
  v_difficulty text := case lower(btrim(p_approved_difficulty))
    when 'e' then 'easy'
    when 'easy' then 'easy'
    when 'd' then 'easy'
    when 'c' then 'normal'
    when 'normal' then 'normal'
    when 'b' then 'normal'
    when 'a' then 'hard'
    when 's' then 'hard'
    when 'hard' then 'hard'
    else null
  end;
  v_return_difficulty text := case
    when lower(btrim(p_approved_difficulty)) in ('e', 'd', 'c', 'b', 'a', 's')
      then upper(btrim(p_approved_difficulty))
    else v_difficulty
  end;
  v_result jsonb;
  v_daily_gold_earned integer;
begin
  if v_difficulty is null then
    raise exception using errcode = 'P0001', message = 'INVALID_DIFFICULTY';
  end if;

  select profile.*
  into v_profile
  from public.profiles as profile
  where profile.id = p_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'PROFILE_NOT_FOUND';
  end if;

  select task.*
  into v_task
  from public.tasks as task
  where task.id = p_task_id
    and task.user_id = p_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'TASK_NOT_FOUND';
  end if;
  if v_task.status = 'completed' then
    raise exception using errcode = 'P0001', message = 'TASK_ALREADY_COMPLETED';
  end if;
  if v_task.assessment_status <> 'processing'
     or v_task.assessment_token is distinct from p_request_id
     or v_task.assessment_started_at is null
     or v_task.assessment_started_at <= now() - interval '2 minutes' then
    raise exception using
      errcode = 'P0001',
      message = 'ASSESSMENT_RESERVATION_LOST';
  end if;

  update public.tasks as task
  set difficulty = v_difficulty
  where task.id = p_task_id;

  v_result := private.complete_task_for_user_v2(
    p_task_id,
    p_user_id,
    true
  );

  select profile.daily_gold_earned
  into v_daily_gold_earned
  from public.profiles as profile
  where profile.id = p_user_id;

  return query
  select
    p_task_id,
    v_return_difficulty,
    (v_result #>> '{reward,xp_delta}')::integer,
    (v_result #>> '{reward,gold_delta}')::integer,
    (v_result #>> '{profile,xp}')::integer,
    (v_result #>> '{profile,gold}')::integer,
    v_daily_gold_earned,
    (v_result #>> '{profile,level}')::integer,
    (v_result ->> 'completed_at')::timestamp with time zone;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS and privileges
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.task_completions enable row level security;
alter table public.reward_ledger enable row level security;
alter table public.cities enable row level security;
alter table public.building_definitions enable row level security;
alter table public.user_buildings enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists tasks_select_own on public.tasks;
create policy tasks_select_own
  on public.tasks
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists tasks_insert_own on public.tasks;
create policy tasks_insert_own
  on public.tasks
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and status = 'pending'
    and not is_completed
    and completed_at is null
    and assessment_status = 'idle'
  );

drop policy if exists tasks_update_metadata_own on public.tasks;
create policy tasks_update_metadata_own
  on public.tasks
  for update
  to authenticated
  using (
    (select auth.uid()) = user_id
    and status = 'pending'
    and (
      assessment_status = 'idle'
      or assessment_started_at <= now() - interval '2 minutes'
    )
  )
  with check (
    (select auth.uid()) = user_id
    and status = 'pending'
    and not is_completed
    and completed_at is null
    and (
      assessment_status = 'idle'
      or assessment_started_at <= now() - interval '2 minutes'
    )
  );

drop policy if exists tasks_delete_own on public.tasks;
create policy tasks_delete_own
  on public.tasks
  for delete
  to authenticated
  using (
    (select auth.uid()) = user_id
    and status = 'pending'
    and not is_completed
    and (
      assessment_status = 'idle'
      or assessment_started_at <= now() - interval '2 minutes'
    )
  );

drop policy if exists task_completions_select_own on public.task_completions;
create policy task_completions_select_own
  on public.task_completions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists reward_ledger_select_own on public.reward_ledger;
create policy reward_ledger_select_own
  on public.reward_ledger
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists cities_select_own on public.cities;
create policy cities_select_own
  on public.cities
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists building_definitions_select_authenticated
  on public.building_definitions;
create policy building_definitions_select_authenticated
  on public.building_definitions
  for select
  to authenticated
  using (true);

drop policy if exists user_buildings_select_own on public.user_buildings;
create policy user_buildings_select_own
  on public.user_buildings
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.profiles,
                    public.tasks,
                    public.task_completions,
                    public.reward_ledger,
                    public.cities,
                    public.building_definitions,
                    public.user_buildings
  from anon, authenticated;

grant select on table public.profiles,
                      public.tasks,
                      public.task_completions,
                      public.reward_ledger,
                      public.cities,
                      public.building_definitions,
                      public.user_buildings
  to authenticated;

grant insert (
  user_id,
  title,
  description,
  category,
  difficulty,
  scheduled_date,
  deadline,
  verification_mode
)
on public.tasks to authenticated;

grant update (
  title,
  description,
  category,
  difficulty,
  scheduled_date,
  deadline,
  verification_mode
)
on public.tasks to authenticated;

grant delete on table public.tasks to authenticated;

revoke all on function private.player_level_for_xp_v2(integer)
  from public, anon, authenticated;
revoke all on function private.sync_task_compatibility_v2()
  from public, anon, authenticated;
revoke all on function private.complete_task_for_user_v2(uuid, uuid, boolean)
  from public, anon, authenticated;
revoke all on function private.create_city_for_profile_v2()
  from public, anon, authenticated;
revoke all on function private.city_state_for_user_v2(uuid)
  from public, anon, authenticated;
revoke all on function private.migrate_legacy_city_buildings_v2()
  from public, anon, authenticated;

revoke all on function public.complete_task_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.get_progression_state_v2()
  from public, anon, authenticated;
revoke all on function public.get_city_state_v2()
  from public, anon, authenticated;
revoke all on function public.build_city_building_v2(text, integer, integer, integer)
  from public, anon, authenticated;
revoke all on function public.move_city_building_v2(uuid, integer, integer, integer)
  from public, anon, authenticated;
revoke all on function public.complete_task_award(uuid, uuid, uuid, text)
  from public, anon, authenticated;

grant execute on function public.complete_task_v2(uuid) to authenticated;
grant execute on function public.get_progression_state_v2() to authenticated;
grant execute on function public.get_city_state_v2() to authenticated;
grant execute on function public.build_city_building_v2(text, integer, integer, integer)
  to authenticated;
grant execute on function public.move_city_building_v2(uuid, integer, integer, integer)
  to authenticated;
grant execute on function public.complete_task_award(uuid, uuid, uuid, text)
  to service_role;

-- Retire authenticated access to legacy city RPCs: they settle passive income
-- and mutate the old one-tile buildings table, both intentionally absent in v2.
revoke all on function public.get_city_state()
  from public, anon, authenticated;
revoke all on function public.build_city_building(text, integer, integer)
  from public, anon, authenticated;
revoke all on function public.upgrade_city_building(uuid)
  from public, anon, authenticated;
