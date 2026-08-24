# Tilde Agent Guide

Tilde is an open-source macOS input method for quiet, local autocomplete. The
owner daily-drives it. Every change should make suggestions faster, more useful,
safer, or simpler.

## Product rules

- Suggestions must help more than they interrupt. Silence and noise are both
  failures.
- Privacy is a hard requirement. Tilde may retain writing locally when it
  provides direct user benefit. Personal writing data remains on the user's
  device, is controlled by the user, and is never transmitted for inference,
  analytics, or training. The only setup-time network request is the fixed,
  immutable Gemma 4 E2B model asset; it carries no user-derived request data.
  Never print personal writing data in logs or scripts.
- The product is the input method. Render with IMKit marked text in the focused
  app; do not add an Accessibility/overlay insertion path. Reading screen
  text through the Accessibility API is permitted under the same Screen
  Memory covenant and gates as OCR — it is a faster, exact source of the
  same on-device, memory-only data, never an insertion mechanism.
- Inference is app-owned. The signed `llama-server` helper remains inside the
  app, while the pinned Gemma 4 E2B GGUF is downloaded once into external,
  app-owned storage and verified before use. Users must not install Ollama,
  llama.cpp, Python, or a separate model server.
- Screen Memory covenant (supersedes the old blanket OCR/Screen Recording
  ban; 2026-08-16 owner directive made Screen Memory required, not opt-in):
  Tilde may capture on-device screen text under these non-negotiables —
  on-device only, no cloud, and no user-derived network egress; the only
  permitted network phase is the fixed model-asset download. The release
  egress proof runs a packaged capture/redaction stimulus inside the
  observed release-proof process — a synthetic conversation is classified,
  carried into the scene-bearing prompt, completed over loopback, and
  redaction must redact or fail closed — so the gate actually exercises
  Screen Memory's code paths;
  redaction runs before persistence and fails closed, so a redactor error
  drops the capture rather than storing it raw; capture is excluded whenever
  macOS Secure Event Input is active, or any visible window — not just the
  frontmost one, since capture is full-display — belongs to an app on the
  exclusion list (shared with Personal History); no raw screen text may
  appear in logs, diagnostics, or any report; and owner-visible controls are
  mandatory — a master toggle (ON by default for new installs; an existing
  install's explicit choice persists), per-app exclusions, a visible storage
  meter, and one-click delete-everything. Screen Recording permission is
  required for Tilde to suggest at all: while the toggle is off or the OS
  permission is missing, Tilde answers every completion request with
  silence instead of a suggestion — a deliberate all-or-nothing product
  decision, not a bug — and the menu bar carries a persistent, honest status
  line with a one-click path to grant access or open System Settings, plus a
  first-launch explanation dialog offering the same two actions. Do not add
  cloud sync, accept sounds, or hidden telemetry. Personal History and
  Screen Memory must both remain explicit, local, and user-controlled.
- Show app, helper, and model status in the menu, and record input-method and
  runtime failures in privacy-safe diagnostics.

The only production model is Gemma 4 E2B Q4_K_M: revision
`3762686d74ff8db6c98f8d3c389f56fbdf994d5a`, file
`gemma-4-E2B.Q4_K_M.gguf`, exactly `3427861984` bytes, SHA-256
`389c868898bffed97fd178646f88562cafecc6f60983a636bac53b131fd068a2`. The
first-run asset phase may request only the matching immutable Hugging Face
resolve URL; it must never include user text or screen content.

## Architecture

- `Sources/AutocompleteLabCore` is pure deterministic Swift. Suggestion
  decisions belong here with focused tests. It has no AppKit, IMKit, process,
  socket, or file-system work.
- `Sources/InlineGhostIME` owns keystrokes, bounded document context, marked
  text, and acceptance. Keep it responsive and thin.
- `Sources/AutocompleteLabApp` owns the local Unix socket, signed llama helper,
  external model download/verification/lifecycle, input-method installation,
  menu, and redacted diagnostics. It is the only owner of persistent Personal
  History; ordinary completion requests and unaccepted model responses remain
  memory-only.
- Prefer deleting or merging policy over adding another gate. Independent
  thresholds compound into a silent product.
- Add or update tests with every behavior change.

## Proof

- Pre-merge: `./script/proof.sh fast`
- Structural change:
  `PROOF_STRUCTURAL_CHANGE=1 PROOF_DIFF_BASE=origin/main ./script/proof.sh fast`
- Release, on macOS: `./script/package_app.sh` with the pinned inputs shown by
  `./script/package_app.sh --help`

The release driver's no-embedded-GGUF bundle check, helper/IME signatures,
external proof-model preseed, runtime, signing, notarization, Gatekeeper, and
post-download open-socket observation lanes are blocking. The model download is
a separate first-run phase restricted to the one immutable Hugging Face URL and
does not carry user-derived data. Open-socket observation is not packet capture.
Keep deterministic proof separate from manual editor compatibility proof.

Do not add a script without a real caller or a document without a durable
reader. Root `AGENTS.md` and `CLAUDE.md` are the only agent guides.
