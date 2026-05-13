#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MANIFEST_PATH="${AUTOCOMPLETE_LAB_PROOF_MANIFEST:-docs/product/proof-manifest.json}"
MANUAL_SMOKE_PATH="${AUTOCOMPLETE_LAB_MANUAL_SMOKE_RUNS:-docs/product/manual-smoke-runs.md}"
CHECK_SCRIPT="${AUTOCOMPLETE_LAB_PROMPT_PROOF_GATE_SCRIPT:-./script/check_prompt_app_proof.sh}"

CLAIMS_FILE="$(mktemp)"
trap 'rm -f "$CLAIMS_FILE"' EXIT

python3 - "$MANIFEST_PATH" "$MANUAL_SMOKE_PATH" >"$CLAIMS_FILE" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
manual_smoke_path = Path(sys.argv[2])

prompt_bundles = {
    "com.openai.codex",
    "com.anthropic.claude-code",
    "com.anthropic.claudefordesktop",
    "com.openai.chat",
    "com.openai.ChatGPT",
    "com.openai.atlas",
    "com.tinyspeck.slackmacgap",
    "com.hnc.Discord",
    "com.hnc.DiscordPTB",
    "com.hnc.DiscordCanary",
    "ru.keepcoder.Telegram",
}


def fail(message: str) -> None:
    print(f"Prompt app manifest proof gate failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def clean_cell(value: str) -> str:
    return value.strip().strip("`").strip()


def parse_smoke_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        fail(f"missing manual smoke file: {path}")

    rows: list[dict[str, str]] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("|") or "---" in line:
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 8 or cells[0].lower() == "date":
            continue
        diagnostics_cell = cells[-2]
        trace_cell = cells[-1]
        modes_cell = "|".join(cells[5:-2])
        rows.append(
            {
                "date": cells[0],
                "app": clean_cell(cells[1]),
                "bundle": clean_cell(cells[2]),
                "proof": clean_cell(cells[3]) or "default",
                "accepts": clean_cell(cells[4]),
                "modes": clean_cell(modes_cell),
                "diagnostics": diagnostics_cell,
                "trace": trace_cell,
            }
        )
    return rows


def trace_reference(row: dict[str, str]) -> tuple[str, str, str] | None:
    match = re.search(r"lines\s+(\d+)-(\d+)\s+in\s+`([^`]+)`", row["trace"])
    if not match:
        return None
    return match.group(3), match.group(1), match.group(2)


def is_prompt_claim(surface: dict, claim: dict) -> bool:
    bundle = str(claim.get("bundle", "")).strip()
    proof = str(claim.get("proof", "")).strip().lower()
    surface_name = str(surface.get("surface", "")).strip().lower()
    return bundle in prompt_bundles or (
        bundle == "com.google.Chrome"
        and (proof == "chat-like" or "chrome chat-like" in surface_name)
    )


def prompt_claims_from_complete_requirements(surface_name: str, surface: dict) -> list[tuple[str, dict]]:
    claims: list[tuple[str, dict]] = []
    requirements = surface.get("requirements")
    if not isinstance(requirements, list):
        return claims

    for requirement in requirements:
        if not isinstance(requirement, dict) or requirement.get("status") != "complete":
            continue
        requirement_name = str(requirement.get("id") or requirement.get("summary") or "requirement")
        manual_smoke = requirement.get("manualSmoke")
        if isinstance(manual_smoke, dict) and is_prompt_claim(surface, manual_smoke):
            claims.append((f"{surface_name} / {requirement_name}", manual_smoke))
        variants = requirement.get("manualSmokeVariants")
        if isinstance(variants, list):
            for variant in variants:
                if isinstance(variant, dict) and is_prompt_claim(surface, variant):
                    claims.append((f"{surface_name} / {requirement_name}", variant))

    return claims


def complete_prompt_claims(manifest: dict) -> list[tuple[str, dict]]:
    claims: list[tuple[str, dict]] = []
    for surface in manifest.get("surfaces", []):
        if not isinstance(surface, dict):
            continue
        surface_name = str(surface.get("surface", "unnamed surface"))
        claims.extend(prompt_claims_from_complete_requirements(surface_name, surface))
        if surface.get("status") != "complete":
            continue
        manual_smoke = surface.get("manualSmoke")
        if isinstance(manual_smoke, dict) and is_prompt_claim(surface, manual_smoke):
            claims.append((surface_name, manual_smoke))
        variants = surface.get("manualSmokeVariants")
        if isinstance(variants, list):
            for variant in variants:
                if isinstance(variant, dict) and is_prompt_claim(surface, variant):
                    claims.append((surface_name, variant))
    return claims


if not manifest_path.exists():
    fail(f"missing proof manifest: {manifest_path}")

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
smoke_rows = parse_smoke_rows(manual_smoke_path)
claims = complete_prompt_claims(manifest)
if not claims:
    fail("no complete prompt-app manual smoke claims found in the proof manifest")

for surface_name, claim in claims:
    app = str(claim.get("app", "")).strip()
    bundle = str(claim.get("bundle", "")).strip()
    proof = str(claim.get("proof", "default")).strip() or "default"
    matches = [
        row
        for row in smoke_rows
        if row["app"] == app
        and row["bundle"] == bundle
        and row["proof"] == proof
        and "strict-complete" in row["trace"]
        and trace_reference(row) is not None
    ]
    if bundle == "com.openai.codex":
        matches = [
            row for row in matches
            if "prompt no-submit confirmed" in row["trace"]
        ]
    if not matches:
        fail(f"{surface_name}: no bounded strict prompt smoke row for {app} {bundle} proof={proof}")

    row = matches[-1]
    trace_path, start_line, end_line = trace_reference(row) or ("", "", "")
    print("\t".join([surface_name, trace_path, start_line, end_line, bundle, proof]))
PY

claim_count=0
failure_count=0
echo "Prompt app manifest proof status"
while IFS=$'\t' read -r surface trace_path start_line end_line bundle proof; do
  [[ -n "$surface" ]] || continue
  claim_count=$((claim_count + 1))
  echo "- $surface: $bundle proof=$proof lines $start_line-$end_line"
  if ! "$CHECK_SCRIPT" \
    --trace "$trace_path" \
    --start-line "$start_line" \
    --end-line "$end_line" \
    --bundle "$bundle" \
    --surface "$proof"; then
    failure_count=$((failure_count + 1))
  fi
done <"$CLAIMS_FILE"

if ((claim_count == 0)); then
  echo "Prompt app manifest proof gate failed: no prompt claims emitted" >&2
  exit 1
fi

if ((failure_count > 0)); then
  echo "Prompt app manifest proof gate failed with $failure_count failing prompt slice(s)." >&2
  exit 1
fi

echo "Prompt app manifest proof gate passed with $claim_count bounded prompt slice(s)."
