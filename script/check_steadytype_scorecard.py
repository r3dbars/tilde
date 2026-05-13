#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
from dataclasses import dataclass
import math
import re
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_SCORECARD = ROOT_DIR / "docs/product/steadytype-product-scorecard.md"

REQUIRED_AREAS = [
    "suggestion quality",
    "placement",
    "tab safety",
    "latency",
    "privacy",
    "app coverage",
    "onboarding",
    "controls",
    "diagnostics",
    "model readiness",
    "beta readiness",
    "test/proof coverage",
]

EVIDENCE_MARKERS = (
    "`./script/",
    "`script/",
    "`swift test",
    "`git ",
    "docs/product/",
    "docs/evals/",
    "Tests/",
    "Sources/",
    ".png",
    "trace slice",
    "screenshot",
    "proof manifest row",
    "documented manual gate",
    "manual gate",
    "lines ",
)

NEXT_PROOF_MARKERS = (
    "`./script/",
    "`script/",
    "documented manual gate",
    "manual gate",
    "proof-manifest",
    "proof manifest",
    "checklist",
)

LOW_SCORE_PATTERNS = (
    ("stale", re.compile(r"\bstale\b"), 75),
    ("pending", re.compile(r"\bpending\b"), 75),
    ("blocked", re.compile(r"\bblocked\b"), 75),
    ("missing", re.compile(r"\bmissing\b"), 75),
    ("failed", re.compile(r"\b(?:failed|failing)\b"), 85),
)

PERFECT_SCORE_UNRESOLVED_PATTERNS = (
    ("stale", re.compile(r"\bstale\b")),
    ("pending", re.compile(r"\bpending\b")),
    ("blocked", re.compile(r"\bblocked\b")),
    ("missing", re.compile(r"\bmissing\b")),
    ("failed", re.compile(r"\b(?:failed|failing)\b")),
    ("incomplete", re.compile(r"\bincomplete\b")),
    ("open gap", re.compile(r"\b(?:open|remaining)\b[^.]*\b(?:gap|proof|gate|lane|issue|item|row)s?\b|\bgaps?\b")),
    ("still needs", re.compile(r"\bstill\s+(?:needs?|requires?|depends)\b")),
    (
        "needs proof",
        re.compile(
            r"\bneeds?\s+(?:fresh|current|manual|proof|evidence|screenshot|latency|runtime|app|signed|notarized|distribution|tester|walkthrough|gate)\b"
        ),
    ),
    ("short of", re.compile(r"\bshort of\b")),
    ("not yet", re.compile(r"\bnot yet\b")),
    ("not complete", re.compile(r"\bnot complete\b|\bbefore\b[^.]*\bcomplete\b")),
)

PERFECT_SCORE_NEXT_PROOF_ACTION = re.compile(
    r"^\s*(?:add|check|close|finish|notarize|produce|record|refresh|recheck|rerun|run|staple|validate|verify)\b"
)

MANUAL_SMOKE_SCORECARD_PATTERNS = (
    re.compile(
        r"manual_smoke_status[.]sh\s+--strict`?:\s*"
        r"(?:[^|.]*?\bfailed with\s+)?([0-9]+)\s+[^|.]*?\bstale or pending\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"\bmanual app proof is blocked by\s+([0-9]+)\s+stale or pending rows\b",
        re.IGNORECASE,
    ),
)

PROOF_MANIFEST_SCORECARD_PATTERNS = (
    re.compile(
        r"check_proof_manifest[.]sh\s+--require-all`?:\s*[^|.]*?"
        r"\b([0-9]+)\s+(?:manifest\s+)?issues\b",
        re.IGNORECASE,
    ),
)

MANUAL_SMOKE_LIVE_COUNT = re.compile(
    r"\b([0-9]+)\s+target app pass(?:[(]es[)]|es)?\s+still need real manual smoke proof\b",
    re.IGNORECASE,
)

PROOF_MANIFEST_LIVE_COUNT = re.compile(
    r"\bProof manifest check failed with\s+([0-9]+)\s+issue(?:[(]s[)]|s)?\.",
    re.IGNORECASE,
)

LATENCY_SELECTOR_SCORECARD_GREEN_PATTERN = re.compile(
    r"select_latency_window[.]py\b[^|]*?:\s*selected\s+"
    r"diagnosticsLine=([0-9]+),\s*"
    r"traceStartLine=([0-9]+),\s*"
    r"firstVisibleSamples=([0-9]+),\s*"
    r"modelSamples=([0-9]+),\s*"
    r"fastWordVisibleSamples=([0-9]+)",
    re.IGNORECASE,
)

LATENCY_SELECTOR_SCORECARD_RED_PATTERN = re.compile(
    r"select_latency_window[.]py\b[^|]*?:\s*failed\s+red\s+because\s+"
    r"(.+?),\s*with\s*"
    r"diagnosticsLine=([0-9]+),\s*"
    r"traceStartLine=([0-9]+),\s*"
    r"firstVisibleSamples=([0-9]+),\s*"
    r"modelSamples=([0-9]+),\s*"
    r"fastWordVisibleSamples=([0-9]+)",
    re.IGNORECASE,
)

LATENCY_SELECTOR_LIVE_PATTERN = re.compile(
    r"\bLatency window:\s*(.+?);\s*"
    r"diagnosticsLine=([0-9]+);\s*"
    r"traceStartLine=([0-9]+);\s*"
    r"diagnosticsEndLine=(?:[0-9]+|none);\s*"
    r"traceEndLine=(?:[0-9]+|none);\s*"
    r"firstVisibleSamples=([0-9]+);\s*"
    r"modelSamples=([0-9]+);\s*"
    r"fastWordVisibleSamples=([0-9]+)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class CountClaim:
    kind: str
    count: int
    line_number: int
    snippet: str


@dataclass(frozen=True)
class LatencySelectorClaim:
    ok: bool
    reason: str
    diagnostics_line: int
    trace_start_line: int
    first_visible_samples: int
    model_samples: int
    fast_word_visible_samples: int
    line_number: int
    snippet: str


@dataclass(frozen=True)
class LatencySelectorResult:
    ok: bool
    reason: str
    diagnostics_line: int | None = None
    trace_start_line: int | None = None
    first_visible_samples: int | None = None
    model_samples: int | None = None
    fast_word_visible_samples: int | None = None


def split_markdown_row(line: str) -> list[str]:
    body = line.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|"):
        body = body[:-1]

    cells: list[str] = []
    current: list[str] = []
    in_code = False
    for character in body:
        if character == "`":
            in_code = not in_code
            current.append(character)
            continue
        if character == "|" and not in_code:
            cells.append("".join(current).strip())
            current = []
            continue
        current.append(character)
    cells.append("".join(current).strip())
    return cells


def normalize_area(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def parse_score(value: str, area: str, failures: list[str]) -> int | None:
    match = re.fullmatch(r"([0-9]{1,3})/100", value.strip())
    if not match:
        failures.append(f"{area}: score must look like N/100, got {value!r}")
        return None
    score = int(match.group(1))
    if not 0 <= score <= 100:
        failures.append(f"{area}: score must be between 0 and 100, got {score}")
        return None
    return score


def parse_rows(source: str, failures: list[str]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    in_table = False
    headers: list[str] = []

    for raw_line in source.splitlines():
        line = raw_line.strip()
        if not line.startswith("|"):
            if in_table and rows:
                break
            continue

        cells = split_markdown_row(line)
        lowered = [cell.lower() for cell in cells]
        if lowered[:5] == ["area", "score", "evidence", "why it is not higher", "next proof"]:
            headers = lowered
            in_table = True
            continue
        if not in_table:
            continue
        if set("".join(cells)) <= {"-", ":", " "}:
            continue
        if len(cells) != len(headers):
            failures.append(f"score row has {len(cells)} cells, expected {len(headers)}: {line}")
            continue
        rows.append(dict(zip(headers, cells)))

    if not rows:
        failures.append("missing score table with Area, Score, Evidence, Why It Is Not Higher, and Next Proof columns")
    return rows


def parse_overall(source: str, failures: list[str]) -> int | None:
    match = re.search(r"^Overall score:\s*([0-9]{1,3})/100\.\s*$", source, re.MULTILINE)
    if not match:
        failures.append("missing overall score line")
        return None
    overall = int(match.group(1))
    if not 0 <= overall <= 100:
        failures.append(f"overall score must be between 0 and 100, got {overall}")
        return None
    return overall


def compact_snippet(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip())


def count_claim_key(kind: str, line_number: int, count: int, snippet: str) -> tuple[str, int, int, str]:
    return (kind, line_number, count, snippet)


def extract_count_claims(source: str) -> list[CountClaim]:
    claims: list[CountClaim] = []
    seen: set[tuple[str, int, int, str]] = set()

    for line_number, line in enumerate(source.splitlines(), start=1):
        snippet = compact_snippet(line)
        if not snippet:
            continue

        if "manual_smoke_status.sh" in snippet or "manual app proof is blocked" in snippet.lower():
            for pattern in MANUAL_SMOKE_SCORECARD_PATTERNS:
                for match in pattern.finditer(snippet):
                    count = int(match.group(1))
                    key = count_claim_key("manual", line_number, count, snippet)
                    if key not in seen:
                        seen.add(key)
                        claims.append(
                            CountClaim(
                                kind="manual",
                                count=count,
                                line_number=line_number,
                                snippet=snippet,
                            )
                        )

        if "check_proof_manifest.sh" in snippet:
            for pattern in PROOF_MANIFEST_SCORECARD_PATTERNS:
                for match in pattern.finditer(snippet):
                    count = int(match.group(1))
                    key = count_claim_key("proof-manifest", line_number, count, snippet)
                    if key not in seen:
                        seen.add(key)
                        claims.append(
                            CountClaim(
                                kind="proof-manifest",
                                count=count,
                                line_number=line_number,
                                snippet=snippet,
                            )
                        )

    return claims


def extract_latency_selector_claims(source: str) -> list[LatencySelectorClaim]:
    claims: list[LatencySelectorClaim] = []
    for line_number, line in enumerate(source.splitlines(), start=1):
        snippet = compact_snippet(line)
        if "select_latency_window.py" not in snippet:
            continue
        for match in LATENCY_SELECTOR_SCORECARD_GREEN_PATTERN.finditer(snippet):
            claims.append(
                LatencySelectorClaim(
                    ok=True,
                    reason="selected",
                    diagnostics_line=int(match.group(1)),
                    trace_start_line=int(match.group(2)),
                    first_visible_samples=int(match.group(3)),
                    model_samples=int(match.group(4)),
                    fast_word_visible_samples=int(match.group(5)),
                    line_number=line_number,
                    snippet=snippet,
                )
            )
        for match in LATENCY_SELECTOR_SCORECARD_RED_PATTERN.finditer(snippet):
            claims.append(
                LatencySelectorClaim(
                    ok=False,
                    reason=match.group(1).strip(),
                    diagnostics_line=int(match.group(2)),
                    trace_start_line=int(match.group(3)),
                    first_visible_samples=int(match.group(4)),
                    model_samples=int(match.group(5)),
                    fast_word_visible_samples=int(match.group(6)),
                    line_number=line_number,
                    snippet=snippet,
                )
            )
    return claims


def read_or_run_output(fixture_path: Path | None, command: list[str]) -> str:
    if fixture_path is not None:
        return fixture_path.read_text(encoding="utf-8")

    result = subprocess.run(
        command,
        cwd=ROOT_DIR,
        text=True,
        capture_output=True,
        check=False,
    )
    return f"{result.stdout}\n{result.stderr}"


def strict_latency_selector_command() -> list[str]:
    return [
        "./script/select_latency_window.py",
        "--diagnostics-log",
        str(Path.home() / "Library/Logs/SteadyType/diagnostics.log"),
        "--trace-log",
        str(Path.home() / "Library/Logs/SteadyType/traces.jsonl"),
        "--expected-asset",
        "Qwen3.5-4B-4bit",
        "--min-first-visible-samples",
        "5",
        "--min-model-samples",
        "5",
        "--required-proof-app",
        "com.apple.TextEdit",
        "--required-proof-scenario",
        "textedit-model-latency",
        "--required-trace-app",
        "com.apple.TextEdit",
        "--required-request-mode",
        "wordCompletion",
        "--require-model-backed-visible",
        "--forbid-fast-word-visible",
    ]


def parse_manual_smoke_live_count(output: str) -> int | None:
    matches = list(MANUAL_SMOKE_LIVE_COUNT.finditer(output))
    if matches:
        return int(matches[-1].group(1))
    if "All required target proofs are covered." in output:
        return 0
    return None


def parse_proof_manifest_live_count(output: str) -> int | None:
    matches = list(PROOF_MANIFEST_LIVE_COUNT.finditer(output))
    if matches:
        return int(matches[-1].group(1))
    if "Proof manifest verified." in output:
        return 0
    return None


def parse_latency_selector_result(output: str) -> LatencySelectorResult:
    matches = list(LATENCY_SELECTOR_LIVE_PATTERN.finditer(output))
    if not matches:
        reason_match = re.search(r"\bLatency window:\s*([^\n]+)", output)
        reason = reason_match.group(1).strip() if reason_match else "missing Latency window output"
        return LatencySelectorResult(False, reason)

    match = matches[-1]
    has_start_lines = (
        "AUTOCOMPLETE_LAB_LOG_START_LINE=" in output
        and "AUTOCOMPLETE_LAB_TRACE_START_LINE=" in output
    )
    return LatencySelectorResult(
        ok=has_start_lines and match.group(1).strip().startswith("selected"),
        reason=match.group(1).strip(),
        diagnostics_line=int(match.group(2)),
        trace_start_line=int(match.group(3)),
        first_visible_samples=int(match.group(4)),
        model_samples=int(match.group(5)),
        fast_word_visible_samples=int(match.group(6)),
    )


def normalize_latency_reason(value: str) -> str:
    normalized = re.sub(r"\s+", " ", value.strip().lower())
    normalized = re.sub(r"^the\s+", "", normalized)
    return re.sub(r"\s*\([^)]*\)", "", normalized).strip()


def latency_reason_has_volatile_latest_lines(value: str) -> bool:
    return normalize_latency_reason(value).startswith(
        "latest runtime launch is newer than the required proof launch"
    )


def compare_latency_selector_claim(
    claim: LatencySelectorClaim,
    live_result: LatencySelectorResult,
) -> list[str]:
    mismatches: list[str] = []
    if claim.ok != live_result.ok:
        claim_state = "green" if claim.ok else "red"
        live_state = "green" if live_result.ok else "red"
        mismatches.append(f"scorecard claims {claim_state}, live output is {live_state}")
    if not claim.ok and not live_result.ok:
        if normalize_latency_reason(claim.reason) != normalize_latency_reason(live_result.reason):
            mismatches.append(
                f"red reason claim is {claim.reason!r}, live output reports {live_result.reason!r}"
            )
    volatile_latest_lines = (
        not claim.ok
        and not live_result.ok
        and latency_reason_has_volatile_latest_lines(claim.reason)
        and latency_reason_has_volatile_latest_lines(live_result.reason)
    )
    if not volatile_latest_lines:
        if claim.diagnostics_line != live_result.diagnostics_line:
            mismatches.append(
                f"diagnosticsLine claim is {claim.diagnostics_line}, live output reports {live_result.diagnostics_line}"
            )
        if claim.trace_start_line != live_result.trace_start_line:
            mismatches.append(
                f"traceStartLine claim is {claim.trace_start_line}, live output reports {live_result.trace_start_line}"
            )
    if claim.first_visible_samples != live_result.first_visible_samples:
        mismatches.append(
            f"firstVisibleSamples claim is {claim.first_visible_samples}, live output reports {live_result.first_visible_samples}"
        )
    if claim.model_samples != live_result.model_samples:
        mismatches.append(
            f"modelSamples claim is {claim.model_samples}, live output reports {live_result.model_samples}"
        )
    if claim.fast_word_visible_samples != live_result.fast_word_visible_samples:
        mismatches.append(
            f"fastWordVisibleSamples claim is {claim.fast_word_visible_samples}, live output reports {live_result.fast_word_visible_samples}"
        )
    return mismatches


def validate_live_counts(
    source: str,
    manual_smoke_output: Path | None,
    proof_manifest_output: Path | None,
    *,
    latency_selector_output: Path | None = None,
    require_latency_selector: bool = False,
) -> list[str]:
    failures: list[str] = []
    claims = extract_count_claims(source)
    manual_claims = [claim for claim in claims if claim.kind == "manual"]
    proof_manifest_claims = [claim for claim in claims if claim.kind == "proof-manifest"]
    latency_selector_claims = extract_latency_selector_claims(source)

    if manual_claims:
        output = read_or_run_output(
            manual_smoke_output,
            ["./script/manual_smoke_status.sh", "--strict"],
        )
        live_count = parse_manual_smoke_live_count(output)
        if live_count is None:
            failures.append("manual smoke live output did not include a stale/pending count")
        else:
            for claim in manual_claims:
                if claim.count != live_count:
                    failures.append(
                        f"line {claim.line_number}: manual smoke stale/pending count claim is "
                        f"{claim.count}, live output reports {live_count}: {claim.snippet}"
                    )

    if proof_manifest_claims:
        output = read_or_run_output(
            proof_manifest_output,
            ["./script/check_proof_manifest.sh", "--require-all"],
        )
        live_count = parse_proof_manifest_live_count(output)
        if live_count is None:
            failures.append("proof manifest live output did not include an issue count")
        else:
            for claim in proof_manifest_claims:
                if claim.count != live_count:
                    failures.append(
                        f"line {claim.line_number}: proof manifest issue count claim is "
                        f"{claim.count}, live output reports {live_count}: {claim.snippet}"
                    )

    if latency_selector_output is not None or require_latency_selector:
        if not latency_selector_claims:
            failures.append("latency selector live check requires a select_latency_window.py scorecard claim")
        output = read_or_run_output(latency_selector_output, strict_latency_selector_command())
        live_result = parse_latency_selector_result(output)
        if not live_result.ok and not any(not claim.ok for claim in latency_selector_claims):
            failures.append(f"latency selector live output is red: {live_result.reason}")
        for claim in latency_selector_claims:
            mismatches = compare_latency_selector_claim(claim, live_result)
            if mismatches:
                failures.append(
                    f"line {claim.line_number}: latency selector claim is stale: "
                    f"{'; '.join(mismatches)}: {claim.snippet}"
                )

    return failures


def validate_scorecard(
    path: Path,
    *,
    live: bool = False,
    manual_smoke_output: Path | None = None,
    proof_manifest_output: Path | None = None,
    latency_selector_output: Path | None = None,
    require_latency_selector: bool = False,
) -> list[str]:
    failures: list[str] = []
    try:
        source = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return [f"missing scorecard: {path}"]

    overall = parse_overall(source, failures)
    rows = parse_rows(source, failures)
    seen: dict[str, tuple[int, str]] = {}

    for row in rows:
        raw_area = row["area"]
        area = normalize_area(raw_area)
        if area in seen:
            failures.append(f"duplicate score row: {raw_area}")
            continue

        score = parse_score(row["score"], raw_area, failures)
        if score is None:
            continue
        seen[area] = (score, raw_area)

        evidence = row["evidence"]
        next_proof = row["next proof"]
        combined = " ".join(row.values()).lower()

        if any(bad in combined for bad in ("tbd", "todo", "vibes", "round up", "green enough")):
            failures.append(f"{raw_area}: scorecard language must stay evidence-based")

        if not any(marker.lower() in evidence.lower() for marker in EVIDENCE_MARKERS):
            failures.append(f"{raw_area}: evidence must name a command, trace slice, screenshot, proof row, or documented manual gate")

        if not any(marker.lower() in next_proof.lower() for marker in NEXT_PROOF_MARKERS):
            failures.append(f"{raw_area}: next proof must name a command or documented manual gate")

        for term, pattern, maximum in LOW_SCORE_PATTERNS:
            if pattern.search(combined) and score > maximum:
                failures.append(f"{raw_area}: contains {term!r}, so score must stay <= {maximum}/100")

        if score == 100:
            unresolved_terms = [
                term for term, pattern in PERFECT_SCORE_UNRESOLVED_PATTERNS if pattern.search(combined)
            ]
            if PERFECT_SCORE_NEXT_PROOF_ACTION.search(next_proof.lower()):
                unresolved_terms.append("unfinished next proof")
            if unresolved_terms:
                joined = ", ".join(dict.fromkeys(unresolved_terms))
                failures.append(f"{raw_area}: 100/100 requires resolved row gates; unresolved language found: {joined}")

    missing = [area for area in REQUIRED_AREAS if area not in seen]
    extra = [raw for key, (_, raw) in seen.items() if key not in REQUIRED_AREAS]
    for area in missing:
        failures.append(f"missing required score area: {area}")
    for area in extra:
        failures.append(f"unexpected score area: {area}")

    if overall is not None and len(seen) == len(REQUIRED_AREAS):
        average = sum(score for score, _ in seen.values()) / len(REQUIRED_AREAS)
        expected = math.floor(average + 0.5)
        if overall != expected:
            failures.append(f"overall score is {overall}/100, expected rounded average {expected}/100")

    if live:
        failures.extend(
            validate_live_counts(
                source,
                manual_smoke_output,
                proof_manifest_output,
                latency_selector_output=latency_selector_output,
                require_latency_selector=require_latency_selector,
            )
        )

    return failures


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT_DIR))
    except ValueError:
        return str(path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the SteadyType product scorecard.")
    parser.add_argument(
        "--scorecard",
        default=str(DEFAULT_SCORECARD),
        help="Path to the scorecard markdown file.",
    )
    parser.add_argument(
        "--live",
        action="store_true",
        help="Compare scorecard claims against live proof gate output, including strict latency proof.",
    )
    parser.add_argument(
        "--manual-smoke-output",
        help="Read manual_smoke_status output from this file instead of running the live command.",
    )
    parser.add_argument(
        "--proof-manifest-output",
        help="Read check_proof_manifest output from this file instead of running the live command.",
    )
    parser.add_argument(
        "--latency-selector-output",
        help="Read strict select_latency_window output from this file instead of running the live command.",
    )
    parser.add_argument(
        "--require-latency-selector",
        action="store_true",
        help="Require the scorecard latency selector claim to match strict live selector output.",
    )
    args = parser.parse_args()
    if (
        args.manual_smoke_output
        or args.proof_manifest_output
        or args.latency_selector_output
        or args.require_latency_selector
    ) and not args.live:
        parser.error("--manual-smoke-output, --proof-manifest-output, and latency selector live options require --live")

    path = Path(args.scorecard)
    if not path.is_absolute():
        path = ROOT_DIR / path

    manual_smoke_output = Path(args.manual_smoke_output) if args.manual_smoke_output else None
    proof_manifest_output = Path(args.proof_manifest_output) if args.proof_manifest_output else None
    latency_selector_output = Path(args.latency_selector_output) if args.latency_selector_output else None
    failures = validate_scorecard(
        path,
        live=args.live,
        manual_smoke_output=manual_smoke_output,
        proof_manifest_output=proof_manifest_output,
        latency_selector_output=latency_selector_output,
        require_latency_selector=args.live,
    )
    if failures:
        print("SteadyType scorecard check failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(f"SteadyType scorecard verified: {display_path(path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
