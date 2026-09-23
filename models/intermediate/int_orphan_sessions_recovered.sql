-- Recovers the answers whose session is missing from assessment_sittings entirely, by working
-- out which test they belong to from the questions themselves. See README
-- "How we recover answers with no sitting record".
--
-- We have no finished_at for these (there's no sitting row at all), so we proxy it with the last
-- time we saw an answer for that session. We treat the session as a finished sitting of the test
-- we inferred, per the same README section.
with known_question_assessment as (

    -- Which assessment each question belongs to, learned only from real, known sittings.
    select distinct
        r.question_id,
        s.assessment_id
    from {{ ref('int_responses_deduped') }} r
    inner join {{ ref('stg_assessment_sittings') }} s using (session_id)
    where s.session_type = 'summative_assessment'

),

orphan_responses as (

    select r.*
    from {{ ref('int_responses_deduped') }} r
    where r.session_id not in (select session_id from {{ ref('stg_assessment_sittings') }})

),

orphan_sessions as (

    select
        session_id,
        any_value(pupil_id) as pupil_id,
        count(*) as n_questions,
        max(answered_at) as finished_at
    from orphan_responses
    group by session_id

),

votes as (

    select
        o.session_id,
        qa.assessment_id,
        count(*) as n_matched_questions
    from orphan_responses o
    inner join known_question_assessment qa using (question_id)
    group by o.session_id, qa.assessment_id
    qualify row_number() over (partition by o.session_id order by n_matched_questions desc) = 1

)

select
    o.session_id,
    o.pupil_id,
    v.assessment_id as inferred_assessment_id,
    o.n_questions,
    v.n_matched_questions,
    safe_divide(v.n_matched_questions, o.n_questions) as match_share,
    o.finished_at
from orphan_sessions o
left join votes v using (session_id)
