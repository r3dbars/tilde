#!/usr/bin/env python3
"""Accuracy + latency harness for the INSTANT DICTIONARY layer.

The instant dictionary is the mid-word word-completion fallback in
InlineGhostIME (`dictionaryCompletion(for:)` in
Sources/InlineGhostIME/GhostInputController.swift) — NSSpellChecker
completions filtered/ranked by a couple of small quality rules (never extend
an already-complete common word, prefer completing TO a common word, cap
obscure completions at +9 chars). It fires before the brain model ever gets
a chance to respond, so it may be a large share of the app's *felt* speed —
but it has never been measured against real text.

This harness never touches the running app: it drives a standalone Swift
probe (script/dict_probe.swift) that reimplements dictionaryCompletion
byte-for-byte, using the real macOS NSSpellChecker. It takes real words from
the owner's corpora (~/.cache/steadytype-eval/imessage_eval.jsonl and
diverse_eval.jsonl), cuts each word after 2 and after 3 letters, asks the
probe to complete it, and scores top-1 accuracy + latency.

Usage:
  python3 script/dictionary_test.py                  # default: both corpora, 1200 words
  python3 script/dictionary_test.py -n 3000 --seed 7
  python3 script/dictionary_test.py --corpus imessage # iMessage corpus only

Data in, data out: ~/.cache/steadytype-eval/ only. Nothing is transmitted;
this only shells out to a local compiled binary and reads local jsonl files.
"""
import argparse
import json
import os
import random
import re
import statistics
import subprocess
import sys
import time

CACHE = os.path.expanduser("~/.cache/steadytype-eval")
CORPUS_FILES = {
    "imessage": os.path.join(CACHE, "imessage_eval.jsonl"),
    "diverse": os.path.join(CACHE, "diverse_eval.jsonl"),
}
PROBE_SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dict_probe.swift")
PROBE_BIN_DEFAULT = os.path.join(CACHE, "bin", "dict_probe")
RAW_OUT_DEFAULT = os.path.join(CACHE, "dictionary_layer_eval.jsonl")

WORD_RE = re.compile(r"^[A-Za-z]+$")
MIN_WORD_LEN = 5  # so a 3-letter prefix always leaves >=2 trailing chars


def ensure_probe(probe_bin, probe_src, rebuild=False):
    """Compile the Swift probe with swiftc if missing or stale. Never touches
    the running app — this is a standalone CLI binary."""
    need_build = rebuild or not os.path.exists(probe_bin)
    if not need_build:
        try:
            need_build = os.path.getmtime(probe_src) > os.path.getmtime(probe_bin)
        except OSError:
            need_build = True
    if need_build:
        os.makedirs(os.path.dirname(probe_bin), exist_ok=True)
        print("compiling probe: swiftc -O %s -o %s" % (probe_src, probe_bin), file=sys.stderr)
        result = subprocess.run(
            ["swiftc", "-O", probe_src, "-o", probe_bin],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            sys.stderr.write(result.stderr)
            raise SystemExit("swiftc compile failed")
    return probe_bin


def iter_words(path, source_tag):
    if not os.path.exists(path):
        return
    with open(path, "r") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            text = rec.get("text") or ""
            for raw in text.split():
                w = raw.strip(".,!?;:\"'()[]{}")
                if len(w) < MIN_WORD_LEN or not WORD_RE.match(w):
                    continue
                yield w.lower(), source_tag


def sample_words(corpora, n, seed):
    """Sample word OCCURRENCES (not deduped) so frequent everyday words get
    proportionally more weight, matching real typing distribution."""
    pool = []
    for name in corpora:
        path = CORPUS_FILES[name]
        pool.extend(iter_words(path, name))
    if not pool:
        raise SystemExit("no eligible words found in corpora: %s" % (corpora,))
    rng = random.Random(seed)
    if n >= len(pool):
        sample = pool[:]
        rng.shuffle(sample)
    else:
        sample = rng.sample(pool, n)
    return sample


def run_probe(probe_bin, prefixes):
    """Feed all prefixes to the long-lived probe process at once (one
    process, no running-app interaction) and parse the aligned output."""
    stdin_text = "\n".join(prefixes) + "\n"
    proc = subprocess.run(
        [probe_bin], input=stdin_text, capture_output=True, text=True, timeout=300,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        raise SystemExit("dict_probe failed (exit %d)" % proc.returncode)
    lines = proc.stdout.splitlines()
    if len(lines) != len(prefixes):
        raise SystemExit(
            "probe output misaligned: sent %d prefixes, got %d lines"
            % (len(prefixes), len(lines))
        )
    out = []
    for line in lines:
        suffix, _, ns = line.partition("\t")
        try:
            elapsed_ns = int(ns)
        except ValueError:
            elapsed_ns = -1
        out.append((suffix, elapsed_ns))
    return out


def pctl(values, p):
    if not values:
        return float("nan")
    s = sorted(values)
    idx = min(len(s) - 1, int(round(p / 100.0 * (len(s) - 1))))
    return s[idx]


def summarize(results, cut_len):
    rows = [r for r in results if r["cut_len"] == cut_len]
    n = len(rows)
    if n == 0:
        return None
    correct = sum(1 for r in rows if r["correct"])
    offered = sum(1 for r in rows if r["suffix"] != "")
    latencies_ms = [r["elapsed_ns"] / 1e6 for r in rows if r["elapsed_ns"] >= 0]
    return {
        "cut_len": cut_len,
        "n": n,
        "top1_accuracy": correct / n,
        "coverage": offered / n,  # fraction of prefixes where ANY completion was offered
        "precision_given_offered": (correct / offered) if offered else float("nan"),
        "p50_latency_ms": pctl(latencies_ms, 50),
        "p90_latency_ms": pctl(latencies_ms, 90),
        "mean_latency_ms": statistics.mean(latencies_ms) if latencies_ms else float("nan"),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--corpus", action="append", choices=sorted(CORPUS_FILES.keys()),
                     help="corpus to sample from (repeatable); default: all available")
    ap.add_argument("-n", "--sample-size", type=int, default=1200,
                     help="number of word occurrences to sample (default 1200)")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--probe-bin", default=PROBE_BIN_DEFAULT)
    ap.add_argument("--rebuild-probe", action="store_true")
    ap.add_argument("--out", default=RAW_OUT_DEFAULT, help="raw per-word jsonl output path")
    args = ap.parse_args()

    corpora = args.corpus or [name for name, path in CORPUS_FILES.items() if os.path.exists(path)]
    if not corpora:
        raise SystemExit("no corpus files found under %s" % CACHE)

    probe_bin = ensure_probe(args.probe_bin, PROBE_SRC, rebuild=args.rebuild_probe)

    words = sample_words(corpora, args.sample_size, args.seed)
    print("sampled %d word occurrences from %s" % (len(words), corpora), file=sys.stderr)

    # Build one flat prefix list covering both cut points per word, in a
    # fixed order we can zip back up after the probe responds.
    prefixes = []
    meta = []
    for word, source in words:
        for cut_len in (2, 3):
            prefixes.append(word[:cut_len])
            meta.append({"word": word, "source": source, "cut_len": cut_len})

    t0 = time.time()
    outputs = run_probe(probe_bin, prefixes)
    wall_s = time.time() - t0
    print("probe returned %d results in %.1fs" % (len(outputs), wall_s), file=sys.stderr)

    results = []
    for m, (suffix, elapsed_ns) in zip(meta, outputs):
        completed = m["word"][:m["cut_len"]] + suffix
        results.append({
            "word": m["word"],
            "source": m["source"],
            "cut_len": m["cut_len"],
            "prefix": m["word"][:m["cut_len"]],
            "suffix": suffix,
            "completed": completed,
            "correct": completed == m["word"],
            "elapsed_ns": elapsed_ns,
        })

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as fh:
        for r in results:
            fh.write(json.dumps(r) + "\n")
    print("wrote raw results: %s" % args.out, file=sys.stderr)

    print()
    print("Instant dictionary layer — accuracy + latency")
    print("corpora: %s   words sampled: %d   seed: %d" % (",".join(corpora), len(words), args.seed))
    print("-" * 78)
    header = "%-10s %8s %12s %10s %20s %12s" % (
        "prefix", "n", "top1 acc", "coverage", "precision|offered", "p50 lat(ms)")
    print(header)
    for cut_len in (2, 3):
        s = summarize(results, cut_len)
        if s is None:
            continue
        print("%-10s %8d %11.1f%% %9.1f%% %19.1f%% %12.3f" % (
            "%d-letter" % cut_len, s["n"], s["top1_accuracy"] * 100,
            s["coverage"] * 100, s["precision_given_offered"] * 100, s["p50_latency_ms"],
        ))
    print("-" * 78)
    all_lat = [r["elapsed_ns"] / 1e6 for r in results if r["elapsed_ns"] >= 0]
    print("overall p50 latency: %.3fms   p90: %.3fms   mean: %.3fms" % (
        pctl(all_lat, 50), pctl(all_lat, 90), statistics.mean(all_lat) if all_lat else float("nan"),
    ))

    # Per-source breakdown, only if more than one corpus contributed.
    sources = sorted(set(r["source"] for r in results))
    if len(sources) > 1:
        print()
        print("by source:")
        for src in sources:
            for cut_len in (2, 3):
                rows = [r for r in results if r["source"] == src and r["cut_len"] == cut_len]
                if not rows:
                    continue
                acc = sum(1 for r in rows if r["correct"]) / len(rows)
                print("  %-10s %d-letter  n=%-6d top1=%.1f%%" % (src, cut_len, len(rows), acc * 100))


if __name__ == "__main__":
    main()
