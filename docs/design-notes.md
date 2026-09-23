# Design notes

Supporting detail for [the README](../README.md). Nothing here is required to understand what was
built or how to run it; it is the reasoning behind decisions the README states briefly.

## How the scale is built

I turn a pupil's percentage into an 80–120 score using GOV.UK's real 2026 KS2 scaled-score tables
(Maths, Reading, and English grammar/punctuation/spelling, "GPS"), converted from raw marks to percentages:

- **One curve per subject, used for every year group.** GOV.UK only publishes a conversion table for Year 6.
  I have no other external source, and nothing in the data gives a sound, independent way to say what
  "meeting the standard" should mean in Y3 versus Y6. Rather than invent a different anchor per year with
  no real basis for it, I apply the Year 6 curve everywhere. The honest trade-off: a Y3 pupil on 60% and
  a Y6 pupil on 60% get the same score, even though a Y6 paper is harder in absolute terms. I have no
  external benchmark for Y1–5 to correct this.
- **"English" is Reading and GPS averaged together, point by point.** Real KS2 English also includes
  Writing, which is teacher-assessed and isn't in the data at all, so this is the closest defensible
  approximation from what I have, not a true English SATs equivalent.
- **The 2026 table only, not date-matched to when a pupil sat their test.** Atom's own papers aren't the
  real SATs anyway, so matching a sitting's date to "the correct" GOV.UK year would be false precision;
  the year-to-year shift is 1 to 3 points at most.
- **GOV.UK has no scaled score below 3 raw marks on a fixed paper.** My percentage is pooled across a
  varying number of questions across all of a pupil's sittings, not one fixed paper, so that rule doesn't
  translate directly. I floor at 80 instead.

Implementation: a small seed table (`sats_scale_lookup`, subject × whole percentage point → score, plus the
`gov_uk_table_year` it was built from) that the score model joins against directly, with no interpolation logic
at query time.
The score is looked up from the unrounded percentage; the `pct_correct` column shown alongside it is rounded
to 1 decimal place for readability, so re-deriving a score from that displayed value can occasionally round
differently. The stored `sats_score` is always the correct one.

## Year groups and tests

How the tests are set up:
- **Each year group has its own set of short tests per subject** (English 6 to 9, Maths 4 to 6).
  Each test covers one to a few topics, and pupils sit them across the year.
- **Questions are not reused** across English or Maths tests. Only the Screeners share questions.
- **Screeners are shared by design.** 8 Screener tests are sat by Y3–Y6 together. They are not scored.
- **Pupils who sat a subject did not always sit all of its tests.** On average they sat 54% to 94% of their
  year's tests (lowest for Y5 English, 54%). A score reflects the tests that pupil actually took.

Stray sittings (kept, never dropped): 22 English and Maths sittings by 8 pupils where the year group on
the sitting does not match the test's own year group. A pupil's year group is only recorded on each sitting,
so a change of year can only be seen as a change in that label. All 8 pupils are still active
(none are deleted).
- 3 pupils sat Y2 tests in Nov 2025, then Y3 tests in Jan and Feb 2026 while still labelled Y2,
  and were labelled Y3 from May 2026. The label changed mid-year, not in September, so this is
  either sitting up followed by a move up, or a label that was updated late.
- 1 pupil was labelled Y2 for four Y6 tests in Nov 2025, then labelled Y6 from Feb 2026.
  Y2 to Y6 is not plausible, so the early labels are probably wrong.
- 2 pupils labelled Y4 sat a few Y2 tests alongside their Y4 ones (4 sittings). This looks like catch-up work.
- All 22 are complete sittings with answers, so all of them are scored.

I cannot tell from the data whether a stray is a decision or a mistake. So every sitting keeps both its
recorded year group and the test's own year group. The output table has a `year_group_mismatch` column that is true
when any sitting behind a pupil's score has two different year groups, so these pupils can be looked at separately.
This no longer affects the score itself (see "How the scale is built"); it's kept purely so these pupils can be found.

## The subjects I don't score

Four of the seven subjects produce no SATs score. They aren't all the same kind of "no", and one of
them turned out to be the most useful thing in the dataset.

**Screeners: not scored, but my only common ruler.** Every year group from Y3 to Y6 sits the
*same* Screener questions (Y3 and Y6 share 100% of items), 6 to 7 short sittings each, all inside a
single window in June. Each of those sittings covers **exactly one topic, one subtopic and one atom**:
about 19 questions drilling a single skill, against 8.8 atoms for a typical English sitting and 11.0
for Maths. They're also fast: 10.7 seconds per question against 31 to 35 for English and Maths, with skips
clustered on specific questions (14 of 138 skipped by over half of pupils, the worst by 96%).

That combination of one skill per sitting, answered at speed, with a tail of questions almost nobody
reaches, is a battery of timed subtests, not a test of what pupils know. So `is_no_attempt` means
something completely different here: ran out of time, not couldn't do it. My "no attempt counts as
wrong" rule is right for SATs and would be plainly wrong applied to this.

June is a distinct window in the year generally: Screeners (568 sittings) and Wellbeing (124) both run
then, while English and Maths nearly stop (14 and 8, against 200–325 in each of the November, February
and May waves). It reads as an end-of-year exercise separate from the termly attainment cycle.

**Wellbeing: not scored, and shouldn't be.** One sitting per pupil, 129 pupils, a survey. The 61%
"correct" figure is an artefact of the column existing, not a result. It would be useful next to
attainment for pastoral purposes (a dip with a wellbeing signal is a different conversation from a
dip without one), but that's a different product, not a SATs score.

**Verbal and Non-Verbal Reasoning: not enough pupils, and a different population.** 8 and 3 pupils,
Y6 only, inside a two-day window in September, and *none* of them also sit English or Maths. Neither
subject is part of the national curriculum. Both are classic **11+ entrance exam** subjects, and
September of Y6 is exactly when those exams are sat. Their papers run 48 to 53 questions against
roughly 27 for English and Maths, and all 8 pupils appear for the first time in September 2026 with no
earlier history. That reads as a separate 11+ preparation cohort just starting, rather than curriculum
pupils doing extra. The data supports the pattern; it can't confirm the reason. Too few to score
either way.

**Science: nothing to score.** 335 questions defined in the hierarchy, and zero responses ever
recorded against any of them. The curriculum exists; the activity doesn't.

## How I recover answers with no sitting record

1,433 answers (56 sessions, 44 pupils) point to a session that is missing from `assessment_sittings`,
the table that says which test it was, its year group, and whether it finished. I can still use them:

- Every one of the 56 sessions has its answers concentrated in a single known test: on average 80%+ of a
  session's questions belong to one test, once I look up which test each question belongs to.
- None of them are a pupil re-doing a test they already have a proper sitting for, so I am not double
  counting anyone.
- I treat the session as if it were a finished sitting of that test, using the test's year group, and set
  `sitting_inferred = true` on the resulting score so it can be told apart from a normal one.
- I do not know why the sitting record is missing (deleted at source, dropped from the extract, or lost in
  loading). `is_deleted` is false on every sitting in this data, so if these were deleted, the flag was not
  the mechanism. Worth asking the data owners directly.

## Known bugs

**A sitting can get stuck fully-answered but never marked finished.** One sitting has all 25 of its 25
questions answered, but `finished_at` is empty and `is_complete` is false. Its last answer was nearly
6 days before this was checked, so it is not a test still in progress. It should have closed itself out
and did not.

How I tell "stuck" from "genuinely still open": a test takes minutes, not days. A sitting with no
`finished_at` only counts as "maybe still open" if its last answer was very recent (say, the last hour or two).
Once it has gone quiet for longer than that, it is either abandoned (a pupil who stopped partway through,
which is normal) or stuck (fully answered but never closed, which is not). I check for the second case.

The sitting is still scored (assumption 4) and flagged with `includes_unfinished_sitting`, so the pupil
doesn't lose a test's worth of evidence to an upstream failure. That doesn't make it less of a bug.

I check for this with a dbt test that fails when a sitting has answered every question, is not marked
complete, and has had no new answers for over an hour. Right now it is set to **warn**, because this is a
take-home task and nobody is on call to act on it. In production this should **fail the pipeline run**,
because it means the app or the pipeline silently lost a "finished" write, and someone needs to look at it.

## Fixing the source data

The duplicate answers are the one problem I cannot fully solve downstream. I recommend the app
records these so the final answer can always be identified:
1. An **attempt number** on each answer, increasing by 1 each time the pupil changes it.
2. A **final answer flag** (or a timestamp precise to the millisecond), so ordering is unambiguous.
3. The **option the pupil actually picked**, not just right/wrong. That also makes any disputed answer auditable.
4. A **unique key** on session, question and attempt number, so a repeat send cannot create a second row.
5. If the data comes out of CockroachDB via a changefeed, keep its `updated` timestamp on each row.
6. A **load time** on every row in the warehouse, so past scores can be rebuilt as they were known.
7. **Timestamp rounding.** 1,608 answers are stamped 1 second after their sitting's finish time. Answers and finish times
   should round the same way, so an answer can never appear to come after the sitting ended.

## To investigate

**Year group changes and stray sittings** (8 pupils, see "Year groups and tests"): sitting up, a late label
update, or a wrong label? The `year_group_mismatch` flag marks them for follow-up, but I cannot resolve
which from this data.

**Scoring tests that are still in progress.** I score any sitting that has answers, finished or not
(assumption 4). That is safe here because nothing in this data is live: the most recent answer anywhere
is 7 days old, and both unfinished sittings have been quiet for 6 and 8 days. In production it would not
be. A run partway through a school morning would pick up a pupil three questions into a thirty-question
test and produce a score built on three answers, which would change completely an hour later. An
abandoned test is finished data and should be scored; a test still being sat is provisional and should
not be.

The rule I would add is the inverse of a completion guess: exclude a sitting that is not marked complete
*and* whose last answer is very recent, on the grounds that it is probably still being worked on, and let
it come back in on the next run once it settles. I have not built it because it would exclude nothing
from this dataset and so cannot be tested against it, and an untestable rule guarding a case that does not
occur is worse than a documented gap. It needs a real threshold too, which should come from how long
sittings actually take in production rather than from a guess.

**`is_deleted` is false for every row in every table** (0 of 242 pupils, 0 of 2,509 sittings). Either nothing
in this dataset has ever been deleted, or deletions are handled another way before the data reaches the warehouse
(e.g. hard-deleted, or filtered out of the extract). Worth raising directly with the data owners. Time
allowing, this is worth a deeper look, since it affects how much I can trust the missing-sitting-record
question above.

---

## Future work: difficulty weighting and live scoring

Some assessments are set up to serve harder questions to pupils who are doing well (`style = 'adaptive'`
in `assessment_sittings`). It would be natural to want those harder questions to count for more, and to
know a pupil's score while they're still sitting the test, so the next question can be chosen well. I
did not build this. Why:

- **No difficulty data exists yet.** No table carries a difficulty or weight for a question. Without
  that, there's nothing to weight by.
- **I can't see what the adaptive tests actually did.** The 6 `adaptive` sittings in this data have zero
  responses recorded, so I can't even reconstruct what questions they served or in what order.
- **The tests I score aren't adaptive.** Every summative assessment behind the SATs score is
  `fixed_question`, the same paper for every pupil. There's no difficulty ramp to weight here today.
- **It's a different kind of system.** Weighting difficulty into a score is a batch problem, and this
  pipeline could produce a difficulty value per question (e.g. from historical pass rates) for that.
  But deciding what question to serve *next, mid-test* is a real-time, low-latency decision that belongs
  in the application next to CockroachDB, not in a batch warehouse pipeline. "Live scoring" in that sense
  would mean building that service, not extending this one.

What it would take to build later: a difficulty or ability estimate per question (even a simple one, like
% of pupils who got it right historically), and adaptive sittings that actually log their responses.

One thing that makes this more buildable than it first looks: `course_hierarchy` nests strictly as
subject → topic → subtopic → **atom** → questions, with no cross-links anywhere, and an atom is the
finest unit: a specific skill, with a bank of questions written against it (1 to 423 of them, median 22).
A sitting samples only 1 to 3 questions per atom rather than working through a bank. That matters because
a per-question pass rate would be far too noisy for atoms holding only a question or two, whereas a
**per-atom** pass rate pools enough answers to be a stable difficulty estimate, and it's a grouping that
already exists in the data rather than one I'd have to invent.

## Future work: linking forward to GCSE outcomes

My point-in-time design exists so that, years from now, I could honestly ask "what was this
pupil's primary-school profile at the point they left Y6?" rather than one contaminated by
hindsight. The model already supports this (see "Scores as at a date"). Three things are needed to
actually use it once Atom has real, linkable GCSE outcomes:

- **`pupil_id` needs to stay the same identifier** all the way from primary school to GCSE age.
  Worth confirming with the platform team. Not something this data can verify.
- **The history has to be retained continuously** between now and then. Nothing here works if the
  raw tables or the snapshot get truncated at some point in between.
- **There's no signal for exactly when a pupil left primary school.** `pupils` only has an id and
  a deleted flag: no date of birth, no leave date. Until a real "left KS2" signal exists elsewhere
  in the product, I'd proxy it with a pupil's last recorded Y6 sitting.

To make this usable without new modelling later, the score model takes an `as_at_date` parameter.
Recomputing a pupil's profile at the date they left primary is then just running the model with
that date, once I know it.

## Future work: fairness data for a predictive model

See [Step 3](docs/gcse-prediction.md) for the full reasoning. In short: nothing in this dataset
carries demographic or contextual information (free school meals eligibility, EAL, SEN, school
context), and none of it can be derived from `responses`, `assessment_sittings`, `pupils` or
`course_hierarchy` as given. It would need to come from elsewhere in Atom's systems, or a school's
own records. This is data to source, not something I can build from what's here. Without it, a
prediction model risks being both less accurate and unevenly wrong across groups of pupils it has
no context for.

