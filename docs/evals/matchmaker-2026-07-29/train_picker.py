#!/usr/bin/env python3
"""Train the picker: learn to spot the candidate closest to what the owner
actually said — without ever seeing the answer at pick time.

Target: each training candidate's cosine-to-truth (the oracle's own measure).
The picker regresses that from features available at runtime, then picking =
argmax over the 5 candidates. Evaluated ONLY on the frozen exam's candidate
sets, scored by the exam scorer of record.

The bar it must clear (from the best-of-5 experiment):
  one-shot 8.2  ·  own-confidence picker 8.4 (the wash)  ·  oracle 15.2
"""
import json
import os
import sys

import numpy as np

EVAL = os.path.expanduser("~/.cache/steadytype-eval")
MM = os.path.join(EVAL, "matchmaker")
sys.path.insert(0, EVAL)
from general_quiz import score_dump               # noqa: E402

from sentence_transformers import SentenceTransformer   # noqa: E402
import torch                                            # noqa: E402

ST = SentenceTransformer("all-MiniLM-L6-v2")


def rows(path):
    for line in open(path, errors="ignore"):
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(r, dict):
            yield r


def embed(texts):
    return ST.encode(texts, batch_size=256, convert_to_tensor=True,
                     normalize_embeddings=True)


def features(case, cand, e_page, e_ctx, e_cand):
    """Runtime-available signals only. e_* are normalised embeddings."""
    text = cand["text"]
    words = text.split()
    n = len(words)
    ctx_words = set(w.lower().strip(".,!?") for w in case["context"].split())
    page_words = set(w.lower().strip(".,!?") for w in case["page"].split()[-40:])
    toks = [w.lower().strip(".,!?") for w in words]
    return [
        float(torch.dot(e_cand, e_page)) if e_page is not None else 0.0,
        float(torch.dot(e_cand, e_ctx)),
        cand.get("logprob_mean") if cand.get("logprob_mean") is not None else -3.0,
        float(n),
        1.0 if text and text[0].islower() else 0.0,
        (sum(1 for t in toks if t in page_words) / n) if n else 0.0,
        (sum(1 for t in toks if t in ctx_words) / n) if n else 0.0,
        1.0 if text.rstrip().endswith((".", "!", "?")) else 0.0,
        sum(1 for w in words if len(w) == 1 and w.lower() not in ("a", "i")),
    ]


FEATURE_NAMES = ["sim_to_page", "sim_to_context", "own_logprob", "n_words",
                 "lowercase_start", "page_overlap", "ctx_overlap",
                 "ends_sentence", "frag_tokens"]


def build_xy(path, with_target):
    X, y, meta = [], [], []
    for case in rows(path):
        cands = case.get("candidates") or []
        texts = [c["text"] for c in cands]
        if not texts:
            continue
        e_cands = embed(texts)
        e_ctx = embed([case["context"]])[0]
        e_page = embed([case["page"]])[0] if case.get("page") else None
        if with_target:
            e_truth = embed([" ".join(case["golden"].split()[:12])])[0]
        for j, cand in enumerate(cands):
            X.append(features(case, cand, e_page, e_ctx, e_cands[j]))
            if with_target:
                y.append(float(torch.dot(e_cands[j], e_truth)))
        meta.append((case, len(cands)))
    return np.array(X, dtype=float), np.array(y, dtype=float), meta


def main():
    print("featurising training candidates…")
    Xtr, ytr, _ = build_xy(os.path.join(MM, "picker_train.jsonl"), True)
    print(f"  train candidates: {len(Xtr):,}")

    from sklearn.ensemble import HistGradientBoostingRegressor
    picker = HistGradientBoostingRegressor(max_iter=300, learning_rate=0.08,
                                           validation_fraction=0.1,
                                           early_stopping=True, random_state=0)
    picker.fit(Xtr, ytr)
    print(f"  fit done (iters used: {picker.n_iter_})")

    print("featurising exam candidates…")
    Xte, _, meta = build_xy(os.path.join(MM, "picker_exam.jsonl"), False)

    # pick per question
    picked, one_shot = [], []
    i = 0
    scores = picker.predict(Xte)
    for case, k in meta:
        s = scores[i:i + k]
        texts = [c["text"] for c in case["candidates"]]
        picked.append({"suggestion": texts[int(np.argmax(s))],
                       "golden": case["golden"]})
        one_shot.append({"suggestion": texts[0], "golden": case["golden"]})
        i += k

    results = {}
    for label, rows_ in (("one_shot", one_shot), ("picker", picked)):
        p = os.path.join(MM, f"dump_picker_{label}.jsonl")
        with open(p, "w") as f:
            for r in rows_:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        results[label] = score_dump(p)

    # oracle on the SAME candidate sets, for the honest ceiling
    oracle = []
    for case, _ in meta:
        texts = [c["text"] for c in case["candidates"]]
        e_truth = embed([" ".join(case["golden"].split()[:12])])[0]
        e_c = embed(texts)
        sims = [float(torch.dot(e, e_truth)) for e in e_c]
        oracle.append({"suggestion": texts[int(np.argmax(sims))],
                       "golden": case["golden"]})
    p = os.path.join(MM, "dump_picker_oracle.jsonl")
    with open(p, "w") as f:
        for r in oracle:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    results["oracle"] = score_dump(p)

    json.dump(results, open(os.path.join(MM, "picker_results.json"), "w"),
              indent=1)
    print(f"\nRAW NUMBERS   (n={len(meta)})")
    print(f"{'arm':<12}{'word1':>8}{'first2':>8}{'similar*':>9}{'meaning':>9}")
    for label in ("one_shot", "picker", "oracle"):
        s = results[label]
        print(f"{label:<12}{s['word1']:>8.3f}{s['word12']:>8.3f}"
              f"{s['similar']:>9.3f}{s['meaning']:>9.3f}")

    gap = results["oracle"]["similar"] - results["one_shot"]["similar"]
    got = results["picker"]["similar"] - results["one_shot"]["similar"]
    if gap > 0:
        print(f"\npicker collected {100*got/gap:.0f}% of the oracle gap")
    imp = sorted(zip(FEATURE_NAMES,
                     getattr(picker, "feature_importances_", [0]*len(FEATURE_NAMES))),
                 key=lambda kv: -kv[1]) if hasattr(picker, "feature_importances_") else []
    for name, w in imp[:5]:
        print(f"  {name:<16}{w:.3f}")


if __name__ == "__main__":
    main()
