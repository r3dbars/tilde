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
- `tilde-lab ingest-events --instrument` and `online-report --instrument` for
  diagnostics only; receipt-bound `f03-closeout` is the decision-grade path.
- Delete Personalization Data wipes the count file and the diary.
- Production menu stats are still shown / accepted / words.

## What the current audit proves — and does not

- An earlier 2026-08-30 diagnostic snapshot recorded at commit `78df853f` had
  1,364 rows spanning pre-fix history and two monotonic-retention violations.
  Its inferred post-install slice had 575 events, including 39 accepts and 225
  typed-through outcomes, with zero duplicate, XOR, domain, or monotonic
  violations.
- That slice is diagnostic only. Its boundary comes from install timing, not
  sealed event provenance, and the complete file is not clean.
- A distinct later 2026-08-30 snapshot recorded at commit `d3bc71d5` examined
  the then-active `Tilde 9B Preview` build-2918 file and found 374/374
  structurally valid v3 events, including 41 accepts and 148 typed-through
  outcomes, with zero privacy, duplicate, domain, or monotonic violations. It
  is still diagnostic because the installed build and events contain no sealed
  source commit or rotation run record. It is not the 1,364-row snapshot; never
  combine their counts or call them one campaign.
- A separate clean checkout at source
  `3d84b97d211021f315d87ed964899f89dc930b5c` reproduced Preview9B build
  2926, verified the pinned model and strict signatures, excluded an embedded
  GGUF, and passed 889/889 tests without installing or launching it. This
  closes package preflight only. The decisive F03 run must rebuild from the
  final clean source so the sealed source and installed package are the same
  artifact lineage.
- F03 therefore remains **IMPLEMENTING**, not supported.

## What is still missing

1. From a clean source commit, rebuild the daily-driver IME and record the
   commit, bundle build, installed binary hash, and rotation timestamp in the
   local run record. The public aggregate may carry hashes and timestamps, not
   a local path.
2. Rotate the text-free count file. Preserve or delete the previous local audit
   file according to the owner's data choice; never check it into Git.
3. Type normally, deactivate the IME to publish the terminal write/flush
   snapshot, stop the exact Preview9B app, helper, and IME processes, then run
   `tilde-lab f03-closeout --receipt ... --output ...`. **Never check in the
   receipt, events, JSONL, or any writing.** Only the aggregate, path-free
   closeout report may be reviewed for publication.
4. Mark F03 **SUPPORTED** only when that full-file report is decision-grade
   eligible and meets the protocol's promotion rule. Then stop. Do not start
   H01 in the same attempt.

## Enforced source-to-run handoff

The Preview9B builder now makes the provenance boundary executable instead of
leaving it to a notebook:

- a decision-grade build refuses any tracked, staged, deleted, or untracked
  source change;
- `--diagnostic-dirty-source` is the only dirty-tree escape hatch, and labels
  both the app and IME `diagnostic` so they cannot become F03 evidence;
- both signed bundles carry the exact Git commit, Git tree, canonical
  clean-commit path/mode/length/content manifest SHA-256, clean/dirty
  state, sealed runner identity, the v2 toolchain/SDK identity over the signed
  Xcode seal and exact SwiftPM/driver/compiler/linker/libtool/archiver/SDK
  inputs, approved helper-input SHA-256/team, and evidence class; both plists
  must independently exact-match those receipt-linked fields;
- decision-grade compilation reads a private read-only archive of that commit,
  not mutable worktree bytes, and the builder rechecks both source and
  toolchain around compiler and signing operations; toolchain capture rejects
  out-of-bundle build tools and pins the selected Xcode namespace identity
  across each invocation; and
- assembly into fixed `dist` bundle names is serialized, and the owner-approved
  transaction executes the retained archived runner whose digest is embedded;
- build-only preview packaging verifies model inputs but does not seed or
  chmod the owner's installed model store.

Do **not** run the maintenance command below merely because it is documented.
It requires the owner's explicit approval for that exact install/rotation
window and an explicit choice for the previous text-free file:

```bash
./script/build_preview_9b.sh \
  --helper "/Applications/Tilde 9B Preview.app/Contents/Helpers/llama-server" \
  --helper-sha256 e7b0946d81c2342d0d5afd1639dcb8af444c843b4fb50cef5ceeafa302a80546 \
  --helper-team XG6WL66WUQ \
  --owner-approved-f03-run \
  --previous-ledger archive
```

Use `delete` instead of `archive` only when the owner explicitly chooses
deletion. The guarded path verifies clean app/IME lineage and signatures,
replaces only Preview9B, lets the app perform its existing atomic IME update,
stops the exact preview processes, bumps the wipe generation, rotates only
`events.jsonl` under an exclusive lock, relaunches the exact packaged helper,
and atomically writes an owner-only, path-free local receipt. A failure rolls
back the prior app, IME, Outcome Ledger generation, and ledger when safe, and
leaves owner-only recovery material.
The local word diary is never moved or read. An archived prior event file stays
local beside the receipt and must never enter Git.

The receipt closes source/package/install/rotation attribution; it is not an
outcome. After the owner confirms Preview9B is the active input source, ordinary
typing still has to produce a complete fresh file that passes F03's registered
gates.

The closeout command holds the same global maintenance lock, re-verifies the
current installed package, signing team, and model against that receipt, reads
the complete owner-only event file, joins its exact row count and digest to the
current generation's attempted/written/dropped and terminal flush snapshot,
requires the preview processes to remain stopped, and creates one new
aggregate-only report. An eligible closeout atomically advances to a fresh
generation and renames the sealed event file to
`events.closed-<runID>.jsonl` before releasing writers; publication failure
restores the prior name/generation or fails closed for manual recovery. Generic
instrument ingest cannot substitute for it. The published artifact is
`tilde-lab.f03-closeout.v2`; an in-memory pre-seal analysis is explicitly
ineligible and cannot be written as the terminal result. Old-generation
accounting/flush state is read after generation advance and checked again at
the report's no-replace commit boundary, together with stopped processes,
installed identity, maintenance state, and the held event snapshot.
The maintenance lock and Outcome Ledger are opened below the same held support
directory identity. If final-path or durability checks fail after report
rename, the generation remains sealed and the returned report carries
`terminal-publication-indeterminate`, so it cannot advance F03.

The receipt directly binds the registered Qwen model. The signed bundle itself
does not yet embed a canonical per-profile model-manifest digest; add that
before using these safeguards to claim complete standalone provenance for the
other preview profiles.

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
