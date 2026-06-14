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
    guardrail: str


LANE_ORDER: tuple[CoverageLane, ...] = (
    CoverageLane(
        rank=1,
        surface="Apple Pages documents",
        value="High",
        proof_risk="Low-Medium",
        current_stance="Unprofiled generic Accessibility path; installed locally as com.apple.iWork.Pages.",
        smallest_proof_lane=(
            "Use a disposable Pages document body and prove same-line placement,"
            " one-word Tab, full accept, verified insertion, native undo, and no suggestions"
            " in title/sidebar/comment/share fields."
        ),
        guardrail="Local document surface only; do not use private documents for proof.",
    ),
    CoverageLane(
        rank=2,
        surface="LibreOffice Writer documents",
        value="High",
        proof_risk="Medium",
        current_stance="Unprofiled generic Accessibility path; installed locally as org.libreoffice.script.",
        smallest_proof_lane=(
            "Use a disposable Writer document body and prove caret placement,"
            " one-word Tab, verified insertion, undo/recovery, and no suggestions in menus,"
            " dialogs, find, or save/export fields."
        ),
        guardrail="Local document surface only; keep toolbars, dialogs, and file fields suppressed.",
    ),
    CoverageLane(
        rank=3,
        surface="Safari local textarea/contenteditable fixtures",
        value="Medium-High",
        proof_risk="Low-Medium",
        current_stance="Safari is disabled until WebKit local fixture proof exists.",
        smallest_proof_lane=(
            "Mirror the Chrome local textarea/contenteditable fixture proof in Safari with"
            " strict screenshots, safe Tab, verified insertion, undo/recovery, and"
            " sensitive-field suppression."
        ),
        guardrail="Local fixtures only; no public pages or hosted browser apps.",
    ),
    CoverageLane(
        rank=4,
        surface="Focused local writing apps",
        value="Medium-High",
        proof_risk="Medium",
        current_stance="No exact app proof yet; good candidates include Bear, Drafts, iA Writer, Ulysses, Typora, or CotEditor when installed.",
        smallest_proof_lane=(
            "Pick one installed local writing app, capture its bundle/version,"
            " then prove disposable-document placement, one-word Tab, verified insertion,"
            " undo/recovery, and no suggestions in library/search/title fields."
        ),
        guardrail="Prefer local-only documents; do not graduate sync/share/comment fields from generic proof.",
    ),
    CoverageLane(
        rank=5,
        surface="Google Docs in Chrome",
        value="High",
        proof_risk="High",
        current_stance="Blocked by hosted browser surface policy.",
        smallest_proof_lane=(
            "Use a disposable real-service document and prove placement, one-word Tab,"
            " verified insertion, undo/recovery, and no sensitive-field leak."
        ),
        guardrail="Exact disposable real-service proof only; local fixtures do not count.",
    ),
    CoverageLane(
        rank=6,
        surface="Notion browser or desktop",
        value="High",
        proof_risk="High",
        current_stance="Blocked; local ProseMirror-like fixtures do not count.",
        smallest_proof_lane=(
            "Use a disposable Notion page and prove ProseMirror placement,"
            " verified insertion, undo/recovery, and no navigation or submit side effect."
        ),
        guardrail="Disposable page only; no private workspaces or shared/comment surfaces.",
    ),
    CoverageLane(
        rank=7,
        surface="Chrome production text fields",
        value="High",
        proof_risk="High",
        current_stance="Blocked; local textarea/contenteditable fixtures do not count.",
        smallest_proof_lane=(
            "Use one disposable production page with a plain non-send text field,"
            " then prove placement, safe Tab, verified insertion, undo/recovery,"
            " and current-head screenshot evidence."
        ),
        guardrail="No authenticated/private, search, address, payment, or message-send fields.",
    ),
    CoverageLane(
        rank=8,
        surface="Real Monaco and CodeMirror editors",
        value="High",
        proof_risk="High",
        current_stance="Blocked; forced/local editor fixtures do not graduate production editors.",
        smallest_proof_lane=(
            "Run official CodeMirror or default-AX Monaco proof with verified insertion,"
            " undo/recovery, and current screenshots."
        ),
        guardrail="Proof the real editor body only; command palettes, terminals, and AI composers stay blocked.",
    ),
    CoverageLane(
        rank=9,
        surface="Codex and Claude desktop layouts",
        value="High",
        proof_risk="High",
        current_stance="Prompt-app dogfood/proof lanes only; not beta-safe normal writing support.",
        smallest_proof_lane=(
            "Add one extra disposable prompt layout with one-word Tab,"
            " no-submit proof, insertion verification, and screenshot trace."
        ),
        guardrail="Prompt apps stay word-only/guarded unless exact no-submit proof exists for the layout.",
    ),
    CoverageLane(
        rank=10,
        surface="Mail, webmail, Messages, Slack, Discord, terminals",
        value="High",
        proof_risk="Very High",
        current_stance="Blocked, diagnostics-only, or proof-only; send/submit/private fields need exact no-send proof.",
        smallest_proof_lane=(
            "Pick one disposable compose surface and prove one-word Tab, no send/submit,"
            " verified insertion, undo/recovery, sensitive-field suppression, and screenshot trace."
        ),
        guardrail="Keep off by default until no-submit/no-send proof exists for the exact app and field.",
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
        lines.append(f"   guardrail: {lane.guardrail}")
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
