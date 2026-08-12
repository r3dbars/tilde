# Tilde

![Tilde cover](Assets/GitHub/tilde-cover.png)

Tilde is an open-source macOS input method that offers quiet inline writing
suggestions. Type normally, then use:

- `Tab` to accept the next word; press it again to keep advancing
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

Completion requests and unaccepted model output stay in memory. When the user
explicitly enables Personal History, the input method asynchronously sends the
text the user produces to the Tilde app. The app stores a local encrypted event
log and quietly evaluates a bounded personal word completer in memory. The
personal candidate remains shadow-only: it does not change visible suggestions.
Tilde has no cloud inference, analytics, sync, upload, screenshots, or accept
sounds.

Personal History is off by default. Its menu shows the local storage location
and approximate size, lets the user exclude the current app, and can delete the
entire store. Each record is encrypted with AES-GCM; its key lives as a
non-synchronizing item in the user's macOS login Keychain. See
[PRIVACY.md](PRIVACY.md) for the capture boundary and remaining risks.

## Status and requirements

Tilde is beta software for Apple Silicon Macs running macOS 26 or newer. The
input method must be enabled once in System Settings. IMKit behavior varies by
editor; see the [compatibility guide](docs/compatibility/app-compatibility-runbook.md).

## Development

The project is a Swift 6.2 package with no Xcode project file.

```bash
./script/proof.sh fast
./script/build_and_run.sh
./script/build_ime.sh
```

The two build scripts create development bundles; they do not contain the
release model or helper. By default, both require the one eligible Apple
Development identity in the keychain, so the app and IME receive matching,
non-empty Team IDs. If multiple identities exist, pass the same exact SHA-1 to
both with `--sign-identity`. Explicit `--sign-identity -` builds ad hoc bundles,
which cannot exercise the authenticated app-to-IME runtime.
`script/proof.sh fast` is the pre-merge gate.
`script/package_app.sh` is the single manual release driver; it requires exact
SHA-256 pins for the helper and
model, then blocks on bundle, runtime, signing, notarization, Gatekeeper, and
open-socket observation checks. Run `./script/package_app.sh --help` for its
required release inputs. Its isolated runtime lane observes only the exact
packaged app and helper on a dedicated port. It may append privacy-safe
diagnostics, but it does not quit or change the daily driver or input method;
IME/editor/authenticated-socket proof stays manual.
The pins must come from human review: matching bytes and valid file shapes do
not prove where a helper or model came from.

For private, aggregate-only model comparisons, see the
[evaluation guide](docs/evaluation.md).

Production code has three parts:

- `Sources/AutocompleteLabCore`: pure, deterministic suggestion policy
- `Sources/InlineGhostIME`: IMKit input and marked-text presentation
- `Sources/AutocompleteLabApp`: local socket, app-owned llama lifecycle, menu,
  installation, encrypted Personal History, and redacted diagnostics

Read [AGENTS.md](AGENTS.md) before changing behavior.

## Privacy

Tilde may retain writing locally when it provides direct user benefit. Personal
writing data remains on the user's device, is controlled by the user, and is
never transmitted for inference, analytics, or training. See
[PRIVACY.md](PRIVACY.md) and the current
[threat model](docs/security/threat-model.md).

## License

[MIT](LICENSE)
