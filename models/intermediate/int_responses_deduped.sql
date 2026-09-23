-- Collapses the same question recorded more than once for a sitting down to one row.
-- Correct only if every recorded copy agrees it was correct; any disagreement is treated as
-- incorrect and flagged, since nothing in the data says which copy was final.
-- See README "Assumptions" (2) and "Data quality issues".
select
    session_id,
    question_id,
    any_value(pupil_id) as pupil_id,
    logical_and(is_correct) as is_correct,
    count(distinct is_correct) > 1 as is_corrupt_duplicate,
    any_value(is_no_attempt) as is_no_attempt,
    any_value(answered_at) as answered_at,
    count(*) as n_recorded_copies
from {{ ref('stg_responses') }}
group by session_id, question_id
