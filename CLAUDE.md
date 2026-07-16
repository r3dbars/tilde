# SteadyType Repository Guide

Read this with `AGENTS.md` and the guide pair in the folder you are editing.

SteadyType is a lightweight macOS writing assistant. Keep work centered on the
quiet suggest, accept, and dismiss loop; do not grow lab or research sprawl.

Canonical references:

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for system boundaries
- [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) for build, test, and release truth
- [`PRIVACY-BETA.md`](PRIVACY-BETA.md) for the privacy promise
- [`docs/product/compatibility-matrix.md`](docs/product/compatibility-matrix.md)
  and `docs/product/proof-manifest.json` for support policy and proof

Run `./script/proof.sh fast` before a PR or push. GitHub CI skips Swift, so run
Swift proof locally. `./script/build_and_run.sh --bundle-only` does not launch;
`--verify` launches the built app and checks process stability.

Keep raw typed text, prompts, output, screenshots, document names, URLs, and
recipients out of logs and docs unless the user explicitly opts into a bounded
local debug path. Pending manual proof stays pending.
