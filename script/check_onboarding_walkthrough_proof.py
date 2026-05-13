#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_PROOF = ROOT_DIR / "docs/product/onboarding-permission-qa-checklist.md"

REQUIRED_COLUMNS = [
    "time utc",
    "build proof",
    "macos user",
    "accessibility",
    "runtime",
    "textedit practice",
    "tab",
    "esc",
    "pause",
    "delete traces",
    "result",
    "evidence",
]

UNRESOLVED_TERMS = (
    "pending",
    "todo",
    "stale",
    "missing",
    "needs",
    "blocked",
    "failed",
    "failing",
)

EXTERNAL_RUNTIME_TERMS = (
    "ollama",
    "llama.cpp",
    "separate server",
    "user-managed server",
    "mock fallback",
    "mock runtime",
)

BUILD_TOKEN_PATTERN = re.compile(
    r"(commit:[0-9a-fA-F]{7,40}|app-sha256:[0-9a-fA-F]{64}|archive-sha256:[0-9a-fA-F]{64})"
)
PASS_RESULT_PATTERN = re.compile(r"\bpass(?:ed)?\b")
RECORDING_GUIDE = "docs/product/onboarding-walkthrough-proof.md"


def run_git(args: list[str], *, check: bool = False) -> str:
    process = subprocess.run(
        ["git", *args],
        cwd=ROOT_DIR,
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return process.stdout.strip()


def sha256_token(prefix: str, path: Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return f"{prefix}:{digest}"


def current_build_tokens() -> set[str]:
    tokens: set[str] = set()

    commit = run_git(["rev-parse", "--verify", "HEAD"], check=True)
    if commit:
        tokens.add(f"commit:{commit}")
        tokens.add(f"commit:{commit[:12]}")
        tokens.add(f"commit:{commit[:7]}")

    for token in (
        sha256_token("app-sha256", ROOT_DIR / "dist/SteadyType.app/Contents/MacOS/SteadyType"),
        sha256_token("archive-sha256", ROOT_DIR / "dist/smoke-proof/SteadyType.zip"),
        sha256_token("archive-sha256", ROOT_DIR / "dist/SteadyType.zip"),
        sha256_token("archive-sha256", ROOT_DIR / "dist/SteadyType.dmg"),
    ):
        if token:
            tokens.add(token)

    return tokens


def source_compatible_commit(token: str) -> bool:
    if not token.startswith("commit:"):
        return False

    raw_commit = token.split(":", 1)[1]
    proof_commit = run_git(["rev-parse", "--verify", "--quiet", f"{raw_commit}^{{commit}}"])
    current_commit = run_git(["rev-parse", "--verify", "--quiet", "HEAD^{commit}"])
    if not proof_commit or not current_commit:
        return False
    if proof_commit == current_commit:
        return True

    diff = subprocess.run(
        [
            "git",
            "diff",
            "--quiet",
            f"{proof_commit}..{current_commit}",
            "--",
            "Package.swift",
            "Package.resolved",
            "Sources",
        ],
        cwd=ROOT_DIR,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return diff.returncode == 0


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


def normalize(value: str) -> str:
    value = value.replace("`", "")
    return re.sub(r"\s+", " ", value.strip().lower())


def parse_walkthrough_rows(source: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    in_table = False

    for raw_line in source.splitlines():
        line = raw_line.strip()
        if not line.startswith("|"):
            if in_table:
                break
            continue

        cells = split_markdown_row(line)
        lowered = [normalize(cell) for cell in cells]
        if lowered == REQUIRED_COLUMNS:
            in_table = True
            continue
        if not in_table:
            continue
        if set("".join(cells)) <= {"-", ":", " "}:
            continue
        if len(cells) == len(REQUIRED_COLUMNS):
            rows.append(dict(zip(REQUIRED_COLUMNS, cells)))

    return rows


def contains_any(value: str, terms: tuple[str, ...]) -> bool:
    lowered = normalize(value)
    return any(term in lowered for term in terms)


def require_cell(
    row: dict[str, str],
    column: str,
    required: tuple[str, ...],
    failures: list[str],
    message: str,
) -> None:
    lowered = normalize(row[column])
    if not all(term in lowered for term in required):
        failures.append(message)


def validate_build_proof(row: dict[str, str], tokens: set[str], failures: list[str]) -> None:
    value = row["build proof"]
    found = BUILD_TOKEN_PATTERN.findall(value)
    if not found:
        failures.append("build proof must include commit:, app-sha256:, or archive-sha256:")
        return

    if any(token in tokens or source_compatible_commit(token) for token in found):
        return

    failures.append("build proof is not current and is not source-compatible with this checkout")


def validate_row(row: dict[str, str], tokens: set[str]) -> list[str]:
    failures: list[str] = []
    row_text = " ".join(row.values())
    for term in UNRESOLVED_TERMS:
        if re.search(rf"\b{re.escape(term)}\b", normalize(row_text)):
            failures.append(f"row still contains unresolved marker: {term}")

    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", row["time utc"].strip()):
        failures.append("time utc must be an ISO UTC timestamp like 2026-05-13T12:00:00Z")

    if normalize(row["macos user"]) in {"", "-", "clean tester account"}:
        failures.append("macos user must name the clean tester account used for the walkthrough")

    validate_build_proof(row, tokens, failures)

    accessibility = normalize(row["accessibility"])
    if "granted" not in accessibility and "allowed" not in accessibility:
        failures.append("Accessibility must be granted or allowed")
    if not any(term in accessibility for term in ("user-triggered", "after allow", "after settings", "app-owned")):
        failures.append("Accessibility proof must show the system prompt came after app-owned user intent")

    runtime = normalize(row["runtime"])
    if "ready" not in runtime:
        failures.append("runtime proof must show the local model is ready")
    if not any(term in runtime for term in ("app-owned", "mlx", "no external server")):
        failures.append("runtime proof must show app-owned local runtime, not tester-side setup")
    if contains_any(runtime, EXTERNAL_RUNTIME_TERMS):
        failures.append("runtime proof must not rely on Ollama, llama.cpp, mock fallback, or a separate server")

    textedit = normalize(row["textedit practice"])
    if "textedit" not in textedit or "opened" not in textedit or "disposable" not in textedit:
        failures.append("TextEdit practice proof must open a disposable TextEdit practice file")

    tab = normalize(row["tab"])
    if not any(term in tab for term in ("one-word", "next word")) or not any(
        term in tab for term in ("verified", "inserted")
    ):
        failures.append("Tab proof must show a verified one-word or next-word insert")

    esc = normalize(row["esc"])
    if "dismiss" not in esc or not any(term in esc for term in ("no text change", "unchanged")):
        failures.append("Esc proof must show dismiss with no text change")

    pause = normalize(row["pause"])
    if "pause" not in pause or not any(term in pause for term in ("stopped", "no suggestion", "off")):
        failures.append("pause proof must show suggestions stopped")

    delete_traces = normalize(row["delete traces"])
    if "delete" not in delete_traces or not any(term in delete_traces for term in ("trace", "log")):
        failures.append("delete-traces proof must show local trace or log deletion")
    if not any(term in delete_traces for term in ("gone", "removed", "0 files")):
        failures.append("delete-traces proof must show files were removed")

    if not PASS_RESULT_PATTERN.search(normalize(row["result"])):
        failures.append("result must be pass or passed")

    evidence = normalize(row["evidence"])
    if not any(term in evidence for term in ("manual gate", "script/", "diagnostics", "trace", "lines")):
        failures.append("evidence must cite command output, diagnostics/trace lines, or a manual gate row")

    return failures


def is_nonpassing_manual_row(row: dict[str, str]) -> bool:
    result = normalize(row["result"])
    if PASS_RESULT_PATTERN.search(result):
        return False

    row_text = " ".join(normalize(value) for value in row.values())
    return contains_any(row_text, UNRESOLVED_TERMS)


def current_commit_token() -> str:
    commit = run_git(["rev-parse", "--short=12", "--verify", "HEAD"], check=True)
    return f"commit:{commit}"


def current_time_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).strftime("%Y-%m-%dT%H:%M:%SZ")


def proof_row_template() -> str:
    return (
        f"| {current_time_utc()} | `{current_commit_token()}` | "
        "steadytype-clean-2026-05-13 | "
        "Accessibility granted after app-owned Settings user-triggered Allow Accessibility | "
        "Runtime ready; app-owned MLX; no external server | "
        "TextEdit opened disposable local practice file | "
        "one-word Tab inserted verified next word | "
        "Esc dismissed with no text change | "
        "Pause stopped suggestions | "
        "Delete traces removed local trace/log files | "
        "pass | "
        "manual gate; diagnostics lines <start>-<end>; trace lines <start>-<end> |"
    )


def recording_template() -> str:
    header = (
        "| Time UTC | Build proof | macOS user | Accessibility | Runtime | "
        "TextEdit practice | Tab | Esc | Pause | Delete traces | Result | Evidence |"
    )
    separator = (
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    )
    return "\n".join(
        [
            "Onboarding walkthrough proof recording guide",
            "",
            "Only add a pass row after a real clean-user walkthrough. Do not copy this as proof from memory.",
            "",
            "Before the run:",
            "- Build or verify the current app.",
            "- Use a clean macOS tester account.",
            "- Keep typed text disposable and do not paste raw user text into docs.",
            "",
            "A pass row must prove:",
            "- app-owned explanation before Accessibility",
            "- user-triggered Accessibility grant",
            "- app-owned local MLX runtime ready with no external server",
            "- disposable TextEdit practice opened",
            "- one-word or next-word Tab insert verified",
            "- Esc dismiss with no text change",
            "- pause stops suggestions",
            "- local trace/log deletion removed files",
            "",
            f"Full runbook: {RECORDING_GUIDE}",
            "",
            header,
            separator,
            proof_row_template(),
        ]
    )


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT_DIR))
    except ValueError:
        return str(path)


def validate(path: Path) -> list[str]:
    try:
        source = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return [f"missing onboarding walkthrough proof file: {display_path(path)}"]

    rows = parse_walkthrough_rows(source)
    if not rows:
        return [
            "missing walkthrough proof table with columns: "
            + ", ".join(REQUIRED_COLUMNS)
        ]

    tokens = current_build_tokens()
    row_failures: list[str] = []
    nonpassing_rows: list[str] = []
    for index, row in enumerate(rows, start=1):
        if is_nonpassing_manual_row(row):
            result = row["result"].strip() or "empty"
            nonpassing_rows.append(
                f"row {index}: result is {result}; this is not completed pass proof"
            )
            continue

        failures = validate_row(row, tokens)
        if not failures:
            return []
        row_failures.extend(f"row {index}: {failure}" for failure in failures)

    if row_failures:
        return row_failures

    return [
        "no completed passing walkthrough proof row found",
        *nonpassing_rows,
        f"record a real manual row, then rerun this check; guide: {RECORDING_GUIDE}",
        "template: ./script/check_onboarding_walkthrough_proof.py --print-template",
    ]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate the guided TextEdit onboarding walkthrough proof gate."
    )
    parser.add_argument(
        "--proof",
        default=str(DEFAULT_PROOF),
        help="Markdown file containing the Guided TextEdit Walkthrough Proof table.",
    )
    parser.add_argument(
        "--print-template",
        action="store_true",
        help="Print the exact passing-row template and recording rules.",
    )
    args = parser.parse_args()

    if args.print_template:
        print(recording_template())
        return 0

    path = Path(args.proof)
    if not path.is_absolute():
        path = ROOT_DIR / path

    failures = validate(path)
    if failures:
        print("Onboarding walkthrough proof failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(f"Onboarding walkthrough proof passed: {display_path(path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
