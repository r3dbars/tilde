#!/usr/bin/env bash
set -euo pipefail

trace_path="${1:-${AUTOCOMPLETE_LAB_SENSITIVE_TRACE_PATH:-${AUTOCOMPLETE_LAB_TRACE_PATH:-}}}"
if [[ -z "$trace_path" || ! -f "$trace_path" ]]; then
  echo "usage: $0 <redacted-trace.jsonl>" >&2
  exit 2
fi

python3 - "$trace_path" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
required = {
    "password",
    "otp",
    "payment",
    "login",
    "search",
    "url-address",
    "address",
    "command-line",
    "api-key-like-text",
    "password-manager",
    "private-prompt",
    "private-search",
}
raw_needles = [
    "sk-LOCALTEST",
    "4242 4242",
    "123456",
    "correct horse",
    "example.invalid",
    "1600 Amphitheatre",
    "rm -rf",
]

seen = set()
presented = []
errors = []

for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
    if not line.strip():
        continue
    event = json.loads(line)
    metadata = event.get("metadata") or {}
    category = metadata.get("sensitiveSuppressionCategory") or metadata.get("sensitiveFieldCategory")
    if not category:
        continue

    if event.get("type") == "suggestionPresented":
        presented.append((line_number, category))
        continue

    seen.add(category)
    if metadata.get("sensitiveSuppressionDecision") != "blocked":
        errors.append(f"line {line_number}: {category} is not marked blocked")
    if not metadata.get("sensitiveSuppressionProof"):
        errors.append(f"line {line_number}: {category} is missing proof level")

missing = sorted(required - seen)
if missing:
    errors.append("missing sensitive categories: " + ", ".join(missing))
if presented:
    errors.append("sensitive presentations: " + ", ".join(f"line {line}:{category}" for line, category in presented))

contents = path.read_text(encoding="utf-8")
for needle in raw_needles:
    if needle in contents:
        errors.append(f"raw fixture text leaked: {needle}")

if errors:
    print("Sensitive field proof failed:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    sys.exit(1)

print("Sensitive field proof passed.")
PY
