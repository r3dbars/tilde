# TypeAhead-Informed Scorecard

Reviewed: 2026-05-26

Scores are repo-local judgment, not a public claim.

| Area | Before | After | Notes |
| --- | ---: | ---: | --- |
| Suggestion quality | 8 | 8.5 | Default visible length is now calmer at 3 words. |
| Timing | 8 | 8 | Existing timing lanes remain unchanged. |
| Non-annoyance | 8 | 8.5 | Safer silence copy reduces confusion; shorter defaults reduce visual noise. |
| Tab safety | 9 | 9 | `Tab` remains one-word accept. |
| Esc/snooze behavior | 8.5 | 8.5 | Existing field/session silence remains unchanged. |
| Sensitive-field suppression | 9 | 9.3 | Secure/search/URL/form/unknown reasons are now clearer. |
| Browser/form suppression | 8.5 | 9 | Form, URL, search, unproven, and unknown surfaces get plain explanations. |
| Visual placement | 8 | 8 | No placement changes in this pass. |
| Latency | 7.5 | 7.5 | No runtime changes in this pass. |
| Local-first/privacy | 9 | 9.2 | Settings now includes a direct local-only proof line for app-owned model use, raw-text default-off, and redacted Privacy Bundles. |
| Onboarding/trust | 8 | 8.7 | Settings/menu "why" is less internal. |
| Diagnostics | 8.5 | 8.8 | `silenceExplanation` is trace-safe metadata beside stable reason codes. |
| Beta readiness | 7.5 | 7.8 | Better default behavior, but proof gates still rule. |
| Test coverage | 9 | 9.2 | Added pure core tests for silence explanations, updated default tuning tests, and fixed the missing TextEdit AX proof helper. |

## Verification From This Pass

- `swift test --jobs 1`: passed, 1334 tests.
- `./script/check_test_coverage_manifest.sh`: passed.
- `./script/check_sensitive_field_proof_self_test.sh`: passed.
- `./script/check_trace_eval_self_test.sh`: passed.
- `./script/check_controls_diagnostics_readiness.sh`: passed.
- `./script/check_local_only_network_surface_self_test.sh`: passed.
- `bash -n script/real_app_smoke.sh`: passed.
- `./script/real_app_smoke_self_test.sh`: passed.
- `./script/smoke_test.sh`: blocked by stale scorecard proof after its earlier checks passed.
- `./script/fresh_latency_proof.sh --target textedit-model-latency --runs 1`: first exposed the missing TextEdit AX helper, then later failed in live TextEdit proof because the proof run lost a clean frontmost/model-timing path.

## Remaining Risks

- Full app smoke proof is still not green; run current-head TextEdit/Notes/Chrome proof before raising support claims.
- Settings and Diagnostics now have clearer text, but the field badge itself still does not show a detailed reason.
- Existing users with a saved `SuggestionMaxVisibleWords` default keep their saved setting until they reset tuning.
