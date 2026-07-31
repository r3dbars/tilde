#!/usr/bin/env python3
"""Best-of-5 by the model's own confidence — the simplest possible version.

For each frozen exam question: generate 5 candidates (1 at the production
temperature, 4 warmer for diversity), score each by its own length-normalised
mean log-probability, keep the winner. No new models, no training — the
picker is arithmetic the server already returns.

Three arms, same questions:
  one_shot   candidate #1 alone (today's behaviour)
  best_of_5  picked by own confidence (the proposal)
  oracle_5   picked by peeking at the answer key (the ceiling — tells us
             whether failures are in GENERATING candidates or PICKING them)

Env: BQ_N (questions, default 1500), BQ_K (candidates, default 5).
"""
import json
import os
import sys
import time
import urllib.request

import numpy as np

EVAL = os.path.expanduser("~/.cache/steadytype-eval")
MM = os.path.join(EVAL, "matchmaker")
sys.path.insert(0, EVAL)
sys.path.insert(0, MM)
os.environ.setdefault("AB_FLOOR", "loose")

import ab_quiz                                    # noqa: E402  (harness reuse)
from general_quiz import score_dump               # noqa: E402  (scorer of record)

N_Q = int(os.environ.get("BQ_N", "1500"))
K = int(os.environ.get("BQ_K", "5"))
PORT = ab_quiz.PORT
SAMPLE_TEMP = 0.8
SEED0 = 20260730
RESULTS = os.path.join(MM, "bestof_results.json")


def complete_with_logprobs(prompt, temperature, seed):
    body = json.dumps({
        "prompt": prompt, "n_predict": ab_quiz.N_PREDICT,
        "temperature": temperature, "seed": seed,
        "cache_prompt": True, "n_probs": 1,
    }).encode()
    req = urllib.request.Request(
        f"http://127.0.0.1:{PORT}/completion", data=body,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        d = json.loads(r.read())
    content = d.get("content", "")
    probs = d.get("completion_probabilities") or []
    lps = [t.get("logprob") for t in probs if t.get("logprob") is not None]
    return content, lps


def phrase_confidence(raw, lps):
    """Length-normalised mean log-prob over the tokens that survive cleanup.

    The suggestion is cut at the first newline before display; scoring tokens
    the user never sees would let trailing junk drag a good phrase down.
    """
    visible = raw.split("\n", 1)[0]
    if not lps or not visible.strip():
        return float("-inf")
    # count generated tokens that belong to the visible span (approximate by
    # accumulating token text lengths — llama tokens concatenate to content)
    n = 0
    consumed = 0
    for lp_len in lps:
        n += 1
        consumed += 1
        if consumed >= len(visible.split()):
            break
    keep = lps[:max(1, n)]
    return sum(keep) / len(keep)


def main():
    t0 = time.time()
    model, vecs, train = None, None, None      # matchmaker OFF — clean arm

    cases = ab_quiz.load_texting_paper()[:N_Q]
    base_scaffold = open(ab_quiz.SCAFFOLD_BASE, encoding="utf-8").read()
    print(f"questions: {len(cases)}   candidates per question: {K}")

    server = ab_quiz.Server()
    server.start()
    print(f"private llama-server on {PORT} (champion, n_probs on)")

    one, best, oracle = [], [], []
    from sentence_transformers import SentenceTransformer
    import torch
    st = SentenceTransformer("all-MiniLM-L6-v2")

    try:
        for i, c in enumerate(cases):
            prompt = ab_quiz.build_prompt(base_scaffold, c["context"], c["page"])
            cands = []
            for k in range(K):
                temp = ab_quiz.TEMP if k == 0 else SAMPLE_TEMP
                raw, lps = complete_with_logprobs(prompt, temp, SEED0 + k)
                sugg = ab_quiz.normalize_continuation(raw)
                conf = phrase_confidence(raw, lps)
                cands.append((sugg, conf))

            one.append({"suggestion": cands[0][0], "golden": c["golden"]})
            pick = max(cands, key=lambda x: x[1])[0]
            best.append({"suggestion": pick, "golden": c["golden"]})

            # oracle: embed once per question, pick candidate closest to truth
            texts = [s for s, _ in cands]
            G = st.encode([" ".join(c["golden"].split()[:12])],
                          convert_to_tensor=True)
            S = st.encode(texts, convert_to_tensor=True)
            sims = torch.nn.functional.cosine_similarity(
                G.repeat(len(texts), 1), S).tolist()
            oracle.append({"suggestion": texts[int(np.argmax(sims))],
                           "golden": c["golden"]})

            if (i + 1) % 100 == 0:
                print(f"  {i+1}/{len(cases)}  ({time.time()-t0:.0f}s)", flush=True)
    finally:
        server.stop()

    results = {}
    for label, rows_ in (("one_shot", one), ("best_of_5", best),
                         ("oracle_5", oracle)):
        path = os.path.join(MM, f"dump_bestof_{label}.jsonl")
        with open(path, "w") as f:
            for r in rows_:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        results[label] = score_dump(path)
        print(f"{label}: {results[label]}")

    json.dump(results, open(RESULTS, "w"), indent=1)
    print(f"\nRAW NUMBERS   (n={len(cases)})")
    print(f"{'arm':<12}{'word1':>8}{'first2':>8}{'similar*':>9}{'meaning':>9}{'spoke':>7}")
    for label in ("one_shot", "best_of_5", "oracle_5"):
        s = results[label]
        print(f"{label:<12}{s['word1']:>8.3f}{s['word12']:>8.3f}"
              f"{s['similar']:>9.3f}{s['meaning']:>9.3f}{s['spoke']:>7.3f}")
    print(f"\ntotal {time.time()-t0:.0f}s   results: {RESULTS}")


if __name__ == "__main__":
    main()
