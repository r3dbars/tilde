# N-gram Language Models — Speech and Language Processing, 3rd ed. draft, Ch. 3 (Jurafsky & Martin, 2026)

**Source:** https://web.stanford.edu/~jurafsky/slp3/3.pdf (chapter also linked from https://web.stanford.edu/~jurafsky/slp3/)
**License:** "Copyright © 2026. All rights reserved." (stated on the PDF's first page) — this is a copyrighted textbook draft, not openly licensed; treat as link-and-cite only, no redistribution of text.

## What it does (plain words)

This chapter teaches the oldest trick for guessing the next word in a sentence: count how often word B follows word A (or a short chain of words) in a pile of text, turn those counts into probabilities, and predict what comes next — betting on what usually happened before, rather than a neural network's learned abstract patterns. It walks through a toy restaurant-queries dataset (9,332 sentences, vocabulary 1,446) to show exactly how counts turn into probabilities, introduces perplexity as the standard yardstick for how good a language model is, shows how to generate ("sample") text from one, and spends real time on the central weakness: most word combinations you'll ever need were never seen during training, so raw counting alone leaves a model riddled with zero-probability holes. The back half is a tour of "smoothing" techniques that patch those holes.

## Method (the mechanism, in my own words)

Start from the chain rule: a sentence's probability is the product of each word's probability given everything before it. No corpus is big enough to have seen every full history, so the Markov assumption truncates context to the last n-1 words — bigram looks one word back, trigram two. Under that truncation, probability becomes relative frequency: count(context, word) / count(context), i.e. maximum likelihood estimation. On the toy corpus, P(want|to) = 608/2417 ≈ 0.66, and chaining bigram probabilities gives a full-sentence probability like 0.000031 for "I want english food."

Two fixes follow. Multiplying many sub-1 probabilities underflows, so everything is stored and computed as log probabilities and summed. More importantly, any n-gram absent from training gets probability zero, which both under-estimates real language and makes perplexity undefined. The remedies are smoothing (Laplace/add-one: add 1 to every count and renormalize; the more tunable add-k) and reweighting across n-gram orders — linear interpolation (blend unigram/bigram/trigram estimates with weights λ summing to 1, optionally learned per-context from held-out data via EM) and backoff (drop to a lower order only when the higher order has zero count). "Stupid backoff" (Brants et al., 2007) is flagged as the pragmatic choice at huge, low-latency scale: no real discounting, just a fixed λ=0.4 penalty on backoff.

Evaluation is intrinsic (perplexity: inverse test-set probability, normalized per word, lower is better) versus extrinsic (plugging the LM into a real task and measuring that task's own metric). The chapter states plainly that a perplexity win doesn't guarantee a downstream win.

## Key findings (with the actual numbers)

- Toy Berkeley Restaurant Project corpus: 9,332 sentences, vocabulary V=1,446; example bigram probabilities include P(want|to)=0.66, P(food|english)=0.5, P(i|<s>)=0.25 — full-sentence probability for "I want English food" comes out to 0.000031.
- WSJ experiment: unigram/bigram/trigram models trained on 38 million words, tested on 1.5 million words. Perplexity: unigram 962, bigram 170, trigram 109 — perplexity drops sharply as context grows.
- Shakespeare corpus for text generation: N=884,647 tokens, V=29,066 word types, so possible bigrams number V²=844,000,000 and possible 4-grams V⁴=7×10¹⁷ — a corpus nowhere near large enough to fill that space, illustrating how sparse high-order n-grams are.
- Generated text quality rises with n: unigram output has no coherence, bigram has local word-pair coherence, and 4-gram output on Shakespeare starts reproducing exact source phrases (e.g. "It cannot be but so," straight out of King John) because so few continuations remain possible.
- A model trained on Shakespeare tested against WSJ-style text (or vice versa) shows almost no usable overlap — n-gram models generalize only within their training genre/register.
- Stupid backoff's fixed discount λ=0.4 is cited as empirically effective at Google web-text scale.

## What Tilde should take from it

Tilde's on-device n-gram next-word model is the MLE-plus-smoothing machinery this chapter walks through, but at a much smaller, more idiosyncratic scale — one user's typing history is closer in size to the 9,332-sentence toy corpus than to WSJ's 38M words, and far more skewed toward that person's own vocabulary. Three takeaways:

1. **Don't ship raw MLE or even Laplace.** The chapter itself calls add-one smoothing too crude for real n-gram LMs — a teaching baseline only. On a personal corpus this small, nearly everything a user hasn't already typed is a zero count; interpolation or backoff against the bundled base model's broader distribution is the realistic design, not naive counting.
2. **Perplexity is the wrong headline metric for Tilde, and the chapter agrees.** Its own caveat — that an intrinsic perplexity win doesn't guarantee an extrinsic win — backs Tilde's existing choice to eval on EM@1, keystrokes-saved, and latency via the deterministic continuation quiz, rather than tuning the n-gram layer against perplexity alone.
3. **Stupid backoff fits the "awaiting promotion into serving" personalization model.** It skips learned discount parameters and just falls back to the base 2B model's distribution when the personal n-gram has no count — cheap, latency-friendly, and Brants et al.'s λ=0.4 is a sane starting point before spending effort on EM-tuned interpolation weights. Given Tilde's rule that suggestions must help more than they interrupt, backing off gracefully on unseen contexts (rather than force-feeding a low-confidence personal-corpus guess) guards against the exact overconfidence failure the Shakespeare/WSJ mismatch illustrates: a model trained on a narrow style is a bad predictor once context drifts outside that style.

## Limits and caveats (what does not transfer)

The chapter's numbers all come from clean, large, single-genre corpora (WSJ, Shakespeare, a scripted restaurant-dialogue set) — none of that maps onto one person's noisy, code-mixed, multi-register typing (emails, code, chat) that Tilde personalizes on. Its own generalization example (Shakespeare vs. WSJ barely overlapping) argues against a held-out corpus's λ-tuning transferring cleanly to a live session; Tilde would need per-user or online tuning, uncovered here. It also assumes subword (BPE) tokenization solves out-of-vocabulary cleanly, but says nothing about a hybrid setting like Tilde's, where a small personal n-gram layer sits beside a much larger neural base model with its own tokenizer — this chapter's smoothing math blends orders within one model, not across two models of different capacity. Finally, this is pedagogy, not a deployed-system report: no latency, memory, or serving-cost data, which are the concerns that actually gate whether Tilde's n-gram layer ships.
