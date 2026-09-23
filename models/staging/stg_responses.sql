-- 1:1 with the source, light renaming only. Deduplication and scoring logic live downstream in
-- the intermediate layer, not here — see README "Assumptions" (2).
select
    response_id,
    pupil_id,
    session_id,
    question_id,
    is_correct,
    is_no_attempt,
    seconds_taken,
    question_number,
    answered_at
from {{ source('de_raw', 'responses') }}
