# Replay Eval CLI

This folder contains the headless typing-replay and live-scorecard executable.

Never write prompts, corpus text, actual continuations, or model output to trend artifacts.
Malformed corpus rows may be skipped, but privacy-checking committed trend rows must fail closed.
Personalized evaluation must never train or retrieve from the same day as its replay case.
Every replay row records prompt format and raw-versus-gated quality separately.
