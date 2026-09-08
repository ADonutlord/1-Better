-- ============================================================================
-- 1% Better — Relax mood_checkins mood constraint to the 25-mood vocabulary.
-- Migration 0040 added the 25-mood validation to the check_in_mood function but
-- the mood_checkins.mood column still carried the old 5-mood CHECK constraint
-- (mood_checkins_mood_check) from 00001, rejecting every new mood at the table
-- level. This replaces it with the expanded set.
-- ============================================================================

alter table public.mood_checkins
  drop constraint if exists mood_checkins_mood_check;

-- Normalize any rows outside the 25-mood set (should be none, but guards the
-- re-add below) before enforcing the check.
begin;
update public.mood_checkins
   set mood = (case mood
                when 'great'    then 'excited'
                when 'good'     then 'happy'
                when 'okay'     then 'confused'
                when 'low'      then 'sad'
                when 'stressed' then 'stressed'
                else null
              end)
 where mood not in (
    'excited', 'happy', 'enthusiastic', 'elated', 'energetic',
    'calm', 'content', 'relaxed', 'peaceful', 'serene',
    'angry', 'anxious', 'stressed', 'irritable', 'frustrated',
    'sad', 'bored', 'tired', 'depressed', 'gloomy',
    'confused', 'nostalgic', 'curious', 'indifferent', 'surprised'
  );
delete from public.mood_checkins where mood is null;
commit;

alter table public.mood_checkins
  add constraint mood_checkins_mood_check
  check (mood in (
    'excited', 'happy', 'enthusiastic', 'elated', 'energetic',
    'calm', 'content', 'relaxed', 'peaceful', 'serene',
    'angry', 'anxious', 'stressed', 'irritable', 'frustrated',
    'sad', 'bored', 'tired', 'depressed', 'gloomy',
    'confused', 'nostalgic', 'curious', 'indifferent', 'surprised'
  ));
