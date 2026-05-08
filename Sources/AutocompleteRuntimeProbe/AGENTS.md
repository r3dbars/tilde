# Runtime Probe

This target is a local developer proof harness for the app-owned model runtime.

- Keep it non-interactive and safe to run from scripts.
- Do not add cloud inference, raw typed-text capture, or external model servers.
- Use the same app-owned model path and conservative completion defaults as the menu bar app.
- Emit diagnostics compatible with `script/model_latency_report.py`.
