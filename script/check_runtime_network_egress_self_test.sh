#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

NO_EGRESS="$TMP_DIR/no-egress.lsof"
REMOTE_EGRESS="$TMP_DIR/remote-egress.lsof"
MODEL_SETUP="$TMP_DIR/model-setup.lsof"
MODEL_SETUP_UNEXPECTED="$TMP_DIR/model-setup-unexpected.lsof"
FRESH_PROOF="$TMP_DIR/fresh-proof.json"
STALE_PROOF="$TMP_DIR/stale-proof.json"
MODEL_PHASE_PROOF="$TMP_DIR/model-phase-proof.json"
LATEST_LAUNCH_LOG="$TMP_DIR/latest-launch.log"
HASHED_LAUNCH_LOG="$TMP_DIR/hashed-launch.log"

cat >"$NO_EGRESS" <<'EOF'
COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
Autocomplete 42 user   12u  IPv4 0xabc      0t0  TCP 127.0.0.1:50100->127.0.0.1:50101 (ESTABLISHED)
Autocomplete 42 user   13u  IPv6 0xdef      0t0  TCP [::1]:50102->[::1]:50103 (ESTABLISHED)
EOF

cat >"$REMOTE_EGRESS" <<'EOF'
COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
Autocomplete 42 user   12u  IPv4 0xabc      0t0  TCP 192.168.1.10:50100->203.0.113.10:443 (ESTABLISHED)
EOF

cat >"$MODEL_SETUP" <<'EOF'
COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
Autocomplete 42 user   12u  IPv4 0xabc      0t0  TCP 192.168.1.10:50100->huggingface.co:443 (ESTABLISHED)
Autocomplete 42 user   13u  IPv4 0xdef      0t0  TCP 192.168.1.10:50101->cdn-lfs.huggingface.co:443 (ESTABLISHED)
EOF

cat >"$MODEL_SETUP_UNEXPECTED" <<'EOF'
COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
Autocomplete 42 user   12u  IPv4 0xabc      0t0  TCP 192.168.1.10:50100->example.com:443 (ESTABLISHED)
EOF

./script/check_runtime_network_egress.py \
  --pid "$$" \
  --sample "$NO_EGRESS" \
  --phase autocomplete \
  --proof-out "$TMP_DIR/no-egress.md" \
  --json-out "$TMP_DIR/no-egress.json" \
  --activity-note "typed from /Users/redbars/private-draft.md with secret note" \
  >"$TMP_DIR/no-egress.out"

if ! grep -F "Runtime network egress proof: PASS" "$TMP_DIR/no-egress.out" >/dev/null; then
  echo "runtime network self-test expected no-egress autocomplete fixture to pass" >&2
  cat "$TMP_DIR/no-egress.out" >&2
  exit 1
fi

if ! grep -F "Unexpected remote endpoints: \`0\`" "$TMP_DIR/no-egress.md" >/dev/null; then
  echo "runtime network self-test expected proof artifact to record zero unexpected endpoints" >&2
  cat "$TMP_DIR/no-egress.md" >&2
  exit 1
fi

for artifact in "$TMP_DIR/no-egress.md" "$TMP_DIR/no-egress.json"; do
  for forbidden in \
    "/Users/redbars/private-draft.md" \
    "typed from" \
    "$ROOT_DIR" \
    "check_runtime_network_egress_self_test.sh"; do
    if grep -F "$forbidden" "$artifact" >/dev/null; then
      echo "runtime network self-test found unredacted proof metadata in $artifact: $forbidden" >&2
      cat "$artifact" >&2
      exit 1
    fi
  done
done

if ! grep -F "Command line: \`String(" "$TMP_DIR/no-egress.md" >/dev/null; then
  echo "runtime network self-test expected command line to be summarized in markdown" >&2
  cat "$TMP_DIR/no-egress.md" >&2
  exit 1
fi

if ! grep -F '"command_summary": "String(' "$TMP_DIR/no-egress.json" >/dev/null; then
  echo "runtime network self-test expected command line to be summarized in json" >&2
  cat "$TMP_DIR/no-egress.json" >&2
  exit 1
fi

./script/check_runtime_network_egress.py \
  --validate-proof "$TMP_DIR/no-egress.json" \
  --max-proof-age-seconds 315360000 \
  --min-samples 1 \
  >"$TMP_DIR/validate-current.out"

if ! grep -F "Runtime network egress proof validation: PASS" "$TMP_DIR/validate-current.out" >/dev/null; then
  echo "runtime network self-test expected generated proof validation to pass" >&2
  cat "$TMP_DIR/validate-current.out" >&2
  exit 1
fi

./script/check_runtime_network_egress.py \
  --validate-proof "$TMP_DIR/no-egress.md" \
  --max-proof-age-seconds 315360000 \
  --min-samples 1 \
  >"$TMP_DIR/validate-current-markdown.out"

if ! grep -F "Runtime network egress proof validation: PASS" "$TMP_DIR/validate-current-markdown.out" >/dev/null; then
  echo "runtime network self-test expected generated markdown proof validation to pass" >&2
  cat "$TMP_DIR/validate-current-markdown.out" >&2
  exit 1
fi

cat >"$FRESH_PROOF" <<'JSON'
{
  "generated_at": "2026-05-13T05:05:00+00:00",
  "phase": "autocomplete",
  "result": "pass",
  "samples": 30,
  "unexpected_remote_endpoint_count": 0,
  "processes": [
    {
      "executable_sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ]
}
JSON

cat >"$STALE_PROOF" <<'JSON'
{
  "generated_at": "2026-05-11T05:05:00+00:00",
  "phase": "autocomplete",
  "result": "pass",
  "samples": 30,
  "unexpected_remote_endpoint_count": 0
}
JSON

cat >"$MODEL_PHASE_PROOF" <<'JSON'
{
  "generated_at": "2026-05-13T05:05:00+00:00",
  "phase": "model-setup",
  "result": "pass",
  "samples": 30,
  "unexpected_remote_endpoint_count": 0
}
JSON

cat >"$LATEST_LAUNCH_LOG" <<'LOG'
2026-05-13T05:00:00Z launch accessibility=true
2026-05-13T05:00:01Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit nativeRuntimeAvailable=true
LOG

cat >"$HASHED_LAUNCH_LOG" <<'LOG'
2026-05-13T05:00:00Z launch accessibility=true executableSHA256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
2026-05-13T05:30:00Z launch accessibility=true executableSHA256=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
LOG

./script/check_runtime_network_egress.py \
  --validate-proof "$FRESH_PROOF" \
  --diagnostics-log "$LATEST_LAUNCH_LOG" \
  --require-newer-than-latest-launch \
  --max-proof-age-seconds 86400 \
  --now "2026-05-13T06:00:00Z" \
  --min-samples 10 \
  >"$TMP_DIR/validate-fresh.out"

if ! grep -F "Autocomplete no-egress proof is fresh enough" "$TMP_DIR/validate-fresh.out" >/dev/null; then
  echo "runtime network self-test expected fresh no-egress proof validation to pass" >&2
  cat "$TMP_DIR/validate-fresh.out" >&2
  exit 1
fi

if ./script/check_runtime_network_egress.py \
  --validate-proof "$STALE_PROOF" \
  --max-proof-age-seconds 86400 \
  --now "2026-05-13T06:00:00Z" \
  --min-samples 10 \
  >"$TMP_DIR/validate-stale.out" 2>"$TMP_DIR/validate-stale.err"; then
  echo "runtime network self-test expected stale no-egress proof to fail validation" >&2
  exit 1
fi

if ! grep -F "no-egress proof is stale" "$TMP_DIR/validate-stale.err" >/dev/null; then
  echo "runtime network self-test expected stale proof failure output" >&2
  cat "$TMP_DIR/validate-stale.err" >&2
  exit 1
fi

if ./script/check_runtime_network_egress.py \
  --validate-proof "$STALE_PROOF" \
  --diagnostics-log "$LATEST_LAUNCH_LOG" \
  --require-newer-than-latest-launch \
  --max-proof-age-seconds 315360000 \
  --now "2026-05-13T06:00:00Z" \
  --min-samples 10 \
  >"$TMP_DIR/validate-before-launch.out" 2>"$TMP_DIR/validate-before-launch.err"; then
  echo "runtime network self-test expected proof before latest launch to fail validation" >&2
  exit 1
fi

if ! grep -F "older than latest runtime launch" "$TMP_DIR/validate-before-launch.err" >/dev/null; then
  echo "runtime network self-test expected latest-launch staleness failure output" >&2
  cat "$TMP_DIR/validate-before-launch.err" >&2
  exit 1
fi

./script/check_runtime_network_egress.py \
  --validate-proof "$FRESH_PROOF" \
  --diagnostics-log "$HASHED_LAUNCH_LOG" \
  --require-newer-than-latest-launch \
  --expected-executable-sha256 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --max-proof-age-seconds 86400 \
  --now "2026-05-13T06:00:00Z" \
  --min-samples 10 \
  >"$TMP_DIR/validate-hashed-launch.out"

if ! grep -F "Runtime network egress proof validation: PASS" "$TMP_DIR/validate-hashed-launch.out" >/dev/null; then
  echo "runtime network self-test expected later different-executable launches not to stale the proof" >&2
  cat "$TMP_DIR/validate-hashed-launch.out" >&2
  exit 1
fi

if ./script/check_runtime_network_egress.py \
  --validate-proof "$MODEL_PHASE_PROOF" \
  --max-proof-age-seconds 86400 \
  --now "2026-05-13T06:00:00Z" \
  --min-samples 10 \
  >"$TMP_DIR/validate-model-phase.out" 2>"$TMP_DIR/validate-model-phase.err"; then
  echo "runtime network self-test expected model-setup proof to fail autocomplete validation" >&2
  exit 1
fi

if ! grep -F "does not prove autocomplete no-egress" "$TMP_DIR/validate-model-phase.err" >/dev/null; then
  echo "runtime network self-test expected model phase validation failure output" >&2
  cat "$TMP_DIR/validate-model-phase.err" >&2
  exit 1
fi

if ./script/check_runtime_network_egress.py \
  --validate-proof "$TMP_DIR/missing-proof.json" \
  >"$TMP_DIR/validate-missing.out" 2>"$TMP_DIR/validate-missing.err"; then
  echo "runtime network self-test expected missing no-egress proof to fail validation" >&2
  exit 1
fi

if ! grep -F "missing no-egress proof" "$TMP_DIR/validate-missing.err" >/dev/null; then
  echo "runtime network self-test expected missing proof failure output" >&2
  cat "$TMP_DIR/validate-missing.err" >&2
  exit 1
fi

if ./script/check_runtime_network_egress.py \
  --sample "$REMOTE_EGRESS" \
  --phase autocomplete \
  --no-proof \
  >"$TMP_DIR/remote-egress.out" 2>"$TMP_DIR/remote-egress.err"; then
  echo "runtime network self-test expected autocomplete remote egress fixture to fail" >&2
  exit 1
fi

if ! grep -F "Unexpected autocomplete-time egress" "$TMP_DIR/remote-egress.err" >/dev/null; then
  echo "runtime network self-test expected failure to name autocomplete-time egress" >&2
  cat "$TMP_DIR/remote-egress.err" >&2
  exit 1
fi

./script/check_runtime_network_egress.py \
  --sample "$MODEL_SETUP" \
  --phase model-setup \
  --proof-out "$TMP_DIR/model-setup.md" \
  >"$TMP_DIR/model-setup.out"

for expected in \
  "Runtime network egress proof: PASS" \
  "Allowed model setup/update endpoints: 2"; do
  if ! grep -F "$expected" "$TMP_DIR/model-setup.out" >/dev/null; then
    echo "runtime network self-test missing expected model-setup output: $expected" >&2
    cat "$TMP_DIR/model-setup.out" >&2
    exit 1
  fi
done

if ! grep -F "Only allowlisted model setup/update endpoints are permitted" "$TMP_DIR/model-setup.md" >/dev/null; then
  echo "runtime network self-test expected model setup proof to distinguish allowed setup traffic" >&2
  cat "$TMP_DIR/model-setup.md" >&2
  exit 1
fi

if ./script/check_runtime_network_egress.py \
  --sample "$MODEL_SETUP_UNEXPECTED" \
  --phase model-setup \
  --no-proof \
  >"$TMP_DIR/model-setup-unexpected.out" 2>"$TMP_DIR/model-setup-unexpected.err"; then
  echo "runtime network self-test expected non-allowlisted model setup fixture to fail" >&2
  exit 1
fi

if ! grep -F "Unexpected model setup/update egress" "$TMP_DIR/model-setup-unexpected.err" >/dev/null; then
  echo "runtime network self-test expected failure to name model setup/update egress" >&2
  cat "$TMP_DIR/model-setup-unexpected.err" >&2
  exit 1
fi

echo "Runtime network egress self-test passed."
