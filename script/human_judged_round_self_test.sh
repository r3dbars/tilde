#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT="$(script/human_judged_round.py --self-test)"
grep -q "Human judged round scaffold: PASS" <<<"$OUTPUT"
echo "$OUTPUT"
