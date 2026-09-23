# How I used AI on this task

Written to cover the "AI planning documents, prompts or commits" part of the submission. The
findings themselves live in [README.md](README.md) — this is about how the work was done.

I used Claude Code throughout, with BigQuery access, as an investigator and a pair rather than a
code generator. The short version: it did the looking, I did the deciding, and both of us were
wrong at points that the other caught.

## The loop

1. Gave it the job description and the task, and had it gather context before writing anything.
2. Set up the environment — uv, dbt, BigQuery auth.
3. **Profiled before designing.** This was the most valuable step. Rather than jumping to a data
   model, I had it characterise all four tables first: keys, duplicates, orphans, date ranges,
   distributions. Almost every design decision later traced back to something found here.
4. Worked through the ambiguous calls one at a time — duplicates, no-attempts, which subjects to
   score, what "point-in-time" means — deciding each, then writing it into the README before moving on.
5. Built the models, then audited them for over-engineering and cut what didn't earn its place.
6. Kept exploring after the build, in a [notebook](notebooks/explore_questions.ipynb) rather than
   throwaway queries, so the working stayed reproducible and I could go back to it. This turned up
   things the build had missed — that every Screener sitting drills a single skill, that no pupil ever
   retakes a test — and several of them changed what the README says.

## What I decided, and where I overruled it

The judgment calls are mine. Several changed the output materially:

- **Duplicate answers.** 2,082 questions are recorded more than once, and 965 disagree with
  themselves about whether the pupil was right. Claude's first instinct was "any correct = correct".
  I rejected that: a pupil who clicked through several options and settled on a wrong one shouldn't be
  credited. The rule became correct *only* if every copy agrees, which is the conservative direction.

- **Minimum evidence.** It proposed a per-pupil threshold — no score below 30 questions. I pushed
  back: a child who sat a test should be scored on what they did, not hidden. The threshold belonged
  at subject level (is there enough data to score this subject at all), not pupil level. It had
  conflated two different questions.

- **Point-in-time vs live scoring.** I asked whether the brief's point-in-time requirement meant I
  should score tests mid-flight. It initially agreed that was a gap. On working it through, it wasn't:
  point-in-time means recomputing *backwards* ("what was their score on 1 March"), not scoring a test
  in progress. Worth flagging because the two are easy to conflate and the design differs completely.

- **Keeping the messy data.** Where it proposed dropping records — unfinished sittings, stray year
  groups, sessions with no sitting record — I pushed to keep and flag instead. Losing 1,433 answers
  because a join failed isn't a fix.

- **Over-engineering.** I asked it to audit its own work against the brief. It found a whole
  subject-eligibility mechanism that could never fire (it checked a threshold *after* filtering to the
  two subjects that always passed it) and a config variable referenced by nothing. Both were cut. I
  also asked what justified an extra column it had offered; it conceded there wasn't a reason and
  dropped it.

- **Being pedantic paid both ways.** I queried whether a `gov_uk_table_year` of `2026` should be
  `2025/2026` to avoid cohort confusion. It argued against — the integer matches GOV.UK's own
  publication name and stays sortable, and my design deliberately doesn't map cohorts to table years.
  Good argument, so I left it.

## Where it got things wrong

Worth recording, because this is the part that decides how much supervision AI work needs.

- **It reported the point-in-time recompute working when it wasn't.** A clean `dbt run` and a
  correctly-stamped date column both looked fine. The scores hadn't changed at all: BigQuery views
  store their SQL as compiled at creation, so re-running only the final table read through a stale
  view and silently ignored the date. Only caught by comparing actual row values between two runs.
  The lesson I'd carry: a green pipeline is not evidence that the logic ran.

- **It raised a false alarm on its own calibration.** It flagged a bug where calibrated scores looked
  wrong by year group. The model was fine — its verification query was comparing two different
  populations, because SQL `AVG` skips nulls. It found this itself on investigation, and then wrote a
  test so the real version of that mistake can't slip through.

- **Documentation drifted from decisions.** More than once the README still described an approach I'd
  since replaced. It caught most of these on re-reading, but only when prompted to look.
