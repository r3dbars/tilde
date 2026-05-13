#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_EXPECTED_ASSET = "Qwen3.5-4B-4bit"


@dataclass(frozen=True)
class Launch:
    line: int
    timestamp: str
    asset: str
    candidate: str
    native_runtime_available: str
    model_override: str
    proof_app: str
    proof_scenario: str


@dataclass(frozen=True)
class TraceWindow:
    start_line: int
    end_line: int | None
    first_visible_samples: int
    model_samples: int
    fast_word_visible_samples: int


@dataclass(frozen=True)
class Selection:
    launch: Launch | None
    window: TraceWindow | None
    reason: str
    ok: bool
    diagnostics_end_line: int | None = None


def fields_from(parts):
    fields = {}
    for part in parts:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key] = value
    return fields


def int_value(value):
    if value is None or value == "none":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def suggestion_key(event, line_number):
    return event.get("suggestionID") or event.get("id") or f"line-{line_number}"


def runtime_launches(path):
    launches = []
    current_proof_app = ""
    current_proof_scenario = ""
    if not path.exists():
        return launches

    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if " app-proof-mode-started " in f" {stripped} ":
                parts = stripped.split()
                fields = fields_from(parts[1:])
                current_proof_app = fields.get("app", "")
                current_proof_scenario = fields.get("scenario", "")
                continue

            if " app-proof-mode-ended " in f" {stripped} ":
                parts = stripped.split()
                fields = fields_from(parts[1:])
                ended_app = fields.get("app", "")
                if not ended_app or ended_app == current_proof_app:
                    current_proof_app = ""
                    current_proof_scenario = ""
                continue

            if " runtime-bootstrap " not in f" {stripped} ":
                continue
            parts = stripped.split()
            if not parts:
                continue
            fields = fields_from(parts[1:])
            launches.append(
                Launch(
                    line=line_number,
                    timestamp=parts[0],
                    asset=fields.get("asset", ""),
                    candidate=fields.get("activeCandidate", ""),
                    native_runtime_available=fields.get("nativeRuntimeAvailable", ""),
                    model_override=fields.get("modelOverride", ""),
                    proof_app=current_proof_app,
                    proof_scenario=current_proof_scenario,
                )
            )
    return launches


def trace_window(
    path,
    timestamp,
    before_timestamp=None,
    required_trace_app=None,
    require_model_backed_visible=False,
    forbid_fast_word_visible=False,
):
    trace_start_line = None
    trace_end_line = None
    first_visible_samples = 0
    model_samples = 0
    fast_word_visible_samples = 0
    seen_presented = set()
    seen_model = set()
    model_backed_suggestion_ids = set()
    last_line_number = 0

    if not timestamp or not path.exists():
        return TraceWindow(
            0,
            trace_end_line,
            first_visible_samples,
            model_samples,
            fast_word_visible_samples,
        )

    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, line in enumerate(handle, start=1):
            last_line_number = line_number
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            event_timestamp = str(event.get("timestamp") or "")
            if event_timestamp < timestamp:
                continue
            if before_timestamp and event_timestamp >= before_timestamp:
                trace_end_line = max(0, line_number - 1)
                break

            if trace_start_line is None:
                trace_start_line = max(0, line_number - 1)

            if required_trace_app and event.get("appBundleIdentifier") != required_trace_app:
                continue

            event_type = event.get("type")
            if event_type == "suggestionPresented":
                key = suggestion_key(event, line_number)
                if key in seen_presented:
                    continue

                metadata = event.get("metadata") or {}
                selection_source = event.get("candidateSelectionSource") or metadata.get(
                    "candidateSelectionSource"
                )
                if forbid_fast_word_visible and selection_source == "fast-word-completion":
                    fast_word_visible_samples += 1

                if require_model_backed_visible:
                    if selection_source != "app-model-result" and key not in model_backed_suggestion_ids:
                        continue

                seen_presented.add(key)
                if int_value(event.get("latencyMilliseconds")) is not None:
                    first_visible_samples += 1
                continue

            if event_type == "modelResult":
                key = (suggestion_key(event, line_number), line_number)
                if key in seen_model:
                    continue
                seen_model.add(key)
                metadata = event.get("metadata") or {}
                generation_latency = int_value(
                    metadata.get("totalGenerationLatencyMilliseconds")
                )
                if generation_latency is None:
                    generation_latency = int_value(event.get("latencyMilliseconds"))
                if generation_latency is not None:
                    model_backed_suggestion_ids.add(suggestion_key(event, line_number))
                    model_samples += 1

    if before_timestamp and trace_end_line is None:
        trace_end_line = last_line_number

    return TraceWindow(
        trace_start_line or 0,
        trace_end_line,
        first_visible_samples,
        model_samples,
        fast_word_visible_samples,
    )


def eligible_default_launches(launches, expected_asset):
    return [
        launch
        for launch in launches
        if launch.asset == expected_asset
        and not launch.model_override
        and launch.candidate == "mlx"
        and launch.native_runtime_available == "true"
    ]


def is_eligible_default_launch(launch, expected_asset):
    return (
        launch.asset == expected_asset
        and not launch.model_override
        and launch.candidate == "mlx"
        and launch.native_runtime_available == "true"
    )


def select_window(
    diagnostics_log,
    trace_log,
    expected_asset,
    min_first_visible_samples,
    min_model_samples,
    required_proof_app=None,
    required_trace_app=None,
    require_model_backed_visible=False,
    required_proof_scenario=None,
    forbid_fast_word_visible=False,
):
    launches = runtime_launches(diagnostics_log)
    eligible_launches = eligible_default_launches(launches, expected_asset)
    if required_proof_app:
        eligible_launches = [
            launch for launch in eligible_launches if launch.proof_app == required_proof_app
        ]
    if required_proof_scenario:
        eligible_launches = [
            launch for launch in eligible_launches if launch.proof_scenario == required_proof_scenario
        ]

    if not eligible_launches:
        return Selection(None, None, "no eligible default runtime launch", False)

    latest_launch = launches[-1]
    if required_proof_app:
        required_launches = [
            launch
            for launch in launches
            if launch.proof_app == required_proof_app
            and (not required_proof_scenario or launch.proof_scenario == required_proof_scenario)
        ]
        latest_required_launch = required_launches[-1] if required_launches else None
    else:
        latest_required_launch = latest_launch

    if latest_required_launch and not is_eligible_default_launch(latest_required_launch, expected_asset):
        reason = (
            "latest runtime launch is not the expected default runtime "
            f"(diagnosticsLine={latest_required_launch.line}; asset={latest_required_launch.asset or 'unknown'}; "
            f"candidate={latest_required_launch.candidate or 'unknown'}; "
                f"modelOverride={latest_required_launch.model_override or 'none'}; "
                f"nativeRuntimeAvailable={latest_required_launch.native_runtime_available or 'unknown'}; "
                f"proofApp={latest_required_launch.proof_app or 'none'}; "
                f"proofScenario={latest_required_launch.proof_scenario or 'none'})"
        )
        return Selection(
            latest_required_launch,
            trace_window(
                trace_log,
                latest_required_launch.timestamp,
                required_trace_app=required_trace_app,
                require_model_backed_visible=require_model_backed_visible,
                forbid_fast_word_visible=forbid_fast_word_visible,
            ),
            reason,
            False,
        )

    current_segment_start = 0
    if not required_proof_app:
        for index, launch in enumerate(launches[:-1]):
            if not is_eligible_default_launch(launch, expected_asset):
                current_segment_start = index + 1

    skipped_unsampled_default_launches = 0
    eligible_indexed_launches = [
        (index, launch)
        for index, launch in enumerate(launches[current_segment_start:], start=current_segment_start)
        if is_eligible_default_launch(launch, expected_asset)
        and (not required_proof_app or launch.proof_app == required_proof_app)
        and (not required_proof_scenario or launch.proof_scenario == required_proof_scenario)
    ]
    for index, launch in reversed(eligible_indexed_launches):
        next_launch = launches[index + 1] if index + 1 < len(launches) else None
        before_timestamp = next_launch.timestamp if next_launch else None
        diagnostics_end_line = max(0, next_launch.line - 1) if next_launch else None
        window = trace_window(
            trace_log,
            launch.timestamp,
            before_timestamp,
            required_trace_app=required_trace_app,
            require_model_backed_visible=require_model_backed_visible,
            forbid_fast_word_visible=forbid_fast_word_visible,
        )
        if forbid_fast_word_visible and window.fast_word_visible_samples > 0:
            return Selection(
                launch,
                window,
                "selected latency window has fast word completion samples",
                False,
                diagnostics_end_line,
            )
        if (
            window.first_visible_samples >= min_first_visible_samples
            and window.model_samples >= min_model_samples
        ):
            reason = "selected latest sampled default runtime launch"
            if skipped_unsampled_default_launches:
                reason += f"; skippedUnsampledDefaultLaunches={skipped_unsampled_default_launches}"
            return Selection(launch, window, reason, True, diagnostics_end_line)

        if window.first_visible_samples == 0 and window.model_samples == 0:
            skipped_unsampled_default_launches += 1
            continue

        return Selection(
            launch,
            window,
            "latest default runtime launch has too few samples",
            False,
            diagnostics_end_line,
        )

    fallback_launch = latest_required_launch or latest_launch
    window = trace_window(
        trace_log,
        fallback_launch.timestamp,
        required_trace_app=required_trace_app,
        require_model_backed_visible=require_model_backed_visible,
        forbid_fast_word_visible=forbid_fast_word_visible,
    )
    return Selection(
        fallback_launch,
        window,
        "no sampled default runtime launch meets sample requirements",
        False,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Select a trustworthy latency proof window for beta readiness."
    )
    parser.add_argument("--diagnostics-log", required=True)
    parser.add_argument("--trace-log", required=True)
    parser.add_argument("--expected-asset", default=DEFAULT_EXPECTED_ASSET)
    parser.add_argument("--min-first-visible-samples", type=int, default=5)
    parser.add_argument("--min-model-samples", type=int, default=5)
    parser.add_argument(
        "--required-proof-app",
        help="Only select runtime launches started by this proof-mode app bundle.",
    )
    parser.add_argument(
        "--required-proof-scenario",
        help="Only select runtime launches tagged with this proof scenario.",
    )
    parser.add_argument(
        "--required-trace-app",
        help="Only count trace samples from this app bundle inside the selected window.",
    )
    parser.add_argument(
        "--require-model-backed-visible",
        action="store_true",
        help="Only count visible samples that are explicitly model-backed.",
    )
    parser.add_argument(
        "--forbid-fast-word-visible",
        action="store_true",
        help="Fail if the selected window contains a fast word completion presentation.",
    )
    args = parser.parse_args()

    selection = select_window(
        Path(args.diagnostics_log).expanduser(),
        Path(args.trace_log).expanduser(),
        args.expected_asset,
        args.min_first_visible_samples,
        args.min_model_samples,
        required_proof_app=args.required_proof_app,
        required_trace_app=args.required_trace_app,
        require_model_backed_visible=args.require_model_backed_visible,
        required_proof_scenario=args.required_proof_scenario,
        forbid_fast_word_visible=args.forbid_fast_word_visible,
    )
    launch = selection.launch
    window = selection.window
    reason = selection.reason

    if launch is None or window is None:
        print(f"Latency window: {reason}", file=sys.stderr)
        return 1

    print(
        "Latency window: "
        f"{reason}; diagnosticsLine={launch.line}; traceStartLine={window.start_line}; "
        f"diagnosticsEndLine={selection.diagnostics_end_line or 'none'}; "
        f"traceEndLine={window.end_line or 'none'}; "
        f"firstVisibleSamples={window.first_visible_samples}; modelSamples={window.model_samples}; "
        f"fastWordVisibleSamples={window.fast_word_visible_samples}",
        file=sys.stderr,
    )
    if not selection.ok:
        return 1

    print(f"AUTOCOMPLETE_LAB_LOG_START_LINE={max(0, launch.line - 1)}")
    print(f"AUTOCOMPLETE_LAB_TRACE_START_LINE={window.start_line}")
    if selection.diagnostics_end_line is not None:
        print(f"AUTOCOMPLETE_LAB_LOG_END_LINE={selection.diagnostics_end_line}")
    if window.end_line is not None:
        print(f"AUTOCOMPLETE_LAB_TRACE_END_LINE={window.end_line}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
