# Tilde Threat Model

Status: current for the simplified IMKit + bundled llama architecture
(2026-08-12).

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
this personal research build persists text the user produces as readable local
events for owner-directed Codex analysis.
Tilde has no Accessibility, Screen Recording, OCR, screenshot capture, cloud
inference, sync, upload, or analytics path.

## Assets to protect

1. Typed context, prompts, model output, accepted text, and the durable readable
   Personal History corpus.
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
- Personal History is off by default. The input method applies the master
  switch, Secure Event Input, valid-app, and app-exclusion policy before
  capture; the app repeats the durable settings checks before persistence.
  The input method performs no disk I/O and keeps only a bounded in-memory
  queue. Only the app writes the history store.
- One process-held lock owns the runtime. The socket directory is mode `0700`,
  the socket is mode `0600`, and both endpoints require the same user, the
  expected signing identifiers, and matching non-empty Team IDs in release
  builds. Completion payloads are not logged or written to disk; explicit
  Personal History payloads are written only to the explicit open research store.
- The input method uses a cancellable two-second request deadline and the wire
  protocol distinguishes suggestions, silence, timeout, invalid input, and
  runtime failure.
- When macOS Secure Event Input is active, the input method clears its fallback
  context and pending history batch, cancels suggestion work, and refuses to
  read, request, display, or capture text.
- Personal History records are readable JSONL. The directory is restricted to
  the owner (`0700`) and the file is owner-only (`0600`), but same-user processes
  can intentionally read it and no encryption-at-rest protection is claimed.
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
  stored in the same readable history-log record as the events it scores. The
  aggregate has no
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
  In this research build it is deliberately readable to any process running as
  the same user. Owner-only permissions do not protect it from same-user malware,
  privileged access, backups, snapshots, or copied files. A compromise of the
  running app can expose the recent replay window and derived personal
  contexts, transitions, aggregate paired outcome counts, and recipe identifiers.
- The open log exposes the complete event corpus and metadata. Structural
  validation detects malformed records when they are replayed; launch replay
  validates records in its recent window, while append checks the most recent
  existing record. Older corruption outside the replay window may remain
  undetected. Validation does not prevent deletion, duplication, or reordering
  of complete records. A lost local acknowledgement can
  also cause an event retry; readers deduplicate recent stable event IDs.
- On first use, the research store migrates the legacy encrypted corpus and
  removes its old file and Keychain key after validating copied event identities.
- Deleting Personal History removes its current open file and any legacy key but
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
excluded apps, secure-input policy, bounded event decoding, plaintext
round-trips, legacy migration, corrupt-store failure, deletion, prediction-before-learning,
duplicate delivery, edit-boundary isolation, aggregate-checkpoint corruption,
restart restoration, replay/live overlap, stale checkpoint rejection, and the
retention and clearing lifecycle. Manual installed-IME proof
must confirm that secure password fields add no records, ordinary fields add
records only after explicit opt-in, exclusions work in real host apps, and the
menu accurately reports size, paired-test progress, shadow-only status, memory
capacity, and deletion. Those manual checks are not proven by the deterministic
test suite.
