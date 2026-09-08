-- Curated "negative / low energy" 1% Better task set.
-- Recommended whenever the user checks in with sad, bored, tired, depressed,
-- or gloomy. Repeatable: on conflict (title) do nothing.
-- NOTE: run AFTER 0040 so mood_tags use the new vocabulary.

insert into public.actions
  (title, description, category, sub_category, estimated_minutes, difficulty,
   required_energy, mood_tags, situation_tags, base_xp, active)
values
  ('Box Breathing', 'Breathe in for 4 counts, hold for 4, out for 4, hold for 4. Repeat for 2 minutes.', 'wellbeing', 'breathing', 2, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{stress,other}'::text[], 10, true),
  ('5-4-3-2-1 Grounding', 'Name 5 things you see, 4 you hear, 3 you feel, 2 you smell, 1 you taste.', 'wellbeing', 'grounding', 3, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{stress,other}'::text[], 10, true),
  ('Progressive Muscle Release', 'Tense and release one muscle group at a time for 2 minutes.', 'wellbeing', 'relaxation', 2, 2, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{stress,other}'::text[], 10, true),
  ('Cold Water on Wrists', 'Run cold water over your wrists or splash your face for 30 seconds. The dive reflex lowers your heart rate.', 'wellbeing', 'grounding', 1, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{stress,other}'::text[], 10, true),
  ('Stand Up and Stretch', 'Stand up and stretch your arms, back, and legs for 2 minutes.', 'physical', 'stretching', 2, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{stress,other}'::text[], 10, true),
  ('Write a New Angle', 'Write down one thought that''s bothering you, then one alternative way to see it.', 'reflection', 'journaling', 5, 2, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{motivation,other}'::text[], 10, true),
  ('Three Things That Went Okay', 'List 3 things that went okay today, however small.', 'reflection', 'gratitude', 3, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{motivation,other}'::text[], 10, true),
  ('Name the Emotion and Rate It', 'Name the emotion you''re feeling and rate its intensity from 1 to 10.', 'reflection', 'feelings', 2, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{motivation,other}'::text[], 10, true),
  ('Worry Postponement', 'Write the worry down and schedule a specific time to think about it later.', 'reflection', 'planning', 5, 2, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{motivation,other}'::text[], 10, true),
  ('Do One Two-Minute Task', 'Do one 2-minute task you''ve been avoiding: make the bed, wash one dish.', 'productivity', 'task breakdown', 2, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{motivation,stress}'::text[], 10, true),
  ('Step Outside for Fresh Air', 'Step outside for fresh air for 2 minutes.', 'physical', 'walking', 2, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{motivation,stress}'::text[], 10, true),
  ('Text Someone You Care About', 'Send one text to a person you care about.', 'social', 'message', 5, 2, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{motivation,stress}'::text[], 10, true),
  ('Put On One Song', 'Put on one song you like and just listen, without doing anything else.', 'wellbeing', 'self-soothing', 3, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{motivation,stress}'::text[], 10, true),
  ('A Kind Sentence to Yourself', 'Write one kind sentence to yourself, as if to a friend.', 'reflection', 'journaling', 2, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{loneliness,motivation}'::text[], 10, true),
  ('One Thing You''re Grateful For', 'Recall one thing you''re grateful for and write why.', 'reflection', 'gratitude', 2, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{loneliness,motivation}'::text[], 10, true),
  ('A Photo That Makes You Smile', 'Look at a photo that makes you smile for a minute.', 'reflection', 'gratitude', 1, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{loneliness,motivation}'::text[], 10, true),
  ('Take Ten Counted Breaths', 'Take 10 slow breaths, counting each one.', 'wellbeing', 'breathing', 1, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{stress,other}'::text[], 10, true),
  ('Splash Water and Breathe', 'Splash cold water on your face, then take 3 deep breaths.', 'wellbeing', 'breathing', 1, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{stress,other}'::text[], 10, true),
  ('Unclench and Breathe', 'Unclench your jaw, drop your shoulders, and take 3 slow breaths.', 'wellbeing', 'relaxation', 1, 1, 'low', '{sad,bored,tired,depressed,gloomy}'::text[], '{stress,other}'::text[], 10, true)
on conflict (title) do nothing;