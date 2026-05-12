# Overnight Quality Loop - 2026-05-12

Current score: 91/100.

This is a progress score, not a release claim. The deterministic 500-case prediction harness is green, and TextEdit, Notes title/body/checklist, Notes title/body/checklist undo, Notes short/long/checked variants, Chrome local fixtures, Chrome chat-like, public Chrome text-field lanes, normal-Chrome ProseMirror, Obsidian default, and Obsidian theme proof now have fresh strict proof rows on the same current app binary. Normal-Chrome default AX proof for pinned real Monaco still fails closed before proof. The strict target gate still fails because Obsidian pane/long-note variants, prompt no-submit variants, default AX Monaco, and production official editor variants are not complete.

## Prompt-To-Artifact Checklist

| Requirement | Evidence | Status |
| --- | --- | --- |
| Repo-wide audit of autocomplete quality, placement, insertion safety, privacy, runtime, controls, and proof gaps | This report plus `docs/product/deep-research-overall-excellence-scorecard-2026-05-08.md`, `docs/product/app-proof-matrix.md`, and `docs/product/proof-manifest.json` | Partial; strict proof gaps remain |
| Deterministic 500-case next-word / next-phrase eval | `docs/evals/completion-prediction-quality-500-2026-05-11.md`; `swift test --filter CompletionPredictionQualityEvalTests --jobs 1`; `./script/check_quality_eval.sh` | Passed |
| Loop improvements based on evidence | `CompletionCandidateRanker` common phrase prior; TextEdit smoke focus retry; manual proof freshness classifier fix; Chrome setup text now tries AX value replacement before slower key/paste fallback; Notes undo lanes now run guarded disposable-note proof instead of manual-only validation | Passed for shipped slices |
| Text boxes and visual placement proof | `docs/product/manual-smoke-runs.md`; `./script/manual_proof_refresh.sh --print`; `./script/manual_smoke_status.sh --strict` | Partial |
| TextEdit proof | Fresh strict row at `2026-05-12T05:06:55Z`, 2 verified accepts, app proof `app-sha256:318d83089231706e633000d0428ffde1e07a75907ee774ce2d979f8252cc662c` | Passed |
| Notes proof | Fresh strict rows at `2026-05-12T05:04:49Z`, `2026-05-12T05:05:56Z`, and `2026-05-12T05:06:15Z` for title/body/checklist; undo rows at `2026-05-12T05:20:17Z`, `2026-05-12T05:20:38Z`, and `2026-05-12T05:22:39Z`; short/long/checked variant rows from `2026-05-12T05:31:38Z` through `2026-05-12T05:34:10Z` | Passed for defined Notes lanes |
| Chrome textarea/contenteditable/editor fixtures | Fresh strict rows from `2026-05-12T05:07:16Z` through `2026-05-12T05:09:04Z` on the same app binary | Passed |
| Online notepad and MediumEditor-style public text fields | Fresh `textarea-public` and `contenteditable-public` rows at `2026-05-12T05:09:32Z` and `2026-05-12T05:09:52Z` | Passed |
| Normal-Chrome Monaco/ProseMirror default AX | `prosemirror-real-default` passed at `2026-05-12T05:38:52Z` with 2 verified accepts and strict visual trace evidence. `monaco-real-default` still fails closed before proof because Chrome exposes Monaco's hidden textarea without a stable editable value path. | Partial |
| Obsidian | Default proof passed at `2026-05-12T05:42:47Z` and theme proof passed at `2026-05-12T05:44:48Z` with 2 verified accepts after opening the dedicated proof-vault note by URI; pane and long-note variants remain pending | Partial |
| Codex, Claude Code, Claude desktop | Codex current-binary rerun reached visible suggestion proof but failed before accept because Tab was rejected as `focus-changed`; Claude Code and Claude desktop still have stale/manual-gated rows only | Blocked by prompt proof |
| Privacy of reports | Manual rows store redacted log/trace slices and proof fingerprints, not raw user text | Passed |
| Verification commands | `bash -n`; `./script/real_app_smoke_self_test.sh`; `./script/manual_smoke_self_test.sh`; `./script/check_proof_manifest.sh`; `./script/manual_proof_refresh_self_test.sh`; `swift test --filter CompletionPredictionQualityEvalTests --jobs 1`; `./script/check_quality_eval.sh`; `git diff --check`; targeted manual proof verifies; `./script/check_score_targets.sh` | Passed for changed slices; score target still fails honestly with 57 issues |

## Scorecard

| Area | Score | Reason |
| --- | ---: | --- |
| Prediction quality | 18/20 | 500 deterministic cases are 100/100; live model audit remains opt-in and disposable. |
| Insertion safety | 14/15 | TextEdit and Chrome safe lanes verify insertion; prompt/manual lanes are not current. |
| Visual placement | 14/15 | Strict screenshot rows are current for TextEdit, Notes base and variant lanes, Chrome safe lanes, and public text fields; private app variants and default AX real-editor refresh remain open. |
| Privacy and restraint | 14/15 | Reports are redacted and local; prompt apps stay manual-gated. |
| Runtime readiness | 8/10 | MLX app-owned runtime launches and warms; full long-session latency/energy proof remains outside this pass. |
| Controls and recoverability | 9/10 | Notes same-slice undo proof is now recorded for title, body, and checklist; broader GUI parity still needs more coverage. |
| Proof coverage | 14/15 | `manual_proof_refresh` reports fresh current rows for the defined Notes title/body/checklist base, undo, and short/long/checked variant gates, and the manifest now treats the three Notes surfaces as complete. |

## Remaining Blockers

- Obsidian pane and long-note lanes need current proof after the dedicated proof-vault setup is adapted to each variant.
- Codex needs a focus-stability fix before current-binary one-word no-submit proof can pass.
- Claude Code and Claude desktop lanes need manual no-submit confirmation on the current app binary.
- Normal-Chrome default AX proof for local real Monaco still needs a stable setup path; ProseMirror default AX is now current.
- Production official CodeMirror, Monaco, and ProseMirror site variants still need bounded screenshot-backed traces. `codemirror-official` was attempted on 2026-05-12 and failed closed before typing because Chrome's Allow JavaScript from Apple Events setting is disabled.
- `./script/check_score_targets.sh` should keep failing until those proof gates close.
