# Overnight Quality Loop - 2026-05-12

Current score: 84/100.

This is a progress score, not a release claim. The deterministic 500-case prediction harness is green, and the safe TextEdit plus Chrome proof lanes were refreshed on the current app binary. The strict target gate still fails because private/manual apps, prompt no-submit variants, and normal-Chrome default AX editor lanes are not complete.

## Prompt-To-Artifact Checklist

| Requirement | Evidence | Status |
| --- | --- | --- |
| Repo-wide audit of autocomplete quality, placement, insertion safety, privacy, runtime, controls, and proof gaps | This report plus `docs/product/deep-research-overall-excellence-scorecard-2026-05-08.md`, `docs/product/app-proof-matrix.md`, and `docs/product/proof-manifest.json` | Partial; strict proof gaps remain |
| Deterministic 500-case next-word / next-phrase eval | `docs/evals/completion-prediction-quality-500-2026-05-11.md`; `swift test --filter CompletionPredictionQualityEvalTests --jobs 1`; `./script/check_quality_eval.sh` | Passed |
| Loop improvements based on evidence | `CompletionCandidateRanker` common phrase prior; TextEdit smoke focus retry; manual proof freshness classifier fix | Passed for shipped slices |
| Text boxes and visual placement proof | `docs/product/manual-smoke-runs.md`; `./script/manual_proof_refresh.sh --print`; `./script/manual_smoke_status.sh --strict` | Partial |
| TextEdit proof | Fresh strict row at `2026-05-12T04:24:17Z`, 2 verified accepts, app proof `app-sha256:4590d7aaf8e29f41c8ea9db7237875d51b043c9e905cd4316abef17f150383d7` | Passed |
| Chrome textarea/contenteditable/editor fixtures | Fresh strict rows from `2026-05-12T04:24:39Z` through `2026-05-12T04:26:17Z` | Passed |
| Online notepad and MediumEditor-style public text fields | Fresh `textarea-public` and `contenteditable-public` rows at `2026-05-12T04:26:43Z` and `2026-05-12T04:27:01Z` | Passed |
| Normal-Chrome Monaco/ProseMirror default AX | Tried on this pass; Monaco default reached visible suggestion but full accept missed after key tap idle; ProseMirror default entered quiet mode before second suggestion | Still blocked |
| Notes, Obsidian, Codex, Claude Code, Claude desktop | Existing stale/manual-gated rows only; not rerun unattended | Blocked by manual gate |
| Privacy of reports | Manual rows store redacted log/trace slices and proof fingerprints, not raw user text | Passed |
| Verification commands | `bash -n`, `./script/real_app_smoke_self_test.sh`, `./script/manual_proof_refresh_self_test.sh`, `git diff --check`, targeted manual proof verifies | Passed for changed slices |

## Scorecard

| Area | Score | Reason |
| --- | ---: | --- |
| Prediction quality | 18/20 | 500 deterministic cases are 100/100; live model audit remains opt-in and disposable. |
| Insertion safety | 14/15 | TextEdit and Chrome safe lanes verify insertion; prompt/manual lanes are not current. |
| Visual placement | 12/15 | Strict screenshot rows are current for TextEdit and Chrome safe lanes; default AX and private app variants remain open. |
| Privacy and restraint | 14/15 | Reports are redacted and local; prompt apps stay manual-gated. |
| Runtime readiness | 8/10 | MLX app-owned runtime launches and warms; full long-session latency/energy proof remains outside this pass. |
| Controls and recoverability | 8/10 | Existing pause/accept/undo controls are covered by tests; broader GUI parity was not rerun here. |
| Proof coverage | 10/15 | `manual_proof_refresh` reports 11 current rows, 7 stale rows, and 9 pending rows before final docs commit. |

## Remaining Blockers

- Notes title/body/checklist need manual-gated current proof.
- Obsidian default, theme, pane, and long-note lanes need manual-gated current proof.
- Codex and Claude lanes need manual no-submit confirmation on the current app binary.
- Normal-Chrome default AX Monaco and ProseMirror remain unreliable on this machine.
- `./script/check_score_targets.sh` should keep failing until those proof gates close.
