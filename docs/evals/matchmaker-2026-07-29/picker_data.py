#!/usr/bin/env python3
"""Generate the picker's data: candidate sets with known truths.

Two outputs, strictly separated by the corpus's own frozen split (seeded
shuffle, SEED 20260724 — identical to curve_run.prep_data):

  picker_train.jsonl  candidates for TRAIN-POOL messages (model never quizzed
                      on these) with cosine-to-truth per candidate — the
                      picker learns to predict that score from features
  picker_exam.jsonl   candidates for the frozen exam questions — the picker
                      is only ever EVALUATED here

Env: PK_TRAIN_N (train messages, default 4000), PK_K (candidates, 5).
"""
import json
import os
import random
import sys
import time
import urllib.request

EVAL = os.path.expanduser("~/.cache/steadytype-eval")
MM = os.path.join(EVAL, "matchmaker")
sys.path.insert(0, EVAL)
sys.path.insert(0, MM)
os.environ.setdefault("AB_FLOOR", "loose")
import ab_quiz                                    # noqa: E402

SEED_SPLIT = 20260724                              # curve_run's frozen split
SEED_GEN = 20260730
K = int(os.environ.get("PK_K", "5"))
TRAIN_N = int(os.environ.get("PK_TRAIN_N", "4000"))
SAMPLE_TEMP = 0.8


def load_corpus():
    records = []
    for line in open(os.path.join(EVAL, "imessage_eval.jsonl")):
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        text = (e.get("text") or "").strip()
        if len(text.split()) < 3:
            continue
        priors = e.get("prior_messages") or []
        if isinstance(priors, str):
            try:
                priors = eval(priors, {"__builtins__": {}})   # noqa: S307 — mirrors curve_run
            except Exception:                                  # noqa: BLE001
                priors = [priors]
        records.append((priors, text))
    random.Random(SEED_SPLIT).shuffle(records)
    return records[1500:], records[:1500]          # train pool, frozen exam


def to_case(priors, text):
    words = text.split()
    cut = max(1, min(2, len(words) - 2))
    priors = [p for p in priors if p and p.strip()]
    return {
        "context": " ".join(words[:cut]) + " ",
        "golden": " ".join(words[cut:]),
        "page": "\n".join(priors[-3:]),
    }


def gen_candidates(server, scaffold, case):
    prompt = ab_quiz.build_prompt(scaffold, case["context"], case["page"])
    out = []
    for k in range(K):
        temp = ab_quiz.TEMP if k == 0 else SAMPLE_TEMP
        body = json.dumps({"prompt": prompt, "n_predict": ab_quiz.N_PREDICT,
                           "temperature": temp, "seed": SEED_GEN + k,
                           "cache_prompt": True, "n_probs": 1}).encode()
        req = urllib.request.Request(
            f"http://127.0.0.1:{ab_quiz.PORT}/completion", data=body,
            headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=120) as r:
            d = json.loads(r.read())
        raw = d.get("content", "")
        lps = [t.get("logprob") for t in (d.get("completion_probabilities") or [])
               if t.get("logprob") is not None]
        out.append({
            "text": ab_quiz.normalize_continuation(raw),
            "logprob_mean": (sum(lps) / len(lps)) if lps else None,
        })
    return out


def main():
    t0 = time.time()
    pool, _ = load_corpus()
    rng = random.Random(SEED_GEN)
    train_msgs = rng.sample(pool, min(TRAIN_N, len(pool)))
    exam_cases = ab_quiz.load_texting_paper()      # the frozen exam, verbatim

    scaffold = open(ab_quiz.SCAFFOLD_BASE, encoding="utf-8").read()
    server = ab_quiz.Server()
    server.start()
    print(f"server up · train msgs {len(train_msgs):,} · exam {len(exam_cases):,} · K={K}")

    try:
        with open(os.path.join(MM, "picker_train.jsonl"), "w") as f:
            for i, (priors, text) in enumerate(train_msgs):
                case = to_case(priors, text)
                cands = gen_candidates(server, scaffold, case)
                f.write(json.dumps({**case, "candidates": cands},
                                   ensure_ascii=False) + "\n")
                if (i + 1) % 250 == 0:
                    print(f"  train {i+1}/{len(train_msgs)} ({time.time()-t0:.0f}s)",
                          flush=True)

        with open(os.path.join(MM, "picker_exam.jsonl"), "w") as f:
            for i, case in enumerate(exam_cases):
                cands = gen_candidates(server, scaffold, case)
                f.write(json.dumps({**case, "candidates": cands},
                                   ensure_ascii=False) + "\n")
                if (i + 1) % 250 == 0:
                    print(f"  exam {i+1}/{len(exam_cases)} ({time.time()-t0:.0f}s)",
                          flush=True)
    finally:
        server.stop()
    print(f"done in {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
