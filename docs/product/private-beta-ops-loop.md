# Private Beta Ops Loop

Goal: a normal tester can install, use, report, export, and stop safely without
a separate explanation from Justin.

This loop is for the 10-day small beta only. It does not widen app support and
does not make Transcripted integration a promise.

## Daily Tester Checklist

Before writing:

- Open SteadyType from the menu bar.
- Confirm Settings says the local model is ready.
- Confirm raw text tracing and screenshot tracing are off unless there is a
  separate debug session.
- Use only the allowed app for the session.
- Know the exits: `Esc`, menu bar pause, `Pause Current App`, Diagnostics export,
  Diagnostics delete traces, and Quit.

During writing:

- Write normally for 5 to 20 minutes.
- Press `Tab` only when the next word is clearly wanted.
- Press `Esc` when a suggestion feels wrong.
- Stop if a suggestion appears in search, login, payment, address, URL,
  private, or secure fields.
- Stop if text inserts in the wrong app, wrong field, wrong spot, duplicates,
  submits a prompt, or makes `Tab` feel unsafe.

After writing:

- Open Diagnostics.
- Export the Privacy Bundle.
- Add one short row to `dist/private-beta/feedback-log.md`.
- File a beta feedback issue only for trust breaks, repeated friction, or
  changes needed before the next tester.
- Use short labels. Do not paste private text.

## Redacted Report Export

Tester path:

1. Open the menu bar item.
2. Open `Debug` -> `Diagnostics`.
3. Choose `Export Privacy Bundle`.
4. Share only that redacted export when filing feedback.

Operator proof:

```bash
./script/check_redacted_report_export.sh
```

The beta stops if redacted export fails or asks for raw typed text, prompts,
screenshots, document names, URLs, recipients, subject lines, or trace excerpts
by default.

## Feedback Path

The menu bar item `Submit Feedback...` opens the structured GitHub beta issue
form. It does not attach diagnostics, read typed text, or upload anything from
the app.

The tester chooses whether to attach the redacted Privacy Bundle.

Validate the issue form with:

```bash
./script/validate_beta_issue_template.sh
```

## Triage Labels

Label definitions live in `.github/labels.yml`.

Every issue starts with:

- `beta feedback`
- `needs triage`

Use:

- `beta stop` for any hard stop condition.
- `beta trust blocker` for wrong insertion, prompt submit, private field,
  data loss, or unsafe `Tab`.
- `beta high` for repeated interruption or broken core flow.
- `beta needs report` when the redacted Privacy Bundle is missing.
- `beta docs` when install, privacy, export, uninstall, or packet copy is
  unclear.
- `beta ready to close` only after the proof and tester confirmation are linked.

Remove `needs triage` only after the next action is clear.

## Stop-Condition Dashboard

| Stop condition | Proof command or check | Label |
| --- | --- | --- |
| Wrong app, wrong field, wrong spot, duplicate insertion, or focus steal | `./script/check_trace_eval.sh` plus the session Privacy Bundle | `beta stop`, `beta trust blocker` |
| Prompt/chat submitted from `Tab` or full accept | `./script/manual_proof_queue.sh --print` and same-slice no-submit proof | `beta stop`, `beta trust blocker` |
| Suggestion in search, login, payment, address, URL, private, or secure field | `./script/beta_readiness.sh --check-only` plus the forced edge-case row | `beta stop`, `beta trust blocker` |
| `Tab` unreliable or surprising | `./script/manual_smoke_status.sh --require-all` and tester repro | `beta stop`, `beta high` |
| Accepted text deleted within 2 seconds repeatedly | `./script/check_trace_eval.sh` accepted-and-kept / annoyance section | `beta high` |
| Mock fallback, manual model server, Ollama, llama.cpp, Python, or shell setup needed | `./script/beta_readiness.sh --check-only` and `./script/check_diagnostics_log.sh` | `beta stop`, `beta trust blocker` |
| Redacted report export failed or requested private content | `./script/check_redacted_report_export.sh` | `beta stop`, `beta needs report` |
| Packet checksum stale for tester artifact | `./script/private_beta_packet.sh --check` | `beta stop`, `beta docs` |

Close a stop row only after the proof command passes for the affected artifact
or the affected app is removed from beta coverage.

## Packet Artifact

`./script/private_beta_packet.sh create` writes a self-contained packet to
`dist/private-beta/` with:

- install checklist,
- daily tester checklist,
- redacted export flow,
- feedback log,
- feedback triage labels,
- stop-condition dashboard,
- issue template validation,
- privacy status,
- model asset status,
- copied tester docs under `tester-docs/`,
- beta readiness summary,
- archive checksum.

Validate the packet with:

```bash
./script/private_beta_packet_self_test.sh
./script/private_beta_packet.sh --check
```

The `--check` path validates the current DMG/ZIP first. If those artifacts pass
but `dist/private-beta/` is missing or stale, it regenerates the packet and then
verifies the new checksums.

## Score Impact

- Documentation and feedback operations: `10/10` once the packet and issue form
  validators pass.
- Private beta readiness: `84/100` after this ops pass.

That is not external-beta clear. Fresh artifact proof, prompt-app no-submit
proof, and install/delete-data proof still decide whether testers can be
invited.
