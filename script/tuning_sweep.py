#!/usr/bin/env python3
"""Overnight tuning sweep: run many one-knob-changed versions of the app against
the frozen golden-continuation quiz and emit a ranked league table.

Each version relaunches the app fresh (killing any stray llama-server), sets
launch-time overrides via env (scaffold file, token budget, temperature,
model), waits for the socket, VERIFIES the active config via the config probe
(guards against silently testing the wrong build), then runs the full quiz in
--json mode. Harness-only versions (context format, register ablation) relaunch
the plain baseline binary and vary quiz flags instead.

Results stream to a JSONL log as each version finishes, so a crash mid-sweep
never loses completed rows. At the end a league table is printed sorted by
ExactMatch@1, each row deltaed against the first "baseline" control.

Not committed data: reads corpus + scaffolds from ~/.cache/steadytype-eval.
"""
import json
import os
import subprocess
import sys
import time

ROOT = "/Users/redbars/Steadytype/.claude/worktrees/busy-kare-569e80"
APP_BIN = os.path.join(ROOT, "dist/SteadyType.app/Contents/MacOS/SteadyType")
EVAL = os.path.join(ROOT, "script/golden_eval.py")
CORPUS = os.environ.get("SWEEP_CORPUS",
                        os.path.expanduser("~/.cache/steadytype-eval/discord_eval.jsonl"))
SCAFFOLDS = os.path.expanduser("~/.cache/steadytype-eval/scaffolds")
SOCK = os.path.expanduser("~/Library/Application Support/SteadyType/ghost.sock")
GGUF_DIR = os.path.expanduser("~/Library/Application Support/SteadyType/Models/GGUF")
RESULTS = os.path.expanduser("~/.cache/steadytype-eval/sweep_results.jsonl")


def sh(cmd, **kw):
    return subprocess.run(cmd, shell=True, text=True, capture_output=True, **kw)


def scaffold(name):
    return {"STEADYTYPE_SCAFFOLD_CHAT_FILE": os.path.join(SCAFFOLDS, name)}


# Each version: label, env overrides (relaunch knobs), quiz flags (harness
# knobs), and the config field->expected-substring the probe must confirm.
# All versions run --context prior unless flags say otherwise, so they compare
# against the context baseline (17.2% EM@1).
BASE_FLAGS = "--context prior"

VERSIONS = [
    ("baseline-control-A", {}, BASE_FLAGS, {}),

    # 1) scaffold source (real mined Discord examples vs hand-written)
    ("scaffold-veryshort", scaffold("chat_veryshort.txt"), BASE_FLAGS, {"scaffold_chat": "veryshort"}),
    ("scaffold-short", scaffold("chat_short.txt"), BASE_FLAGS, {"scaffold_chat": "short"}),
    ("scaffold-medium", scaffold("chat_medium.txt"), BASE_FLAGS, {"scaffold_chat": "medium"}),
    ("scaffold-long", scaffold("chat_long.txt"), BASE_FLAGS, {"scaffold_chat": "long"}),
    ("scaffold-mixed", scaffold("chat_mixed.txt"), BASE_FLAGS, {"scaffold_chat": "mixed"}),

    # 2) scaffold size (how many examples)
    ("scaffold-size1", scaffold("chat_size1.txt"), BASE_FLAGS, {"scaffold_chat": "size1"}),
    ("scaffold-size6", scaffold("chat_size6.txt"), BASE_FLAGS, {"scaffold_chat": "size6"}),
    ("scaffold-size10", scaffold("chat_size10.txt"), BASE_FLAGS, {"scaffold_chat": "size10"}),
    ("scaffold-size14", scaffold("chat_size14.txt"), BASE_FLAGS, {"scaffold_chat": "size14"}),

    # 3) suggestion length (token budget)
    ("budget-8", {"STEADYTYPE_TOKEN_BUDGET": "8"}, BASE_FLAGS, {"token_budget": "8"}),
    ("budget-12", {"STEADYTYPE_TOKEN_BUDGET": "12"}, BASE_FLAGS, {"token_budget": "12"}),
    ("budget-20", {"STEADYTYPE_TOKEN_BUDGET": "20"}, BASE_FLAGS, {"token_budget": "20"}),
    ("budget-28", {"STEADYTYPE_TOKEN_BUDGET": "28"}, BASE_FLAGS, {"token_budget": "28"}),

    # 4) temperature (confirm greedy is best for exact-match)
    ("temp-0.15", {"STEADYTYPE_TEMPERATURE": "0.15"}, BASE_FLAGS, {"temperature": "0.15"}),
    ("temp-0.3", {"STEADYTYPE_TEMPERATURE": "0.3"}, BASE_FLAGS, {"temperature": "0.3"}),

    # 5) conversation-context formatting (harness-only, baseline binary)
    ("context-turns1", {}, "--context prior --context-turns 1", {}),
    ("context-turns2", {}, "--context prior --context-turns 2", {}),
    ("context-turns5", {}, "--context prior --context-turns 5", {}),
    ("context-labeled", {}, "--context prior --context-style labeled", {}),

    # 6) register system: does chat-voice beat prose/email on chat text?
    ("register-prose", {}, "--context prior --force-app com.apple.TextEdit", {}),
    ("register-email", {}, "--context prior --force-app com.apple.mail", {}),

    # 7) smaller model (the M1 MacBook question)
    ("model-E2B", {"STEADYTYPE_MODEL": "E2B"}, BASE_FLAGS, {"model": "E2B"}),

    ("baseline-control-B", {}, BASE_FLAGS, {}),
]

# Confidence-gate threshold sweep (SWEEP_SET=confidence). Each suppresses the
# suggestion when the model's first-token probability is below the threshold.
CONFIDENCE_VERSIONS = [
    ("confidence-off", {}, BASE_FLAGS, {"confidence": "0"}),
    ("confidence-0.10", {"STEADYTYPE_CONFIDENCE": "0.10"}, BASE_FLAGS, {"confidence": "0.10"}),
    ("confidence-0.15", {"STEADYTYPE_CONFIDENCE": "0.15"}, BASE_FLAGS, {"confidence": "0.15"}),
    ("confidence-0.20", {"STEADYTYPE_CONFIDENCE": "0.20"}, BASE_FLAGS, {"confidence": "0.20"}),
    ("confidence-0.25", {"STEADYTYPE_CONFIDENCE": "0.25"}, BASE_FLAGS, {"confidence": "0.25"}),
    ("confidence-0.30", {"STEADYTYPE_CONFIDENCE": "0.30"}, BASE_FLAGS, {"confidence": "0.30"}),
    ("confidence-0.40", {"STEADYTYPE_CONFIDENCE": "0.40"}, BASE_FLAGS, {"confidence": "0.40"}),
    ("confidence-0.50", {"STEADYTYPE_CONFIDENCE": "0.50"}, BASE_FLAGS, {"confidence": "0.50"}),
]

if os.environ.get("SWEEP_SET") == "confidence":
    VERSIONS = CONFIDENCE_VERSIONS

# Base-model re-tune (SWEEP_SET=retune): re-measure the "more predictive" levers
# — suggestion length (token budget) and scaffold — on whatever model is pinned
# via STEADYTYPE_MODEL_PATH (export it before running). Includes a length x
# scaffold combo. Compared against the base-model default (baseline-control-A).
RETUNE_VERSIONS = [
    ("baseline-control-A", {}, BASE_FLAGS, {}),
    ("budget-20", {"STEADYTYPE_TOKEN_BUDGET": "20"}, BASE_FLAGS, {"token_budget": "20"}),
    ("budget-28", {"STEADYTYPE_TOKEN_BUDGET": "28"}, BASE_FLAGS, {"token_budget": "28"}),
    ("budget-36", {"STEADYTYPE_TOKEN_BUDGET": "36"}, BASE_FLAGS, {"token_budget": "36"}),
    ("scaffold-short", scaffold("chat_short.txt"), BASE_FLAGS, {"scaffold_chat": "short"}),
    ("scaffold-mixed", scaffold("chat_mixed.txt"), BASE_FLAGS, {"scaffold_chat": "mixed"}),
    ("scaffold-size6", scaffold("chat_size6.txt"), BASE_FLAGS, {"scaffold_chat": "size6"}),
    ("context-labeled", {}, "--context prior --context-style labeled", {}),
    ("combo-short+budget28",
     dict(list(scaffold("chat_short.txt").items()) + [("STEADYTYPE_TOKEN_BUDGET", "28")]),
     BASE_FLAGS, {"scaffold_chat": "short", "token_budget": "28"}),
]

if os.environ.get("SWEEP_SET") == "retune":
    VERSIONS = RETUNE_VERSIONS

# Model bakeoff (SWEEP_SET=models): one version per GGUF in the models dir, each
# pointed at via STEADYTYPE_MODEL_PATH. Built dynamically so it picks up whatever
# the downloader produced. The current default (E4B) is the reference row.
if os.environ.get("SWEEP_SET") == "models":
    import glob
    MODEL_DIR = os.path.expanduser("~/.cache/steadytype-eval/models")
    # Both Gemma 4 tiers as references (current shipping E4B + the low-RAM E2B),
    # scored on the same diverse quiz as every bakeoff candidate.
    VERSIONS = [
        ("ref-gemma4-E4B", {}, BASE_FLAGS, {}),
        ("ref-gemma4-E2B", {"STEADYTYPE_MODEL": "E2B"}, BASE_FLAGS, {"model": "E2B"}),
    ]
    for path in sorted(glob.glob(os.path.join(MODEL_DIR, "*.gguf"))):
        stem = os.path.basename(path)[:-5]
        VERSIONS.append((
            "m-" + stem[:34],
            {"STEADYTYPE_MODEL_PATH": path},
            BASE_FLAGS,
            {"model_path": os.path.basename(path)[:16]},
        ))


def kill_app():
    # Loop until truly dead: a stale instance still bound to the socket would
    # make us quiz the wrong (old) binary. Escalate to -9, then remove the
    # socket file so a fresh bind is unambiguous.
    for attempt in range(15):
        sh("pkill -x SteadyType")
        sh("pkill -f 'llama-server.*17872'")
        time.sleep(1)
        if not sh("pgrep -x SteadyType").stdout.strip():
            break
        sh("pkill -9 -x SteadyType")
        sh("pkill -9 -f 'llama-server.*17872'")
        time.sleep(1)
    try:
        os.unlink(SOCK)
    except OSError:
        pass
    # Wait until port 17872 is actually free — a stale llama-server still bound
    # would make the next app adopt the WRONG model (config check would reject it).
    for _ in range(20):
        if not sh("lsof -nP -iTCP:17872 -sTCP:LISTEN").stdout.strip():
            break
        sh("pkill -9 -f 'llama-server'")
        time.sleep(1)
    time.sleep(2)


def wait_socket(timeout=180):
    import socket
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(2)
            s.connect(SOCK)
            s.close()
            return True
        except OSError:
            time.sleep(2)
    return False


def wait_model_ready(timeout=300):
    """Wait until llama-server has actually LOADED the model, by polling its
    /health endpoint for "ok". A socket response alone is not enough — the app
    answers with an empty suggestion (fallback) while the model is still
    loading, which would silently score a slow-loading model as 0%. After
    health is ok, give the app a moment to notice via its own health poll."""
    import urllib.request
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen("http://127.0.0.1:17872/health", timeout=3) as r:
                if b'"status":"ok"' in r.read():
                    time.sleep(3)  # let the app's 2s health poll register it
                    return True
        except Exception:
            pass
        time.sleep(3)
    return False


def probe_config():
    out = sh("python3 %s --config-only --sock %r" % (EVAL, SOCK))
    try:
        return json.loads(out.stdout.strip().splitlines()[-1])
    except Exception:
        return {}


def running_model_gguf():
    out = sh("pgrep -fl 'llama-server.*17872'")
    line = out.stdout
    if "E2B" in line:
        return "E2B"
    if "E4B" in line:
        return "E4B"
    return "?"


def launch(env_overrides):
    env = dict(os.environ)
    env.update(env_overrides)
    subprocess.Popen([APP_BIN], env=env,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def run_version(label, env_overrides, flags, expect):
    print("\n=== %s ===" % label, flush=True)
    kill_app()
    launch(env_overrides)
    if not wait_socket():
        return {"label": label, "error": "socket never came up"}

    # Gate on the NEW binary actually serving: the config echo only exists in
    # the current build, so a non-empty probe proves we're not on a stale app.
    cfg = {}
    for _ in range(30):
        cfg = probe_config()
        if cfg:
            break
        time.sleep(2)
    if not cfg:
        return {"label": label, "error": "config echo never responded (stale/old binary?)"}
    if not wait_model_ready():
        return {"label": label, "error": "model never warmed"}
    cfg = probe_config()
    # Verify the override is actually live before spending 13 minutes on it.
    mismatches = []
    for field, want in expect.items():
        got = str(cfg.get(field, ""))
        if want not in got:
            mismatches.append("%s: want ~%r got %r" % (field, want, got))
    # Model is verified independently against the actual llama-server cmdline.
    if env_overrides.get("STEADYTYPE_MODEL"):
        want_model = env_overrides["STEADYTYPE_MODEL"]
        got_model = running_model_gguf()
        if want_model != got_model:
            mismatches.append("model(gguf): want %s got %s" % (want_model, got_model))
    # For an explicit GGUF path, the config echo already reports model_path and
    # kill_app guarantees the port was free before launch — so verify via the
    # echo (below) rather than a flaky pgrep of the process cmdline.
    if env_overrides.get("STEADYTYPE_MODEL_PATH"):
        want_base = os.path.basename(env_overrides["STEADYTYPE_MODEL_PATH"])
        if want_base not in str(cfg.get("model_path", "")):
            mismatches.append("model_path echo: %s not in %r" % (want_base, cfg.get("model_path")))
    if mismatches:
        print("  CONFIG MISMATCH — skipping:", "; ".join(mismatches), flush=True)
        return {"label": label, "error": "config mismatch: " + "; ".join(mismatches),
                "config": cfg}

    print("  config OK:", json.dumps(cfg), flush=True)
    limit = os.environ.get("SWEEP_QUIZ_LIMIT")
    limit_flag = (" --limit " + limit) if limit else ""
    # --sleep 0: the old 0.25s inter-question pause added ~8 min of pure idle
    # per version. The app handles back-to-back requests fine (serialized socket
    # writes + SIGPIPE-safe), and single-threaded keeps latency numbers honest.
    cmd = "python3 %s --corpus %r %s%s --json --sleep 0 --sock %r" % (EVAL, CORPUS, flags, limit_flag, SOCK)
    t0 = time.time()
    out = sh(cmd)
    dur = int(time.time() - t0)
    try:
        metrics = json.loads(out.stdout.strip().splitlines()[-1])
    except Exception:
        return {"label": label, "error": "quiz output unparseable",
                "stdout_tail": out.stdout[-400:], "stderr_tail": out.stderr[-400:]}
    row = {"label": label, "config": cfg, "flags": flags, "duration_s": dur}
    row.update(metrics)
    print("  EM@1 %.1f%% (spoken %.1f%%)  keystrokes/spoken %.2f  spoke %.1f%%  p50 %dms p95 %dms  (%dm%ds)" % (
        100 * metrics["em1_rate"], 100 * metrics.get("em1_spoken_rate", 0),
        metrics["keystrokes_per_spoken"], 100 * metrics["spoke_rate"],
        metrics["p50_ms"], metrics["p95_ms"], dur // 60, dur % 60), flush=True)
    return row


def league_table(rows):
    scored = [r for r in rows if "em1_rate" in r]
    if not scored:
        return "no scored versions"
    base = next((r for r in scored if r["label"].startswith("baseline")), scored[0])
    b_em1 = base["em1_rate"]
    b_ks = base["keystrokes_per_spoken"]
    scored.sort(key=lambda r: (r["em1_rate"], r["keystrokes_per_spoken"]), reverse=True)
    lines = []
    lines.append("%-20s %7s %8s %8s %9s %7s %7s" % (
        "version", "EM@1", "EM@1spk", "spoke", "kstrokes", "p50ms", "p95ms"))
    lines.append("-" * 74)
    for r in scored:
        d = 100 * (r["em1_rate"] - b_em1)
        lines.append("%-20s %6.1f%% %7.1f%% %7.1f%% %9.2f %7d %7d" % (
            r["label"], 100 * r["em1_rate"], 100 * r.get("em1_spoken_rate", 0),
            100 * r["spoke_rate"], r["keystrokes_per_spoken"], r["p50_ms"], r["p95_ms"]))
    errs = [r for r in rows if "error" in r]
    if errs:
        lines.append("")
        lines.append("errors/skipped:")
        for r in errs:
            lines.append("  %-22s %s" % (r["label"], r["error"]))
    lines.append("")
    lines.append("baseline: %s (EM@1 %.1f%%, keystrokes/spoken %.2f)" % (
        base["label"], 100 * b_em1, b_ks))
    return "\n".join(lines)


def main():
    only = None
    if len(sys.argv) > 1:
        only = set(sys.argv[1:])  # run just these labels (dry run)
    versions = [v for v in VERSIONS if not only or v[0] in only]
    open(RESULTS, "w").close()
    rows = []
    for label, env_overrides, flags, expect in versions:
        row = run_version(label, env_overrides, flags, expect)
        rows.append(row)
        with open(RESULTS, "a") as f:
            f.write(json.dumps(row) + "\n")
    print("\n\n========== LEAGUE TABLE ==========", flush=True)
    print(league_table(rows), flush=True)
    # Leave a clean, default app running so the product still works afterward.
    kill_app()
    launch({})
    wait_socket()
    return 0


if __name__ == "__main__":
    sys.exit(main())
