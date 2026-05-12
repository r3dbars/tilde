#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROOF_OUTPUT="$(mktemp -d "${TMPDIR:-/tmp}/steadytype-redacted-export-proof.XXXXXX")"
trap 'rm -rf "$PROOF_OUTPUT"' EXIT

swift test --filter 'RawTraceReportExportTests|PrivacyExportProofCommandTests'

AUTOCOMPLETE_LAB_REBUILD_PRIVACY_PROOF=1 \
AUTOCOMPLETE_LAB_PRIVACY_PROOF_OUTPUT="$PROOF_OUTPUT" \
  ./script/check_current_build_privacy_export.sh
