# Tilde

![Tilde cover](Assets/GitHub/tilde-cover.png)

Tilde is an open-source macOS input method that offers quiet inline writing
suggestions. Type normally, then use:

- `Tab` to accept the next word; press it again to keep advancing
- `Esc` to dismiss

Suggestions are IMKit marked text inside the app where you are writing. Tilde
does not use an overlay, Accessibility-based insertion, or synthetic paste
events. Screen
Memory uses macOS Screen Recording and on-device OCR when enabled by its
privacy controls; screen text stays on this Mac and is never sent for cloud
inference.

## Two parts, one repository

This repository contains exactly two things:

| Name | Purpose | Ships to users? |
| --- | --- | --- |
| **Tilde** | The macOS input method and its local runtime | **Yes** |
| **Tilde Lab** | The separate app and command-line tools used to test and improve Tilde | **No** |

There is no separate “Tilde Research” product. Long-running experiments are a
Tilde Lab capability and use the `tilde-lab` command.

The source boundary is enforced by Swift package dependencies: Tilde Lab may
exercise `TildeCore`, but `TildeApp` and `InlineGhostIME` do not import or link
any `TildeLab…` target. Packaging includes the Tilde app, input method, and
signed inference helper—not Tilde Lab. See the
[repository boundary map](docs/repository-boundary.md) for the exact folders and
dependency direction.

## How it works

Tilde ships as a small signed package:

1. `InlineGhostIME` handles keystrokes and marked-text display.
2. The Tilde menu-bar app receives bounded context over an owner-only local
   Unix socket.
3. The app runs its signed `llama-server` helper as a child process. Users do
   not install or run a model server.
4. On first run, `ModelManager` downloads one pinned Gemma 4 E2B GGUF to
   Tilde's external app-support storage, verifies its exact size and SHA-256,
   and starts the helper only with that verified path. The GGUF is never part
   of `Tilde.app`.

The only model asset is `gemma-4-E2B.Q4_K_M.gguf` at exactly 3,427,861,984
bytes (SHA-256
`389c868898bffed97fd178646f88562cafecc6f60983a636bac53b131fd068a2`). The
download uses this immutable revision URL and no model picker or Hugging Face
login:

`https://huggingface.co/mradermacher/gemma-4-E2B-GGUF/resolve/3762686d74ff8db6c98f8d3c389f56fbdf994d5a/gemma-4-E2B.Q4_K_M.gguf`

Completion requests and unaccepted model output stay in memory. When the user
explicitly enables Personal History, the input method asynchronously sends the
text the user produces to the Tilde app. The app stores a local encrypted event
log and quietly compares two bounded personal next-word recipes. That paired
comparison remains shadow-only, but the same opt-in also lets a conservative,
read-only personal prediction run beside Gemma. When it has enough local
support, it can replace the visible base suggestion; otherwise Gemma remains.
Serving never changes the paired score or trains Gemma. The comparison's bounded
lifetime and daily aggregate checkpoint is encrypted in the same app-owned
history log as the batch it scores; it contains no words, candidate text, or
per-case rows.
Tilde has no cloud inference, analytics, sync, upload, or accept sounds. The
separate first-run asset phase may make an HTTPS request only to the immutable
model URL above; it sends no typed text, screen text, prompt, history, or model
output. After the model is verified, autocomplete is local-only.

Personal History is off by default. Its menu shows the local storage location
and approximate size, lets the user exclude the current app, reports aggregate
next-word test progress, and can delete the entire store. At launch the two
in-memory recipes restore aggregate results and rebuild their learned contexts
without scoring from a bounded recent 4 MiB history tail. Writing stored while
that rebuild is loading warms the model but is not scored. They then learn and
score shared fresh writing while Tilde runs. The menu reports fresh words,
candidate predictions, disagreements, active days, and any memory limit; only
after fixed descriptive thresholds does it show candidate versus baseline
effective rates. Each history record is encrypted with AES-GCM; its key lives
as a non-synchronizing item in the user's macOS login Keychain. See
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
`script/package_app.sh` is the single manual release driver. It requires the
helper hash and an explicitly named `--proof-model` preseed. That model is
checked against the Gemma 4 E2B revision, byte count, and SHA-256 above, copied
only into isolated external proof storage, and never into the signed app. The
driver then blocks on bundle shape, helper/IME signatures, runtime health,
steady-state open-socket observation, notarization, Gatekeeper checks, and a
32 MiB hard cap on the signed app artifact. Run
`./script/package_app.sh --help` for the full command. The pins must come from
human review: matching bytes and valid file shapes do not prove provenance.

For private, aggregate-only model comparisons, see the
[evaluation guide](docs/evaluation.md).

Tilde Lab is the separate local regression studio for reply quality, judgment,
Scene Memory, synthetic personalization, real text-system interaction, and
performance experiments. It runs reproducible multi-arm suites through the
pinned loopback-only Gemma runtime, includes deterministic policy audits and an
instrumented AppKit Scene Host, and persists aggregate-only reports for
baseline/candidate comparison. Its locked headline is **Net Keystrokes Saved**,
with safety, bad-suggestion, temporal-integrity, privacy, interaction, and
latency gates outside the number. The `tilde-lab` CLI adds durable
work-item resume, interleaved paired blocks, a hard development/validation/
holdout firewall, root-clustered uncertainty, risk–coverage, chronological
personalization, local dogfood/attention-tax and confidence calibration,
real-host evidence, soak gates, and immutable permanent regressions. It
includes a 300-case protected curated
Slack pack with prefix replay/context ablations, the 400-case synthetic quiz,
and a read-only development-only importer for private accepted/typed-instead
history:

```bash
./script/build_and_run.sh --tilde-lab
swift build --product tilde-lab
.build/debug/tilde-lab init --name qwen-factorial --hypothesis-id QWEN-GEN-01 --hypothesis "The registered treatment improves expected utility without increasing harm." --class generator --suite certified-v2 --output campaign.json
.build/debug/tilde-lab run campaign.json --resume
.build/debug/tilde-lab review --campaign campaign.json --status supported --conclusion "The preregistered criteria passed; see the experiment record."
.build/debug/tilde-lab compare --campaign campaign.json
swift run tilde-lab-runner --workers 1 --slots 8 --repetitions 10
swift run tilde-lab-runner --built-in-suite slack-reply-gold-v1
swift run tilde-lab-runner --manifest ./candidate-matrix.tilde-lab.json
```

See the [Tilde Lab guide](docs/tilde-lab.md) for the complete knob manifest,
score and privacy contracts, scenario format, matrix runner, and the boundary
between high-throughput model evidence and foreground real-IME proof. The
[Tilde Learning Ledger](docs/learning-ledger.md) preserves what experiments
taught us, why candidates were kept or rejected, and what should be tested next.
The [research roadmap](docs/research-roadmap.md) sequences the longer-term
hypotheses behind that queue, while [experiment records](docs/experiments/README.md)
define the public pre-registration and result format.

The code follows the same two-part boundary:

- **Tilde:** `Sources/TildeCore`, `Sources/TildeApp`, and
  `Sources/InlineGhostIME`.
- **Tilde Lab:** `Sources/TildeLabKit`, `Sources/TildeLab`,
  `Sources/TildeLabCLI`, and `Sources/TildeLabRunner`.

The names inside each group describe implementation components, not additional
products.

Read [AGENTS.md](AGENTS.md) before changing behavior.

## Privacy

Tilde may retain writing locally when it provides direct user benefit. Personal
writing data remains on the user's device, is controlled by the user, and is
never transmitted for inference, analytics, or training. See
[PRIVACY.md](PRIVACY.md) and the current
[threat model](docs/security/threat-model.md).

## License

[MIT](LICENSE)
