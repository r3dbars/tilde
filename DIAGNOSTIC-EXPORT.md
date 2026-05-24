# Diagnostic Export

Diagnostics are local-first and redacted by default.

## What The Export Is For

Use the export after a beta writing session or when reporting a trust issue.
It should help debug timing, placement, insertion, and suppression behavior
without sharing what the tester typed.

## What The Default Export Can Include

- app version and build metadata when available,
- macOS and runtime readiness labels,
- app bundle IDs,
- field kind labels,
- render and insertion modes,
- latency summaries,
- failure reason labels,
- accepted-and-kept summaries,
- redacted trace JSONL,
- redacted HTML reports,
- visual calibration reports.
- `PRIVACY-CHECKLIST.md`, mapping each default field to retention, opt-in
  state, and whether it can leave the Mac.

## What The Default Export Must Not Include

- raw typed text,
- prompts,
- model output,
- accepted text,
- screenshots,
- document names,
- URLs,
- recipients,
- subject lines,
- Personal Capture Markdown files.

## How To Export

Open `Debug` -> `Diagnostics` from the menu bar and use `Export Privacy Bundle`.

For beta feedback, use the structured issue form from `Submit Feedback...`.
Attach only the redacted Privacy Bundle when diagnostics are needed; the form
does not need raw traces or screenshots by default and does not attach
diagnostics automatically.

Personal Capture is separate from diagnostics. Do not attach it to beta support
unless the developer explicitly chooses that local dogfood artifact.

For command-line checks, run:

```bash
./script/check_redacted_report_export.sh
./script/check_current_build_privacy_export.sh
```

The current-build check runs the built app binary against synthetic private
sentinels and verifies the exported privacy bundle does not contain them.

## Raw Debug Sessions

Raw text or screenshots are allowed only for an explicit debug session. Record
that consent in the session notes before collecting them, and turn the debug
switches off afterward.
