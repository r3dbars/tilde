# Tilde and Tilde Lab

This repository has two product concepts and one allowed dependency direction.

## Tilde

Tilde is the software shipped to users:

- `Sources/TildeCore` — deterministic product policy and shared data types
- `Sources/TildeApp` — menu-bar app, local model lifecycle, storage, and diagnostics
- `Sources/InlineGhostIME` — IMKit input method and marked-text presentation

The `Tilde` and `InlineGhostIME` products may depend on `TildeCore`. They must
not depend on any Tilde Lab target.

## Tilde Lab

Tilde Lab is development-only software for testing and improving Tilde:

- `Sources/TildeLab` — macOS experiment interface
- `Sources/TildeLabCLI` — the `tilde-lab` command for durable experiments
- `Sources/TildeLabRunner` — unattended benchmark execution
- `Sources/TildeLabKit` — experiment design, execution, scoring, and reporting

Tilde Lab may depend on `TildeCore` so it can test the exact production policy.
That dependency never points the other way.

## Shipping boundary

`script/package_app.sh` packages Tilde, its input method, and the signed local
inference helper. It does not package Tilde Lab, its SQLite database, experiment
fixtures, campaign files, reports, or alternate models.

Tilde Lab writes experiment state under `~/Library/Application Support/Tilde
Lab`. Those files are local development artifacts and are not part of the Git
repository or the shipped Tilde application.
