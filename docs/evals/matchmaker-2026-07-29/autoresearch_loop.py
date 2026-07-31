#!/usr/bin/env python3
"""AutoResearch loop for Tilde — the Karpathy pattern pointed at similar★.

Precedent: the owner's diarization loop (147 iterations overnight, DER
34.1%→19.2%). Same shape here: mutate ONE variable, examine on the frozen
exam, keep the change only if the objective improves without breaking the
guard, journal every trial, repeat until told to stop.

Objective : similar★ on a fixed 500-question slice of the frozen texting exam
Guard     : word-1 must stay within 2.0 points of the best config's word-1
Accept    : similar★ must beat the incumbent by ≥ 0.8 points (above the
            ~±0.7 one-sigma noise at n=500, measured); smaller wins are
            noise-chasing and are logged but not kept
Confirm   : the final best config gets a full-1500 confirmation run

Search space (one mutation per iteration, chosen at random):
  scaffold   ∈ chat_size1 / size6 / size10 / size14 / short / medium
  temperature∈ 0.0 / 0.1 / 0.3
  n_predict  ∈ 12 / 16 / 20
  retrieval  ∈ off / k2 / k3 / k5      (loose matchmaker index)

Controls:
  touch STOP in this directory → loop finishes the current trial and exits
  AR_MAX_ITERS / AR_MAX_HOURS env caps (default 400 / 10)

Every trial is appended to autoresearch_journal.jsonl — config, scores,
verdict, wall time — so the run is a citable experiment log, not an anecdote.
"""
import json
import os
import random
import sys
import time

import numpy as np

EVAL = os.path.expanduser("~/.cache/steadytype-eval")
MM = os.path.join(EVAL, "matchmaker")
sys.path.insert(0, EVAL)
sys.path.insert(0, MM)
os.environ.setdefault("AB_FLOOR", "loose")
os.environ.setdefault("AB_N_TEXTING", "1500")

import ab_quiz                                    # noqa: E402
from general_quiz import score_dump               # noqa: E402

JOURNAL = os.path.join(MM, "autoresearch_journal.jsonl")
STOP = os.path.join(MM, "STOP")
N_TRIAL = 500                                     # questions per trial
MIN_WIN = 0.008                                   # +0.8 pts similar★ to accept
WORD1_GUARD = 0.020                               # stay within 2 pts of best
MAX_ITERS = int(os.environ.get("AR_MAX_ITERS", "400"))
MAX_HOURS = float(os.environ.get("AR_MAX_HOURS", "10"))

SPACE = {
    "scaffold": ["chat_size1.txt", "chat_size6.txt", "chat_size10.txt",
                 "chat_size14.txt", "chat_short.txt", "chat_medium.txt"],
    "temperature": [0.0, 0.1, 0.3],
    "n_predict": [12, 16, 20],
    "retrieval_k": [0, 2, 3, 5],
}
START = {"scaffold": "chat_size6.txt", "temperature": 0.1,
         "n_predict": 16, "retrieval_k": 0}       # today's production recipe


def jlog(entry):
    entry["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(JOURNAL, "a") as f:
        f.write(json.dumps(entry) + "\n")
    print(json.dumps(entry), flush=True)


def load_retrieval():
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer("all-MiniLM-L6-v2")
    meta = [json.loads(l) for l in open(os.path.join(MM, "index_v2_loose.meta.jsonl"))]
    vecs = np.nan_to_num(np.load(os.path.join(MM, "index_v2_loose.npz"))["vectors"])
    return model, vecs, meta


def evaluate(server, cases, cfg, retr):
    scaffold = open(os.path.join(EVAL, "scaffolds", cfg["scaffold"]),
                    encoding="utf-8").read()
    model, vecs, meta = retr
    dump = os.path.join(MM, "ar_trial.jsonl")
    with open(dump, "w") as f:
        for c in cases:
            if cfg["retrieval_k"] > 0:
                pre = ab_quiz.retrieve(model, vecs, meta, c["query"],
                                       k=cfg["retrieval_k"])
                scaf = ab_quiz.with_scaffold(pre)
            else:
                scaf = scaffold
            prompt = ab_quiz.build_prompt(scaf, c["context"], c["page"])
            body = json.dumps({"prompt": prompt, "n_predict": cfg["n_predict"],
                               "temperature": cfg["temperature"],
                               "seed": 20260731, "cache_prompt": True}).encode()
            import urllib.request
            req = urllib.request.Request(
                f"http://127.0.0.1:{ab_quiz.PORT}/completion", data=body,
                headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=120) as r:
                raw = json.loads(r.read()).get("content", "")
            sugg = ab_quiz.normalize_continuation(raw)
            f.write(json.dumps({"suggestion": sugg, "golden": c["golden"]},
                               ensure_ascii=False) + "\n")
    return score_dump(dump)


def main():
    t0 = time.time()
    cases = ab_quiz.load_texting_paper()[:N_TRIAL]
    retr = load_retrieval()
    server = ab_quiz.Server()
    server.start()
    jlog({"event": "start", "n_trial": len(cases), "space": SPACE,
          "start_config": START, "min_win": MIN_WIN, "guard": WORD1_GUARD})

    best_cfg = dict(START)
    try:
        best = evaluate(server, cases, best_cfg, retr)
        jlog({"event": "baseline", "config": best_cfg,
              "similar": best["similar"], "word1": best["word1"]})

        for it in range(1, MAX_ITERS + 1):
            if os.path.exists(STOP):
                jlog({"event": "stopped_by_owner", "iter": it})
                break
            if (time.time() - t0) / 3600 > MAX_HOURS:
                jlog({"event": "time_budget_reached", "iter": it})
                break

            knob = random.choice(list(SPACE))
            options = [v for v in SPACE[knob] if v != best_cfg[knob]]
            cand_cfg = dict(best_cfg)
            cand_cfg[knob] = random.choice(options)

            t1 = time.time()
            cand = evaluate(server, cases, cand_cfg, retr)
            verdict = "reject"
            if (cand["similar"] >= best["similar"] + MIN_WIN
                    and cand["word1"] >= best["word1"] - WORD1_GUARD):
                best, best_cfg, verdict = cand, cand_cfg, "ACCEPT"
            jlog({"event": "trial", "iter": it, "mutated": knob,
                  "config": cand_cfg, "similar": cand["similar"],
                  "word1": cand["word1"], "verdict": verdict,
                  "best_similar": best["similar"], "secs": round(time.time()-t1)})

        # confirmation: full exam on the winner
        full = ab_quiz.load_texting_paper()
        confirm = evaluate(server, full, best_cfg, retr)
        jlog({"event": "confirm_full_1500", "config": best_cfg,
              "similar": confirm["similar"], "word1": confirm["word1"],
              "meaning": confirm["meaning"]})
    finally:
        server.stop()
        jlog({"event": "done", "hours": round((time.time()-t0)/3600, 2),
              "best_config": best_cfg, "best_similar_n500": best["similar"]})


if __name__ == "__main__":
    main()
