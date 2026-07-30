# Tilde metrics — every number, ranked by how much it should change your mind

Current values are from capture 2026-07-24..28 (22,230 suggestions shown) and
the latest exam runs. Live version: `python3 script/scorecard.py`.

The ranking is the point. Tier 0 is the one to chase; tier 1 tells you whether
the product is worth keeping; tier 2 whether it is worth tolerating; tier 3
predicts both; tiers 4-5 exist so a broken app can never masquerade as a bad
one.

---

## TIER 0 — the north star

### Words earned per suggestion shown — **0.06** (target 1.00)

Words accepted ÷ suggestions shown. Sixteen interruptions per word earned.

The only single number that cannot be gamed. It rises by suggesting better OR
by interrupting less — both are the product — and it collapses if either half
is abandoned. A model that is always right but rarely speaks scores ~0; so
does one that never shuts up. Every other metric here can be moved without the
product improving.

---

## TIER 1 — did it help? (why anyone keeps it)

| metric | now | what it means |
|---|---|---|
| Words written for you | 1,232 (246/day) | the odometer; the felt benefit |
| Words per accept | 1.25 | how much each yes is worth. Near 1.0 means single words only |
| Whole-phrase share | 9% | `~` accepts vs Tab accepts. The whole-thought product is this slice |
| Share of typing | via scorecard | % of your words Tilde wrote |
| Words/min with vs without | `TildeStats` | the honest counterfactual — your fingers alone vs assisted |

**Watch:** words-per-accept. Raising acceptance by only offering single words
would inflate tier 2 while flattening this. Value needs both.

---

## TIER 2 — was it welcome? (why anyone uninstalls)

| metric | now | what it means |
|---|---|---|
| **Accept rate** | **4.4%** | accepted ÷ shown. The annoyance measure |
| Typed over | 3,276 | rejections. Also the richest training label |
| Flagged (Shift-Esc) | 11 | explicit "this was bad" — highest-trust negative |
| Walk depth | *pending build* | words taken before stopping. **The per-word verdict** |
| Benched re-shows | 86/day (was 2,030) | repeat offenders. The manners fix |
| Kills per shown | ~0 (was 0.66) | suppression moved upstream of generation |

### Accept rate by source
| source | shown | accept |
|---|---|---|
| fast (your dictionary) | 5,695 | **5.1%** |
| model (the AI) | 16,535 | 4.2% |

The dictionary beats the model. The cheap layer is currently the better one.

### Accept rate by app — *where it works and where it doesn't*
| app | shown | accept |
|---|---|---|
| Claude | 13,104 | **5.9%** |
| Messages | 538 | 4.6% |
| Codex | 1,503 | 4.1% |
| iTerm | 757 | 3.6% |
| Slack | 3,154 | **2.2%** |
| Atlas / Zoom | 2,112 | ~0.4% |

Browsers and meeting apps are hostile terrain. Slack is a third of Claude's
rate despite heavy use — worth a look, since Slack is the everyday case.

### Accept rate by hour — *the strongest signal in the whole table*
Best 06h **10%** · 11h 7% · 23h 7% — worst 13h **2%** · 15h 2% · 21h 3%

A 5× swing by time of day. Morning = composing (welcome). Afternoon =
editing existing text (interruption). This is why the mid-line guard shipped.

---

## TIER 3 — is it getting smarter? (the lab exams)

All exams work the same way: take real finished writing, hide the ending, let
the model guess, compare to what the human actually wrote.

| metric | what it asks | note |
|---|---|---|
| **similar★** | did it mean the same thing? | MiniLM cosine ≥ 0.50. **The stuck one (~8%)** and the reason the memory work exists |
| word-1 | first word exactly right? | typing saved |
| first-2 / first-3 | first two, three right? | falls off a cliff; three-in-a-row is hard |
| meaning | average closeness | the continuous version of similar★ |
| spoke | did it say anything? | catches a model that went quiet rather than good |
| EM@1 | exact match | the texting exam's headline |
| reoffend | did it repeat a flagged miss? | **must be 0** — the only exam where silence passes |

### The papers
| paper | size | asks |
|---|---|---|
| Texting | 1,500 | good at being *you*? (your old iMessages, never trained on) |
| Live | 64 | good at being *current* you? (recent typing, session-split) |
| Trap | 10 | does it repeat flagged mistakes? |
| General | 8,000 | good for *anyone*? (8 registers) — **the product floor**, currently 14.7% word-1 |

### The nightly gate
A new model ships only if **nothing regressed and something improved**
(exact-match, meaning, live paper, and traps all checked). Worst case is no
change — you cannot silently get worse overnight.

---

## TIER 4 — instrument quality (do the numbers mean anything?)

Measured 2026-07-29; the most surprising results of the week.

| metric | value | meaning |
|---|---|---|
| correlation(confidence, accepted) | **+0.06** | the model's confidence barely predicts your behaviour |
| correlation(length, accepted) | **−0.27** | length predicts it far better — shorter is better |
| accept by length | 1 word **25.4%** · 2-3 **4.0%** · 4+ **~2%** | six-to-one |
| confidence gate, single words | 25% → **48%** | works beautifully here |
| confidence gate, phrases | 4% → 5.9% | useless here |

`p_first` scores only the **first token** — the whole answer for one word,
nearly nothing for a sentence. The missing instrument is whole-phrase
confidence (length-normalised sequence log-prob).

**Rule this establishes: calibrate before you trust.** A confidence number
that does not predict behaviour is decoration.

---

## TIER 5 — is it alive? (rule out "broken")

| metric | now |
|---|---|
| app + brain running | yes / yes |
| engine identity | personal vs generic model — surfaces identity loss |
| socket latency | 0-11 ms to first byte |
| last captured keystroke | the tell that capture died |
| capture volume/day | 6-10k events on a working day |
| source mix | model 74% / fast 26% |
| exam twin count | **0** (was 77/99) — proves the exam isn't cheating |

This tier exists because of a near-miss: capture went quiet, and the manners
grade nearly read as a regression when the real cause was the owner
travelling. **Always rule out "broken" before concluding "worse."**

---

## If you only track three

1. **Words earned per suggestion** — the product in one ratio
2. **Accept rate** — whether it is welcome
3. **similar★** — whether it sounds like you

Everything else is diagnostic: reach for it when one of those three moves and
you need to know why.

## Two traps worth remembering

**Optimising a lab number.** similar★ predicts acceptance; it is not
acceptance. A model can gain on the exam and lose in the hand.

**Raising a ratio by shrinking its denominator.** Accept rate goes up if you
only ever offer single words — and tier 1 quietly goes down. Read the north
star alongside it; it catches exactly this.
