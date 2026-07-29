#!/usr/bin/env python3
"""Matchmaker Sitting 2: offline A/B — the model WITH retrieved precedents in
the scaffold slot vs WITHOUT (current production scaffold), on the two
personal papers:

  LIVE paper   : the frozen nightly live_exam.jsonl (exam-slice moments)
  TEXTING paper: first 500 valid questions of the frozen imessage_test.jsonl,
                 built exactly like the nightly quiz (prefix-words 2,
                 min-prior 1, prior-messages as the page)

Both arms are identical in every way except the scaffold slot:
  WITHOUT = scaffolds/chat_size6.txt (the eval scaffold of record)
  WITH    = same header + top-3 retrieved precedents from the frozen
            matchmaker index, formatted as Text/Continuation pairs

Model: the live champion personal.gguf, served on a PRIVATE llama-server
(port 17999) with the app's own flags. The running app on 17872 is never
touched; port 8800 is never touched.

Scoring: general_quiz.score_dump verbatim (word1 / word12 / word123 /
similar★ / meaning / spoke). Raw numbers to stdout + ab_results.json.
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

import numpy as np

EVAL = os.path.expanduser("~/.cache/steadytype-eval")
MM = os.path.join(EVAL, "matchmaker")
WORK = os.path.join(EVAL, "curve_run")
sys.path.insert(0, EVAL)
sys.path.insert(0, os.path.join(MM))

from general_quiz import score_dump          # scorer of record, unmodified

MODEL = os.path.expanduser(
    "~/Library/Application Support/SteadyType/Models/personal.gguf")
SCAFFOLD_BASE = os.path.join(EVAL, "scaffolds", "chat_size6.txt")
LIVE_EXAM = os.path.join(EVAL, "nightly", "live_exam.jsonl")
TEXT_EXAM = os.path.join(WORK, "imessage_test.jsonl")
FLOOR = os.environ.get("AB_FLOOR", "strict")   # strict | loose
SUFFIX = "" if FLOOR == "strict" else "_loose"
INDEX_NPZ = os.path.join(MM, f"index_v2{SUFFIX}.npz")
INDEX_META = os.path.join(MM, f"index_v2{SUFFIX}.meta.jsonl")
RESULTS = os.path.join(MM, os.environ.get("AB_RESULTS", f"ab_results{SUFFIX}.json"))

PORT = 17999                       # private server; 17872 is the app, 8800 forbidden
N_TEXTING = int(os.environ.get("AB_N_TEXTING", "500"))
PAPERS = os.environ.get("AB_PAPERS", "live,texting").split(",")
ARMS = os.environ.get("AB_ARMS", "without,with").split(",")
EXEMPLARS = os.environ.get("AB_EXEMPLARS", "retrieved")   # retrieved | random
GENERAL_REGISTERS = ["aeslc", "enron_thread", "ubuntu", "dailydialog",
                     "discord", "reddit", "blog", "diverse"]
N_GENERAL_PER_REG = int(os.environ.get("AB_N_GENERAL", "1000"))
TOP_K = 3
TEMP = 0.1                         # eval recipe of record (curve_run.launch)
N_PREDICT = 16
SEED = 20260728

NEVER_END_ON = {
    "a", "an", "the", "of", "on", "in", "to", "at", "by", "as", "if",
    "and", "or", "but", "with", "for", "from", "that", "than", "so",
    "my", "your", "our", "their", "his", "her", "its", "is", "are",
    "was", "be", "been", "will", "would", "can", "could", "should",
    "very", "more", "most", "quite", "really",
}


def repair_dangling_tail(text: str) -> str:
    """Port of RawContinuationPrompt.repairDanglingTail."""
    trimmed = text.strip()
    if not trimmed or not (trimmed[-1].isalpha() or trimmed[-1].isdigit()):
        return text
    words = trimmed.split(" ")
    while words and words[-1].lower().strip(".,!?;:\"'()[]{}") in NEVER_END_ON:
        words.pop()
    if not words:
        return text
    lead = " " if text.startswith(" ") else ""
    return lead + " ".join(words)


def normalize_continuation(raw: str) -> str:
    """Port of normalizedContinuation for a context that ends in a space."""
    text = raw.split("\n", 1)[0]
    text = text.lstrip(" ")          # context ended in whitespace
    return repair_dangling_tail(text).strip()


# ---------------------------------------------------------------- server
class Server:
    def __init__(self):
        self.proc = None

    def start(self):
        if subprocess.run(["lsof", "-nP", f"-iTCP:{PORT}", "-sTCP:LISTEN"],
                          capture_output=True).returncode == 0:
            raise RuntimeError(f"port {PORT} already in use — refusing")
        self.proc = subprocess.Popen(
            ["/opt/homebrew/bin/llama-server", "-m", MODEL,
             "--host", "127.0.0.1", "--port", str(PORT),
             "-c", "4096", "--swa-full", "--cache-reuse", "256"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(120):
            try:
                with urllib.request.urlopen(
                        f"http://127.0.0.1:{PORT}/health", timeout=2) as r:
                    if b"ok" in r.read():
                        return
            except Exception:
                time.sleep(1)
        raise RuntimeError("private llama-server never became healthy")

    def stop(self):
        # only ever our own child — no pkill patterns that could catch 17872
        if self.proc:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.proc.kill()

    def complete(self, prompt: str) -> str:
        body = json.dumps({
            "prompt": prompt, "n_predict": N_PREDICT,
            "temperature": TEMP, "seed": SEED,
            "cache_prompt": True,
        }).encode()
        req = urllib.request.Request(
            f"http://127.0.0.1:{PORT}/completion", data=body,
            headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read()).get("content", "")


# ---------------------------------------------------------------- index v2
def norm_ws(t):
    return re.sub(r"\s+", " ", (t or "").lower()).strip()


FRAG_OK = {"a", "i", "ok", "no", "me", "it", "is", "to", "go", "on", "in",
           "at", "up", "we", "he", "us", "my", "be", "so", "do", "oh", "hi"}


def strip_frag_tail(cont: str) -> str:
    """Drop trailing 1-char junk tokens (mid-word capture artifacts)."""
    words = cont.split()
    while words and len(words[-1]) == 1 and words[-1].lower() not in FRAG_OK:
        words.pop()
    return " ".join(words)


def clean_cont(cont: str) -> bool:
    """strict: ≥3 words, no fragment tokens anywhere (customer-cold-start
    pessimism). loose: any real continuation of ≥1 word with ≥2 chars after
    stripping fragment tails — keeps short-burst replies, which is most of
    the capture."""
    if FLOOR == "loose":
        c = strip_frag_tail(cont)
        return bool(c) and any(len(w) >= 2 for w in c.split())
    words = cont.split()
    if len(words) < 3:
        return False
    shorts = [w for w in words if len(w) == 1 and w.lower() not in FRAG_OK]
    return not shorts


def build_index_v2():
    """Rebuild pairs (ctx/cont stored separately) with the quality floor,
    exchange collapse, exam-slice exclusion. Frozen for this A/B."""
    sys.path.insert(0, MM)
    import build_index as b1

    events = b1.load_jsonl(os.path.join(b1.USAGE, "ghost_events_*.jsonl"))
    samples = b1.load_jsonl(os.path.join(b1.USAGE, "brain_samples_*.jsonl"))

    # rebuild raw pairs but keep ctx/cont split
    raw = []
    events_s = sorted(events, key=lambda r: r.get("ts", ""))
    samples_s = sorted(samples, key=lambda r: r.get("ts", ""))
    sample_ts = [s.get("ts", "") for s in samples_s]
    lo = 0
    for e in events_s:
        if e.get("event") not in b1.REPLY_EVENTS:
            continue
        ctx = (e.get("context") or "").strip()
        if e.get("event") == "typed_instead":
            cont = (e.get("typed") or "").strip()
        else:
            cont = (e.get("accepted") or e.get("ghost") or "").strip()
        if not cont or not clean_cont(cont):
            continue
        if FLOOR == "loose":
            cont = strip_frag_tail(cont)
        ets = e.get("ts", "")
        while lo < len(sample_ts) and sample_ts[lo] <= ets:
            lo += 1
        screen = ""
        ghost = e.get("ghost") or ""
        for s in reversed(samples_s[max(0, lo - 400):lo]):
            if s.get("app_bundle") != e.get("app_bundle"):
                continue
            sugg = (s.get("suggestion") or "")[:20]
            if sugg and sugg in ghost:
                screen = (s.get("screen") or "").strip()
                break
        incoming = screen if len(screen) >= b1.MIN_INCOMING_CHARS else ctx
        if len(incoming) < b1.MIN_INCOMING_CHARS:
            continue
        raw.append({"ts": ets, "app": e.get("app_bundle", ""),
                    "event": e.get("event"), "incoming": incoming[:600],
                    "ctx": ctx[-200:], "cont": cont[:200],
                    "reply": (ctx + " " + cont).strip()[:400],
                    "had_screen": bool(screen)})

    pairs = b1.collapse(raw)
    train = [p for p in pairs if not b1.is_exam(p["ts"])]

    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer("all-MiniLM-L6-v2")
    vecs = model.encode([p["incoming"] for p in train], batch_size=128,
                        convert_to_numpy=True, normalize_embeddings=True,
                        show_progress_bar=False).astype(np.float32)
    vecs = np.nan_to_num(vecs)
    np.savez_compressed(INDEX_NPZ, vectors=vecs)
    with open(INDEX_META, "w", encoding="utf-8") as f:
        for p in train:
            f.write(json.dumps(p, ensure_ascii=False) + "\n")
    print(f"index v2 (quality floor): {len(raw)} raw -> {len(pairs)} exchanges "
          f"-> {len(train)} indexed (exam slice excluded)")
    return model, vecs, train


# ---------------------------------------------------------------- retrieval
def retrieve(model, vecs, train, query, k=TOP_K):
    q = model.encode([query], convert_to_numpy=True,
                     normalize_embeddings=True).astype(np.float32)
    q = np.nan_to_num(q)
    scores = (q @ vecs.T)[0]
    out, seen = [], set()
    for j in np.argsort(-scores):
        cont_key = norm_ws(train[j]["cont"])[:80]
        if cont_key in seen:
            continue
        seen.add(cont_key)
        out.append((float(scores[j]), train[j]))
        if len(out) == k:
            break
    return out


HEADER = ("The following are real chat messages being written by their "
          "authors, continued naturally in the same casual voice.\n\n")


def with_scaffold(precedents):
    """The matchmaker scaffold: same header, retrieved precedents as the
    examples — each shown as its real ctx-tail/continuation split."""
    parts = [HEADER]
    for _, p in precedents:
        ctx_tail = p["ctx"][-90:].lstrip()
        cont = " ".join(p["cont"].split()[:14])
        if not ctx_tail or not cont:
            continue
        parts.append(f"Text: {ctx_tail}\nContinuation: {cont}\n\n")
    parts.append("\n")
    return "".join(parts)


def page_block(page):
    if not page:
        return ""
    bounded = page[:700].strip()
    if not bounded:
        return ""
    return ("Reference notes visible on the writer's screen (may be a message "
            "being replied to, a document being discussed, or unrelated windows "
            "— use names and topics from it when they fit; never copy or "
            "continue it):\n" + bounded + "\n\n\n")


def build_prompt(scaffold, context, page):
    return scaffold + page_block(page) + "Text: " + context.rstrip() + "\nContinuation:"


# ---------------------------------------------------------------- papers
def load_live_paper():
    cases = []
    for line in open(LIVE_EXAM, encoding="utf-8"):
        c = json.loads(line)
        cases.append({"context": c["context"], "golden": c["truth"],
                      "page": "", "query": c["context"][-200:]})
    return cases


def load_texting_paper():
    cases = []
    for line in open(TEXT_EXAM, encoding="utf-8"):
        e = json.loads(line)
        text = (e.get("text") or "").strip()
        priors = [p for p in (e.get("prior_messages") or []) if p and p.strip()]
        if not priors:
            continue                          # --min-prior 1
        words = text.split()
        if len(words) < 1 + 2:                # prefix 1..2 + golden >= 2
            continue
        cut = max(1, min(2, len(words) - 2))  # --prefix-words 2
        context = " ".join(words[:cut]) + " "
        golden = " ".join(words[cut:])
        page = "\n".join(priors[-3:])         # build_page(prior, turns=3)
        cases.append({"context": context, "golden": golden,
                      "page": page, "query": page[-300:]})
        if len(cases) == N_TEXTING:
            break
    return cases


def load_general_paper():
    """The product-floor exam: strangers' text across 8 registers, built like
    general_quiz (prefix-words 2, min-prior 0, priors as page)."""
    cases = []
    for reg in GENERAL_REGISTERS:
        path = os.path.join(EVAL, f"{reg}_eval.jsonl")
        if not os.path.exists(path):
            continue
        n = 0
        for line in open(path, encoding="utf-8", errors="replace"):
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            text = (e.get("text") or "").strip()
            words = text.split()
            if len(words) < 3:
                continue
            priors = [x for x in (e.get("prior_messages") or []) if x and x.strip()]
            cut = max(1, min(2, len(words) - 2))
            context = " ".join(words[:cut]) + " "
            golden = " ".join(words[cut:])
            page = "\n".join(priors[-3:])
            cases.append({"context": context, "golden": golden, "page": page,
                          "query": (page[-300:] if page else context), "reg": reg})
            n += 1
            if n == N_GENERAL_PER_REG:
                break
    return cases


def run_paper(server, model, vecs, train, cases, arm, base_scaffold, dump_path):
    stats = {"top1": [], "truth_hits": 0}
    with open(dump_path, "w", encoding="utf-8") as f:
        for i, c in enumerate(cases):
            if arm == "with":
                if EXEMPLARS == "random":
                    rng = __import__("random").Random(SEED + i)
                    pre = [(0.0, train[j]) for j in rng.sample(range(len(train)), TOP_K)]
                else:
                    pre = retrieve(model, vecs, train, c["query"])
                scaffold = with_scaffold(pre)
                if pre:
                    stats["top1"].append(pre[0][0])
                    if any(norm_ws(p["cont"]) == norm_ws(c["golden"])
                           for _, p in pre):
                        stats["truth_hits"] += 1
            else:
                scaffold = base_scaffold
            prompt = build_prompt(scaffold, c["context"], c["page"])
            raw = server.complete(prompt)
            sugg = normalize_continuation(raw)
            f.write(json.dumps({"suggestion": sugg, "golden": c["golden"]},
                               ensure_ascii=False) + "\n")
            if (i + 1) % 50 == 0:
                print(f"    {i+1}/{len(cases)}", flush=True)
    return stats


def main():
    t0 = time.time()
    print("=" * 70)
    print("MATCHMAKER SITTING 2 — offline A/B, WITH vs WITHOUT precedents")
    print("=" * 70)

    model, vecs, train = build_index_v2()
    base_scaffold = open(SCAFFOLD_BASE, encoding="utf-8").read()

    loaders = {"live": load_live_paper, "texting": load_texting_paper,
               "general": load_general_paper}
    papers = [(p, loaders[p]()) for p in PAPERS if p in loaders]
    print("papers: " + " | ".join(f"{p} n={len(c)}" for p, c in papers))

    server = Server()
    server.start()
    print(f"private llama-server up on {PORT} (champion personal.gguf, "
          f"temp {TEMP}, n_predict {N_PREDICT}, seed {SEED})")

    results = {}
    try:
        for paper, cases in papers:
            for arm in ARMS:
                dump = os.path.join(MM, f"dump_{paper}_{arm}{SUFFIX}.jsonl")
                print(f"  running {paper}/{arm} ({len(cases)} questions)...",
                      flush=True)
                t1 = time.time()
                stats = run_paper(server, model, vecs, train, cases, arm,
                                  base_scaffold, dump)
                s = score_dump(dump)
                s["seconds"] = round(time.time() - t1, 1)
                if arm == "with":
                    s["retrieval_top1_mean"] = (round(float(np.mean(stats["top1"])), 3)
                                                if stats["top1"] else None)
                    s["precedent_equals_truth"] = stats["truth_hits"]
                results[f"{paper}_{arm}"] = s
                if paper == "general":
                    rows = [json.loads(l) for l in open(dump)]
                    per = {}
                    for c, r in zip(cases, rows):
                        per.setdefault(c["reg"], []).append(r)
                    for reg, rr in per.items():
                        tmp = dump + f".{reg}"
                        with open(tmp, "w") as tf:
                            for r in rr:
                                tf.write(json.dumps(r) + "\n")
                        results[f"general_{reg}_{arm}"] = score_dump(tmp)
                print(f"  {paper}/{arm}: {s}", flush=True)
    finally:
        server.stop()

    json.dump(results, open(RESULTS, "w"), indent=1)
    print("\n" + "=" * 70)
    print("RAW NUMBERS")
    print("=" * 70)
    hdr = f"{'paper/arm':<18}{'n':>5}{'word1':>8}{'first2':>8}{'first3':>8}{'sim★':>7}{'meaning':>9}{'spoke':>7}"
    print(hdr)
    for key in [k for k in results if not k.startswith("general_") or k.count("_") == 1]:
        s = results[key]
        if s is None: continue
        print(f"{key:<18}{s['n']:>5}{s['word1']:>8.3f}{s['word12']:>8.3f}"
              f"{s['word123']:>8.3f}{s['similar']:>7.3f}{s['meaning']:>9.3f}"
              f"{s['spoke']:>7.3f}")
    print(f"\nresults saved: {RESULTS}")
    print(f"total {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
