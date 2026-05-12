# SteadyType Product Scorecard

Updated: 2026-05-12.
Base app/source evidence checked at `8d0b3a1cd15d`.
Overall score: 64/100.

This is the single current product scorecard. Older scorecards are historical
inputs only. Do not raise a score unless the evidence in the row changes.
Stale proof can explain progress, but it cannot make a row green.
This worktree also had unrelated uncommitted changes during scoring; this file
only counts the command output named below.

## Scores

| Area | Score | Evidence | Why It Is Not Higher | Next Proof |
| --- | ---: | --- | --- | --- |
| Suggestion quality | 78/100 | `./script/check_quality_eval.sh` on 2026-05-12: completion, word-completion, and offline-model quality suites passed; the final build phase then failed after a concurrent `AppDelegate.swift` modification. `docs/evals/completion-prediction-quality-500-2026-05-11.md` remains the deterministic corpus input. | Deterministic quality is strong, but the latest full command did not end green, and local model dogfood evidence is still opt-in. | Rerun `./script/check_quality_eval.sh` from a stable worktree, then add a short `AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 ./script/local_quality_audit.py` report without durable raw prompt text. |
| Placement | 70/100 | `./script/check_visual_placement_evidence.sh --require-all`: 22 screenshot files verified. `./script/manual_smoke_status.sh --strict`: 30 target app passes are stale or pending on this head. | Screenshot files exist, but current-head app proof is stale for most lanes, and Obsidian long-note plus Monaco default AX remain open. | Use `./script/manual_smoke_status.sh --strict` to pick the next stale lane, rerun the listed `./script/real_app_smoke.sh` command with screenshot tracing, then rerun `./script/check_visual_placement_evidence.sh --require-all`. |
| Tab safety | 72/100 | `./script/beta_readiness.sh --check-only`: prompt app proof gate passed with accidental submit, send-key collision, prompt mutation, wrong-context insertion, and content violation counts at 0. The same run says manual app proof is blocked by stale rows. | One-word Tab proof is safer than before, but full accept stays disabled for prompt apps and current-head accept proof is stale across the main app lanes. | Refresh Codex, Claude Code, and Claude desktop one-word no-submit lanes from `./script/manual_smoke_status.sh --strict`, then keep full accept disabled until a dedicated no-submit full-accept gate exists. |
| Latency | 52/100 | `./script/beta_readiness.sh --check-only`: latency beta gate blocked; first-visible p99 was 1546 ms against a 750 ms budget, and AX p99-window budget exceeded the allowed count. | Median behavior is usable in the trace, but the tail is too slow for beta trust. | Run `./script/latency_benchmark_report.py --beta-gate` after fixing the late Notes slice and AX slow windows, then rerun `./script/beta_readiness.sh --check-only`. |
| Privacy | 74/100 | `./script/beta_readiness.sh --check-only`: clipboard fallback disabled OK, issue template OK, prompt app proof gate OK, but redacted report export blocked when `AppDelegate.swift` changed during the Swift build. `docs/product/beta-privacy-data-checklist.md` documents the privacy review surface. | The privacy design is solid, but the current-build privacy export did not complete in this run. | Rerun `./script/check_current_build_privacy_export.sh --privacy-export-proof`, `./script/check_runtime_network_egress.py`, and the beta readiness gate from a stable worktree. |
| App coverage | 55/100 | `./script/check_proof_manifest.sh --require-all`: 7 complete surfaces, 6 partial surfaces, and 7 manifest issues. `./script/manual_smoke_status.sh --strict`: 30 stale or pending target app passes. | Coverage is broad on paper, but many rows are not current proof and several high-risk app classes stay intentionally blocked. | Close one proof-manifest pending requirement at a time, starting with current safe lanes before prompt apps or production browser editors. |
| Onboarding | 64/100 | Documented manual gate: `docs/product/onboarding-permission-qa-checklist.md`. Product docs also point testers to `docs/product/manual-smoke-checklist.md`. | The first-run path is documented, but there is no current tester-walkthrough proof tying Accessibility, model readiness, TextEdit practice, pause, and trace deletion into one fresh run. | Record one guided TextEdit practice run and update the checklist with command output or a manual gate row. |
| Controls | 76/100 | Documented manual gate: `docs/product/privacy-and-controls.md`. `./script/beta_readiness.sh --check-only` confirms clipboard fallback insertion is disabled. | Pause/delete/export controls exist, but the latest score run did not prove state parity across Settings, menu bar, and Diagnostics. | Run focused control-surface tests or a documented manual gate that toggles pause, disabled apps, trace delete, and redacted export from all visible surfaces. |
| Diagnostics | 70/100 | `./script/beta_readiness.sh --check-only`: runtime production gate OK and diagnostics log verified, but redacted report export blocked after a concurrent `AppDelegate.swift` modification during build. | Launch diagnostics are readable now, but export verification still needs a clean build pass. | Rerun `./script/check_diagnostics_log.sh`, then rerun `./script/check_current_build_privacy_export.sh --privacy-export-proof` from a stable worktree. |
| Model readiness | 50/100 | `./script/beta_readiness.sh --check-only`: runtime production gate OK with MLX metadata, but model asset check failed because `.steadytype-model-integrity.json` was missing from the expected Qwen3.5 4B MLX folder. | The app-owned runtime is visible, but this host cannot prove the pinned model asset integrity receipt. | Install or repair the model with `./script/download_mlx_model.py --model qwen35-4b`, then rerun `./script/check_model_asset.py` and `./script/beta_readiness.sh --check-only`. |
| Beta readiness | 38/100 | `./script/beta_readiness.sh --check-only`: 6 blockers, including model asset integrity, latency, redacted export build, stale manual app proof, missing notarized install proof, and private beta packet signing. Release prerequisites also report missing `NOTARYTOOL_PROFILE`. | The archive exists now, but beta still cannot be called ready while integrity, latency, proof, notarization, and signing gates are open. | Clear the beta readiness blockers in order, then run `./script/private_beta_packet.sh` and `./script/beta_readiness.sh --check-only`. |
| Test/proof coverage | 66/100 | `./script/check_test_coverage_manifest.sh`: verified. `./script/check_visual_placement_evidence.sh --require-all`: passed. `./script/check_proof_manifest.sh --require-all`: failed with 7 issues. `./script/manual_smoke_status.sh --strict`: failed with 30 stale or pending app rows. | The coverage manifest and screenshot audit are strong, but current proof coverage is still incomplete. | Keep `./script/check_steadytype_scorecard.py`, `./script/check_proof_manifest.sh --require-all`, and `./script/manual_smoke_status.sh --strict` in the loop until stale proof is refreshed. |

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
./script/check_proof_manifest.sh --require-all
./script/manual_smoke_status.sh --strict
./script/beta_readiness.sh --check-only
```
