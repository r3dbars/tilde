#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Pure-logic self-test: percentile math, prompt/payload identity with the quality
# audit, template override, and terminator truncation. Needs no mlx_lm install.
python3 script/first_token_latency.py --self-test

echo "First-token latency self-test: PASS"
