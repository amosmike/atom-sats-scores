{{ config(severity = 'warn') }}

-- A sitting that has answered every question but was never marked finished, and has gone quiet,
-- is stuck rather than still in progress — see README "Known bugs". This is severity warn here
-- because nobody is on call for a take-home task; in production this should fail the run.
with answered as (

    select
        session_id,
        count(*) as n_answered,
        max(answered_at) as last_answered_at
    from {{ ref('stg_responses') }}
    group by session_id

)

select
    s.session_id,
    s.total_questions,
    a.n_answered,
    a.last_answered_at
from {{ ref('stg_assessment_sittings') }} s
inner join answered a using (session_id)
where not s.is_complete
  and a.n_answered >= s.total_questions
  and timestamp_diff(current_timestamp(), a.last_answered_at, minute) > 60
