#!/usr/bin/env python3
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
    first_visible_samples: int
    model_samples: int


def fields_from(parts):
    fields = {}
    for part in parts:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key] = value
    return fields


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


def trace_window(path, timestamp):
    trace_start_line = None
    first_visible_samples = 0
    model_samples = 0

    if not timestamp or not path.exists():
        return TraceWindow(0, first_visible_samples, model_samples)

    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, line in enumerate(handle, start=1):
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            event_timestamp = str(event.get("timestamp") or "")
            if event_timestamp < timestamp:
                continue

            if trace_start_line is None:
                trace_start_line = max(0, line_number - 1)

            event_type = event.get("type")
            if event_type == "suggestionPresented" and event.get("latencyMilliseconds") is not None:
                first_visible_samples += 1
                continue

            if event_type == "modelResult":
                metadata = event.get("metadata") or {}
                if (
                    event.get("latencyMilliseconds") is not None
                    or metadata.get("firstTokenLatencyMilliseconds") is not None
                    or metadata.get("totalGenerationLatencyMilliseconds") is not None
                ):
                    model_samples += 1

    return TraceWindow(trace_start_line or 0, first_visible_samples, model_samples)


def eligible_default_launches(launches, expected_asset):
    return [
        launch
        for launch in launches
        if launch.asset == expected_asset
        and not launch.model_override
        and launch.candidate == "mlx"
        and launch.native_runtime_available == "true"
    ]


def select_window(
    diagnostics_log,
    trace_log,
    expected_asset,
    min_first_visible_samples,
    min_model_samples,
):
    launches = eligible_default_launches(runtime_launches(diagnostics_log), expected_asset)
    if not launches:
        return None, None, "no eligible default runtime launch"

    latest_window = trace_window(trace_log, launches[-1].timestamp)
    for launch in reversed(launches):
        window = trace_window(trace_log, launch.timestamp)
        if (
            window.first_visible_samples >= min_first_visible_samples
            and window.model_samples >= min_model_samples
        ):
            return launch, window, "selected latest sampled default runtime launch"

    return launches[-1], latest_window, "latest default runtime launch has too few samples"


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

    launch, window, reason = select_window(
        Path(args.diagnostics_log).expanduser(),
        Path(args.trace_log).expanduser(),
        args.expected_asset,
        args.min_first_visible_samples,
        args.min_model_samples,
    )

    if launch is None or window is None:
        print(f"Latency window: {reason}", file=sys.stderr)
        return 1

    print(
        "Latency window: "
        f"{reason}; diagnosticsLine={launch.line}; traceStartLine={window.start_line}; "
        f"firstVisibleSamples={window.first_visible_samples}; modelSamples={window.model_samples}",
        file=sys.stderr,
    )
    print(f"AUTOCOMPLETE_LAB_LOG_START_LINE={max(0, launch.line - 1)}")
    print(f"AUTOCOMPLETE_LAB_TRACE_START_LINE={window.start_line}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
