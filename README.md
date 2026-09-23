# Atom Learning Data Engineer — Take-Home Task

A SATs-style score on the 80–120 scale for every pupil, in every scored subject. dbt on BigQuery,
materialised at `atom-analytics-candidates.michael_amos.fct_pupil_subject_scores`.

This README covers what was built, how it fits together, the data quality issues and the assumptions.
Supporting detail lives alongside it: [design notes](docs/design-notes.md) (scale construction, year
groups, unscored subjects, source-data fixes, open questions), [how the scale was derived from GOV.UK's
tables](docs/govuk-sats-scale-research.md), [year group calibration](docs/year-group-calibration.md),
[Step 3: predicting GCSE results](docs/gcse-prediction.md), [how I used AI](NOTES.md), and an
[exploration notebook](notebooks/explore_questions.ipynb).

## What I built

**`fct_pupil_subject_scores`** is the model that answers the brief: 484 rows, one per pupil × subject,
covering 242 pupils across English and Maths.

| `fct_pupil_subject_scores` column | |
|---|---|
| `pupil_id`, `subject_name` | The grain. |
| `sats_score` | The deliverable: 80–120, from GOV.UK's real 2026 KS2 conversion tables. Null when a pupil has no answers. |
| `score_reason` | `scored` (306 rows) or `no_answers` (178). |
| `pct_correct`, `n_questions`, `n_correct` | The evidence behind the score. |
| `year_group_mismatch`, `sitting_inferred`, `includes_unfinished_sitting`, `has_late_answers` | Data-quality flags, carried through to the pupil. |
| `scored_as_at_date` | Which point in time this run reflects. |
| `sats_score_calibrated`, `pct_correct_calibrated`, `calibration_reason` | A second, optional score. See [year group calibration](docs/year-group-calibration.md). |

**How the score is built.** Take every question a pupil was *given* in that subject, pooled across all
their sittings, and count how many they got right as a share of all of them. Skipped questions count as
wrong, not as absent, so the denominator is every question put in front of them rather than just the ones
they attempted. That percentage is looked up in `sats_scale_lookup`, a seed built from GOV.UK's published
2026 conversion tables. GOV.UK gives those as raw marks out of a fixed paper total, so they were converted
to percentages to work against tests of varying length.

**One curve per subject, used for every year group.** GOV.UK only publishes a table for Year 6 and there
is no sound basis in this data for inventing a different anchor per year, so the Year 6 curve is applied
throughout. The trade-off, stated plainly: a Y3 on 60% and a Y6 on 60% score the same, though a Y6 paper
is harder. "English" is Reading and GPS averaged, since Writing is teacher-assessed and absent from the
data. Full reasoning in [design notes](docs/design-notes.md).

**Only English and Maths are scored.** They have enough pupils for the scores to mean something (154 and
152), against 8 for Verbal Reasoning and 3 for Non-Verbal. Screeners and Wellbeing are not attainment
tests, and Science has no responses at all. The list lives in `scored_subjects` in `dbt_project.yml`.
Adding a subject means adding it there and giving it a curve in the scale seed. No model needs changing,
because every layer below the mart already carries all seven subjects. Choosing what that curve should be
is the hard part, not the plumbing: GOV.UK only publishes tables for Maths, Reading and GPS, so anything
else needs an external source or a documented judgement of its own.

### Why 178 rows have no score

The brief asks for a score for every pupil in every subject, and every pupil is here: 484 rows, 242 pupils
across both subjects, nobody dropped. But 178 of those rows carry no score, because those pupils have no
answers in that subject. `score_reason` marks them `no_answers`.

They were deliberately not floored at 80. On the GOV.UK scale 80 is a real, attainable score meaning "sat
the paper and scored at the bottom", and one pupil in this data genuinely has it. Flooring the unassessed
to 80 would make that pupil indistinguishable from 178 I know nothing about, and would put 178 names at
the top of any "who most needs help" list, which is the opposite of what the score is for. GOV.UK takes
the same position: below 3 raw marks their own tables return "no scaled score" rather than the floor.

### Running it

```bash
dbt seed && dbt snapshot && dbt run && dbt test
```

To recompute a pupil's score as it stood on a past date:

```bash
dbt run --select +fct_pupil_subject_scores --vars '{"as_at_date": "2026-03-01"}'
```

The `+` before the model name matters: it rebuilds every upstream view too. BigQuery views store their
SQL as it was when last created rather than re-evaluating per query, so selecting only the mart would
silently read through a stale, unfiltered view and ignore the date.

## How the pieces fit together

```
sources (de_raw.*)
  -> snapshots/snap_assessment_sittings        keeps every version of a sitting, not just the latest
  -> models/staging/stg_*                      1:1 rename/cast per source table, no logic
  -> models/intermediate/
       int_responses_deduped                   collapses duplicate answers (assumption 2)
       int_assessment_home_year_group           the year group a test was actually written for
       int_orphan_sessions_recovered            recovers answers with no sitting record
       int_sittings_resolved                    real + recovered sittings, one point-in-time filter
       int_pupil_subject_responses              everything joined up, subject-agnostic
       int_pupil_screener_scores                the one test every year group sits identically
       int_year_group_calibration               are year papers evenly pitched? (beyond the brief)
  -> seeds/sats_scale_lookup                     the GOV.UK-derived scale
  -> models/marts/
       fct_pupil_subject_scores                  one row per pupil x subject: the deliverable
       fct_year_group_calibration                diagnostic: are year papers evenly pitched?
```

Each arrow is a `ref()`. `int_pupil_subject_responses` carries every subject, not just the two scored,
which is what let the year group calibration be built without touching anything upstream of it. Macros
hold logic used more than once or that the date parameter must reach consistently: `sitting_finished_by()`
is the single point-in-time filter, `is_late_answer()` and `clamped_pct()` each name one rounding
decision, and `scored_subjects_array()` keeps the mart's two uses of the subject list in step.

**Point-in-time.** A score as at a date uses every sitting that had finished on or before it, so any past
date can be recomputed. Sittings are dated by `finished_at`, or by their last answer where that is missing.
This only holds if the sitting row cannot be silently rewritten between runs, so `assessment_sittings` is
snapshotted (SCD Type 2 on `is_complete`, `finished_at`, `is_deleted`), keeping every version rather than
the latest. That table is roughly 30x smaller than `responses`, so the snapshot stays cheap at production
volume. `responses` is not snapshotted for the same reason in reverse.

The limit worth knowing: a snapshot only protects history from the point it starts running, and no
mechanism can recover a version of a row that changed before that. No raw table carries its own update
time, so the snapshot compares values run over run and its own run time becomes the load timestamp.

## Data quality issues

| Issue | How big | What I do |
|---|---|---|
| Same question recorded more than once in a sitting | 2,082 questions (4,493 rows); 965 of them disagree on right/wrong | Count once. Correct only if every copy is correct. Disagreements flagged as corrupt (assumption 2). |
| Answers whose sitting is missing from the sittings table | 1,433 answers, 56 sessions, 44 pupils | Recovered: the test is inferred from the questions answered, then scored. Flagged as `sitting_inferred`. |
| Sittings with no answers at all | 79 sittings | Nothing to score. Ignored. |
| Pupils with no answers | 78 of 242 | Kept in the output with no score. |
| Skipped questions ("no attempt") | 3,279 answers | Counted as wrong (assumption 1). |
| Sittings that are not finished | 13; only 2 have answers (31 answers) | Scored on what was answered and flagged with `includes_unfinished_sitting` (assumption 4). One of the 2 is a bug (see design notes). |
| Answers logged after the sitting's finish time | 1,608 answers, every one exactly 1 second late | Rounding. I allow 2 seconds and flag anything later (none today). I keep using `finished_at`. |
| Sittings with fewer questions answered than expected | 50 | Scored on what was answered. Flagged. |
| Missing or zero time taken | 25 missing, 3,156 zero | Time is not used for scoring, so no impact. |
| Sitting year group differs from the test's own year group | 22 sittings, 8 pupils | Kept and scored, both year groups stored, mismatch flagged. The [calibration](docs/year-group-calibration.md) corrects the difficulty difference, though not the fact that a paper may be wrong for a pupil's age. |
| Entrance-exam and mock sittings, with year groups up to 15 | 40 sittings, none with answers | Out of scope. Only summative assessments are used. |
| Non-attainment subjects (Screeners, Wellbeing) | 568 and 125 sittings | Not scored. |

Two of these are worth calling bugs rather than mess, and both are covered in
[design notes](docs/design-notes.md): a sitting that was fully answered but never marked finished (caught
by `tests/assert_no_stuck_sittings.sql`, set to warn here and should fail a run in production), and
answers timestamped a second after their sitting ended.

## Assumptions

1. **No attempt counts as wrong.** A skipped question scores the same as an incorrect one, as in real
   SATs. Most skips come at the end of a test (1.4% in the first quarter of a paper, 10.7% in the last),
   so they are largely pupils running out of time. The count is kept so it stays visible.
2. **A question is correct only if every recorded copy says so.** 2,082 questions are recorded more than
   once for the same sitting, and 965 of those disagree with themselves. The copies are identical in every
   other respect, so nothing says which was the pupil's final answer. Any disagreement is treated as
   incorrect and flagged, rather than crediting a pupil who may have settled on a wrong answer.
3. **Percentage is correct questions divided by every question the pupil was given** in that subject,
   pooled across all their sittings rather than per paper.
4. **A sitting is scored if it has answers, finished or not.** Questions a pupil never reached produce no
   rows, so an abandoned test contributes fewer questions rather than a worse score. This is consistent
   with the 49 sittings that *are* marked complete but have fewer answers than questions. An in-progress
   test cannot be told from one that errored, so both are scored and flagged with
   `includes_unfinished_sitting`. Safe here because nothing in this data is live, but it would need
   revisiting before production (see [design notes](docs/design-notes.md)).
5. **The sittings table is the source of truth** for session type and dates. The responses table labels
   the same sessions differently (`MOCK_TEST` instead of `summative_assessment`).

## Step 3, and work beyond the brief

**[Step 3: predicting GCSE results from primary-school work](docs/gcse-prediction.md).** What would be
needed to build it, what this pipeline already provides, and why the missing piece is labelled outcome
data rather than a model.

**[Year group calibration](docs/year-group-calibration.md).** Using Screeners, the one test every year
group sits with identical questions, to measure how evenly each year's papers are pitched and what that
says about the uniform-curve limitation.

## Not built

- **Difficulty weighting and live scoring.** No difficulty data exists, the adaptive sittings have no
  recorded responses, and the tests being scored are fixed-form anyway.
- **Applying the year group calibration to the headline score.** It is computed and inspectable, but
  covers Y3 to Y6 only and rests on 18 to 24 pupils per year.
- **Excluding genuinely in-progress tests.** Would exclude nothing from this dataset, so it cannot be
  tested here.

Reasoning for each in [design notes](docs/design-notes.md) and
[year group calibration](docs/year-group-calibration.md).
