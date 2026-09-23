-- Diagnostic: are each year group's English/Maths papers pitched at the same difficulty, measured
-- against the Screener battery as a common ruler? One row per year group (Y3-Y6 — Screeners aren't
-- sat below Y3). The calculation lives in int_year_group_calibration; this adds the translation
-- into scaled-score points, which is what makes the size of the effect legible.
--
-- See README "Calibrating year groups against a common test".
select
    cal.year_group,
    cal.pupils,
    round(cal.screener_mean_pct, 1) as screener_mean_pct,
    round(cal.actual_em_pct, 1) as actual_em_pct,
    round(cal.predicted_em_pct, 1) as predicted_em_pct,
    round(cal.offset_pct_points, 1) as offset_pct_points,

    -- The same offset expressed on the 80-120 scale: the score at this year group's actual
    -- percentage, minus the score at its calibrated percentage. Uses the Maths curve as a
    -- reference — English differs by a point or two in places, so this indicates the size of the
    -- effect rather than being subject-specific.
    coalesce(actual_scale.sats_score, 0) - coalesce(adjusted_scale.sats_score, 0)
        as offset_scaled_points,

    round(cal.within_year_correlation, 3) as within_year_correlation,
    round(cal.overall_correlation, 3) as overall_correlation,
    cal.pupils_in_fit

from {{ ref('int_year_group_calibration') }} cal

left join {{ ref('sats_scale_lookup') }} actual_scale
    on actual_scale.subject_name = 'Maths'
    and actual_scale.pct_correct = {{ clamped_pct('cal.actual_em_pct') }}
left join {{ ref('sats_scale_lookup') }} adjusted_scale
    on adjusted_scale.subject_name = 'Maths'
    and adjusted_scale.pct_correct = {{ clamped_pct('cal.actual_em_pct - cal.offset_pct_points') }}

order by cal.year_group
