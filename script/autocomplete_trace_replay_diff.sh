#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <redacted-trace.jsonl> [AutocompleteTraceReplay args]" >&2
  exit 64
fi

swift run AutocompleteTraceReplay --decision-diff --one-brain-preview "$@"
