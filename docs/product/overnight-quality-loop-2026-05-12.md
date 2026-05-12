# Overnight Quality Loop - 2026-05-12

Current score: 93/100.

This is a progress score, not a release claim. The deterministic 500-case prediction harness is green, and TextEdit, Notes title/body/checklist, Notes title/body/checklist undo, Notes short/long/checked variants, Chrome local fixtures, Chrome chat-like, public Chrome text-field lanes, normal-Chrome Monaco/ProseMirror, Obsidian default/theme/pane/long-note, and Codex default proof have strict proof rows on their recorded build fingerprints. The latest code slice fixed Claude Code terminal scrollback handling and added a current no-submit Claude Code pass, but it intentionally does not claim screenshot evidence because the fresh signed test app hit a macOS screen/audio permission prompt that was not granted. The strict target gate still fails because current-head reruns, Claude desktop variants, production official editor variants, real-service browser chat proof, and Codex prompt layout variants are not complete.

## Prompt-To-Artifact Checklist

| Requirement | Evidence | Status |
| --- | --- | --- |
| Repo-wide audit of autocomplete quality, placement, insertion safety, privacy, runtime, controls, and proof gaps | This report plus `docs/product/deep-research-overall-excellence-scorecard-2026-05-08.md`, `docs/product/app-proof-matrix.md`, and `docs/product/proof-manifest.json` | Partial; strict proof gaps remain |
| Deterministic 500-case next-word / next-phrase eval | `docs/evals/completion-prediction-quality-500-2026-05-11.md`; `swift test --filter CompletionPredictionQualityEvalTests --jobs 1`; `./script/check_quality_eval.sh` | Passed |
| Loop improvements based on evidence | `CompletionCandidateRanker` common phrase prior; TextEdit smoke focus retry; manual proof freshness classifier fix; Chrome setup text now tries AX value replacement before slower key/paste fallback; official Chrome editor delivery now falls back from cramped inline placement to mirror and preserves fallback placement on refresh; Notes undo lanes now run guarded disposable-note proof instead of manual-only validation | Passed for shipped slices |
| Text boxes and visual placement proof | `docs/product/manual-smoke-runs.md`; `./script/manual_proof_refresh.sh --print`; `./script/manual_smoke_status.sh --strict` | Partial |
| TextEdit proof | Fresh strict row at `2026-05-12T05:06:55Z`, 2 verified accepts, app proof `app-sha256:318d83089231706e633000d0428ffde1e07a75907ee774ce2d979f8252cc662c` | Passed |
| Notes proof | Fresh strict rows at `2026-05-12T05:04:49Z`, `2026-05-12T05:05:56Z`, and `2026-05-12T05:06:15Z` for title/body/checklist; undo rows at `2026-05-12T05:20:17Z`, `2026-05-12T05:20:38Z`, and `2026-05-12T05:22:39Z`; short/long/checked variant rows from `2026-05-12T05:31:38Z` through `2026-05-12T05:34:10Z` | Passed for defined Notes lanes |
| Chrome textarea/contenteditable/editor fixtures | Fresh strict rows from `2026-05-12T05:07:16Z` through `2026-05-12T05:09:04Z` on the same app binary | Passed |
| Online notepad and MediumEditor-style public text fields | Fresh `textarea-public` and `contenteditable-public` rows at `2026-05-12T05:09:32Z` and `2026-05-12T05:09:52Z` | Passed |
| Normal-Chrome Monaco/ProseMirror default AX | `monaco-real-default` passed at `2026-05-12T04:36:10Z` and `prosemirror-real-default` passed at `2026-05-12T05:38:52Z` with 2 verified accepts and strict visual trace evidence. | Passed |
| Obsidian | Default proof passed at `2026-05-12T05:42:47Z`, theme proof passed at `2026-05-12T05:44:48Z`, pane proof passed at `2026-05-12T06:10:49Z`, and long-note proof passed at `2026-05-12T06:19:20Z`, each with 2 verified accepts after opening the dedicated proof-vault note path. | Passed |
| Codex, Claude Code, Claude desktop | Codex default proof passed at `2026-05-12T05:59:26Z` with one verified word accept, strict visual trace evidence, prompt no-submit confirmation, and private draft restore. Claude Code default Terminal-host proof passed at `2026-05-12T06:41:56Z` on `ca41cdc33e5e` with one verified word accept and prompt no-submit confirmation, but visual strict evidence is not claimed for that row. Claude desktop still has stale/manual-gated rows only. | Partial |
| Privacy of reports | Manual rows store redacted log/trace slices and proof fingerprints, not raw user text | Passed |
| Verification commands | `bash -n`; `swift test --filter ClaudeCodeTerminalHostProofPolicyTests --jobs 1`; `swift build`; `./script/real_app_smoke_self_test.sh`; `./script/manual_smoke_self_test.sh`; `./script/check_proof_manifest.sh`; `./script/manual_proof_refresh_self_test.sh`; `swift test --filter CompletionPredictionQualityEvalTests --jobs 1`; `./script/check_quality_eval.sh`; `git diff --check`; targeted manual proof verifies; `./script/check_score_targets.sh` | Passed for changed slices; score target still fails honestly with 55 issues |

## Scorecard

| Area | Score | Reason |
| --- | ---: | --- |
| Prediction quality | 18/20 | 500 deterministic cases are 100/100; live model audit remains opt-in and disposable. |
| Insertion safety | 14.5/15 | TextEdit, Chrome, Notes, Obsidian, Codex, and Claude Code default Terminal proof verify insertion in their bounded lanes; Claude desktop variants are not current. |
| Visual placement | 14.5/15 | Strict screenshot rows exist for TextEdit, Notes base and variant lanes, Chrome safe lanes, public text fields, defined Obsidian lanes, and Codex on their recorded fingerprints; Claude Code's current pass is insertion-only, and Claude prompt variants plus production official editor lanes remain open. |
| Privacy and restraint | 14/15 | Reports are redacted and local; prompt apps stay manual-gated. |
| Runtime readiness | 8/10 | MLX app-owned runtime launches and warms; full long-session latency/energy proof remains outside this pass. |
| Controls and recoverability | 9/10 | Notes same-slice undo proof is now recorded for title, body, and checklist; broader GUI parity still needs more coverage. |
| Proof coverage | 14.5/15 | `manual_proof_refresh` reports rows for the defined Notes title/body/checklist base, undo, and short/long/checked variant gates, and the manifest now treats the three Notes surfaces, Codex default, Chrome default real-editor AX, Obsidian default/theme/pane/long-note, and Claude Code current no-submit insertion gates as real. The latest commit still needs broad strict current-head reruns before release claims. |

## Remaining Blockers

- Claude Code has current insertion/no-submit proof, but strict screenshot refresh is blocked until the user grants the local macOS screen/audio permission prompt; iTerm2 and Ghostty host-labeled lanes are still pending.
- Claude desktop lanes need manual no-submit confirmation on the current app binary.
- Production official Monaco still needs bounded proof with verified insertion. The official-demo harness now uses isolated Chrome plus localhost DevTools instead of Chrome JavaScript-from-Apple-Events; `prosemirror-official` passed strict screenshot-backed proof at 2026-05-12T07:47:10Z, and `codemirror-official` passed strict screenshot-backed proof at 2026-05-12T08:14:38Z after narrowing setup and CodeMirror AX soft-wrap repair. Monaco now reaches display with `floatingMirror` after `inline-room-too-small`, but the AX-readable setup keeps insertion verification `unchanged`; the more natural Monaco setup exposes `beforeChars=0` and fails as `tooLittleContext`. No green Monaco official accept proof is claimed.
- Browser ChatGPT, Slack, and Discord stay blocked until exact real-service no-submit proof exists.
- Codex needs more prompt layout proof before it can move above A-.
- `./script/check_score_targets.sh` should keep failing until those proof gates close.
