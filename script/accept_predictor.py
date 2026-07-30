#!/usr/bin/env python3
"""Would the writer accept this suggestion? An offline judge built from capture.

Why: acceptance is the metric that matters most and the one no quiz can
measure — it needs a human reacting in the moment. This trains a small model
on real accept/reject labels so a NEW model's answers can be scored for
likely acceptance offline, shrinking the feedback loop from a week of typing
to minutes.

Honest framing, because this technique invites self-deception:

  * The judge learns from the CURRENT model's output. It is most trustworthy
    judging models that behave similarly, and least trustworthy judging the
    large changes actually worth making. It shrinks the loop; it does not
    replace live typing.
  * What it actually learned is CONTEXT, not content: which app, what hour.
    It is a "should I speak right now?" judge, not a "are these words good?"
    judge. Useful as a selectivity lever; useless as a quality score.
  * Raw scores are NOT probabilities. Class-balancing (needed because only
    ~7% of rows are positive) inflates them badly — the first version
    predicted 35-60% where the true rate was 2.6%. A Platt calibration is
    fitted on a held-out slice and its effect measured, so the printed
    probabilities mean what they say.
  * It is only worth having if it beats the obvious baseline. Length alone
    already correlates -0.27 with acceptance, so a judge that merely
    rediscovers "short is good" adds nothing. That comparison is printed.
  * Train/test are split by SESSION, never by row: keystrokes of one sentence
    otherwise land on both sides and the score flatters itself. Same lesson
    the live exam learned the hard way.

Run: python3 script/accept_predictor.py
"""
import datetime
import glob
import hashlib
import json
import os
from collections import Counter

import numpy as np

USAGE = os.path.expanduser(
    "~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage")
OUT = os.path.expanduser("~/.cache/steadytype-eval/accept_predictor.json")

ACCEPTS = ("accept_word", "accept_all")
REJECTS = ("typed_instead", "dismiss", "flagged")
RESOLVE_WINDOW_S = 45
SESSION_GAP_S = 600
EDGES = [0, .02, .05, .1, .2, .35, .6, 1.01]


def parse(value):
    try:
        return datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None


def load_events():
    events = []
    for path in glob.glob(os.path.join(USAGE, "ghost_events_*.jsonl")):
        for line in open(path, errors="ignore"):
            try:
                row = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                continue
            if isinstance(row, dict) and row.get("ts"):
                events.append(row)
    events.sort(key=lambda e: e["ts"])
    return events


def label_rows(events):
    """A shown ghost is resolved by the next accept/reject in the same app.

    Deliberately does NOT stop at the next 'shown': a Tab-walk re-shows the
    remainder between presses, and stopping there hid two thirds of accepts
    (measured 1.6% positive against a true 4.4%).
    """
    by_app = {}
    for e in events:
        by_app.setdefault(e.get("app_bundle", ""), []).append(e)

    rows = []
    for app, seq in by_app.items():
        for pos, e in enumerate(seq):
            if e.get("event") != "shown":
                continue
            ghost = (e.get("ghost") or "").strip()
            if not ghost:
                continue
            start = parse(e["ts"])
            verdict = None
            for nxt in seq[pos + 1:pos + 25]:
                later = parse(nxt["ts"])
                if not start or not later:
                    break
                if (later - start).total_seconds() > RESOLVE_WINDOW_S:
                    break
                if nxt.get("event") in ACCEPTS:
                    verdict = 1
                    break
                if nxt.get("event") in REJECTS:
                    verdict = 0
                    break
            if verdict is None:
                continue                      # ambiguous: never resolved
            rows.append({
                "ts": e["ts"], "app": app, "ghost": ghost,
                "context": e.get("context") or "",
                "source": e.get("source") or "?",
                "y": verdict,
            })
    return rows


def sessionise(rows):
    """Group rows into typing sessions (same app, gaps under 10 min)."""
    by_app = {}
    for r in rows:
        by_app.setdefault(r["app"], []).append(r)
    for app, seq in by_app.items():
        seq.sort(key=lambda r: r["ts"])
        start, prev = None, None
        for r in seq:
            now = parse(r["ts"])
            if prev is None or not now or (now - prev).total_seconds() > SESSION_GAP_S:
                start = r["ts"]
            r["session"] = f"{app}|{start}"
            prev = now or prev
    return rows


def featurise(rows):
    apps = [a for a, _ in Counter(r["app"] for r in rows).most_common(8)]
    names = (["words", "chars", "ends_space", "has_punct", "src_model",
              "ctx_len", "ctx_midword", "hour_morning", "hour_afternoon"]
             + [f"app_{a.rsplit('.',1)[-1][:12]}" for a in apps])
    X = []
    for r in rows:
        g, ctx = r["ghost"], r["context"]
        hour = int(r["ts"][11:13])
        local = (hour - 5) % 24                       # UTC -> local
        X.append([
            len(g.split()),
            len(g) / 20.0,
            1.0 if g.endswith(" ") else 0.0,
            1.0 if any(c in g for c in ".,!?") else 0.0,
            1.0 if r["source"] == "model" else 0.0,
            min(len(ctx), 200) / 200.0,
            0.0 if (ctx.endswith(" ") or not ctx) else 1.0,
            1.0 if 5 <= local < 12 else 0.0,
            1.0 if 12 <= local < 18 else 0.0,
        ] + [1.0 if r["app"] == a else 0.0 for a in apps])
    return np.array(X, dtype=float), names


def auc(y, p):
    """Probability a random positive outranks a random negative."""
    order = np.argsort(p)
    ranks = np.empty(len(p), dtype=float)
    ranks[order] = np.arange(1, len(p) + 1)
    pos, neg = y.sum(), len(y) - y.sum()
    if pos == 0 or neg == 0:
        return float("nan")
    return (ranks[y == 1].sum() - pos * (pos + 1) / 2) / (pos * neg)


def main():
    rows = sessionise(label_rows(load_events()))
    y_all = np.array([r["y"] for r in rows])
    print(f"resolved rows: {len(rows):,}   accepted: {y_all.sum():,} "
          f"({100*y_all.mean():.1f}%)")

    # Three-way split BY SESSION so one sentence cannot appear in two slices:
    # train fits the ranker, calib fits the probability mapping, test judges
    # both. Calibrating on the training slice would report a fit to itself.
    sessions = sorted({r["session"] for r in rows})

    def bucket(session):
        return int(hashlib.md5(session.encode()).hexdigest(), 16) % 5

    test_s = {s for s in sessions if bucket(s) == 0}
    calib_s = {s for s in sessions if bucket(s) == 1}
    tr = [i for i, r in enumerate(rows)
          if r["session"] not in test_s and r["session"] not in calib_s]
    ca = [i for i, r in enumerate(rows) if r["session"] in calib_s]
    te = [i for i, r in enumerate(rows) if r["session"] in test_s]
    print(f"sessions: {len(sessions):,}  ->  train {len(tr):,} / "
          f"calibrate {len(ca):,} / test {len(te):,} rows (session-split)")

    X, names = featurise(rows)
    y = y_all

    from sklearn.linear_model import LogisticRegression
    model = LogisticRegression(max_iter=2000, class_weight="balanced")
    model.fit(X[tr], y[tr])
    raw_test = model.predict_proba(X[te])[:, 1]
    model_auc = auc(y[te], raw_test)

    # Platt scaling: a 1-D logistic mapping raw score -> honest probability,
    # fitted on the calibration sessions only. Chosen over isotonic because
    # with ~27 held-out sessions isotonic overfits the steps.
    platt = LogisticRegression(max_iter=2000)
    platt.fit(model.predict_proba(X[ca])[:, 1].reshape(-1, 1), y[ca])
    p = platt.predict_proba(raw_test.reshape(-1, 1))[:, 1]

    # The baseline that must be beaten: shorter is better, nothing else.
    base = -X[te][:, 0]
    base_auc = auc(y[te], base)

    print(f"\nAUC on held-out sessions")
    print(f"  length alone (the dumb baseline) : {base_auc:.3f}")
    print(f"  the predictor                    : {model_auc:.3f}")
    print(f"  (0.50 = coin flip, 1.00 = perfect)")
    gain = model_auc - base_auc
    print(f"  gain over baseline               : {gain:+.3f}"
          f"   {'WORTH IT' if gain > 0.03 else 'NOT WORTH IT — use length'}")

    print("\nwhat it learned (positive = more likely accepted)")
    for name, w in sorted(zip(names, model.coef_[0]), key=lambda kv: -abs(kv[1]))[:8]:
        print(f"  {name:<22}{w:+.2f}")

    # Calibration: when it says 30%, is it right 30% of the time?
    def ece(scores):
        """Expected calibration error — average gap between promise and truth."""
        total, err = 0, 0.0
        for lo, hi in zip(EDGES, EDGES[1:]):
            m = (scores >= lo) & (scores < hi)
            if m.sum() == 0:
                continue
            err += m.sum() * abs(scores[m].mean() - y[te][m].mean())
            total += m.sum()
        return err / max(1, total)

    print(f"\ncalibration error (lower is better)")
    print(f"  before (raw scores)  : {ece(raw_test):.3f}")
    print(f"  after  (Platt-fitted): {ece(p):.3f}")

    print("\nwhen it predicts X, how often was it right?")
    print(f"  {'predicted':<16}{'n':>7}{'promised':>10}{'actual':>9}")
    for lo, hi in zip(EDGES, EDGES[1:]):
        m = (p >= lo) & (p < hi)
        if m.sum() < 25:
            continue
        print(f"  {lo:.2f}-{hi:.2f}      {m.sum():>7,}"
              f"{100*p[m].mean():>9.1f}%{100*y[te][m].mean():>8.1f}%")

    json.dump({"auc": float(model_auc), "baseline_auc": float(base_auc),
               "ece_raw": float(ece(raw_test)), "ece_calibrated": float(ece(p)),
               "n_train": len(tr), "n_calib": len(ca), "n_test": len(te),
               "features": names, "weights": model.coef_[0].tolist(),
               "intercept": float(model.intercept_[0])},
              open(OUT, "w"), indent=1)
    print(f"\nsaved: {OUT}")


if __name__ == "__main__":
    main()
