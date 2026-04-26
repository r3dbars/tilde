#!/usr/bin/env python3
import argparse
import re
import statistics
from pathlib import Path


DEFAULT_LOG = Path.home() / "Library/Logs/AutocompleteLab/diagnostics.log"

BOOTSTRAP_RE = re.compile(
    r"^(?P<timestamp>\S+) runtime-bootstrap .*?\basset=(?P<asset>\S+)"
)
TIMING_RE = re.compile(
    r"^(?P<timestamp>\S+) mlx-completion-timing .*?"
    r"\bfirstChunkMilliseconds=(?P<first>\d+|none).*?"
    r"\bgenerationMilliseconds=(?P<generation>\d+).*?"
    r"\bmode=(?P<mode>\w+).*?"
    r"\btotalMilliseconds=(?P<total>\d+)"
)
PRESENTED_RE = re.compile(
    r"^(?P<timestamp>\S+) suggestion-presented .*?"
    r"\blatencyMilliseconds=(?P<latency>\d+).*?"
    r"\brequestMode=(?P<mode>\w+)"
)


def percentile(values, fraction):
    if not values:
        return None

    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def metric_line(label, values):
    if not values:
        return f"{label}: no samples"

    return (
        f"{label}: n={len(values)} min={min(values)}ms "
        f"avg={round(statistics.mean(values))}ms "
        f"p50={percentile(values, 0.50)}ms "
        f"p90={percentile(values, 0.90)}ms "
        f"max={max(values)}ms"
    )


def parse_launches(lines):
    launches = []
    current = None

    for line in lines:
        bootstrap = BOOTSTRAP_RE.search(line)
        if bootstrap:
            current = {
                "timestamp": bootstrap.group("timestamp"),
                "asset": bootstrap.group("asset"),
                "timings": [],
                "presented": [],
            }
            launches.append(current)
            continue

        if current is None:
            continue

        timing = TIMING_RE.search(line)
        if timing:
            first = timing.group("first")
            current["timings"].append(
                {
                    "timestamp": timing.group("timestamp"),
                    "mode": timing.group("mode"),
                    "first": None if first == "none" else int(first),
                    "generation": int(timing.group("generation")),
                    "total": int(timing.group("total")),
                }
            )
            continue

        presented = PRESENTED_RE.search(line)
        if presented:
            current["presented"].append(
                {
                    "timestamp": presented.group("timestamp"),
                    "mode": presented.group("mode"),
                    "latency": int(presented.group("latency")),
                }
            )

    return launches


def print_launch(launch):
    print(f"Launch: {launch['timestamp']} asset={launch['asset']}")

    timings = launch["timings"]
    presented = launch["presented"]
    if not timings and not presented:
        print("  no timing samples yet")
        return

    modes = sorted({item["mode"] for item in timings} | {item["mode"] for item in presented})
    for mode in modes:
        mode_timings = [item for item in timings if item["mode"] == mode]
        mode_presented = [item for item in presented if item["mode"] == mode]
        first = [item["first"] for item in mode_timings if item["first"] is not None]
        total = [item["total"] for item in mode_timings]
        shown = [item["latency"] for item in mode_presented]

        print(f"  {mode}")
        print(f"    {metric_line('first token', first)}")
        print(f"    {metric_line('model total', total)}")
        print(f"    {metric_line('shown latency', shown)}")


def main():
    parser = argparse.ArgumentParser(description="Summarize local Autocomplete Lab model latency logs.")
    parser.add_argument("--log", default=str(DEFAULT_LOG), help="diagnostics.log path")
    parser.add_argument("--latest", action="store_true", help="show only the latest model launch")
    parser.add_argument("--asset", help="show only launches whose asset contains this text")
    args = parser.parse_args()

    log_path = Path(args.log).expanduser()
    if not log_path.exists():
        raise SystemExit(f"diagnostics log missing: {log_path}")

    launches = parse_launches(log_path.read_text(errors="ignore").splitlines())
    if args.asset:
        launches = [launch for launch in launches if args.asset in launch["asset"]]
    if args.latest and launches:
        launches = [launches[-1]]

    if not launches:
        raise SystemExit("no matching model launches found")

    for index, launch in enumerate(launches):
        if index:
            print()
        print_launch(launch)


if __name__ == "__main__":
    main()
