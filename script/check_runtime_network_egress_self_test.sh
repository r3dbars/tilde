#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

NO_EGRESS="$TMP_DIR/no-egress.lsof"
REMOTE_EGRESS="$TMP_DIR/remote-egress.lsof"
MODEL_SETUP="$TMP_DIR/model-setup.lsof"

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

./script/check_runtime_network_egress.py \
  --sample "$NO_EGRESS" \
  --phase autocomplete \
  --proof-out "$TMP_DIR/no-egress.md" \
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

if ! grep -F "Remote endpoints are classified as model setup/update traffic" "$TMP_DIR/model-setup.md" >/dev/null; then
  echo "runtime network self-test expected model setup proof to distinguish allowed setup traffic" >&2
  cat "$TMP_DIR/model-setup.md" >&2
  exit 1
fi

echo "Runtime network egress self-test passed."
