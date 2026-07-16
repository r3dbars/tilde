# SteadyType

![SteadyType cover](Assets/GitHub/steadytype-cover.png)

SteadyType is a lightweight Mac writing assistant. It shows a short suggestion
near the cursor and inserts text only when you accept it.

## Core Loop

- `Tab` accepts the next word.
- `Shift-Tab` accepts the visible suggestion.
- `Esc` dismisses.
- Pause stops suggestions globally or for the current app.
- The app owns its local MLX runtime; users do not run a separate model server.

SteadyType reads the focused field and caret through macOS Accessibility.
Secure and sensitive fields are blocked. Diagnostics stay local and redacted by
default; raw text and screenshots require an explicit, time-limited debug opt-in.

## Compatibility

TextEdit is the reference target. Notes and Obsidian are proof-gated targets,
and Chrome support is limited to local textarea and contenteditable fixtures.
Unknown apps may use a conservative generic Accessibility path, but that is not
a support claim. Prompt, send, terminal, public browser, and hosted editor
surfaces stay guarded or blocked until their exact layout has current proof.

See [known limitations](KNOWN-LIMITATIONS.md) and the current
[compatibility matrix](docs/product/compatibility-matrix.md).

## Development

SteadyType is a Swift 6.2 package for macOS 26 on Apple Silicon.

```bash
./script/proof.sh fast
./script/build_and_run.sh --bundle-only
```

The broad private-beta gate is separate:

```bash
./script/beta_readiness.sh
```

Start with [development and release](docs/DEVELOPMENT.md) and
[architecture](docs/ARCHITECTURE.md).

## Product Truth

- [Privacy](PRIVACY-BETA.md)
- [First run](FIRST-RUN-BETA.md)
- [Diagnostics export](DIAGNOSTIC-EXPORT.md)
- [Uninstall and delete local data](UNINSTALL-DELETE-DATA.md)
- [Release notes template](RELEASE-NOTES.md)

Automated checks, current manual proof, and a shipped release are separate
facts. This repository does not treat a green scorecard or a filled template as
release evidence.
