# Calibrating year groups against a common test

Beyond the brief. Built and running (`int_pupil_screener_scores`, `int_year_group_calibration`,
`fct_year_group_calibration`), but it does not change the headline score. See
[the README](../README.md) for what was asked for.

## The problem

One curve covers every year group, so a Y3 on 60% and a Y6 on 60% score the same even though the Y6
paper is harder. There is no published benchmark for Y1 to Y5 to correct that with.

## How it works

Each year sits a different English and Maths paper and nobody sits two of them, so the papers cannot be
compared with each other. A Y3 on 60% and a Y6 on 60% might mean the same thing or something very
different, and nothing in the data says which.

The Screeners are the same questions for every year group from Y3 to Y6, which gives one shared
yardstick. That makes the measurement possible in three steps:

1. **Learn the general rule.** Across all 82 pupils who sat both, ignoring year group entirely, work
   out the typical relationship between Screener score and English/Maths score: a pupil scoring this
   much on the Screeners usually scores about that much on their papers.
2. **Predict each year group.** Take one year group's actual Screener scores and apply that rule. The
   answer is what they should have scored on their own papers, if their papers were pitched like
   everybody else's.
3. **Compare with what they really scored.** The gap between predicted and actual is the paper effect.

Y3 is the clearest example. They averaged 42.6% on the Screeners. The general rule says pupils at that
level usually score around 49.9% on English and Maths. Y3 actually scored 53.2%, beating the prediction
by 3.3 points, which says their papers ran easier than everyone else's.

If every year's papers were pitched identically, each year group would land on its own prediction. They
do not, and the size of the miss is the measurement.

This only holds if the Screeners measure something related to English and Maths ability. They do.
Pupils who do well on one almost always do well on the other, and the link holds within a single year
group as well as across them (0.81 overall, 0.75 to 0.89 within year, on a scale where 1.0 would be
perfect lockstep). Holding within a year matters: otherwise it would just be saying older pupils score
higher on everything.

## The result

| Year | Screener mean | Actual E/M | Predicted E/M | Off by | On the 80–120 scale |
|---|---|---|---|---|---|
| Y3 | 42.6% | 53.2% | 49.9% | +3.3 | +1 |
| Y4 | 52.8% | 53.7% | 57.8% | −4.1 | −1 |
| Y5 | 48.1% | 57.7% | 54.1% | +3.6 | +1 |
| Y6 | 64.4% | 65.5% | 66.8% | −1.3 | −1 |

**About ±1 point.** Y4 runs hard, Y3 and Y5 run easy, but the whole spread is 7.6 percentage points,
worth roughly one scaled point. The uniform-curve decision costs very little.

## Two scores in the output

`fct_pupil_subject_scores` carries both, since they answer different questions:

| Column | What it answers |
|---|---|
| `sats_score` | How is this pupil doing against the expected standard? The headline number. |
| `sats_score_calibrated` | The same, with uneven paper pitching removed, so year groups compare more fairly. |

`sats_score` stays primary and matches how real SATs work: a scaled score is normed against your own
year, not against the whole of primary school. `sats_score_calibrated` subtracts the year group's
offset before the scale lookup, and is null where that cannot be done honestly:

| `calibration_reason` | Rows | Meaning |
|---|---|---|
| `calibrated` | 201 | Every answer came from a year group with an offset. |
| `outside_screener_years` | 96 | All answers from Y1/Y2, which do not sit Screeners. |
| `partly_outside_screener_years` | 9 | Answers span calibrated and uncalibrated years. Calibrating half of someone's work would mean nothing in particular. |
| `no_answers` | 178 | Nothing to score either way. |

The two rarely diverge: of 201 calibrated rows, 29 are identical, 134 differ by one point, and 2 differ
by 3 or more (4 at most).

## Which year's offset applies

The offset belongs to the paper, not the pupil, so the lookup keys on the paper a pupil actually sat
rather than the year group they are recorded as. That matters twice over: for recovered sittings, which
have no recorded year group but a known paper, and for the 22 sittings where the two disagree. Keyed on
the label, two pupils recorded as Y4 who sat some Y2 papers would be credited with compensation for a
hard Y4 paper they never sat.

It corrects difficulty, not suitability. A pupil genuinely sitting a paper years above their own is
being tested on material they have not been taught, and no offset makes that a fair measure of what
they know. `year_group_mismatch` stays set on those scores so they can be found.

## Why it is not applied to the headline score

It covers Y3 to Y6 only, rests on 18 to 24 pupils per year group, and Y5 sitting below Y4 on the common
ruler shows how much noise that carries. A ±1 point adjustment on that basis is not strong enough to
become the number a teacher sees. Keeping it alongside means the question can be argued with rather
than assumed away.

What would change that: Screener coverage extending to Y1 and Y2, and enough pupils per year group for
the offsets to hold steady across runs.

## If you extend this

A positive offset means papers ran *easy*, so the pupil's percentage is adjusted **down**, not up.
Getting it backwards still produces plausible numbers, so
`tests/assert_calibration_applied_correctly.sql` checks the arithmetic on every run.
