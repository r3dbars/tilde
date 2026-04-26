#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift test
./script/build_and_run.sh --verify
./script/check_diagnostics_log.sh

echo
echo "Manual app smoke checklist: docs/product/manual-smoke-checklist.md"
echo "Diagnostics log: $HOME/Library/Logs/AutocompleteLab/diagnostics.log"
