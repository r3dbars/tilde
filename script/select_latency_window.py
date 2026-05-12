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


@dataclass(frozen=True)
class TraceWindow:
    start_line: int
    end_line: int | None
    first_visible_samples: int
    model_samples: int


@dataclass(frozen=True)
class Selection:
    launch: Launch | None
    window: TraceWindow | None
    reason: str
    ok: bool
    diagnostics_end_line: int | None = None
    stale_launch: Launch | None = None
    stale_window: TraceWindow | None = None


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
    if not path.exists():
        return launches

    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
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
                )
            )
    return launches


def trace_window(path, timestamp, before_timestamp=None):
    trace_start_line = None
    trace_end_line = None
    first_visible_samples = 0
    model_samples = 0
    seen_presented = set()
    seen_model = set()
    last_line_number = 0

    if not timestamp or not path.exists():
        return TraceWindow(0, trace_end_line, first_visible_samples, model_samples)

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

            event_type = event.get("type")
            if event_type == "suggestionPresented":
                key = suggestion_key(event, line_number)
                if key in seen_presented:
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
                    model_samples += 1

    if before_timestamp and trace_end_line is None:
        trace_end_line = last_line_number

    return TraceWindow(
        trace_start_line or 0,
        trace_end_line,
        first_visible_samples,
        model_samples,
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
):
    launches = runtime_launches(diagnostics_log)
    eligible_launches = eligible_default_launches(launches, expected_asset)
    if not eligible_launches:
        return Selection(None, None, "no eligible default runtime launch", False)

    latest_launch = launches[-1]
    if not is_eligible_default_launch(latest_launch, expected_asset):
        reason = (
            "latest runtime launch is not the expected default runtime "
            f"(diagnosticsLine={latest_launch.line}; asset={latest_launch.asset or 'unknown'}; "
            f"candidate={latest_launch.candidate or 'unknown'}; "
            f"modelOverride={latest_launch.model_override or 'none'}; "
            f"nativeRuntimeAvailable={latest_launch.native_runtime_available or 'unknown'})"
        )
        return Selection(latest_launch, trace_window(trace_log, latest_launch.timestamp), reason, False)

    current_segment_start = 0
    for index, launch in enumerate(launches[:-1]):
        if not is_eligible_default_launch(launch, expected_asset):
            current_segment_start = index + 1

    skipped_unsampled_default_launches = 0
    stale_launch = None
    stale_window = None
    eligible_indexed_launches = [
        (index, launch)
        for index, launch in enumerate(launches[current_segment_start:], start=current_segment_start)
        if is_eligible_default_launch(launch, expected_asset)
    ]
    for index, launch in reversed(eligible_indexed_launches):
        next_launch = launches[index + 1] if index + 1 < len(launches) else None
        before_timestamp = next_launch.timestamp if next_launch else None
        diagnostics_end_line = max(0, next_launch.line - 1) if next_launch else None
        window = trace_window(trace_log, launch.timestamp, before_timestamp)
        if (
            window.first_visible_samples >= min_first_visible_samples
            and window.model_samples >= min_model_samples
        ):
            reason = "selected latest sampled default runtime launch"
            if skipped_unsampled_default_launches:
                reason += f"; skippedUnsampledDefaultLaunches={skipped_unsampled_default_launches}"
            if stale_launch and stale_window:
                reason += (
                    "; currentDefaultRuntimeUnderSampled=true"
                    f"; currentDiagnosticsLine={stale_launch.line}"
                    f"; currentFirstVisibleSamples={stale_window.first_visible_samples}"
                    f"; currentModelSamples={stale_window.model_samples}"
                )
            return Selection(
                launch,
                window,
                reason,
                True,
                diagnostics_end_line,
                stale_launch,
                stale_window,
            )

        if window.first_visible_samples == 0 and window.model_samples == 0:
            skipped_unsampled_default_launches += 1
            continue

        if index == len(launches) - 1 or skipped_unsampled_default_launches > 0:
            stale_launch = launch
            stale_window = window
            continue

        return Selection(
            launch,
            window,
            "latest default runtime launch has too few samples",
            False,
            diagnostics_end_line,
        )

    window = trace_window(trace_log, latest_launch.timestamp)
    return Selection(
        latest_launch,
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
    args = parser.parse_args()

    selection = select_window(
        Path(args.diagnostics_log).expanduser(),
        Path(args.trace_log).expanduser(),
        args.expected_asset,
        args.min_first_visible_samples,
        args.min_model_samples,
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
        f"firstVisibleSamples={window.first_visible_samples}; modelSamples={window.model_samples}",
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
    if selection.stale_launch and selection.stale_window:
        print("AUTOCOMPLETE_LAB_LATENCY_WINDOW_STALE=1")
        print(
            "AUTOCOMPLETE_LAB_LATENCY_WINDOW_STALE_DIAGNOSTICS_LINE="
            f"{selection.stale_launch.line}"
        )
        print(
            "AUTOCOMPLETE_LAB_LATENCY_WINDOW_STALE_FIRST_VISIBLE_SAMPLES="
            f"{selection.stale_window.first_visible_samples}"
        )
        print(
            "AUTOCOMPLETE_LAB_LATENCY_WINDOW_STALE_MODEL_SAMPLES="
            f"{selection.stale_window.model_samples}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
