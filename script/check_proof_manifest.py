#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT_DIR / "docs/product/proof-manifest.json"
DEFAULT_MANUAL_SMOKE = ROOT_DIR / "docs/product/manual-smoke-runs.md"
DEFAULT_SCORECARD = ROOT_DIR / "docs/product/deep-dive-scorecard-2026-05-06.md"
DEFAULT_APP_PROOF_MATRIX = ROOT_DIR / "docs/product/app-proof-matrix.md"
DEFAULT_COMPATIBILITY_PROFILES = ROOT_DIR / "Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift"
PROOF_METADATA_SOURCE = ROOT_DIR / "Sources/AutocompleteLabCore/Tracing/AutocompleteTraceProofMetadata.swift"
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
TRACE_REFERENCE_PATTERN = re.compile(
    r"lines\s+(\d+)(?:\s*-\s*(\d+)|\+)?\s+in\s+`?([^`;\s]+)`?"
)
PROOF_EVENT_TYPES = {
    "suggestionRequested",
    "modelResult",
    "suggestionPresented",
    "suggestionHidden",
    "suggestionAccepted",
    "suggestionSuppressed",
    "insertionVerified",
    "insertionFailed",
    "acceptedTextEdited",
    "caretGeometryFailed",
}
PROMPT_NO_SUBMIT_BUNDLES = {
    "com.openai.codex",
    "com.anthropic.claude-code",
    "com.anthropic.claudefordesktop",
}
NO_SUBMIT_ONLY_PROMPT_BUNDLES = PROMPT_NO_SUBMIT_BUNDLES
SUBMIT_LIKE_SIGNALS = {
    "fieldsend",
    "field-send",
    "field-send-finalized",
    "submit",
    "submitted",
    "prompt-submit",
    "prompt-submitted",
    "send",
    "sent",
    "enter",
    "return",
    "run",
    "run-command",
}
SUBMIT_SIGNAL_METADATA_KEYS = {
    "action",
    "checkpoint",
    "finishReason",
    "key",
    "keyboardAction",
    "outcome",
    "reason",
    "result",
}


def fail(message: str) -> None:
    print(f"Proof manifest check failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        fail(f"missing manifest {path}")
    except json.JSONDecodeError as error:
        fail(f"invalid JSON in {path}: {error}")


def current_proof_versions() -> dict[str, str]:
    source = PROOF_METADATA_SOURCE.read_text(encoding="utf-8")
    names = [
        "traceProofVersion",
        "placementProofVersion",
        "keyCaptureProofVersion",
        "runtimeProofVersion",
    ]
    versions: dict[str, str] = {}
    for name in names:
        match = re.search(rf'public static let {name} = "([^"]+)"', source)
        if not match:
            fail(f"could not find {name} in {PROOF_METADATA_SOURCE}")
        versions[name] = match.group(1)
    return versions


def current_commit() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT_DIR,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except subprocess.CalledProcessError:
        return ""


def compatibility_profiles(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        fail(f"missing compatibility profile source {path}")

    source = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r'CompatibilityProfile\(\s*bundleIdentifier:\s*"([^"]+)",\s*'
        r'displayName:\s*"([^"]+)".*?supportLevel:\s*\.([A-Za-z0-9_]+)',
        re.DOTALL,
    )
    profiles: dict[str, dict[str, str]] = {}
    for bundle, display_name, support_level in pattern.findall(source):
        profiles[bundle] = {
            "displayName": display_name,
            "supportLevel": support_level,
        }

    if not profiles:
        fail(f"could not find compatibility profiles in {path}")
    return profiles


def is_tracked(path: Path) -> bool:
    try:
        subprocess.check_output(
            ["git", "ls-files", "--error-unmatch", str(path.relative_to(ROOT_DIR))],
            cwd=ROOT_DIR,
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return True
    except (subprocess.CalledProcessError, ValueError):
        return False


def clean_cell(value: str) -> str:
    return value.strip().strip("`")


def split_markdown_row(line: str) -> list[str]:
    cells: list[str] = []
    current: list[str] = []
    in_code = False
    body = line.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|"):
        body = body[:-1]

    for character in body:
        if character == "`":
            in_code = not in_code
            current.append(character)
            continue
        if character == "|" and not in_code:
            cells.append(clean_cell("".join(current)))
            current = []
            continue
        current.append(character)
    cells.append(clean_cell("".join(current)))
    return cells


def manual_smoke_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    rows: list[dict[str, str]] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("|"):
            continue
        if "| Time UTC |" in line or "| --- |" in line:
            continue
        cells = split_markdown_row(line)
        if len(cells) < 8:
            continue
        rows.append(
            {
                "timeUTC": cells[0],
                "app": cells[1],
                "bundle": cells[2],
                "proof": cells[3],
                "verifiedAccepts": cells[4],
                "renderExpectation": cells[5],
                "diagnosticsSlice": cells[6],
                "traceSlice": cells[7],
            }
        )
    return rows


def app_proof_matrix_grades(path: Path, failures: list[str], require_matrix: bool) -> dict[str, str]:
    if not path.exists():
        if require_matrix:
            failures.append(f"missing app proof matrix {path}")
        return {}

    grades: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("|"):
            continue
        if "| Surface |" in line or "| --- |" in line:
            continue
        cells = split_markdown_row(line)
        if len(cells) < 2:
            continue
        surface = cells[0].strip()
        grade = cells[1].strip()
        if not surface or not re.fullmatch(r"[A-D][+-]?", grade):
            continue
        grades[surface] = grade

    if require_matrix and not grades:
        failures.append(f"app proof matrix has no parseable surface grades: {path}")
    return grades


def find_manual_row(rows: list[dict[str, str]], claim: dict) -> dict[str, str] | None:
    expected_app = str(claim.get("app", ""))
    expected_bundle = str(claim.get("bundle", ""))
    expected_proof = str(claim.get("proof", "default"))
    min_accepts = int(claim.get("minVerifiedAccepts", 1))
    max_accepts = claim.get("maxVerifiedAccepts")
    max_accepts = int(max_accepts) if max_accepts is not None else None
    for row in reversed(rows):
        if row["app"] != expected_app:
            continue
        if row["bundle"] != expected_bundle:
            continue
        if row["proof"] != expected_proof:
            continue
        try:
            accepts = int(row["verifiedAccepts"])
        except ValueError:
            continue
        if accepts >= min_accepts and (max_accepts is None or accepts <= max_accepts):
            return row
    return None


def parse_trace_reference(value: str) -> dict[str, object] | None:
    match = TRACE_REFERENCE_PATTERN.search(value)
    if not match:
        return None
    start_line = int(match.group(1))
    end_line = int(match.group(2)) if match.group(2) else None
    return {
        "startLine": start_line,
        "endLine": end_line,
        "path": repo_path(match.group(3).strip()),
        "isOpenEnded": end_line is None,
    }


def load_trace_slice(path: Path, start_line: int, end_line: int) -> tuple[list[dict], list[str]]:
    failures: list[str] = []
    events: list[dict] = []
    if not path.exists():
        return [], [f"trace file missing: {path}"]

    with path.open("r", encoding="utf-8") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            if line_number < start_line:
                continue
            if line_number > end_line:
                break
            line = raw_line.strip()
            if not line:
                continue
            try:
                decoded = json.loads(line)
            except json.JSONDecodeError as error:
                failures.append(f"invalid JSONL at {path}:{line_number}: {error}")
                continue
            if isinstance(decoded, dict):
                events.append(decoded)
            else:
                failures.append(f"trace event at {path}:{line_number} must be an object")

    return events, failures


def event_has_current_fingerprint(event: dict, current_versions: dict[str, str]) -> bool:
    metadata = event.get("metadata")
    if not isinstance(metadata, dict):
        return False
    return all(metadata.get(key) == expected for key, expected in current_versions.items())


def normalized_signal(value: object) -> str:
    return re.sub(r"[^a-z0-9-]+", "", str(value).strip().lower())


def is_submit_like_signal(value: object) -> bool:
    normalized = normalized_signal(value)
    if not normalized:
        return False
    if normalized in SUBMIT_LIKE_SIGNALS:
        return True
    return any(signal in normalized for signal in {"fieldsend", "prompt-submit", "submitted"})


def submit_like_trace_signal(event: dict) -> str | None:
    for key in ["type", "outcome", "reason", "triggerReason"]:
        value = event.get(key)
        if is_submit_like_signal(value):
            return f"{key}={value}"

    metadata = event.get("metadata")
    if isinstance(metadata, dict):
        for key in SUBMIT_SIGNAL_METADATA_KEYS:
            value = metadata.get(key)
            if is_submit_like_signal(value):
                return f"metadata.{key}={value}"

    return None


def is_full_accept_event(event: dict) -> bool:
    metadata = event.get("metadata")
    accept_mode = metadata.get("acceptMode") if isinstance(metadata, dict) else None
    accepted_scope = metadata.get("acceptedVisibleScope") if isinstance(metadata, dict) else None
    return (
        event.get("outcome") == "acceptAllVisible"
        or accept_mode in {"acceptAllVisible", "full"}
        or accepted_scope == "fullVisible"
    )


def is_prompt_no_submit_surface(name: str, claim: dict) -> bool:
    bundle = str(claim.get("bundle", "")).strip()
    proof = str(claim.get("proof", "")).strip().lower()
    normalized_name = name.strip().lower()
    if bundle in PROMPT_NO_SUBMIT_BUNDLES:
        return True
    return bundle == "com.google.Chrome" and (
        proof == "chat-like" or "chrome chat-like" in normalized_name
    )


def is_no_submit_only_prompt_surface(name: str, claim: dict) -> bool:
    bundle = str(claim.get("bundle", "")).strip()
    if bundle in NO_SUBMIT_ONLY_PROMPT_BUNDLES:
        return True
    return name.strip().lower() in {"codex", "claude code", "claude desktop"}


def verify_manual_trace_slice(
    name: str,
    claim: dict,
    matched: dict[str, str],
    current_versions: dict[str, str],
    require_bounded_trace_slices: bool,
    trace_window_lines: int,
    require_prompt_no_submit: bool,
) -> tuple[list[str], list[str], bool]:
    failures: list[str] = []
    warnings: list[str] = []
    reference = parse_trace_reference(matched["traceSlice"])
    if reference is None:
        return [f"{name}: matched manual smoke row is missing a parseable trace slice"], [], False

    start_line = int(reference["startLine"])
    end_line = reference["endLine"]
    is_open_ended = bool(reference["isOpenEnded"])
    if is_open_ended:
        if require_bounded_trace_slices:
            failures.append(f"{name}: trace proof must use bounded line evidence, not lines {start_line}+")
        else:
            warnings.append(f"{name}: trace proof is open-ended; using a {trace_window_lines}-line verification window")
        end_line = start_line + trace_window_lines - 1

    assert isinstance(end_line, int)
    trace_path = reference["path"]
    assert isinstance(trace_path, Path)
    events, load_failures = load_trace_slice(trace_path, start_line, end_line)
    failures.extend(f"{name}: {failure}" for failure in load_failures)
    if not events:
        failures.append(f"{name}: trace slice is empty")
        return failures, warnings, False

    expected_bundle = str(claim.get("bundle", ""))
    app_events = [event for event in events if event.get("appBundleIdentifier") == expected_bundle]
    if not app_events:
        failures.append(f"{name}: trace slice has no events for {expected_bundle}")
        return failures, warnings, False

    min_accepts = int(claim.get("minVerifiedAccepts", 1))
    max_accepts = claim.get("maxVerifiedAccepts")
    max_accepts = int(max_accepts) if max_accepts is not None else None
    accepted = [event for event in app_events if event.get("type") == "suggestionAccepted"]
    verified = [
        event
        for event in app_events
        if event.get("type") == "insertionVerified" and event.get("outcome") == "verified"
    ]
    if len(accepted) < min_accepts:
        failures.append(f"{name}: trace slice has {len(accepted)} accepts; expected at least {min_accepts}")
    if len(verified) < min_accepts:
        failures.append(f"{name}: trace slice has {len(verified)} verified insertions; expected at least {min_accepts}")
    if max_accepts is not None and len(verified) > max_accepts:
        failures.append(f"{name}: trace slice has {len(verified)} verified insertions; expected at most {max_accepts}")

    if claim.get("requiresVisualStrictComplete") is True:
        if "strict-complete" not in matched["traceSlice"]:
            failures.append(f"{name}: matched manual smoke row is missing visual strict-complete")
        screenshot_events = [
            event
            for event in app_events
            if event.get("type") == "suggestionPresented" and str(event.get("screenshotPath", "")).strip()
        ]
        if not screenshot_events:
            failures.append(f"{name}: strict visual proof requires screenshot-backed presented trace events")

    if require_prompt_no_submit and is_prompt_no_submit_surface(name, claim):
        submit_signals = [
            signal
            for event in app_events
            if (signal := submit_like_trace_signal(event)) is not None
        ]
        if submit_signals:
            failures.append(
                f"{name}: prompt no-submit trace contains submit-like signal(s): "
                + ", ".join(submit_signals[:3])
            )

        if is_no_submit_only_prompt_surface(name, claim):
            full_accepts = [
                event
                for event in app_events
                if event.get("type") in {"suggestionAccepted", "insertionVerified", "acceptedTextEdited"}
                and is_full_accept_event(event)
            ]
            if full_accepts:
                failures.append(
                    f"{name}: no-submit-only prompt proof contains full accept; "
                    "use one-word Tab proof until separate full-accept no-submit proof exists"
                )

    proof_events = [event for event in app_events if event.get("type") in PROOF_EVENT_TYPES]
    if not proof_events:
        failures.append(f"{name}: trace slice has no proof-gated events")
    else:
        stale_count = sum(
            1
            for event in proof_events
            if not event_has_current_fingerprint(event, current_versions)
        )
        if stale_count:
            failures.append(
                f"{name}: {stale_count}/{len(proof_events)} proof events are missing current proof fingerprints"
            )

    return failures, warnings, not failures


def referenced_scorecard_screenshots(path: Path) -> set[str]:
    if not path.exists():
        return set()
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r"visual-placement-screenshots/[^)\s]+[.]png", text))


def is_png(path: Path) -> bool:
    try:
        with path.open("rb") as handle:
            return handle.read(len(PNG_MAGIC)) == PNG_MAGIC
    except FileNotFoundError:
        return False


def repo_path(value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else ROOT_DIR / path


def verify_manifest(
    manifest_path: Path,
    manual_smoke_path: Path,
    scorecard_path: Path,
    app_proof_matrix_path: Path,
    compatibility_profiles_path: Path,
    require_all: bool,
    require_current_commit: bool,
    skip_profile_coverage: bool,
    verify_trace_slices: bool,
    require_bounded_trace_slices: bool,
    trace_window_lines: int,
) -> int:
    manifest = load_json(manifest_path)
    failures: list[str] = []
    warnings: list[str] = []

    if manifest.get("schemaVersion") != 1:
        failures.append("schemaVersion must be 1")

    profile_coverage_count = 0
    if not skip_profile_coverage:
        profile_coverage_count = verify_profile_coverage(
            manifest,
            compatibility_profiles(compatibility_profiles_path),
            failures,
        )

    proof_fingerprint = manifest.get("proofFingerprint", {})
    current_versions = current_proof_versions()
    for key, expected in current_versions.items():
        actual = proof_fingerprint.get(key)
        if actual != expected:
            failures.append(f"proofFingerprint.{key} is {actual!r}; expected {expected!r}")

    manifest_commit = str(manifest.get("sourceCommit", ""))
    head = current_commit()
    if require_current_commit and head and manifest_commit != head:
        failures.append(f"sourceCommit is {manifest_commit or 'missing'}; expected current HEAD {head}")

    surfaces = manifest.get("surfaces")
    if not isinstance(surfaces, list) or not surfaces:
        failures.append("surfaces must be a non-empty list")
        surfaces = []

    names: set[str] = set()
    smoke_rows = manual_smoke_rows(manual_smoke_path)
    scorecard_screenshots = referenced_scorecard_screenshots(scorecard_path)
    app_proof_grades = app_proof_matrix_grades(
        app_proof_matrix_path,
        failures,
        require_matrix=require_all,
    )
    pending: list[str] = []
    partial: list[str] = []
    complete = 0
    verified_trace_slices = 0

    for index, surface in enumerate(surfaces):
        if not isinstance(surface, dict):
            failures.append(f"surface entry {index + 1} must be an object")
            continue

        name = str(surface.get("surface", "")).strip()
        if not name:
            failures.append(f"surface entry {index + 1} is missing surface")
            continue
        if name in names:
            failures.append(f"duplicate surface: {name}")
        names.add(name)

        status = str(surface.get("status", "")).strip()
        if status not in {"complete", "partial", "pending", "blocked"}:
            failures.append(f"{name}: status must be complete, partial, pending, or blocked")
            continue

        gaps = surface.get("gaps", [])
        if status == "complete":
            complete += 1
            if gaps:
                failures.append(f"{name}: complete surfaces must not list gaps")
            if require_all and app_proof_grades.get(name) == "A-":
                failures.append(
                    f"{name}: app proof matrix grade is A-; variant-incomplete proof must stay partial"
                )
        else:
            if status == "partial":
                partial.append(name)
            else:
                pending.append(name)
            if require_all:
                failures.append(f"{name}: proof is {status}, not complete")
            if not gaps:
                failures.append(f"{name}: {status} surfaces must list at least one gap")

        manual_smoke = surface.get("manualSmoke")
        if status == "complete" and not isinstance(manual_smoke, dict):
            failures.append(f"{name}: complete proof requires manualSmoke")
        elif isinstance(manual_smoke, dict):
            matched = find_manual_row(smoke_rows, manual_smoke)
            if matched is None:
                failures.append(
                    f"{name}: no manual smoke row for "
                    f"{manual_smoke.get('app')} {manual_smoke.get('bundle')} proof={manual_smoke.get('proof', 'default')}"
                )
            elif manual_smoke.get("requiresVisualStrictComplete") is True and "strict-complete" not in matched["traceSlice"]:
                failures.append(f"{name}: matched manual smoke row is missing visual strict-complete")
            elif verify_trace_slices:
                trace_failures, trace_warnings, trace_verified = verify_manual_trace_slice(
                    name,
                    manual_smoke,
                    matched,
                    current_versions,
                    require_bounded_trace_slices,
                    trace_window_lines,
                    require_all,
                )
                failures.extend(trace_failures)
                warnings.extend(trace_warnings)
                if trace_verified:
                    verified_trace_slices += 1

        screenshots = surface.get("screenshots", [])
        if status == "complete" and not screenshots:
            failures.append(f"{name}: complete proof requires at least one screenshot")
        if screenshots and not isinstance(screenshots, list):
            failures.append(f"{name}: screenshots must be a list")
            screenshots = []
        for screenshot in screenshots:
            screenshot_text = str(screenshot)
            screenshot_path = repo_path(screenshot_text)
            if not screenshot_path.exists():
                failures.append(f"{name}: screenshot missing: {screenshot_text}")
                continue
            if screenshot_path.is_relative_to(ROOT_DIR) and not is_tracked(screenshot_path):
                failures.append(f"{name}: screenshot is not tracked by git: {screenshot_text}")
            if not is_png(screenshot_path):
                failures.append(f"{name}: screenshot is not a PNG: {screenshot_text}")
            if screenshot_text.startswith("docs/product/"):
                scorecard_link = screenshot_text.removeprefix("docs/product/")
            else:
                scorecard_link = screenshot_text
            if scorecard_link not in scorecard_screenshots:
                failures.append(f"{name}: screenshot is not referenced by the scorecard: {screenshot_text}")

    print("Proof manifest status")
    print(f"Manifest: {manifest_path.relative_to(ROOT_DIR) if manifest_path.is_relative_to(ROOT_DIR) else manifest_path}")
    print(f"Complete surfaces: {complete}")
    print(f"Partial surfaces: {len(partial)}")
    print(f"Pending surfaces: {len(pending)}")
    if not skip_profile_coverage:
        print(f"Profile coverage rows: {profile_coverage_count}")
    if verify_trace_slices:
        print(f"Verified trace slices: {verified_trace_slices}")
    if partial:
        print("Partial proof:")
        for name in partial:
            print(f"- {name}")
    if pending:
        print("Pending proof:")
        for name in pending:
            print(f"- {name}")
    for warning in warnings:
        print(f"Warning: {warning}")

    if failures:
        print("", file=sys.stderr)
        print("Proof manifest gaps:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        print(f"Proof manifest check failed with {len(failures)} issue(s).", file=sys.stderr)
        return 1

    print("Proof manifest verified.")
    return 0


def verify_profile_coverage(
    manifest: dict,
    expected_profiles: dict[str, dict[str, str]],
    failures: list[str],
) -> int:
    rows = manifest.get("profileCoverage")
    if not isinstance(rows, list) or not rows:
        failures.append("profileCoverage must list every CompatibilityProfile bundle")
        return 0

    allowed_statuses = {"complete", "partial", "pending", "blocked"}
    seen: dict[str, dict] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"profileCoverage entry {index + 1} must be an object")
            continue

        bundle = str(row.get("bundle", "")).strip()
        if not bundle:
            failures.append(f"profileCoverage entry {index + 1} is missing bundle")
            continue
        if bundle in seen:
            failures.append(f"profileCoverage duplicate bundle: {bundle}")
        seen[bundle] = row

        if bundle not in expected_profiles:
            failures.append(f"profileCoverage unknown bundle: {bundle}")
            continue

        expected = expected_profiles[bundle]
        display_name = str(row.get("displayName", "")).strip()
        if display_name != expected["displayName"]:
            failures.append(
                f"profileCoverage {bundle}: displayName is {display_name!r}; expected {expected['displayName']!r}"
            )

        support_level = str(row.get("supportLevel", "")).strip()
        if support_level != expected["supportLevel"]:
            failures.append(
                f"profileCoverage {bundle}: supportLevel is {support_level!r}; expected {expected['supportLevel']!r}"
            )

        status = str(row.get("status", "")).strip()
        if status not in allowed_statuses:
            failures.append(f"profileCoverage {bundle}: status must be complete, partial, pending, or blocked")

        for key in ["surface", "owner", "safetyNote"]:
            if not str(row.get(key, "")).strip():
                failures.append(f"profileCoverage {bundle}: missing {key}")

    missing = sorted(set(expected_profiles) - set(seen))
    if missing:
        failures.append("profileCoverage missing bundle(s): " + ", ".join(missing))

    return len(seen)


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify machine-readable app proof status.")
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--manual-smoke", default=str(DEFAULT_MANUAL_SMOKE))
    parser.add_argument("--scorecard", default=str(DEFAULT_SCORECARD))
    parser.add_argument("--app-proof-matrix", default=str(DEFAULT_APP_PROOF_MATRIX))
    parser.add_argument("--compatibility-profiles", default=str(DEFAULT_COMPATIBILITY_PROFILES))
    parser.add_argument("--require-all", "--strict", action="store_true", dest="require_all")
    parser.add_argument("--require-current-commit", action="store_true")
    parser.add_argument("--skip-profile-coverage", action="store_true")
    parser.add_argument("--verify-trace-slices", action="store_true")
    parser.add_argument("--require-bounded-trace-slices", action="store_true")
    parser.add_argument("--trace-window-lines", type=int, default=80)
    args = parser.parse_args()
    if args.trace_window_lines < 1:
        fail("--trace-window-lines must be at least 1")

    return verify_manifest(
        manifest_path=repo_path(args.manifest),
        manual_smoke_path=repo_path(args.manual_smoke),
        scorecard_path=repo_path(args.scorecard),
        app_proof_matrix_path=repo_path(args.app_proof_matrix),
        compatibility_profiles_path=repo_path(args.compatibility_profiles),
        require_all=args.require_all,
        require_current_commit=args.require_current_commit,
        skip_profile_coverage=args.skip_profile_coverage,
        verify_trace_slices=args.verify_trace_slices or args.require_all,
        require_bounded_trace_slices=args.require_bounded_trace_slices or args.require_all,
        trace_window_lines=args.trace_window_lines,
    )


if __name__ == "__main__":
    raise SystemExit(main())
