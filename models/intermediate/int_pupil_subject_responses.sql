-- One row per question-response that counts towards a score, joined up to subject and pupil.
-- Deliberately not restricted to English/Maths here — that's a mart-level decision (README
-- "What we score") — so a colleague adding a new subject next month only touches the mart and
-- the scale seed, not this layer.
select
    resp.session_id,
    sit.pupil_id,
    hier.subject_name,
    resp.question_id,
    resp.is_correct,
    resp.is_corrupt_duplicate,
    sit.assessment_id,
    sit.year_group_label,
    sit.home_year_group,
    sit.year_group_mismatch,
    sit.is_sitting_inferred,
    sit.is_sitting_unfinished,
    sit.finished_at,
    {{ is_late_answer('resp.answered_at', 'sit.finished_at') }} as is_late_answer
from {{ ref('int_responses_deduped') }} resp
inner join {{ ref('int_sittings_resolved') }} sit using (session_id)
inner join {{ ref('stg_course_hierarchy') }} hier using (question_id)
