#!/usr/bin/env python3
"""Matchmaker Sitting 1: build the meaning-memory index from live capture,
then demo retrieval on 10 real held-out typing moments.

Design (owner-settled, 2026-07-28):
  - capture-ONLY: no iMessage seed. Pairs come from joining brain_samples
    (incoming side: what was on screen) with ghost_events (reply side: what
    the owner actually typed or accepted), the same join the trace bench uses.
  - flat index file, brute-force cosine search.
  - embedder: all-MiniLM-L6-v2 — the same model live_quiz.py already uses
    for similar★. (The app's production path will use a llama-server
    embedder; for Sitting 1 offline we ride the proven python one.)

Exam hygiene: rows whose md5(ts)%5==0 are the exam slice and NEVER enter the
index (identical rule to live_quiz.py). The 10 demo probes are drawn FROM
that held-out slice, so the demo is retrieval on moments the index has
never seen.

Output: summary counts + a 10-probe report (incoming → what you wrote →
top-3 retrieved precedents with scores). Owner judges: nod or kill.
"""
import glob
import hashlib
import json
import os
import random
import re
import sys
import time

import numpy as np

USAGE = os.path.expanduser(
    "~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage"
)
OUT_DIR = os.path.expanduser("~/.cache/steadytype-eval/matchmaker")
INDEX_NPZ = os.path.join(OUT_DIR, "index_v1.npz")
INDEX_META = os.path.join(OUT_DIR, "index_v1.meta.jsonl")

REPLY_EVENTS = ("typed_instead", "accept_word", "accept_all")
MIN_REPLY_WORDS = 2          # a pair needs a reply with some meat
MIN_INCOMING_CHARS = 12      # and an incoming side that says something
N_PROBES = 10
TOP_K = 3
SEED = 20260728              # deterministic demo — same probes every run


def is_exam(ts: str) -> bool:
    """Identical to live_quiz.py: the never-train slice."""
    return int(hashlib.md5(ts.encode()).hexdigest(), 16) % 5 == 0


def load_jsonl(pattern):
    rows = []
    for path in sorted(glob.glob(pattern)):
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return rows


def reply_text(e) -> str:
    """The owner's actual words at that moment."""
    ctx = (e.get("context") or "").strip()
    if e.get("event") == "typed_instead":
        cont = (e.get("typed") or "").strip()
    else:
        cont = (e.get("accepted") or e.get("ghost") or "").strip()
    return (ctx + " " + cont).strip() if cont else ctx


def build_pairs(events, samples):
    """Join reply moments to the screen that prompted them (trace-bench join:
    latest brain_sample at-or-before the event whose suggestion prefix appears
    in the event's ghost)."""
    events = sorted(events, key=lambda r: r.get("ts", ""))
    samples = sorted(samples, key=lambda r: r.get("ts", ""))
    sample_ts = [s.get("ts", "") for s in samples]

    pairs = []
    joined = 0
    lo = 0
    for e in events:
        if e.get("event") not in REPLY_EVENTS:
            continue
        r = reply_text(e)
        if len(r.split()) < MIN_REPLY_WORDS:
            continue
        ets = e.get("ts", "")
        # advance a window pointer instead of scanning all samples per event
        while lo < len(sample_ts) and sample_ts[lo] <= ets:
            lo += 1
        screen = ""
        ghost = e.get("ghost") or ""
        for s in reversed(samples[max(0, lo - 400):lo]):
            if s.get("app_bundle") != e.get("app_bundle"):
                continue          # a screen from another app is not this moment
            sugg = (s.get("suggestion") or "")[:20]
            if sugg and sugg in ghost:
                screen = (s.get("screen") or "").strip()
                break
        incoming = screen if len(screen) >= MIN_INCOMING_CHARS else ""
        if not incoming:
            # no usable screen — fall back to the typed context as the
            # "incoming" meaning anchor (context-only memory still helps)
            incoming = (e.get("context") or "").strip()
        if len(incoming) < MIN_INCOMING_CHARS:
            continue
        if screen:
            joined += 1
        pairs.append({
            "ts": ets,
            "app": e.get("app_bundle", ""),
            "event": e.get("event"),
            "incoming": incoming[:600],
            "reply": r[:400],
            "had_screen": bool(screen),
        })
    return pairs, joined


def norm(t: str) -> str:
    return re.sub(r"\s+", " ", t.lower()).strip()


def collapse(pairs):
    """Keystroke events -> exchanges. Within one app and a short window, a
    growing sentence produces many pairs whose replies are prefixes of each
    other; keep only the longest (final) form. Exam split must happen AFTER
    this, or the same moment lands on both sides."""
    pairs = sorted(pairs, key=lambda p: (p["app"], p["ts"]))
    kept = []
    for p in pairs:
        r = norm(p["reply"])
        if not r:
            continue
        merged = False
        for k in reversed(kept[-8:]):
            if k["app"] != p["app"]:
                continue
            if abs_seconds(k["ts"], p["ts"]) > 300:
                break
            kr = norm(k["reply"])
            if kr.startswith(r) or r.startswith(kr):
                if len(r) > len(kr):
                    k.update(p)      # newer, longer form wins
                merged = True
                break
        if not merged:
            kept.append(dict(p))
    # exact dupes (same meaning anchor + same reply)
    seen, out = set(), []
    for p in kept:
        key = (p["app"], norm(p["incoming"])[:200], norm(p["reply"])[:200])
        if key in seen:
            continue
        seen.add(key)
        out.append(p)
    return out


def abs_seconds(a: str, b: str) -> float:
    import datetime
    try:
        ta = datetime.datetime.fromisoformat(a.replace("Z", "+00:00"))
        tb = datetime.datetime.fromisoformat(b.replace("Z", "+00:00"))
        return abs((tb - ta).total_seconds())
    except ValueError:
        return 1e9


def main():
    t0 = time.time()
    print("=" * 72)
    print("MATCHMAKER SITTING 1 — index build + 10-probe retrieval demo")
    print("=" * 72)

    events = load_jsonl(os.path.join(USAGE, "ghost_events_*.jsonl"))
    samples = load_jsonl(os.path.join(USAGE, "brain_samples_*.jsonl"))
    print(f"loaded: {len(events):,} ghost events, {len(samples):,} brain samples")

    raw_pairs, joined = build_pairs(events, samples)
    pairs = collapse(raw_pairs)
    by_event = {}
    for p in pairs:
        by_event[p["event"]] = by_event.get(p["event"], 0) + 1
    n_screen = sum(1 for p in pairs if p["had_screen"])
    print(f"raw keystroke-level pairs: {len(raw_pairs):,}")
    print(f"collapsed to exchanges   : {len(pairs):,} "
          f"({n_screen:,} screen-joined, {len(pairs) - n_screen:,} context-anchored)")
    print(f"  by event: {by_event}")

    train = [p for p in pairs if not is_exam(p["ts"])]
    exam = [p for p in pairs if is_exam(p["ts"])]
    print(f"exam-slice split: {len(train):,} indexable / {len(exam):,} held out "
          f"(md5(ts)%5==0 — never indexed)")

    if len(train) < 50 or len(exam) < N_PROBES:
        print("FATAL: not enough pairs to build a meaningful demo.")
        sys.exit(1)

    print("\nembedding (all-MiniLM-L6-v2, same model as live_quiz similar★)...")
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer("all-MiniLM-L6-v2")
    t1 = time.time()
    vecs = model.encode(
        [p["incoming"] for p in train],
        batch_size=128,
        convert_to_numpy=True,
        normalize_embeddings=True,
        show_progress_bar=False,
    ).astype(np.float32)
    vecs = np.nan_to_num(vecs)
    embed_s = time.time() - t1
    print(f"embedded {len(train):,} incoming texts in {embed_s:.1f}s "
          f"({len(train)/max(embed_s,0.001):.0f}/s), dim={vecs.shape[1]}")

    np.savez_compressed(INDEX_NPZ, vectors=vecs)
    with open(INDEX_META, "w", encoding="utf-8") as f:
        for p in train:
            f.write(json.dumps(p, ensure_ascii=False) + "\n")
    size_mb = (os.path.getsize(INDEX_NPZ) + os.path.getsize(INDEX_META)) / 1e6
    print(f"index written: {INDEX_NPZ}")
    print(f"               {INDEX_META}")
    print(f"index size on disk: {size_mb:.1f} MB")

    # --- demo ---------------------------------------------------------
    rng = random.Random(SEED)
    # prefer probes that had a real screen join and a real typed reply
    good = [p for p in exam if p["had_screen"] and p["event"] == "typed_instead"]
    pool = good if len(good) >= N_PROBES else exam
    probes = rng.sample(pool, N_PROBES)

    q = model.encode(
        [p["incoming"] for p in probes],
        convert_to_numpy=True,
        normalize_embeddings=True,
    ).astype(np.float32)
    q = np.nan_to_num(q)

    t2 = time.time()
    scores = q @ vecs.T          # cosine (both sides normalized)
    search_ms = (time.time() - t2) * 1000
    print(f"\nbrute-force search: {N_PROBES} probes x {len(train):,} memories "
          f"in {search_ms:.1f} ms total ({search_ms/N_PROBES:.2f} ms/probe)")

    print("\n" + "=" * 72)
    print(f"10-PROBE DEMO — held-out moments the index has never seen")
    print("=" * 72)
    for i, p in enumerate(probes):
        pr = norm(p["reply"])
        top = [j for j in np.argsort(-scores[i])
               if norm(train[j]["reply"]) != pr][:TOP_K]
        print(f"\nPROBE {i+1}  [{p['app'] or '?'}  {p['ts']}  {p['event']}]")
        print(f"  INCOMING : {p['incoming'][:160]}")
        print(f"  YOU WROTE: {p['reply'][:160]}")
        print(f"  top-{TOP_K} precedents:")
        for rank, j in enumerate(top, 1):
            m = train[j]
            print(f"    {rank}. ({scores[i][j]:.3f}) "
                  f"[{m['app'] or '?'} {m['ts'][:10]}]")
            print(f"       incoming: {m['incoming'][:120]}")
            print(f"       you wrote: {m['reply'][:120]}")

    print("\n" + "=" * 72)
    print(f"done in {time.time()-t0:.1f}s. Judge the demo: "
          f"do the precedents rhyme with the moment? Nod → Sitting 2 (A/B). "
          f"Kill → we stop here.")
    print("=" * 72)


if __name__ == "__main__":
    main()
