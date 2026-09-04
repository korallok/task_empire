-- Trusted, atomic economy operation used only by complete_task_secure.
-- The Edge Function validates the user and obtains the approved rank from AI;
-- PostgreSQL remains the authority for rewards, cap enforcement and idempotency.

create or replace function public.complete_task_award(
  p_task_id uuid,
  p_user_id uuid,
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
    raise exception using
      errcode = 'P0001',
      message = 'INVALID_DIFFICULTY';
  end if;

  -- All economy mutations lock the profile first. That order is also used by
  -- building operations, preventing deadlocks between rewards and purchases.
  select profile.*
    into v_profile
    from public.profiles as profile
   where profile.id = p_user_id
   for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'PROFILE_NOT_FOUND';
  end if;

  select task.*
    into v_task
    from public.tasks as task
   where task.id = p_task_id
     and task.user_id = p_user_id
   for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'TASK_NOT_FOUND';
  end if;

  if v_task.is_completed then
    raise exception using
      errcode = 'P0001',
      message = 'TASK_ALREADY_COMPLETED';
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

  -- The rule is all-or-nothing: if this reward would cross the cap, this task
  -- awards zero rather than only the remaining part of the daily allowance.
  v_gold_awarded := case
    when v_profile.daily_gold_earned + v_reward <= v_daily_gold_cap
      then v_reward
    else 0
  end;

  update public.tasks as task
     set difficulty = p_approved_difficulty::character(1),
         is_completed = true,
         completed_at = v_completed_at
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

revoke all on function public.complete_task_award(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.complete_task_award(uuid, uuid, text)
  to service_role;

