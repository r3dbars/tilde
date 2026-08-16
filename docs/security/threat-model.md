# Tilde Threat Model

Status: current for the simplified IMKit + bundled llama architecture
(2026-08-12), extended (2026-08-16) with the Screen Memory covenant. Screen
Memory itself is planned, not shipped; its entries below describe the model
this document holds it to once built, per `docs/plans/screen-memory.md`.

## System boundary

Tilde has two signed user-facing processes and one signed helper child:

- `InlineGhostIME` receives keystrokes and bounded document context from IMKit,
  renders marked-text suggestions, commits accepted text, and—only when the
  user enables Personal History—buffers bounded history events in memory.
- The Tilde app receives bounded context over an owner-only Unix socket, runs
  its bundled GGUF model, returns suggestions, and exclusively owns the local
  Personal History store and paired personal next-word shadow.
- The bundled `llama-server` helper is a localhost-only child of the Tilde app.

The helper is an app-owned child process bound to localhost. Ordinary request
text and unaccepted model output exist in memory only. If explicitly enabled,
Personal History persists text the user produces as encrypted local events.
Tilde has no Accessibility, Screen Recording, OCR, screenshot capture, cloud
inference, sync, upload, or analytics path.

## Assets to protect

1. Typed context, prompts, model output, accepted text, and the durable Personal
   History corpus and encryption key.
2. Integrity of committed text and the field receiving it.
3. Integrity of the signed input method, helper, and model.
4. Privacy-safe settings and diagnostics stored for the local user.
5. Screen-derived text (OCR output of on-screen content) at rest in the
   Personal History store and in memory during capture, redaction, and scene
   classification, once Screen Memory ships. Unlike asset 1, this text is not
   necessarily the user's own writing — see Screen Memory below.

## Adversaries

- A malicious app or document receiving input.
- Another process running as the same macOS user.
- A local user who can inspect or modify another user's files.
- A network attacker.
- Once Screen Memory ships: local malware running as the user, reading the
  screen-text portion of the Personal History store. Mitigated the same way
  as Personal History today (encryption at rest, owner-only file
  permissions) — this does not raise a new class of adversary, only a richer
  asset for the existing one.
- Once Screen Memory ships: someone physically observing the user's own
  screen while a capture happens (shoulder-surfing). Tilde does not defend
  against this directly; macOS's system-level purple screen-recording
  indicator is the mitigation, by disclosure rather than prevention — it is
  the same honesty signal any other screen-recording app gives, and Screen
  Memory does not attempt to hide or suppress it.

Root, a compromised macOS input subsystem, and an attacker with Tilde's signing
identity are out of scope.

## Controls

- Text stays on-device and is bounded before it crosses the local socket.
- Personal History is off by default. The input method applies the master
  switch, Secure Event Input, valid-app, and app-exclusion policy before
  capture; the app repeats the durable settings checks before persistence.
  The input method performs no disk I/O and keeps only a bounded in-memory
  queue. Only the app writes the history store.
- One process-held lock owns the runtime. The socket directory is mode `0700`,
  the socket is mode `0600`, and both endpoints require the same user, the
  expected signing identifiers, and matching non-empty Team IDs in release
  builds. Completion payloads are not logged or written to disk; explicit
  Personal History payloads are written only to the encrypted history store.
- The input method uses a cancellable two-second request deadline and the wire
  protocol distinguishes suggestions, silence, timeout, invalid input, and
  runtime failure.
- When macOS Secure Event Input is active, the input method clears its fallback
  context and pending history batch, cancels suggestion work, and refuses to
  read, request, display, or capture text.
- Personal History records are independently authenticated and encrypted with
  AES-GCM using a 256-bit, non-synchronizing key in the user's macOS login
  Keychain. Its directory and file are restricted to the owner.
- The paired personal next-word shadow restores bounded aggregate totals, then
  rebuilds both learned recipes without scoring from a bounded recent 4 MiB
  history tail. It processes new allowed events in append order, scores both
  recipes on the same fresh words, censors the tail's first possibly truncated
  token, predicts before learning, ignores accepted model suggestions, and
  deduplicates recent stable event IDs. Neither recipe affects visible
  suggestions. The menu reports if the learned table reaches its fixed memory
  capacity.
- The only persistent shadow state is bounded aggregate lifetime totals and up
  to 64 daily buckets,
  encrypted in the same history-log append as the events it scores. It has no
  words, candidates, contexts, or per-case rows. Its envelope must match the
  local history identifier, durable exclusion generation, and exact exclusion set; malformed, stale, or
  mismatched data fails validation. Disable retains it, while exclusion changes
  logically clear it and deletion removes it.
- Diagnostics pass through a redaction layer and store shape, timing, count,
  app identity, and failure metadata only. Personal History is a separate,
  explicit data path.
- Suggestions are marked text and become committed text only after explicit
  acceptance. There is no clipboard or cross-app synthetic insertion path.
- Distributed builds embed the helper and model inside the signed app. There is
  no runtime model download or remote inference fallback. The release driver
  requires exact input hashes before it copies or signs either asset.
- Before using packaged assets, the app strictly validates its signed bundle
  and nested code. Before every prompt, it rechecks that the localhost listener
  belongs to its exact helper child. Local HTTP requests use an ephemeral
  session with caches, cookies, credentials, and proxies disabled.
- The release driver verifies bundle structure, runtime ownership, signing,
  notarization, Gatekeeper assessment, and observed open sockets.

## Remaining risks

- A macOS input method is highly trusted and can observe typing while active.
  Users must explicitly enable Tilde and can switch input sources or quit it.
- Enabling Personal History creates a durable, highly sensitive writing corpus.
  Encryption at rest does not protect it from local malware running as the
  user, a compromise of Tilde while the key is available, privileged access,
  or plaintext copied elsewhere after decryption. A compromise of the running
  app can expose the decrypted recent replay window and derived personal
  contexts, transitions, aggregate paired outcome counts, and recipe identifiers.
- The encrypted log exposes a plaintext format header, approximate size,
  ciphertext lengths, and record count. Independent per-record authentication
  detects modified ciphertext when that record is replayed; launch replay
  authenticates records in its recent window, while append checks the most
  recent existing record. Older corruption outside the replay window may
  remain undetected. Authentication does not prevent deletion, duplication, or
  reordering of complete encrypted records. A lost local acknowledgement can
  also cause an event retry; readers deduplicate recent stable event IDs.
- The encryption key is not synchronized by Tilde, but the user's login
  Keychain can migrate through a Keychain copy or restore. If ciphertext exists
  without its original key, Tilde refuses replay and append rather than creating
  a replacement key and mixing unreadable and newly encrypted records.
- Deleting Personal History removes its current file and Keychain key but
  cannot promise forensic erasure from backups, snapshots, storage
  wear-leveling, or copies made outside Tilde. Deletion turns capture off and
  rotates a local history identifier so queued pre-deletion events cannot
  recreate the corpus.
- The llama HTTP listener is local-only but is not authenticated. Another
  same-user process can contact it and consume model resources. Tilde checks
  exact listener ownership before each prompt, but a fixed TCP port still has a
  small check-to-request race.
- Debug builds can deliberately lower Unix-socket authentication to same-user
  processes with `TILDE_ALLOW_UNSIGNED_LOCAL_PEER=1`. Release builds do not
  honor that escape hatch.
- Secure Event Input is the only field-sensitivity signal available through
  this IMKit design. A custom secret field that does not enable the macOS signal
  is indistinguishable from an ordinary field.
- IMKit exposes no stable field identifier. Tilde separates history on known
  app, caret, edit, and composition changes, but two fields in one app at the
  same caret can share one shadow context if no composition callback is
  delivered.
- Host apps control marked-text behavior and key routing. Compatibility must be
  proven per editor; wrong or duplicate commits are release-blocking bugs.
- `llama-server`, the model parser, IMKit, and macOS remain complex trusted
  components. Signed packaging reduces tampering risk but cannot remove bugs in
  those components.

## Screen Memory (planned)

Not yet implemented; this section states the controls and residual risks this
document will hold the feature to once it ships, per
`docs/plans/screen-memory.md`. It supersedes the prior blanket OCR/Screen
Recording ban recorded in `AGENTS.md`.

Controls, once shipped:

- Redaction runs before any persistence and fails closed: a structured-secret
  rules pass, then a local span-detection model pass, must both complete
  before redacted text is written; a redactor error drops the capture
  instead of storing it raw.
- Capture is suspended unconditionally under the same conditions Personal
  History already enforces — master toggle off (default), macOS Secure Event
  Input active, or frontmost app on the shared exclusion list — plus a
  locked screen and a hard capture-rate cap.
- Screen-derived text is stored in the same encrypted, owner-only Personal
  History file, under the same Keychain key, subject to its own rolling
  retention budget (256 MB default, oldest-first pruning), and is removed by
  the same delete-all action that destroys the encryption key.
- Screen-derived text never trains the table that models the user's own
  writing; it feeds a separate, bounded conversation-context table only.

Residual risks, stated honestly:

- **Screen Memory will capture other people's words, not just the user's.**
  Anything visible on screen when a capture fires — the other side of a
  chat, a document someone else wrote, an email in the reading pane — is
  captured and OCR'd identically to the user's own text. Tilde cannot
  distinguish authorship from screen geometry alone. Per-app exclusion is
  the only control; there is no per-person or per-message control.
- **Redaction is not 100% recall.** The rules layer targets ≥99% recall on
  structured secrets (card numbers, API-key shapes, JWTs); the model layer
  targets ≥90% recall on unstructured secrets (free-text passwords, informal
  PII). Both bars, and both misses, are measured per release the same way
  the golden eval is, but neither is a guarantee that no secret ever
  persists.
- **OCR quality varies.** Low-contrast text, small retina-scaled text, and
  unusual fonts degrade recognition; degraded OCR mostly fails the scene
  classifier silently rather than corrupting a suggestion, but it also means
  redaction is operating on text Tilde read imperfectly.
- **The purple indicator is disclosure, not consent enforcement.** macOS
  shows a system-level indicator whenever screen recording is active, the
  same as any other screen-recording app. Tilde does not add a stronger
  signal, and a user who does not notice or understand the indicator is not
  separately warned by Tilde.
- **A compromise of the running app while Screen Memory is enabled** exposes
  the same class of decrypted-recent-window and derived-context risk this
  document already states for Personal History, extended to screen-derived
  conversation context.
- **Best-effort private-browsing exclusion is not a guarantee.** Tilde
  attempts to detect and skip known browsers' private/incognito windows by
  window metadata; this is heuristic, not guaranteed across all browsers or
  browser versions, and a user who needs certainty should add the browser to
  the app exclusion list instead.

## Required proof after security-sensitive changes

Run `./script/proof.sh fast` for every change. Before release, run
`./script/package_app.sh` with reviewed helper and model hashes, and require all
bundle, runtime, signing, notarization, Gatekeeper, and socket-observation lanes
to pass. File-shape checks and matching hashes do not prove provenance; the
operator must review the source of both inputs. The egress lane sends a fixed
synthetic prompt directly to the helper;
its isolated proof mode observes only the exact app and helper on a dedicated
port. It may append privacy-safe diagnostics, but it does not quit or change the
daily driver or input method. It is open-socket observation, not packet capture,
input-method execution, Unix-socket authentication proof, or a real-editor
round trip. Model or helper changes also require a freshly installed, notarized
build and manual IME checks—including secure text fields—in disposable
documents.

Personal History changes additionally require tests for disabled capture,
excluded apps, secure-input policy, bounded event decoding, encrypted
round-trips, corrupt-store failure, deletion, prediction-before-learning,
duplicate delivery, edit-boundary isolation, aggregate-checkpoint corruption,
restart restoration, replay/live overlap, stale checkpoint rejection, and the
retention and clearing lifecycle. Manual installed-IME proof
must confirm that secure password fields add no records, ordinary fields add
records only after explicit opt-in, exclusions work in real host apps, and the
menu accurately reports size, paired-test progress, shadow-only status, memory
capacity, and deletion. Those manual checks are not proven by the deterministic
test suite.
