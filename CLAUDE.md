# Claude Code

Read [AGENTS.md](AGENTS.md). It is the single source of truth for Tilde's
product rules, architecture, and proof commands. The release app contains the
signed helper and input method but no GGUF; first-run asset setup downloads only
the pinned Gemma 4 E2B file into external app-owned storage. Release proof uses
an explicitly named `--proof-model` preseed and keeps the post-download runtime
egress check loopback-only.
