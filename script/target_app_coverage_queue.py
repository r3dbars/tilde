#!/usr/bin/env python3
"""Print the next target-app coverage lanes without widening support claims."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT_DIR / "docs/product/proof-manifest.json"


@dataclass(frozen=True)
class CoverageLane:
    rank: int
    surface: str
    value: str
    proof_risk: str
    current_stance: str
    smallest_proof_lane: str


LANE_ORDER: tuple[CoverageLane, ...] = (
    CoverageLane(
        rank=1,
        surface="Obsidian broader vault layouts",
        value="High",
        proof_risk="Low-Medium",
        current_stance="Supported only for current disposable proof lanes; broader vault variance stays yellow.",
        smallest_proof_lane=(
            "Run one disposable Obsidian hidden-caret or native-undo variant with strict screenshot,"
            " one-word Tab, full accept, verified insertion, and undo/recovery."
        ),
    ),
    CoverageLane(
        rank=2,
        surface="TextEdit and Notes polish variants",
        value="Medium-High",
        proof_risk="Low",
        current_stance="Beta-safe when strict smoke is current; extra variants harden the boring core.",
        smallest_proof_lane=(
            "Refresh TextEdit wrapped/narrow and one Notes undo variant with strict screenshot,"
            " verified one-word/full accept, and native undo evidence."
        ),
    ),
    CoverageLane(
        rank=3,
        surface="Chrome production text fields",
        value="High",
        proof_risk="Medium",
        current_stance="Blocked; local textarea/contenteditable fixtures do not count.",
        smallest_proof_lane=(
            "Use one disposable production page with a plain non-send text field,"
            " then prove placement, safe Tab, verified insertion, undo/recovery,"
            " and current-head screenshot evidence."
        ),
    ),
    CoverageLane(
        rank=4,
        surface="Real Monaco and CodeMirror editors",
        value="High",
        proof_risk="Medium-High",
        current_stance="Blocked; forced/local editor fixtures do not graduate production editors.",
        smallest_proof_lane=(
            "Run official CodeMirror or default-AX Monaco proof with verified insertion,"
            " undo/recovery, and current screenshots."
        ),
    ),
    CoverageLane(
        rank=5,
        surface="Codex layouts",
        value="High",
        proof_risk="High",
        current_stance="Proof-only default composer; not beta-safe normal writing support.",
        smallest_proof_lane=(
            "Add one extra disposable Codex prompt layout with one-word Tab,"
            " full-accept no-submit proof, insertion verification, and screenshot trace."
        ),
    ),
    CoverageLane(
        rank=6,
        surface="Claude desktop layouts",
        value="High",
        proof_risk="High",
        current_stance="Proof-only; default one-word no-submit proof exists, layout variants pending.",
        smallest_proof_lane=(
            "Run the empty or wrapped Claude desktop composer lane with one-word no-submit,"
            " verified insertion, and screenshot trace. Keep full accept off."
        ),
    ),
    CoverageLane(
        rank=7,
        surface="Claude Code terminal hosts",
        value="Medium-High",
        proof_risk="High",
        current_stance="Proof-only; Terminal/iTerm2 have proof, Ghostty remains red on verified insertion.",
        smallest_proof_lane=(
            "Fix or prove Ghostty verified insertion after handled=true in the detached proof runner;"
            " only count it when the runner exits 0."
        ),
    ),
    CoverageLane(
        rank=8,
        surface="Google Docs in Chrome",
        value="High",
        proof_risk="High",
        current_stance="Blocked by hosted browser surface policy.",
        smallest_proof_lane=(
            "Use a disposable real-service document and prove placement, one-word Tab,"
            " verified insertion, undo/recovery, and no sensitive-field leak."
        ),
    ),
    CoverageLane(
        rank=9,
        surface="Notion browser or desktop",
        value="High",
        proof_risk="High",
        current_stance="Blocked; local ProseMirror-like fixtures do not count.",
        smallest_proof_lane=(
            "Use a disposable Notion page and prove ProseMirror placement,"
            " verified insertion, undo/recovery, and no navigation or submit side effect."
        ),
    ),
    CoverageLane(
        rank=10,
        surface="Messages, Slack, browser ChatGPT, webmail, Discord",
        value="High",
        proof_risk="Very High",
        current_stance="Blocked or proof-only; send/submit surfaces need exact no-send proof.",
        smallest_proof_lane=(
            "Pick one disposable compose surface and prove one-word Tab, no send/submit,"
            " verified insertion, undo/recovery, sensitive-field suppression, and screenshot trace."
        ),
    ),
)


def load_manifest(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        print(f"manifest not found: {path}", file=sys.stderr)
        raise SystemExit(2)
    except json.JSONDecodeError as error:
        print(f"invalid manifest JSON: {error}", file=sys.stderr)
        raise SystemExit(2)


def manifest_lookup(manifest: dict) -> dict[str, dict]:
    rows: dict[str, dict] = {}
    for row in manifest.get("graduationDecisions", []):
        surface = row.get("surface")
        if isinstance(surface, str):
            rows[surface.lower()] = row
    return rows


def manifest_state(surface: str, rows: dict[str, dict]) -> str:
    row = rows.get(surface.lower())
    if not row:
        return "manifest: no direct graduation row"
    return (
        f"manifest: decision={row.get('decision', 'unknown')},"
        f" proofState={row.get('proofState', 'unknown')}"
    )


def format_lanes(lanes: tuple[CoverageLane, ...], rows: dict[str, dict], limit: int) -> str:
    lines = ["Target app coverage queue:"]
    for lane in lanes[:limit]:
        lines.append(
            f"{lane.rank}. {lane.surface} | value={lane.value} | risk={lane.proof_risk}"
        )
        lines.append(f"   stance: {lane.current_stance} ({manifest_state(lane.surface, rows)})")
        lines.append(f"   smallest proof: {lane.smallest_proof_lane}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Rank target app surfaces by value, proof risk, and smallest safe proof lane."
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help=f"Proof manifest path. Default: {DEFAULT_MANIFEST}",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=len(LANE_ORDER),
        help="Number of ranked lanes to print.",
    )
    args = parser.parse_args()

    if args.limit < 1:
        print("--limit must be a positive integer", file=sys.stderr)
        return 2

    manifest = load_manifest(args.manifest)
    print(format_lanes(LANE_ORDER, manifest_lookup(manifest), args.limit))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
