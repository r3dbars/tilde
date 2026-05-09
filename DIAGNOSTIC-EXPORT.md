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
- subject lines.

## How To Export

Open Diagnostics from the menu bar and use Export Report.

For beta feedback, attach only that redacted Privacy Bundle. The structured
feedback form does not need raw traces or screenshots by default. The menu bar
`Submit Feedback...` item opens that form, but it does not attach diagnostics
automatically.

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
