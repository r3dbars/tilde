#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import statistics
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DIAGNOSTICS_LOG = Path.home() / "Library/Logs/SteadyType/diagnostics.log"
DEFAULT_MODEL_ROOT = Path.home() / "Library/Application Support/SteadyType/Models"
DEFAULT_LINE_LIMIT = 5000


@dataclass(frozen=True)
class ModelConfig:
    alias: str
    display_name: str
    relative_path: str
    expected_minimum_bytes: int
    required_files: tuple[str, ...] = ("config.json",)
    required_extension: str = "safetensors"
    alternates: tuple[str, ...] = ()

    @property
    def file_name(self) -> str:
        return Path(self.relative_path).name

    @property
    def label(self) -> str:
        return f"{self.alias} / {self.display_name} / {self.file_name}"


@dataclass(frozen=True)
class AssetState:
    installed: str
    available: str
    size: str


@dataclass(frozen=True)
class MetricSummary:
    n: int
    p50: int
    p95: int
    unit: str
    source: str


@dataclass
class RuntimeReportEvidence:
    active_alias: str | None = None
    cpu_percent: float | None = None
    rss_mb: int | None = None
    energy_risk: str | None = None
    installed_models: set[str] = field(default_factory=set)
    metrics: dict[str, dict[str, MetricSummary]] = field(
        default_factory=lambda: defaultdict(dict)
    )
    sources: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class EgressEvidence:
    status: str
    reason: str
    sources: tuple[str, ...] = ()


SUPPORTED_MODELS = [
    ModelConfig(
        "qwen3-0.6b",
        "Qwen3 0.6B",
        "Qwen3Small/MLX/qwen3-0.6b-4bit",
        256 * 1024 * 1024,
    ),
    ModelConfig(
        "qwen3-1.7b",
        "Qwen3 1.7B",
        "Qwen3Medium/MLX/qwen3-1.7b-4bit",
        768 * 1024 * 1024,
    ),
    ModelConfig(
        "qwen35-4b",
        "Qwen3.5 4B",
        "Qwen35FourB/MLX/Qwen3.5-4B-4bit",
        2 * 1024 * 1024 * 1024,
        required_files=("config.json", "tokenizer.json", "tokenizer_config.json"),
        alternates=("qwen3.5-4b",),
    ),
    ModelConfig(
        "qwen35-9b",
        "Qwen3.5 9B",
        "Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit",
        5 * 1024 * 1024 * 1024,
        required_files=("config.json", "tokenizer.json", "tokenizer_config.json"),
        alternates=("qwen3.5-9b",),
    ),
    ModelConfig(
        "gemma-4-e2b",
        "Gemma 4 E2B",
        "Gemma4E2B/MLX/gemma-4-e2b-mlx",
        1024 * 1024,
    ),
    ModelConfig(
        "gemma-4-e4b",
        "Gemma 4 E4B",
        "Gemma4E4B/MLX/gemma-4-e4b-4bit",
        4 * 1024 * 1024 * 1024,
        required_files=("config.json", "tokenizer.json", "tokenizer_config.json"),
        alternates=("gemma4-e4b", "gemma-4-e4b-4bit"),
    ),
    ModelConfig(
        "gemma-4-e4b-it-optiq",
        "Gemma 4 E4B IT OptiQ",
        "Gemma4E4BItOptiQ/MLX/gemma-4-e4b-it-OptiQ-4bit",
        5 * 1024 * 1024 * 1024,
        required_files=("config.json", "tokenizer.json", "tokenizer_config.json"),
        alternates=("gemma4-e4b-it-optiq", "gemma-4-e4b-it-optiq-4bit"),
    ),
    ModelConfig(
        "gemma-4-26b",
        "Gemma 4 26B A4B",
        "Gemma4A4B/MLX/gemma-4-26b-a4b-it-4bit",
        14 * 1024 * 1024 * 1024,
        required_files=("config.json", "tokenizer.json", "tokenizer_config.json"),
    ),
]

MODEL_BY_ALIAS = {model.alias: model for model in SUPPORTED_MODELS}


def normalize_model_key(value: str | None) -> str:
    return (value or "").strip().lower()


def build_alias_lookup() -> dict[str, str]:
    lookup: dict[str, str] = {}
    for model in SUPPORTED_MODELS:
        values = {
            model.alias,
            model.display_name,
            model.file_name,
            Path(model.relative_path).name,
            *model.alternates,
        }
        for value in values:
            lookup[normalize_model_key(value)] = model.alias
    return lookup


ALIAS_LOOKUP = build_alias_lookup()


def canonical_alias(value: str | None) -> str | None:
    normalized = normalize_model_key(value)
    if not normalized:
        return None
    if normalized in ALIAS_LOOKUP:
        return ALIAS_LOOKUP[normalized]
    for key, alias in ALIAS_LOOKUP.items():
        if key and key in normalized:
            return alias
    return None


def fields_from(parts: list[str]) -> dict[str, str]:
    fields: dict[str, str] = {}
    for part in parts:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key] = value
    return fields


def int_value(value: str | None) -> int | None:
    if value is None or value == "none":
        return None
    try:
        return int(value)
    except ValueError:
        return None


def percentile(values: list[int], fraction: float) -> int | None:
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def summarize(values: list[int], unit: str, source: str) -> MetricSummary | None:
    if not values:
        return None
    p50 = percentile(values, 0.50)
    p95 = percentile(values, 0.95)
    if p50 is None or p95 is None:
        return None
    return MetricSummary(n=len(values), p50=p50, p95=p95, unit=unit, source=source)


def metric_text(summary: MetricSummary | None) -> str:
    if summary is None:
        return "missing"
    return (
        f"n={summary.n} p50={summary.p50}{summary.unit} "
        f"p95={summary.p95}{summary.unit} ({summary.source})"
    )


def directory_size_bytes(path: Path) -> int | None:
    if not path.exists():
        return None
    total = 0
    for child in path.rglob("*"):
        if child.is_file():
            try:
                total += child.stat().st_size
            except OSError:
                pass
    return total


def format_bytes(size: int | None) -> str:
    if size is None:
        return "missing"
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{size} B"


def asset_state(model_root: Path, model: ModelConfig, report: RuntimeReportEvidence) -> AssetState:
    path = model_root / model.relative_path
    report_installed = model.alias in report.installed_models
    if not path.exists():
        installed = "yes (runtime report)" if report_installed else "missing"
        return AssetState(installed=installed, available="missing", size="missing")
    if not path.is_dir():
        return AssetState(installed="yes", available="invalid: expected directory", size="missing")

    try:
        child_names = set(item.name for item in path.iterdir())
    except OSError as error:
        return AssetState(installed="yes", available=f"invalid: {error}", size="missing")

    for required in model.required_files:
        if required not in child_names:
            return AssetState(
                installed="yes",
                available=f"invalid: missing {required}",
                size=format_bytes(directory_size_bytes(path)),
            )

    model_bytes = 0
    for child in path.iterdir():
        if child.is_file() and child.name.lower().endswith(f".{model.required_extension}"):
            try:
                model_bytes += child.stat().st_size
            except OSError:
                pass

    if model_bytes <= 0:
        return AssetState(
            installed="yes",
            available=f"invalid: missing .{model.required_extension} weights",
            size=format_bytes(directory_size_bytes(path)),
        )
    if model_bytes < model.expected_minimum_bytes:
        return AssetState(
            installed="yes",
            available="invalid: model weights too small",
            size=format_bytes(directory_size_bytes(path)),
        )

    return AssetState(installed="yes", available="available", size=format_bytes(directory_size_bytes(path)))


def alias_from_fields(fields: dict[str, str]) -> str | None:
    return (
        canonical_alias(fields.get("modelOverride"))
        or canonical_alias(fields.get("asset"))
        or canonical_alias(fields.get("model"))
    )


def line_slice(path: Path, line_limit: int) -> list[tuple[int, str]]:
    if not path.exists():
        return []
    rows: list[tuple[int, str]] = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            stripped = raw_line.strip()
            if stripped:
                rows.append((line_number, stripped))
    if line_limit > 0:
        rows = rows[-line_limit:]
    return rows


def parse_diagnostics(path: Path, line_limit: int) -> tuple[dict[str, dict[str, MetricSummary]], str | None]:
    values: dict[str, dict[str, list[int]]] = defaultdict(lambda: defaultdict(list))
    current_alias: str | None = None
    latest_alias: str | None = None

    for _, line in line_slice(path, line_limit):
        parts = line.split()
        if len(parts) < 2:
            continue
        event = parts[1]
        fields = fields_from(parts[2:])

        if event == "runtime-bootstrap":
            current_alias = alias_from_fields(fields)
            latest_alias = current_alias or latest_alias
            continue

        if current_alias is None:
            continue

        if event == "mlx-model-load-succeeded":
            load = int_value(fields.get("loadMilliseconds"))
            if load is not None:
                values[current_alias]["load"].append(load)
            continue

        if event == "runtime-warm-succeeded":
            warm = int_value(fields.get("warmMilliseconds"))
            if warm is not None:
                values[current_alias]["warm"].append(warm)
            continue

        if event == "suggestion-presented":
            latency = int_value(fields.get("latencyMilliseconds"))
            if latency is not None:
                values[current_alias]["suggestion"].append(latency)
            continue

        if event == "mlx-completion-timing":
            first = int_value(fields.get("firstChunkMilliseconds"))
            total = int_value(fields.get("totalMilliseconds")) or int_value(
                fields.get("generationMilliseconds")
            )
            if first is not None:
                values[current_alias]["first_token"].append(first)
            if total is not None:
                values[current_alias]["total"].append(total)

    summaries: dict[str, dict[str, MetricSummary]] = defaultdict(dict)
    for alias, metrics in values.items():
        for name, metric_values in metrics.items():
            summaries[alias][name] = summarize(metric_values, "ms", "log")
    return summaries, latest_alias


def parse_metric_summary(line: str, source: str) -> MetricSummary | None:
    match = re.search(
        r"\bn=(?P<n>\d+)\b.*?\bp50=(?P<p50>\d+)(?P<unit>ms|us)\b.*?\bp95=(?P<p95>\d+)(?P=unit)\b",
        line,
    )
    if not match:
        return None
    return MetricSummary(
        n=int(match.group("n")),
        p50=int(match.group("p50")),
        p95=int(match.group("p95")),
        unit=match.group("unit"),
        source=source,
    )


def parse_runtime_report(path: Path) -> RuntimeReportEvidence:
    report = RuntimeReportEvidence(sources=[str(path)])
    active_alias: str | None = None
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return report

    for line in text.splitlines():
        launch = re.search(r"^Runtime launch:\s+asset=(\S+)\s+", line)
        if launch:
            active_alias = canonical_alias(launch.group(1))
            report.active_alias = active_alias or report.active_alias
            continue

        live = re.search(r"\bcpu=([0-9.]+)%\s+rss=([0-9]+)MB\b", line)
        if live:
            report.cpu_percent = float(live.group(1))
            report.rss_mb = int(live.group(2))
            continue

        energy = re.search(r"^Battery/energy risk:\s*([a-z]+)\b", line)
        if energy:
            report.energy_risk = energy.group(1)
            continue

        installed = re.search(r"^\s+([A-Za-z0-9_.-]+):\s+installed,", line)
        if installed:
            alias = canonical_alias(installed.group(1))
            if alias:
                report.installed_models.add(alias)
            continue

        if not active_alias:
            continue

        metric_name = None
        if line.startswith("Cold model load succeeded:"):
            metric_name = "load"
        elif line.startswith("Runtime warm succeeded:"):
            metric_name = "warm"
        elif line.startswith("First visible / keystroke-to-visible:"):
            metric_name = "suggestion"
        elif line.startswith("First token:"):
            metric_name = "first_token"
        elif line.startswith("Total generation:"):
            metric_name = "total"

        if metric_name:
            summary = parse_metric_summary(line, "runtime-report")
            if summary:
                report.metrics[active_alias][metric_name] = summary

    return report


def merge_runtime_reports(paths: list[Path]) -> RuntimeReportEvidence:
    merged = RuntimeReportEvidence()
    for path in paths:
        report = parse_runtime_report(path)
        merged.sources.extend(report.sources)
        merged.installed_models.update(report.installed_models)
        merged.metrics.update(report.metrics)
        if report.active_alias is not None:
            merged.active_alias = report.active_alias
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
    generated_at = data.get("generated_at", "unknown")
    if phase != "autocomplete":
        return False, f"{path}: phase={phase} does not prove autocomplete no-egress"
    if result == "pass" and unexpected == 0:
        return True, f"{path}: pass generatedAt={generated_at}"
    return False, f"{path}: result={result or 'unknown'} unexpectedRemoteEndpoints={unexpected}"


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
        return True, f"{path}: pass"
    return False, f"{path}: result={result or 'unknown'} unexpectedRemoteEndpoints={unexpected}"


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
            passed = False
            reason = f"{path}: could not parse no-egress JSON ({error})"
        (passes if passed else failures).append(reason)

    for path in report_paths:
        try:
            passed, reason = parse_egress_report(path)
        except (OSError, ValueError) as error:
            passed = False
            reason = f"{path}: could not parse no-egress report ({error})"
        (passes if passed else failures).append(reason)

    if failures:
        return EgressEvidence("fail", "; ".join(failures), tuple(map(str, paths)))
    if passes:
        return EgressEvidence("pass", "; ".join(passes), tuple(map(str, paths)))
    return EgressEvidence("missing", "no autocomplete no-egress proof provided", tuple(map(str, paths)))


def existing_paths(paths: list[str | Path]) -> list[Path]:
    resolved: list[Path] = []
    for item in paths:
        path = Path(item).expanduser()
        if path.exists():
            resolved.append(path)
    return dedupe_paths(resolved)


def dedupe_paths(paths: list[Path]) -> list[Path]:
    seen: set[str] = set()
    unique: list[Path] = []
    for path in paths:
        key = str(path.resolve()) if path.exists() else str(path)
        if key in seen:
            continue
        seen.add(key)
        unique.append(path)
    return unique


def default_runtime_reports() -> list[Path]:
    run_dir = ROOT_DIR / "docs" / "diagnostics" / "runs"
    reports = sorted(run_dir.glob("runtime-performance-report-*.txt"))
    return reports[-1:] if reports else []


def default_egress_jsons() -> list[Path]:
    return existing_paths([ROOT_DIR / "docs" / "product" / "runtime-network-egress-latest.json"])


def default_egress_reports() -> list[Path]:
    paths: list[Path] = []
    latest_product = ROOT_DIR / "docs" / "product" / "runtime-network-egress-latest.md"
    if latest_product.exists():
        paths.append(latest_product)
    run_dir = ROOT_DIR / "docs" / "diagnostics" / "runs"
    run_reports = sorted(run_dir.glob("runtime-network-egress-*.md"))
    if run_reports:
        paths.append(run_reports[-1])
    return dedupe_paths(paths)


def selected_models(raw_models: list[str]) -> list[ModelConfig]:
    if not raw_models:
        return SUPPORTED_MODELS
    models: list[ModelConfig] = []
    seen: set[str] = set()
    for raw in raw_models:
        alias = canonical_alias(raw)
        if not alias:
            raise SystemExit(f"unknown supported model config: {raw}")
        if alias in seen:
            continue
        seen.add(alias)
        models.append(MODEL_BY_ALIAS[alias])
    return models


def choose_metric(
    alias: str,
    name: str,
    log_metrics: dict[str, dict[str, MetricSummary]],
    report: RuntimeReportEvidence,
) -> MetricSummary | None:
    return log_metrics.get(alias, {}).get(name) or report.metrics.get(alias, {}).get(name)


def runtime_resource_text(alias: str, active_alias: str | None, report: RuntimeReportEvidence) -> str:
    if alias != active_alias:
        return "missing"
    fields = []
    if report.cpu_percent is not None:
        fields.append(f"cpu={report.cpu_percent:.1f}%")
    if report.rss_mb is not None:
        fields.append(f"rss={report.rss_mb}MB")
    if report.energy_risk is not None:
        fields.append(f"energy={report.energy_risk}")
    return " ".join(fields) if fields else "missing"


def no_egress_text(alias: str, active_alias: str | None, egress: EgressEvidence) -> str:
    if egress.status == "missing":
        return "missing"
    if active_alias is None:
        return f"{egress.status} (global)"
    if alias == active_alias:
        return f"{egress.status} (active)"
    return "missing"


def table_row(values: list[str]) -> str:
    escaped = [value.replace("|", "\\|") for value in values]
    return "| " + " | ".join(escaped) + " |"


def evidence_gaps(
    model: ModelConfig,
    state: AssetState,
    log_metrics: dict[str, dict[str, MetricSummary]],
    report: RuntimeReportEvidence,
    active_alias: str | None,
    egress: EgressEvidence,
) -> list[str]:
    gaps: list[str] = []
    if state.installed == "missing":
        gaps.append("install state missing")
    if state.available != "available":
        gaps.append(f"availability {state.available}")
    for metric_name, label in [
        ("load", "load latency"),
        ("warm", "warm latency"),
        ("suggestion", "suggestion latency"),
        ("first_token", "first-token latency"),
        ("total", "total latency"),
    ]:
        if choose_metric(model.alias, metric_name, log_metrics, report) is None:
            gaps.append(f"{label} missing")
    if model.alias == active_alias and runtime_resource_text(model.alias, active_alias, report) == "missing":
        gaps.append("CPU/RSS/energy missing")
    if no_egress_text(model.alias, active_alias, egress) == "missing":
        gaps.append("no-egress evidence missing")
    return gaps


def print_report(args: argparse.Namespace) -> None:
    diagnostics_path = Path(args.diagnostics_log).expanduser()
    model_root = Path(args.model_root).expanduser()
    runtime_report_paths = existing_paths(args.runtime_report)
    egress_json_paths = existing_paths(args.egress_json)
    egress_report_paths = existing_paths(args.egress_report)

    if not args.no_default_artifacts:
        runtime_report_paths = dedupe_paths(runtime_report_paths + default_runtime_reports())
        egress_json_paths = dedupe_paths(egress_json_paths + default_egress_jsons())
        egress_report_paths = dedupe_paths(egress_report_paths + default_egress_reports())

    log_metrics, latest_log_alias = parse_diagnostics(diagnostics_path, max(0, args.line_limit))
    runtime_report = merge_runtime_reports(runtime_report_paths)
    active_alias = runtime_report.active_alias or latest_log_alias
    egress = load_egress_evidence(egress_json_paths, egress_report_paths)
    models = selected_models(args.models)

    print("Supported local model config matrix")
    print(f"Diagnostics log: {diagnostics_path if diagnostics_path.exists() else 'missing'}")
    print(f"Model root: {model_root if model_root.exists() else 'missing'}")
    print(
        "Runtime reports: "
        + (", ".join(map(str, runtime_report_paths)) if runtime_report_paths else "missing")
    )
    print(f"Active runtime model: {active_alias or 'missing'}")
    print(f"No-egress evidence: {egress.status} ({egress.reason})")
    print(
        "Privacy: metadata-only report; no prompts, typed text, completions, screenshots, URLs, or event paths are printed."
    )
    print()

    headers = [
        "model config",
        "installed",
        "available",
        "size",
        "load",
        "warm",
        "suggestion p50/p95",
        "first-token p50/p95",
        "total p50/p95",
        "CPU/RSS/energy",
        "no-egress",
    ]
    print(table_row(headers))
    print(table_row(["---"] * len(headers)))

    gap_lines: list[str] = []
    for model in models:
        state = asset_state(model_root, model, runtime_report)
        print(
            table_row(
                [
                    model.label,
                    state.installed,
                    state.available,
                    state.size,
                    metric_text(choose_metric(model.alias, "load", log_metrics, runtime_report)),
                    metric_text(choose_metric(model.alias, "warm", log_metrics, runtime_report)),
                    metric_text(choose_metric(model.alias, "suggestion", log_metrics, runtime_report)),
                    metric_text(choose_metric(model.alias, "first_token", log_metrics, runtime_report)),
                    metric_text(choose_metric(model.alias, "total", log_metrics, runtime_report)),
                    runtime_resource_text(model.alias, active_alias, runtime_report),
                    no_egress_text(model.alias, active_alias, egress),
                ]
            )
        )
        gaps = evidence_gaps(model, state, log_metrics, runtime_report, active_alias, egress)
        if gaps:
            gap_lines.append(f"  - {model.alias}: {', '.join(gaps)}")

    print()
    print("Evidence gaps")
    if gap_lines:
        for line in gap_lines:
            print(line)
    else:
        print("  - none in the selected evidence slice")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Compare SteadyType app-owned supported local model configs using only local "
            "diagnostics and proof artifacts."
        )
    )
    parser.add_argument("--diagnostics-log", default=str(DEFAULT_DIAGNOSTICS_LOG))
    parser.add_argument("--model-root", default=str(DEFAULT_MODEL_ROOT))
    parser.add_argument("--line-limit", type=int, default=DEFAULT_LINE_LIMIT)
    parser.add_argument("--runtime-report", action="append", default=[])
    parser.add_argument("--egress-json", action="append", default=[])
    parser.add_argument("--egress-report", action="append", default=[])
    parser.add_argument(
        "--no-default-artifacts",
        action="store_true",
        help="Do not auto-read repo-local runtime/no-egress proof artifacts.",
    )
    parser.add_argument("--models", nargs="*", default=[])
    args = parser.parse_args()

    print_report(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
