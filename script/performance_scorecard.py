#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DIAGNOSTICS_LOG = Path.home() / "Library/Logs/SteadyType/diagnostics.log"
DEFAULT_LINE_LIMIT = 5000

SENSITIVE_KEY_FRAGMENTS = (
    "accepted",
    "clipboard",
    "context",
    "document",
    "image",
    "output",
    "prompt",
    "raw",
    "screenshot",
    "selected",
    "selection",
    "text",
    "title",
    "typed",
    "url",
    "value",
    "window",
)

SAFE_FIELD_KEYS = {
    "accessibility",
    "activeCandidate",
    "allowsUserManagedServer",
    "asset",
    "candidate",
    "cleanupMilliseconds",
    "count",
    "cpuPercent",
    "decision",
    "durationMicros",
    "durationMilliseconds",
    "fallbackReason",
    "firstChunkMilliseconds",
    "generationMilliseconds",
    "key",
    "latencyMilliseconds",
    "loadMilliseconds",
    "maxMicros",
    "maxMilliseconds",
    "maxTokens",
    "mode",
    "modelOverride",
    "nativeRuntimeAvailable",
    "p50Micros",
    "p50Milliseconds",
    "p90Micros",
    "p90Milliseconds",
    "p95Micros",
    "p95Milliseconds",
    "p99Micros",
    "p99Milliseconds",
    "preferredCandidate",
    "readinessAction",
    "readinessStage",
    "reason",
    "requestMode",
    "rssMB",
    "sessionMilliseconds",
    "state",
    "totalMilliseconds",
    "traceID",
    "warmMilliseconds",
}


@dataclass(frozen=True)
class Record:
    line: int
    event: str
    fields: dict[str, str]


@dataclass
class PrivacyStats:
    ignored_sensitive_fields: int = 0
    ignored_unknown_fields: int = 0


@dataclass
class RuntimeReport:
    cpu_percent: float | None = None
    rss_mb: int | None = None
    energy_risk: str | None = None
    installed_models: set[str] = field(default_factory=set)
    assets: set[str] = field(default_factory=set)
    candidates: set[str] = field(default_factory=set)
    sources: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class EgressEvidence:
    status: str
    reason: str
    sources: tuple[str, ...] = ()


@dataclass(frozen=True)
class ScoreItem:
    name: str
    weight: int
    score: int
    reason: str


def is_sensitive_key(key: str) -> bool:
    lowered = key.lower()
    return any(fragment in lowered for fragment in SENSITIVE_KEY_FRAGMENTS)


def metadata_fields(parts: list[str], privacy: PrivacyStats) -> dict[str, str]:
    fields: dict[str, str] = {}
    for part in parts:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        if is_sensitive_key(key):
            privacy.ignored_sensitive_fields += 1
            continue
        if key not in SAFE_FIELD_KEYS:
            privacy.ignored_unknown_fields += 1
            continue
        fields[key] = value
    return fields


def parse_records(path: Path, line_limit: int, privacy: PrivacyStats) -> list[Record]:
    records: deque[Record] = deque(maxlen=line_limit if line_limit > 0 else None)
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            stripped = raw_line.strip()
            if not stripped:
                continue
            parts = stripped.split()
            if len(parts) < 2:
                continue
            records.append(
                Record(
                    line=line_number,
                    event=parts[1],
                    fields=metadata_fields(parts[2:], privacy),
                )
            )
    return list(records)


def int_field(fields: dict[str, str], key: str) -> int | None:
    value = fields.get(key)
    if value is None or value == "none":
        return None
    try:
        return int(value)
    except ValueError:
        return None


def float_value(value: str | None) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def bool_field(fields: dict[str, str], key: str) -> bool | None:
    value = fields.get(key)
    if value is None:
        return None
    lowered = value.lower()
    if lowered in {"1", "true", "yes", "on"}:
        return True
    if lowered in {"0", "false", "no", "off"}:
        return False
    return None


def percentile(values: list[int], fraction: float) -> int | None:
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def average(values: list[int]) -> int | None:
    if not values:
        return None
    return round(statistics.mean(values))


def latest_slice(records: list[Record]) -> list[Record]:
    launch_lines = [
        record.line
        for record in records
        if record.event == "launch" and "accessibility" in record.fields
    ]
    bootstrap_lines = [
        record.line
        for record in records
        if record.event == "runtime-bootstrap"
    ]
    start_line = max(
        launch_lines[-1] if launch_lines else 0,
        bootstrap_lines[-1] if bootstrap_lines else 0,
    )
    return [record for record in records if record.line >= start_line]


def deduped_shown_latencies(records: list[Record]) -> list[int]:
    samples: list[int] = []
    seen_trace_ids: set[str] = set()
    for record in records:
        if record.event != "suggestion-presented":
            continue
        latency = int_field(record.fields, "latencyMilliseconds")
        if latency is None:
            continue
        trace_id = record.fields.get("traceID")
        if trace_id:
            if trace_id in seen_trace_ids:
                continue
            seen_trace_ids.add(trace_id)
        samples.append(latency)
    return samples


def metric_summary(values: list[int]) -> dict[str, int] | None:
    if not values:
        return None
    return {
        "n": len(values),
        "avg": average(values) or 0,
        "p50": percentile(values, 0.50) or 0,
        "p95": percentile(values, 0.95) or 0,
        "p99": percentile(values, 0.99) or 0,
        "max": max(values),
    }


def collect_metrics(records: list[Record], runtime_report: RuntimeReport) -> dict[str, Any]:
    current = latest_slice(records)
    current_or_all = current if current else records
    bootstraps = [record for record in current if record.event == "runtime-bootstrap"]
    if not bootstraps:
        bootstraps = [record for record in records if record.event == "runtime-bootstrap"]
    runtime_statuses = [
        record
        for record in current
        if record.event == "runtime" and "readinessStage" in record.fields
    ]
    if not runtime_statuses:
        runtime_statuses = [
            record
            for record in records
            if record.event == "runtime" and "readinessStage" in record.fields
        ]

    assets = {
        record.fields["asset"]
        for record in records
        if "asset" in record.fields and record.fields["asset"] not in {"", "none", "unknown"}
    }
    assets.update(runtime_report.assets)

    candidates = {
        value
        for record in records
        for value in (record.fields.get("activeCandidate"), record.fields.get("candidate"))
        if value and value not in {"", "none", "unknown"}
    }
    candidates.update(runtime_report.candidates)

    model_first = [
        value
        for record in current_or_all
        if record.event == "mlx-completion-timing"
        for value in [int_field(record.fields, "firstChunkMilliseconds")]
        if value is not None
    ]
    model_total = [
        value
        for record in current_or_all
        if record.event == "mlx-completion-timing"
        for value in [
            int_field(record.fields, "totalMilliseconds")
            or int_field(record.fields, "generationMilliseconds")
        ]
        if value is not None
    ]
    event_tap_raw = [
        value
        for record in current_or_all
        if record.event == "keyboard-event-tap-latency"
        for value in [int_field(record.fields, "durationMicros")]
        if value is not None
    ]
    event_tap_summary_counts = [
        value
        for record in current_or_all
        if record.event == "keyboard-event-tap-latency-summary"
        for value in [int_field(record.fields, "count")]
        if value is not None
    ]
    event_tap_summary_p95 = [
        value
        for record in current_or_all
        if record.event == "keyboard-event-tap-latency-summary"
        for value in [int_field(record.fields, "p95Micros")]
        if value is not None
    ]
    event_tap_summary_max = [
        value
        for record in current_or_all
        if record.event == "keyboard-event-tap-latency-summary"
        for value in [int_field(record.fields, "maxMicros")]
        if value is not None
    ]
    ax_summary_counts = [
        value
        for record in current_or_all
        if record.event == "focused-text-poll-latency-summary"
        for value in [int_field(record.fields, "count")]
        if value is not None
    ]
    ax_summary_p95 = [
        value
        for record in current_or_all
        if record.event == "focused-text-poll-latency-summary"
        for value in [int_field(record.fields, "p95Milliseconds")]
        if value is not None
    ]
    ax_summary_max = [
        value
        for record in current_or_all
        if record.event == "focused-text-poll-latency-summary"
        for value in [int_field(record.fields, "maxMilliseconds")]
        if value is not None
    ]
    warm_times = [
        value
        for record in current_or_all
        if record.event == "runtime-warm-succeeded"
        for value in [int_field(record.fields, "warmMilliseconds")]
        if value is not None
    ]
    model_load_times = [
        value
        for record in current_or_all
        if record.event == "mlx-model-load-succeeded"
        for value in [int_field(record.fields, "loadMilliseconds")]
        if value is not None
    ]
    cpu_samples = [
        value
        for record in records
        for value in [float_value(record.fields.get("cpuPercent"))]
        if value is not None
    ]
    rss_samples = [
        value
        for record in records
        for value in [int_field(record.fields, "rssMB")]
        if value is not None
    ]
    if runtime_report.cpu_percent is not None:
        cpu_samples.append(runtime_report.cpu_percent)
    if runtime_report.rss_mb is not None:
        rss_samples.append(runtime_report.rss_mb)

    return {
        "records": len(records),
        "latest_bootstrap": bootstraps[-1] if bootstraps else None,
        "latest_runtime_status": runtime_statuses[-1] if runtime_statuses else None,
        "latest_warm_failed": any(record.event == "runtime-warm-failed" for record in current),
        "latest_warm_succeeded": any(record.event == "runtime-warm-succeeded" for record in current),
        "assets": assets,
        "candidates": candidates,
        "shown": deduped_shown_latencies(current_or_all),
        "shown_summary": metric_summary(deduped_shown_latencies(current_or_all)),
        "model_first": model_first,
        "model_first_summary": metric_summary(model_first),
        "model_total": model_total,
        "model_total_summary": metric_summary(model_total),
        "event_tap_raw": event_tap_raw,
        "event_tap_summary_counts": event_tap_summary_counts,
        "event_tap_summary_p95": event_tap_summary_p95,
        "event_tap_summary_max": event_tap_summary_max,
        "event_tap_slow_markers": sum(1 for record in current_or_all if record.event == "keyboard-event-tap-latency-slow"),
        "event_tap_disabled": sum(1 for record in current_or_all if record.event == "keyboard-event-tap-disabled"),
        "event_tap_start_failed": sum(1 for record in current_or_all if record.event == "keyboard-event-tap-start-failed"),
        "event_tap_failed_closed": sum(1 for record in current_or_all if record.event == "keyboard-event-tap-failed-closed"),
        "event_tap_dropped": sum(1 for record in current_or_all if record.event == "keyboard-event-tap-unhandled-consumed-key-dropped"),
        "ax_summary_counts": ax_summary_counts,
        "ax_summary_p95": ax_summary_p95,
        "ax_summary_max": ax_summary_max,
        "ax_slow_markers": sum(1 for record in current_or_all if record.event == "focused-text-poll-latency-slow"),
        "ax_skipped": sum((int_field(record.fields, "count") or 1) for record in current_or_all if record.event == "focused-text-poll-skipped"),
        "cancellations": sum(1 for record in current_or_all if record.event == "suggestion-request-cancelled"),
        "warm_times": warm_times,
        "model_load_times": model_load_times,
        "cpu_samples": cpu_samples,
        "rss_samples": rss_samples,
        "energy_risk": runtime_report.energy_risk,
        "installed_models": runtime_report.installed_models,
    }


def score_for_count(count: int, full: int, okay: int, weak: int) -> int:
    if count >= full:
        return 100
    if count >= okay:
        return 80
    if count >= weak:
        return 55
    return 20 if count else 0


def clamp(score: int, lower: int = 0, upper: int = 100) -> int:
    return max(lower, min(upper, score))


def format_metric(summary: dict[str, int] | None, unit: str) -> str:
    if summary is None:
        return "no samples"
    return f"n={summary['n']} avg={summary['avg']}{unit} p95={summary['p95']}{unit} max={summary['max']}{unit}"


def score_runtime(metrics: dict[str, Any], egress: EgressEvidence) -> ScoreItem:
    score = 0
    reasons: list[str] = []
    bootstrap: Record | None = metrics["latest_bootstrap"]
    status: Record | None = metrics["latest_runtime_status"]

    if bootstrap is None:
        reasons.append("no runtime-bootstrap metadata")
    else:
        fields = bootstrap.fields
        candidate = fields.get("activeCandidate", "unknown")
        native = bool_field(fields, "nativeRuntimeAvailable")
        allows_server = bool_field(fields, "allowsUserManagedServer")
        asset = fields.get("asset", "unknown")
        score += 20
        reasons.append(f"asset={asset}")
        if candidate == "mlx":
            score += 20
        elif candidate not in {"mock", "unavailable", "unknown"}:
            score += 10
        else:
            reasons.append(f"candidate={candidate}")
        if native is True:
            score += 15
        elif native is False:
            reasons.append("native runtime unavailable")
        if allows_server is False:
            score += 10
        elif allows_server is True:
            reasons.append("user-managed server allowed")
        if candidate in {"mock", "unavailable"} or "fallbackReason" in fields:
            score = min(score, 35)
            reasons.append("mock/fallback runtime marker")

    readiness = status.fields.get("readinessStage") if status else None
    if readiness == "ready" or metrics["latest_warm_succeeded"]:
        score += 20
        reasons.append("latest runtime ready")
    elif readiness:
        score += 5
        reasons.append(f"readinessStage={readiness}")
    if not metrics["latest_warm_failed"]:
        score += 5
    else:
        score = min(score, 55)
        reasons.append("latest warm failed")

    if egress.status == "pass":
        score += 10
        reasons.append("no-egress proof passed")
    elif egress.status == "fail":
        score = min(score, 45)
        reasons.append(egress.reason)
    else:
        reasons.append("no-egress proof not provided")

    return ScoreItem("Runtime readiness + no egress", 20, clamp(score), "; ".join(reasons))


def score_sample_depth(metrics: dict[str, Any]) -> ScoreItem:
    shown_count = len(metrics["shown"])
    model_count = len(metrics["model_total"])
    tap_evidence = len(metrics["event_tap_raw"]) + sum(metrics["event_tap_summary_counts"])
    ax_evidence = sum(metrics["ax_summary_counts"])
    score = round(
        (
            score_for_count(shown_count, full=5, okay=3, weak=1)
            + score_for_count(model_count, full=5, okay=3, weak=1)
            + score_for_count(tap_evidence, full=20, okay=5, weak=1)
            + score_for_count(ax_evidence, full=20, okay=5, weak=1)
        )
        / 4
    )
    reason = f"shown={shown_count}; modelTiming={model_count}; eventTapEvidence={tap_evidence}; axPollEvidence={ax_evidence}"
    return ScoreItem("Latency sample depth", 15, score, reason)


def score_typing(metrics: dict[str, Any]) -> ScoreItem:
    score = 100
    reasons: list[str] = []
    shown = metrics["shown_summary"]
    if shown is None:
        score = 35
        reasons.append("no shown-latency samples")
    else:
        p95 = shown["p95"]
        avg = shown["avg"]
        if p95 > 1200:
            score -= 55
        elif p95 > 750:
            score -= 35
        elif p95 > 500:
            score -= 15
        elif p95 > 250:
            score -= 5
        if avg > 700:
            score -= 15
        reasons.append(f"shown {format_metric(shown, 'ms')}")

    ax_p95 = max(metrics["ax_summary_p95"]) if metrics["ax_summary_p95"] else None
    ax_max = max(metrics["ax_summary_max"]) if metrics["ax_summary_max"] else None
    if ax_p95 is None:
        score -= 10
        reasons.append("no AX poll summary")
    else:
        if ax_p95 > 80:
            score -= 20
        elif ax_p95 > 25:
            score -= 5
        reasons.append(f"AX p95Max={ax_p95}ms")
    if ax_max is not None and ax_max > 120:
        score -= 10
        reasons.append(f"AX max={ax_max}ms")
    if metrics["ax_slow_markers"]:
        score -= 20
        reasons.append(f"AX slowMarkers={metrics['ax_slow_markers']}")
    if metrics["ax_skipped"]:
        score -= 10
        reasons.append(f"AX skipped={metrics['ax_skipped']}")
    if metrics["cancellations"] > max(5, len(metrics["shown"])):
        score -= 5
        reasons.append(f"cancellations={metrics['cancellations']}")

    return ScoreItem("Typing responsiveness", 15, clamp(score), "; ".join(reasons))


def score_model_timing(metrics: dict[str, Any]) -> ScoreItem:
    score = 100
    reasons: list[str] = []
    first = metrics["model_first_summary"]
    total = metrics["model_total_summary"]
    if first is None and total is None:
        return ScoreItem("Model timing", 15, 35, "no mlx-completion-timing samples")
    if first is not None:
        p95 = first["p95"]
        if p95 > 1000:
            score -= 55
        elif p95 > 600:
            score -= 35
        elif p95 > 300:
            score -= 15
        elif p95 > 150:
            score -= 5
        reasons.append(f"firstToken {format_metric(first, 'ms')}")
    else:
        score -= 15
        reasons.append("first-token missing")
    if total is not None:
        p95 = total["p95"]
        if p95 > 1600:
            score -= 50
        elif p95 > 1200:
            score -= 35
        elif p95 > 700:
            score -= 18
        elif p95 > 350:
            score -= 8
        reasons.append(f"modelTotal {format_metric(total, 'ms')}")
    else:
        score -= 15
        reasons.append("model-total missing")

    warm_max = max(metrics["warm_times"]) if metrics["warm_times"] else None
    load_max = max(metrics["model_load_times"]) if metrics["model_load_times"] else None
    if warm_max is not None and warm_max > 30000:
        score -= 15
    elif warm_max is not None and warm_max > 10000:
        score -= 5
    if load_max is not None and load_max > 30000:
        score -= 15
    elif load_max is not None and load_max > 10000:
        score -= 5
    if warm_max is not None:
        reasons.append(f"warmMax={warm_max}ms")
    if load_max is not None:
        reasons.append(f"loadMax={load_max}ms")
    return ScoreItem("Model timing", 15, clamp(score), "; ".join(reasons))


def score_event_tap(metrics: dict[str, Any]) -> ScoreItem:
    raw_p95 = percentile(metrics["event_tap_raw"], 0.95)
    summary_p95 = max(metrics["event_tap_summary_p95"]) if metrics["event_tap_summary_p95"] else None
    p95 = max([value for value in [raw_p95, summary_p95] if value is not None], default=None)
    raw_max = max(metrics["event_tap_raw"]) if metrics["event_tap_raw"] else None
    summary_max = max(metrics["event_tap_summary_max"]) if metrics["event_tap_summary_max"] else None
    maximum = max([value for value in [raw_max, summary_max] if value is not None], default=None)
    if p95 is None and maximum is None:
        return ScoreItem("Event-tap latency", 15, 45, "no event-tap latency samples")

    score = 100
    reasons: list[str] = []
    if p95 is not None:
        if p95 > 8000:
            score -= 50
        elif p95 > 4000:
            score -= 25
        elif p95 > 1000:
            score -= 10
        reasons.append(f"p95={p95}us")
    if maximum is not None:
        if maximum > 16000:
            score -= 35
        elif maximum > 8000:
            score -= 20
        reasons.append(f"max={maximum}us")
    severe = (
        metrics["event_tap_slow_markers"]
        + metrics["event_tap_disabled"]
        + metrics["event_tap_start_failed"]
        + metrics["event_tap_failed_closed"]
        + metrics["event_tap_dropped"]
    )
    if severe:
        score -= min(60, severe * 20)
        reasons.append(f"severeMarkers={severe}")
    return ScoreItem("Event-tap latency", 15, clamp(score), "; ".join(reasons))


def score_memory_cpu(metrics: dict[str, Any]) -> ScoreItem:
    cpu = max(metrics["cpu_samples"]) if metrics["cpu_samples"] else None
    rss = max(metrics["rss_samples"]) if metrics["rss_samples"] else None
    energy = metrics["energy_risk"]
    if cpu is None and rss is None and energy is None:
        return ScoreItem("Memory/CPU", 10, 75, "no runtime performance report CPU/RSS sample provided")

    score = 100
    reasons: list[str] = []
    if cpu is not None:
        if cpu > 35:
            score -= 35
        elif cpu > 10:
            score -= 15
        reasons.append(f"cpuMax={cpu:.1f}%")
    if rss is not None:
        if rss > 8192:
            score -= 35
        elif rss > 4096:
            score -= 15
        elif rss > 2048:
            score -= 5
        reasons.append(f"rssMax={rss}MB")
    if energy:
        reasons.append(f"energyRisk={energy}")
        if energy == "high":
            score = min(score, 55)
        elif energy == "medium":
            score = min(score, 80)
    return ScoreItem("Memory/CPU", 10, clamp(score), "; ".join(reasons))


def score_multi_model(metrics: dict[str, Any]) -> ScoreItem:
    asset_count = len(metrics["assets"])
    installed_count = len(metrics["installed_models"])
    candidate_count = len(metrics["candidates"])
    if asset_count >= 2 and installed_count >= 2:
        score = 100
    elif asset_count >= 2:
        score = 90
    elif installed_count >= 2:
        score = 85
    elif asset_count == 1 or candidate_count >= 1:
        score = 60
    else:
        score = 30
    reason = f"runtimeAssets={asset_count}; candidates={candidate_count}; installedModels={installed_count}"
    return ScoreItem("Multi-model evidence", 10, score, reason)


def weighted_overall(items: list[ScoreItem]) -> int:
    total_weight = sum(item.weight for item in items)
    return round(sum(item.score * item.weight for item in items) / total_weight) if total_weight else 0


def parse_runtime_report(path: Path) -> RuntimeReport:
    report = RuntimeReport(sources=[str(path)])
    text = path.read_text(encoding="utf-8", errors="ignore")
    for line in text.splitlines():
        live = re.search(r"\bcpu=([0-9.]+)%\s+rss=([0-9]+)MB\b", line)
        if live:
            report.cpu_percent = float(live.group(1))
            report.rss_mb = int(live.group(2))
            continue
        energy = re.search(r"^Battery/energy risk:\s*([a-z]+)\b", line)
        if energy:
            report.energy_risk = energy.group(1)
            continue
        model = re.search(r"^\s+([A-Za-z0-9_.-]+):\s+installed,", line)
        if model:
            report.installed_models.add(model.group(1))
            continue
        launch = re.search(r"Runtime launch:\s+asset=(\S+)\s+candidate=(\S+)\s+native=(\S+)", line)
        if launch:
            report.assets.add(launch.group(1))
            report.candidates.add(launch.group(2))
    return report


def merge_runtime_reports(paths: list[Path]) -> RuntimeReport:
    merged = RuntimeReport()
    for path in paths:
        report = parse_runtime_report(path)
        merged.sources.extend(report.sources)
        merged.installed_models.update(report.installed_models)
        merged.assets.update(report.assets)
        merged.candidates.update(report.candidates)
        if report.cpu_percent is not None:
            merged.cpu_percent = report.cpu_percent
        if report.rss_mb is not None:
            merged.rss_mb = report.rss_mb
        if report.energy_risk is not None:
            merged.energy_risk = report.energy_risk
    return merged


def parse_egress_json(path: Path) -> tuple[bool, str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    result = str(data.get("result", "")).lower()
    phase = str(data.get("phase", "autocomplete")).lower()
    unexpected = int(data.get("unexpected_remote_endpoint_count", 0))
    if phase != "autocomplete":
        return False, f"{path}: phase={phase} does not prove autocomplete no-egress"
    if result == "pass" and unexpected == 0:
        return True, f"{path}: autocomplete no-egress pass"
    return False, f"{path}: unexpectedRemoteEndpoints={unexpected} result={result or 'unknown'}"


def parse_egress_report(path: Path) -> tuple[bool, str]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    result_match = re.search(r"Result:\s*`?([A-Za-z]+)`?", text)
    phase_match = re.search(r"Phase:\s*`?([A-Za-z-]+)`?", text)
    unexpected_match = re.search(r"Unexpected remote endpoints:\s*`?([0-9]+)`?", text)
    result = result_match.group(1).lower() if result_match else ""
    phase = phase_match.group(1).lower() if phase_match else "autocomplete"
    unexpected = int(unexpected_match.group(1)) if unexpected_match else 0
    if phase != "autocomplete":
        return False, f"{path}: phase={phase} does not prove autocomplete no-egress"
    if result == "pass" and unexpected == 0:
        return True, f"{path}: autocomplete no-egress pass"
    return False, f"{path}: unexpectedRemoteEndpoints={unexpected} result={result or 'unknown'}"


def load_egress_evidence(json_paths: list[Path], report_paths: list[Path]) -> EgressEvidence:
    paths = json_paths + report_paths
    if not paths:
        return EgressEvidence("missing", "no no-egress proof provided")

    passes: list[str] = []
    failures: list[str] = []
    for path in json_paths:
        try:
            passed, reason = parse_egress_json(path)
        except (OSError, ValueError, json.JSONDecodeError) as error:
            passed, reason = False, f"{path}: could not parse no-egress JSON ({error})"
        (passes if passed else failures).append(reason)
    for path in report_paths:
        try:
            passed, reason = parse_egress_report(path)
        except OSError as error:
            passed, reason = False, f"{path}: could not parse no-egress report ({error})"
        (passes if passed else failures).append(reason)

    if failures:
        return EgressEvidence("fail", "; ".join(failures), tuple(map(str, paths)))
    if passes:
        return EgressEvidence("pass", "; ".join(passes), tuple(map(str, paths)))
    return EgressEvidence("missing", "no autocomplete no-egress proof provided", tuple(map(str, paths)))


def make_scorecard(metrics: dict[str, Any], egress: EgressEvidence) -> list[ScoreItem]:
    return [
        score_runtime(metrics, egress),
        score_sample_depth(metrics),
        score_typing(metrics),
        score_model_timing(metrics),
        score_event_tap(metrics),
        score_memory_cpu(metrics),
        score_multi_model(metrics),
    ]


def relative_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT_DIR))
    except ValueError:
        return str(path)


def print_report(
    *,
    diagnostics_log: Path | None,
    line_limit: int,
    privacy: PrivacyStats,
    egress: EgressEvidence,
    items: list[ScoreItem],
    overall: int,
) -> None:
    print("Performance scorecard")
    print(f"Diagnostics log: {diagnostics_log}" if diagnostics_log is not None else "Diagnostics log: not provided")
    print(f"Line limit: {line_limit if line_limit > 0 else 'all'}")
    print(f"Privacy: metadata-only parse; ignored sensitive field values={privacy.ignored_sensitive_fields}")
    print(f"No-egress proof: {egress.status} ({egress.reason})")
    print(f"Overall score: {overall}/100")
    print()
    for item in items:
        print(f"{item.name}: {item.score}/100 - {item.reason}")
    print()
    print(
        "Privacy note: this scorecard reads whitelisted diagnostic metadata only. "
        "It does not print typed text, prompts, model output, screenshots, URLs, "
        "document names, or trace lines."
    )


def write_json(path: Path, items: list[ScoreItem], overall: int, privacy: PrivacyStats, egress: EgressEvidence) -> None:
    payload = {
        "overall_score": overall,
        "privacy": {
            "ignored_sensitive_field_values": privacy.ignored_sensitive_fields,
            "ignored_unknown_fields": privacy.ignored_unknown_fields,
            "note": "Only whitelisted diagnostic metadata is included.",
        },
        "no_egress": {
            "status": egress.status,
            "reason": egress.reason,
            "sources": list(egress.sources),
        },
        "scores": [
            {
                "name": item.name,
                "weight": item.weight,
                "score": item.score,
                "reason": item.reason,
            }
            for item in items
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def existing_paths(values: list[str]) -> list[Path]:
    paths: list[Path] = []
    for value in values:
        path = Path(value).expanduser()
        if not path.is_absolute():
            path = ROOT_DIR / path
        paths.append(path)
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Score SteadyType runtime performance readiness from privacy-safe "
            "diagnostic metadata and optional no-egress/runtime report evidence."
        )
    )
    parser.add_argument("--diagnostics-log", default=str(DEFAULT_DIAGNOSTICS_LOG))
    parser.add_argument("--line-limit", type=int, default=DEFAULT_LINE_LIMIT)
    parser.add_argument("--egress-json", action="append", default=[], help="No-egress JSON proof from check_runtime_network_egress.py")
    parser.add_argument("--egress-report", action="append", default=[], help="No-egress Markdown proof from check_runtime_network_egress.py")
    parser.add_argument("--runtime-report", action="append", default=[], help="Text output from runtime_performance_report.py")
    parser.add_argument("--json-out", help="Optional machine-readable scorecard output")
    parser.add_argument("--min-score", type=int, help="Fail if the weighted overall score is below this value")
    parser.add_argument("--require-no-egress", action="store_true", help="Fail unless autocomplete no-egress proof is provided and passing")
    args = parser.parse_args()

    diagnostics_path = Path(args.diagnostics_log).expanduser()
    runtime_report_paths = existing_paths(args.runtime_report)
    egress_json_paths = existing_paths(args.egress_json)
    egress_report_paths = existing_paths(args.egress_report)

    privacy = PrivacyStats()
    records: list[Record] = []
    parsed_diagnostics_path: Path | None = None
    if diagnostics_path.exists():
        records = parse_records(diagnostics_path, max(0, args.line_limit), privacy)
        parsed_diagnostics_path = diagnostics_path
    elif not runtime_report_paths:
        print(f"diagnostics log missing: {diagnostics_path}", file=sys.stderr)
        return 2

    try:
        runtime_report = merge_runtime_reports(runtime_report_paths)
    except OSError as error:
        print(f"runtime report parse failed: {error}", file=sys.stderr)
        return 2

    egress = load_egress_evidence(egress_json_paths, egress_report_paths)
    metrics = collect_metrics(records, runtime_report)
    items = make_scorecard(metrics, egress)
    overall = weighted_overall(items)

    print_report(
        diagnostics_log=parsed_diagnostics_path,
        line_limit=max(0, args.line_limit),
        privacy=privacy,
        egress=egress,
        items=items,
        overall=overall,
    )

    if args.json_out:
        json_path = Path(args.json_out).expanduser()
        if not json_path.is_absolute():
            json_path = ROOT_DIR / json_path
        write_json(json_path, items, overall, privacy, egress)
        print(f"JSON scorecard: {relative_path(json_path)}")

    failures: list[str] = []
    if args.require_no_egress and egress.status != "pass":
        failures.append(f"required no-egress proof is {egress.status}")
    if args.min_score is not None and overall < args.min_score:
        failures.append(f"overall score {overall}/100 is below required {args.min_score}/100")
    if failures:
        for failure in failures:
            print(f"performance scorecard failed: {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
