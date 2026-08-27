# The road to better completions: GitHub Copilot's accepted-and-retained metric (GitHub, 2025)

**Source:** https://github.blog/ai-and-ml/github-copilot/the-road-to-better-completions-building-a-faster-smarter-github-copilot-with-a-new-custom-model/
**License:** GitHub Blog; use as a public engineering report, not as a paper to quote at length.

## What it does (plain words)

GitHub published how they improved Copilot's inline completions. The useful part for Tilde is not their model. It is the metric change. They originally optimized acceptance rate, noticed that this rewarded short easy suggestions that people Tabbed and then deleted, and switched the headline to *accepted and retained characters*: text the developer accepted and still kept. They report 20% more retained characters, 12% higher acceptance, 3× throughput, and 35% lower latency for the new completions model. They ship only when those live numbers move together.

## Method

Three evaluation layers, in order:

1. Offline: execution tests (does the completed code build and pass?) plus an independent judge for quality, relevance, and helpfulness.
2. Internal dogfood and language-expert review for taste and trust.
3. Production A/B tests on real developer traffic, using retained characters, acceptance, show rate, time-to-first-token, and latency.

Training used mid-training on modern code, fill-in-the-middle fine-tuning so the model inserts instead of rewriting the suffix, and reinforcement learning for quality/relevance/helpfulness. Early RL reward-hacked into longer, comment-heavy completions; they added penalties for that.

## Key findings

- Acceptance rate alone selected short, high-volume suggestions that did not stay in the file.
- Retained characters became the product headline. Acceptance stayed a supporting metric.
- They refuse to ship a latency or acceptance win that fails retained characters, and the reverse.
- Reward functions that ignore brevity produce bloat. Guard the objective or the model will pad.

## What Tilde should take from it

This is the public existence proof for Tilde's RNKS plan. Copilot learned the same lesson Tilde's ledger already recorded: Tab is not ground truth. Tilde's version has to be stricter because writing is local and text-free:

- keep 5-second, 30-second, and segment-close retained characters;
- never let acceptance be the promotion target;
- do not start a learned gate until those horizons exist (F03);
- treat "useful but later deleted" as a loss, not a win.

Their evaluation stack also matches Tilde's promotion path: offline quiz, then dogfood, then live A/B, with hard gates that cannot be averaged away. Copy the *order*, not the cloud training loop. Tilde must not train on private writing or send user text anywhere.

The FIM warning matters for later editing work (H17), not for current ghost-text: a model that overwrites the suffix is an interaction failure. Tilde already treats suffix damage as a hard gate.

## Limits and caveats

This is a vendor blog about a hosted code model trained on millions of repositories. None of the training story is available to Tilde, and none of it is allowed under Tilde's privacy rules. The 20% retained-character lift is Copilot's own production A/B, not a number Tilde can expect from a three-word cap or a Qwen preview. Code retention (still in the file at some unspecified horizon) is not the same as Tilde's 5s/30s/segment writing retention. Use it as a metric lesson, not as a quality bar or a training recipe.
