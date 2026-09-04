-- Calendar Strategy: initial Supabase schema.
-- All dates used for the daily economy are stored/calculated in UTC.

create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  gold integer not null default 100,
  prosperity integer not null default 0,
  daily_gold_earned integer not null default 0,
  last_calc_date date not null default (timezone('utc', now())::date),

  constraint profiles_gold_non_negative check (gold >= 0),
  constraint profiles_prosperity_non_negative check (prosperity >= 0),
  constraint profiles_daily_gold_non_negative check (daily_gold_earned >= 0)
);

create table public.tasks (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  difficulty character(1) not null default 'E',
  has_deadline boolean not null default false,
  deadline timestamp with time zone,
  is_completed boolean not null default false,
  created_at timestamp with time zone not null default now(),
  completed_at timestamp with time zone,

  constraint tasks_title_not_blank check (
    char_length(btrim(title)) between 1 and 500
  ),
  constraint tasks_difficulty_valid check (
    difficulty in ('E', 'D', 'C', 'B', 'A', 'S')
  ),
  constraint tasks_deadline_consistent check (
    (has_deadline and deadline is not null)
    or (not has_deadline and deadline is null)
  ),
  constraint tasks_completion_consistent check (
    is_completed = (completed_at is not null)
  )
);

create table public.buildings (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  level integer not null default 1,
  iso_x integer not null,
  iso_y integer not null,

  constraint buildings_type_valid check (type in ('town_hall', 'market')),
  constraint buildings_level_positive check (level >= 1),
  constraint buildings_iso_x_in_grid check (iso_x between 0 and 7),
  constraint buildings_iso_y_in_grid check (iso_y between 0 and 7),
  constraint buildings_one_per_tile unique (user_id, iso_x, iso_y)
);

create index tasks_user_created_idx
  on public.tasks (user_id, created_at desc);

create index tasks_open_deadline_idx
  on public.tasks (user_id, deadline)
  where not is_completed and has_deadline;

create index tasks_open_without_deadline_idx
  on public.tasks (user_id, created_at desc)
  where not is_completed and not has_deadline;

create index buildings_user_idx
  on public.buildings (user_id);

-- auth.users is not directly writable from the public API. This security-definer
-- trigger creates the corresponding economy profile in the same transaction.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    id,
    gold,
    prosperity,
    daily_gold_earned,
    last_calc_date
  )
  values (
    new.id,
    100,
    0,
    0,
    timezone('utc', now())::date
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.buildings enable row level security;

create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

create policy tasks_select_own
  on public.tasks
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy tasks_insert_own
  on public.tasks
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and not is_completed
    and completed_at is null
  );

create policy tasks_delete_own
  on public.tasks
  for delete
  to authenticated
  using ((select auth.uid()) = user_id and not is_completed);

create policy buildings_select_own
  on public.buildings
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- The client is intentionally unable to mutate profiles/buildings or update
-- tasks. Completion and economy changes are performed by trusted server code.
revoke all on table public.profiles, public.tasks, public.buildings
  from anon, authenticated;

grant select on table public.profiles to authenticated;
grant select, delete on table public.tasks to authenticated;
grant insert (user_id, title, difficulty, has_deadline, deadline)
  on table public.tasks to authenticated;
grant select on table public.buildings to authenticated;

