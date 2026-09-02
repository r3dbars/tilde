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

## State as of 2026-09-02 (read this first)

The owner daily-drives the Tilde 9B Preview identity (Qwen 9B). Since
2026-09-01, `main` carries, for every profile, four output-identical speed
cuts (stream cut at the settled cap, peer identity cache, scaffold
prewarm, model hash once per process; PR #461), and, gated to the
`preview-9b` profile only: exact screen text via Accessibility, the
non-actionable gate anchored to the current sentence and paragraph, the
window title in the scene block, the chained accept, the shorter Electron
reveal floor, and punctuation as a request boundary (PRs #461–#463).
Production Gemma is byte-identical and pinned by `ProfileSceneOptionsTests`.

None of the preview changes is a registered result. The ordered causal
queue below is unchanged; what changed is that the build the owner types
on now produces the F03 events this page is about, and the outcome ledger
can additionally compare chained ghosts against opening ghosts. The
dated read behind all of it is
[`platform-audit-2026-09-01.md`](platform-audit-2026-09-01.md); the
attempts are in [`lab-log.md`](lab-log.md).

Build and install: `script/build_preview_9b.sh --model <installed model.gguf>
--helper "/Applications/Tilde 9B Preview.app/Contents/Helpers/llama-server"`,
quit the preview, move the old bundle aside, `ditto` the new one into
`/Applications`, open it. The app reinstalls and restarts the keyboard.

## What already landed on GitHub

On branch `cursor/f03-live-ruler-and-local-diary` (built on PR 424):

- F03 pre-registered, status **IMPLEMENTING**, not supported.
- `tilde-lab.online-event.v3` plus the IME producer in
  `Sources/InlineGhostIME/GhostOutcomeLedger.swift`.
- Shared count contract in
  `Sources/TildeCore/Policy/RetainedCharacterObservation.swift`.
- A second local word diary. Lab ingest rejects `acceptedText`.
- `tilde-lab ingest-events --instrument` and `online-report --instrument`.
- Delete Personalization Data wipes the count file and the diary.
- Production menu stats are still shown / accepted / words.

## What is still missing

1. Rebuild the daily-driver IME so ordinary typing writes events.
2. Ingest that local count file with `tilde-lab ingest-events --instrument`.
   **Never check in events, JSONL, or any writing.**
3. Confirm Tab-and-keep and Tab-and-rewrite look different from real use.
4. Mark F03 **SUPPORTED** only when the protocol's promotion rule is
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
