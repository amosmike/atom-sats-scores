-- The calibrated percentage must be the raw percentage minus that year group's offset.
--
-- Worth testing explicitly because the arithmetic is easy to get backwards: a positive offset means
-- the papers ran easy, so the pupil's percentage is adjusted DOWN, not up. Getting the sign wrong
-- would still produce plausible-looking scores, which is exactly the kind of bug that survives a
-- casual eyeball. Tolerance allows for pct_correct being stored rounded to 1 decimal place.
with pupil_year_group as (

    select pupil_id, any_value(year_group) as year_group
    from {{ ref('int_pupil_screener_scores') }}
    group by pupil_id

)

select
    f.pupil_id,
    f.subject_name,
    f.pct_correct,
    f.pct_correct_calibrated,
    cal.offset_pct_points,
    abs((f.pct_correct - cal.offset_pct_points) - f.pct_correct_calibrated) as deviation
from {{ ref('fct_pupil_subject_scores') }} f
inner join pupil_year_group pyg on pyg.pupil_id = f.pupil_id
inner join {{ ref('int_year_group_calibration') }} cal on cal.year_group = pyg.year_group
where f.pct_correct_calibrated is not null
  and abs((f.pct_correct - cal.offset_pct_points) - f.pct_correct_calibrated) > 0.15
