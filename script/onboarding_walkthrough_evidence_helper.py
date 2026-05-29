#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_LOG_DIR = Path.home() / "Library/Logs/SteadyType"
DEFAULT_DIAGNOSTICS_LOG = DEFAULT_LOG_DIR / "diagnostics.log"
DEFAULT_TRACE_LOG = DEFAULT_LOG_DIR / "traces.jsonl"
DEFAULT_RAW_TRACE_LOG = DEFAULT_LOG_DIR / "raw-traces.jsonl"
DEFAULT_SCREENSHOT_DIR = DEFAULT_LOG_DIR / "screenshots"


@dataclass(frozen=True)
class MatchedLine:
    number: int
    label: str


@dataclass(frozen=True)
class TraceSummary:
    textedit_lines: list[int]
    proof_lines: list[int]
    presented: int
    accepted_next_word: int
    accepted_total: int


def run_git(args: list[str]) -> str:
    process = subprocess.run(
        ["git", *args],
        cwd=ROOT_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    return process.stdout.strip()


def sha256_token(prefix: str, path: Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return f"{prefix}:{digest}"


def current_build_proof() -> str:
    proofs: list[str] = []
    commit = run_git(["rev-parse", "--short=12", "--verify", "HEAD"])
    if commit:
        proofs.append(f"commit:{commit}")

    for token in (
        sha256_token("app-sha256", ROOT_DIR / "dist/SteadyType.app/Contents/MacOS/SteadyType"),
        sha256_token("archive-sha256", ROOT_DIR / "dist/smoke-proof/SteadyType.zip"),
        sha256_token("archive-sha256", ROOT_DIR / "dist/SteadyType.zip"),
        sha256_token("archive-sha256", ROOT_DIR / "dist/SteadyType.dmg"),
    ):
        if token:
            proofs.append(token)

    return ", ".join(f"`{proof}`" for proof in proofs) if proofs else "none"


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT_DIR))
    except ValueError:
        return str(path)


def line_range(lines: list[int]) -> str:
    if not lines:
        return "none"
    if len(lines) == 1:
        return str(lines[0])
    return f"{min(lines)}-{max(lines)}"


def read_text_lines(path: Path) -> list[str]:
    if not path.is_file():
        return []
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def diagnostics_matches(path: Path) -> list[MatchedLine]:
    latest: dict[str, MatchedLine] = {}
    label_order = (
        "TextEdit practice started",
        "Local model ready at practice start",
        "TextEdit enabled at practice start",
        "Suggestions unpaused at practice start",
        "TextEdit Tab accepted one word",
        "TextEdit Esc dismissed suggestion",
        "Pause Suggestions turned on",
        "Delete Local Logs recorded",
    )

    for number, line in enumerate(read_text_lines(path), start=1):
        if "textedit-practice-started" in line:
            latest["TextEdit practice started"] = MatchedLine(number, "TextEdit practice started")
            if "model=ready" in line:
                latest["Local model ready at practice start"] = MatchedLine(
                    number,
                    "Local model ready at practice start",
                )
            if "textEditEnabled=true" in line:
                latest["TextEdit enabled at practice start"] = MatchedLine(
                    number,
                    "TextEdit enabled at practice start",
                )
            if "globalPaused=false" in line:
                latest["Suggestions unpaused at practice start"] = MatchedLine(
                    number,
                    "Suggestions unpaused at practice start",
                )
        if (
            "keyboard-action" in line
            and "action=acceptNextWord" in line
            and "app=com.apple.TextEdit" in line
            and "handled=true" in line
            and "key=tab" in line
        ):
            latest["TextEdit Tab accepted one word"] = MatchedLine(number, "TextEdit Tab accepted one word")
        if (
            "keyboard-action" in line
            and "action=dismiss" in line
            and "app=com.apple.TextEdit" in line
            and "handled=true" in line
            and "key=escape" in line
        ):
            latest["TextEdit Esc dismissed suggestion"] = MatchedLine(number, "TextEdit Esc dismissed suggestion")
        if "suggestions-control" in line and "paused=true" in line:
            latest["Pause Suggestions turned on"] = MatchedLine(number, "Pause Suggestions turned on")
        if "local-privacy-logs-deleted" in line:
            latest["Delete Local Logs recorded"] = MatchedLine(number, "Delete Local Logs recorded")

    return [latest[label] for label in label_order if label in latest]


def summarize_trace(path: Path) -> TraceSummary:
    textedit_lines: list[int] = []
    last_presented_line: int | None = None
    last_accepted_next_word_line: int | None = None
    presented = 0
    accepted_next_word = 0
    accepted_total = 0

    if not path.is_file():
        return TraceSummary(textedit_lines, [], presented, accepted_next_word, accepted_total)

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for number, raw_line in enumerate(handle, start=1):
            try:
                event = json.loads(raw_line)
            except json.JSONDecodeError:
                continue

            if event.get("appBundleIdentifier") != "com.apple.TextEdit":
                continue

            textedit_lines.append(number)
            event_type = event.get("type")
            if event_type == "suggestionPresented":
                presented += 1
                last_presented_line = number
            if event_type == "suggestionAccepted":
                accepted_total += 1
                if event.get("outcome") == "acceptNextWord":
                    accepted_next_word += 1
                    last_accepted_next_word_line = number

    proof_lines = [
        line
        for line in (last_presented_line, last_accepted_next_word_line)
        if line is not None
    ]
    return TraceSummary(textedit_lines, proof_lines, presented, accepted_next_word, accepted_total)


def file_missing_or_empty(path: Path) -> bool:
    return not path.exists() or (path.is_file() and path.stat().st_size == 0)


def folder_missing_or_empty(path: Path) -> bool:
    return not path.exists() or (path.is_dir() and not any(path.iterdir()))


def print_commands() -> None:
    print("Onboarding walkthrough evidence commands")
    print()
    print("Run these during the real clean-user walkthrough. They do not replace the manual proof row.")
    print()
    print("```bash")
    print("./script/build_and_run.sh --verify")
    print("# Complete Settings Practice in TextEdit through Tab, Esc, and Pause Suggestions.")
    print("./script/onboarding_walkthrough_evidence_helper.py --mode before-delete --require-ready > /tmp/steadytype-onboarding-before-delete.txt")
    print("# Click Delete Local Logs in SteadyType Settings Practice.")
    print("./script/onboarding_walkthrough_evidence_helper.py --mode after-delete --require-ready > /tmp/steadytype-onboarding-after-delete.txt")
    print("./script/check_onboarding_walkthrough_proof.py --print-template")
    print("# After recording the real row:")
    print("./script/check_onboarding_walkthrough_proof.py")
    print("```")


def before_delete_report(diagnostics_log: Path, trace_log: Path, require_ready: bool) -> int:
    matches = diagnostics_matches(diagnostics_log)
    trace = summarize_trace(trace_log)

    match_by_label = {match.label: match for match in matches}
    labels = set(match_by_label)
    practice_start = match_by_label.get("TextEdit practice started")
    practice_start_line = practice_start.number if practice_start is not None else None
    missing: list[str] = []
    for label in (
        "TextEdit practice started",
        "Local model ready at practice start",
        "TextEdit enabled at practice start",
        "Suggestions unpaused at practice start",
    ):
        if label not in labels:
            missing.append(label)
    for label in (
        "TextEdit Tab accepted one word",
        "TextEdit Esc dismissed suggestion",
        "Pause Suggestions turned on",
    ):
        match = match_by_label.get(label)
        if match is None:
            missing.append(label)
        elif practice_start_line is not None and match.number < practice_start_line:
            missing.append(f"{label} after TextEdit practice started")
    if trace.presented == 0:
        missing.append("TextEdit suggestionPresented trace event")
    if trace.accepted_next_word == 0:
        missing.append("TextEdit acceptNextWord suggestionAccepted trace event")

    diagnostics_lines = [match.number for match in matches if match.label != "Delete Local Logs recorded"]

    print("Onboarding walkthrough evidence helper: before-delete")
    print("This is not a pass row. It only checks redacted local evidence for the clean-user row.")
    print(f"Build proof: {current_build_proof()}")
    print(f"Diagnostics: {display_path(diagnostics_log)} lines {line_range(diagnostics_lines)}")
    if practice_start_line is not None:
        print(f"Latest TextEdit practice start line: {practice_start_line}")
    for match in matches:
        if match.label != "Delete Local Logs recorded":
            print(f"- line {match.number}: {match.label}")
    print(f"Trace: {display_path(trace_log)} lines {line_range(trace.proof_lines)}")
    print(f"- TextEdit suggestionPresented events: {trace.presented}")
    print(f"- TextEdit suggestionAccepted events: {trace.accepted_total}")
    print(f"- TextEdit acceptNextWord events: {trace.accepted_next_word}")

    if missing:
        print("Missing evidence:")
        for item in missing:
            print(f"- {item}")
    else:
        print(
            "Suggested Evidence cell before delete: "
            f"manual gate; diagnostics lines {line_range(diagnostics_lines)}; "
            f"trace lines {line_range(trace.proof_lines)}; before-delete helper OK"
        )

    return 1 if require_ready and missing else 0


def after_delete_report(
    diagnostics_log: Path,
    trace_log: Path,
    raw_trace_log: Path,
    screenshot_dir: Path,
    require_ready: bool,
) -> int:
    matches = diagnostics_matches(diagnostics_log)
    labels = {match.label for match in matches}
    missing: list[str] = []

    if "Delete Local Logs recorded" not in labels:
        missing.append("local-privacy-logs-deleted diagnostics event")
    if not file_missing_or_empty(trace_log):
        missing.append("traces.jsonl removed")
    if not file_missing_or_empty(raw_trace_log):
        missing.append("raw-traces.jsonl removed")
    if not folder_missing_or_empty(screenshot_dir):
        missing.append("screenshots folder removed or empty")

    delete_lines = [match.number for match in matches if match.label == "Delete Local Logs recorded"]

    print("Onboarding walkthrough evidence helper: after-delete")
    print("This is not a pass row. It only checks that local proof artifacts were deleted.")
    print(f"Diagnostics: {display_path(diagnostics_log)} lines {line_range(delete_lines)}")
    for match in matches:
        if match.label == "Delete Local Logs recorded":
            print(f"- line {match.number}: {match.label}")
    print(f"Trace JSONL removed: {'yes' if file_missing_or_empty(trace_log) else 'no'}")
    print(f"Raw trace JSONL removed: {'yes' if file_missing_or_empty(raw_trace_log) else 'no'}")
    print(f"Screenshots removed: {'yes' if folder_missing_or_empty(screenshot_dir) else 'no'}")

    if missing:
        print("Missing deletion evidence:")
        for item in missing:
            print(f"- {item}")
    else:
        print(
            "Suggested Evidence cell after delete: "
            f"delete helper OK; diagnostics lines {line_range(delete_lines)}; "
            "trace/log files gone"
        )

    return 1 if require_ready and missing else 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Collect redacted evidence hints for the manual onboarding walkthrough."
    )
    parser.add_argument(
        "--mode",
        choices=("before-delete", "after-delete"),
        default="before-delete",
        help="Which point in the manual walkthrough to inspect.",
    )
    parser.add_argument(
        "--print-commands",
        action="store_true",
        help="Print the copyable clean-user evidence commands.",
    )
    parser.add_argument(
        "--require-ready",
        action="store_true",
        help="Exit nonzero if required evidence for the selected mode is missing.",
    )
    parser.add_argument("--diagnostics-log", default=str(DEFAULT_DIAGNOSTICS_LOG))
    parser.add_argument("--trace-log", default=str(DEFAULT_TRACE_LOG))
    parser.add_argument("--raw-trace-log", default=str(DEFAULT_RAW_TRACE_LOG))
    parser.add_argument("--screenshot-dir", default=str(DEFAULT_SCREENSHOT_DIR))
    args = parser.parse_args()

    if args.print_commands:
        print_commands()
        return 0

    diagnostics_log = Path(args.diagnostics_log).expanduser()
    trace_log = Path(args.trace_log).expanduser()
    raw_trace_log = Path(args.raw_trace_log).expanduser()
    screenshot_dir = Path(args.screenshot_dir).expanduser()

    if args.mode == "before-delete":
        return before_delete_report(diagnostics_log, trace_log, args.require_ready)

    return after_delete_report(
        diagnostics_log,
        trace_log,
        raw_trace_log,
        screenshot_dir,
        args.require_ready,
    )


if __name__ == "__main__":
    raise SystemExit(main())
