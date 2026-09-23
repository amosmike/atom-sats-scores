-- Current version of each sitting, from the historized snapshot. Renamed year_group_at_sitting
-- to year_group_label to make clear downstream that this is the recorded label, not necessarily
-- the year group the test itself was written for — see README "Year groups and tests".
select
    session_id,
    pupil_id,
    assessment_id,
    session_type,
    style,
    year_group_at_sitting as year_group_label,
    total_questions,
    is_complete,
    is_deleted,
    started_at,
    finished_at
from {{ ref('snap_assessment_sittings') }}
where dbt_valid_to is null
