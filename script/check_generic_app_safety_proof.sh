#!/usr/bin/env bash
set -euo pipefail

# Validates a redacted trace for the default-on "Generic App" fallback. The
# generic fallback widened suggestion + native-AX insertion to arbitrary apps
# without a custom profile, so this gate proves two things across a battery of
# unknown apps:
#   (a) zero wrong-field insertions  - no suggestion is presented into a field
#       kind we cannot positively classify as a safe compose surface, and
#   (b) sensitive-field suppression  - secure / password / payment / search /
#       URL / login / form / prompt fields stay silent under the fallback.
# It pairs with GenericAppSafetyProofHarness (core) and never accepts raw text.

trace_path="${1:-${AUTOCOMPLETE_LAB_GENERIC_APP_TRACE_PATH:-${AUTOCOMPLETE_LAB_TRACE_PATH:-}}}"
if [[ -z "$trace_path" || ! -f "$trace_path" ]]; then
  echo "usage: $0 <redacted-trace.jsonl>" >&2
  exit 2
fi

python3 - "$trace_path" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

# Wrong/sensitive surfaces that must stay silent under the generic fallback.
required_silent = {
    "secure-field",
    "password",
    "payment",
    "search",
    "url-address",
    "login",
    "form-field",
    "command-prompt",
    "unknown-field",
}
# Safe compose controls that must still present, so the gate is not trivially
# satisfied by blocking everything.
required_present = {
    "multiline-compose",
    "singleline-compose",
}
# Field kinds we can never positively classify as a safe compose surface.
unsafe_field_kinds = {"search", "form", "secure", "url", "unprovenSurface", "unknown"}
# Raw typed text that must never reach a redacted trace.
raw_needles = [
    "the quick brown fox",
    "Let me jot down a quick",
    "thanks so much for the",
    "4242 4242",
    "sk-LOCALTEST",
]

seen_silent = set()
seen_present = set()
wrong_field_presentations = []
errors = []

for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
    if not line.strip():
        continue
    event = json.loads(line)
    metadata = event.get("metadata") or {}
    category = metadata.get("genericAppFieldCategory")
    if not category:
        continue

    event_type = event.get("type")
    field_kind = metadata.get("fieldKind") or event.get("fieldKind")
    expectation = metadata.get("genericAppExpectation")

    if event_type == "suggestionPresented" and field_kind in unsafe_field_kinds:
        wrong_field_presentations.append((line_number, category, field_kind))

    if metadata.get("genericAppFallbackResolved") != "true":
        errors.append(f"line {line_number}: {category} did not resolve to the generic fallback")
    if metadata.get("rawTextIncluded") != "false":
        errors.append(f"line {line_number}: {category} is missing rawTextIncluded=false")

    if expectation == "silent":
        seen_silent.add(category)
        if event_type == "suggestionPresented":
            errors.append(f"line {line_number}: silent field {category} was presented")
        if metadata.get("genericAppRouterDecision") != "suppressed":
            errors.append(f"line {line_number}: {category} router decision is not suppressed")
        if metadata.get("genericAppLiveDecision") != "blocked":
            errors.append(f"line {line_number}: {category} live decision is not blocked")
    elif expectation == "present":
        seen_present.add(category)
        if event_type != "suggestionPresented":
            errors.append(f"line {line_number}: compose control {category} was not presented")
        if metadata.get("genericAppRouterDecision") != "allowed":
            errors.append(f"line {line_number}: {category} router decision is not allowed")
        if metadata.get("genericAppLiveDecision") != "presented":
            errors.append(f"line {line_number}: {category} live decision is not presented")
    else:
        errors.append(f"line {line_number}: {category} has unknown expectation {expectation!r}")

missing_silent = sorted(required_silent - seen_silent)
if missing_silent:
    errors.append("missing suppressed categories: " + ", ".join(missing_silent))
missing_present = sorted(required_present - seen_present)
if missing_present:
    errors.append("missing presented compose controls: " + ", ".join(missing_present))
if wrong_field_presentations:
    errors.append(
        "wrong-field presentations: "
        + ", ".join(f"line {line}:{category}/{kind}" for line, category, kind in wrong_field_presentations)
    )

contents = path.read_text(encoding="utf-8")
for needle in raw_needles:
    if needle in contents:
        errors.append(f"raw fixture text leaked: {needle}")

if errors:
    print("Generic app safety proof failed:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    sys.exit(1)

print("Generic app safety proof passed.")
PY
