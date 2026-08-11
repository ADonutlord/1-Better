-- ============================================================================
-- 1% Better — Professions fix
-- 2D array literals in Postgres need uniform dimensions; pad short groups
-- with null so the profession_rank function from 0013 compiles.
-- ============================================================================

create or replace function public.profession_rank(p_human text, p_helper text)
returns int
language plpgsql
stable
as $$
declare
  i int;
  v_group_a text;
  v_group_b text;
  v_groups text[][] := array[
    array['student'::text,'teacher',null],
    array['software_engineer'::text,'engineer',null],
    array['designer'::text,'artist','writer'],
    array['doctor'::text,'nurse','therapist_counselor'],
    array['entrepreneur'::text,'sales_marketing','finance_accounting'],
    array['lawyer'::text,null,null],
    array['trades'::text,null,null],
    array['chef'::text,null,null],
    array['hospitality_retail'::text,null,null],
    array['caregiving'::text,'parent_homemaker',null],
    array['unemployed_job_seeking'::text,'retired','other']
  ];
  v_pairs text[][] := array[
    array['software_engineer'::text,'designer'],
    array['entrepreneur'::text,'finance_accounting'],
    array['entrepreneur'::text,'lawyer'],
    array['engineer'::text,'trades'],
    array['chef'::text,'hospitality_retail'],
    array['doctor'::text,'therapist_counselor'],
    array['nurse'::text,'caregiving'],
    array['parent_homemaker'::text,'caregiving'],
    array['student'::text,'engineer']
  ];
begin
  if p_human is null or p_helper is null then
    return 1;
  end if;

  if p_human = p_helper then
    return 4;
  end if;

  for i in 1..array_length(v_groups, 1) loop
    if array_position(v_groups[i], p_human) is not null then
      v_group_a := 'g' || i;
    end if;
    if array_position(v_groups[i], p_helper) is not null then
      v_group_b := 'g' || i;
    end if;
  end loop;

  if v_group_a is not null and v_group_a = v_group_b then
    return 3;
  end if;

  for i in 1..array_length(v_pairs, 1) loop
    if (v_pairs[i][1] = p_human and v_pairs[i][2] = p_helper)
       or (v_pairs[i][1] = p_helper and v_pairs[i][2] = p_human) then
      return 2;
    end if;
  end loop;

  return 1;
end;
$$;
