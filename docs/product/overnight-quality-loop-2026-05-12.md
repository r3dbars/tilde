# Overnight Quality Loop - 2026-05-12

Current score: 92.5/100.

This is a progress score, not a release claim. The deterministic 500-case prediction harness is green and now splits the positive corpus between model candidate ranking and a common-phrase fallback that succeeds even when the raw model candidates omit the expected answer. This pass refreshed current proof rows for TextEdit, Notes title/body/checklist, Obsidian default/theme/pane, Chrome local fixtures, Chrome chat-like, public Chrome textarea/contenteditable, normal-Chrome ProseMirror, and isolated forced-renderer Monaco/ProseMirror on their recorded build fingerprints. The latest code slice also adds tested Obsidian CodeMirror cursor-drift repairs for long virtualized notes. However, after commit `a58ac36d97ee`, `./script/manual_smoke_status.sh --strict` correctly reports 30 current-head proof gaps because the source changed and the app rows need reruns. Obsidian long-note reruns still fail before presentation because Obsidian/CodeMirror reports the AX cursor before the bottom typed line; no green long-note current-head proof is claimed.

## Prompt-To-Artifact Checklist

| Requirement | Evidence | Status |
| --- | --- | --- |
| Repo-wide audit of autocomplete quality, placement, insertion safety, privacy, runtime, controls, and proof gaps | This report plus `docs/product/deep-research-overall-excellence-scorecard-2026-05-08.md`, `docs/product/app-proof-matrix.md`, and `docs/product/proof-manifest.json` | Partial; strict proof gaps remain |
| Deterministic 500-case next-word / next-phrase eval | `docs/evals/completion-prediction-quality-500-2026-05-11.md`; `swift test --filter CompletionPredictionQualityEvalTests --jobs 1`; `./script/check_quality_eval.sh` | Passed; 200/200 predictor-only positives and 200/200 model-ranker positives |
| Loop improvements based on evidence | `CommonPhraseContinuationPredictor`; prompt style `screen-aware-continuation-v6`; `CompletionCandidateRanker` common phrase prior; TextEdit smoke focus retry; manual proof freshness classifier fix; Chrome setup text now tries AX value replacement before slower key/paste fallback; official Chrome editor delivery now falls back from cramped inline placement to mirror and preserves fallback placement on refresh; Notes undo lanes now run guarded disposable-note proof instead of manual-only validation | Passed for shipped slices |
| Text boxes and visual placement proof | `docs/product/manual-smoke-runs.md`; `./script/manual_proof_refresh.sh --print`; `./script/manual_smoke_status.sh --strict` | Partial; current-head rows need reruns after `a58ac36d97ee` |
| TextEdit proof | Fresh strict row at `2026-05-12T05:06:55Z`, 2 verified accepts, app proof `app-sha256:318d83089231706e633000d0428ffde1e07a75907ee774ce2d979f8252cc662c` | Passed |
| Notes proof | Fresh strict rows at `2026-05-12T05:04:49Z`, `2026-05-12T05:05:56Z`, and `2026-05-12T05:06:15Z` for title/body/checklist; undo rows at `2026-05-12T05:20:17Z`, `2026-05-12T05:20:38Z`, and `2026-05-12T05:22:39Z`; short/long/checked variant rows from `2026-05-12T05:31:38Z` through `2026-05-12T05:34:10Z` | Passed for defined Notes lanes |
| Chrome textarea/contenteditable/editor fixtures | Fresh strict rows from `2026-05-12T09:12:22Z` through `2026-05-12T09:14:17Z` on pushed commit `46c9dbd21a86` | Passed |
| Online notepad and MediumEditor-style public text fields | `textarea-public` passed at `2026-05-12T09:15:03Z`; `contenteditable-public` passed at `2026-05-12T09:30:53Z` after allowing the same AX editor target to shrink to a 33px single-line editing frame. | Passed |
| Normal-Chrome Monaco/ProseMirror default AX | `prosemirror-real-default` passed at `2026-05-12T09:19:46Z` with 2 verified accepts and strict visual trace evidence after the same-app focus churn fix. `monaco-real-default` is blocked: normal Chrome AX exposes too little Monaco text context and setup verification stays unchanged. | Partial |
| Obsidian | Default proof passed at `2026-05-12T10:19:10Z`, theme proof passed at `2026-05-12T10:19:37Z`, and pane proof passed at `2026-05-12T10:20:12Z`, each with 2 verified accepts on clean commit `cc24798d033b`. Current-head long-note proof is blocked: reruns on `a58ac36d97ee` time out before `suggestion-presented` because CodeMirror reports the AX cursor before the bottom typed line. | Partial |
| Codex, Claude Code, Claude desktop | Codex default proof passed at `2026-05-12T05:59:26Z` with one verified word accept, strict visual trace evidence, prompt no-submit confirmation, and private draft restore. Claude Code default Terminal-host proof passed at `2026-05-12T06:41:56Z` on `ca41cdc33e5e` with one verified word accept and prompt no-submit confirmation, but visual strict evidence is not claimed for that row. Claude desktop still has stale/manual-gated rows only. | Partial |
| Privacy of reports | Manual rows store redacted log/trace slices and proof fingerprints, not raw user text | Passed |
| Verification commands | `bash -n script/real_app_smoke.sh`; `swift test --filter TextContextRepairPolicyTests --jobs 1`; `swift test --filter CompletionPredictionQualityEvalTests --jobs 1`; `./script/check_quality_eval.sh`; `swift build`; `./script/real_app_smoke_self_test.sh`; `./script/manual_smoke_status.sh --strict`; `git diff --check`; targeted real-app proof rows | Passed for changed slices; strict current-head proof still fails honestly |

## Scorecard

| Area | Score | Reason |
| --- | ---: | --- |
| Prediction quality | 18.5/20 | 500 deterministic cases are 100/100, including 200 cases where the expected phrase is absent from raw model candidates and recovered by the local common-phrase predictor; live model audit remains opt-in and disposable. |
| Insertion safety | 14.4/15 | TextEdit, Chrome, Notes, Obsidian default/theme/pane, Codex, and Claude Code default Terminal proof verify insertion in their bounded lanes on recorded fingerprints; current-head reruns and Claude desktop variants are not complete. |
| Visual placement | 14.4/15 | Strict screenshot rows exist for TextEdit, Notes base and variant lanes, Chrome safe lanes, public text fields, Obsidian default/theme/pane, and Codex on their recorded fingerprints; Obsidian long-note current-head proof, Claude Code strict refresh, Claude prompt variants, and production official editor lanes remain open. |
| Privacy and restraint | 14/15 | Reports are redacted and local; prompt apps stay manual-gated. |
| Runtime readiness | 8/10 | MLX app-owned runtime launches and warms; full long-session latency/energy proof remains outside this pass. |
| Controls and recoverability | 9/10 | Notes same-slice undo proof is now recorded for title, body, and checklist; broader GUI parity still needs more coverage. |
| Proof coverage | 13.8/15 | `manual_smoke_status.sh --strict` reports 30 current-head gaps after the `a58ac36d97ee` source change. The recorded rows remain useful evidence, but beta/release claims need broad reruns. Chrome default Monaco AX and Obsidian long-note are explicit blockers, not hidden failures. |

## Remaining Blockers

- Claude Code has current insertion/no-submit proof, but strict screenshot refresh is blocked until the user grants the local macOS screen/audio permission prompt; iTerm2 and Ghostty host-labeled lanes are still pending.
- Claude desktop lanes need manual no-submit confirmation on the current app binary.
- Obsidian long-note current-head proof is blocked. The app now has unit-tested repairs for CodeMirror leading-word and after-cursor active-line drift, but the live proof harness still sees CodeMirror place the AX range before the bottom typed line, so `obsidian-long-note` times out before `suggestion-presented`.
- Normal-Chrome Monaco and production official Monaco still need bounded proof with verified insertion. The default-AX Monaco rerun on pushed commit `46c9dbd21a86` could not setup-verify text (`beforeChars=1`, unchanged after AX/key/paste attempts). The official-demo harness now uses isolated Chrome plus localhost DevTools instead of Chrome JavaScript-from-Apple-Events; `prosemirror-official` passed strict screenshot-backed proof at 2026-05-12T07:47:10Z, and `codemirror-official` passed strict screenshot-backed proof at 2026-05-12T08:14:38Z after narrowing setup and CodeMirror AX soft-wrap repair. Monaco official display reaches `floatingMirror` after `inline-room-too-small`, but the AX-readable setup keeps insertion verification `unchanged`; the more natural setup exposes `beforeChars=0` and fails as `tooLittleContext`. No green Monaco accept proof is claimed.
- Browser ChatGPT, Slack, and Discord stay blocked until exact real-service no-submit proof exists.
- Codex needs more prompt layout proof before it can move above A-.
- `./script/check_score_targets.sh` should keep failing until those proof gates close.
