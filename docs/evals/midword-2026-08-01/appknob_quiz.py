#!/usr/bin/env python3
"""App-tag knob: does telling the model WHICH app the writer is in help?

One line added to the prompt ("App: Messages") on the frozen texting exam,
against the identical prompt without it. Register gating was falsified
2026-07-30; expectation registered as NEUTRAL — this exists to close the
question with a number, not to win.
"""
import json
import os
import sys
import time

EVAL = os.path.expanduser("~/.cache/steadytype-eval")
MM = os.path.join(EVAL, "matchmaker")
sys.path.insert(0, EVAL)
sys.path.insert(0, MM)
os.environ.setdefault("AB_FLOOR", "loose")
import ab_quiz                                     # noqa: E402
from general_quiz import score_dump                # noqa: E402

N = int(os.environ.get("AK_N", "500"))


def main():
    t0 = time.time()
    cases = ab_quiz.load_texting_paper()[:N]
    scaffold = open(ab_quiz.SCAFFOLD_BASE, encoding="utf-8").read()
    server = ab_quiz.Server()
    server.start()
    print(f"questions: {len(cases)}")
    results = {}
    try:
        for arm in ("plain", "app_tag"):
            rows = []
            for i, c in enumerate(cases):
                prompt = ab_quiz.build_prompt(scaffold, c["context"], c["page"])
                if arm == "app_tag":
                    prompt = prompt.replace(
                        "Text: ", "App: Messages\nText: ", 1) \
                        if "Text: " in prompt else prompt
                raw = server.complete(prompt)
                rows.append({"suggestion": ab_quiz.normalize_continuation(raw),
                             "golden": c["golden"]})
                if (i + 1) % 250 == 0:
                    print(f"  {arm} {i+1}/{len(cases)} ({time.time()-t0:.0f}s)",
                          flush=True)
            p = os.path.join(MM, f"dump_appknob_{arm}.jsonl")
            with open(p, "w") as f:
                for r in rows:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")
            results[arm] = score_dump(p)
    finally:
        server.stop()

    json.dump(results, open(os.path.join(MM, "appknob_results.json"), "w"),
              indent=1)
    print(f"\nRAW NUMBERS   (n={len(cases)})")
    print(f"{'arm':<10}{'word1':>8}{'first2':>8}{'similar*':>9}{'meaning':>9}")
    for arm in ("plain", "app_tag"):
        s = results[arm]
        print(f"{arm:<10}{s['word1']:>8.3f}{s['word12']:>8.3f}"
              f"{s['similar']:>9.3f}{s['meaning']:>9.3f}")
    print(f"total {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
