# Tilde Threat Model

Status: current for the simplified IMKit + bundled llama architecture
(2026-08-11).

## System boundary

Tilde has two signed user-facing processes and one signed helper child:

- `InlineGhostIME` receives keystrokes and bounded document context from IMKit,
  renders marked-text suggestions, and commits accepted text.
- The Tilde app receives bounded context over an owner-only Unix socket, runs
  its bundled GGUF model, and returns a suggestion.
- The bundled `llama-server` helper is a localhost-only child of the Tilde app.

The helper is an app-owned child process bound to localhost. Request text and
model output exist in memory only. Tilde has no Accessibility, Screen Recording,
OCR, screenshot capture, raw trace, writing-history, learning, cloud inference,
or analytics path.

## Assets to protect

1. Typed context, prompts, model output, and accepted text.
2. Integrity of committed text and the field receiving it.
3. Integrity of the signed input method, helper, and model.
4. Privacy-safe settings and diagnostics stored for the local user.

## Adversaries

- A malicious app or document receiving input.
- Another process running as the same macOS user.
- A local user who can inspect or modify another user's files.
- A network attacker.

Root, a compromised macOS input subsystem, and an attacker with Tilde's signing
identity are out of scope.

## Controls

- Text stays on-device and is bounded before it crosses the local socket.
- The socket and its directory are owner-only. Payload text is not logged or
  written to disk.
- Diagnostics pass through a redaction layer and store shape, timing, count,
  app identity, and failure metadata only.
- Suggestions are marked text and become committed text only after explicit
  acceptance. There is no clipboard or cross-app synthetic insertion path.
- Distributed builds embed the helper and model inside the signed app. There is
  no runtime model download or remote inference fallback. The release driver
  requires exact input hashes before it copies or signs either asset.
- The release driver verifies bundle structure, runtime ownership, signing,
  notarization, Gatekeeper assessment, and observed open sockets.

## Remaining risks

- A macOS input method is highly trusted and can observe typing while active.
  Users must explicitly enable Tilde and can switch input sources or quit it.
- Owner-only permissions isolate other accounts, not hostile processes already
  running as the same user. The Unix socket has no independent peer identity
  check.
- The llama HTTP listener is local-only, but another same-user process may race
  for or contact its fixed localhost port. Tilde fails closed when a foreign
  process owns the port.
- Host apps control marked-text behavior and key routing. Compatibility must be
  proven per editor; wrong or duplicate commits are release-blocking bugs.
- `llama-server`, the model parser, IMKit, and macOS remain complex trusted
  components. Signed packaging reduces tampering risk but cannot remove bugs in
  those components.

## Required proof after security-sensitive changes

Run `./script/proof.sh fast` for every change. Before release, run
`./script/package_app.sh` with reviewed helper and model hashes, and require all
bundle, runtime, signing, notarization, Gatekeeper, and socket-observation lanes
to pass. Socket observation is not packet capture. Model or helper changes also
require a freshly installed, notarized build and manual IME checks in disposable
documents.
