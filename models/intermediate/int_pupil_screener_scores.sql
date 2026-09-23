-- One row per pupil: how they did on the Screener battery.
--
-- Screeners are the one instrument in this data sat by every year group (Y3-Y6) with the same
-- questions — Y3 and Y6 share 100% of items. That makes it a common ruler across year groups,
-- which English and Maths can't be, since each year sits its own paper. See README
-- "Calibrating year groups against a common test".
--
-- Year group here is the pupil's own recorded label, NOT the paper's home year group: a Screener
-- paper is deliberately shared across years, so `home_year_group` is meaningless for it.
select
    pupil_id,
    any_value(year_group_label) as year_group,
    count(*) as n_questions,
    countif(is_correct) as n_correct,
    safe_divide(countif(is_correct), count(*)) as screener_pct
from {{ ref('int_pupil_subject_responses') }}
where subject_name = 'Screeners'
  and year_group_label is not null
group by pupil_id
