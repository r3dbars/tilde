#!/usr/bin/env python3
"""Mid-word constrained-generation quiz (the KeyType experiment).

The frozen exams cut at word boundaries; real typing mostly pauses MID-word
("tomo|"). This quiz rebuilds the frozen texting exam with mid-word cuts and
measures whether constraining generation to legally extend the typed prefix
helps.

Arms (same questions, same server, same seed):
  baseline  serving recipe of record, unconstrained
  bouncer   baseline generations, but violating suggestions are suppressed
            (post-hoc filter -- zero new compute, what the Swift guard does)
  grammar   GBNF: output MUST start with >=1 word chars then space/punct
  trie      GBNF: first word must complete the prefix into a word from
            /usr/share/dict/words + the personal lexicon

Scoring: final text = typed_prefix + suggestion, judged against the golden
message by the scorer of record. A violation therefore scores ~0 on its own
(it produces "tomotomorrow" or "tomo tomorrow") -- exactly what the user
would see.

Violations measured on baseline:
  fmt      first char is not a word char (model treated prefix as complete)
  restart  first word starts with the whole prefix again (would double it)

MW_N (default 500) questions, private port 17999 only.
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
import ab_quiz                                     # noqa: E402
from general_quiz import score_dump                # noqa: E402

N = int(os.environ.get("MW_N", "500"))
SEED_SPLIT = 20260724
SEED_GEN = 20260731
WCHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'")


def load_midword_cases(limit):
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
                priors = eval(priors, {"__builtins__": {}})   # noqa: S307
            except Exception:                                  # noqa: BLE001
                priors = [priors]
        records.append((priors, text))
    random.Random(SEED_SPLIT).shuffle(records)
    exam = records[:1500]                          # the frozen exam slice

    cases = []
    for priors, text in exam:
        words = text.split()
        cut = max(1, min(2, len(words) - 2))
        target = words[cut]
        if len(target) < 4 or not all(c in WCHARS for c in target):
            continue
        plen = 2 if len(target) < 6 else 3
        prefix = target[:plen]
        priors = [p for p in priors if p and p.strip()]
        cases.append({
            "context": " ".join(words[:cut]) + " " + prefix,
            "prefix": prefix,
            "golden": " ".join(words[cut:]),
            "page": "\n".join(priors[-3:]),
        })
        if len(cases) == limit:
            break
    return cases


# ---------------------------------------------------------------- grammar
TAIL = 'tail ::= [ .,!?] [ -~]*\n'

GRAMMAR_LETTERS = ("root ::= [a-zA-Z']+ tail?\n" + TAIL)


def load_vocab():
    vocab = set(w.strip().lower() for w in open("/usr/share/dict/words")
                if w.strip())
    lex = os.path.join(MM, "lexicon.txt")
    if os.path.exists(lex):
        vocab |= set(w.strip().lower() for w in open(lex) if w.strip())
    return vocab


def trie_grammar(prefix, vocab):
    p = prefix.lower()
    comps = sorted({w[len(p):] for w in vocab
                    if w.startswith(p) and len(w) > len(p)
                    and "\\" not in w and '"' not in w},
                   key=lambda c: (len(c), c))[:300]
    if not comps:
        return GRAMMAR_LETTERS, True
    alts = " | ".join(f'"{c}"' for c in comps)
    return (f"root ::= ({alts}) tail?\n" + TAIL), False


# ---------------------------------------------------------------- serving
def gen(prompt, grammar=None):
    body = {"prompt": prompt, "n_predict": ab_quiz.N_PREDICT,
            "temperature": ab_quiz.TEMP, "seed": SEED_GEN,
            "cache_prompt": True}
    if grammar:
        body["grammar"] = grammar
    req = urllib.request.Request(
        f"http://127.0.0.1:{ab_quiz.PORT}/completion",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read()).get("content", "")


def finalize(prefix, raw):
    """What the user would see: prefix + raw first line, NO lstrip (a
    leading space is a real, visible violation mid-word)."""
    first = raw.split("\n", 1)[0].rstrip()
    return ab_quiz.repair_dangling_tail(prefix + first).strip()


def violations(prefix, raw):
    first = raw.split("\n", 1)[0]
    fmt = bool(first) and first[0] not in WCHARS
    tok0 = first.strip().split(" ")[0].lower() if first.strip() else ""
    restart = tok0.startswith(prefix.lower()) and len(tok0) >= len(prefix)
    return fmt, restart


def main():
    t0 = time.time()
    cases = load_midword_cases(N)
    vocab = load_vocab()
    scaffold = open(ab_quiz.SCAFFOLD_BASE, encoding="utf-8").read()
    print(f"mid-word questions: {len(cases)}   vocab: {len(vocab):,}")

    server = ab_quiz.Server()
    server.start()
    print("private llama-server up on 17999")
    results, extra = {}, {}
    try:
        # ---- baseline + bouncer (one generation pass)
        base_rows, boun_rows = [], []
        n_fmt = n_restart = 0
        for i, c in enumerate(cases):
            raw = gen(ab_quiz.build_prompt(scaffold, c["context"], c["page"]))
            fmt, restart = violations(c["prefix"], raw)
            n_fmt += fmt
            n_restart += restart
            final = finalize(c["prefix"], raw)
            base_rows.append({"suggestion": final, "golden": c["golden"]})
            boun_rows.append({"suggestion": "" if (fmt or restart) else final,
                              "golden": c["golden"]})
            if (i + 1) % 100 == 0:
                print(f"  baseline {i+1}/{len(cases)} ({time.time()-t0:.0f}s)",
                      flush=True)

        # ---- grammar arm
        gram_rows = []
        for i, c in enumerate(cases):
            raw = gen(ab_quiz.build_prompt(scaffold, c["context"], c["page"]),
                      grammar=GRAMMAR_LETTERS)
            gram_rows.append({"suggestion": finalize(c["prefix"], raw),
                              "golden": c["golden"]})
            if (i + 1) % 100 == 0:
                print(f"  grammar {i+1}/{len(cases)} ({time.time()-t0:.0f}s)",
                      flush=True)

        # ---- trie arm
        trie_rows, n_fallback = [], 0
        for i, c in enumerate(cases):
            g, fb = trie_grammar(c["prefix"], vocab)
            n_fallback += fb
            raw = gen(ab_quiz.build_prompt(scaffold, c["context"], c["page"]),
                      grammar=g)
            trie_rows.append({"suggestion": finalize(c["prefix"], raw),
                              "golden": c["golden"]})
            if (i + 1) % 100 == 0:
                print(f"  trie {i+1}/{len(cases)} ({time.time()-t0:.0f}s)",
                      flush=True)
    finally:
        server.stop()

    for label, rows in (("baseline", base_rows), ("bouncer", boun_rows),
                        ("grammar", gram_rows), ("trie", trie_rows)):
        p = os.path.join(MM, f"dump_midword_{label}.jsonl")
        with open(p, "w") as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        results[label] = score_dump(p)

    shown = sum(1 for r in boun_rows if r["suggestion"])
    extra = {"n": len(cases),
             "fmt_violations": n_fmt, "restart_violations": n_restart,
             "violation_rate": round((n_fmt + n_restart) / len(cases), 3),
             "bouncer_shown_rate": round(shown / len(cases), 3),
             "trie_fallbacks": n_fallback,
             "secs": round(time.time() - t0)}
    json.dump({"arms": results, "extra": extra},
              open(os.path.join(MM, "midword_results.json"), "w"), indent=1)

    print(f"\nviolations: fmt {n_fmt}  restart {n_restart}  "
          f"({100*extra['violation_rate']:.1f}% of {len(cases)})")
    print(f"bouncer shows {100*extra['bouncer_shown_rate']:.1f}% of the time; "
          f"trie fell back on {n_fallback}")
    print(f"\nRAW NUMBERS   (n={len(cases)})")
    print(f"{'arm':<10}{'word1':>8}{'first2':>8}{'similar*':>9}{'meaning':>9}")
    for label in ("baseline", "bouncer", "grammar", "trie"):
        s = results[label]
        print(f"{label:<10}{s['word1']:>8.3f}{s['word12']:>8.3f}"
              f"{s['similar']:>9.3f}{s['meaning']:>9.3f}")
    print(f"\ntotal {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
