# Lightweight Budget

SteadyType should stay one small Mac app plus one local model. Size changes
that cross these limits need an explicit review instead of silently shipping.

## Blocking Budgets

| Surface | Budget | Enforced by |
| --- | ---: | --- |
| Release app bundle | 180,000,000 logical file bytes | `check_lightweight_budget.py --app-bundle` from the release bundle check |
| Pinned release model payload | 3,100,000,000 bytes | `check_lightweight_budget.py --source-only` in the fast proof gate |

The app bundle must contain exactly:

- `Contents/Info.plist`
- `Contents/MacOS/SteadyType`
- `Contents/MacOS/SteadyTypeTextEventHelper`
- `Contents/Resources/AppIcon.icns`
- `Contents/Resources/mlx-swift_Cmlx.bundle/default.metallib`
- `Contents/_CodeSignature/CodeResources`

This means two executables, no embedded model weights, no bundled frameworks
or dynamic libraries, and no developer-only products such as
`AutocompleteTraceReplay`.

## Fresh Main Baseline

Measured on 2026-07-16 from `origin/main` commit `ee4d556e` with a release
SwiftPM build on Apple Silicon, macOS 26.5, and Swift 6.3.3.

| Measurement | Result |
| --- | ---: |
| App bundle logical bytes | 163,610,786 bytes |
| MLX Metal library | 107,370,314 bytes |
| Main app executable | 55,373,456 bytes |
| Text-event helper | 112,096 bytes |
| Pinned Qwen 3.5 4B payload | 3,061,129,077 bytes |
| Installed model directory, including local receipt/cache metadata | 3,061,131,995 bytes |

The app cap leaves about 10% headroom. The model cap is intentionally tighter:
changing model files or their pinned sizes should force a review.

## Local Runtime Measurements

These measurements are informational because they vary by hardware, OS state,
filesystem cache, permissions, and model readiness. They do not block CI.

- First post-build launch to `applicationDidFinishLaunching`: 1,746.6 ms
  (one run; filesystem caches were not purged).
- Warm launch: 402.3 ms median across five runs; 467.4 ms maximum.
- Late idle CPU: 1.4% median and 1.5% maximum across six 5-second samples.
- Late idle resident memory: 345 MB for all six samples.

The current release model check pins Qwen 3.5 4B, while the runtime default at
this commit points at a missing Gemma asset. The launch and idle measurements
therefore describe the shipped app with its model runtime unavailable, not a
loaded inference session. Resolve that product-policy drift separately before
using these numbers as model-loaded runtime evidence.

No manual typing, Accessibility, hardware interaction, or model-loaded proof
was run for this budget baseline.

## Commands

```bash
python3 script/check_lightweight_budget.py --source-only
bash script/check_lightweight_budget_self_test.sh
python3 script/check_lightweight_budget.py --app-bundle dist/SteadyType.app
```
