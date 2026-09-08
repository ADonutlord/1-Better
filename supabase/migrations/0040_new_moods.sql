-- ============================================================================
-- 1% Better — Expanded mood vocabulary
-- Replaces the 5 moods (great, good, okay, low, stressed) with a 25-mood
-- set grouped by energy and valence, and remaps existing action mood tags
-- so the recommender keeps matching after the swap.
-- ============================================================================

create or replace function public.check_in_mood(
  p_mood       text,
  p_situations text[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_known text[] := array[
    'excited', 'happy', 'enthusiastic', 'elated', 'energetic',
    'calm', 'content', 'relaxed', 'peaceful', 'serene',
    'angry', 'anxious', 'stressed', 'irritable', 'frustrated',
    'sad', 'bored', 'tired', 'depressed', 'gloomy',
    'confused', 'nostalgic', 'curious', 'indifferent', 'surprised'
  ];
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not (p_mood = any(v_known)) then
    raise exception 'Invalid mood';
  end if;

  insert into public.mood_checkins (user_id, mood, situation)
  values (auth.uid(), p_mood,
          coalesce(p_situations, '{}')::text[])
  returning id into v_id;

  insert into public.daily_progress (user_id, date, mood_completed)
  values (auth.uid(), current_date, true)
  on conflict (user_id, date) do update
    set mood_completed = true;

  return jsonb_build_object('id', v_id, 'mood', p_mood, 'status', 'ok');
end;
$$;

-- Remap the existing action mood tags to the new vocabulary. One
-- representative tag per old tag; the recommender's group adjacency
-- (same energy + valence) covers the rest.
update public.actions
   set mood_tags = array(
     select (case elem
              when 'great'    then 'excited'
              when 'good'     then 'happy'
              when 'okay'     then 'confused'
              when 'low'      then 'sad'
              when 'stressed' then 'stressed'
              else elem
            end)
       from unnest(mood_tags) as elem
     )
 where array_length(mood_tags, 1) > 0;