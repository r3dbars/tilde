# Mid-word grammar: the biggest single win so far (2026-08-01)

Idea borrowed from KeyType (the 437-star open-source Cotypist clone): when
the writer is mid-word ("tomo|"), constrain generation so the output MUST
legally finish that word. llama.cpp GBNF grammars, applied per-request.

## The discovery

The frozen exams all cut at word boundaries — real typing mostly pauses
mid-word. A mid-word rebuild of the frozen texting exam (same split, same
scorer, n=500) found the model emits a **leading space on 96.6%** of
mid-word requests: it was fine-tuned only on word-boundary continuations,
so a partial word reads as a finished one. Mid-word suggestions were
essentially all format-broken at the source, hidden downstream by the
cleaner's client-side patches (prefix trimming, first-word truncation).

## Raw numbers (midword_quiz.py, n=500, private 17999)

| arm | word1 | first2 | similar★ | meaning |
|---|---|---|---|---|
| baseline (unconstrained) | 0.012 | 0.002 | 0.030 | 0.192 |
| bouncer (filter only) | 0.012 | 0.002 | 0.006 | 0.312 |
| grammar (letters) | 0.416 | 0.112 | 0.114 | 0.286 |
| **trie (dict + lexicon)** | **0.460** | **0.120** | **0.134** | 0.297 |

word-1 mid-word: **1.2% → 46.0%** (38x). Filtering is useless (bouncer just
goes silent 96% of the time) — the constraint must REDIRECT generation, not
censor it. With 2–3 letters typed, the model can finish the word nearly
half the time. Mid-word word-1 (46%) now beats boundary word-1 (25.6%):
the prefix is information, and the grammar finally lets the model use it.

## Shipped

- `MidwordGrammar` + `WordVocabulary` (AutocompleteLabCore): prefix
  extraction (ASCII-only guard), letters grammar, trie grammar capped at
  300 alternatives, binary-search vocabulary. 9 new tests; suite at 100.
- `LlamaCompletionEngine`: attaches the grammar when mode == wordCompletion.
  Kill switch STEADYTYPE_MIDWORD_GRAMMAR=0. Instruct mode exempt.
- Personal lexicon (`lexicon_harvest.py`): 1,106 words (317 mid-sentence
  capitalized names + 789 out-of-dictionary slang) from the 30,837-message
  train pool — exam slice excluded so the trie can never know an exam
  answer. Installed to Application Support; system dictionary alone is the
  fallback. Nightly regeneration is a follow-up.

## Also closed: the app-tag knob

"App: Messages" line in the prompt, frozen texting exam, n=500,
pre-registered neutral (register gating already falsified 2026-07-30):
word1 0.254 vs 0.254, similar★ 0.074 vs 0.078. Inside noise; below the
+0.8 accept bar. Not shipped. (appknob_quiz.py)

## Caveats

- The mid-word exam inherits the frozen split but is a NEW paper — its
  numbers are not comparable to the boundary exam's, only across its own
  arms.
- Grammar arms re-generate (same seed/temp); bouncer reuses baseline
  generations, so its comparison is exact.
- Live proof pending: deploy (script/tilde_deploy.sh) + a real typing week
  decide whether exam gains survive contact with the owner's fingers.
