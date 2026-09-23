-- The year group a test was actually written for: the most common recorded label among the real
-- sittings of that assessment. Used to flag when a pupil's own label disagrees with it — see
-- README "Year groups and tests". Ties are broken by the lower year group, arbitrarily but
-- deterministically, so a re-run always picks the same one.
select
    assessment_id,
    year_group_label as home_year_group
from (
    select
        assessment_id,
        year_group_label,
        count(*) as n_sittings
    from {{ ref('stg_assessment_sittings') }}
    where year_group_label is not null
    group by assessment_id, year_group_label
)
qualify row_number() over (
    partition by assessment_id order by n_sittings desc, year_group_label asc
) = 1
