#!/usr/bin/env python3
"""Q08 aggregate-only analysis; caller and interpretation: Q08 experiment record.

Requires NumPy in the analyst environment, not in the shipped app. Input files
stay owner-only. No inference, campaign mutation, comparison, or promotion.
Usage: python3 script/lab_cache_analysis.py CAMPAIGN_DIRECTORY OUTPUT_JSON
       python3 script/lab_cache_analysis.py --self-test
"""
import bisect
import collections
import copy
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import sqlite3
import sys

import numpy as np

ARMS = ("prompt-cache-off", "prompt-cache-on")
IDENTITY = ("rootScenarioID", "scenarioID", "replayCheckpoint",
            "contextVariant", "generationSeed", "repetition")
CAMPAIGN = "4c22544a-0e77-4164-a690-e5bffc61a121"
SOURCE = "9857295778f0dd49ed45ae0de921c09f826ca1bb"
BAD = {"wrong", "unwanted"}


def require(value, message):
    if not value:
        raise ValueError(message)  # Static messages only; never echo input rows.


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def identity(case):
    return tuple(case[k] for k in IDENTITY)


def index_cases(cases):
    result = {identity(c): c for c in cases}
    require(len(result) == len(cases), "duplicate paired identity")
    return result


def percentile(values, fraction):
    if not len(values):
        return None
    ordered = sorted(values)
    return float(ordered[math.floor(fraction * (len(ordered) - 1) + 0.5)])


def rate(numerator, denominator):
    return None if denominator == 0 else numerator / denominator


def counters(cases):
    outcomes = collections.Counter(c["outcome"] for c in cases)
    return {"evaluations": len(cases), "model_requests": sum(c["modelRequested"] for c in cases),
            "policy_suppressions": sum(c["policySuppressed"] for c in cases),
            "useful": outcomes["useful"], "bad": sum(outcomes[k] for k in BAD),
            "shown": sum(c["offered"] for c in cases),
            "safe_opportunities": sum(c["expectedSuggestion"] for c in cases),
            "outcomes": dict(sorted(outcomes.items())),
            "useful_per_safe": rate(outcomes["useful"], sum(c["expectedSuggestion"] for c in cases)),
            "bad_per_shown": rate(sum(outcomes[k] for k in BAD), sum(c["offered"] for c in cases))}


def histogram_quantile(histograms, fraction):
    # Same noninterpolating nearest-index convention as LabScorer, including
    # Swift's positive half-away-from-zero rounding. Histograms preserve exact
    # integer milliseconds and repeated cluster multiplicities.
    totals = histograms.sum(axis=1)
    require(np.all(totals > 0), "bootstrap has no requested observations")
    rank = np.floor(fraction * (totals - 1) + 0.5)
    return (np.cumsum(histograms, axis=1) > rank[:, None]).argmax(axis=1)


def bootstrap(pairs, field, draws=10000):
    groups = sorted({a[field] for a, _ in pairs})
    positions = {group: i for i, group in enumerate(groups)}
    counts = np.zeros((len(groups), 8), dtype=np.int64)
    hist = {}
    for metric in ("latencyMilliseconds", "firstTokenMilliseconds"):
        largest = max(c[metric] for pair in pairs for c in pair if c["modelRequested"])
        hist[metric] = np.zeros((2, len(groups), largest + 1), dtype=np.int64)
    for a, b in pairs:
        i = positions[a[field]]
        require(a[field] == b[field], "cluster mismatch")
        for arm, c in enumerate((a, b)):
            counts[i, arm * 4:arm * 4 + 4] += (
                c["outcome"] == "useful", c["expectedSuggestion"],
                c["outcome"] in BAD, c["offered"])
            if c["modelRequested"]:
                for metric in hist:
                    hist[metric][arm, i, c[metric]] += 1
    samples = collections.defaultdict(list)
    rng = np.random.default_rng(73017)
    for start in range(0, draws, 100):
        weights = rng.multinomial(len(groups), np.full(len(groups), 1 / len(groups)),
                                  size=min(100, draws - start))
        totals = weights @ counts
        require(np.all(totals[:, [1, 3, 5, 7]] > 0), "undefined quality bootstrap rate")
        samples["useful_per_safe_delta_pp"].extend(100 * (totals[:, 4] / totals[:, 5] - totals[:, 0] / totals[:, 1]))
        samples["bad_per_shown_delta_pp"].extend(100 * (totals[:, 6] / totals[:, 7] - totals[:, 2] / totals[:, 3]))
        for metric, matrix in hist.items():
            off, on = weights @ matrix[0], weights @ matrix[1]
            for p in (50, 95, 99):
                q0 = histogram_quantile(off, p / 100)
                q1 = histogram_quantile(on, p / 100)
                require(np.all(q0 > 0), "undefined latency reduction")
                samples[f"{metric}_p{p}_reduction_percent"].extend(100 * (q0 - q1) / q0)
    return {"clusters": len(groups), "draws": draws, "seed": 73017,
            "rng": "NumPy PCG64 multinomial", "intervals95": {
                k: [percentile(v, .025), percentile(v, .975)] for k, v in samples.items()}}


def memory_analysis(rows, events, block_requests):
    ordered = sorted(events, key=lambda e: e["machine"]["checkedAt"])
    starts = [e["machine"]["checkedAt"] for e in ordered]
    bad_blocks = {e["blockIndex"] for e in events if
                  e["machine"]["thermalLevel"] != "nominal" or
                  not e["machine"]["isOnACPower"] or
                  e["machine"]["lowPowerModeEnabled"]}
    grouped = collections.defaultdict(list)
    valid_rss = 0
    helper_samples = 0
    unassigned = 0
    native_totals = {arm: collections.Counter() for arm in ARMS}
    intervals = collections.Counter()
    invalid_native = 0
    interval_candidates = 0
    previous = None
    for row in rows:
        helpers = row["helpers"]
        require(len(helpers) <= 1, "multiple campaign helpers")
        require(not row.get("stop_reason"), "supervisor stop occurred")
        wall_block = max(0, bisect.bisect_right(starts, row["at"][:19] + "Z") - 1)
        if row.get("other_helper_cpu_percent", 0) > 5 or row.get("on_battery", False):
            bad_blocks.add(ordered[wall_block]["blockIndex"])
        if len(helpers) != 1:
            previous = None
            continue
        helper_samples += 1
        rss = helpers[0].get("rss_kib")
        numeric = isinstance(rss, (int, float)) and math.isfinite(rss) and rss > 0
        valid_rss += numeric
        arm, block = row["arm"], row["block"]
        if arm in ARMS and block is not None and numeric:
            grouped[arm, block].append(rss)
        else:
            unassigned += 1
        same = previous is not None and arm in ARMS and block is not None and (
            previous["arm"], previous["block"], previous["helpers"][0]["pid"]) == (
                arm, block, helpers[0]["pid"])
        if same:
            interval_candidates += 1
            keys = ("llamacpp:prompt_tokens_total", "llamacpp:prompt_tokens_cached_total",
                    "llamacpp:prompt_seconds_total", "llamacpp:tokens_predicted_total",
                    "llamacpp:tokens_predicted_seconds_total")
            before, after = previous["native_metrics"], row["native_metrics"]
            valid = all(isinstance(d.get(k), (float, int)) and math.isfinite(d[k])
                        for d in (before, after) for k in keys)
            valid = valid and all(after[k] >= before[k] for k in keys)
            if valid:
                intervals[arm] += 1
                for k in keys:
                    native_totals[arm][k] += after[k] - before[k]
            else:
                invalid_native += 1
        previous = row
    blocks = sorted({block for arm, block in block_requests if block > 0 and block_requests[arm, block] > 0})
    insufficient = [(arm, b) for b in blocks for arm in ARMS if len(grouped[arm, b]) < 30]
    peaks = [100 * (max(grouped[ARMS[1], b]) / max(grouped[ARMS[0], b]) - 1)
             for b in blocks if all(grouped[arm, b] for arm in ARMS)]
    growth = {}
    for arm in ARMS:
        rss = [r["helpers"][0]["rss_kib"] for r in rows if r["arm"] == arm
               and r["block"] is not None and r["block"] > 1 and len(r["helpers"]) == 1]
        n = len(rss) // 4
        require(n > 0, "insufficient memory quartiles")
        first, last = percentile(rss[:n], .5), percentile(rss[-n:], .5)
        growth[arm] = {"samples_after_first_block": len(rss), "quartile_samples": n,
                       "first_quartile_median_kib": first, "last_quartile_median_kib": last,
                       "growth_percent": 100 * (last / first - 1)}
    powers = [r for r in rows if "on_battery" in r]
    return {"samples": len(rows), "in_helper_samples": helper_samples,
            "numeric_rss_samples": valid_rss, "rss_coverage": rate(valid_rss, helper_samples),
            "unassigned_in_helper_samples": unassigned,
            "attributed_samples": {arm: sum(len(v) for (a, _), v in grouped.items() if a == arm) for arm in ARMS},
            "evaluable_non_sentinel_blocks": len(blocks),
            "arm_blocks_below_30_samples": len(insufficient),
            "minimum_arm_block_samples": min(len(grouped[arm, b]) for arm in ARMS for b in blocks),
            "sampled_peak_kib": max(r["helpers"][0]["rss_kib"] for r in rows if len(r["helpers"]) == 1),
            "maximum_paired_block_peak_increase_percent": max(peaks),
            "growth": growth, "power_samples": len(powers),
            "battery_power_samples": sum(r["on_battery"] for r in powers),
            "battery_percent_range": [min(r["battery_percent"] for r in powers), max(r["battery_percent"] for r in powers)],
            "max_other_helper_cpu_proxy_percent": max(r["other_helper_cpu_percent"] for r in rows),
            "native_valid_intervals": dict(intervals), "native_candidate_intervals": interval_candidates,
            "native_invalid_intervals": invalid_native,
            "native_attributed_deltas": {a: dict(v) for a, v in native_totals.items()},
            "excluded_quiet_blocks": len(bad_blocks)}, bad_blocks


def analyze(directory):
    frozen = json.loads((directory / "frozen.json").read_text())
    require(digest(directory / "campaign.json") == frozen["campaign_sha256"], "campaign digest mismatch")
    reports = {}
    report_hashes = {}
    for path in sorted((directory / "campaign.research/reports").glob("*.json")):
        report = json.loads(path.read_text())
        require(report["arm"]["id"] not in reports, "duplicate arm report")
        require(report["schema"] == "tilde-lab.reply-bench-report.v6", "wrong report version")
        prov = report["provenance"]
        require(prov["experiment"]["campaignID"].lower() == CAMPAIGN, "wrong campaign")
        require(prov["source"]["gitCommitSHA"] == SOURCE and prov["source"]["treeState"] == "clean", "unclean source")
        require(prov["source"]["runnerSHA256"] == frozen["runner_sha256"], "runner mismatch")
        require(report["assets"]["modelSHA256"] == frozen["model_sha256"] and
                report["assets"]["helperSHA256"] == frozen["helper_sha256"], "asset mismatch")
        require(report["privacy"] == {"aggregateOnly": True, "filePaths": False,
                "networkInference": False, "rawModelOutput": False, "rawScenarioText": False}, "privacy mismatch")
        reports[report["arm"]["id"]] = report
        report_hashes[report["arm"]["id"]] = digest(path)
    require(set(reports) == set(ARMS), "missing arm report")
    config = [copy.deepcopy(reports[a]["arm"]) for a in ARMS]
    for arm, flag in zip(config, (False, True)):
        del arm["id"]
        require(arm["generation"].pop("cachePrompt") is flag, "incorrect treatment")
        # These three fields are Swift Sets, so JSON array order is not semantic.
        # Do not normalize arbitrary arrays, such as ordered sampler controls.
        arm["interaction"]["hosts"].sort()
        arm["scenarios"]["intents"].sort()
        arm["scenarios"]["tones"].sort()
    require(config[0] == config[1], "additional treatment difference")
    maps = [index_cases(reports[a]["cases"]) for a in ARMS]
    require(len(maps[0]) == 28800 and maps[0].keys() == maps[1].keys(), "incomplete pairing")
    pairs = [(maps[0][key], maps[1][key]) for key in sorted(maps[0])]
    require(all(len(v) == 48 for v in _group(reports[ARMS[0]]["cases"], "rootScenarioID").values()), "root repetition coverage mismatch")
    require(all({c["generationSeed"] for c in r["cases"]} == {17, 41, 73}
                and {c["repetition"] for c in r["cases"]} == set(range(16)) for r in reports.values()), "seed/repetition mismatch")
    for a, b in pairs:
        require(all(a[k] == b[k] for k in ("category", "counterfactualPairID", "expectedSuggestion", "modelRequested")), "pair population mismatch")
        for c in (a, b):
            if c["modelRequested"]:
                require(all(type(c.get(k)) is int and c[k] > 0 for k in
                        ("latencyMilliseconds", "firstTokenMilliseconds")), "missing request latency")
    db = sqlite3.connect((directory / "research.sqlite3").as_uri() + "?mode=ro", uri=True)
    require(db.execute("SELECT status FROM campaign WHERE id=?", (CAMPAIGN,)).fetchone() == ("completed",), "campaign incomplete")
    require(db.execute("SELECT status,count(*) FROM work_item GROUP BY status").fetchall() == [("completed", 57600)], "work incomplete")
    require(db.execute("SELECT count(*) FROM campaign_session WHERE state='running'").fetchone()[0] == 0, "live session")
    require(db.execute("SELECT count(*) FROM comparison").fetchone()[0] == 0 and
            db.execute("SELECT count(*) FROM promotion").fetchone()[0] == 0, "unexpected decision mutation")
    block_of = {}
    block_requests = collections.Counter()
    observed = 0
    for arm, block, encoded in db.execute("SELECT w.trial_id,w.block_index,o.result_json FROM observation o JOIN work_item w ON w.id=o.work_item_id"):
        c = json.loads(encoded)
        require(c == maps[ARMS.index(arm)][identity(c)], "database/report disagreement")
        require(identity(c) not in block_of or block_of[identity(c)] == block, "paired block mismatch")
        block_of[identity(c)] = block
        block_requests[arm, block] += c["modelRequested"]
        observed += 1
    require(observed == 57600, "missing durable observations")
    events = [json.loads(r[0]) for r in db.execute("SELECT aggregate_json FROM event_log WHERE kind='block-environment' ORDER BY id")]
    require(all(e["armRunOrder"] == list(ARMS[::1 if e["blockIndex"] % 2 == 0 else -1]) and
                e["candidateCacheEnabled"] is False and e["workerCount"] == 1 and e["configuredSlotsPerWorker"] == 1 for e in events), "block controls mismatch")
    rows = [json.loads(line) for line in (directory / "monitor.jsonl").read_text().splitlines()]
    end = json.loads((directory / "monitor-result.json").read_text())
    require(end["exit_status"] == 0 and end["stop_reason"] is None and end["signal"] is None, "unsuccessful supervisor")
    require(len(end["helper_pids"]) == 1 and end["elapsed_seconds"] < 16200, "execution controls mismatch")
    memory, bad_blocks = memory_analysis(rows, events, block_requests)
    result = {"schema": "tilde-lab.q08-aggregate-analysis.v1", "campaign_id": CAMPAIGN.upper(),
              "elapsed_seconds": end["elapsed_seconds"], "reports": {},
              "pairing": {"matched_evaluation_pairs": len(pairs), "unmatched": 0,
                          "requested_pairs": sum(a["modelRequested"] for a, _ in pairs),
                          "missing_request_latency": 0, "roots": len({a["rootScenarioID"] for a, _ in pairs}),
                          "counterfactual_clusters": len({a["counterfactualPairID"] for a, _ in pairs}),
                          "quality_label_mismatches": sum(any(a[k] != b[k] for k in ("outcome", "offered", "expectedSuggestion", "decisionReason")) for a, b in pairs)},
              "memory": memory, "block_count": len(events),
              "block_thermal_counts": dict(collections.Counter(e["machine"]["thermalLevel"] for e in events)),
              "provenance": reports[ARMS[0]]["provenance"],
              "frozen_hashes": frozen, "input_report_hashes": report_hashes,
              "numpy_version": np.__version__}
    for arm in ARMS:
        r = reports[arm]
        counts = counters(r["cases"])
        require(counts["model_requests"] == r["metrics"]["modelRequests"] and counts["useful"] == r["metrics"]["useful"], "metric count mismatch")
        latency = {}
        for key in ("latencyMilliseconds", "firstTokenMilliseconds"):
            values = [c[key] for c in r["cases"] if c["modelRequested"]]
            latency[key] = {f"p{p}": percentile(values, p / 100) for p in (50, 95, 99)}
            report_key = "latency" if key == "latencyMilliseconds" else "firstTokenLatency"
            require(all(latency[key][f"p{p}"] == r["metrics"][report_key][f"p{p}Milliseconds"] for p in (50, 95, 99)), "percentile reconciliation failed")
        result["reports"][arm] = {"id": r["id"], "counts": counts, "latency_ms": latency,
                                 "gates": r["metrics"]["gates"], "metrics": r["metrics"],
                                 "suite_digest": r["suiteDigestSHA256"],
                                 "slices": {k: counters(v) for k, v in sorted(_group(r["cases"], "category").items())}}
    result["counterfactual_bootstrap"] = bootstrap(pairs, "counterfactualPairID")
    result["root_bootstrap"] = bootstrap(pairs, "rootScenarioID")
    quiet = [(a, b) for a, b in pairs if block_of[identity(a)] not in bad_blocks]
    roots = len({a["rootScenarioID"] for a, _ in quiet})
    result["quiet_sensitivity"] = {"roots": roots, "requested_pairs": sum(a["modelRequested"] for a, _ in quiet),
                                  "eligible_for_speed_conclusion": roots >= 100}
    if roots >= 100:
        result["quiet_sensitivity"]["bootstrap"] = bootstrap(quiet, "counterfactualPairID")
    return result


def _group(rows, key):
    grouped = collections.defaultdict(list)
    for row in rows:
        grouped[row[key]].append(row)
    return grouped


def self_test():
    for values in ([1, 2], [1, 1, 2, 8, 15], [3] * 48 + [20] * 96):
        histogram = np.bincount(values)[None, :]
        for p in (.5, .95, .99):
            assert histogram_quantile(histogram, p)[0] == percentile(values, p)
    assert rate(1, 0) is None
    c = {k: 0 for k in IDENTITY}
    try:
        index_cases([c, c])
        raise AssertionError("accepted duplicate")
    except ValueError:
        pass
    pairs = []
    for root in range(4):
        for rep in range(3):
            a = dict(rootScenarioID=str(root), counterfactualPairID=str(root // 2),
                     modelRequested=True, outcome="useful", expectedSuggestion=True,
                     offered=True, latencyMilliseconds=100, firstTokenMilliseconds=50)
            b = dict(a, latencyMilliseconds=80, firstTokenMilliseconds=40)
            pairs.append((a, b))
    for field in ("rootScenarioID", "counterfactualPairID"):
        intervals = bootstrap(pairs, field, draws=100)["intervals95"]
        assert intervals["latencyMilliseconds_p95_reduction_percent"] == [20., 20.]
        assert intervals["useful_per_safe_delta_pp"] == [0., 0.]
    # Independently expand unequal cluster sizes to check multiplicities/ranks.
    clusters = [[1, 3], [5, 7, 9], [12]]
    matrix = np.array([np.bincount(c, minlength=13) for c in clusters])
    for weights in ([1, 1, 1], [0, 3, 0], [2, 0, 1]):
        expanded = [v for c, w in zip(clusters, weights) for _ in range(w) for v in c]
        weighted = (np.array(weights) @ matrix)[None, :]
        for p in (.5, .95, .99):
            assert histogram_quantile(weighted, p)[0] == percentile(expanded, p)
    keys = ("llamacpp:prompt_tokens_total", "llamacpp:prompt_tokens_cached_total",
            "llamacpp:prompt_seconds_total", "llamacpp:tokens_predicted_total",
            "llamacpp:tokens_predicted_seconds_total")
    clock = datetime.datetime(2026, 1, 1)
    rows, events, requests = [], [], {}
    totals = dict.fromkeys(keys, 0)
    for block in (1, 2):
        events.append({"blockIndex": block, "machine": {"checkedAt": clock.isoformat() + "Z",
                       "thermalLevel": "nominal", "isOnACPower": True, "lowPowerModeEnabled": False}})
        for arm in ARMS:
            requests[arm, block] = 30
            for _ in range(30):
                for k in keys:
                    totals[k] += int(k != keys[1] or arm == ARMS[1])
                rows.append({"at": clock.isoformat() + "Z", "helpers": [{"pid": 1, "rss_kib": 1000}],
                             "arm": arm, "block": block, "native_metrics": dict(totals),
                             "on_battery": False, "battery_percent": 80, "other_helper_cpu_percent": 0})
                clock += datetime.timedelta(seconds=1)
    memory, excluded = memory_analysis(rows, events, requests)
    assert not excluded and memory["arm_blocks_below_30_samples"] == 0
    assert memory["native_valid_intervals"] == dict.fromkeys(ARMS, 58)
    assert memory["native_attributed_deltas"][ARMS[1]][keys[1]] == 58
    assert memory["native_attributed_deltas"][ARMS[0]][keys[1]] == 0
    rows[35]["native_metrics"].pop(keys[0])
    rows[40]["native_metrics"][keys[1]] = -1
    rows[50]["arm"] = None
    memory, _ = memory_analysis(rows, events, requests)
    assert memory["native_invalid_intervals"] == 3
    assert memory["unassigned_in_helper_samples"] == 1
    assert memory["arm_blocks_below_30_samples"] == 1
    print("PASS: quantiles, denominators, duplicates, cluster multiplicities, paired bootstrap, native resets/missingness/transitions, RSS coverage")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    else:
        require(len(sys.argv) == 3, "expected campaign directory and aggregate output path")
        destination = Path(sys.argv[2])
        require(not destination.exists(), "refusing to overwrite analysis")
        result = analyze(Path(sys.argv[1]).resolve())
        os.umask(0o077)
        with destination.open("x") as output:
            json.dump(result, output, indent=2, allow_nan=False)
            output.write("\n")
        print("PASS: reconciled complete reports and wrote aggregate analysis")
