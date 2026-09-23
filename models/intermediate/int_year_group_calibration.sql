-- How evenly is each year group's English/Maths paper pitched?
--
-- We can't tell from the papers themselves, because every year sits a different one. The Screener
-- battery is the missing piece: the same questions sat by every year group from Y3 to Y6, so it
-- measures pupils on one common ruler regardless of age.
--
-- Method: across all pupils who sat both, fit the general relationship between Screener score and
-- English/Maths score. Then for each year group, compare what they actually scored against what
-- their Screener results predict. Scoring above prediction means the papers are pitched easy.
--
-- Lives in intermediate, not marts, because two marts consume it: fct_year_group_calibration
-- presents it, and fct_pupil_subject_scores uses the offsets to produce a calibrated score.
with english_maths as (

    select
        pupil_id,
        safe_divide(countif(is_correct), count(*)) as em_pct
    from {{ ref('int_pupil_subject_responses') }}
    where subject_name in unnest({{ scored_subjects_array() }})
    group by pupil_id

),

paired as (

    select
        s.pupil_id,
        s.year_group,
        s.screener_pct,
        em.em_pct
    from {{ ref('int_pupil_screener_scores') }} s
    inner join english_maths em using (pupil_id)

),

-- Fitted across every paired pupil at once. Pooling is deliberate: fitting per year group would
-- re-absorb the very difference we're trying to measure.
fit as (

    select
        covar_pop(em_pct, screener_pct) / nullif(var_pop(screener_pct), 0) as slope,
        avg(em_pct)
            - (covar_pop(em_pct, screener_pct) / nullif(var_pop(screener_pct), 0)) * avg(screener_pct)
            as intercept,
        corr(em_pct, screener_pct) as overall_correlation,
        count(*) as pupils_in_fit
    from paired

)

select
    p.year_group,
    count(*) as pupils,
    avg(p.screener_pct) * 100 as screener_mean_pct,
    avg(p.em_pct) * 100 as actual_em_pct,
    avg(f.intercept + f.slope * p.screener_pct) * 100 as predicted_em_pct,

    -- Positive: scores higher than Screener results predict, so papers look pitched easy.
    -- Negative: pitched hard. Subtract this from a pupil's percentage to remove the pitch effect.
    (avg(p.em_pct) - avg(f.intercept + f.slope * p.screener_pct)) * 100 as offset_pct_points,

    corr(p.screener_pct, p.em_pct) as within_year_correlation,
    any_value(f.overall_correlation) as overall_correlation,
    any_value(f.pupils_in_fit) as pupils_in_fit
from paired p
cross join fit f
group by p.year_group
