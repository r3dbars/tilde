#!/usr/bin/env python3
"""Quiz harness for the instant-dictionary word-completion layer.

CPU-only. Talks to the compiled `dict_probe` binary (script/dict_probe.swift)
over stdin/stdout in batches — never touches the GPU, the dist app,
script/build_and_run.sh, or any SteadyType/llama-server process. All data it
writes goes under ~/.cache/steadytype-eval.

Builds a quiz set of real words (>=5 letters) pulled from the owner's own
vocabulary (imessage_eval.jsonl) and general chat (diverse_eval.jsonl), cuts
each word after 1/2/3/4 letters, asks dict_probe for the completion it would
show, and scores:

  - top-1 accuracy: did the offered completion exactly reproduce the
    intended word?
  - helpful-prefix: was every character it offered correct (even if it
    didn't complete the whole word) — a strictly looser, partial-credit
    version of top-1.
  - keystrokes saved: (word length - cut length) credited only when top-1
    was correct (a wrong guess isn't accepted, so it saves nothing).
  - false-completion rate: of the times it spoke up, how often was it wrong
    — the cost of being wrong for an instant layer that shows ghost text
    with no confirmation step.
  - silence: how often it correctly said nothing vs. guessed (right or
    wrong).
  - latency: p50/p95 of the actual dictionaryCompletion() call, timed
    inside the long-lived Swift process (excludes process-spawn/XPC warm-up
    and stdio overhead).

Also runs a coordinate-ascent sweep over every knob dict_probe exposes, using
a train/test split so the reported "tuned" numbers aren't just curve-fit to
the exact quiz set.

Usage:
    python3 script/dictionary_eval.py
"""
from __future__ import annotations

import json
import os
import random
import re
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_DIR = Path(__file__).resolve().parent
PROBE_BIN = SCRIPT_DIR / "dict_probe"
EVAL_DIR = Path.home() / ".cache" / "steadytype-eval"
IMESSAGE_FILE = EVAL_DIR / "imessage_eval.jsonl"
DIVERSE_FILE = EVAL_DIR / "diverse_eval.jsonl"
OUT_RESULTS = EVAL_DIR / "dictionary_layer_eval_v2.jsonl"
OUT_SWEEP = EVAL_DIR / "dictionary_layer_sweep.jsonl"
OUT_SUMMARY = EVAL_DIR / "dictionary_layer_summary.json"

WORD_RE = re.compile(r"[A-Za-z']+")

DEFAULT_CONFIG = {
    "STEADYTYPE_DICT_MIN_LETTERS": "2",
    "STEADYTYPE_DICT_MIN_SUFFIX": "2",
    "STEADYTYPE_DICT_MAX_OBSCURE_LEN": "9",
    "STEADYTYPE_DICT_PREFER_COMMON": "1",
    "STEADYTYPE_DICT_COMMON_ONLY": "0",
    "STEADYTYPE_DICT_BLOCK_COMPLETE_COMMON": "1",
}

# Coordinate-ascent search space. Keys must match DEFAULT_CONFIG.
KNOB_CANDIDATES = {
    "STEADYTYPE_DICT_MIN_LETTERS": ["1", "2", "3"],
    "STEADYTYPE_DICT_MIN_SUFFIX": ["1", "2", "3", "4"],
    "STEADYTYPE_DICT_MAX_OBSCURE_LEN": ["4", "6", "9", "12", "999"],
    "STEADYTYPE_DICT_PREFER_COMMON": ["1", "0"],
    "STEADYTYPE_DICT_COMMON_ONLY": ["0", "1"],
    "STEADYTYPE_DICT_BLOCK_COMPLETE_COMMON": ["1", "0"],
}

FALSE_COMPLETION_PENALTY = 3.0  # utility cost of a wrong instant guess, in keystroke-equivalents


# --------------------------------------------------------------------------
# Quiz-set construction
# --------------------------------------------------------------------------

def extract_words(path: Path, min_len: int = 5) -> list[str]:
    words: list[str] = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            text = rec.get("text", "")
            for tok in WORD_RE.findall(text):
                tok = tok.strip("'")
                if tok.isalpha() and len(tok) >= min_len:
                    words.append(tok)
    return words


@dataclass
class Case:
    word: str
    source: str
    cut_len: int
    prefix: str


def build_cases(n_per_source: int, seed: int) -> list[Case]:
    rng = random.Random(seed)
    cases: list[Case] = []
    for source, path in (("imessage", IMESSAGE_FILE), ("diverse", DIVERSE_FILE)):
        pool = extract_words(path)
        if not pool:
            continue
        sample_size = min(n_per_source, len(pool))
        sample = rng.sample(pool, sample_size)
        for word in sample:
            for cut_len in (1, 2, 3, 4):
                if cut_len >= len(word):
                    continue
                cases.append(Case(word=word, source=source, cut_len=cut_len, prefix=word[:cut_len]))
    rng.shuffle(cases)
    return cases


# --------------------------------------------------------------------------
# Talking to dict_probe
# --------------------------------------------------------------------------

def run_probe(cases: list[Case], config: dict[str, str]) -> list[tuple[str, int]]:
    """Feed every case's prefix to one long-lived dict_probe process; return
    (offered_suffix, elapsed_ns) in the same order as `cases`."""
    if not cases:
        return []
    env = os.environ.copy()
    env.update(config)
    stdin_data = "\n".join(c.prefix for c in cases) + "\n"
    proc = subprocess.run(
        [str(PROBE_BIN)],
        input=stdin_data,
        capture_output=True,
        text=True,
        env=env,
        check=True,
    )
    out_lines = proc.stdout.splitlines()
    if len(out_lines) != len(cases):
        raise RuntimeError(
            f"dict_probe returned {len(out_lines)} lines for {len(cases)} inputs "
            f"(stderr: {proc.stderr[:500]})"
        )
    results = []
    for line in out_lines:
        suffix, _, elapsed = line.rpartition("\t")
        results.append((suffix, int(elapsed) if elapsed else 0))
    return results


# --------------------------------------------------------------------------
# Scoring
# --------------------------------------------------------------------------

@dataclass
class Scored:
    case: Case
    offered: str
    elapsed_ns: int
    spoke: bool
    top1_correct: bool
    helpful: bool
    keystrokes_saved: int


def score_cases(cases: list[Case], probe_out: list[tuple[str, int]]) -> list[Scored]:
    scored = []
    for case, (offered, elapsed_ns) in zip(cases, probe_out):
        true_suffix = case.word[case.cut_len:]
        spoke = offered != ""
        top1_correct = spoke and offered.lower() == true_suffix.lower()
        helpful = spoke and true_suffix.lower().startswith(offered.lower())
        keystrokes_saved = (len(case.word) - case.cut_len) if top1_correct else 0
        scored.append(Scored(
            case=case, offered=offered, elapsed_ns=elapsed_ns, spoke=spoke,
            top1_correct=top1_correct, helpful=helpful, keystrokes_saved=keystrokes_saved,
        ))
    return scored


def summarize(scored: list[Scored], group_key=None) -> dict:
    if group_key is None:
        groups = {"all": scored}
    else:
        groups: dict[str, list[Scored]] = {}
        for s in scored:
            k = group_key(s)
            groups.setdefault(k, []).append(s)

    out = {}
    for key, items in sorted(groups.items()):
        n = len(items)
        spoken = [s for s in items if s.spoke]
        n_spoken = len(spoken)
        n_correct = sum(1 for s in spoken if s.top1_correct)
        n_wrong = n_spoken - n_correct
        n_helpful = sum(1 for s in spoken if s.helpful)
        keystrokes_saved_total = sum(s.keystrokes_saved for s in items)
        latencies_ms = sorted(s.elapsed_ns / 1e6 for s in items)

        def pct(p):
            if not latencies_ms:
                return 0.0
            idx = min(len(latencies_ms) - 1, int(len(latencies_ms) * p))
            return round(latencies_ms[idx], 4)

        out[key] = {
            "n_cases": n,
            "silence_rate": round(1 - n_spoken / n, 4) if n else 0.0,
            "spoken_rate": round(n_spoken / n, 4) if n else 0.0,
            "top1_accuracy_overall": round(n_correct / n, 4) if n else 0.0,
            "top1_accuracy_when_spoken": round(n_correct / n_spoken, 4) if n_spoken else 0.0,
            "helpful_prefix_rate_when_spoken": round(n_helpful / n_spoken, 4) if n_spoken else 0.0,
            "false_completion_rate_when_spoken": round(n_wrong / n_spoken, 4) if n_spoken else 0.0,
            "false_completion_rate_overall": round(n_wrong / n, 4) if n else 0.0,
            "avg_keystrokes_saved_per_attempt": round(keystrokes_saved_total / n, 4) if n else 0.0,
            "total_keystrokes_saved": keystrokes_saved_total,
            "p50_latency_ms": pct(0.50),
            "p95_latency_ms": pct(0.95),
            "max_latency_ms": round(latencies_ms[-1], 4) if latencies_ms else 0.0,
        }
    return out


def utility(scored: list[Scored]) -> float:
    """Net utility: keystrokes saved minus a heavy penalty per false
    completion (instant layer has no confirm step, so a wrong guess costs
    trust, not just a wasted glance)."""
    saved = sum(s.keystrokes_saved for s in scored)
    wrong = sum(1 for s in scored if s.spoke and not s.top1_correct)
    return saved - FALSE_COMPLETION_PENALTY * wrong


# --------------------------------------------------------------------------
# Coordinate ascent
# --------------------------------------------------------------------------

def coordinate_ascent(train_cases: list[Case], rounds: int = 2) -> tuple[dict, float, list[dict]]:
    config = dict(DEFAULT_CONFIG)
    log = []

    def eval_config(cfg: dict[str, str]) -> float:
        out = run_probe(train_cases, cfg)
        scored = score_cases(train_cases, out)
        return utility(scored)

    best_utility = eval_config(config)
    log.append({"round": 0, "knob": "baseline", "value": None, "config": dict(config), "utility": best_utility})

    for rnd in range(1, rounds + 1):
        improved_this_round = False
        for knob, candidates in KNOB_CANDIDATES.items():
            best_value = config[knob]
            local_best_utility = best_utility
            for value in candidates:
                if value == config[knob]:
                    continue
                trial = dict(config)
                trial[knob] = value
                u = eval_config(trial)
                log.append({"round": rnd, "knob": knob, "value": value, "config": dict(trial), "utility": u})
                if u > local_best_utility:
                    local_best_utility = u
                    best_value = value
            if best_value != config[knob]:
                config[knob] = best_value
                best_utility = local_best_utility
                improved_this_round = True
        if not improved_this_round:
            break

    return config, best_utility, log


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main() -> int:
    if not PROBE_BIN.exists():
        print(f"error: {PROBE_BIN} not found — build it first with:", file=sys.stderr)
        print(f"  swiftc -O {SCRIPT_DIR / 'dict_probe.swift'} -o {PROBE_BIN}", file=sys.stderr)
        return 1
    if not IMESSAGE_FILE.exists() or not DIVERSE_FILE.exists():
        print(f"error: expected eval corpora at {IMESSAGE_FILE} and {DIVERSE_FILE}", file=sys.stderr)
        return 1

    EVAL_DIR.mkdir(parents=True, exist_ok=True)

    n_per_source = int(os.environ.get("DICT_EVAL_N_PER_SOURCE", "800"))
    seed = int(os.environ.get("DICT_EVAL_SEED", "17"))

    print(f"Building quiz set: {n_per_source} words/source, seed={seed} ...")
    all_cases = build_cases(n_per_source, seed)
    print(f"  {len(all_cases)} (word, cut_len) test cases total")

    # 70/30 train/test split for tuning, so reported "tuned" numbers aren't
    # just curve-fit to the exact quiz set.
    rng = random.Random(seed + 1)
    shuffled = all_cases[:]
    rng.shuffle(shuffled)
    split = int(len(shuffled) * 0.7)
    train_cases, test_cases = shuffled[:split], shuffled[split:]
    print(f"  train={len(train_cases)} test={len(test_cases)}")

    # --- Baseline (shipped defaults) on the FULL set ---
    print("Scoring current shipped defaults on full set ...")
    t0 = time.time()
    baseline_out = run_probe(all_cases, DEFAULT_CONFIG)
    baseline_scored = score_cases(all_cases, baseline_out)
    baseline_summary_overall = summarize(baseline_scored)
    baseline_summary_by_cutlen = summarize(baseline_scored, lambda s: f"cut_len={s.case.cut_len}")
    baseline_summary_by_source = summarize(baseline_scored, lambda s: s.case.source)
    baseline_utility = utility(baseline_scored)
    print(f"  done in {time.time() - t0:.1f}s, utility={baseline_utility:.1f}")

    # --- Coordinate ascent on train, evaluate on held-out test ---
    print("Running coordinate-ascent sweep on train split ...")
    t0 = time.time()
    tuned_config, train_utility, sweep_log = coordinate_ascent(train_cases, rounds=2)
    print(f"  sweep done in {time.time() - t0:.1f}s ({len(sweep_log)} configs tried)")
    print(f"  tuned config: {tuned_config}")

    print("Scoring tuned config on held-out test split ...")
    test_out = run_probe(test_cases, tuned_config)
    test_scored = score_cases(test_cases, test_out)
    tuned_test_summary = summarize(test_scored)
    tuned_test_utility = utility(test_scored)

    # Baseline on the same held-out test split, for an apples-to-apples
    # comparison against the tuned numbers above.
    baseline_test_out = run_probe(test_cases, DEFAULT_CONFIG)
    baseline_test_scored = score_cases(test_cases, baseline_test_out)
    baseline_test_summary = summarize(baseline_test_scored)
    baseline_test_utility = utility(baseline_test_scored)

    # --- Tuned config on the FULL set, for the bigger-sample headline numbers ---
    print("Scoring tuned config on full set ...")
    tuned_full_out = run_probe(all_cases, tuned_config)
    tuned_full_scored = score_cases(all_cases, tuned_full_out)
    tuned_full_summary_overall = summarize(tuned_full_scored)
    tuned_full_summary_by_cutlen = summarize(tuned_full_scored, lambda s: f"cut_len={s.case.cut_len}")
    tuned_full_summary_by_source = summarize(tuned_full_scored, lambda s: s.case.source)
    tuned_full_utility = utility(tuned_full_scored)

    # --- Persist raw + summary ---
    with OUT_RESULTS.open("w") as f:
        for s in baseline_scored:
            f.write(json.dumps({
                "config": "baseline", "word": s.case.word, "source": s.case.source,
                "cut_len": s.case.cut_len, "prefix": s.case.prefix, "offered": s.offered,
                "spoke": s.spoke, "top1_correct": s.top1_correct, "helpful": s.helpful,
                "elapsed_ns": s.elapsed_ns,
            }) + "\n")
        for s in tuned_full_scored:
            f.write(json.dumps({
                "config": "tuned", "word": s.case.word, "source": s.case.source,
                "cut_len": s.case.cut_len, "prefix": s.case.prefix, "offered": s.offered,
                "spoke": s.spoke, "top1_correct": s.top1_correct, "helpful": s.helpful,
                "elapsed_ns": s.elapsed_ns,
            }) + "\n")

    with OUT_SWEEP.open("w") as f:
        for entry in sweep_log:
            f.write(json.dumps(entry) + "\n")

    summary = {
        "n_cases_total": len(all_cases),
        "n_cases_train": len(train_cases),
        "n_cases_test": len(test_cases),
        "n_per_source": n_per_source,
        "seed": seed,
        "default_config": DEFAULT_CONFIG,
        "tuned_config": tuned_config,
        "baseline_full_set": {
            "overall": baseline_summary_overall["all"],
            "by_cut_len": baseline_summary_by_cutlen,
            "by_source": baseline_summary_by_source,
            "utility": baseline_utility,
        },
        "tuned_full_set": {
            "overall": tuned_full_summary_overall["all"],
            "by_cut_len": tuned_full_summary_by_cutlen,
            "by_source": tuned_full_summary_by_source,
            "utility": tuned_full_utility,
        },
        "held_out_test_comparison": {
            "baseline": {"overall": baseline_test_summary["all"], "utility": baseline_test_utility},
            "tuned": {"overall": tuned_test_summary["all"], "utility": tuned_test_utility},
        },
        "sweep_configs_tried": len(sweep_log),
    }
    with OUT_SUMMARY.open("w") as f:
        json.dump(summary, f, indent=2)

    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
