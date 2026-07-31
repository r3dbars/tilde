# How Tilde improves — the whole system on one page

Everything below already exists and runs. This page is the map; if a document
disagrees with it, this page wins.

## The loop

    you type  →  it records  →  3:30 AM: retrain on the day
              →  new brain takes the exams
              →  better stays, worse is thrown away

That is the product improving itself. Worst case, every night, is "no
change" — the gate discards any brain that regressed. Nothing else in the
system is allowed to change the model.

## The three numbers

Run `python3 script/scorecard.py`.

1. **Words earned per suggestion** — the product. Words you accepted ÷
   suggestions shown. Rises by suggesting better OR interrupting less;
   collapses if either is abandoned. Cannot be gamed.
2. **Accept rate** — the annoyance. Why someone would uninstall.
3. **similar★** — the voice. Does it guess your *meaning*? The stuck one,
   and the one the memory experiment targets.

If none of the three moved, nothing else matters today. Every other number
(`--full`, `docs/evals/METRICS.md`) is for diagnosing WHY one of these moved.

## The three judges

Every suggestion faces three questions. Two seats are filled:

| judge | question | status |
|---|---|---|
| the filters (~15 rules) | are the WORDS junk? | works — kills fragments/echoes before display |
| the moment model | is NOW a good time? | built; browsers/Zoom/afternoons are dead ground |
| whole-phrase confidence | is the SENTENCE good? | **missing — the next build.** p_first judges one syllable |

The empty seat is why long suggestions run at ~2% acceptance.

## What runs on a schedule (everything else is on-demand)

| when | what |
|---|---|
| 3:30 AM | retrain + exams + gate (the loop above) |
| 4:15 AM | journal organizer writes the daily page |
| Aug 11, once | matchmaker re-test, then it removes itself |

The 8,000-question strangers' exam is deliberately NOT scheduled: run it
before ship decisions, not nightly.

## The rules that keep it bulletproof

1. **One experiment at a time, and every experiment ends in a written
   sentence** (kept / parked-until-date / dead). An experiment without a
   verdict is clutter. Current: matchmaker — retest Aug 11. Parked: accept
   predictor. Dead: distillation, register-gating, confidence-gating phrases.
2. **No silent liars.** A toggle isn't done until a test shows it failing;
   a metric isn't trusted until the instrument is checked. Every bug this
   week (dead toggles, leaking exam, mute that didn't mute) was a silent
   liar; the tests that now exist each reproduce one.
3. **Rule out "broken" before concluding "worse."** The scorecard's health
   line exists because quiet capture once nearly read as a regression when
   the owner was simply travelling.
4. **When a measurement disagrees with a number you already trust, the
   measurement is wrong.** Caught two labeling bugs and one fake +16pt
   exam win this week.
5. **Delete the apparatus once the lesson is written.** The finding goes in
   `docs/research/`; the scaffolding goes away.

## Where things live

- verdicts and lessons: `docs/research/` (dated, one file per finding)
- the numbers reference: `docs/evals/METRICS.md`
- frozen experiment data: `docs/evals/<experiment>-<date>/`
- this page: the summary that outranks them all
