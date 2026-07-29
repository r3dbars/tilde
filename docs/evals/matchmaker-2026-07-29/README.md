# Matchmaker A/B — frozen artifacts, 2026-07-29

The write-up lives in
`docs/research/2026-07-29-matchmaker-verdict-and-memory-thesis.md`. This folder
holds the numbers and the harness so the result can be checked or re-run
without depending on `~/.cache/steadytype-eval/`, which is disposable.

## Results

| file | what |
|---|---|
| `ab-full-suite.json` | the real run: TEXTING-1500 + GENERAL-8000, both arms, with per-register breakdown |
| `ab-random-exemplar-control.json` | random personal exemplars instead of retrieved — the control that proves matching is the active ingredient |
| `ab-strict-floor.json` | first pass, 205-memory index (strict quality floor) |
| `ab-loose-floor.json` | first pass, 897-memory index |
| `chart-full-suite.png` | baseline vs random vs retrieved, both papers |
| `chart-first-ab.png` | earlier chart, both index floors |

## Harness

`build_index.py` builds the meaning-memory from capture and runs a 10-probe
retrieval demo. `ab_quiz.py` runs the A/B; `chart.py` draws the comparison.

Environment knobs on `ab_quiz.py`:

    AB_FLOOR=strict|loose        pair quality floor (index size)
    AB_PAPERS=live,texting,general
    AB_N_TEXTING=1500
    AB_ARMS=without,with
    AB_EXEMPLARS=retrieved|random
    AB_RESULTS=<filename>

It serves the champion model on a **private llama-server on port 17999** and
never touches the running app on 17872. Port 8800 belongs to a different
project and is never touched.

## Reading the numbers

`similar★` is the fraction of answers whose meaning matches the human's
(MiniLM cosine ≥ 0.5 on the first 12 words) — the metric training plateaued on
and the one this experiment targets. `word1` / `word12` / `word123` are exact
first-N-word matches. `spoke` is how often the model said anything at all.

The headline: **similar★ 7.1 → 8.5 on the owner's own messages
(McNemar p≈0.051), while the general paper regresses** — so always-on
injection fails the ship-gate, and the memory needs breadth before it earns
a place in the app.

## Caveat worth keeping

These arms talk to the model directly and bypass the app's ~15-filter cleaner
stack, so absolute numbers run higher than the nightly's. Both arms share the
identical path, so the **deltas** are the trustworthy part, not the levels.
