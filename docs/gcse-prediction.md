# Step 3: predicting GCSE results from primary-school work

A five-year gap between a Y6 profile and a GCSE result makes this a probability question, not a
certainty one: the output should be a likely range that narrows as a pupil moves closer to Year 11,
not a single predicted grade. The binding constraint is not more primary-school data, it is a
**labelled dataset**, meaning real pupils whose KS2 profile and eventual GCSE results are both known.
This data has none, since these are Y1 to Y6 pupils. There are two realistic routes to one: grow it
internally, which means waiting for a cohort to travel from primary through to GCSE age, or license a
linkage to the DfE's National Pupil Database, which already holds KS2-to-KS4 outcomes nationally and
could calibrate a first model years earlier.

The features go beyond a single snapshot. Subject-by-subject attainment matters, but so does
**trajectory**: whether a pupil is improving, plateauing or dipping, and whether a dip is a blip or a
trend. This pipeline already supports that without collecting anything new, because it keeps granular
history rather than overwriting it, and the point-in-time design means a model can be evaluated
honestly on what was knowable at the time rather than leaking later information. The sharper version
sits below subject level: the curriculum nests as subject, topic, subtopic, atom, where an atom is one
specific skill with its own bank of questions. Tracking which atoms a pupil has and has not mastered
over time is far more diagnostic than a subject percentage, since two pupils on the same percentage can
have entirely different gaps underneath it. I have not built atom-level features here, but the data
supports them and that is where I would look first for signal.

None of it works fairly without context. Family income, EAL, SEN status and the school a pupil attends
all correlate strongly with GCSE outcomes independently of ability, and none of that exists in this
dataset, so a model built on attainment alone would both perform worse and risk mispredicting for
particular groups in ways that are hard to detect. Given these predictions could influence where a
teacher spends their attention, testing for that bias belongs in the build rather than after it. I
would assume KS2 attainment and trajectory carry real predictive signal, which DfE's own progress
measures support, but treat it as noisy across five years: I would start with a simple baseline of attainment
plus trend, sanity-check it against the national KS2-to-KS4 patterns DfE already publishes before
trusting it on Atom's smaller population, and present the result to teachers as a range with a
confidence attached. The cost of a confident, wrong prediction this far out is real.

The [year group calibration](year-group-calibration.md) is a small worked example of that discipline on
the data already here: an independent instrument used to check a score, the size of the uncertainty
measured rather than assumed, and the resulting adjustment left unapplied once the sample proved too
thin to carry it.
