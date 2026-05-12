# SteadyType Product Scorecard

Updated: 2026-05-12.
Base app/source evidence checked through `f1de7710`.
Latest beta gate evidence checked on 2026-05-12 with the strict latency selector.
Overall score: 75/100.

This is the single current product scorecard. Older scorecards are historical
inputs only. Do not raise a score unless the evidence in the row changes.
Stale proof can explain progress, but it cannot make a row green.
This worktree also had unrelated uncommitted changes during scoring; this file
only counts the command output named below.

## Scores

| Area | Score | Evidence | Why It Is Not Higher | Next Proof |
| --- | ---: | --- | --- | --- |
| Suggestion quality | 90/100 | `./script/check_quality_eval.sh`: completion quality, word-completion quality, offline-model quality, and the deterministic 500-case completion-prediction suite all passed on 2026-05-12 after the generic-filler suppression and concrete suffix examples in `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift` and `script/local_completion_runtime.py`. `docs/evals/completion-prediction-quality-500-2026-05-11.md` remains the checked-in corpus input. | Deterministic quality is green and the prompts are tighter, but local model dogfood evidence is still opt-in and short of broad live writing volume. | Add a short `AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 ./script/local_quality_audit.py` report without durable raw prompt text, then rerun `./script/check_quality_eval.sh`. |
| Placement | 70/100 | `./script/check_visual_placement_evidence.sh --require-all`: 22 screenshot files verified. `./script/manual_smoke_status.sh --strict`: 30 target app passes are stale or pending on this head. | Screenshot files exist, but current-head app proof is stale for most lanes, and Obsidian long-note plus Monaco default AX remain open. | Use `./script/manual_smoke_status.sh --strict` to pick the next stale lane, rerun the listed `./script/real_app_smoke.sh` command with screenshot tracing, then rerun `./script/check_visual_placement_evidence.sh --require-all`. |
| Tab safety | 72/100 | `./script/beta_readiness.sh --check-only`: prompt app proof gate passed with accidental submit, send-key collision, prompt mutation, wrong-context insertion, and content violation counts at 0. The same run says manual app proof is blocked by stale rows. | One-word Tab proof is safer than before, but full accept stays disabled for prompt apps and current-head accept proof is stale across the main app lanes. | Refresh Codex, Claude Code, and Claude desktop one-word no-submit lanes from `./script/manual_smoke_status.sh --strict`, then keep full accept disabled until a dedicated no-submit full-accept gate exists. |
| Latency | 84/100 | `./script/beta_readiness.sh --check-only`: strict latest-launch latency gate passed on 2026-05-12 with `AUTOCOMPLETE_LAB_LOG_START_LINE=19217` and `AUTOCOMPLETE_LAB_TRACE_START_LINE=4879`; first-visible n=12, p95 252 ms, p99 267 ms, first-token p95 192 ms, total-generation p95 247 ms, lateShown=0. `./script/select_latency_window_self_test.sh` and `./script/latency_benchmark_report_self_test.sh` passed. | The current slice is fast, but it is still TextEdit-heavy and does not replace broader current-head real-app proof. | Keep `./script/select_latency_window_self_test.sh` and `./script/latency_benchmark_report_self_test.sh` green, then run `./script/beta_readiness.sh --check-only` after each fresh launch so empty or old latency slices cannot count. |
| Privacy | 88/100 | `./script/beta_readiness.sh --check-only`: redacted report export OK, issue template OK, clipboard fallback disabled OK, prompt app proof gate OK, and prompt/chat safety counters stayed at 0. `docs/product/beta-privacy-data-checklist.md` documents the privacy review surface. | Privacy proof is strong for this loop, but a final beta claim still needs current manual app proof and signed/notarized distribution proof. | Rerun `./script/check_current_build_privacy_export.sh --privacy-export-proof`, `./script/check_runtime_network_egress.py`, and `./script/beta_readiness.sh --check-only` after the remaining beta gates close. |
| App coverage | 55/100 | `./script/check_proof_manifest.sh --require-all`: 7 complete surfaces, 6 partial surfaces, and 7 manifest issues. `./script/manual_smoke_status.sh --strict`: 30 stale or pending target app passes. | Coverage is broad on paper, but many rows are not current proof and several high-risk app classes stay intentionally blocked. | Close one proof-manifest pending requirement at a time, starting with current safe lanes before prompt apps or production browser editors. |
| Onboarding | 64/100 | Documented manual gate: `docs/product/onboarding-permission-qa-checklist.md`. Product docs also point testers to `docs/product/manual-smoke-checklist.md`. | The first-run path is documented, but there is no current tester-walkthrough proof tying Accessibility, model readiness, TextEdit practice, pause, and trace deletion into one fresh run. | Record one guided TextEdit practice run and update the checklist with command output or a manual gate row. |
| Controls | 76/100 | Documented manual gate: `docs/product/privacy-and-controls.md`. `./script/beta_readiness.sh --check-only` confirms clipboard fallback insertion is disabled. | Pause/delete/export controls exist, but the latest score run did not prove state parity across Settings, menu bar, and Diagnostics. | Run focused control-surface tests or a documented manual gate that toggles pause, disabled apps, trace delete, and redacted export from all visible surfaces. |
| Diagnostics | 86/100 | `./script/check_diagnostics_log.sh`: diagnostics log verified. `./script/beta_readiness.sh --check-only`: runtime production gate OK and redacted report export OK after the RawTraceReportExport tests passed. | Diagnostics are healthy enough for the current loop, but manual proof rows still need fresh current-build slices before the diagnostics story is complete. | Rerun `./script/check_diagnostics_log.sh`, `./script/check_current_build_privacy_export.sh --privacy-export-proof`, and `./script/manual_smoke_status.sh --strict` after refreshing manual proof. |
| Model readiness | 90/100 | `./script/check_model_asset.py`: Qwen3.5 4B MLX verified at revision `32f3e8ecf65426fc3306969496342d504bfa13f3` with `.steadytype-model-integrity.json`; `./script/beta_readiness.sh --check-only`: model asset OK, runtime production gate OK with MLX metadata, and the strict latency slice used the same app-owned Qwen3.5 default runtime. | The app-owned model path is proven for the current slice, but beta trust still depends on fresh manual app proof and distribution proof. | Keep `./script/check_model_asset.py` green, then rerun `./script/beta_readiness.sh --check-only` after current manual app proof refreshes. |
| Beta readiness | 60/100 | `./script/beta_readiness.sh --check-only`: model asset OK, runtime production gate OK, latency beta gate OK, redacted report export OK, issue template OK, clipboard fallback disabled OK, prompt app proof gate OK, visual placement proof OK, release prerequisites OK, private beta archive OK, and private beta packet OK. The command still found 2 blockers: stale manual app proof and notarized install proof. | The app is closer to beta, but it still cannot ship without current app proof and Apple notarization plus fresh-install Gatekeeper proof. | Refresh current manual proof, add signed/notarized install proof, rerun `./script/private_beta_packet.sh --check`, and finish with `./script/beta_readiness.sh --check-only`. |
| Test/proof coverage | 70/100 | `./script/check_test_coverage_manifest.sh`: verified. `./script/check_visual_placement_evidence.sh --require-all`: passed. `./script/check_runtime_network_egress_self_test.sh`: passed after the no-process failure path stopped crashing. `./script/select_latency_window_self_test.sh`: passed. `./script/latency_benchmark_report_self_test.sh`: passed. `./script/check_proof_manifest.sh --require-all`: failed with 7 issues. `./script/manual_smoke_status.sh --strict`: failed with 30 stale or pending app rows. | The coverage manifest, screenshot audit, latency selector tests, and egress verifier self-test are stronger, but current proof coverage is still incomplete. | Keep `./script/check_steadytype_scorecard.py`, `./script/check_proof_manifest.sh --require-all`, `./script/manual_smoke_status.sh --strict`, and `./script/beta_readiness.sh --check-only` in the loop until stale proof is refreshed. |

## Score Rules

- The overall score is the rounded average of the 12 row scores.
- A row with stale, blocked, missing, or failed evidence must stay visibly below green.
- A row can only rise when its evidence cell names a current command, trace slice,
  screenshot, proof manifest row, or documented manual gate.
- If a gate fails, the failure is evidence. Keep it in the row until the command
  actually passes.

## Loop Command

Run this before changing the score:

```bash
./script/check_steadytype_scorecard.py
./script/check_test_coverage_manifest.sh
./script/check_visual_placement_evidence.sh --require-all
./script/select_latency_window_self_test.sh
./script/latency_benchmark_report_self_test.sh
./script/check_proof_manifest.sh --require-all
./script/manual_smoke_status.sh --strict
./script/beta_readiness.sh --check-only
```
