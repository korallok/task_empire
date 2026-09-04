-- City construction, upgrades and passive income.
-- All mutating operations use auth.uid() and lock the profile before buildings,
-- matching the lock order used by complete_task_award.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

alter table public.profiles
  add column last_passive_income_at timestamp with time zone not null default now(),
  add column passive_income_remainder numeric not null default 0,
  add constraint profiles_passive_remainder_valid check (
    passive_income_remainder >= 0 and passive_income_remainder < 1
  );

alter table public.buildings
  add constraint buildings_level_supported check (level between 1 and 5);

create or replace function private.building_max_level(p_type text)
returns integer
language sql
immutable
strict
set search_path = ''
as $$
  select case p_type
    when 'market' then 5
    when 'town_hall' then 5
    else null
  end;
$$;

create or replace function private.building_build_price(p_type text)
returns integer
language sql
immutable
strict
set search_path = ''
as $$
  select case p_type
    when 'market' then 200
    when 'town_hall' then 500
    else null
  end;
$$;

create or replace function private.building_income_per_hour(
  p_type text,
  p_level integer
)
returns integer
language sql
immutable
strict
set search_path = ''
as $$
  select case
    when p_level < 1 then null
    when p_type = 'market' then 5 * p_level
    when p_type = 'town_hall' then 12 * p_level
    else null
  end;
$$;

create or replace function private.building_prosperity(
  p_type text,
  p_level integer
)
returns integer
language sql
immutable
strict
set search_path = ''
as $$
  select case
    when p_level < 1 then null
    when p_type = 'market' then 15 * p_level
    when p_type = 'town_hall' then 40 * p_level
    else null
  end;
$$;

create or replace function private.building_upgrade_cost(
  p_type text,
  p_current_level integer
)
returns integer
language sql
immutable
strict
set search_path = ''
as $$
  select case
    when p_current_level < 1 then null
    when p_current_level >= private.building_max_level(p_type) then null
    else ceil(
      private.building_build_price(p_type)
      * power(1.75::numeric, p_current_level)
    )::integer
  end;
$$;

create or replace function private.total_prosperity(p_user_id uuid)
returns integer
language sql
stable
strict
set search_path = ''
as $$
  select coalesce(
    sum(private.building_prosperity(building.type, building.level)),
    0
  )::integer
  from public.buildings as building
  where building.user_id = p_user_id;
$$;

create or replace function private.settle_passive_income_locked(p_user_id uuid)
returns table (
  passive_gold_earned integer,
  total_gold integer,
  income_per_hour integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last_calc timestamp with time zone;
  v_remainder numeric;
  v_income_per_hour integer;
  v_elapsed_seconds numeric;
  v_exact_income numeric;
  v_gold_earned integer;
  v_total_gold integer;
begin
  -- The caller must already hold a FOR UPDATE lock on this profile.
  select
    profile.last_passive_income_at,
    profile.passive_income_remainder
  into v_last_calc, v_remainder
  from public.profiles as profile
  where profile.id = p_user_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'PROFILE_NOT_FOUND';
  end if;

  select coalesce(
    sum(private.building_income_per_hour(building.type, building.level)),
    0
  )::integer
  into v_income_per_hour
  from public.buildings as building
  where building.user_id = p_user_id;

  v_elapsed_seconds := greatest(
    extract(epoch from (now() - v_last_calc)),
    0
  );
  v_exact_income := v_remainder
    + (v_income_per_hour::numeric * v_elapsed_seconds / 3600);
  v_gold_earned := floor(v_exact_income)::integer;

  update public.profiles as profile
  set gold = profile.gold + v_gold_earned,
      last_passive_income_at = now(),
      passive_income_remainder = v_exact_income - v_gold_earned
  where profile.id = p_user_id
  returning profile.gold into v_total_gold;

  return query
  select v_gold_earned, v_total_gold, v_income_per_hour;
end;
$$;

create or replace function public.get_city_state()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_passive_gold_earned integer;
  v_total_gold integer;
  v_income_per_hour integer;
  v_prosperity integer;
  v_buildings jsonb;
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;

  select profile.*
  into v_profile
  from public.profiles as profile
  where profile.id = v_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'PROFILE_NOT_FOUND';
  end if;

  select settlement.passive_gold_earned,
         settlement.total_gold,
         settlement.income_per_hour
  into v_passive_gold_earned, v_total_gold, v_income_per_hour
  from private.settle_passive_income_locked(v_user_id) as settlement;

  v_prosperity := private.total_prosperity(v_user_id);
  if v_profile.prosperity <> v_prosperity then
    update public.profiles as profile
    set prosperity = v_prosperity
    where profile.id = v_user_id;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', building.id,
        'type', building.type,
        'level', building.level,
        'iso_x', building.iso_x,
        'iso_y', building.iso_y,
        'income_per_hour', private.building_income_per_hour(
          building.type,
          building.level
        ),
        'prosperity', private.building_prosperity(
          building.type,
          building.level
        ),
        'upgrade_cost', private.building_upgrade_cost(
          building.type,
          building.level
        ),
        'max_level', private.building_max_level(building.type)
      )
      order by building.iso_x + building.iso_y, building.iso_x
    ),
    '[]'::jsonb
  )
  into v_buildings
  from public.buildings as building
  where building.user_id = v_user_id;

  return jsonb_build_object(
    'profile', jsonb_build_object(
      'gold', v_total_gold,
      'prosperity', v_prosperity,
      'daily_gold_earned', v_profile.daily_gold_earned,
      'passive_gold_earned', v_passive_gold_earned,
      'income_per_hour', v_income_per_hour
    ),
    'buildings', v_buildings,
    'catalog', jsonb_build_array(
      jsonb_build_object(
        'type', 'market',
        'build_price', private.building_build_price('market'),
        'income_per_hour', private.building_income_per_hour('market', 1),
        'prosperity', private.building_prosperity('market', 1),
        'max_level', private.building_max_level('market')
      ),
      jsonb_build_object(
        'type', 'town_hall',
        'build_price', private.building_build_price('town_hall'),
        'income_per_hour', private.building_income_per_hour('town_hall', 1),
        'prosperity', private.building_prosperity('town_hall', 1),
        'max_level', private.building_max_level('town_hall')
      )
    )
  );
end;
$$;

create or replace function public.build_city_building(
  p_type text,
  p_iso_x integer,
  p_iso_y integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_passive_gold_earned integer;
  v_total_gold integer;
  v_income_per_hour integer;
  v_price integer;
  v_building_id uuid;
  v_prosperity integer;
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;

  if p_type not in ('market', 'town_hall') then
    raise exception using errcode = 'P0001', message = 'INVALID_BUILDING_TYPE';
  end if;
  if p_iso_x not between 0 and 7 or p_iso_y not between 0 and 7 then
    raise exception using errcode = 'P0001', message = 'INVALID_TILE';
  end if;

  select profile.*
  into v_profile
  from public.profiles as profile
  where profile.id = v_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'PROFILE_NOT_FOUND';
  end if;

  select settlement.passive_gold_earned,
         settlement.total_gold,
         settlement.income_per_hour
  into v_passive_gold_earned, v_total_gold, v_income_per_hour
  from private.settle_passive_income_locked(v_user_id) as settlement;

  if exists (
    select 1
    from public.buildings as building
    where building.user_id = v_user_id
      and building.iso_x = p_iso_x
      and building.iso_y = p_iso_y
  ) then
    raise exception using errcode = 'P0001', message = 'TILE_OCCUPIED';
  end if;

  v_price := private.building_build_price(p_type);
  if v_total_gold < v_price then
    raise exception using errcode = 'P0001', message = 'INSUFFICIENT_GOLD';
  end if;

  insert into public.buildings (user_id, type, level, iso_x, iso_y)
  values (v_user_id, p_type, 1, p_iso_x, p_iso_y)
  returning id into v_building_id;

  v_prosperity := private.total_prosperity(v_user_id);
  update public.profiles as profile
  set gold = v_total_gold - v_price,
      prosperity = v_prosperity
  where profile.id = v_user_id;

  return jsonb_build_object(
    'building_id', v_building_id,
    'gold', v_total_gold - v_price,
    'prosperity', v_prosperity,
    'passive_gold_earned', v_passive_gold_earned
  );
end;
$$;

create or replace function public.upgrade_city_building(p_building_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_building public.buildings%rowtype;
  v_passive_gold_earned integer;
  v_total_gold integer;
  v_income_per_hour integer;
  v_upgrade_cost integer;
  v_prosperity integer;
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;

  select profile.*
  into v_profile
  from public.profiles as profile
  where profile.id = v_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'PROFILE_NOT_FOUND';
  end if;

  select settlement.passive_gold_earned,
         settlement.total_gold,
         settlement.income_per_hour
  into v_passive_gold_earned, v_total_gold, v_income_per_hour
  from private.settle_passive_income_locked(v_user_id) as settlement;

  select building.*
  into v_building
  from public.buildings as building
  where building.id = p_building_id
    and building.user_id = v_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'BUILDING_NOT_FOUND';
  end if;

  v_upgrade_cost := private.building_upgrade_cost(
    v_building.type,
    v_building.level
  );
  if v_upgrade_cost is null then
    raise exception using errcode = 'P0001', message = 'MAX_LEVEL_REACHED';
  end if;
  if v_total_gold < v_upgrade_cost then
    raise exception using errcode = 'P0001', message = 'INSUFFICIENT_GOLD';
  end if;

  update public.buildings as building
  set level = v_building.level + 1
  where building.id = p_building_id;

  v_prosperity := private.total_prosperity(v_user_id);
  update public.profiles as profile
  set gold = v_total_gold - v_upgrade_cost,
      prosperity = v_prosperity
  where profile.id = v_user_id;

  return jsonb_build_object(
    'building_id', p_building_id,
    'level', v_building.level + 1,
    'gold', v_total_gold - v_upgrade_cost,
    'prosperity', v_prosperity,
    'passive_gold_earned', v_passive_gold_earned
  );
end;
$$;

revoke all on all functions in schema private from public, anon, authenticated;

revoke all on function public.get_city_state() from public, anon, authenticated;
revoke all on function public.build_city_building(text, integer, integer)
  from public, anon, authenticated;
revoke all on function public.upgrade_city_building(uuid)
  from public, anon, authenticated;

grant execute on function public.get_city_state() to authenticated;
grant execute on function public.build_city_building(text, integer, integer)
  to authenticated;
grant execute on function public.upgrade_city_building(uuid) to authenticated;
