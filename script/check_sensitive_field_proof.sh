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
    "government-id",
    "date-of-birth",
    "tax",
    "insurance",
    "medical",
    "crypto-wallet",
    "command-line",
    "api-key-like-text",
    "password-manager",
    "private-prompt",
    "private-search",
}
required_browser_surfaces = {
    "google-docs",
    "notion",
    "chatgpt",
    "slack",
    "discord",
    "browser-login",
    "browser-payment",
    "browser-password-manager",
    "browser-private-search",
    "browser-search-or-address-bar",
    "browser-developer-tool",
    "unproven-browser-surface",
}
raw_needles = [
    "sk-LOCALTEST",
    "4242 4242",
    "123456",
    "correct horse",
    "example.invalid",
    "1600 Amphitheatre",
    "123-45-6789",
    "01/02/1990",
    "12-3456789",
    "ABC123456",
    "Current medication",
    "abandon abandon",
    "rm -rf",
]

seen = set()
seen_browser_surfaces = set()
presented = []
unsafe_field_presentations = []
errors = []
unsafe_field_kinds = {"search", "form", "secure", "url", "unprovenSurface", "unknown"}

for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
    if not line.strip():
        continue
    event = json.loads(line)
    metadata = event.get("metadata") or {}
    category = metadata.get("sensitiveSuppressionCategory") or metadata.get("sensitiveFieldCategory")
    browser_surface = metadata.get("browserSurface")
    field_kind = metadata.get("fieldKind") or event.get("fieldKind")
    if event.get("type") == "suggestionPresented" and field_kind in unsafe_field_kinds:
        unsafe_field_presentations.append((line_number, field_kind))
    if browser_surface:
        if metadata.get("browserSurfaceDecision") != "blocked":
            errors.append(f"line {line_number}: browser surface {browser_surface} is not marked blocked")
        elif browser_surface in required_browser_surfaces:
            seen_browser_surfaces.add(browser_surface)
        if event.get("type") == "suggestionPresented":
            errors.append(f"line {line_number}: browser surface {browser_surface} was presented")
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
missing_browser_surfaces = sorted(required_browser_surfaces - seen_browser_surfaces)
if missing_browser_surfaces:
    errors.append("missing browser-hosted blocks: " + ", ".join(missing_browser_surfaces))
if presented:
    errors.append("sensitive presentations: " + ", ".join(f"line {line}:{category}" for line, category in presented))
if unsafe_field_presentations:
    errors.append("unsafe field presentations: " + ", ".join(f"line {line}:{field_kind}" for line, field_kind in unsafe_field_presentations))

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
