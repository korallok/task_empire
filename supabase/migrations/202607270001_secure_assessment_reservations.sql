-- Reserve AI assessments before making a paid model request.
-- This prevents duplicate concurrent assessments and caps per-user API spend.

alter table public.tasks
  add column assessment_status text not null default 'idle',
  add column assessment_started_at timestamp with time zone,
  add column assessment_token uuid;

update public.tasks
set assessment_status = 'completed'
where is_completed;

alter table public.tasks
  add constraint tasks_assessment_status_valid check (
    assessment_status in ('idle', 'processing', 'completed')
  ),
  add constraint tasks_assessment_state_consistent check (
    (
      assessment_status = 'processing'
      and assessment_started_at is not null
      and assessment_token is not null
      and not is_completed
    )
    or (
      assessment_status <> 'processing'
      and assessment_started_at is null
      and assessment_token is null
    )
  ),
  add constraint tasks_assessment_completion_consistent check (
    is_completed = (assessment_status = 'completed')
  );

drop policy tasks_delete_own on public.tasks;
create policy tasks_delete_own
  on public.tasks
  for delete
  to authenticated
  using (
    (select auth.uid()) = user_id
    and not is_completed
    and (
      assessment_status = 'idle'
      or assessment_started_at <= now() - interval '2 minutes'
    )
  );

create table private.ai_assessment_usage (
  user_id uuid not null references public.profiles (id) on delete cascade,
  usage_date date not null,
  request_count integer not null default 0,

  primary key (user_id, usage_date),
  constraint ai_assessment_usage_count_valid check (request_count >= 0)
);

revoke all on table private.ai_assessment_usage
  from public, anon, authenticated;

create or replace function public.reserve_task_assessment(
  p_task_id uuid,
  p_user_id uuid,
  p_request_id uuid
)
returns table (task_title text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks%rowtype;
  v_request_count integer;
  v_today date := timezone('utc', now())::date;
  v_daily_request_cap constant integer := 30;
  v_reservation_timeout constant interval := interval '2 minutes';
begin
  if p_request_id is null then
    raise exception using errcode = 'P0001', message = 'INVALID_REQUEST_ID';
  end if;

  -- Keep the same profile -> task lock order as every other economy mutation.
  perform 1
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
  if v_task.is_completed then
    raise exception using errcode = 'P0001', message = 'TASK_ALREADY_COMPLETED';
  end if;
  if v_task.assessment_status = 'processing'
     and v_task.assessment_started_at > now() - v_reservation_timeout then
    raise exception using
      errcode = 'P0001',
      message = 'TASK_ASSESSMENT_IN_PROGRESS';
  end if;

  insert into private.ai_assessment_usage (
    user_id,
    usage_date,
    request_count
  )
  values (p_user_id, v_today, 1)
  on conflict (user_id, usage_date) do update
    set request_count = private.ai_assessment_usage.request_count + 1
  returning request_count into v_request_count;

  if v_request_count > v_daily_request_cap then
    raise exception using errcode = 'P0001', message = 'AI_DAILY_LIMIT';
  end if;

  update public.tasks as task
  set assessment_status = 'processing',
      assessment_started_at = now(),
      assessment_token = p_request_id
  where task.id = p_task_id;

  return query select v_task.title;
end;
$$;

create or replace function public.release_task_assessment(
  p_task_id uuid,
  p_user_id uuid,
  p_request_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.tasks as task
  set assessment_status = 'idle',
      assessment_started_at = null,
      assessment_token = null
  where task.id = p_task_id
    and task.user_id = p_user_id
    and task.assessment_status = 'processing'
    and task.assessment_token = p_request_id
    and not task.is_completed;
$$;

drop function public.complete_task_award(uuid, uuid, text);

create function public.complete_task_award(
  p_task_id uuid,
  p_user_id uuid,
  p_request_id uuid,
  p_approved_difficulty text
)
returns table (
  task_id uuid,
  approved_difficulty text,
  gold_awarded integer,
  total_gold integer,
  daily_gold_earned integer,
  completed_at timestamp with time zone
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_task public.tasks%rowtype;
  v_reward integer;
  v_gold_awarded integer;
  v_total_gold integer;
  v_daily_gold_earned integer;
  v_today date := timezone('utc', now())::date;
  v_completed_at timestamp with time zone := now();
  v_daily_gold_cap constant integer := 600;
begin
  if p_approved_difficulty is null
     or p_approved_difficulty not in ('E', 'D', 'C', 'B', 'A', 'S') then
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
  if v_task.is_completed then
    raise exception using errcode = 'P0001', message = 'TASK_ALREADY_COMPLETED';
  end if;
  if v_task.assessment_status <> 'processing'
     or v_task.assessment_token is distinct from p_request_id then
    raise exception using
      errcode = 'P0001',
      message = 'ASSESSMENT_RESERVATION_LOST';
  end if;

  if v_profile.last_calc_date <> v_today then
    v_profile.daily_gold_earned := 0;
  end if;

  v_reward := case p_approved_difficulty
    when 'E' then 5
    when 'D' then 15
    when 'C' then 40
    when 'B' then 100
    when 'A' then 250
    when 'S' then 600
  end;

  v_gold_awarded := case
    when v_profile.daily_gold_earned + v_reward <= v_daily_gold_cap
      then v_reward
    else 0
  end;

  update public.tasks as task
  set difficulty = p_approved_difficulty::character(1),
      is_completed = true,
      completed_at = v_completed_at,
      assessment_status = 'completed',
      assessment_started_at = null,
      assessment_token = null
  where task.id = p_task_id;

  update public.profiles as profile
  set gold = profile.gold + v_gold_awarded,
      daily_gold_earned = v_profile.daily_gold_earned + v_gold_awarded,
      last_calc_date = v_today
  where profile.id = p_user_id
  returning profile.gold, profile.daily_gold_earned
  into v_total_gold, v_daily_gold_earned;

  return query
  select
    p_task_id,
    p_approved_difficulty,
    v_gold_awarded,
    v_total_gold,
    v_daily_gold_earned,
    v_completed_at;
end;
$$;

-- Reset the visible daily counter at the UTC date boundary, even if the user
-- opens the city before completing the first task of the day.
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
  v_today date := timezone('utc', now())::date;
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

  if v_profile.last_calc_date <> v_today then
    update public.profiles as profile
    set daily_gold_earned = 0,
        last_calc_date = v_today
    where profile.id = v_user_id;
    v_profile.daily_gold_earned := 0;
    v_profile.last_calc_date := v_today;
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

revoke all on function public.reserve_task_assessment(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.release_task_assessment(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.complete_task_award(uuid, uuid, uuid, text)
  from public, anon, authenticated;

grant execute on function public.reserve_task_assessment(uuid, uuid, uuid)
  to service_role;
grant execute on function public.release_task_assessment(uuid, uuid, uuid)
  to service_role;
grant execute on function public.complete_task_award(uuid, uuid, uuid, text)
  to service_role;
