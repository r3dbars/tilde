# Next thread: on-device F03 ingest

This page is the briefing for a **new local Mac thread**. The previous
cloud thread implemented the ruler schema. It did not watch anyone type.
Do not restart the literature sweep. Do not change the ghost.

How we work: [`lab-partnership.md`](lab-partnership.md).
The attempt notebook: [`lab-log.md`](lab-log.md).
The protocol: [`docs/experiments/F03-retained-outcome-ledger.md`](../experiments/F03-retained-outcome-ledger.md).

## In one sentence

Tilde can see Tab. It cannot see whether those characters were still
there later. This thread wires a quiet Mac-side counter so Lab can tell
keep from rewrite without storing words.

## What is already true (do not rediscover)

- Personal keyboard papers stalled ~2018–2020. Recent work is generic
  HCI or Copilot-on-code. See [`where-the-field-stopped.md`](where-the-field-stopped.md).
- The scientific object is the **controller**, not a newer GGUF. See
  [`scientific-program.md`](scientific-program.md).
- Tab tracks feeling (Ziegler) and still pays for deleted junk. The
  score we want is retained useful characters at 5s / 30s / segment.
- Missingness and zero are different facts.
- Typed-through (settled ghost, writer typed it, no Tab/Escape) must
  not collapse into ignored.
- A flicker shorter than 200ms is not a read
  (`SettledVisibility.minimumReadMilliseconds`).
- Play with configs is a hunch. A decision is one change, same test,
  frozen everything else. First live bet after F03 is supported: H01
  three words vs eight. Not a new model.

## What already landed on GitHub

On branch `cursor/autocomplete-research-briefing-22a1`, PR 424:

- F03 pre-registered, status **IMPLEMENTING**, not supported.
- `tilde-lab.online-event.v3` in
  `Sources/TildeLabKit/Models/LabOnlineExperiment.swift`.
- Shared contract in
  `Sources/TildeCore/Policy/RetainedCharacterObservation.swift`.
- Privacy allowlist and horizon reports in
  `Sources/TildeLabKit/Models/LabRetainedOutcome.swift`.
- Fixtures in `Tests/TildeLabKitTests/LabRetainedOutcomeTests.swift`
  and `Tests/TildeCoreTests/RetainedCharacterObservationTests.swift`.
- `tilde-lab ingest-events` and `online-report` already exist. They
  accept local JSONL. They do not produce events from the IME.
- Production still only counts shown / accepted / words in
  `GhostStats` / `TildeStats`. No 30s or segment retention.

## What this Mac thread must do

1. Produce v3 **text-free** events from real IMKit use (or a thin
   recorder next to the IME that the Lab can ingest).
2. Count retained characters at 5s, 30s, and segment close (focus
   change, send/commit, or a privacy-safe idle boundary).
3. If a horizon cannot be watched, store a missingness reason. Never
   coerce that to zero kept characters.
4. Distinguish typed-through from ignored and from dismissed.
5. Keep one store: extend `LabOnlineExperimentEvent`. Do not add a
   second telemetry format.
6. Ingest locally with `tilde-lab ingest-events`. **Never check in
   events, JSONL, or any writing.**
7. Prove, on this Mac, that Tab-and-keep and Tab-and-rewrite look
   different in the aggregate report.
8. Mark F03 **SUPPORTED** only when the protocol's promotion rule is
   honestly met. Then stop. Do not start H01.

`TildeApp` and `InlineGhostIME` must not depend on Tilde Lab. The
count contract may live in `TildeCore`. Lab remains the ingest and
report owner.

## What this thread must not do

- Change suggestion text, length, timing, or model.
- Start H01, H02, a Qwen rematch, LoRA, Future Lattice, or whole-sentence
  ghosts.
- Print or commit personal writing, screen text, prompts, candidates,
  or local paths.
- Add an Accessibility/overlay insertion path.
- Treat `online-report` on fixtures as live proof.

## After F03 is actually supported

House research list, in order: F04 (freeze scoring cheats), close or
kill Qwen on one clean rerun, then H01 (three vs eight) as the first
live config bet. Playing with other configs in Lab is allowed as
discovery. Promoting them is not.

## Proof

- Pre-merge: `./script/proof.sh fast`
- Structural (if shipped Swift grows for a reason other than a
  net-negative refactor):
  `PROOF_STRUCTURAL_CHANGE=1 PROOF_DIFF_BASE=origin/main ./script/proof.sh fast`
- After every attempt: append [`lab-log.md`](lab-log.md).
