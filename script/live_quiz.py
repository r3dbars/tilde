#!/usr/bin/env python3
"""The LIVE paper: an exam built from the owner's actual recent typing across
ALL apps (not just iMessage). Questions = moments the owner typed their own
words over a ghost (human-authored truth). Train/test hygiene: rows whose
timestamp hashes into the exam slice (md5(ts)%5==0) are NEVER trained on —
nightly_retrain.fresh_capture excludes them.

Also the FLAG paper: every flagged ghost becomes a trap — the model must not
re-offer it in that context.

Scores: word-1 exact, similar-phrase (MiniLM cos>=0.5 on first 12 words),
meaning (mean cosine)."""
import json, os, glob, socket, hashlib, datetime

USAGE = os.path.expanduser("~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage")
SOCK = os.path.expanduser("~/Library/Application Support/SteadyType/ghost.sock")
EXAM_CACHE = os.path.expanduser("~/.cache/steadytype-eval/nightly/live_exam.jsonl")

def in_exam_slice(ts):
    return int(hashlib.md5(ts.encode()).hexdigest(), 16) % 5 == 0

def _events(kind):
    for f in glob.glob(USAGE + "/ghost_events_*.jsonl"):
        for line in open(f, errors="ignore"):
            try: e = json.loads(line)
            except Exception: continue
            if e.get("event") == kind: yield e

def build_exam(days=14, limit=250):
    """Balanced paper from the exam slice, all apps: half FRONTIER (moments
    the model failed — typed_instead; can we do better now?) and half
    HOLD-THE-LINE (whole-phrase accepts — do we still nail what worked?)."""
    cutoff = (datetime.datetime.utcnow() - datetime.timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%S")
    frontier, hold = [], []
    for kind, bucket, field in (("typed_instead", frontier, "typed"), ("accept_all", hold, "accepted")):
        for e in _events(kind):
            ts = e.get("ts", "")
            if ts < cutoff or not in_exam_slice(ts): continue
            truth = (e.get(field) or "").strip()
            ctx = (e.get("context") or "")
            if len(truth.split()) < 3 or len(ctx.strip()) < 8: continue
            bucket.append({"ts": ts, "app": e.get("app_bundle",""), "context": ctx[-400:],
                           "truth": truth, "kind": kind})
    for b in (frontier, hold): b.sort(key=lambda c: c["ts"], reverse=True)
    half = limit // 2
    cases = frontier[:max(half, limit - len(hold))] + hold[:half]
    with open(EXAM_CACHE, "w") as f:
        for c in cases: f.write(json.dumps(c) + "\n")
    return cases

def build_traps(limit=100):
    traps = []
    for e in _events("flagged"):
        ghost = (e.get("ghost") or "").strip()
        ctx = (e.get("context") or "")
        if not ghost or len(ctx.strip()) < 4: continue
        traps.append({"ts": e.get("ts",""), "context": ctx[-400:], "bad_ghost": ghost})
    return traps[-limit:]

def ask(context, field):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(10)
    s.connect(SOCK)
    s.sendall((json.dumps({"context": context, "app": "live-quiz", "field": field}) + "\n").encode())
    buf = b""
    try:
        while True:
            c = s.recv(4096)
            if not c: break
            buf += c
    except socket.timeout: pass
    s.close()
    final = ""
    for line in buf.decode(errors="ignore").splitlines():
        try:
            o = json.loads(line)
            if not o.get("partial"): final = o.get("suggestion","")
        except Exception: pass
    return final.strip()

def run_paper(label, cases=None):
    """Returns {word1, similar, meaning, spoke, n} for the currently-running app."""
    from sentence_transformers import SentenceTransformer
    import torch
    m = SentenceTransformer("all-MiniLM-L6-v2")
    cases = cases if cases is not None else build_exam()
    if not cases: return None
    sugg, truths, word1 = [], [], 0
    spoke = 0
    for i, c in enumerate(cases):
        out = ask(c["context"], f"lq{i}")
        if out:
            spoke += 1
            if out.split() and c["truth"].split() and out.split()[0].lower().strip(".,!?") == c["truth"].split()[0].lower().strip(".,!?"):
                word1 += 1
            sugg.append(out); truths.append(" ".join(c["truth"].split()[:12]))
    similar = 0; meaning = 0.0
    if sugg:
        G = m.encode(truths, convert_to_tensor=True); S = m.encode(sugg, convert_to_tensor=True)
        sims = torch.nn.functional.cosine_similarity(G, S).tolist()
        similar = sum(1 for x in sims if x >= 0.5)
        meaning = sum(sims) / len(sims)
    n = len(cases)
    return {"label": label, "n": n, "word1": word1/n, "similar": similar/n,
            "meaning": round(meaning, 3), "spoke": spoke/n}

def run_traps(label, traps=None):
    """Fraction of flagged ghosts the model re-offers in their context (lower=better)."""
    traps = traps if traps is not None else build_traps()
    if not traps: return {"label": label, "n": 0, "reoffend": 0.0}
    re = 0
    for i, t in enumerate(traps):
        out = ask(t["context"], f"tr{i}")
        bad = " ".join(t["bad_ghost"].lower().split()[:3])
        if bad and bad in out.lower(): re += 1
    return {"label": label, "n": len(traps), "reoffend": re/len(traps)}

if __name__ == "__main__":
    cases = build_exam()
    traps = build_traps()
    print(f"exam: {len(cases)} live questions | traps: {len(traps)} flagged moments")
    r = run_paper("current_champion", cases)
    print("LIVE PAPER:", r)
    print("FLAG PAPER:", run_traps("current_champion", traps))
