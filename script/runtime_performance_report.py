#!/usr/bin/env python3
import argparse
import datetime as dt
import statistics
import subprocess
from dataclasses import dataclass
from pathlib import Path


DEFAULT_DIAGNOSTICS_LOG = Path.home() / "Library/Logs/SteadyType/diagnostics.log"
DEFAULT_MODEL_ROOT = Path.home() / "Library/Application Support/AutocompleteLab/Models"
DEFAULT_LINE_LIMIT = 5000

SUPPORTED_MODELS = [
    ("qwen3-0.6b", "Qwen3Small/MLX/qwen3-0.6b-4bit"),
    ("qwen3-1.7b", "Qwen3Medium/MLX/qwen3-1.7b-4bit"),
    ("qwen35-4b", "Qwen35FourB/MLX/Qwen3.5-4B-4bit"),
    ("qwen35-9b", "Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit"),
    ("gemma-4-e2b", "Gemma4E2B/MLX/gemma-4-e2b-mlx"),
    ("gemma-4-e4b", "Gemma4E4B/MLX/gemma-4-e4b-4bit"),
    ("gemma-4-e4b-it-optiq", "Gemma4E4BItOptiQ/MLX/gemma-4-e4b-it-OptiQ-4bit"),
    ("gemma-4-26b", "Gemma4A4B/MLX/gemma-4-26b-a4b-it-4bit"),
]


@dataclass(frozen=True)
class LiveProcess:
    pid: int
    cpu_percent: float
    rss_mb: int
    elapsed: str


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def metric_summary(values):
    if not values:
        return None
    return {
        "n": len(values),
        "min": min(values),
        "avg": round(statistics.mean(values)),
        "p50": percentile(values, 0.50),
        "p90": percentile(values, 0.90),
        "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99),
        "max": max(values),
    }


def metric_line(label, values, unit):
    summary = metric_summary(values)
    if summary is None:
        return f"{label}: no samples"
    return (
        f"{label}: n={summary['n']} min={summary['min']}{unit} "
        f"avg={summary['avg']}{unit} p50={summary['p50']}{unit} "
        f"p95={summary['p95']}{unit} p99={summary['p99']}{unit} max={summary['max']}{unit}"
    )


def duration_values(rows):
    return [duration for _, _, _, duration in rows if duration is not None]


def timing_metric_line(label, rows, unit="ms"):
    if not rows:
        return f"{label}: no events"

    values = duration_values(rows)
    if not values:
        return f"{label}: no duration samples (events={len(rows)})"

    line = metric_line(label, values, unit)
    missing = len(rows) - len(values)
    if missing:
        line += f" (events={len(rows)}, missingDurations={missing})"
    return line


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
    except ValueError:
        return None


def parse_timestamp(value):
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def line_slice(path, line_limit):
    if not path.exists():
        return []
    rows = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if stripped:
                rows.append((line_number, stripped))
    if line_limit > 0:
        rows = rows[-line_limit:]
    return rows


def parse_diagnostics(path, line_limit):
    data = {
        "launches": [],
        "warm_starts": [],
        "warm_results": [],
        "warm_succeeded": [],
        "warm_failed": [],
        "warm_skipped": [],
        "model_loads": [],
        "model_load_succeeded": [],
        "model_load_failed": [],
        "model_load_cancelled": [],
        "model_load_reused": [],
        "first_token": [],
        "total_generation": [],
        "first_visible": [],
        "event_tap": [],
        "ax_p95_windows": [],
        "ax_p99_windows": [],
        "ax_max_windows": [],
        "event_tap_slow": 0,
        "ax_slow": 0,
        "late_visible": 0,
        "cancellations": 0,
    }
    warm_start_by_candidate = {}

    for line_number, line in line_slice(path, line_limit):
        parts = line.split()
        if len(parts) < 2:
            continue
        timestamp = parse_timestamp(parts[0])
        event = parts[1]
        fields = fields_from(parts[2:])

        if event == "runtime-bootstrap":
            data["launches"].append((line_number, fields))
            continue

        if event == "runtime-warm-start":
            candidate = fields.get("candidate", "unknown")
            warm_start_by_candidate[candidate] = timestamp
            data["warm_starts"].append((line_number, fields))
            continue

        if event in {"runtime-warm-succeeded", "runtime-warm-failed", "runtime-warm-skipped"}:
            duration = int_value(fields.get("warmMilliseconds"))
            candidate = fields.get("candidate", "unknown")
            if duration is None and timestamp and candidate in warm_start_by_candidate:
                duration = max(0, round((timestamp - warm_start_by_candidate[candidate]).total_seconds() * 1000))
            row = (line_number, event, fields, duration)
            data["warm_results"].append(row)
            if event == "runtime-warm-succeeded":
                data["warm_succeeded"].append(row)
            elif event == "runtime-warm-failed":
                data["warm_failed"].append(row)
            elif event == "runtime-warm-skipped":
                data["warm_skipped"].append(row)
            continue

        if event in {
            "mlx-model-load-succeeded",
            "mlx-model-load-failed",
            "mlx-model-load-cancelled",
            "mlx-model-load-reused",
        }:
            duration = int_value(fields.get("loadMilliseconds"))
            row = (line_number, event, fields, duration)
            data["model_loads"].append(row)
            if event == "mlx-model-load-succeeded":
                data["model_load_succeeded"].append(row)
            elif event == "mlx-model-load-failed":
                data["model_load_failed"].append(row)
            elif event == "mlx-model-load-cancelled":
                data["model_load_cancelled"].append(row)
            elif event == "mlx-model-load-reused":
                data["model_load_reused"].append(row)
            continue

        if event == "mlx-completion-timing":
            first = int_value(fields.get("firstChunkMilliseconds"))
            total = int_value(fields.get("totalMilliseconds"))
            if first is not None:
                data["first_token"].append(first)
            if total is not None:
                data["total_generation"].append(total)
            continue

        if event == "suggestion-presented":
            latency = int_value(fields.get("latencyMilliseconds"))
            if latency is not None:
                data["first_visible"].append(latency)
                if latency > 750:
                    data["late_visible"] += 1
            continue

        if event == "keyboard-event-tap-latency":
            duration = int_value(fields.get("durationMicros"))
            if duration is not None:
                data["event_tap"].append(duration)
            continue

        if event == "keyboard-event-tap-latency-slow":
            data["event_tap_slow"] += 1
            continue

        if event == "focused-text-poll-latency-summary":
            p95 = int_value(fields.get("p95Milliseconds"))
            p99 = int_value(fields.get("p99Milliseconds"))
            maximum = int_value(fields.get("maxMilliseconds"))
            if p95 is not None:
                data["ax_p95_windows"].append(p95)
            if p99 is not None:
                data["ax_p99_windows"].append(p99)
            if maximum is not None:
                data["ax_max_windows"].append(maximum)
            continue

        if event == "focused-text-poll-latency-slow":
            data["ax_slow"] += 1
            continue

        if event == "suggestion-request-cancelled":
            data["cancellations"] += 1

    return data


def format_latest_launch(launches):
    if not launches:
        return "Runtime launch: no runtime-bootstrap events"
    line, fields = launches[-1]
    override = fields.get("modelOverride") or "none"
    return (
        "Runtime launch: "
        f"asset={fields.get('asset', 'unknown')} "
        f"candidate={fields.get('activeCandidate', 'unknown')} "
        f"native={fields.get('nativeRuntimeAvailable', 'unknown')} "
        f"override={override} line={line}"
    )


def format_latest_timing(label, rows):
    if not rows:
        return f"{label}: no samples"
    line, event, fields, duration = rows[-1]
    duration_text = f"{duration}ms" if duration is not None else "unknown"
    return f"{label}: {event} {duration_text} line={line}"


def scorecard_caveats(data):
    caveats = []
    if not data["launches"]:
        caveats.append(
            "Missing runtime-bootstrap samples; do not score current runtime readiness from this report."
        )
    if not duration_values(data["warm_succeeded"]):
        caveats.append(
            "Missing runtime warm success duration samples; do not score warm readiness timing from this report."
        )
    if not duration_values(data["model_load_succeeded"]):
        caveats.append(
            "Missing cold model load samples; do not score cold-start load time from this report."
        )
    if not duration_values(data["model_load_reused"]):
        caveats.append(
            "Missing warm model reuse samples; do not claim warm-reuse speed from this report."
        )
    if not data["first_visible"]:
        caveats.append(
            "Missing first-visible samples; do not score keystroke-to-visible latency from this report."
        )
    if not data["first_token"]:
        caveats.append("Missing first-token samples; do not score model response latency from this report.")
    if not data["total_generation"]:
        caveats.append(
            "Missing total-generation samples; do not score generation completion latency from this report."
        )
    return caveats


def directory_size_bytes(path):
    total = 0
    if not path.exists():
        return None
    for child in path.rglob("*"):
        if child.is_file():
            try:
                total += child.stat().st_size
            except OSError:
                pass
    return total


def format_bytes(size):
    if size is None:
        return "missing"
    units = ["B", "KiB", "MiB", "GiB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{size} B"


def model_table(model_root):
    rows = []
    for name, relative_path in SUPPORTED_MODELS:
        path = model_root / relative_path
        rows.append((name, path.exists(), format_bytes(directory_size_bytes(path))))
    return rows


def find_live_process(explicit_pid=None):
    pid = explicit_pid
    if pid is None:
        completed = subprocess.run(
            ["pgrep", "-f", "/SteadyType.app/Contents/MacOS/SteadyType"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        pids = [int(item) for item in completed.stdout.split() if item.isdigit()]
        pid = pids[0] if pids else None
    if pid is None:
        return None

    completed = subprocess.run(
        ["ps", "-p", str(pid), "-o", "%cpu=,rss=,etime="],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    parts = completed.stdout.split()
    if len(parts) < 3:
        return None
    try:
        cpu = float(parts[0])
        rss_mb = round(int(parts[1]) / 1024)
    except ValueError:
        return None
    return LiveProcess(pid=pid, cpu_percent=cpu, rss_mb=rss_mb, elapsed=parts[2])


def energy_risk(data, live_process):
    score = 0
    reasons = []
    if live_process:
        if live_process.cpu_percent > 35:
            score += 2
            reasons.append(f"CPU {live_process.cpu_percent:.1f}%")
        elif live_process.cpu_percent > 10:
            score += 1
            reasons.append(f"CPU {live_process.cpu_percent:.1f}%")

        if live_process.rss_mb > 8192:
            score += 2
            reasons.append(f"RSS {live_process.rss_mb}MB")
        elif live_process.rss_mb > 4096:
            score += 1
            reasons.append(f"RSS {live_process.rss_mb}MB")

    event_p95 = percentile(data["event_tap"], 0.95)
    if event_p95 is not None and event_p95 > 8000:
        score += 2
        reasons.append(f"event tap p95 {event_p95}us")

    ax_p99_max = max(data["ax_p99_windows"]) if data["ax_p99_windows"] else None
    if ax_p99_max is not None and ax_p99_max > 120:
        score += 1
        reasons.append(f"AX p99 window {ax_p99_max}ms")

    if data["late_visible"]:
        score += 1
        reasons.append(f"{data['late_visible']} late visible suggestions")

    if data["event_tap_slow"]:
        score += 2
        reasons.append(f"{data['event_tap_slow']} slow event-tap markers")

    if score >= 4:
        label = "high"
    elif score >= 2:
        label = "medium"
    else:
        label = "low"
    return label, reasons or ["no current risk markers"]


def print_report(args, data, live_process, models):
    print("Runtime performance report")
    print(f"Diagnostics log: {args.diagnostics_log}")
    print(f"Line limit: {args.line_limit if args.line_limit > 0 else 'all'}")
    print(format_latest_launch(data["launches"]))
    print(format_latest_timing("Latest warm event", data["warm_results"]))
    print(timing_metric_line("Runtime warm succeeded", data["warm_succeeded"]))
    if data["warm_failed"]:
        print(timing_metric_line("Runtime warm failed", data["warm_failed"]))
    if data["warm_skipped"]:
        print(timing_metric_line("Runtime warm skipped", data["warm_skipped"]))
    print(format_latest_timing("Latest model load event", data["model_loads"]))
    print(timing_metric_line("Cold model load succeeded", data["model_load_succeeded"]))
    if data["model_load_failed"]:
        print(timing_metric_line("Cold model load failed", data["model_load_failed"]))
    if data["model_load_cancelled"]:
        print(timing_metric_line("Cold model load cancelled", data["model_load_cancelled"]))
    print(timing_metric_line("Warm model reuse", data["model_load_reused"]))
    print(metric_line("First visible / keystroke-to-visible", data["first_visible"], "ms"))
    print(metric_line("First token", data["first_token"], "ms"))
    print(metric_line("Total generation", data["total_generation"], "ms"))
    print(metric_line("Event-tap overhead", data["event_tap"], "us"))
    print(metric_line("AX p95 summary windows", data["ax_p95_windows"], "ms"))
    print(metric_line("AX p99 summary windows", data["ax_p99_windows"], "ms"))
    print(f"In-flight cancellations: {data['cancellations']}")

    if live_process:
        print(
            "Live process: "
            f"pid={live_process.pid} cpu={live_process.cpu_percent:.1f}% "
            f"rss={live_process.rss_mb}MB elapsed={live_process.elapsed}"
        )
    else:
        print("Live process: not running")

    risk, reasons = energy_risk(data, live_process)
    print(f"Battery/energy risk: {risk} ({'; '.join(reasons)})")
    print()
    print("Scorecard caveats")
    caveats = scorecard_caveats(data)
    if caveats:
        for caveat in caveats:
            print(f"  - {caveat}")
    else:
        print("  - No missing core timing samples in this log slice. Treat this as local diagnostics, not broad beta proof.")
    print("Privacy: redacted timings/counts only; typed text, prompts, completions, screenshots, and per-event paths are not printed.")
    print()
    print("Supported local model assets")
    for name, installed, size in models:
        state = "installed" if installed else "missing"
        print(f"  {name}: {state}, {size}")


def main():
    parser = argparse.ArgumentParser(
        description="Summarize SteadyType runtime, latency, live memory, CPU, and local model assets."
    )
    parser.add_argument("--diagnostics-log", default=str(DEFAULT_DIAGNOSTICS_LOG))
    parser.add_argument("--model-root", default=str(DEFAULT_MODEL_ROOT))
    parser.add_argument("--line-limit", type=int, default=DEFAULT_LINE_LIMIT)
    parser.add_argument("--pid", type=int, help="SteadyType process id")
    parser.add_argument("--no-live-process", action="store_true")
    args = parser.parse_args()

    diagnostics_path = Path(args.diagnostics_log).expanduser()
    model_root = Path(args.model_root).expanduser()
    args.diagnostics_log = str(diagnostics_path)

    if not diagnostics_path.exists():
        raise SystemExit(f"diagnostics log missing: {diagnostics_path}")

    data = parse_diagnostics(diagnostics_path, max(0, args.line_limit))
    live_process = None if args.no_live_process else find_live_process(args.pid)
    print_report(args, data, live_process, model_table(model_root))


if __name__ == "__main__":
    main()
