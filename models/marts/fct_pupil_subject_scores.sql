-- A SATs-style score (80-120), or the reason there isn't one yet, for every pupil in every
-- scored subject. One row per pupil x subject: small, flat, and simple enough to migrate into a
-- production application database as-is. See README for the reasoning behind every decision here.
--
-- Two scores, answering two different questions:
--   sats_score             how this pupil did against the expected standard, the headline number
--   sats_score_calibrated  the same, with uneven paper pitching removed, so year groups compare
--                          more fairly. Null where we can't calibrate — see below.
with responses as (

    select *
    from {{ ref('int_pupil_subject_responses') }}
    where subject_name in unnest({{ scored_subjects_array() }})

),

-- The offset describes how a given year's PAPERS are pitched, so it keys on the paper's own year
-- group, not the pupil's recorded one. Those differ for 22 stray sittings: a pupil labelled Y4 who
-- sat Y2 papers should not carry the Y4 adjustment. Joining per response also weights the offsets by
-- how many answers came from each paper, handling pupils whose sittings span two years.
responses_with_offset as (

    select
        r.*,
        cal.offset_pct_points
    from responses r
    left join {{ ref('int_year_group_calibration') }} cal
        on cal.year_group = r.home_year_group

),

pupil_subject_stats as (

    select
        pupil_id,
        subject_name,
        count(*) as n_questions,
        countif(is_correct) as n_correct,
        safe_divide(countif(is_correct), count(*)) * 100 as pct_correct,

        -- Mean offset across this pupil's answers, and what share of them we could calibrate at
        -- all. Y1 and Y2 have no Screener data, so their answers contribute no offset.
        avg(offset_pct_points) as mean_offset_pct_points,
        safe_divide(countif(offset_pct_points is not null), count(*)) as share_calibratable,

        logical_or(coalesce(year_group_mismatch, false)) as year_group_mismatch,
        logical_or(is_sitting_inferred) as sitting_inferred,
        logical_or(is_sitting_unfinished) as includes_unfinished_sitting,
        logical_or(is_late_answer) as has_late_answers,
        max(finished_at) as last_finished_at
    from responses_with_offset
    group by pupil_id, subject_name

),

-- Only calibrate a pupil when every one of their answers sits in a year group we have a Screener
-- offset for. Calibrating part of a pupil's work and not the rest would produce a number that
-- means nothing in particular.
scored as (

    select
        *,
        case
            when share_calibratable = 1 then pct_correct - mean_offset_pct_points
        end as pct_correct_calibrated
    from pupil_subject_stats

),

-- Every pupil x every scored subject, so a pupil with nothing to score still gets a row.
pupil_x_subject as (

    select
        p.pupil_id,
        subject_name
    from {{ ref('stg_pupils') }} p
    cross join unnest({{ scored_subjects_array() }}) as subject_name
    where not p.is_deleted

)

select
    px.pupil_id,
    px.subject_name,

    case when pss.n_questions is null then 'no_answers' else 'scored' end as score_reason,
    scale.sats_score,

    calibrated_scale.sats_score as sats_score_calibrated,
    case
        when pss.n_questions is null then 'no_answers'
        when pss.share_calibratable = 1 then 'calibrated'
        when pss.share_calibratable > 0 then 'partly_outside_screener_years'
        else 'outside_screener_years'
    end as calibration_reason,

    round(pss.pct_correct, 1) as pct_correct,
    round(pss.pct_correct_calibrated, 1) as pct_correct_calibrated,
    pss.n_questions,
    pss.n_correct,
    coalesce(pss.year_group_mismatch, false) as year_group_mismatch,
    coalesce(pss.sitting_inferred, false) as sitting_inferred,
    coalesce(pss.includes_unfinished_sitting, false) as includes_unfinished_sitting,
    coalesce(pss.has_late_answers, false) as has_late_answers,
    pss.last_finished_at,

    -- The date this run represents: the as_at_date var if one was passed, otherwise today.
    {% if var('as_at_date', none) %} date('{{ var("as_at_date") }}')
    {%- else %} current_date()
    {%- endif %} as scored_as_at_date

from pupil_x_subject px
left join scored pss
    on pss.pupil_id = px.pupil_id and pss.subject_name = px.subject_name
left join {{ ref('sats_scale_lookup') }} scale
    on scale.subject_name = px.subject_name
    and scale.pct_correct = {{ clamped_pct('pss.pct_correct') }}
left join {{ ref('sats_scale_lookup') }} calibrated_scale
    on calibrated_scale.subject_name = px.subject_name
    and calibrated_scale.pct_correct = {{ clamped_pct('pss.pct_correct_calibrated') }}
