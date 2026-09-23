# GOV.UK SATs scale — research and final decision

Research into what GOV.UK publishes for KS2 scaled scores, and how I used it to build the 80–120 scale.
**This is now built** — see README "How the scale is built" for the live description, and
`seeds/sats_scale_lookup.csv` for the actual output. This file keeps the original research and shows
how the "options" below resolved once I had the real tables and could check them against the pupil data.

## What GOV.UK actually publishes

- Every July, the Standards and Testing Agency publishes a table that converts raw marks to a scaled score, for that year's KS2 tests.
- There are three separate tables: maths (out of 110), reading (out of 50), and GPS/grammar (out of 70).
- Sources: [2025 tables](https://www.gov.uk/government/publications/key-stage-2-tests-2025-scaled-scores/2025-key-stage-2-scaled-score-conversion-tables), [2026 tables](https://www.gov.uk/government/publications/key-stage-2-tests-2026-scaled-scores/2026-key-stage-2-scaled-score-conversion-tables), [how scaled scores work](https://www.gov.uk/guidance/understanding-scaled-scores-at-key-stage-2).
- 100 means "met the expected standard". 80 is the lowest possible score, and needs at least 3 marks out of the total. Below 3 marks, there's no score at all. 120 is the highest possible score.
- The tables only cover **raw marks**, not percentages. I worked out the percentages myself.
- The tables are **only for Year 6**. GOV.UK doesn't publish anything for Y3, Y4 or Y5, and doesn't say how to apply the Y6 scale to other years.
- **The tables change every year**, because the difficulty of the test changes. The raw mark needed to hit 100 moves up or down each year to keep the standard the same.

## What I found when I pulled the tables apart

- I downloaded the official 2025 and 2026 tables and checked they behave sensibly (scores only go up as raw marks go up, no gaps or errors). They do.
- Turning the raw marks into percentages:

  | Subject | % needed for 100 (2025) | % needed for 100 (2026) | % needed for 120 |
  |---|---|---|---|
  | Maths | 52.7% | 50.9% | ~99% |
  | Reading | 56.0% | 50.0% | ~94–96% |
  | GPS | 50.0% | 48.6% | ~93–94% |

- The relationship between percentage and scaled score is **not a straight line**. It's steep at the bottom, flattens out in the middle (around 90–105), then gets steep again near the top.
- **Each subject has its own curve.** For example, 80% correct comes out as 107 in maths, but 110–111 in reading and GPS. A single formula shared across all subjects would give the wrong answer for some of them.
- **The curve moves a bit year to year.** Comparing 2025 to 2026, most raw marks shift the scaled score by only 1 point either way. Reading shifts by up to 3 points at the low end.

## The core problem

- The GOV.UK tables convert *official SATs raw marks* to a scaled score. The pupils here sit *different assessments* (Atom's own papers), so a percentage on an Atom paper isn't the same thing as a raw mark on the real SATs paper.
- There's also nothing published for anything other than Year 6, but a scale is needed for every year group.

## Options I considered, from simplest to most involved

1. **Use the Y6 curve as-is for every year group.**
   Simple, and defensible since GOV.UK is what the brief points to. Downside: a Y3 pupil scoring 60% on a Y3 paper would get the same score as a Y6 pupil scoring 60% on the (harder) Y6 paper, even though those two results don't mean the same thing.

2. **Anchor each year group on a "pass mark" percentage, then reuse the shape of the GOV.UK curve.**
   Treat "meeting the expected standard for that year" as 100, using something close to the real GOV.UK pass mark (roughly 50–56%, depending on subject and year), and reuse the general shape of the published curve around it. This needs an assumption written down and defended for each year group's anchor point.

3. **Build a scale from Atom's own data (percentiles).**
   Rank pupils against their own year group and subject, and turn that ranking into a score centred on 100. This uses the real data, but it stops being a "SATs score" in the GOV.UK sense — it becomes a relative ranking instead. With only 18–37 pupils per year group, this would also be quite noisy.

## What I actually decided

Once BigQuery access was back and I had the real 2026 tables, option 2 turned out not to be
available as a distinct choice: it needs a defensible, independent pass-mark percentage for each
year group, and I found no external source and no sound basis in the data for setting a
different one for Y1–5. Picking one anyway would just be option 3 (self-referential) wearing option
2's name. So I went with **option 1, stated plainly**: one curve per subject, from the real Y6
tables, applied to every year group, with the trade-off named outright rather than dressed up as a
year-specific calibration I don't actually have.

Two more decisions came out of building it:
- **"English" is Reading and GPS averaged together, point by point.** Real KS2 English also has a
  teacher-assessed Writing component that isn't in the data at all, so this is the closest
  defensible approximation from what I have, not a true equivalent.
- **The 2026 table only**, not matched to when a pupil actually sat their test. Atom's own papers
  aren't the real SATs anyway, so matching a sitting's date to "the correct" GOV.UK year would be
  false precision — the tables move by 1 to 3 points year over year.

## Loose ends — resolved

- **Checked against real pupil percentages:** cohort medians run 50–64% per year and subject,
  comfortably inside GOV.UK's ~49–57% pass-mark range, so anchoring there doesn't push these pupils
  to the extremes.
- **Questions per paper:** 15–50 on any single paper, but this turned out not to matter — a
  pupil's score is built from every sitting they've done pooled together, not one paper, so most
  scored pupils have 100+ questions behind their score.
- **Which table year:** 2026 only, for every sitting regardless of date — see above.
