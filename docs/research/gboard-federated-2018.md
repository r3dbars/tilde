# Federated Learning for Mobile Keyboard Prediction (Hard, Rao, Mathews, Ramaswamy, Beaufays, Augenstein, Eichner, Kiddon, Ramage; 2018)

**Source:** https://arxiv.org/abs/1811.03604
**License:** Creative Commons Attribution-NonCommercial-ShareAlike 4.0 (CC BY-NC-SA 4.0), as posted on arXiv

## What it does (plain words)

This is the Google Gboard team's paper on training the phone keyboard's next-word predictor without ever pulling raw typing data off the phone. Instead of collecting what people type into a central server, each phone trains a small copy of the model on its own local typing history overnight while charging and on WiFi, then sends up only the updated model weights. Google's server averages thousands of these weight updates together into one improved shared model, which is then pushed back down to every phone. Over 3,000 rounds of this cycle, involving 1.5 million phones, the resulting model beat the old model trained the normal way (collecting logged sentences on a server and doing regular gradient descent). It's essentially proof that you can get a better keyboard predictor by learning from data that literally never leaves the device.

## Method (the mechanism)

The predictor is a single-layer CIFG LSTM (a coupled input-forget-gate LSTM variant, which trims about 25% of the parameters of a standard LSTM by tying the input and forget gates together) with 670 hidden units, a 96-dimensional embedding, and a 10,000-word vocabulary, tying the input embedding and output projection matrices to save weight. Total size: 1.4M parameters, quantized down to a 1.4MB on-device model.

Training uses FederatedAveraging: on each round, the server selects 100-500 eligible clients (phone must be charging, idle, on an unmetered network, have ≥2GB free memory, US-English North America user), sends them the current global weights, each phone runs a few local SGD steps over its own cached typing sentences (batches of ~400 sentences), and uploads only the resulting weight delta — never the raw text. The server does a weighted average of the deltas and applies it with a server-side learning rate of 1.0 using Nesterov momentum (0.9). This repeats for 3,000 rounds over 4-5 days, touching 600M sentences across 1.5M unique clients. The server-trained baseline instead trained on 7.5 billion logged, anonymized sentences over 150 million ordinary SGD steps. No differential privacy or secure aggregation was used — privacy came from data minimization plus averaging across many clients, with DP/secure-agg flagged as future work.

## Key findings

- Server-side eval logs (Table 3): n-gram baseline 13.0% top-1 / 22.1% top-3 recall; server CIFG 16.5% / 27.1%; federated CIFG 16.4% / 27.0% — roughly a wash here.
- Held-out client-cache data (Table 4), closer to real usage: n-gram 12.5±0.2% top-1; server CIFG 15.0±0.5%; federated CIFG 15.8±0.3% — a 0.8-point absolute / ~5% relative top-1 gain for federated.
- Live production A/B test (Table 5): federated CIFG 5.82±0.03% impression top-1 / 13.75±0.03% top-3, vs. server CIFG 5.76±0.03%/13.63±0.04%, vs. n-gram 5.24±0.02%/11.05±0.03% — ~1% relative live-traffic win for federated over server-trained.
- Click-through rate (Table 6): federated CIFG 2.35±0.03% CTR vs. n-gram 2.13±0.03% — ~10% relative CTR lift.
- Federated (on-device) data composition differed from server logs: 66% chat / 16% social / 5% web / 12% other, vs. 60% chat / 35% web-input / 5% long-form on the server side — authors describe on-device data as untruncated, more representative, and higher quality.
- Deployed footprint: 1.4M parameters, 1.4MB quantized.

## What Tilde should take from it

This is the strongest existing evidence that on-device, never-uploaded personalization data beats server-collected data for a keyboard predictor — directly relevant to Tilde's bet on its local n-gram next-word model. Three concrete takeaways:

1. **The load-bearing insight is "better local data," not federation itself.** Tilde doesn't have millions of devices to average across — it has one user's device. But the paper's finding that on-device caches are richer than any centrally logged corpus (untruncated, non-sandboxed apps, closer to real usage) is the same argument for promoting Tilde's local n-gram model into serving: the personal on-device signal should beat generic base-model priors on the user's own text, no federation machinery needed.

2. **Recall gains on a generic eval log understate the real-world win.** The federated model looked flat vs. server-trained on the server-log eval (16.4% vs 16.5%) but won clearly on client-cache data (15.8% vs 15.0%) and live traffic (+CTR). Tilde's own EM@1 / keystrokes-saved quiz should be read the same way — a personalization signal that looks flat on a generic continuation quiz may still move the needle in the live app; production behavior (or a live-traffic proxy) is the tiebreaker, not the offline benchmark.

3. **A tiny 1.4MB, 1.4M-parameter model was enough** to beat both an n-gram baseline and a model trained on 7.5B server sentences. That's a data point for Tilde's "n-gram model awaiting promotion" decision: meaningful personalization lift doesn't require scale — a small model trained purely on local signal can outperform a much bigger model trained on generic data, which argues for shipping the n-gram promotion sooner rather than waiting on a larger personalization model.

## Limits and caveats

- **No true federation applies to Tilde.** FederatedAveraging across 100-500 devices/round and 1.5M clients has no analog for a single-user local app. Tilde can borrow "train on local cache, never upload raw text" but not the averaging mechanism itself.
- **Not apples-to-apples per the authors**: server and federated arms used different optimizers (plain SGD vs. federated SGD + server-side Nesterov momentum), so part of the measured gap may be optimizer choice, not data source — don't over-read the magnitude.
- **No DP/secure aggregation despite the privacy framing** — the privacy claim rests on "raw text never leaves the device" plus cross-client aggregation, a weaker guarantee than Tilde's single-device, no-server-round-trip design already provides. Not a privacy proof point to cite beyond "don't upload raw text."
- **Infra and scale assumptions don't transfer** — 1.5M clients, dedicated FL infrastructure, idle/charging/unmetered eligibility gating are all irrelevant to a solo macOS input method.
- **Metric mismatch** — headline metrics are word-level top-1/top-3 recall and chip CTR inside Gboard's UI, not Tilde's EM@1, keystrokes-saved, or "help more than interrupt" friction constraint; numbers are directionally useful, not directly comparable.

File written to `/private/tmp/claude-501/-Users-redbars-Steadytype--claude-worktrees-musing-poitras-f871d3/84c04d6c-b013-4ad4-aa07-1c8390cf1f60/scratchpad/fed_keyboard_digest.md`.
