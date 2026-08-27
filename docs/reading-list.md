# Reading list

The external knowledge Tilde builds on: annotated links, never copied text
(free to read is not free to redistribute). Each entry earns its place with a
one-line note on what it teaches *for Tilde*. Ideas from here are hypotheses;
once measured, the result graduates to `docs/model-lessons.md` as fact.

Most high-leverage entries have an original-words digest in `docs/research/` —
method, numbers, what applies to Tilde, and what does not. The digest index is
`docs/research/README.md`. Read the digest first; fetch the source only when
the digest is not enough. Every attempt this lab makes from those papers is
written in `docs/research/lab-log.md`; reusable lessons graduate to the
Learning Ledger.

This file is the durable catalog. A 2026-08-27 sweep walked HCI word
prediction, AAC, email ghost-text, code completion, interruption science,
personalization, decoding, and writing-agency literatures. New papers should
be added here in the same row format, even if they do not yet have a digest.

## What the literature agrees on

These claims show up independently in mobile keyboards, AAC, Gmail, and Copilot.
They are priors for Tilde, not proof that the same number will appear in Mail.

1. **Showing is the product.** Smart Compose, Smart Reply, Copilot, and Horvitz
   all spend as much effort on when to stay quiet as on what to say.
2. **Tab lies.** Acceptance predicts how helped people *feel* (Ziegler 2022) and
   still rewards short junk they delete (GitHub 2025). The live headline has to
   be retained characters (RNKS), with Tab as a diagnostic.
3. **A wrong or unused look is expensive.** Quinn 2016, Koester 1994–96, Chitnis
   2024 (~10 ms right glance, ~50 ms wrong), and Li & Feit 2025 (68% of checks
   fail) all say an ignored ghost is not free.
4. **Desktop fast typists mostly skip.** Roy/TOCHI 2025: 76.5 WPM desktop,
   near-zero use, ~15% keystroke saving even at 0.9 accuracy versus ~44% on
   phone. Tilde is that desktop case.
5. **Phrases steer writing.** Arnold 2016/2020, Buschek 2021, Jakesch/CoAuthor:
   multi-word ghosts are read as *what to say*. A Tilde win that flattens the
   owner's voice is a failure even if keystrokes fall.

## Where the field actually stopped

The last *shipped personal keyboard or mail-ghost* papers are Gboard (2018),
Smart Compose (2019), and interpolation (2020). Google did not publish the
sequel. Recent work is either generic HCI (Roy 2025, Li & Feit 2025) or Copilot
metrics on code. Commercial local Mac ghosts exist; none published a ruler.

That is the hole. No paper has a system-wide desktop IME, on-device personal
memory, on-screen context, and retained characters counted without storing the
writing — for a fast typist. Roy's "desktop typists skip" was measured on
generic transcription ghosts. The unasked question is whether they still skip
when the ghost is their phrasing, grounded in the screen, and scored by whether
it stays.

How to push that without lying: digest
[`docs/research/where-the-field-stopped.md`](research/where-the-field-stopped.md).
The scientific stance (wrong objective, learn the controller, identify the
Roy interaction) is
[`docs/research/scientific-program.md`](research/scientific-program.md).
How we work as colleagues is
[`docs/research/lab-partnership.md`](research/lab-partnership.md).
The executable queue does not move because the hole is exciting. Finish the
ruler, then ask that question on the Mac.

## How to read a row

- **Digest** — Tilde note in `docs/research/`, or `—` if indexed only.
- **Run** — what we can actually do with it:
  - `github-now` — protocol, metric, or sanitized test; no owner writing.
  - `local-after-F03` — needs the Mac and retained-outcome events.
  - `parked` — true, and locked behind a later stage or a different product.
  - `not-an-experiment` — background theory; do not stand up a campaign.

## Runnable now (do these, in order)

One causal question at a time. Generator stays frozen except for the already
open Qwen close.

| Next action | Why the papers say so | Where |
| --- | --- | --- |
| Finish F03, then F04 | Every live paper above is unusable until we can count kept characters and freeze scoring cheats | Local contract + GitHub tests |
| Close Qwen a0-vs-a5 | A Lab preview is not a tournament; finish or kill | Local only |
| H01 3 vs 8 words on real writing | Roy, Arnold, Chitnis, quiz already | Local, after F03 |
| H02 stop at the visible span | CodeCompose latency; Smart Compose stop-at-punctuation | Local, after F03 |
| H03 context quality / packing | Smart Compose context; Lost in the Middle | Local, after F03 |
| H04 quiet after dismiss / fast typing | Roy, Quinn, Fogarty, McFarlane, Dhakal | Local, after F03 |
| Helper prompt-lookup / n-gram draft flag | Saxena; llama.cpp speculative | Local runtime A/B, still one question |
| H06/H07 learned or cascade quiet gate | Mozannar, Horvitz, Smart Reply | `parked` until F03 + H01–H04 |

Do not start Future Lattice, another model bake-off, private LoRA,
whole-sentence ghosts, or an edit brain because a paper exists.

---

## Catalog by Tilde question

### 1. When to stay quiet

| Paper | Tilde take | Digest | Run |
| --- | --- | --- | --- |
| [When to Show a Suggestion?](https://arxiv.org/abs/2306.04930) (Mozannar et al., AAAI 2024) | Cascade: skip generation, then hide likely rejects; never train the generator on Tab | [when-to-show-suggestion-2023.md](research/when-to-show-suggestion-2023.md) | `local-after-F03` (H06/H07) |
| [Sequential Decision-Making for Inline Text Autocomplete](https://arxiv.org/abs/2403.15502) (Chitnis, Yang & Geramifard, 2024) | Wrong glance ~50 ms, right ~10 ms; length is not the reading cost; RL lost to a threshold | [sequential-autocomplete-2024.md](research/sequential-autocomplete-2024.md) | `github-now` for the 10/50 prior; `local-after-F03` for H04 |
| [A Cost-Benefit Study of Text Entry Suggestion Interaction](https://doi.org/10.1145/2858036.2858305) (Quinn & Zhai, CHI 2016) | Always-on is slowest; thresholded is faster; silence is fastest; people still prefer suggestions | [quinn-zhai-suggestion-cost-2016.md](research/quinn-zhai-suggestion-cost-2016.md) | `local-after-F03` (H04/H06) |
| [Are Word Suggestions Beneficial?](https://doi.org/10.1145/3772716) (Roy, Casiez & Vogel, TOCHI 2025) | Desktop fast typists skip; speed only rises at high accuracy and low unaided speed; inline +4% KS, +2 WPM, more distracting than a bar | [word-suggestions-beneficial-2025.md](research/word-suggestions-beneficial-2025.md) | `local-after-F03` (H01/H04) |
| [Typing Efficiency and Suggestion Accuracy](https://doi.org/10.1145/3411764.3445725) (Roy et al., CHI 2021) | Experiment 1 of the TOCHI paper: desktop vs tablet vs phone | same digest | same |
| [Smart Reply](https://arxiv.org/abs/1606.04870) (Kannan et al., KDD 2016) | A trigger model decides whether to offer *any* reply; diversity is a filter | [smart-reply-2016.md](research/smart-reply-2016.md) | `parked` (H07 situation skip) |
| [Gmail Smart Compose](https://arxiv.org/abs/1906.00080) (Chen et al., KDD 2019) | Confidence threshold tuned to a trigger rate; 60 ms p90 is their "instant" bar | [smart-compose-2019.md](research/smart-compose-2019.md) | `local-after-F03` for the threshold idea, not the 60 ms SLA |
| [Principles of Mixed-Initiative User Interfaces](https://doi.org/10.1145/302979.303030) (Horvitz, CHI 1999) | Act only when expected benefit beats expected cost of a wrong guess; make dismiss cheap | [horvitz-mixed-initiative-1999.md](research/horvitz-mixed-initiative-1999.md) | `not-an-experiment` (rule for H06) |
| [Comparison of Four Interruption Methods](https://doi.org/10.1207/s15327051hci1701_2) (McFarlane, 2002) | Negotiate or wait for a breakpoint; do not interrupt immediately unless delay is deadly | [mcfarlane-interruption-2002.md](research/mcfarlane-interruption-2002.md) | `local-after-F03` (H04) |
| [Predicting Human Interruptibility with Sensors](https://doi.org/10.1145/1089733.1089735) (Fogarty et al.) | Typing is a "not now" sensor; task breakpoints are safer | [fogarty-interruptibility-2005.md](research/fogarty-interruptibility-2005.md) | `github-now` as H04 prior; no extra sensors |
| [How We Type with Word Suggestions](https://doi.org/10.1145/3749520) (Li & Feit, 2025) | 68% of suggestion checks fail; 43.6% saw the right word and typed it anyway | [how-we-type-word-suggestions-2025.md](research/how-we-type-word-suggestions-2025.md) | `local-after-F03` (type-through-after-show) |
| Iqbal & Bailey, breakpoint / interruption cost papers | Safer to fire after a completed subtask than mid-burst | — | `parked` (same as H04) |
| Horvitz BusyBody / LookOut | Learned "is this a meeting?" plus a decision to act now/later/never | — | `not-an-experiment` |

### 2. What to measure

| Paper | Tilde take | Digest | Run |
| --- | --- | --- | --- |
| [The road to better completions](https://github.blog/ai-and-ml/github-copilot/the-road-to-better-completions-building-a-faster-smarter-github-copilot-with-a-new-custom-model/) (GitHub, 2025) | Retained characters became the headline after acceptance rewarded junk | [copilot-retained-completions-2025.md](research/copilot-retained-completions-2025.md) | `github-now` (F03/F04 design) |
| [Productivity assessment of neural code completion](https://doi.org/10.1145/3520312.3534864) (Ziegler et al., MAPS 2022) | Acceptance predicts *felt* productivity better than persistence; that is why Tab tempts | [copilot-productivity-acceptance-2022.md](research/copilot-productivity-acceptance-2022.md) | `github-now` (keep Tab as diagnostic only) |
| [Measuring GitHub Copilot's Impact on Productivity](https://doi.org/10.1145/3633453) (CACM 2024) | Long form of Ziegler 2022; 27% accept rate, persistence 30–600 s | same digest | same |
| [The Impact of AI on Developer Productivity](https://arxiv.org/abs/2302.06590) (Peng et al., 2023) | RCT: about 55% faster on one JavaScript task. Not a Tilde target | [peng-copilot-rct-2023.md](research/peng-copilot-rct-2023.md) | `not-an-experiment` |
| [Evaluating Word Prediction: Framing Keystroke Savings](https://aclanthology.org/P08-2066/) (Trnka & McCoy, ACL 2008) | Report NKS against a ceiling; 58.7% actual vs ~78% theoretical on their UI | [trnka-keystroke-savings-2008.md](research/trnka-keystroke-savings-2008.md) | `github-now` (offline scoring note) |
| Trnka, Yarrington & McCoy, keystroke-savings limit | You cannot hit 100%; first letter + select is already a cap | same digest | `github-now` |
| Copestake 1997, Shannon-based KS ceiling | Practical word-prediction ceiling around 50–60% | same digest | `not-an-experiment` |
| Lesher, Moulton & Higginbotham 2002 | Human oracles ~59% KS; headroom exists but shrinks | same digest | `not-an-experiment` |
| [Federated Learning for Mobile Keyboard Prediction](https://arxiv.org/abs/1811.03604) (Hard et al., 2018) | Ignore federation. Steal impressions / accept / keystrokes-saved vocabulary | [gboard-federated-2018.md](research/gboard-federated-2018.md) | `github-now` (counter names) |
| SPACE framework (Forsgren et al.) | Felt productivity has several axes; do not let one Likert item ship a model | — | `not-an-experiment` |
| Soukoreff & MacKenzie, text-entry metrics | WPM, MSD, KSPC — use KSPC as the human-error floor next to NKS | — | `github-now` |
| CodeCompose metrics (Dunay et al.) | Only credit accepts shown >750 ms; keystrokes saved = accepted / typed | [multiline-code-authoring-2024.md](research/multiline-code-authoring-2024.md) | `github-now` (F04 flicker-accept) |

### 3. How long / how much to show

| Paper | Tilde take | Digest | Run |
| --- | --- | --- | --- |
| [Multi-line AI-assisted Code Authoring](https://arxiv.org/abs/2402.04141) (Dunay et al., FSE 2024) | 16% of shows, 42% of accepted chars; 9%→17% KS; jarring if the ghost moves trusted text | [multiline-code-authoring-2024.md](research/multiline-code-authoring-2024.md) | `parked` (H08); steal 750 ms floor now |
| [IntelliCode Compose](https://arxiv.org/abs/2005.08025) (Svyatkovskiy et al., FSE 2020) | Client prefix trie; explicit length score; offline similarity ≠ live CTR (~10%) | [intellicode-compose-2020.md](research/intellicode-compose-2020.md) | `local-after-F03` for memory-only trie |
| [On Suggesting Phrases vs. Predicting Words](https://eecs.harvard.edu/~kgajos/papers/2016/arnold16suggesting.pdf) (Arnold, Gajos & Kalai, UIST 2016) | Phrases = what to say; words = what I was about to type | [predictive-text-predictable-writing-2020.md](research/predictive-text-predictable-writing-2020.md) | `local-after-F03` (H01) |
| [The Impact of Multiple Parallel Phrase Suggestions](https://arxiv.org/abs/2101.09157) (Buschek, Zürn & Houben, CHI 2021) | 0/1/3/6 ghosts: more choices help ideation and hurt speed; do not add a bar | [buschek-parallel-suggestions-2021.md](research/buschek-parallel-suggestions-2021.md) | `parked` (Tilde stays at one ghost) |
| [Grounded Copilot](https://arxiv.org/abs/2206.15000) (Barke, James & Polikarpova, 2023) | Acceleration wants short checkable ghosts; exploration wants long menus | [grounded-copilot-2023.md](research/grounded-copilot-2023.md) | `not-an-experiment` (Tilde is acceleration) |
| Expectation vs experience with Copilot (Vaithilingam et al., CHI 2022) | Repair time can erase typing saved; N-best pane overloads | [vaithilingam-copilot-usability-2022.md](research/vaithilingam-copilot-usability-2022.md) | `not-an-experiment` |
| Prather et al., "It's Weird That It Knows What I Want" (TOCHI 2023) | Novices also split acceleration / exploration; over-reliance stalls | same digest | `not-an-experiment` |
| Swiffin et al. / AAC list-size studies | 5 vs 10 predictions: more keys saved, little or no speed | — | `parked` (we will not ship a list) |

### 4. Cognitive cost of a suggestion

| Paper | Tilde take | Digest | Run |
| --- | --- | --- | --- |
| Koester & Levine 1994 / 1996 | List search ate the keystroke savings; even unused lists slowed keypresses | [aac-word-prediction-koester.md](research/aac-word-prediction-koester.md) | `not-an-experiment` (cost accounting) |
| Anson et al., Assistive Technology 2006 | Word completion/prediction on on-screen keyboards: mixed or negative rates | same digest | `not-an-experiment` |
| Venkatagiri, word-prediction efficiency | Cognitive cost vs physical savings, same AAC ledger | same digest | `not-an-experiment` |
| [Typing Behavior is About More than Speed](https://doi.org/10.1145/3604276) (Lehmann et al., 2023) | Slow typists use more and still get slower; they have non-speed jobs (fix, capitalize) | [lehmann-suggestion-strategies-2023.md](research/lehmann-suggestion-strategies-2023.md) | `local-after-F03` (tag accept class, no text) |
| Kristensson & Müllners, envelope / function-structure models (CHI 2021) | Model look-cost and key-cost separately; empirics still required | — | `not-an-experiment` |
| WSTypist (Li, Feit, et al., 2026 preprint) | Simulation: ~60–70% accuracy as a trade-off band; failed gaze checks are costly | — | `parked` (no eye tracker) |
| Card, Moran & Newell; Miller 1968 | ~100 ms feels instantaneous; Smart Compose's 60 ms is a datacenter cousin | — | `not-an-experiment` |
| Dhakal et al., 136M keystrokes (CHI 2018) | Fast typists ~120 ms IKI, 40–70% rollover; render lag lands inside the burst | [typing-136m-keystrokes-2018.md](research/typing-136m-keystrokes-2018.md) | `github-now` (H04 timing priors) |
| [How we type: movement strategies](https://doi.org/10.1145/2858036.2858233) (Feit, Weir & Oulasvirta, CHI 2016) | Finger/strategy clusters; not all "fast" typists look the same | — | `not-an-experiment` |
| Palin et al., How We Type on Smartphones (CHI 2019) | Mobile helpers exist because the channel is bad; do not import that aggressiveness | [palin-mobile-typing-2019.md](research/palin-mobile-typing-2019.md) | `not-an-experiment` |

### 5. Personalization that never leaves the device

| Paper | Tilde take | Digest | Run |
| --- | --- | --- | --- |
| Smart Compose personal n-gram blend | `P = α P_personal + (1-α) P_global`; live ~6% CTR / ~10% EM; interior α (~0.4) beat "all personal" | [smart-compose-2019.md](research/smart-compose-2019.md) | `parked` (Stage 3) |
| [Personalized interpolation](https://arxiv.org/abs/2006.05469) (Shao et al., 2020) | OOV-aware α; 80% of users improved; thin history barely helps | [personalized-interpolation-2020.md](research/personalized-interpolation-2020.md) | `parked` (Stage 3) |
| [kNN-LM](https://arxiv.org/abs/1911.00172) (Khandelwal et al.) | Retrieval over past text helps rare personal tokens | [knn-lm-2019.md](research/knn-lm-2019.md) | `parked` (H09/H11) |
| [Continuous cache](https://arxiv.org/abs/1612.04426) (Grave, Joulin & Usunier) | Decaying pointer over recent hidden states; no retraining | [continuous-cache-2016.md](research/continuous-cache-2016.md) | `parked` (H10) |
| Kuhn & De Mori, cache language models | Count-based recency before neural caches existed | — | `parked` (H10) |
| Jurafsky & Martin, SLP ch. 3 | KN smoothing / backoff behind the Personal History table | [ngram-language-models-slp3.md](research/ngram-language-models-slp3.md) | `not-an-experiment` |
| Chen & Goodman, KN / modified KN | The actual discount recipe | — | `not-an-experiment` |
| Brants et al., Stupid Backoff | Cheap web-scale backoff when KN is too heavy | — | `parked` |
| Gboard: Applied Federated Learning; federated n-grams; OOV words | More federation. Ignore the upload; keep on-device counting | — | `not-an-experiment` |
| Bengio 2003 neural LM; Mikolov RNNLM | History of why we have a neural global model at all | — | `not-an-experiment` |
| Carlini et al., training-data extraction | Why Tilde must not train on private writing or log completions | — | `not-an-experiment` |

### 6. Engine, latency, mid-text

| Paper | Tilde take | Digest | Run |
| --- | --- | --- | --- |
| [FIM](https://arxiv.org/abs/2207.14255) (Bavarian et al.) | Suffix-aware fill-in-the-middle; no NL FIM GGUF to download (checked 2026-08-15) | [fill-in-the-middle-2022.md](research/fill-in-the-middle-2022.md) | `parked` (H17 / mid-edit) |
| InCoder; CodeLlama FIM; SantaCoder | Code FIM exists; CodeCompose used it to avoid suffix damage | — | `parked` |
| [Speculative decoding](https://arxiv.org/abs/2211.17192) (Leviathan et al.) | Draft-and-verify; helper already can | [speculative-decoding-2022.md](research/speculative-decoding-2022.md) | `local-after-F03` (runtime flag) |
| Prompt-lookup decoding (Saxena; llama.cpp) | Draft by copying n-grams already in the prompt; no second GGUF | [prompt-lookup-decoding-2023.md](research/prompt-lookup-decoding-2023.md) | `local-after-F03` |
| Medusa, EAGLE, Lookahead, Jacobi | Extra heads / trees for speculation | — | `parked` (new model pieces) |
| CALM / early-exit / mixture-of-depths | Spend less compute when sure | — | `parked` |
| [Lost in the Middle](https://arxiv.org/abs/2307.03172) (Liu et al.) | Pack fresh prefix and best scene at the edges; do not just lengthen | [lost-in-the-middle-2023.md](research/lost-in-the-middle-2023.md) | `github-now` synthetic packing tests |
| Holtzman et al., nucleus sampling | Sampler family already in the helper; not a product bet | — | `not-an-experiment` |
| Dettmers, 4-bit / QLoRA | Why Q4_K_M is a reasonable on-device point; not a new bake-off | — | `not-an-experiment` |
| Flash Attention / paged KV / vLLM batching | Multi-tenant serving. Tilde is one user; keep only persistent KV | — | `not-an-experiment` |

### 7. Writing quality and agency

| Paper | Tilde take | Digest | Run |
| --- | --- | --- | --- |
| [Predictive Text Encourages Predictable Writing](https://www.eecs.harvard.edu/~kgajos/papers/2020/arnold20predictive.pdf) (Arnold, Chauncey & Gajos, IUI 2020) | Suggestions shortened captions and removed unpredictable words | [predictive-text-predictable-writing-2020.md](research/predictive-text-predictable-writing-2020.md) | `local-after-F03` (agency beside RNKS) |
| Arnold, Chauncey & Gajos, GI 2018 sentiment study | Biased phrase suggestions moved review sentiment | same digest | `not-an-experiment` |
| Jakesch / AI-mediated communication; Lee et al. [CoAuthor](https://arxiv.org/abs/2201.06796) | Model priors homogenize a corpus; insertion UIs cost ownership | [jakesch-ai-writing-homogenization.md](research/jakesch-ai-writing-homogenization.md) | `parked` (H12); never check in traces |
| Wordcraft; GhostWriter / Buschek DIS 2024 "Collage is the New Writing" | Co-writing tools fragment authorship. Tilde is not that product | — | `not-an-experiment` |
| Smart Compose fairness note | They dropped gendered-pronoun ghosts. Cheap filter, keep it | [smart-compose-2019.md](research/smart-compose-2019.md) | `github-now` (safety fixtures) |

### 8. IME, composition, other input methods

| Paper | Tilde take | Digest | Run |
| --- | --- | --- | --- |
| [Dasher](https://dasher.at/) (MacKay) | Spend a glance only when it buys bits; do not build Dasher | [dasher-mackay.md](research/dasher-mackay.md) | `not-an-experiment` |
| Masui, POBox | Predictive Japanese entry by example; IME-native, not an overlay | — | `not-an-experiment` |
| Ikegami et al., hybrid RNN+n-gram Japanese next-word (2024) | Client/server split for CJK. Tilde stays on-device and English-first | — | `parked` |
| Google Mozc / ATOK / Sogou engineering notes | Conversion IME is a different product than ghost-text Latin IME | — | `not-an-experiment` |
| T9, iTAP, LetterWise, ShapeWriter / SHARK, VelociTap | Ambiguous-key and gesture keyboards. Different cost model | — | `not-an-experiment` |
| Zhai / Android correction-vs-completion Pareto (Google pub 41877) | Correction and completion only mildly trade off on soft keyboards | — | `not-an-experiment` |
| Hunnicutt Predict/Prophet; Newell PAL; Co:Writer; WordQ | AAC product line; same KS-vs-speed lesson as Koester | [aac-word-prediction-koester.md](research/aac-word-prediction-koester.md) | `not-an-experiment` |

### 9. Shipped-system playbooks (code and mail)

| Paper | Tilde take | Digest | Run |
| --- | --- | --- | --- |
| Smart Compose (above) | Closest product in the literature | [smart-compose-2019.md](research/smart-compose-2019.md) | see §1 and §5 |
| Smart Reply (above) | Trigger + diversity, not ghost text | [smart-reply-2016.md](research/smart-reply-2016.md) | see §1 |
| IntelliCode Compose (above) | First whole-line IDE ghost + client trie | [intellicode-compose-2020.md](research/intellicode-compose-2020.md) | see §3 |
| CodeCompose / multi-line (above) | Visual stability and 750 ms display floor | [multiline-code-authoring-2024.md](research/multiline-code-authoring-2024.md) | see §3 |
| Mozannar / Ziegler / Peng / Barke / Vaithilingam / GitHub 2025 | Copilot metric and UX cluster | see §1–§3 | see those rows |
| Liang et al., why developers reject Copilot | Rejection taxonomy (wrong, too long, already knew) | — | `not-an-experiment` |
| Weisz, Sarkar, Prather, other Copilot HCI | More over-reliance and trust calibration | — | `not-an-experiment` |
| TabNine / Kite / CodeWhisperer / Replit Ghostwriter writeups | Same ghost UX, weaker public measurement | — | `not-an-experiment` |
| Superhuman / Shortwave / Spark "AI complete" | Mail vendors; almost no public method | — | `not-an-experiment` |
| TextExpander / aText / Typinator | Exact-phrase expansion is H11, not generation | — | `parked` (H11) |
| Apple QuickType / SwiftKey marketing | No durable public method. Do not cite as evidence | — | `not-an-experiment` |

### 10. Indexed in this sweep, digest later if a campaign needs it

These were opened, cited, or searched so the next pass does not rediscover them.
Add a digest only when a queued experiment actually depends on the details.

- Garay-Vitoria & Abascal, AAC word-prediction survey (2006)
- Horstmann & Levine 1990 AAC user modeling, plus Newell/Arnott/Waller commentary
- Magnússon / Carlberger long-term Prophet use (learning effects over months)
- Trnka & McCoy 2007 topic-adapted prediction
- Wandmacher & Antoine, OOV and prediction
- Li & Hirst 2005 semantic word prediction
- Koester & Levine, scanning systems with/without prediction (Assistive Technology 1994)
- Silfverberg, MacKenzie & Korhonen, phone keypad models
- Arif & Stuerzlinger, cost of error correction (CHI 2010)
- Azenkot & Zhai, posture and soft-keyboard tapping
- Banovic / residual cost of notifications
- Czerwinski, Chrisman & Schumacher, warning before interruption
- Katz 1995, negotiation overhead can exceed the interruption
- Clark 1996, human–human interruption (accept / alter / decline / withdraw)
- Norman, gulfs of execution and evaluation
- Fitts' law (Tab as a target is already cheap; looking is the cost)
- Shannon, prediction and entropy of English
- Cover & Thomas, bits as the deep KS unit
- Brown et al., class-based n-grams
- Rosenfeld, adaptive / maximum-entropy LM
- Jelinek, interpolating language models
- Grave et al. vs. Memory Networks / NTM (why the simple cache won)
- RETRO / retrieval-augmented LMs (cloud-scale; Tilde stays local)
- UL2, T5 span corruption, GLM, CM3 (infill families; no Tilde GGUF)
- StarCoder / SantaCoder FIM ablations
- Prompt cache / radix attention / SGLang (serving, not a single IME)
- Token healing, BPE-boundary partial-word completion
- Apple Private Cloud Compute (opposite of Tilde's on-device rule)
- ScreenAI / Ferret-UI / Set-of-Mark (UI understanding; not an insertion path)
- "Lost in the middle" follow-ups and position-bias mitigations
- Gboard next-word live metrics papers after 2018
- Docs / Slides Smart Compose launch notes (product, thin method)
- Outlook / Microsoft Editor completions (thin method)
- GrammarlyGO / Notion AI (paragraph co-writing; wrong product)
- Cursor Tab / Copilot NES (editor-native; no paper of record yet)
- Peng/Kalliamvakou SPACE survey instrument (appendix of Ziegler)
- Mozannar et al. on time spent evaluating Copilot suggestions
- Tan et al. interviews on trust in intelligent tools
- Lehmann / Buschek later collage-writing papers
- Orthographic / syllable-boundary suggestion use (psycholinguistics; WSTypist cites)
- Japanese/Chinese IME conversion evaluation vs Mozc (elapsed time, not RNKS)

If you find a paper that changes a queued experiment and it is not here, add a
row in the matching section. If it does not change a queued experiment, leave
it in §10.

## Sweep coverage (so the next pass does not start over)

Searched and read in this pass: CHI / TOCHI / PACMHCI word-suggestion and
text-entry; AAC prediction (Koester through Trnka); Gmail Smart Reply and Smart
Compose; Gboard federated and metric vocabulary; Copilot/IntelliCode/CodeCompose
industry papers and blogs; Copilot HCI (Barke, Vaithilingam, Prather, Peng,
Ziegler); interruption science (McFarlane, Horvitz, Fogarty, Iqbal); writing
agency (Arnold, Buschek, Jakesch, CoAuthor); cache and retrieval LMs; FIM and
speculative decoding; long-context position bias; Dasher and IME/CJK prediction;
mobile vs desktop typing corpora (Dhakal, Palin, Feit).

Deliberately out of scope for Tilde campaigns: cloud training recipes, federated
uploads, overlay insertion, Accessibility-as-keyboard, private LoRA, whole-app
agents, and any method that needs raw owner text in Git.

## Contributing an entry

Add a row plus one honest line on what it changes about how we build Tilde.
No copied text, no PDFs. If it unlocks or reshapes a queued experiment, write
a digest in `docs/research/` and link it. If it inspires a campaign, run that
campaign through the quiz or the live harness and record the measured outcome
in `docs/model-lessons.md`. Entries that never produce a testable idea should
be pruned or moved to §10.
