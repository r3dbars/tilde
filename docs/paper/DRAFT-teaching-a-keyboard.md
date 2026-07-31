# Teaching a Keyboard to Sound Like One Person: Field Notes from an N=1 Autocomplete Laboratory

**Justin Betker** · r3d.bar
*Draft for arXiv — v0.1, 2026-07-31*

## Abstract

I built a text-completion keyboard for macOS whose language model — a 2-billion-parameter model fine-tuned on my own writing — runs entirely on my laptop. Then I instrumented everything: 22,230 shown suggestions, every acceptance and rejection, nightly gated retraining against 9,500 frozen exam questions, and a full journal of my typing. This paper reports what the measurements said, which was frequently not what I believed. Five findings with practical value for anyone building personalized text prediction: (1) evaluations built from keystroke-derived data leak badly across naive train/test splits — 77 of 99 exam questions in one paper carried a same-session twin on the training side, inflating one result by 16 points before the leak was caught; session-level splitting eliminated it. (2) The model's token-level confidence is nearly uncorrelated with human acceptance (r = +0.06); confidence gating doubles acceptance for single-word suggestions (25%→48%) and is useless for phrases, because first-token confidence only ever judges the first token. (3) The primary bottleneck is selection, not generation: sampling five candidates nearly doubles the rate at which a meaning-correct answer exists (6.9%→14.8% on a frozen exam), but neither sequence probability nor a first-attempt learned reranker reliably finds it. (4) A young retrieval memory (four days of capture) helps its owner's register and *hurts* others' — most severely in the register most similar to its contents — because a small personal index encodes topics before it encodes voice. (5) Optimizing for meaning-similarity trades measurably against exact-word accuracy at the moment of candidate selection; the two aims coincide for single words and diverge for phrases. All experiments are single-subject by design and construction; the contribution is methods and traps, not population claims.

---

## 1. Why an N=1 laboratory

Text prediction that adapts to one specific person is usually studied at population scale, where personalization is a small delta on a large shared model. I wanted the opposite corner of the design space: one user, one machine, total instrumentation, and a model whose entire purpose is to sound like its owner.

This corner has two properties that make it a good laboratory. First, everything is measurable — running on-device with the user's consent to capture their own typing means every suggestion shown, accepted, rejected, or abandoned is logged, along with what was on screen at the time. There is no sampling, no privacy-driven aggregation, no telemetry budget. Second, the compute is free at the margin: a local model can be asked for five candidates per keystroke, retrained nightly, and examined against thousands of questions, at electricity prices. Several experiments below would cost real money against a cloud API; locally they cost an idle evening.

The system, called Tilde, is a macOS input method (the mechanism used by Chinese and Japanese keyboards, and the only sanctioned way to sit between keystrokes and the screen) backed by a local server running a quantized Gemma-2-2B fine-tuned on the author's message history. As the user types, the keyboard sends the text before the cursor plus an OCR snapshot of the visible screen to the model, and paints the model's continuation as ghost text. Tab accepts one word; a dedicated key accepts the whole phrase; typing anything else declines. Suggestions pass through roughly fifteen content filters before display.

One methodological note up front: this is autobiographical work. The subject, author, and system owner are the same person. Nothing here supports population claims, and none are made. What transfers, I believe, are the measurement traps and the shape of the bottlenecks — which anyone building in this space will meet regardless of who their user is.

## 2. The measurement system

Every claim in this paper is grounded in one of three instruments.

**Live capture.** Each shown suggestion is logged with its text, source, app, timestamp, and eventual fate (accepted / typed-over / dismissed / flagged). Over the five-day observation window this produced 22,230 shown suggestions and 987 acceptances — a 4.4% acceptance rate, and roughly sixteen interruptions per accepted word.

**Frozen exams.** Real finished messages are cut after their first two words; the model sees the prefix plus the conversational context and must produce the rest; its answer is compared to what the human actually wrote. Four exam papers: 1,500 held-out messages of the author's texting history; 64 recent live-typing moments; 10 "trap" questions built from explicitly flagged bad suggestions (where the passing answer is silence); and 8,000 questions of strangers' text across eight registers (work email, tech chat, Discord, blogs, and so on) serving as a do-no-harm floor.

**Metrics.** Exact-match on the first one, two, and three words; a meaning score (sentence-embedding cosine between the guess and the truth's first twelve words, thresholded at 0.5, called *similar★* throughout); and *spoke*, the fraction of questions where the model said anything — which catches a model that gets "better" by going quiet.

A nightly job retrains on the day's capture and re-examines the result, swapping models only if nothing regressed and something improved. Paired statistics (McNemar's exact test) are reported for every comparison, and the two central experiments carried written predictions registered before their results came back. One of those predictions was wrong; it is graded honestly in §5.

## 3. Finding 1: Your exam is probably leaking

The live-typing exam initially reported that adding retrieval memory improved exact-first-word accuracy by sixteen points. This was false, and the way it was false is the most transferable result in this paper.

Keystroke-derived data does not arrive as independent examples. One sentence of real typing produces dozens of capture events — partial prefixes, corrections, re-completions — all within seconds of each other, all nearly identical. The exam's train/test split hashed *individual event timestamps*, so keystrokes of the same sentence routinely landed on both sides of the split. Any memory-shaped system could then "predict" a test sentence by retrieving its own sibling from thirty seconds earlier. An audit found **77 of 99 exam questions had a same-app precedent within 300 seconds sitting on the training side.**

The fix is to split by *session* — contiguous same-app activity with gaps under ten minutes — so entire typing episodes fall on one side or the other. After the change, the twin count fell from 77/99 to 0/63, and the phantom sixteen-point gain evaporated. A second audit later found the fix itself had a residual bug: keying sessions by timestamp alone, when the real log already contained eleven cross-app timestamp collisions at one-second resolution. Sessions must be keyed by (app, timestamp).

Two lab rules emerged. *A suspiciously large win on a capture-derived exam means suspect the split before celebrating.* And its sibling, learned on a different bug the same week: *when a measurement disagrees with a number you already trust, the measurement is wrong.*

## 4. Finding 2: Confidence only judges the first syllable

The obvious lever for an over-talkative keyboard is a confidence threshold: only speak when sure. Joining 4,690 shown suggestions to the confidence score each was generated with produced a blunt verdict: the correlation between model confidence and human acceptance is **+0.06** — essentially nothing. Thresholding on confidence peaks at 14.7% acceptance while discarding 84% of volume, then *falls* to 5.9% at the highest confidence band. A gate that worsens as the model grows more certain is not a gate.

Suggestion *length*, by contrast, correlates at −0.27: single words were accepted 25.4% of the time, two-to-three-word phrases 4.0%, longer phrases roughly 2%.

Splitting confidence *within* length classes resolves the apparent contradiction and localizes the physics. For single-word suggestions, confidence gating works beautifully: 25% → 43% → 48% as the threshold tightens. For phrases it does nothing at any threshold. The mechanism is unglamorous: the available confidence signal was the model's probability for its *first token*. For a one-word suggestion, the first token is the answer, and the signal is meaningful. For an eight-word phrase it says nothing about words two through eight. The system had been gating sentences on how sure the model was about its opening syllable.

The general statement: **a confidence signal is only as meaningful as the fraction of the decision it actually scores**, and it must be calibrated against real behavior before being trusted as a control. (When a later experiment fit a proper calibrator, the honest probabilities collapsed into a 0–5% band — the inflated scores had been hiding how little signal existed.)

## 5. Finding 3: The bottleneck is selection, not generation

If the model's guesses are usually wrong, two diagnoses are possible: it cannot produce good answers, or it cannot recognize which of its answers are good. These have opposite remedies, and the field's default reflex — train a better model — only treats the first.

The experiment: for each of 500 frozen exam questions, sample five candidates (one at the production temperature, four warmer), then score three arms. *One-shot* — the first candidate alone, today's behavior. *Self-pick* — best of five by the model's own length-normalized sequence probability. *Oracle* — best of five chosen by peeking at the answer key, an upper bound that isolates generation quality from selection quality.

| arm | word-1 | similar★ |
|---|---|---|
| one-shot | 25.6 | 8.2 |
| self-pick | 23.4 | 8.4 |
| oracle | 29.2 | **15.2** |

The oracle nearly doubles meaning-accuracy. **The answers the product needs are already being generated and thrown away.** Meanwhile self-selection is a wash — the third independent confirmation, after §4's two, that this model cannot evaluate its own phrases.

A first attempt at an external judge — gradient-boosted trees over nine runtime features (embedding similarity to the on-screen context, overlap statistics, length, fragment indicators, the model's own log-probability), trained on 154,185 candidates from the training pool labeled with cosine-to-truth — collected 16% of the oracle gap at full exam scale (similar★ 6.9 → 8.2, +54/−35 paired flips, p = 0.056), while *significantly* trading away exact-first-word accuracy (−1.8 points, p = 0.018). Notably, 7.5× more training data collected a *smaller* share of the gap than a 4k-message pilot had (16% vs 23%): the ceiling is what the features can see, not how much they saw of it. Under the system's own standing gate ("the target metric improves, nothing regresses"), this reranker does not ship. It is parked pending a richer label source (§7).

A registered prediction preceded the full-scale run: "the gain shrinks to +1.0–1.5 and crosses into significance." Half right — it shrank to +1.3; it did not cross. The failed half is reported with the same prominence as the successful experiments, because a paper of field notes that only kept its wins would be advertising.

## 6. Finding 4: A young memory knows your topics, not your voice

The personalization lever everyone reaches for is retrieval: index the user's past exchanges, retrieve the most similar ones at suggestion time, and let the model see how the user replied to similar moments before. Four days of captured exchanges (897 after collapsing keystroke streams into whole exchanges — see §3 for why that collapse must precede the train/test split) produced a genuinely mixed verdict.

On the owner's own held-out messages: similar★ 7.1 → 8.5 (+69/−47 flips, p = 0.051) — the only lever that had ever moved this metric, right at the significance line. A control condition establishes the mechanism is real: injecting *randomly chosen* personal exchanges instead of retrieved ones scores *worse than baseline* on every metric. The matching, not the mere presence of personal text, is the active ingredient.

On strangers' text, however, always-on retrieval regressed the do-no-harm floor (first-two-word accuracy down 29% relative at n=8,000), and the per-register breakdown falsified the natural repair hypothesis. The obvious fix — enable memory only for chat-like registers, since the index was built from chat — turns out to be backwards: the register *hurt most* was tech chat (−1.5 points), the most chat-like category in the exam, while work email *improved* (+0.4).

The explanation: four days of one person's intense project work produces an index that encodes *what the owner has been talking about* (evaluation harnesses, error rates, shipping software), not *how the owner talks*. Ask it to help with a stranger's Ubuntu question and it confidently supplies the owner's diarization opinions — same conversational shape, catastrophically wrong content. It leaves email alone only because nothing in the index resembles an email. **A young personal memory is topic-specific before it is style-specific**; breadth and time, not similarity gating, are what convert one into the other. A similarity-threshold simulation confirmed the bind: any threshold high enough to protect the floor also erased the owner-side gain, because the gains come from mid-strength matches.

## 7. Finding 5, and the instrument that ties it together

Both levers that moved meaning-accuracy — retrieval (+1.4) and the reranker (+1.3) — paid for it in exact-word accuracy. This is not a coincidence of two flawed experiments; it is a property of selection. There is exactly one way to say the user's exact next words, and many ways to say their meaning. A selector optimizing meaning will, two times out of three, choose a rewording — spending an exact-match it would otherwise have banked. Model *quality* improves both aims together; candidate *selection* forcibly trades between them. For single words the aims coincide (a word is its meaning); for phrases they diverge, and since exact multi-word matches are coincidence-rare (2% acceptance), phrases arguably have no future as exact-match products at all. The design consequence for Tilde: gate single words on exactness, phrases on meaning — each mode judged by the only thing it can be good at.

The missing measurement, common to §5 and §6, is a label for *where a phrase goes wrong*. The system's richest implicit signal turned out to be already in hand, unrecorded: when a user Tab-walks through a multi-word suggestion and stops, the stopping point is a per-word verdict — accepting four of eight words says the model was right through word four and wrong at word five. In 620 reconstructed walks, 471 stopped after a single word, and nothing had recorded what was on the table when they stopped. The capture layer now logs the full offer, the taken count, and a walk identifier per acceptance, plus an explicit `walk_stopped` event. This is, to the author's knowledge, the cheapest high-resolution preference signal available to any completion system — it costs the user nothing and labels every word of every partially-accepted suggestion — and it is the designated training source for the parked reranker.

## 8. Limitations

**N=1, by construction.** One subject, one writing style, one model family, five days of dense observation. The specific numbers will not transfer; the traps and bottleneck structure, I argue, will.

**The meaning metric is circular in one arm.** similar★ is computed with the same embedding family used by the retrieval index, which could inflate the memory experiment's gains. The exact-match metrics, which share nothing with retrieval, guard the floor — but similar★ gains should be read with this in mind.

**The exams bypass the production filter stack**, so absolute numbers run higher than live behavior; all comparisons are within-harness, where the shared path cancels.

**Acceptance is not ground truth for quality.** It confounds correctness with attention, timing, and habit. §4's per-app and per-hour analysis found a five-fold acceptance swing by hour of day with content held roughly constant — the moment, not just the words, decides.

## 9. What this is for

The practical summary for builders: instrument before you optimize; split behavioral data by session or your exam will flatter you; do not trust first-token confidence beyond the first token; check whether your bottleneck is generation or selection before buying a bigger model; expect a young memory to know topics before voice; and log where users *stop* accepting, because it is the best label you own.

The system continues running; the parked experiments carry written revival conditions (a larger memory index; walk-derived labels for the reranker), and a longitudinal follow-up — the same instruments after one to two months of ordinary use — is the natural next report.

## Acknowledgments

Experiments, analysis, and drafting were conducted with substantial assistance from an AI coding agent (Claude, Anthropic), directed and reviewed by the author. All design decisions, judgments, and the decision of what to publish are the author's.

---

*Figures: see `figures/main-figures.png` — (1) the oracle gap, (2) confidence by length class, (3) the interruption funnel, (4) per-register memory impact.*
