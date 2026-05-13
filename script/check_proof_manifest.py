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
HOST_POLICY_SOURCE = ROOT_DIR / "Sources/AutocompleteLabCore/Configuration/HostCompatibilityPolicy.swift"
CURRENT_PROOF_SOURCE_PATHS = (
    "Package.swift",
    "Package.resolved",
    "Sources",
    "script/local_completion_runtime.py",
    "script/real_app_smoke.sh",
)
EXPECTED_GRADUATION_DECISIONS = {
    "Google Docs in Chrome": {
        "decision": "blocked",
        "proofState": "blocked",
        "smokeCommand": "script/real_app_smoke.sh chrome --fixture google-docs",
        "requiredProof": {
            "correct placement",
            "safe Tab",
            "no submit/send",
            "no sensitive-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        },
    },
    "Notion browser or desktop": {
        "decision": "blocked",
        "proofState": "blocked",
        "smokeCommand": "script/real_app_smoke.sh chrome --fixture notion",
        "requiredProof": {
            "correct placement",
            "safe Tab",
            "no submit/send",
            "no sensitive-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        },
    },
    "Slack browser or desktop": {
        "decision": "blocked",
        "proofState": "blocked",
        "smokeCommand": "script/real_app_smoke.sh chrome --fixture browser-slack",
        "requiredProof": {
            "correct placement",
            "safe Tab",
            "no submit/send",
            "no sensitive-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        },
    },
    "Discord browser or desktop": {
        "decision": "blocked",
        "proofState": "blocked",
        "smokeCommand": "script/real_app_smoke.sh chrome --fixture browser-discord",
        "requiredProof": {
            "correct placement",
            "safe Tab",
            "no submit/send",
            "no sensitive-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        },
    },
    "Mail compose": {
        "decision": "diagnostics-only",
        "proofState": "blocked",
        "smokeCommand": None,
        "requiredProof": {
            "compose-body-only placement",
            "safe Tab",
            "no recipient/search/account-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        },
    },
    "Browser ChatGPT": {
        "decision": "blocked",
        "proofState": "blocked",
        "smokeCommand": "script/real_app_smoke.sh chrome --fixture browser-chatgpt",
        "requiredProof": {
            "correct placement",
            "safe one-word Tab",
            "no submit/send",
            "no tool/context side effect",
            "no sensitive-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        },
    },
    "Claude desktop layouts": {
        "decision": "word-only",
        "proofState": "partial",
        "smokeCommand": "script/real_app_smoke.sh claude-empty --manual-gate",
        "requiredProof": {
            "empty prompt layout",
            "long prompt layout",
            "wrapped prompt layout",
            "narrow window layout",
            "context layout",
            "light appearance",
            "dark appearance",
        },
    },
    "Codex layouts": {
        "decision": "word-only",
        "proofState": "complete",
        "smokeCommand": "script/real_app_smoke.sh codex --manual-gate",
        "requiredProof": {
            "more prompt layouts before raising beyond word-only",
            "separate full-accept no-submit proof before enabling full accept",
        },
    },
    "Obsidian long notes": {
        "decision": "blocked",
        "proofState": "blocked",
        "smokeCommand": "script/real_app_smoke.sh obsidian-long-note --manual-gate",
        "requiredProof": {
            "correct scrolled CodeMirror caret source",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        },
    },
    "Real Monaco and CodeMirror editors": {
        "decision": "blocked",
        "proofState": "blocked",
        "smokeCommand": "script/real_app_smoke.sh chrome --fixture monaco-official",
        "requiredProof": {
            "official CodeMirror proof",
            "official Monaco proof",
            "default-AX Monaco proof",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        },
    },
}
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
    "acceptanceRetentionCleared",
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


def current_host_policy_version() -> str:
    source = HOST_POLICY_SOURCE.read_text(encoding="utf-8")
    match = re.search(r'currentPolicyVersion\s*=\s*"([^"]+)"', source)
    if not match:
        fail(f"could not find currentPolicyVersion in {HOST_POLICY_SOURCE}")
    return match.group(1)


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


def source_commit_is_current_compatible(source_commit: str, head: str) -> bool:
    if not source_commit or not head:
        return False
    try:
        proof_commit = subprocess.check_output(
            ["git", "rev-parse", "--verify", f"{source_commit}^{{commit}}"],
            cwd=ROOT_DIR,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except subprocess.CalledProcessError:
        return False

    if proof_commit == head:
        return True

    try:
        subprocess.check_call(
            ["git", "diff", "--quiet", f"{proof_commit}..{head}", "--", *CURRENT_PROOF_SOURCE_PATHS],
            cwd=ROOT_DIR,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except subprocess.CalledProcessError:
        return False


def proof_sensitive_worktree_changes() -> list[str]:
    try:
        output = subprocess.check_output(
            [
                "git",
                "status",
                "--porcelain",
                "--untracked-files=all",
                "--",
                *CURRENT_PROOF_SOURCE_PATHS,
            ],
            cwd=ROOT_DIR,
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return ["unable to inspect proof-sensitive worktree paths"]

    changes: list[str] = []
    for line in output.splitlines():
        path = line[3:].strip() if len(line) > 3 else line.strip()
        if path:
            changes.append(path)
    return changes


def compatibility_profiles(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        fail(f"missing compatibility profile source {path}")

    source = path.read_text(encoding="utf-8")
    starts = [match.start() for match in re.finditer(r"CompatibilityProfile\(", source)]
    profiles: dict[str, dict[str, str]] = {}
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else len(source)
        block = source[start:end]
        bundle_match = re.search(r'bundleIdentifier:\s*"([^"]+)"', block)
        display_match = re.search(r'displayName:\s*"([^"]+)"', block)
        support_match = re.search(r"supportLevel:\s*\.([A-Za-z0-9_]+)", block)
        if not bundle_match or not display_match or not support_match:
            continue
        prompt_safety_match = re.search(r"promptAppSafetyMode:\s*\.([A-Za-z0-9_]+)", block)
        bundle = bundle_match.group(1)
        profiles[bundle] = {
            "displayName": display_match.group(1),
            "supportLevel": support_match.group(1),
            "promptAppSafetyMode": prompt_safety_match.group(1) if prompt_safety_match else "notPrompt",
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


def requirement_label(requirement: dict) -> str:
    requirement_id = str(requirement.get("id", "")).strip()
    summary = str(requirement.get("summary", "")).strip()
    smoke_command = str(requirement.get("smokeCommand", "")).strip()
    label = requirement_id or "unnamed-requirement"
    if summary:
        label = f"{label} - {summary}"
    if smoke_command:
        label = f"{label} (run {smoke_command})"
    return label


def validate_requirements(name: str, surface: dict, failures: list[str]) -> list[dict]:
    requirements = surface.get("requirements", [])
    if requirements in (None, []):
        return []
    if not isinstance(requirements, list):
        failures.append(f"{name}: requirements must be a list")
        return []

    valid: list[dict] = []
    seen: set[str] = set()
    for index, requirement in enumerate(requirements, start=1):
        if not isinstance(requirement, dict):
            failures.append(f"{name}: requirement {index} must be an object")
            continue
        requirement_id = str(requirement.get("id", "")).strip()
        status = str(requirement.get("status", "")).strip()
        summary = str(requirement.get("summary", "")).strip()
        if not requirement_id:
            failures.append(f"{name}: requirement {index} is missing id")
        elif requirement_id in seen:
            failures.append(f"{name}: duplicate requirement id: {requirement_id}")
        seen.add(requirement_id)
        if status not in {"complete", "pending", "blocked"}:
            failures.append(
                f"{name}: requirement {requirement_id or index} status must be complete, pending, or blocked"
            )
        if not summary:
            failures.append(f"{name}: requirement {requirement_id or index} is missing summary")
        valid.append(requirement)
    return valid


def validate_required_manual_smokes(name: str, surface: dict, failures: list[str]) -> list[dict]:
    required_smokes = surface.get("requiredManualSmokes", [])
    if required_smokes in (None, []):
        return []
    if not isinstance(required_smokes, list):
        failures.append(f"{name}: requiredManualSmokes must be a list")
        return []

    valid: list[dict] = []
    seen: set[str] = set()
    for index, smoke in enumerate(required_smokes, start=1):
        if not isinstance(smoke, dict):
            failures.append(f"{name}: requiredManualSmokes entry {index} must be an object")
            continue
        smoke_id = str(smoke.get("id", "")).strip()
        if not smoke_id:
            failures.append(f"{name}: requiredManualSmokes entry {index} is missing id")
        elif smoke_id in seen:
            failures.append(f"{name}: duplicate required manual smoke id: {smoke_id}")
        seen.add(smoke_id)

        for field in ["app", "bundle", "proof"]:
            if not str(smoke.get(field, "")).strip():
                failures.append(f"{name}: required manual smoke {smoke_id or index} is missing {field}")
        valid.append(smoke)
    return valid


def pending_requirement_labels(requirements: list[dict]) -> list[str]:
    return [
        requirement_label(requirement)
        for requirement in requirements
        if str(requirement.get("status", "")).strip() in {"pending", "blocked"}
    ]


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


def is_accepted_insertion_undo_event(event: dict) -> bool:
    metadata = event.get("metadata")
    metadata = metadata if isinstance(metadata, dict) else {}
    outcome = event.get("outcome") or metadata.get("outcome")
    reason = event.get("reason") or metadata.get("reason")
    return (
        event.get("type") == "acceptanceRetentionCleared"
        and outcome == "undone"
        and reason == "accepted-insertion-undone"
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

    if claim.get("requiresUndo") is True:
        undo_events = [event for event in app_events if is_accepted_insertion_undo_event(event)]
        if not undo_events:
            failures.append(
                f"{name}: undo proof requires acceptanceRetentionCleared "
                "outcome=undone reason=accepted-insertion-undone"
            )

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


def verify_manual_smoke_claim(
    name: str,
    claim: dict,
    smoke_rows: list[dict[str, str]],
    current_versions: dict[str, str],
    verify_trace_slices: bool,
    require_bounded_trace_slices: bool,
    trace_window_lines: int,
    require_prompt_no_submit: bool,
    failures: list[str],
    warnings: list[str],
) -> int:
    matched = find_manual_row(smoke_rows, claim)
    if matched is None:
        failures.append(
            f"{name}: no manual smoke row for "
            f"{claim.get('app')} {claim.get('bundle')} proof={claim.get('proof', 'default')}"
        )
        return 0

    if claim.get("requiresVisualStrictComplete") is True and "strict-complete" not in matched["traceSlice"]:
        failures.append(f"{name}: matched manual smoke row is missing visual strict-complete")

    if not verify_trace_slices:
        return 0

    trace_failures, trace_warnings, trace_verified = verify_manual_trace_slice(
        name,
        claim,
        matched,
        current_versions,
        require_bounded_trace_slices,
        trace_window_lines,
        require_prompt_no_submit,
    )
    failures.extend(trace_failures)
    warnings.extend(trace_warnings)
    return 1 if trace_verified else 0


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

    expected_profiles = compatibility_profiles(compatibility_profiles_path)
    profile_coverage_count = 0
    if not skip_profile_coverage:
        profile_coverage_count = verify_profile_coverage(
            manifest,
            expected_profiles,
            failures,
        )
    host_policy_count = verify_host_policy(manifest, expected_profiles, failures)
    graduation_decision_count = verify_graduation_decisions(
        manifest,
        failures,
        require_graduation_decisions=manifest_path.name == DEFAULT_MANIFEST.name
        or "graduationDecisions" in manifest,
    )

    proof_fingerprint = manifest.get("proofFingerprint", {})
    current_versions = current_proof_versions()
    for key, expected in current_versions.items():
        actual = proof_fingerprint.get(key)
        if actual != expected:
            failures.append(f"proofFingerprint.{key} is {actual!r}; expected {expected!r}")

    manifest_commit = str(manifest.get("sourceCommit", ""))
    head = current_commit()
    if require_current_commit and head and not source_commit_is_current_compatible(manifest_commit, head):
        failures.append(
            f"sourceCommit is {manifest_commit or 'missing'}; expected current HEAD {head} "
            "or a source-compatible commit with no changes in proof-sensitive app/smoke paths"
        )
    if require_current_commit:
        dirty_proof_paths = proof_sensitive_worktree_changes()
        if dirty_proof_paths:
            failures.append(
                "proof-sensitive source paths have uncommitted changes: "
                + ", ".join(dirty_proof_paths[:8])
            )

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
        requirements = validate_requirements(name, surface, failures)
        required_manual_smokes = validate_required_manual_smokes(name, surface, failures)
        pending_requirements = pending_requirement_labels(requirements)
        if status == "complete":
            complete += 1
            if gaps:
                failures.append(f"{name}: complete surfaces must not list gaps")
            if pending_requirements:
                failures.append(
                    f"{name}: complete proof still has pending requirement(s): "
                    + "; ".join(pending_requirements)
                )
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
                if pending_requirements:
                    failures.append(
                        f"{name}: proof is {status}, not complete; pending requirement(s): "
                        + "; ".join(pending_requirements)
                    )
                else:
                    failures.append(f"{name}: proof is {status}, not complete")
            if not gaps and not pending_requirements:
                failures.append(f"{name}: {status} surfaces must list at least one gap or pending requirement")

        has_manual_smoke_claim = False
        manual_smoke = surface.get("manualSmoke")
        if isinstance(manual_smoke, dict):
            has_manual_smoke_claim = True
            verified_trace_slices += verify_manual_smoke_claim(
                name,
                manual_smoke,
                smoke_rows,
                current_versions,
                verify_trace_slices,
                require_bounded_trace_slices,
                trace_window_lines,
                require_all,
                failures,
                warnings,
            )
        elif manual_smoke is not None:
            failures.append(f"{name}: manualSmoke must be an object")

        manual_smoke_variants = surface.get("manualSmokeVariants")
        if manual_smoke_variants is not None:
            if not isinstance(manual_smoke_variants, list):
                failures.append(f"{name}: manualSmokeVariants must be a list")
            else:
                for variant_index, variant in enumerate(manual_smoke_variants, start=1):
                    if not isinstance(variant, dict):
                        failures.append(
                            f"{name}: manualSmokeVariants entry {variant_index} must be an object"
                        )
                        continue
                    has_manual_smoke_claim = True
                    variant_proof = str(variant.get("proof", "default")).strip() or "default"
                    verified_trace_slices += verify_manual_smoke_claim(
                        f"{name} proof={variant_proof}",
                        variant,
                        smoke_rows,
                        current_versions,
                        verify_trace_slices,
                        require_bounded_trace_slices,
                        trace_window_lines,
                        require_all,
                        failures,
                        warnings,
                    )

        for required_smoke in required_manual_smokes:
            has_manual_smoke_claim = True
            required_smoke_id = str(required_smoke.get("id", "unnamed-required-smoke")).strip()
            matched = find_manual_row(smoke_rows, required_smoke)
            if matched is None:
                if status == "complete" or require_all:
                    failures.append(
                        f"{name}: missing required manual smoke {required_smoke_id}: "
                        f"no manual smoke row for {required_smoke.get('app')} "
                        f"{required_smoke.get('bundle')} proof={required_smoke.get('proof', 'default')}"
                    )
                continue

            if required_smoke.get("requiresVisualStrictComplete") is True and "strict-complete" not in matched["traceSlice"]:
                failures.append(
                    f"{name}: required manual smoke {required_smoke_id} is missing visual strict-complete"
                )

            if verify_trace_slices:
                trace_failures, trace_warnings, trace_verified = verify_manual_trace_slice(
                    f"{name} required smoke {required_smoke_id}",
                    required_smoke,
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

        if status == "complete" and not has_manual_smoke_claim:
            failures.append(f"{name}: complete proof requires manualSmoke, manualSmokeVariants, or requiredManualSmokes")

        for requirement in requirements:
            requirement_status = str(requirement.get("status", "")).strip()
            requirement_smoke = requirement.get("manualSmoke")
            if requirement_smoke is None:
                if (
                    require_all
                    and name.startswith("Apple Notes")
                    and requirement_status == "complete"
                ):
                    failures.append(
                        f"{name}: complete Notes requirement "
                        f"{requirement.get('id', 'unnamed-requirement')} requires manualSmoke evidence"
                    )
                continue
            if not isinstance(requirement_smoke, dict):
                failures.append(
                    f"{name}: requirement {requirement.get('id', 'unnamed-requirement')} manualSmoke must be an object"
                )
                continue
            if requirement_status == "complete":
                verified_trace_slices += verify_manual_smoke_claim(
                    f"{name} requirement {requirement.get('id', 'unnamed-requirement')}",
                    requirement_smoke,
                    smoke_rows,
                    current_versions,
                    verify_trace_slices,
                    require_bounded_trace_slices,
                    trace_window_lines,
                    require_all,
                    failures,
                    warnings,
                )

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
    print(f"Host policy rows: {host_policy_count}")
    print(f"Graduation decision rows: {graduation_decision_count}")
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
    requirement_rows: list[tuple[str, list[str]]] = []
    for surface in surfaces:
        if not isinstance(surface, dict):
            continue
        name = str(surface.get("surface", "")).strip()
        if not name:
            continue
        labels = pending_requirement_labels(validate_requirements(name, surface, []))
        if labels:
            requirement_rows.append((name, labels))
    if requirement_rows:
        print("Pending requirements:")
        for name, labels in requirement_rows:
            print(f"- {name}")
            for label in labels:
                print(f"  - {label}")
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


def verify_host_policy(
    manifest: dict,
    expected_profiles: dict[str, dict[str, str]],
    failures: list[str],
) -> int:
    host_policy = manifest.get("hostPolicy")
    if not isinstance(host_policy, dict):
        failures.append("hostPolicy must describe the versioned per-host safety policy")
        return 0

    policy_version = str(host_policy.get("policyVersion", "")).strip()
    expected_policy_version = current_host_policy_version()
    if policy_version != expected_policy_version:
        failures.append(
            f"hostPolicy.policyVersion is {policy_version!r}; expected {expected_policy_version!r}"
        )

    source = str(host_policy.get("source", "")).strip()
    if source != "Sources/AutocompleteLabCore/Configuration/HostCompatibilityPolicy.swift":
        failures.append("hostPolicy.source must point at HostCompatibilityPolicy.swift")
    elif not repo_path(source).exists():
        failures.append(f"hostPolicy.source is missing: {source}")

    entries = host_policy.get("entries")
    if not isinstance(entries, list) or not entries:
        failures.append("hostPolicy.entries must list every CompatibilityProfile bundle")
        return 0

    allowed_version_states = {"exact", "pending"}
    allowed_runtime_states = {"userToggleAllowed", "proofModeOnly", "diagnosticsOnly", "disabled"}
    allowed_proof_states = {"complete", "partial", "blocked", "pending"}
    allowed_kill_switches = {
        "none",
        "perHostDisable",
        "proofModeRequired",
        "diagnosticsOnly",
        "hardDisabled",
    }
    seen: dict[str, dict] = {}

    for index, entry in enumerate(entries, start=1):
        if not isinstance(entry, dict):
            failures.append(f"hostPolicy entry {index} must be an object")
            continue

        bundle = str(entry.get("bundle", "")).strip()
        if not bundle:
            failures.append(f"hostPolicy entry {index} is missing bundle")
            continue
        if bundle in seen:
            failures.append(f"hostPolicy duplicate bundle: {bundle}")
        seen[bundle] = entry

        if bundle not in expected_profiles:
            failures.append(f"hostPolicy unknown bundle: {bundle}")
            continue

        expected = expected_profiles[bundle]
        display_name = str(entry.get("displayName", "")).strip()
        if display_name != expected["displayName"]:
            failures.append(
                f"hostPolicy {bundle}: displayName is {display_name!r}; expected {expected['displayName']!r}"
            )

        safety_mode = str(entry.get("safetyMode", "")).strip()
        if safety_mode != expected["promptAppSafetyMode"]:
            failures.append(
                f"hostPolicy {bundle}: safetyMode is {safety_mode!r}; "
                f"expected {expected['promptAppSafetyMode']!r}"
            )

        version_state = str(entry.get("versionState", "")).strip()
        if version_state not in allowed_version_states:
            failures.append(f"hostPolicy {bundle}: versionState must be exact or pending")
        if version_state == "exact":
            for key in ["hostVersion", "hostBuild", "versionSource"]:
                if not str(entry.get(key, "")).strip():
                    failures.append(f"hostPolicy {bundle}: exact version is missing {key}")
        if version_state == "pending" and not str(entry.get("versionReason", "")).strip():
            failures.append(f"hostPolicy {bundle}: pending version needs versionReason")

        runtime_state = str(entry.get("runtimeState", "")).strip()
        if runtime_state not in allowed_runtime_states:
            failures.append(
                f"hostPolicy {bundle}: runtimeState must be one of {', '.join(sorted(allowed_runtime_states))}"
            )

        proof_state = str(entry.get("proofState", "")).strip()
        if proof_state not in allowed_proof_states:
            failures.append(
                f"hostPolicy {bundle}: proofState must be one of {', '.join(sorted(allowed_proof_states))}"
            )

        kill_switch = str(entry.get("killSwitch", "")).strip()
        if kill_switch not in allowed_kill_switches:
            failures.append(
                f"hostPolicy {bundle}: killSwitch must be one of {', '.join(sorted(allowed_kill_switches))}"
            )

        if expected["supportLevel"] == "diagnosticsOnly" and runtime_state == "userToggleAllowed":
            failures.append(f"hostPolicy {bundle}: diagnostics-only profiles cannot be user-toggle enabled")
        if safety_mode == "disabled" and runtime_state not in {"disabled", "diagnosticsOnly", "proofModeOnly"}:
            failures.append(f"hostPolicy {bundle}: disabled safety mode cannot allow normal suggestions")
        if safety_mode == "wordOnly" and kill_switch != "proofModeRequired":
            failures.append(f"hostPolicy {bundle}: word-only prompt hosts must have proofModeRequired kill switch")

        artifacts = entry.get("proofArtifacts", [])
        if artifacts is None:
            artifacts = []
        if not isinstance(artifacts, list):
            failures.append(f"hostPolicy {bundle}: proofArtifacts must be a list")
            artifacts = []
        if proof_state == "complete" and not artifacts:
            failures.append(f"hostPolicy {bundle}: complete proof needs proofArtifacts")
        for artifact in artifacts:
            if not isinstance(artifact, dict):
                failures.append(f"hostPolicy {bundle}: proofArtifact must be an object")
                continue
            kind = str(artifact.get("kind", "")).strip()
            reference = str(artifact.get("reference", "")).strip()
            if not kind or not reference:
                failures.append(f"hostPolicy {bundle}: proofArtifact needs kind and reference")
                continue
            if reference.startswith("docs/"):
                artifact_path = repo_path(reference)
                if not artifact_path.exists():
                    failures.append(f"hostPolicy {bundle}: proof artifact missing: {reference}")
                elif artifact_path.is_relative_to(ROOT_DIR) and not is_tracked(artifact_path):
                    failures.append(f"hostPolicy {bundle}: proof artifact is not tracked: {reference}")

        if not str(entry.get("notes", "")).strip():
            failures.append(f"hostPolicy {bundle}: missing notes")

    missing = sorted(set(expected_profiles) - set(seen))
    if missing:
        failures.append("hostPolicy missing bundle(s): " + ", ".join(missing))

    return len(seen)


def verify_graduation_decisions(
    manifest: dict,
    failures: list[str],
    require_graduation_decisions: bool,
) -> int:
    rows = manifest.get("graduationDecisions")
    if not isinstance(rows, list) or not rows:
        if require_graduation_decisions:
            failures.append("graduationDecisions must list focused high-value surface decisions")
        return 0

    seen: dict[str, dict] = {}
    for index, row in enumerate(rows, start=1):
        if not isinstance(row, dict):
            failures.append(f"graduationDecisions entry {index} must be an object")
            continue
        surface = str(row.get("surface", "")).strip()
        if not surface:
            failures.append(f"graduationDecisions entry {index} is missing surface")
            continue
        if surface in seen:
            failures.append(f"graduationDecisions duplicate surface: {surface}")
        seen[surface] = row

    expected_surfaces = set(EXPECTED_GRADUATION_DECISIONS)
    missing = sorted(expected_surfaces - set(seen))
    extra = sorted(set(seen) - expected_surfaces)
    if missing:
        failures.append("graduationDecisions missing surface(s): " + ", ".join(missing))
    if extra:
        failures.append("graduationDecisions unexpected surface(s): " + ", ".join(extra))

    for surface, expected in EXPECTED_GRADUATION_DECISIONS.items():
        row = seen.get(surface)
        if row is None:
            continue

        for key in ["decision", "proofState", "smokeCommand"]:
            actual = row.get(key)
            if actual != expected[key]:
                failures.append(
                    f"graduationDecisions {surface}: {key} is {actual!r}; expected {expected[key]!r}"
                )

        required_proof = row.get("requiredProof")
        if not isinstance(required_proof, list):
            failures.append(f"graduationDecisions {surface}: requiredProof must be a list")
            continue
        missing_proof = sorted(set(expected["requiredProof"]) - set(required_proof))
        if missing_proof:
            failures.append(
                f"graduationDecisions {surface}: missing requiredProof item(s): "
                + ", ".join(missing_proof)
            )

        decision = str(row.get("decision", "")).strip()
        if decision in {"blocked", "diagnostics-only"}:
            notes = str(row.get("notes", "")).strip().lower()
            if "until" not in notes and "disabled" not in notes and "diagnosed" not in notes:
                failures.append(
                    f"graduationDecisions {surface}: blocked/diagnostics row needs a concrete blocked-until note"
                )

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
