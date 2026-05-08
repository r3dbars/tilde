# Autocomplete Lab Beta Privacy

Autocomplete Lab is local-first by default.

## What Accessibility Is Used For

The app asks for Accessibility so it can:

- find the active app and focused text field,
- read nearby text around the cursor,
- read cursor and field bounds for placement,
- insert only text you explicitly accept.

Suggestions stay off when Accessibility is denied or the focused field is not
safe to inspect.

## What Stays On This Mac

By default, typed text, nearby context, prompts, model output, accepted text,
screenshots, document names, URLs, recipients, and subject lines stay on this
Mac.

Default diagnostics are local and redacted. They can include app bundle IDs,
field kind, render mode, insertion mode, request mode, timing, counters,
failure labels, and text lengths.

## What Is Never Uploaded By Default

The beta build must not upload typed text, nearby context, screenshots, window
titles, prompts, model output, accepted text, or retained diagnostics by
default.

There is no default remote crash, analytics, or behavior telemetry path in this
repo.

## Optional Sharing Paths

The normal support path is a redacted diagnostics export. Share that only when
you choose to.

Raw text traces and placement screenshots are debug opt-ins. Use them only for
an explicit local debug session, and turn them off afterward.

## Pause, Quit, Disable, And Delete

- Pause suggestions from the menu bar.
- Disable the current app from the menu bar.
- Quiet the current field from Settings.
- Export or delete local traces from Diagnostics.
- Quit from the menu bar when you do not want the app watching typing.

See [UNINSTALL-DELETE-DATA.md](UNINSTALL-DELETE-DATA.md) for full removal.

## Dependency Inventory

Current Swift package dependencies include MLX and Hugging Face libraries for
local model loading. The app must not add analytics or crash SDKs without
updating this document and keeping any remote reporting opt-in.
