# App Compatibility Guide

Tilde is a macOS input method. Compatibility depends on how each app implements
IMKit marked text and routes `Tab` and `Esc`. It does not depend on
Accessibility roles, caret geometry, overlays, the clipboard, or synthetic
insertion.

## Before testing

1. Install a signed and notarized `InlineGhostIME.app`.
2. Add Tilde in System Settings → Keyboard → Input Sources.
3. Switch to Tilde from the input menu.
4. Run the Tilde app and confirm its verified external model is ready.
5. Start with a disposable TextEdit document before testing another editor.

Never test with private writing. Do not capture or attach typed text or
screenshots.

With the packaged app in `dist/`, restart it deliberately, then run the
disposable TextEdit and Chrome smoke lanes:

```bash
./script/restart_app.sh
./script/real_app_smoke.sh textedit
./script/real_app_smoke.sh chrome --fixture textarea
```

They require permission for the invoking terminal to automate the fixture app.
They prove a request was served, not that marked text rendered correctly; the
visual and key-routing checks below remain manual.

## Pass criteria

An editor is compatible only when all of these hold:

- Printable keys appear immediately and exactly once.
- A suggestion appears as marked text after enough context.
- Continued typing replaces or dismisses stale marked text cleanly.
- `Tab` accepts the full visible suggestion only while it is visible.
- `Shift-Tab` keeps the host app's normal behavior.
- `Esc` dismisses without changing committed text.
- Backspace, arrows, shortcuts, undo, dead keys, accents, and key repeat keep
  their normal jobs.
- Switching fields, windows, apps, or input sources clears stale suggestions.
- Form navigation still works when no suggestion is visible.
- Fifteen minutes of normal typing causes no duplicate text, lost text, focus
  change, stuck composition, crash, or meaningful input lag.

Treat each app and major app version as separate evidence. TextEdit passing does
not prove a browser, Electron editor, or custom canvas.

## Stop conditions

Stop and mark the editor unsupported if Tilde:

- changes or loses committed text,
- inserts a suggestion without explicit acceptance,
- consumes `Tab` or `Esc` with no visible suggestion,
- leaves marked text in the wrong field or app,
- breaks composition, autocorrect, password entry, or another input source, or
- requires Accessibility, Screen Recording, a manual model server, or a
  per-editor insertion adapter.

## Reporting a compatibility bug

Report the Tilde build, macOS version, Mac model, host app and version, input
source state, the key that failed, expected behavior, and a reproduction using
disposable text. Privacy-safe diagnostics may include counts, timings, and
failure labels; never include the writing itself.
