-- Transactional smoke test for 202609040001_task_empire_2_foundation.sql.
-- Run after `supabase db reset` with:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f \
--     supabase/tests/task_empire_2_foundation_smoke.sql

\set ON_ERROR_STOP on

begin;

insert into auth.users (id)
values
  ('10000000-0000-4000-8000-000000000001'),
  ('20000000-0000-4000-8000-000000000002');

-- Seed real rows for the second user so every RLS isolation assertion proves
-- filtering rather than succeeding because the underlying table is empty.
do $$
declare
  v_other_task_id uuid;
  v_other_city_id uuid;
  v_house_definition_id uuid;
begin
  insert into public.tasks (
    user_id,
    title,
    description,
    category,
    difficulty,
    scheduled_date,
    verification_mode
  )
  values (
    '20000000-0000-4000-8000-000000000002',
    'Other user task',
    '',
    'work',
    'easy',
    timezone('utc', now())::date,
    'none'
  )
  returning id into v_other_task_id;

  perform private.complete_task_for_user_v2(
    v_other_task_id,
    '20000000-0000-4000-8000-000000000002',
    false
  );

  select city.id
  into v_other_city_id
  from public.cities as city
  where city.user_id = '20000000-0000-4000-8000-000000000002';

  select definition.id
  into v_house_definition_id
  from public.building_definitions as definition
  where definition.code = 'house'
    and definition.level = 1;

  insert into public.user_buildings (
    user_id,
    city_id,
    building_definition_id,
    position_x,
    position_y
  )
  values (
    '20000000-0000-4000-8000-000000000002',
    v_other_city_id,
    v_house_definition_id,
    0,
    0
  );

  update public.profiles
  set prosperity = 10
  where id = '20000000-0000-4000-8000-000000000002';

  -- These fixed IDs are used later to exercise the service-only AI bridge.
  insert into public.tasks (
    id,
    user_id,
    title,
    category,
    difficulty,
    scheduled_date,
    verification_mode
  )
  values
    (
      '10000000-0000-4000-8000-0000000000a1',
      '10000000-0000-4000-8000-000000000001',
      'AI compatibility task',
      'study',
      'hard',
      timezone('utc', now())::date,
      'ai'
    ),
    (
      '10000000-0000-4000-8000-0000000000a2',
      '10000000-0000-4000-8000-000000000001',
      'Expired AI reservation task',
      'study',
      'easy',
      timezone('utc', now())::date,
      'ai'
    );
end;
$$;

-- Exercise the idempotent legacy-city bridge after the migration itself has
-- run. The real rollout calls the same helper while the old rows already exist.
do $$
declare
  v_inserted integer;
  v_migrated record;
begin
  insert into public.buildings (
    id,
    user_id,
    type,
    level,
    iso_x,
    iso_y
  )
  values (
    '20000000-0000-4000-8000-0000000000b1',
    '20000000-0000-4000-8000-000000000002',
    'market',
    3,
    7,
    7
  );

  v_inserted := private.migrate_legacy_city_buildings_v2();
  if v_inserted <> 1 then
    raise exception 'legacy city bridge inserted % rows instead of 1', v_inserted;
  end if;

  select
    building.user_id,
    building.position_x,
    building.position_y,
    building.rotation,
    definition.code,
    definition.level,
    definition.footprint_width,
    definition.footprint_height,
    definition.prosperity,
    definition.sprite
  into v_migrated
  from public.user_buildings as building
  join public.building_definitions as definition
    on definition.id = building.building_definition_id
  where building.id = '20000000-0000-4000-8000-0000000000b1';

  if not found then
    raise exception 'legacy city building was not copied';
  end if;

  if v_migrated.user_id <> '20000000-0000-4000-8000-000000000002'::uuid
     or v_migrated.position_x <> 7
     or v_migrated.position_y <> 7
     or v_migrated.rotation <> 0
     or v_migrated.code <> 'legacy_market'
     or v_migrated.level <> 3
     or v_migrated.footprint_width <> 1
     or v_migrated.footprint_height <> 1
     or v_migrated.prosperity <> 45
     or v_migrated.sprite <> 'assets/city/buildings/market_level_3.webp' then
    raise exception 'legacy city building was not preserved: %', v_migrated;
  end if;

  if private.migrate_legacy_city_buildings_v2() <> 0 then
    raise exception 'legacy city bridge is not idempotent';
  end if;
end;
$$;

do $$
begin
  if has_function_privilege(
    'anon',
    'public.complete_task_v2(uuid)',
    'execute'
  ) then
    raise exception 'anon unexpectedly has complete_task_v2 execute';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.complete_task_v2(uuid)',
    'execute'
  ) then
    raise exception 'authenticated is missing complete_task_v2 execute';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.complete_task_award(uuid,uuid,uuid,text)',
    'execute'
  ) then
    raise exception 'authenticated unexpectedly has AI award execute';
  end if;

  if not has_function_privilege(
    'service_role',
    'public.complete_task_award(uuid,uuid,uuid,text)',
    'execute'
  ) then
    raise exception 'service_role is missing AI award execute';
  end if;

  if has_function_privilege(
    'authenticated',
    'private.migrate_legacy_city_buildings_v2()',
    'execute'
  ) then
    raise exception 'authenticated unexpectedly has legacy migration execute';
  end if;

  if has_column_privilege(
    'authenticated',
    'public.tasks',
    'status',
    'update'
  ) then
    raise exception 'authenticated unexpectedly has task status update';
  end if;

  if has_column_privilege(
    'authenticated',
    'public.tasks',
    'has_deadline',
    'insert'
  ) then
    raise exception 'authenticated unexpectedly has compatibility-column insert';
  end if;

  if not has_column_privilege(
    'authenticated',
    'public.tasks',
    'title',
    'update'
  ) then
    raise exception 'authenticated is missing task title update';
  end if;

  if not has_column_privilege(
    'authenticated',
    'public.tasks',
    'scheduled_date',
    'insert'
  ) then
    raise exception 'authenticated is missing scheduled-date insert';
  end if;

  if has_table_privilege(
    'authenticated',
    'public.reward_ledger',
    'insert'
  ) then
    raise exception 'authenticated unexpectedly has reward ledger insert';
  end if;

  if has_table_privilege(
    'authenticated',
    'public.user_buildings',
    'update'
  ) then
    raise exception 'authenticated unexpectedly has direct building update';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
set local role authenticated;

do $$
declare
  v_task_id uuid;
  v_pending_task_id uuid;
  v_building_id uuid;
  v_result jsonb;
  v_retry jsonb;
  v_city jsonb;
  v_task public.tasks%rowtype;
  v_gold_before_move integer;
  v_expected_error boolean;
begin
  if (
    select count(*)
    from public.tasks
    where user_id = '20000000-0000-4000-8000-000000000002'
  ) <> 0 then
    raise exception 'RLS exposed another user task';
  end if;

  if (
    select count(*)
    from public.profiles
    where id = '20000000-0000-4000-8000-000000000002'
  ) <> 0 then
    raise exception 'RLS exposed another user profile';
  end if;

  if (
    select count(*)
    from public.task_completions
    where user_id = '20000000-0000-4000-8000-000000000002'
  ) <> 0 then
    raise exception 'RLS exposed another user completion';
  end if;

  if (
    select count(*)
    from public.reward_ledger
    where user_id = '20000000-0000-4000-8000-000000000002'
  ) <> 0 then
    raise exception 'RLS exposed another user ledger entry';
  end if;

  if (
    select count(*)
    from public.user_buildings
    where user_id = '20000000-0000-4000-8000-000000000002'
  ) <> 0 then
    raise exception 'RLS exposed another user building';
  end if;

  insert into public.tasks (
    user_id,
    title,
    description,
    category,
    difficulty,
    scheduled_date,
    deadline,
    verification_mode
  )
  values (
    auth.uid(),
    'Finish a focused work block',
    'Foundation smoke test',
    'work',
    'normal',
    timezone('utc', now())::date,
    now() + interval '1 day',
    'none'
  )
  returning id into v_task_id;

  select task.*
  into v_task
  from public.tasks as task
  where task.id = v_task_id;

  if v_task.status <> 'pending'
     or v_task.is_completed
     or v_task.completed_at is not null
     or not v_task.has_deadline
     or v_task.assessment_status <> 'idle' then
    raise exception 'task compatibility fields were not initialized safely';
  end if;

  update public.tasks
  set title = 'Finish the focused work block',
      description = 'Updated metadata'
  where id = v_task_id;

  select public.complete_task_v2(v_task_id) into v_result;

  if (select count(*) from jsonb_object_keys(v_result)) <> 5
     or not (v_result ?& array[
       'task_id', 'status', 'completed_at', 'reward', 'profile'
     ]::text[])
     or (select count(*) from jsonb_object_keys(v_result -> 'reward')) <> 2
     or not ((v_result -> 'reward') ?& array['xp_delta', 'gold_delta']::text[])
     or (select count(*) from jsonb_object_keys(v_result -> 'profile')) <> 3
     or not ((v_result -> 'profile') ?& array['xp', 'gold', 'level']::text[])
     or jsonb_typeof(v_result -> 'completed_at') <> 'string'
     or v_result ->> 'task_id' <> v_task_id::text
     or v_result ->> 'status' <> 'completed'
     or (v_result #>> '{reward,xp_delta}')::integer <> 25
     or (v_result #>> '{reward,gold_delta}')::integer <> 15
     or (v_result #>> '{profile,xp}')::integer <> 25
     or (v_result #>> '{profile,gold}')::integer <> 115
     or (v_result #>> '{profile,level}')::integer <> 1 then
    raise exception 'unexpected normal completion response: %', v_result;
  end if;

  select public.complete_task_v2(v_task_id) into v_retry;
  if (v_retry #>> '{reward,xp_delta}')::integer <> 0
     or (v_retry #>> '{reward,gold_delta}')::integer <> 0
     or (v_retry #>> '{profile,xp}')::integer <> 25
     or (v_retry #>> '{profile,gold}')::integer <> 115
     or v_retry ->> 'completed_at' <> v_result ->> 'completed_at' then
    raise exception 'completion retry was not idempotent: %', v_retry;
  end if;

  if (
    select count(*)
    from public.reward_ledger
    where source_type = 'task_completion'
      and source_id = v_task_id
  ) <> 1 then
    raise exception 'task completion ledger entry is missing or duplicated';
  end if;

  -- RLS and column grants must keep completed tasks immutable to the client.
  update public.tasks
  set title = 'A completed task must not change'
  where id = v_task_id;
  if found then
    raise exception 'authenticated updated a completed task';
  end if;

  delete from public.tasks where id = v_task_id;
  if found then
    raise exception 'authenticated deleted a completed task';
  end if;

  v_city := public.get_city_state_v2();
  if (select count(*) from jsonb_object_keys(v_city)) <> 4
     or not (v_city ?& array['profile', 'city', 'buildings', 'catalog']::text[])
     or (select count(*) from jsonb_object_keys(v_city -> 'profile')) <> 4
     or not ((v_city -> 'profile') ?& array[
       'gold', 'xp', 'level', 'prosperity'
     ]::text[])
     or (select count(*) from jsonb_object_keys(v_city -> 'city')) <> 3
     or not ((v_city -> 'city') ?& array[
       'map_level', 'map_width', 'map_height'
     ]::text[])
     or jsonb_typeof(v_city -> 'buildings') <> 'array'
     or jsonb_typeof(v_city -> 'catalog') <> 'array'
     or jsonb_array_length(v_city -> 'buildings') <> 0
     or jsonb_array_length(v_city -> 'catalog') <> 7
     or (v_city #>> '{city,map_level}')::integer <> 1
     or (v_city #>> '{city,map_width}')::integer <> 16
     or (v_city #>> '{city,map_height}')::integer <> 16 then
    raise exception 'unexpected initial city contract: %', v_city;
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_city -> 'catalog') as catalog(item)
    where (select count(*) from jsonb_object_keys(catalog.item)) <> 13
       or not (catalog.item ?& array[
         'id',
         'code',
         'name',
         'level',
         'position_x',
         'position_y',
         'rotation',
         'price',
         'required_player_level',
         'sprite',
         'footprint_width',
         'footprint_height',
         'prosperity'
       ]::text[])
       or jsonb_typeof(catalog.item -> 'position_x') <> 'null'
       or jsonb_typeof(catalog.item -> 'position_y') <> 'null'
       or jsonb_typeof(catalog.item -> 'rotation') <> 'null'
       or catalog.item ->> 'sprite' not like 'assets/city/buildings/%'
  ) then
    raise exception 'city catalog rows do not match the Flutter contract';
  end if;

  v_expected_error := false;
  begin
    perform public.build_city_building_v2('legacy_market', 8, 8, 0);
  exception when sqlstate 'P0001' then
    v_expected_error := sqlerrm = 'BUILDING_NOT_FOUND';
  end;
  if not v_expected_error then
    raise exception 'legacy-only definition was available for construction';
  end if;

  v_city := public.build_city_building_v2('house', 0, 0, 0);
  if (v_city #>> '{profile,gold}')::integer <> 100
     or jsonb_array_length(v_city -> 'buildings') <> 1
     or v_city -> 'buildings' -> 0 ->> 'code' <> 'house'
     or (v_city -> 'buildings' -> 0 ->> 'footprint_width')::integer <> 2
     or (v_city -> 'buildings' -> 0 ->> 'footprint_height')::integer <> 2 then
    raise exception 'unexpected city build response: %', v_city;
  end if;

  v_building_id := (v_city -> 'buildings' -> 0 ->> 'id')::uuid;
  v_gold_before_move := (v_city #>> '{profile,gold}')::integer;

  v_expected_error := false;
  begin
    perform public.build_city_building_v2('garden', 1, 1, 0);
  exception when sqlstate 'P0001' then
    v_expected_error := sqlerrm = 'BUILDING_OVERLAP';
  end;
  if not v_expected_error then
    raise exception 'overlapping building was accepted';
  end if;

  v_expected_error := false;
  begin
    perform public.build_city_building_v2('house', 15, 15, 0);
  exception when sqlstate 'P0001' then
    v_expected_error := sqlerrm = 'OUT_OF_BOUNDS';
  end;
  if not v_expected_error then
    raise exception 'out-of-bounds building was accepted';
  end if;

  v_city := public.move_city_building_v2(v_building_id, 3, 0, 90);
  if (v_city #>> '{profile,gold}')::integer <> v_gold_before_move
     or (v_city -> 'buildings' -> 0 ->> 'position_x')::integer <> 3
     or (v_city -> 'buildings' -> 0 ->> 'rotation')::integer <> 90 then
    raise exception 'move changed balance or returned wrong placement: %', v_city;
  end if;

  if (
    select count(*)
    from public.reward_ledger
    where source_type = 'building_purchase'
      and source_id = v_building_id
      and gold_delta = -15
  ) <> 1 then
    raise exception 'building purchase debit is missing or duplicated';
  end if;

  v_expected_error := false;
  begin
    perform public.complete_task_v2(
      '10000000-0000-4000-8000-0000000000a1'
    );
  exception when sqlstate 'P0001' then
    v_expected_error := sqlerrm = 'TASK_REQUIRES_AI_VERIFICATION';
  end;
  if not v_expected_error then
    raise exception 'AI verification was bypassed';
  end if;

  insert into public.tasks (
    user_id,
    title,
    category,
    difficulty,
    scheduled_date
  )
  values (
    auth.uid(),
    'Pending deletion test',
    'personal',
    'easy',
    timezone('utc', now())::date
  )
  returning id into v_pending_task_id;

  delete from public.tasks where id = v_pending_task_id;
  if not found then
    raise exception 'owned pending task was not deletable';
  end if;

  v_result := public.get_progression_state_v2();
  if (select count(*) from jsonb_object_keys(v_result)) <> 7
     or not (v_result ?& array[
       'xp',
       'gold',
       'level',
       'xp_into_level',
       'xp_for_next_level',
       'completed_tasks',
       'streak'
     ]::text[])
     or (v_result ->> 'xp')::integer <> 25
     or (v_result ->> 'gold')::integer <> 100
     or (v_result ->> 'level')::integer <> 1
     or (v_result ->> 'completed_tasks')::integer <> 1
     or (v_result ->> 'streak')::integer <> 1
     or (v_result ->> 'xp_into_level')::integer <> 25
     or (v_result ->> 'xp_for_next_level')::integer <> 100 then
    raise exception 'unexpected progression response: %', v_result;
  end if;
end;
$$;

reset role;

-- The service-only bridge accepts a legacy rank, stores its paired canonical v2
-- difficulty, and returns the original rank so an old deployed Edge Function
-- can remain online while the migration and new function roll out separately.
do $$
declare
  v_award record;
  v_task_difficulty text;
  v_expected_error boolean := false;
begin
  perform public.reserve_task_assessment(
    '10000000-0000-4000-8000-0000000000a1',
    '10000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000003'
  );

  select *
  into v_award
  from public.complete_task_award(
    '10000000-0000-4000-8000-0000000000a1',
    '10000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000003',
    'B'
  );

  if v_award.approved_difficulty <> 'B'
     or v_award.xp_awarded <> 25
     or v_award.gold_awarded <> 15
     or v_award.total_xp <> 50
     or v_award.total_gold <> 115
     or v_award.daily_gold_earned <> 30
     or v_award.player_level <> 1 then
    raise exception 'legacy AI bridge returned an incompatible row: %', v_award;
  end if;

  select task.difficulty
  into v_task_difficulty
  from public.tasks as task
  where task.id = '10000000-0000-4000-8000-0000000000a1';

  if v_task_difficulty <> 'normal' then
    raise exception 'legacy B rank did not migrate to normal difficulty';
  end if;

  perform public.reserve_task_assessment(
    '10000000-0000-4000-8000-0000000000a2',
    '10000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000004'
  );

  update public.tasks
  set assessment_started_at = now() - interval '3 minutes'
  where id = '10000000-0000-4000-8000-0000000000a2';

  begin
    perform public.complete_task_award(
      '10000000-0000-4000-8000-0000000000a2',
      '10000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000004',
      'E'
    );
  exception when sqlstate 'P0001' then
    v_expected_error := sqlerrm = 'ASSESSMENT_RESERVATION_LOST';
  end;

  if not v_expected_error then
    raise exception 'expired AI assessment reservation was accepted';
  end if;

  perform public.release_task_assessment(
    '10000000-0000-4000-8000-0000000000a2',
    '10000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000004'
  );
end;
$$;

set local role authenticated;

do $$
declare
  v_result jsonb;
begin
  v_result := public.get_progression_state_v2();
  if (v_result ->> 'xp')::integer <> 50
     or (v_result ->> 'gold')::integer <> 115
     or (v_result ->> 'completed_tasks')::integer <> 2
     or (v_result ->> 'streak')::integer <> 1
     or (v_result ->> 'xp_into_level')::integer <> 50 then
    raise exception 'AI completion was not reflected in progression: %', v_result;
  end if;

  if (select count(*) from public.task_completions) <> 2 then
    raise exception 'RLS returned the wrong completion history';
  end if;

  if (select count(*) from public.reward_ledger) <> 3 then
    raise exception 'RLS returned the wrong reward ledger';
  end if;

  if (select count(*) from public.user_buildings) <> 1 then
    raise exception 'RLS returned the wrong city buildings';
  end if;
end;
$$;

reset role;
rollback;
