#!/usr/bin/env python3
"""Auto-research loop: a self-driving tuner that hill-climbs the app's config
toward higher predictive accuracy, measured by the golden quiz.

The system (see docs/quiz-lessons.md):
  - CHAMPION: the best config found so far (a dict of every knob -> value).
  - CHALLENGER: the champion with exactly ONE knob changed.
  - REFEREE: script/golden_eval.py scores any config on the frozen diverse quiz.
  - LOGBOOK: every config tried + its metrics, append-only.

Algorithm: greedy coordinate ascent. Each pass tries every untested value of
every knob (holding the rest at champion); the best improvement per knob is
adopted; passes repeat until a full pass yields no gain (local optimum) or the
agent count budget runs out. One knob per challenger => every win is explained.

Objective: maximize EM@1 (over all cases) then keystrokes-saved-per-case,
subject to a hard latency ceiling (a config that is slower than LATENCY_BUDGET
is DISQUALIFIED, never crowned — the product must stay instant).

Reuses the launch/verify/quiz machinery in script/tuning_sweep.py. Data + logs
live under ~/.cache/steadytype-eval (never committed).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tuning_sweep as ts

CACHE = os.path.expanduser("~/.cache/steadytype-eval")
ts.CORPUS = os.path.join(CACHE, "diverse_eval.jsonl")     # the referee's questions
MODELS = os.path.join(CACHE, "models")
SCAFFOLDS = os.path.join(CACHE, "scaffolds")
LOGBOOK = os.path.join(CACHE, "research_logbook.jsonl")
CHAMPION_FILE = os.path.join(CACHE, "champion.json")

LATENCY_BUDGET_MS = int(os.environ.get("RESEARCH_LATENCY_MS", "200"))  # instant ceiling
AGENT_BUDGET = int(os.environ.get("RESEARCH_BUDGET", "400"))           # max evaluations

MODEL_PATHS = {
    "gemma-2-2b": os.path.join(MODELS, "gemma-2-2b-base.Q4_K_M.gguf"),
    "smollm2-1.7b": os.path.join(MODELS, "smollm2-1.7b-base.Q4_K_M.gguf"),
    "llama-3.2-3b": os.path.join(MODELS, "llama-3.2-3b-base.Q4_K_M.gguf"),
    "qwen2.5-1.5b": os.path.join(MODELS, "qwen2.5-1.5b-base.Q4_K_M.gguf"),
}
SCAFFOLD_FILES = {
    "builtin": None,
    "veryshort": os.path.join(SCAFFOLDS, "chat_veryshort.txt"),
    "short": os.path.join(SCAFFOLDS, "chat_short.txt"),
    "mixed": os.path.join(SCAFFOLDS, "chat_mixed.txt"),
    "size6": os.path.join(SCAFFOLDS, "chat_size6.txt"),
}

# Each knob -> candidate values. The first value listed is the default/starting
# champion. Cheap knobs (prompt/sampling/filters) churn fast; the model knob is
# the one expensive dial.
KNOBS = {
    # Model locked to Gemma 2 2B (owner's decision) — the loop tunes everything
    # else around it. Restore the alternatives here to re-open the model bakeoff.
    "model": ["gemma-2-2b"],
    "scaffold": ["builtin", "veryshort", "short", "mixed", "size6"],
    "budget": ["default", 16, 20, 24, 28],
    "temperature": [0, 0.1, 0.2],
    "top_p": ["default", 0.9, 0.95],
    "min_p": ["default", 0.05, 0.1],
    "repeat_penalty": ["default", 1.1],
    "confidence": [0, 0.1, 0.15, 0.2],
    "max_context": [3000, 1500],
    "echo_guard": [4, 6, 8, 0],       # 0 = filter off
    "context_turns": [3, 1, 5],
    "context_style": ["plain", "labeled"],
}
DEFAULTS = {k: v[0] for k, v in KNOBS.items()}


def recipe_to_version(recipe):
    """Translate a recipe dict into (env_overrides, quiz_flags, expect) for
    tuning_sweep.run_version."""
    env = {"STEADYTYPE_MODEL_PATH": MODEL_PATHS[recipe["model"]]}
    if recipe["scaffold"] != "builtin":
        env["STEADYTYPE_SCAFFOLD_CHAT_FILE"] = SCAFFOLD_FILES[recipe["scaffold"]]
    if recipe["budget"] != "default":
        env["STEADYTYPE_TOKEN_BUDGET"] = str(recipe["budget"])
    if recipe["temperature"]:
        env["STEADYTYPE_TEMPERATURE"] = str(recipe["temperature"])
    if recipe["top_p"] != "default":
        env["STEADYTYPE_TOP_P"] = str(recipe["top_p"])
    if recipe["min_p"] != "default":
        env["STEADYTYPE_MIN_P"] = str(recipe["min_p"])
    if recipe["repeat_penalty"] != "default":
        env["STEADYTYPE_REPEAT_PENALTY"] = str(recipe["repeat_penalty"])
    if recipe["confidence"]:
        env["STEADYTYPE_CONFIDENCE"] = str(recipe["confidence"])
    if recipe["max_context"] != 3000:
        env["STEADYTYPE_MAX_CONTEXT_CHARS"] = str(recipe["max_context"])
    if recipe["echo_guard"] != 4:
        env["STEADYTYPE_ECHO_GUARD_MIN_WORDS"] = str(recipe["echo_guard"])
    flags = "--context prior"
    if recipe["context_turns"] != 3:
        flags += " --context-turns %d" % recipe["context_turns"]
    if recipe["context_style"] != "plain":
        flags += " --context-style " + recipe["context_style"]
    return env, flags, {}


def recipe_key(recipe):
    return json.dumps(recipe, sort_keys=True)


def objective(metrics):
    """Return a comparable tuple (higher is better), or None if disqualified
    (over the latency budget or errored)."""
    if not metrics or "em1_rate" not in metrics:
        return None
    if metrics.get("p50_ms", 1e9) > LATENCY_BUDGET_MS:
        return None
    cases = max(1, metrics.get("cases", 1))
    ks_per_case = metrics.get("keystrokes_total", 0) / cases
    return (round(metrics["em1_rate"], 4), round(ks_per_case, 3))


def load_logbook():
    """Resume support: recover already-scored recipes so a restart never
    re-tests the same config."""
    seen = {}
    if os.path.exists(LOGBOOK):
        for line in open(LOGBOOK):
            try:
                row = json.loads(line)
                seen[recipe_key(row["recipe"])] = row["metrics"]
            except Exception:
                pass
    return seen


def log_result(recipe, metrics):
    with open(LOGBOOK, "a") as f:
        f.write(json.dumps({"recipe": recipe, "metrics": metrics}) + "\n")


def write_champion(recipe, metrics):
    with open(CHAMPION_FILE, "w") as f:
        json.dump({"recipe": recipe, "metrics": metrics}, f, indent=2)


def score(recipe, seen, label):
    """Score a recipe (cached if already seen), logging new results."""
    key = recipe_key(recipe)
    if key in seen:
        return seen[key]
    env, flags, expect = recipe_to_version(recipe)
    row = ts.run_version(label, env, flags, expect)
    metrics = row if "em1_rate" in row else {"error": row.get("error", "?")}
    seen[key] = metrics
    log_result(recipe, metrics)
    return metrics


def fmt(recipe):
    return " ".join("%s=%s" % (k, recipe[k]) for k in KNOBS
                    if recipe[k] != DEFAULTS[k]) or "(defaults)"


def main():
    seen = load_logbook()
    champion = dict(DEFAULTS)
    ts.log = print
    print("=== scoring starting champion (current live defaults) ===", flush=True)
    champ_metrics = score(champion, seen, "champion-baseline")
    champ_obj = objective(champ_metrics)
    if champ_obj is None:
        print("WARNING: baseline disqualified/errored:", champ_metrics, flush=True)
    write_champion(champion, champ_metrics)
    evals = 1

    improved = True
    while improved and evals < AGENT_BUDGET:
        improved = False
        for knob, values in KNOBS.items():
            best_val = champion[knob]
            best_obj = champ_obj
            best_metrics = champ_metrics
            for val in values:
                if val == champion[knob] or evals >= AGENT_BUDGET:
                    continue
                trial = dict(champion)
                trial[knob] = val
                label = "try-%s=%s" % (knob, val)
                m = score(trial, seen, label)
                evals += 1
                o = objective(m)
                mark = ""
                if o is not None and (best_obj is None or o > best_obj):
                    best_obj, best_val, best_metrics = o, val, m
                    mark = "  <-- best so far for %s" % knob
                if o is None:
                    mark = "  (disqualified)"
                print("  %-26s EM@1 %s  ks/case %s  p50 %s%s" % (
                    label,
                    ("%.1f%%" % (100 * m["em1_rate"])) if "em1_rate" in m else "ERR",
                    ("%.2f" % (m["keystrokes_total"] / max(1, m["cases"]))) if "em1_rate" in m else "-",
                    ("%dms" % m["p50_ms"]) if "em1_rate" in m else "-",
                    mark), flush=True)
            if best_val != champion[knob]:
                champion[knob] = best_val
                champ_metrics, champ_obj = best_metrics, best_obj
                improved = True
                write_champion(champion, champ_metrics)
                print(">>> NEW CHAMPION: %s | EM@1 %.1f%%  ks/case %.2f  p50 %dms" % (
                    fmt(champion), 100 * champ_metrics["em1_rate"],
                    champ_metrics["keystrokes_total"] / max(1, champ_metrics["cases"]),
                    champ_metrics["p50_ms"]), flush=True)

    print("\n========== RESEARCH LOOP DONE ==========", flush=True)
    print("evaluations: %d" % evals, flush=True)
    print("FINAL CHAMPION: %s" % fmt(champion), flush=True)
    if champ_obj:
        print("  EM@1 %.1f%%  keystrokes/case %.2f  p50 %dms" % (
            100 * champ_metrics["em1_rate"],
            champ_metrics["keystrokes_total"] / max(1, champ_metrics["cases"]),
            champ_metrics["p50_ms"]), flush=True)
    print("champion saved to %s ; full logbook %s" % (CHAMPION_FILE, LOGBOOK), flush=True)
    ts.kill_app()
    ts.launch(recipe_to_version(champion)[0])  # leave the champion running
    ts.wait_socket()
    return 0


if __name__ == "__main__":
    sys.exit(main())
