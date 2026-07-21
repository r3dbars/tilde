# SteadyType Threat Model & Security Findings

Status: first adversarial security pass (2026-06-13). Scope: the standalone macOS
autocomplete app (`Sources/AutocompleteLabApp`) and the pure policy core
(`Sources/AutocompleteLabCore`). This complements — it does not replace — the privacy
no-leak sentinel tests and the local privacy export proof.

This document is the source of truth for SteadyType's *security* posture (distinct from the
*privacy/no-leak* proofs). Keep it short and decision-oriented. When you change insertion,
identity, tracing, capture, event-tap, or model-asset behavior, update the matching finding.

---

## 1. What SteadyType can do (trust surface)

SteadyType runs as a menu-bar process the user grants Accessibility (and optionally Screen
Recording) permission to. That permission set is powerful:

- **Read** the focused text field of *every* app — text before/after the caret, role,
  geometry — via `Mac/AccessibilityClient.swift` + `Mac/SerialFocusedTextAXReader.swift`.
- **Observe keystrokes** through a CGEvent tap (`Mac/KeyboardEventTap.swift`) and **swallow**
  Tab / Shift-Tab / Esc while a suggestion is eligible.
- **Inject text** into other apps via the Accessibility API or synthetic key events
  (`Mac/InsertionEngine.swift` → `AccessibilityClient.insertText` /
  `replaceSelectedTextBySettingValue`).
- **Persist local artifacts**: redacted traces (`Mac/RawAutocompleteTraceLog.swift`),
  an activity log (`Mac/DiagnosticsLog.swift`), opt-in caret-region screenshots
  (`Mac/ScreenshotTraceCapture.swift`), an opt-in verbatim "Personal Capture" journal
  (`Mac/PersonalCaptureJournalWriter.swift`, `Mac/PersonalCaptureEpisodeStore.swift`), and a
  downloaded model asset (`Runtime/LocalModelAssetInstaller.swift`).

Generic-app support recently widened the **injection** surface from a curated allowlist to
arbitrary apps, which is what motivated this review.

### Assets to protect

1. The user's typed text, prompts, model output, and accepted text (privacy).
2. Integrity of *where* accepted text is written (it must land only in the field the user saw
   the suggestion in).
3. The local diagnostic/capture artifacts (they can contain derived user content).
4. Integrity of the executed model weights.

### Adversaries considered

- **A1 — Malicious/forged local app**: another app the user runs and focuses. It controls its
  own Info.plist (so its `CFBundleIdentifier`), window titles, and AX tree, and can post
  synthetic events and programmatically steal focus. It does **not** have root.
- **A2 — Local same-user process / second local user / backup**: a process or user who can read
  files the artifact directories expose, or who can tamper with on-disk model weights.
- **A3 — Network attacker**: can MITM the model download (rogue CA, DNS, captive portal).

Out of scope: an attacker with root or with SteadyType's own code-signing identity; physical
attacks; the security of MLX / swift-transformers internals beyond how we invoke them.

### Design strengths confirmed by this pass (no change needed)

- Typed text, prompts, model output, and accepted text are length-summarised, not stored, in
  the default trace lane (`Tracing/AutocompleteTracePrivacyFilter.swift`,
  `Text/DiagnosticsMetadataRedactor.swift`). Raw-content tracing and screenshots are
  **opt-in and auto-expiring** (`RawAutocompleteTraceLog` 1-hour expiry, then redaction).
- Secure fields (AX secure flag) and bundle-ID-sensitive apps are suppressed before a request
  is ever built; the doc-local n-gram corpus excludes secure/sensitive fields
  (`App/SuggestionOrchestrator.swift` `docLocalContextTexts`).
- **Personal Capture is off by default** (`App/AppSettings.swift` → `personalCaptureEnabled`
  defaults `false`) and, when on, is gated by `Session/PersonalCapturePolicy.swift`, which
  blocks secure context, sensitive fields, browser-hosted sensitive surfaces, and
  suppressed field kinds.
- The acceptance pipeline re-validates field identity (bundle + pid + element), surrounding
  text, selection, and a rich target fingerprint at *decision* time
  (`Session/SuggestionAcceptanceGuard.swift`).
- The model is fetched from a **pinned immutable revision** over HTTPS; a missing integrity
  receipt is treated as corruption (no silent "trust it anyway"); integrity is checked before
  the weights are handed to MLX (`Runtime/MLXModelRuntime.swift`).
- The field identity used everywhere includes the **process id**, not just the bundle string
  (`Session/FocusedFieldIdentity.swift`), which resists cross-app confusion.

**There are no CRITICAL findings.** The privacy-by-default design holds. The findings below are
local-threat-model and defense-in-depth hardening.

---

## 2. Findings (ranked)

| ID | Area | Finding | Severity | Status |
|----|------|---------|----------|--------|
| F1 | (2) Field changed between request & accept | Accepted text was written without binding the AX write to the validated field identity — an insertion-time TOCTOU that could redirect text into a field/app that stole focus | MEDIUM (impact high, likelihood low) | **Fixed** |
| F2 | (3) Capture/trace files | Diagnostic & capture artifacts (incl. verbatim Personal Capture, opt-in raw-content traces, and screenshots) created world-readable (`0644` in `0755` dirs) | MEDIUM | **Fixed** |
| F3 | (1) Bundle-ID / identity spoofing | Per-app trust, sensitivity, and capability decisions rest solely on the forgeable `CFBundleIdentifier`; no code-signature / Team-ID verification anywhere | MEDIUM | Mitigated + recommendation |
| F4 | (5) Model asset integrity | The shipped Qwen default has pinned known-good hashes; explicitly selected legacy manifests remain weaker, HTTPS has no pinning, and on-disk weights remain tamperable | MEDIUM | Mitigated + recommendation |
| F5 | (4) Event-tap | Acceptance honors synthetic / other-process key events (no event-source filtering) | LOW | Documented |
| F6 | (3) Capture/trace files | `diagnostics.log` grows unbounded (475 MB observed locally); no rotation | LOW | Documented |

Severity = realistic impact × likelihood under the adversary model above. "Fixed" means a code
change + regression test landed in this branch.

---

## 3. Detailed findings

### F1 — Accepted text not bound to the validated field at write time (Area 2) — MEDIUM — Fixed

**Where:** `Mac/AccessibilityClient.swift` `insertText` / `replaceSelectedTextBySettingValue`
(they call `NSWorkspace.shared.frontmostApplication` and re-resolve the focused element *fresh
at write time*); reached from `App/AppDelegate.swift` `insertAcceptedText` →
`Mac/InsertionEngine.swift` `insert`.

**What:** `Session/SuggestionAcceptanceGuard.swift` does re-validate the focused field (bundle,
pid, element, surrounding text, selection, target fingerprint) at *decision* time — so the
common "field changed" case is already blocked. But the actual Accessibility write happens a few
hops later and **independently re-resolves "the frontmost app / focused element"**. Between the
guard passing and the `AXUIElementSetAttributeValue` call, focus can change (a notification, an
app self-activating, an app programmatically focusing another field). The write primitive only
checked that the element's value *changed*, not that it was still the same target. The synthetic
accepted text is the user's own private continuation, so a drifted write could deposit it into a
different app/field than the one the user saw.

This is a time-of-check / time-of-use (TOCTOU) gap. Impact is high (private text into the wrong
surface); likelihood is low because the decision-time guard fires immediately before and the
window is sub-frame.

**Fix:** New pure guard `Session/InsertionTargetIdentityGuard.swift` compares the validated
("expected") `FocusedFieldIdentity` against the identity re-derived immediately before the
write. `AccessibilityClient` now computes the live identity (`bundle + pid + Int(CFHash(element))`
— the same derivation the reader uses) and **fails closed** (refuses the write, logs
`insert-target-identity-mismatch`) when it drifted. `InsertionEngine.insert` and the
`TextInsertionClient` protocol thread an `expectedFieldIdentity`; `AppDelegate` passes the shown
suggestion's identity (`currentSuggestionFieldIdentity`). Cross-app drift (different bundle/pid)
is always refused; the element check is relaxed only under descendant-text fallback, where the
written element legitimately differs from the read element.

**Residual:** the synthetic **key-event** insertion lane (`InsertionEngine.insertWithKeyEvents`)
posts CGEvents to whatever is frontmost and cannot be identity-bound at the CGEvent layer; it
still relies on the decision-time guard. The AX lanes (the primary path for generic apps) are now
bound. Tests: `Tests/AutocompleteLabCoreTests/InsertionTargetIdentityGuardTests.swift`,
`Tests/AutocompleteLabAppTests/InsertionEngineTests.swift` (forwarding).

### F2 — World-readable local diagnostic & capture artifacts (Area 3) — MEDIUM — Fixed

**Where (pre-fix):** every local writer created its directory and file with default
`FileManager` calls (no `posixPermissions`), so the process umask (`022`) produced **`0644`
world-readable files in `0755` directories**:
`Mac/RawAutocompleteTraceLog.swift`, `Mac/DiagnosticsLog.swift`,
`Mac/PersonalCaptureJournalWriter.swift`, `Mac/PersonalCaptureEpisodeStore.swift`,
`Mac/ScreenshotTraceCapture.swift` (the PNG is written by `/usr/sbin/screencapture` at umask).

**Confirmed on disk:**
```
~/Library/Logs/SteadyType/                 drwxr-xr-x   (0755)
~/Library/Logs/SteadyType/traces.jsonl     -rw-r--r--   (0644)   90 MB
~/Library/Logs/SteadyType/diagnostics.log  -rw-r--r--   (0644)  475 MB
~/Library/Application Support/SteadyType/Personal Capture/  drwxr-xr-x (0755)
```

**What:** Locations and sensitivity:
- `traces.jsonl` — redacted by default, but holds **raw** text/prompts/output/accepted text
  while raw-content dogfood tracing is opted in (1-hour window).
- `Personal Capture/*.md` and `Episodes/*.jsonl` — **verbatim** typed text and accepted text
  (when the feature is enabled).
- `screenshots/*.png` — whatever is on screen near the caret (when screenshot tracing is on).

macOS currently keeps `~/Library` itself at `0700`, which blocks *other users* from traversing
in — so this is not currently a cross-user read in the default layout. It is still a real
defense-in-depth defect: the privacy guarantee must travel with the file, because these files are
copied into Time Machine / synced folders / support bundles and the app must not depend on a
parent directory's mode. Adversary A2.

**Fix:** New `Mac/SecureLocalStorage.swift` creates directories `0700` and files `0600`
(and *tightens existing* artifacts on the next write, so an upgraded install migrates old
world-readable files). Every local artifact writer now routes through it — the five above plus
`Mac/LocalReportExporter.swift` (export/privacy bundles incl. the raw-derived
`survival-inspector-debug.json`), and
`Mac/CompatibilityLearningStore.swift`. `screencapture` output and atomic `Data.write` outputs
are re-tightened after creation. Tests:
`Tests/AutocompleteLabAppTests/SecureLocalStorageTests.swift` and
`LocalArtifactPermissionsTests.swift`.

**Residual (LOW, inherent):** for artifacts written by an external tool or an atomic
`Data.write` (which create a fresh inode at the umask), there is a brief window between creation
and the `restrictFile` chmod during which the file is `0644`. A same-user process (A2) could
`open()` in that window. This is defense-in-depth only and matches the A2 threat model;
eliminating it would require writing into a pre-created `0700` temp dir and renaming, which is not
worth the complexity here.

### F3 — App identity is the forgeable bundle id; no signature check (Area 1) — MEDIUM — Mitigated + recommendation

**Where:** `AccessibilityClient.frontmostApplication()` reads
`NSWorkspace.shared.frontmostApplication.bundleIdentifier`; that string is the *only* key into
the per-app trust model — `AppDelegate.effectiveProfile(for:)` → `profileStore.profile(for:
app.bundleIdentifier)` (and ~10 other `profile(for: bundleIdentifier)` sites),
`Configuration/HostCompatibilityPolicy.swift`, `Compatibility/CompatibilityRouter.swift`. A
repo-wide search for `SecCode` / `SecStaticCode` / `teamIdentifier` / `SecRequirement` returns
**nothing** — code-signing identity is never verified.

**What:** macOS does not enforce `CFBundleIdentifier` uniqueness; a malicious app (A1) can set
its Info.plist `CFBundleIdentifier` to `com.google.Chrome`, `com.apple.TextEdit`, etc. By
spoofing a "green"/trusted id it can induce SteadyType to (a) show inline suggestions and offer
full-sentence acceptance in its own surfaces, and (b) evade bundle-ID-based *sensitivity*
heuristics. The demonstrable harm is bounded: the injected text is the user's own continuation
of text typed **into the attacker's own field** (which the attacker already sees), so spoofing
yields no new exfiltration; and AX-secure-field suppression (`context.isSecure`) is independent
of the bundle string, so password fields stay protected regardless of spoofing.

**Mitigation already in place / added:** field identity and the F1 insertion guard both bind to
**process id**, not just the bundle string, so a spoofer cannot use identity confusion to receive
*another* app's accepted text. The residual is the per-app *capability/sensitivity* model resting
on a forgeable signal.

**Recommendation (not yet implemented — would touch routing broadly):** before granting any
*elevated* trust (full acceptance, detached suggestions, relaxing a one-word/fail-closed prompt
profile), verify the frontmost app's code-signing Team ID / requirement via `SecCode`
(`SecCodeCopyGuestWithAttributes` on the pid → `SecCodeCheckValidity` against a per-profile
designated requirement). Treat an unverifiable signature as untrusted (diagnostics-only). Never
relax a *safety* control purely on bundle id. Track as a follow-up; ranked MEDIUM because the
current demonstrable harm is limited.

### F4 — Legacy selectable model manifests lack the default's integrity guarantees (Area 5) — MEDIUM — Mitigated + recommendation

**Where:** `Runtime/LocalModelAssetInstaller.swift` (`HubClient.default.downloadSnapshot`),
`Runtime/ModelAssetInstaller.swift` (`finalizeDownloadedSnapshot`),
`Runtime/ModelAssetIntegrityReceipt.swift` (`Writer.write` / `Validator.validate`),
model manifests in `Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift`.

**What:**
1. **Transport** is HTTPS via the Hugging Face SDK with an **immutable pinned revision** (commit
   hash) — good. But there is **no certificate/host pinning** in app code, so a rogue CA / MITM
   (A3) that can also satisfy the SDK's checks is not additionally constrained by us.
2. **The normal-launch default is anchored.** `qwen35FourBMLX4Bit` has baked `ExpectedFile`
   byte counts and SHA-256s, and they are enforced
   (`ModelAssetIntegrityReceipt.validateExpectedFiles` → "known-good checksum mismatch"). Some
   explicitly selected legacy manifests, including `Gemma4E4BItOptiQ`, still have no pinned
   source or `expectedFiles`; they therefore retain a weaker structural-only posture instead of
   the default's signed-binary trust anchor.
3. **On-disk tamper (A2):** model weights live under
   `~/Library/Application Support/SteadyType/Models/...`; a same-user process could replace the
   files. For receipt-backed manifests, the validator (recompute-and-compare) catches changes made
   *after* the receipt; legacy manifests without pinned source metadata do not get that check.

**Mitigations:** normal launch now selects receipt-backed Qwen with immutable source metadata and
baked expected hashes. The model directory is also created `0700`
(`ModelAssetInstaller`/`LocalModelAssetInstaller`), reducing the cross-user tamper surface.

**Recommendation (not implemented — needs the canonical hashes):**
- Populate immutable source metadata and `expectedFiles` (byte count + SHA-256) for **every
  selectable manifest**, so first-install
  integrity is anchored to values baked into the signed app binary rather than to first-seen
  bytes. Treat missing source metadata or empty `expectedFiles` as a *weaker* posture and log it.
- Consider a signed model manifest fetched alongside the asset, and/or cert pinning for the
  download host.
- Verification already runs before MLX load (`MLXModelRuntime.verifyModelAssetIntegrity`); keep
  that ordering and avoid widening the check→load window.

### F5 — Event tap accepts synthetic / other-process key events (Area 4) — LOW — Documented

**Where:** `Mac/KeyboardEventTap.swift` `tapCreate(tap: .cgSessionEventTap, place:
.headInsertEventTap, options: .defaultTap, eventsOfInterest: keyDown)`. The callback reads
`eventSourceUnixProcessID` / `eventTargetUnixProcessID` **only for diagnostics** (line ~835) — it
does not filter by source.

**What:** the tap is appropriately least-privilege (keyDown only; swallows keys only while a
suggestion is eligible; re-enables itself on `tapDisabledByTimeout`/`ByUserInput`, lines
~197–222). But because event source is not checked, another process (A1) can post a synthetic Tab
to force-accept a *currently visible* suggestion. Impact is low: it can only accept a suggestion
the user could already see, into the same validated field (the decision-time guard + F1 binding
still apply), and the accepted text is the user's own. No privilege escalation.

**Recommendation (optional):** consider ignoring synthetic events (non-HID source, or
`eventSourceUnixProcessID == own pid`) on the *acceptance* path. Not done here because it can
break the app's own synthetic re-dispatch and legitimate assistive/automation tools that
synthesize Tab; the risk does not justify that regression for a beta.

### F6 — `diagnostics.log` grows unbounded (Area 3) — LOW — Documented

**Where:** `Mac/DiagnosticsLog.swift` appends without rotation; observed at **475 MB** locally.
Availability/footprint issue, not a disclosure one (contents are redacted via
`DiagnosticsMetadataRedactor`, and the file is now `0600` per F2). Recommendation: cap size / rotate.

---

## 4. Coverage of the requested areas

- **(1) Bundle-ID / app-identity spoofing** → F3. A forged app can claim a trusted id; trust rests
  on a non-authenticated string. Mitigated by pid-bound identity (incl. the F1 fix); Team-ID
  verification recommended for elevated trust.
- **(2) Field changed between request & accept** → F1. The orchestrator/`SuggestionAcceptanceGuard`
  *do* re-validate at decision time (verified), but the AX write was not identity-bound; now fixed
  (fail-closed `InsertionTargetIdentityGuard` at the write).
- **(3) Capture/trace files** → F2 (permissions, now `0700`/`0600`) and F6 (growth). Locations,
  redaction completeness, and opt-in/expiry behavior reviewed and found sound; the gap was file
  permissions on content-bearing artifacts.
- **(4) Event-tap exposure / hijack** → F5. Least-privilege and self-healing; no source filtering
  (LOW).
- **(5) Model-asset download + integrity** → F4. The default uses HTTPS + pinned revision + baked
  hashes + receipt + pre-load verification; gaps remain for weaker explicitly selected legacy
  manifests and the lack of certificate pinning.

---

## 5. Fixes landed in this pass

| File | Change |
|------|--------|
| `Sources/AutocompleteLabCore/Session/InsertionTargetIdentityGuard.swift` | New pure guard binding a write to the validated field identity (F1) |
| `Sources/AutocompleteLabApp/Mac/AccessibilityClient.swift` | Re-derive live identity and fail closed before AX writes (F1) |
| `Sources/AutocompleteLabApp/Mac/InsertionEngine.swift` + `App/AppDelegate.swift` | Thread `expectedFieldIdentity` from acceptance into the write (F1) |
| `Sources/AutocompleteLabApp/Mac/SecureLocalStorage.swift` | New helper: `0700` dirs / `0600` files, tighten-on-write migration (F2) |
| `RawAutocompleteTraceLog`, `DiagnosticsLog`, `PersonalCaptureJournalWriter`, `PersonalCaptureEpisodeStore`, `ScreenshotTraceCapture`, `LocalReportExporter`, `CompatibilityLearningStore` | Route artifact creation through `SecureLocalStorage` (F2) |
| `Runtime/ModelAssetInstaller.swift`, `Runtime/LocalModelAssetInstaller.swift` | Create the model directory `0700` (F4 partial) |

Regression tests: `InsertionTargetIdentityGuardTests` (core), `InsertionEngineTests` (forwarding),
`SecureLocalStorageTests`, `LocalArtifactPermissionsTests`. Full suite: `swift test --jobs 1` →
**1640 tests / 203 suites, 0 failures**.

## 6. Open follow-ups (recommended, not yet done)

1. **F3** — verify Team ID / `SecCode` requirement before granting elevated trust; never relax a
   safety control on bundle id alone.
2. **F4** — add `expectedFiles` known-good hashes to every shipped model manifest; log empty
   `expectedFiles` as weaker trust; consider a signed manifest / cert pinning.
3. **F5** — optionally ignore synthetic / foreign-source events on the acceptance path.
4. **F6** — rotate / cap `diagnostics.log`.
