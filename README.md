# SteadyType

![SteadyType cover](Assets/GitHub/steadytype-cover.png)

SteadyType is an open-source macOS menu bar app for quiet, local inline writing
suggestions. It watches the focused text field through Accessibility, shows a
short ghost-text suggestion near the caret, and inserts text only when you
accept it. All inference runs on-device with MLX on Apple Silicon — no cloud,
no telemetry, no separate model server.

- `Tab` accepts the next word
- `Shift-Tab` accepts the whole visible suggestion
- `Esc` dismisses

## Status

Beta, and honestly labeled as such. It works best in TextEdit, Apple Notes,
Obsidian, and browser text areas; other apps go through a generic Accessibility
path and can be paused individually when placement or insertion misbehaves.
Prompt surfaces stay conservative (one word, fail-closed); terminal emulators,
secure fields, and sensitive fields are hard-blocked.

## Requirements

- Apple Silicon Mac, macOS 26+
- Xcode 26 toolchain (SwiftPM package, no project file)
- ~4 GB disk for the local model asset

## Build and run

```bash
git clone https://github.com/r3dbars/steadytype
cd steadytype
./script/build_and_run.sh          # builds the bundle and launches it
```

The app asks for Accessibility permission on first launch, and opens Settings
to install the local model if the asset is missing. `build_and_run.sh --verify`
builds and validates without launching.

## Development

```bash
./script/proof.sh fast             # the pre-merge gate (CI runs exactly this)
swift test --jobs 1                # full suite
./script/smoke_test.sh             # full suite + bundle verify (macOS)
./script/release_check.sh          # release gate incl. live network-egress proof
```

Enable the pre-push hook once with `git config core.hookspath .githooks`.

Architecture in one paragraph: `Sources/AutocompleteLabCore` is pure,
deterministic Swift — every decision about when to request, show, accept, or
suppress a suggestion lives there as a small tested policy type.
`Sources/AutocompleteLabApp` is the native shell — Accessibility reading,
keyboard event tap, text insertion, the overlay panel, and the MLX runtime.
See `AGENTS.md` for the working rules.

## Privacy

Local-first is a hard product requirement. Typed text, context, prompts, model
output, and screenshots never leave the machine; diagnostics are redacted by
default; and the release gate includes a live check that the running app opens
no unexpected network sockets. Details in [PRIVACY.md](PRIVACY.md).

## License

[MIT](LICENSE)
