#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import os
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

DAILY_DRIVER_LOCAL_QUALITY_REPORT = "docs/evals/daily-driver-local-quality-audit-2026-05-25.md"
DAILY_DRIVER_LOCAL_QUALITY_GATE = "./script/check_daily_driver_local_quality_audit_report.sh"
DAILY_DRIVER_DOGFOOD_GATE = "./script/daily_driver_dogfood_session_self_test.sh"
DAILY_DRIVER_MATCH_FAMILY_EVIDENCE = "match-family counts"

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

ZERO_COUNT_RESOLVED_METRIC_PATTERNS = (
    re.compile(r"\bstale\s*/\s*late\s+suppression\s*:?\s*n\s*=\s*0\b", re.IGNORECASE),
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

LATENCY_SELECTOR_EXECUTABLE_SHA_PATTERN = re.compile(
    r"\b(?:app|executable)-sha256\b\s*[:=]?\s*`?([0-9a-f]{64})`?",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class CountClaim:
    kind: str
    count: int
    line_number: int
    snippet: str


@dataclass(frozen=True)
class LatencySelectorTarget:
    proof_app: str
    proof_scenario: str
    trace_app: str
    request_mode: str


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
    target: LatencySelectorTarget
    executable_sha256: str | None


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


def strip_resolved_zero_count_metrics(value: str) -> str:
    scrubbed = value
    for pattern in ZERO_COUNT_RESOLVED_METRIC_PATTERNS:
        scrubbed = pattern.sub("", scrubbed)
    return scrubbed


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


def default_latency_selector_target() -> LatencySelectorTarget:
    proof_app = os.environ.get(
        "AUTOCOMPLETE_LAB_SCORECARD_LATENCY_PROOF_APP",
        "com.anthropic.claudefordesktop",
    )
    proof_scenario = os.environ.get(
        "AUTOCOMPLETE_LAB_SCORECARD_LATENCY_PROOF_SCENARIO",
        "claude-model-latency",
    )
    trace_app = os.environ.get("AUTOCOMPLETE_LAB_SCORECARD_LATENCY_TRACE_APP", proof_app)
    request_mode = os.environ.get("AUTOCOMPLETE_LAB_SCORECARD_LATENCY_REQUEST_MODE", "wordCompletion")
    return LatencySelectorTarget(
        proof_app=proof_app,
        proof_scenario=proof_scenario,
        trace_app=trace_app,
        request_mode=request_mode,
    )


def infer_latency_selector_target(snippet: str, match_start: int) -> LatencySelectorTarget:
    context = snippet[max(0, match_start - 320):match_start].lower()
    if "textedit strict selector" in context:
        return LatencySelectorTarget(
            proof_app="com.apple.TextEdit",
            proof_scenario="textedit-model-latency",
            trace_app="com.apple.TextEdit",
            request_mode="wordCompletion",
        )
    if "claude code strict selector" in context:
        return LatencySelectorTarget(
            proof_app="com.anthropic.claude-code",
            proof_scenario="claude-code-model-latency",
            trace_app="com.anthropic.claude-code",
            request_mode="wordCompletion",
        )
    if "codex strict selector" in context:
        return LatencySelectorTarget(
            proof_app="com.openai.codex",
            proof_scenario="codex-model-latency",
            trace_app="com.openai.codex",
            request_mode="wordCompletion",
        )
    if "claude strict selector" in context:
        return LatencySelectorTarget(
            proof_app="com.anthropic.claudefordesktop",
            proof_scenario="claude-model-latency",
            trace_app="com.anthropic.claudefordesktop",
            request_mode="wordCompletion",
        )
    return default_latency_selector_target()


def infer_latency_selector_executable_sha256(snippet: str, match_start: int) -> str | None:
    context = snippet[max(0, match_start - 240):match_start]
    matches = list(LATENCY_SELECTOR_EXECUTABLE_SHA_PATTERN.finditer(context))
    if not matches:
        return None
    return matches[-1].group(1).lower()


def extract_latency_selector_claims(source: str) -> list[LatencySelectorClaim]:
    claims: list[LatencySelectorClaim] = []
    for line_number, line in enumerate(source.splitlines(), start=1):
        snippet = compact_snippet(line)
        if "select_latency_window.py" not in snippet:
            continue
        for match in LATENCY_SELECTOR_SCORECARD_GREEN_PATTERN.finditer(snippet):
            target = infer_latency_selector_target(snippet, match.start())
            executable_sha256 = infer_latency_selector_executable_sha256(snippet, match.start())
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
                    target=target,
                    executable_sha256=executable_sha256,
                )
            )
        for match in LATENCY_SELECTOR_SCORECARD_RED_PATTERN.finditer(snippet):
            target = infer_latency_selector_target(snippet, match.start())
            executable_sha256 = infer_latency_selector_executable_sha256(snippet, match.start())
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
                    target=target,
                    executable_sha256=executable_sha256,
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


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def latency_executable_sha256() -> str:
    override = os.environ.get("AUTOCOMPLETE_LAB_SCORECARD_LATENCY_EXECUTABLE_SHA256", "").strip()
    if override:
        return override

    app_binary = ROOT_DIR / "dist/SteadyType.app/Contents/MacOS/SteadyType"
    if app_binary.is_file():
        return sha256_file(app_binary)
    return ""


def strict_latency_selector_command(
    target: LatencySelectorTarget | None = None,
    expected_executable_sha256: str | None = None,
) -> list[str]:
    target = target or default_latency_selector_target()
    command = [
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
        target.proof_app,
        "--required-proof-scenario",
        target.proof_scenario,
        "--required-trace-app",
        target.trace_app,
        "--required-request-mode",
        target.request_mode,
        "--require-model-backed-visible",
        "--forbid-fast-word-visible",
    ]
    executable_sha256 = expected_executable_sha256 or latency_executable_sha256()
    if executable_sha256:
        command.extend(["--expected-executable-sha256", executable_sha256])
    return command


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


def parse_latency_selector_results(output: str) -> list[LatencySelectorResult]:
    matches = list(LATENCY_SELECTOR_LIVE_PATTERN.finditer(output))
    if not matches:
        reason_match = re.search(r"\bLatency window:\s*([^\n]+)", output)
        reason = reason_match.group(1).strip() if reason_match else "missing Latency window output"
        return [LatencySelectorResult(False, reason)]

    has_start_lines = (
        "AUTOCOMPLETE_LAB_LOG_START_LINE=" in output
        and "AUTOCOMPLETE_LAB_TRACE_START_LINE=" in output
    )
    results: list[LatencySelectorResult] = []
    for match in matches:
        results.append(
            LatencySelectorResult(
                ok=has_start_lines and match.group(1).strip().startswith("selected"),
                reason=match.group(1).strip(),
                diagnostics_line=int(match.group(2)),
                trace_start_line=int(match.group(3)),
                first_visible_samples=int(match.group(4)),
                model_samples=int(match.group(5)),
                fast_word_visible_samples=int(match.group(6)),
            )
        )
    return results


def parse_latency_selector_result(output: str) -> LatencySelectorResult:
    return parse_latency_selector_results(output)[-1]


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


def best_latency_selector_result_for_claim(
    claim: LatencySelectorClaim,
    live_results: list[LatencySelectorResult],
) -> LatencySelectorResult:
    for result in live_results:
        if not compare_latency_selector_claim(claim, result):
            return result
    return live_results[-1]


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
            return failures
        fixture_results: list[LatencySelectorResult] | None = None
        live_results_by_target: dict[tuple[LatencySelectorTarget, str], LatencySelectorResult] = {}
        if latency_selector_output is not None:
            output = read_or_run_output(latency_selector_output, strict_latency_selector_command())
            fixture_results = parse_latency_selector_results(output)
        for claim in latency_selector_claims:
            if fixture_results is not None:
                live_result = best_latency_selector_result_for_claim(claim, fixture_results)
            else:
                cache_key = (claim.target, claim.executable_sha256 or "")
                if cache_key not in live_results_by_target:
                    output = read_or_run_output(
                        None,
                        strict_latency_selector_command(
                            claim.target,
                            expected_executable_sha256=claim.executable_sha256,
                        ),
                    )
                    live_results_by_target[cache_key] = parse_latency_selector_result(output)
                live_result = live_results_by_target[cache_key]
            mismatches = compare_latency_selector_claim(claim, live_result)
            if mismatches:
                failures.append(
                    f"line {claim.line_number}: latency selector claim is stale: "
                    f"{claim.target.proof_app}/{claim.target.proof_scenario}: "
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
    product_scorecard = "# SteadyType Product Scorecard" in source

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
        unresolved_text = strip_resolved_zero_count_metrics(combined)

        if any(bad in combined for bad in ("tbd", "todo", "vibes", "round up", "green enough")):
            failures.append(f"{raw_area}: scorecard language must stay evidence-based")

        if not any(marker.lower() in evidence.lower() for marker in EVIDENCE_MARKERS):
            failures.append(f"{raw_area}: evidence must name a command, trace slice, screenshot, proof row, or documented manual gate")

        if not any(marker.lower() in next_proof.lower() for marker in NEXT_PROOF_MARKERS):
            failures.append(f"{raw_area}: next proof must name a command or documented manual gate")

        for term, pattern, maximum in LOW_SCORE_PATTERNS:
            if pattern.search(unresolved_text) and score > maximum:
                failures.append(f"{raw_area}: contains {term!r}, so score must stay <= {maximum}/100")

        if score == 100:
            unresolved_terms = [
                term for term, pattern in PERFECT_SCORE_UNRESOLVED_PATTERNS if pattern.search(unresolved_text)
            ]
            if PERFECT_SCORE_NEXT_PROOF_ACTION.search(next_proof.lower()):
                unresolved_terms.append("unfinished next proof")
            if unresolved_terms:
                joined = ", ".join(dict.fromkeys(unresolved_terms))
                failures.append(f"{raw_area}: 100/100 requires resolved row gates; unresolved language found: {joined}")

        if product_scorecard and area == "suggestion quality":
            if DAILY_DRIVER_LOCAL_QUALITY_GATE not in evidence:
                failures.append(
                    f"{raw_area}: evidence must name {DAILY_DRIVER_LOCAL_QUALITY_GATE} now that the "
                    "daily-driver audit report is checked in"
                )
            if DAILY_DRIVER_LOCAL_QUALITY_REPORT not in evidence:
                failures.append(
                    f"{raw_area}: evidence must name {DAILY_DRIVER_LOCAL_QUALITY_REPORT} now that the "
                    "daily-driver audit report is checked in"
                )
            if "local_quality_audit.py" in next_proof or "local quality audit" in next_proof.lower():
                failures.append(
                    f"{raw_area}: next proof must move past the checked local audit toward real writing dogfood"
                )
            if DAILY_DRIVER_DOGFOOD_GATE not in source:
                failures.append(
                    f"{raw_area}: scorecard must name {DAILY_DRIVER_DOGFOOD_GATE} now that dogfood "
                    "report visibility is a daily-driver gate"
                )
            if DAILY_DRIVER_MATCH_FAMILY_EVIDENCE not in source:
                failures.append(
                    f"{raw_area}: scorecard must name redacted instant phrase {DAILY_DRIVER_MATCH_FAMILY_EVIDENCE}"
                )

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
