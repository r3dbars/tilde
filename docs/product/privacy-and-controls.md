# Privacy And Controls

## Plain Promise

SteadyType is local-first.

By default, it does not upload typed text, prompts, model output, accepted text,
screenshots, document names, URLs, recipients, or subject lines.

The default trace is redacted and stays on the Mac. Raw text and screenshots are
only for local debug sessions that the user explicitly turns on.

## What Default Tracing Can Store

The redacted trace may store:

- app bundle ID,
- field kind,
- render and insertion mode,
- request mode,
- model name,
- experiment arm,
- counts,
- lengths,
- latency,
- accepted-and-kept class,
- HMAC fingerprints for local analysis.

It should be enough to answer "did this help?" without saving what the user
wrote.

## Pause An App

To stop suggestions in the current app:

1. Focus the app.
2. Open the SteadyType menu bar item.
3. Choose `Pause in <App Name>`.

Use `Resume in <App Name>` later to enable that app again.

## Pause Or Delete Traces

Open `Debug` -> `Diagnostics` from the menu bar item.

- `Pause Tracing` stops default redacted trace writes.
- `Resume Tracing` turns them back on.
- `Export Privacy Bundle` creates the local redacted HTML report and survival report.
- Exported reports include a short privacy checklist before the metrics.
- `Delete Local Logs` deletes local trace files.
- `Open Trace Folder` reveals the local trace folder.

Open Settings to see the current sharing status. If raw text or screenshots are
enabled for debugging, Settings says to share only the redacted privacy bundle.

For the full field map, see
[`beta-privacy-data-checklist.md`](beta-privacy-data-checklist.md). For the
SDK/dependency inventory, see
[`dependency-sdk-data-inventory.md`](dependency-sdk-data-inventory.md).

The command-line delete path is:

```bash
./script/delete_local_traces.sh
```

## Beta Rule

Private beta reports should use only the redacted export. Do not ask testers for
raw traces or screenshots unless the debug opt-in is the explicit point of that
session.
