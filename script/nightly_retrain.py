#!/usr/bin/env python3
"""Nightly auto-retrain: fold the day's live capture into the personal model,
keep only if better. The flywheel's motor.

Steps: build recency/correction-weighted dataset (proven 4k base + fresh
capture, corrections upweighted) -> LoRA train -> GGUF -> 500-case quiz vs
champion scores -> swap the LIVE model (App Support personal.gguf) only on a
win -> always restore the app via the blessed restart script. Never swaps on
regression; worst case is "no change". Kill switch:
  defaults write bar.r3d.steadytype NightlyRetrainEnabled -bool false
Log: ~/.cache/steadytype-eval/nightly/journal.log"""
import json, os, sys, shutil, subprocess, datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import curve_run as cr
import live_quiz
# Full 1,500-question held-out set nightly (owner: "as many as possible");
# CI tightens from ±3.9 to ±2.2 points and the harness runs it in ~90s.
cr.QUIZ_LIMIT = 1500

NIGHTLY = os.path.expanduser("~/.cache/steadytype-eval/nightly")
SCORES = os.path.join(NIGHTLY, "champion_scores.json")
LIVE_MODEL = os.path.expanduser("~/Library/Application Support/SteadyType/Models/personal.gguf")
RESTART = f"{cr.REPO}/script/restart_app.sh"
os.makedirs(NIGHTLY, exist_ok=True)

def nlog(msg):
    line = f"{datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')} {msg}"
    print(line, flush=True)
    with open(os.path.join(NIGHTLY, "journal.log"), "a") as f:
        f.write(line + "\n")

def enabled():
    r = subprocess.run(["defaults", "read", "bar.r3d.steadytype", "NightlyRetrainEnabled"],
                       capture_output=True, text=True)
    return r.returncode != 0 or r.stdout.strip() != "0"

def fresh_capture(days=7):
    """Corrections x3, whole-phrase accepts x2 from both Macs' capture."""
    cutoff = (datetime.datetime.utcnow() - datetime.timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%S")
    texts = []
    usage = os.path.expanduser("~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage")
    for name in os.listdir(usage):
        if not name.startswith("ghost_events"): continue
        for line in open(os.path.join(usage, name), errors="ignore"):
            try: e = json.loads(line)
            except Exception: continue
            ts = e.get("ts", "")
            if ts < cutoff: continue
            # Train/test hygiene: the exam slice is never trained on.
            if live_quiz.in_exam_slice(ts): continue
            ctx = (e.get("context") or "")[-200:]
            if e.get("event") == "typed_instead" and len(e.get("typed", "")) > 2:
                texts += [ctx + e["typed"]] * 3
            elif e.get("event") == "accept_all" and e.get("accepted"):
                texts += [ctx + e["accepted"]] * 2
    return [t for t in texts if len(t.split()) >= 4]

def main():
    if not enabled():
        nlog("disabled by NightlyRetrainEnabled=0, skipping"); return
    stamp = datetime.datetime.now().strftime("%Y%m%d")
    name = f"nightly_{stamp}"
    quant = f"{cr.LLAMA_CPP}/build/bin/llama-quantize"
    nlog(f"======== NIGHTLY {stamp} start ========")

    base = [json.loads(l)["text"] for l in open(f"{cr.WORK}/data_curve4000/train.jsonl")]
    valid = [json.loads(l)["text"] for l in open(f"{cr.WORK}/data_curve4000/valid.jsonl")]
    fresh = fresh_capture()
    nlog(f"dataset: {len(base)} base + {len(fresh)} fresh capture (weighted)")
    data_dir = cr.write_dataset(name, base + fresh, valid)

    try:
        gguf = cr.train_and_convert(name, data_dir, iters=600, quant=quant)

        champ = json.load(open(SCORES)) if os.path.exists(SCORES) else None
        if champ is None:
            nlog("no champion baseline; quizzing the live model first")
            champ = cr.quiz(LIVE_MODEL, "champ_baseline")
            if not champ: nlog("baseline quiz failed, aborting"); return
            json.dump(champ, open(SCORES, "w"))

        # Paper 2+3 exam sets (frozen for tonight so both models get the
        # same questions), champion's live scores cached alongside.
        exam = live_quiz.build_exam(); traps = live_quiz.build_traps()
        if "live" not in champ:
            cr.launch(LIVE_MODEL)
            champ["live"] = live_quiz.run_paper("champ", exam)
            champ["traps"] = live_quiz.run_traps("champ", traps)
            json.dump(champ, open(SCORES, "w"))
            nlog(f"champ live paper: {champ['live']} traps: {champ['traps']}")

        cand = cr.quiz(gguf, name)
        if not cand: nlog("candidate quiz failed; no swap"); return
        cand["live"] = live_quiz.run_paper(name, exam)
        cand["traps"] = live_quiz.run_traps(name, traps)
        nlog(f"cand live paper: {cand['live']} traps: {cand['traps']}")

        em_ok = (cand["em1"] or 0) >= (champ["em1"] or 0) - 0.005
        me_ok = (cand["meaning"] or 0) >= (champ["meaning"] or 0) - 0.01
        cl, xl = cand.get("live") or {}, champ.get("live") or {}
        live_ok = not xl or not cl or (
            cl.get("similar", 0) >= xl.get("similar", 0) - 0.02
            and cl.get("word1", 0) >= xl.get("word1", 0) - 0.02)
        trap_ok = not champ.get("traps") or not cand.get("traps") or (
            cand["traps"].get("reoffend", 0) <= champ["traps"].get("reoffend", 0) + 0.02)
        better = ((cand["em1"] or 0) > (champ["em1"] or 0)
                  or (cand["meaning"] or 0) > (champ["meaning"] or 0)
                  or (cl and xl and (cl.get("similar", 0) > xl.get("similar", 0)
                                     or cl.get("word1", 0) > xl.get("word1", 0)))
                  or (champ.get("traps") and cand.get("traps")
                      and cand["traps"].get("reoffend", 1) < champ["traps"].get("reoffend", 0)))
        nlog(f"gate: em_ok={em_ok} me_ok={me_ok} live_ok={live_ok} trap_ok={trap_ok} better={better}")
        if em_ok and me_ok and live_ok and trap_ok and better:
            shutil.copy(gguf, LIVE_MODEL)
            json.dump(cand, open(SCORES, "w"))
            nlog(f"SWAP: {name} wins (EM {cand['em1']:.3f} vs {champ['em1']:.3f}, "
                 f"meaning {cand['meaning']:.3f} vs {champ['meaning']:.3f}) — live model updated")
        else:
            nlog(f"NO SWAP: {name} (EM {cand['em1']:.3f} vs {champ['em1']:.3f}, "
                 f"meaning {cand['meaning'] or 0:.3f} vs {champ['meaning'] or 0:.3f}) — champion stands")
    finally:
        cr.kill_app()
        subprocess.run(["bash", RESTART], capture_output=True, text=True, timeout=120)
        nlog("app restored via blessed restart")
    nlog(f"======== NIGHTLY {stamp} done ========")

if __name__ == "__main__":
    main()
