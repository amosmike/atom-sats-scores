-- One row per sitting that counts towards a score: real sittings, plus the recovered ones with no
-- sitting record. This is the single point-in-time filter for the whole pipeline. See the
-- sitting_finished_by() macro and README "Scores as at a date".
--
-- Unfinished sittings are included when they have answers. A pupil who started a test is scored on
-- what they actually did, and unreached questions produce no rows at all, so they can't drag a score
-- down. This also keeps treatment consistent: 49 sittings marked complete already have fewer answers
-- than questions, and we score those on what was answered. See README assumption 4.
with last_answer as (

    select
        session_id,
        max(answered_at) as last_answered_at
    from {{ ref('int_responses_deduped') }}
    group by session_id

),

real_sittings as (

    select
        s.session_id,
        s.pupil_id,
        s.assessment_id,
        s.year_group_label,
        h.home_year_group,

        -- An unfinished sitting has no finish time, so we date it by its last answer. Same approach
        -- as the recovered sittings below, and it keeps the as-at filter working for both.
        coalesce(s.finished_at, la.last_answered_at) as finished_at,

        false as is_sitting_inferred,
        not s.is_complete as is_sitting_unfinished
    from {{ ref('stg_assessment_sittings') }} s
    left join {{ ref('int_assessment_home_year_group') }} h using (assessment_id)
    left join last_answer la using (session_id)
    where s.session_type = 'summative_assessment'
      and not s.is_deleted
      and {{ sitting_finished_by('coalesce(s.finished_at, la.last_answered_at)') }}

),

recovered_sittings as (

    select
        o.session_id,
        o.pupil_id,
        o.inferred_assessment_id as assessment_id,
        cast(null as int64) as year_group_label,
        h.home_year_group,
        o.finished_at,
        true as is_sitting_inferred,
        false as is_sitting_unfinished
    from {{ ref('int_orphan_sessions_recovered') }} o
    left join {{ ref('int_assessment_home_year_group') }} h on h.assessment_id = o.inferred_assessment_id
    where o.inferred_assessment_id is not null
      and {{ sitting_finished_by('o.finished_at') }}

)

select
    session_id,
    pupil_id,
    assessment_id,
    year_group_label,
    home_year_group,
    finished_at,
    is_sitting_inferred,
    is_sitting_unfinished,
    year_group_label is not null
        and home_year_group is not null
        and year_group_label != home_year_group as year_group_mismatch
from real_sittings

union all

select
    session_id,
    pupil_id,
    assessment_id,
    year_group_label,
    home_year_group,
    finished_at,
    is_sitting_inferred,
    is_sitting_unfinished,
    false as year_group_mismatch -- no recorded label to compare against, see README
from recovered_sittings
