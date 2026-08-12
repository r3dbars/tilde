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
  analytics, or training. Never print personal writing data in logs or scripts.
- The product is the input method. Render with IMKit marked text in the focused
  app; do not add an Accessibility/overlay insertion path.
- Inference is app-owned and bundled. Users must not install Ollama, llama.cpp,
  Python, or a separate model server.
- Do not add OCR, Screen Recording, screenshots, cloud sync, accept sounds, or
  hidden telemetry. Personal History must remain explicit, local, and
  user-controlled.
- Show app, helper, and model status in the menu, and record input-method and
  runtime failures in privacy-safe diagnostics.

## Architecture

- `Sources/AutocompleteLabCore` is pure deterministic Swift. Suggestion
  decisions belong here with focused tests. It has no AppKit, IMKit, process,
  socket, or file-system work.
- `Sources/InlineGhostIME` owns keystrokes, bounded document context, marked
  text, and acceptance. Keep it responsive and thin.
- `Sources/AutocompleteLabApp` owns the local Unix socket, bundled llama helper
  and model lifecycle, input-method installation, menu, and redacted
  diagnostics. It is the only owner of persistent Personal History; ordinary
  completion requests and unaccepted model responses remain memory-only.
- Prefer deleting or merging policy over adding another gate. Independent
  thresholds compound into a silent product.
- Add or update tests with every behavior change.

## Proof

- Pre-merge: `./script/proof.sh fast`
- Structural change:
  `PROOF_STRUCTURAL_CHANGE=1 PROOF_DIFF_BASE=origin/main ./script/proof.sh fast`
- Release, on macOS: `./script/package_app.sh` with the pinned inputs shown by
  `./script/package_app.sh --help`

The release driver's bundle, embedded model, runtime, signing, notarization,
Gatekeeper, and open-socket observation lanes are blocking. Open-socket
observation is not packet capture. Keep deterministic proof separate from
manual editor compatibility proof.

Do not add a script without a real caller or a document without a durable
reader. Root `AGENTS.md` and `CLAUDE.md` are the only agent guides.
