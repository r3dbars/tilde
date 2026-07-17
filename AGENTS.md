# SteadyType Agent Guide

Open-source macOS autocomplete app; the owner daily-drives it. The bar for
every change: does it make the app feel faster, more accurate, or simpler? If
a change adds process instead of product, don't.

## Product stance

- The test is simple: does inline help make writing feel easier, or does it get
  annoying? A suggestion that never appears fails that test just as hard as an
  annoying one.
- Privacy is a hard requirement. Never store or transmit raw typed text,
  prompts, model output, accepted text, or screenshots unless the user
  explicitly opts in. Never print them in scripts or logs.
- Keep the model runtime app-owned. Users must never need Ollama, llama.cpp,
  Python, or any separate server. Mock engines are for dev/tests only.
- Fail loudly, not silently. If the app can't suggest (no permission, no model,
  broken field), the user should be able to see why.

## Architecture rules

- `Sources/AutocompleteLabCore` — pure, deterministic Swift. All autocomplete
  *decisions* live here as small policy types with focused tests. No AppKit,
  Accessibility, MLX, or process management.
- `Sources/AutocompleteLabApp` — the native shell: Accessibility, event taps,
  insertion, overlay UI, MLX runtime. As little decision logic as possible.
  `AppDelegate.swift` is oversized and being decomposed — shrink it, never
  grow it.
- Prefer deleting or merging policies over adding new ones. Before adding a
  gate/suppressor/cooldown, check whether an existing one already covers it —
  compounding independent thresholds is how this app once became silent.
- Add or update tests with each behavior change.

## Keeping main green

- Pre-merge gate: `./script/proof.sh fast` — whitespace, python byte-compile,
  harness self-tests, core `swift test`. CI runs exactly this
  (`.github/workflows/fast-proof.yml`); enable locally on push with
  `git config core.hookspath .githooks`.
- Release gate (macOS, manual): `./script/release_check.sh` — bundle checks,
  model asset, and the live network-egress privacy proof. All lanes blocking.
- No new scripts without a consumer; no docs nothing reads; no per-folder
  guide files (this file and CLAUDE.md at the root are the only two).
