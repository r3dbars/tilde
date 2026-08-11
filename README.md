# Tilde

![Tilde cover](Assets/GitHub/tilde-cover.png)

Tilde is an open-source macOS input method that offers quiet inline writing
suggestions. Type normally, then use:

- `Tab` to accept the next word
- `Shift-Tab` to accept the whole suggestion
- `Esc` to dismiss

Suggestions are IMKit marked text inside the app where you are writing. Tilde
does not use an overlay, Accessibility, Screen Recording, OCR, or synthetic
paste events.

## How it works

Tilde ships as one self-contained, signed package:

1. `InlineGhostIME` handles keystrokes and marked-text display.
2. The Tilde menu-bar app receives bounded context over an owner-only local
   Unix socket.
3. The app runs its bundled `llama-server` helper and bundled GGUF model as a
   child process. Users do not install or run a model server.

Typed context and model output stay in memory. Tilde has no cloud inference,
analytics, raw-text learning, screenshots, or accept sounds.

## Status and requirements

Tilde is beta software for Apple Silicon Macs running macOS 26 or newer. The
input method must be enabled once in System Settings. IMKit behavior varies by
editor; see the [compatibility guide](docs/compatibility/app-compatibility-runbook.md).

## Development

The project is a Swift 6.2 package with no Xcode project file.

```bash
./script/proof.sh fast
./script/build_and_run.sh --verify
./script/build_ime.sh --no-notarize --no-install
```

`script/proof.sh fast` is the pre-merge gate. `script/release_check.sh` is the
manual release gate and includes bundle, model, signing, and network-egress
checks. A distributable build embeds the static helper and GGUF model through
`script/package_app.sh`.

Production code has three parts:

- `Sources/AutocompleteLabCore`: pure, deterministic suggestion policy
- `Sources/InlineGhostIME`: IMKit input and marked-text presentation
- `Sources/AutocompleteLabApp`: local socket, app-owned llama lifecycle, menu,
  installation, and redacted diagnostics

Read [AGENTS.md](AGENTS.md) before changing behavior.

## Privacy

Tilde processes writing locally and does not retain raw typed text, prompts,
model output, or accepted text. See [PRIVACY.md](PRIVACY.md) and the current
[threat model](docs/security/threat-model.md).

## License

[MIT](LICENSE)
