# SteadyType Privacy

SteadyType is local-first. That is a product requirement, not a preference.

## What Accessibility is used for

The app asks for Accessibility so it can:

- find the active app and focused text field,
- read nearby text around the cursor,
- read cursor and field bounds for placement,
- insert only text you explicitly accept.

Suggestions stay off when Accessibility is denied or the focused field is not
safe to inspect. Secure fields (passwords, sensitive inputs) are hard-blocked.

Normal setup does not need Screen Recording. Screen Recording is only used for
explicit, local, opt-in placement debugging.

## What stays on this Mac

By default, typed text, nearby context, prompts, model output, accepted text,
screenshots, document names, URLs, recipients, and subject lines stay on this
Mac.

Default diagnostics are local and redacted. They can include app bundle IDs,
field kind, render mode, insertion mode, request mode, timing, counters,
failure labels, and text lengths — never raw text.

## What is never uploaded by default

The app must not upload typed text, nearby context, screenshots, window titles,
prompts, model output, accepted text, or retained diagnostics by default.

There is no remote crash reporting, analytics, or behavior telemetry path in
this repo. The model is downloaded once from a pinned source; after that,
autocomplete runs with no network egress. That claim is enforced by
`script/check_runtime_network_egress.py`, a mandatory lane of
`script/release_check.sh`, which observes the running app's sockets.

## Optional sharing paths

Raw text traces and placement screenshots are debug opt-ins. Use them only for
an explicit local debug session, and turn them off afterward. Delete local
traces at any time with `script/delete_local_traces.sh` or from the app.

## Pause, quit, disable, and delete

- Pause suggestions from the menu bar.
- Pause the current app from the menu bar.
- Turn off optional local capture features from Settings if enabled.
- Delete local traces from Diagnostics or `script/delete_local_traces.sh`.
- Quit from the menu bar when you do not want the app watching typing.
- Full removal: delete the app bundle, `~/Library/Application Support/SteadyType`,
  and `~/Library/Logs/SteadyType`.

## Dependencies

Swift package dependencies are MLX and Hugging Face libraries for local model
loading. The app must not add analytics or crash SDKs without updating this
document, and any remote reporting must be opt-in.
