# Next thread: on-device F03 ingest

This page is the briefing for the **next local Mac F03 run**. The ruler schema
and live producer exist, and a current-file audit has seen ordinary typing. The
remaining job is a clean, provenance-bearing full-file run. Do not restart the
literature sweep. Do not change the ghost.

How we work: [`lab-partnership.md`](lab-partnership.md).
The attempt notebook: [`lab-log.md`](lab-log.md).
The protocol: [`docs/experiments/F03-retained-outcome-ledger.md`](../experiments/F03-retained-outcome-ledger.md).

## In one sentence

Tilde can now count keep versus rewrite without storing words; this thread
proves that counter on one fresh, attributable file.

## What is already true (do not rediscover)

- Personal keyboard and prose-writing papers cluster around 2018–2020. Apple
  published personal email-search query completion in 2024 and production
  search query completion in 2026; those are retrieval/ranking priors, not
  prose/IME proof. See
  [`where-the-field-stopped.md`](where-the-field-stopped.md).
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
  frozen everything else. The first live bet after F03 is supported is H01:
  three words vs eight. Not a new model.

## What already landed on GitHub

The implementation that began on `cursor/f03-live-ruler-and-local-diary`
(built on PR 424) is now present in the repository:

- F03 pre-registered, status **IMPLEMENTING**, not supported.
- `tilde-lab.online-event.v3` plus the IME producer in
  `Sources/InlineGhostIME/GhostOutcomeLedger.swift`.
- Shared count contract in
  `Sources/TildeCore/Policy/RetainedCharacterObservation.swift`.
- A second local word diary. Lab ingest rejects `acceptedText`.
- `tilde-lab ingest-events --instrument` and `online-report --instrument`.
- Delete Personalization Data wipes the count file and the diary.
- Production menu stats are still shown / accepted / words.

## What the current audit proves — and does not

- The complete count file has 1,364 events and two pre-fix monotonic-retention
  violations.
- An inferred post-install slice has 575 events, including 39 accepts and 225
  typed-through outcomes, with zero duplicate, XOR, domain, or monotonic
  violations.
- That slice is diagnostic only. Its boundary comes from install timing, not
  sealed event provenance, and the complete file is not clean.
- A later full-file audit of the active `Tilde 9B Preview` identity found
  340/340 structurally valid v3 events, including 39 accepts and 143
  typed-through outcomes, with zero privacy, duplicate, domain, or monotonic
  violations. Its full proof passed 889 tests. It is still diagnostic because
  the installed build and events contain no sealed source commit or rotation
  run record; build 2918 and binary hashes cannot repair provenance afterward.
- F03 therefore remains **IMPLEMENTING**, not supported.

## What is still missing

1. From a clean source commit, rebuild the daily-driver IME and record the
   commit, bundle build, installed binary hash, and rotation timestamp in the
   local run record. The public aggregate may carry hashes and timestamps, not
   a local path.
2. Rotate the text-free count file. Preserve or delete the previous local audit
   file according to the owner's data choice; never check it into Git.
3. Type normally, then ingest the entire fresh file with
   `tilde-lab ingest-events --instrument`. **Never check in events, JSONL, or
   any writing.**
4. Mark F03 **SUPPORTED** only when the full fresh file meets the protocol's
   promotion rule. Then stop. Do not start H01 in the same attempt.

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

Confirm the Learning Ledger's Stage 0 exit gate, then run H01 (three versus
eight) as the first live config bet. F04 is already a completed foundation.
Playing with other configs in Lab is allowed as discovery. Promoting them is
not.

## Proof

- Pre-merge: `./script/proof.sh fast`
- Structural (if shipped Swift grows for a reason other than a
  net-negative refactor):
  `PROOF_STRUCTURAL_CHANGE=1 PROOF_DIFF_BASE=origin/main ./script/proof.sh fast`
- After every attempt: append [`lab-log.md`](lab-log.md).
