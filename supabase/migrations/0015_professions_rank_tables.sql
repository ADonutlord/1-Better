-- ============================================================================
-- 1% Better — Professions rank via reference tables
-- Replaces the 2D-array approach from 0013/0014 with reference tables, which
-- Postgres handles without array-shape pitfalls and are easy to extend.
-- ============================================================================

create table if not exists public.profession_groups (
  group_name text not null,
  profession text not null,
  primary key (group_name, profession)
);

create table if not exists public.compatible_professions (
  profession_a text not null,
  profession_b text not null,
  primary key (profession_a, profession_b)
);

insert into public.profession_groups (group_name, profession) values
  ('education', 'student'),
  ('education', 'teacher'),
  ('tech', 'software_engineer'),
  ('tech', 'engineer'),
  ('creative', 'designer'),
  ('creative', 'artist'),
  ('creative', 'writer'),
  ('health', 'doctor'),
  ('health', 'nurse'),
  ('health', 'therapist_counselor'),
  ('business', 'entrepreneur'),
  ('business', 'sales_marketing'),
  ('business', 'finance_accounting'),
  ('legal', 'lawyer'),
  ('trades', 'trades'),
  ('food', 'chef'),
  ('services', 'hospitality_retail'),
  ('care', 'caregiving'),
  ('care', 'parent_homemaker'),
  ('other', 'unemployed_job_seeking'),
  ('other', 'retired'),
  ('other', 'other')
on conflict do nothing;

insert into public.compatible_professions (profession_a, profession_b) values
  ('software_engineer', 'designer'),
  ('entrepreneur', 'finance_accounting'),
  ('entrepreneur', 'lawyer'),
  ('engineer', 'trades'),
  ('chef', 'hospitality_retail'),
  ('doctor', 'therapist_counselor'),
  ('nurse', 'caregiving'),
  ('parent_homemaker', 'caregiving'),
  ('student', 'engineer')
on conflict do nothing;

-- Similarity score between two professions.
--   4 = same profession
--   3 = same professional group
--   2 = curated complementary pair
--   1 = unrelated
create or replace function public.profession_rank(p_human text, p_helper text)
returns int
language sql
stable
as $$
  select case
    when p_human is null or p_helper is null then 1
    when p_human = p_helper then 4
    when exists (
      select 1
      from public.profession_groups ga
      join public.profession_groups gb on ga.group_name = gb.group_name
      where ga.profession = p_human and gb.profession = p_helper
    ) then 3
    when exists (
      select 1 from public.compatible_professions cp
      where (cp.profession_a = p_human and cp.profession_b = p_helper)
         or (cp.profession_a = p_helper and cp.profession_b = p_human)
    ) then 2
    else 1
  end
$$;
