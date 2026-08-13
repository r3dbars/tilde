# Tilde

![Tilde cover](Assets/GitHub/tilde-cover.png)

> **Personal research build:** this branch intentionally stores opted-in
> Personal History as readable, owner-only JSONL so local Codex research can
> inspect it. It is not the storage design for a public Tilde release.

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
text the user produces to the Tilde app. This personal research build stores a
readable local event log and quietly compares two bounded personal next-word
recipes. The comparison is shadow-only: neither recipe changes visible
suggestions. Its bounded lifetime and daily aggregate checkpoint is stored in
the same app-owned history record as the batch it scores.
Tilde has no cloud inference, analytics, sync, upload, screenshots, or accept sounds.

Personal History is off by default. Its menu shows the local storage location
and approximate size, lets the user exclude the current app, reports aggregate
next-word test progress, and can delete the entire store. At launch the two
in-memory recipes restore aggregate results and rebuild their learned contexts
without scoring from a bounded recent 4 MiB history tail. Writing stored while
that rebuild is loading warms the model but is not scored. They then learn and
score shared fresh writing while Tilde runs. The menu reports fresh words,
candidate predictions, disagreements, active days, and any memory limit; only
after fixed descriptive thresholds does it show candidate versus baseline
effective rates. The research log is owner-only (`0600`) but deliberately not
encrypted, so any process running as the same macOS user can read it. See
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
  installation, open research Personal History, and redacted diagnostics

Read [AGENTS.md](AGENTS.md) before changing behavior.

## Privacy

Tilde may retain writing locally when it provides direct user benefit. Personal
writing data remains on the user's device, is controlled by the user, and is
never transmitted for inference, analytics, or training. See
[PRIVACY.md](PRIVACY.md) and the current
[threat model](docs/security/threat-model.md).

## License

[MIT](LICENSE)
