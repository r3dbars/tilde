# Cotabby-Inspired Implementation Plan

Date: 2026-05-26

## Product Rule

Use the public Cotabby signal to make SteadyType calmer and safer, not broader.
Do not clone Cotabby. Do not copy code or UI. Keep the app tiny until real
proof says it helps.

## Picked Improvements

1. Explain quiet states in plain language.
   - Add a pure policy that maps activation block reasons to user-facing text.
   - Store the explanation in redacted metadata as `silenceExplanation`.
   - Keep raw text out of the trace.

2. Reduce AX polling heat.
   - Raise the active suggestion poll floor from 50ms to 80ms.
   - Keep active suggestions responsive.
   - Add a test that sub-80ms values clamp to 80ms.

3. Block browser webmail by name.
   - Add a `webmail` hosted browser surface.
   - Match Gmail, Outlook, Yahoo Mail, Fastmail, Proton Mail, iCloud Mail,
     Outlook web, and Office 365 mail fingerprints.
   - Require disposable reply proof with safe Tab, screenshot placement,
     insertion, undo, and latency before support.

## Why These

- They target public complaint themes: "nothing happens", "typing lag", and
  "browser/webmail breaks".
- They are small, testable, and local to existing policies.
- They improve trust without adding a new permission or runtime system.

## Verification Plan

```bash
swift test --jobs 1 --filter 'BrowserHostedSurfacePolicyTests|FocusPollingCadencePolicyTests|FocusedTextPollGatePolicyTests|SuggestionSilenceExplanationPolicyTests'
swift test --jobs 1
./script/check_sensitive_field_proof_self_test.sh
./script/check_trace_eval.sh
```

Manual proof still needed before raising support:

- Current-head TextEdit, Notes, Obsidian, and Chrome local fixture smoke.
- Browser webmail disposable reply proof.
- Fresh latency proof after the 80ms cadence change.
- Multi-display visual placement proof.

## Later

- Add a browser-webmail proof harness only if the app is ready to test Gmail or
  Outlook replies with disposable accounts.
- Add language/grammar experiments only as separate modes.
- Keep Screen Recording and clipboard context out of beta defaults.
