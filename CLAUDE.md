# Claude Code

Read [AGENTS.md](AGENTS.md). It is the single source of truth for Tilde's
product rules, architecture, and proof commands. The release app contains the
signed helper and input method but no GGUF; first-run asset setup downloads only
the pinned Gemma 4 E2B file into external app-owned storage. Release proof uses
an explicitly named `--proof-model` preseed and keeps the post-download runtime
egress check loopback-only.

For Tilde Lab or autocomplete research work, also read
[the staged research roadmap](docs/research-roadmap.md),
[the Learning Ledger contract](docs/learning-ledger.md), and
[the experiment record template](docs/experiments/README.md). The bundled
Learning Ledger JSON is authoritative for the active stage and ordered work
queue. Run one causal experiment at a time, use the exact same test for control
and treatment, do not start locked stages early, and capture every reusable
supported, rejected, or inconclusive result without checking in private text or
raw model output.

Decision-grade comparisons require clean, complete v6 reports with a
registered hypothesis and an explicit supported/rejected/inconclusive review.
Legacy, dirty, incomplete, unregistered, and unreviewed reports stay readable
but must never advance a protected phase.
