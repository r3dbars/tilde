#!/usr/bin/env python3
"""Master overnight GPU-experiment driver. Runs each experiment serially (the
GPU is a single resource), isolated in try/except so one failure never stops the
night, appending findings to docs/overnight-exploration.md and raw rows to
~/.cache/steadytype-eval/overnight_results.jsonl.

Reuses the robust launch/verify/quiz machinery in tuning_sweep.
"""
import json, os, sys, time, traceback

ROOT = "/Users/redbars/Steadytype/.claude/worktrees/busy-kare-569e80"
sys.path.insert(0, os.path.join(ROOT, "script"))
os.environ["SWEEP_QUIZ_LIMIT"] = os.environ.get("OVERNIGHT_LIMIT", "800")
import tuning_sweep as ts

CACHE = os.path.expanduser("~/.cache/steadytype-eval")
AS = os.path.expanduser("~/Library/Application Support/SteadyType/Models/GGUF")
JOURNAL = os.path.join(ROOT, "docs/overnight-exploration.md")
RESULTS = os.path.join(CACHE, "overnight_results.jsonl")
SCAF = os.path.join(CACHE, "scaffolds/chat_size6.txt")
BASE_ENV = {"STEADYTYPE_SCAFFOLD_CHAT_FILE": SCAF, "STEADYTYPE_TOKEN_BUDGET": "16",
            "STEADYTYPE_TEMPERATURE": "0.1", "STEADYTYPE_ECHO_GUARD_MIN_WORDS": "8"}
IMSG = os.path.join(CACHE, "imessage_eval.jsonl")

MODELS = {
    "gemma-2-2b(base)":  os.path.join(CACHE, "models/gemma-2-2b-base.Q4_K_M.gguf"),
    "qwen2.5-7b(base)":  os.path.join(CACHE, "models/qwen2.5-7b-base.Q4_K_M.gguf"),
    "qwen2.5-7b(instr)": os.path.join(CACHE, "models/qwen2.5-7b-instruct.Q4_K_M.gguf"),
    "gemma4-E4B(instr)": os.path.join(AS, "gemma-4-E4B_q4_0-it.gguf"),
    "gemma4-12b(instr)": os.path.join(CACHE, "models/gemma-4-12b.q4_0.gguf"),
    "gemma4-26bMoE(instr)": os.path.join(CACHE, "models/gemma-4-26b-a4b-moe.q4_0.gguf"),
}
REPLY_CORPORA = ["imessage", "dailydialog", "discord", "reddit", "ubuntu", "enron_thread"]


def note(md):
    with open(JOURNAL, "a") as f:
        f.write(md + "\n")
    print(md, flush=True)


def record(obj):
    with open(RESULTS, "a") as f:
        f.write(json.dumps(obj) + "\n")


def arm(model_path, flags, extra_env=None, corpus=None):
    """Run one quiz arm; returns metrics dict or {'error':...}."""
    if corpus:
        ts.CORPUS = corpus
    env = dict(BASE_ENV, STEADYTYPE_MODEL_PATH=model_path)
    if extra_env:
        env.update(extra_env)
    expect = {"model_path": os.path.basename(model_path)}
    row = ts.run_version("overnight", env, flags, expect)
    return row


def m(row):
    if "em1_rate" not in row:
        return None
    return {"em1": round(100 * row["em1_rate"], 1),
            "em2": round(100 * row.get("em2_rate", 0), 1),
            "ks": round(row["keystrokes_total"] / max(1, row["cases"]), 2),
            "spoke": round(100 * row["spoke_rate"], 0),
            "p50": row["p50_ms"], "cases": row["cases"]}


REPLY_FLAGS = "--context prior --prefix-words 2 --min-prior 1"


def exp1_base_vs_instruct():
    note("\n## Theory 5 (tiered brains) / base-vs-instruct on the owner's replies\n")
    note("Predict the owner's real reply from 2 words + screen. Which brain?\n")
    note("| model | EM@1 | keystrokes/reply | p50 |\n|---|---|---|---|")
    for name, path in MODELS.items():
        if not os.path.exists(path):
            note("| %s | (missing) | | |" % name); continue
        r = m(arm(path, REPLY_FLAGS, corpus=IMSG))
        if r:
            note("| %s | %.1f%% | %.2f | %dms |" % (name, r["em1"], r["ks"], r["p50"]))
            record({"exp": "base_vs_instruct", "model": name, **r})
        else:
            note("| %s | ERROR | | |" % name)


def exp2_multi_register():
    note("\n## Screen-response lift across every register (Gemma 2 2B)\n")
    note("Does seeing the screen help predict replies — and where most?\n")
    note("| register | no-screen EM@1 | +screen EM@1 | no-screen ks | +screen ks |\n|---|---|---|---|---|")
    model = MODELS["gemma-2-2b(base)"]
    for name in REPLY_CORPORA:
        corpus = os.path.join(CACHE, "%s_eval.jsonl" % name)
        if not os.path.exists(corpus):
            note("| %s | (missing) | | | |" % name); continue
        off = m(arm(model, "--context off --prefix-words 2 --min-prior 1", corpus=corpus))
        on = m(arm(model, REPLY_FLAGS, corpus=corpus))
        if off and on:
            note("| %s | %.1f%% | %.1f%% | %.2f | %.2f |" % (
                name, off["em1"], on["em1"], off["ks"], on["ks"]))
            record({"exp": "multi_register", "register": name, "off": off, "on": on})


def exp3_confidence_curve():
    note("\n## Theory 1 (cost of being wrong) — confidence gate on the owner's replies\n")
    note("Higher bar = speaks less but more accurate when it does. Find 'never annoying'.\n")
    note("| threshold | speaks | EM@1(spoken) | keystrokes/reply |\n|---|---|---|---|")
    model = MODELS["gemma-2-2b(base)"]
    for thr in ["0", "0.1", "0.15", "0.2", "0.3", "0.4"]:
        env = {"STEADYTYPE_CONFIDENCE": thr} if thr != "0" else {}
        row = arm(model, REPLY_FLAGS, extra_env=env, corpus=IMSG)
        r = m(row)
        if r:
            spk = round(100 * row["em1_spoken_rate"], 1) if "em1_spoken_rate" in row else 0
            note("| %s | %.0f%% | %.1f%% | %.2f |" % (thr, r["spoke"], spk, r["ks"]))
            record({"exp": "confidence_curve", "threshold": thr, "spoke": r["spoke"],
                    "em1_spoken": spk, "ks": r["ks"]})


def main():
    note("\n---\n# Overnight run started %s\n" % time.strftime("%Y-%m-%d %H:%M") if False else "")
    open(RESULTS, "a").close()
    for fn in (exp1_base_vs_instruct, exp2_multi_register, exp3_confidence_curve):
        try:
            fn()
        except Exception:
            note("\n**%s FAILED:**\n```\n%s\n```" % (fn.__name__, traceback.format_exc()[-800:]))
    note("\n_Experiment driver complete %s. Fine-tune + semantic re-score are separate stages._\n"
         % time.strftime("%H:%M"))
    ts.kill_app()
    # leave the tuned champion running so the app works in the morning
    ts.launch(dict(BASE_ENV, STEADYTYPE_MODEL_PATH=MODELS["gemma-2-2b(base)"]))
    ts.wait_socket()
    return 0


if __name__ == "__main__":
    sys.exit(main())
