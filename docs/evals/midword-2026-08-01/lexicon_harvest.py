#!/usr/bin/env python3
"""Harvest the personal lexicon: the owner's names, slang, and jargon.

Sources ONLY the training pool (records[1500:] of the frozen split, seed
20260724) -- exam messages never feed the lexicon, so the trie can never
"know" an exam answer it shouldn't.

Two buckets, both requiring >=3 occurrences:
  proper    capitalized words seen capitalized mid-sentence at least once
  oov       words absent from /usr/share/dict/words (slang)

Output: lexicon.txt (one word per line) + lexicon_counts.json
"""
import json
import os
import random
import re
from collections import Counter

EVAL = os.path.expanduser("~/.cache/steadytype-eval")
MM = os.path.join(EVAL, "matchmaker")
SEED_SPLIT = 20260724
MIN_COUNT = 3

WORD_RE = re.compile(r"[A-Za-z][A-Za-z']*")


def load_train_pool():
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
        records.append(text)
    random.Random(SEED_SPLIT).shuffle(records)
    return records[1500:]                      # exam slice excluded


def main():
    texts = load_train_pool()
    sysdict = set(w.strip().lower() for w in open("/usr/share/dict/words"))

    total = Counter()
    cap_midsentence = Counter()
    for text in texts:
        tokens = WORD_RE.findall(text)
        for i, tok in enumerate(tokens):
            total[tok.lower()] += 1
            if tok[0].isupper() and i > 0:
                cap_midsentence[tok.lower()] += 1

    proper, oov = [], []
    for w, n in total.items():
        if n < MIN_COUNT or len(w) < 3 or w in ("i'm", "i'll", "i've", "i'd"):
            continue
        if cap_midsentence.get(w, 0) >= 1 and w not in sysdict:
            proper.append((w, n))
        elif w not in sysdict:
            oov.append((w, n))

    proper.sort(key=lambda x: -x[1])
    oov.sort(key=lambda x: -x[1])
    lex = [w for w, _ in proper] + [w for w, _ in oov]

    with open(os.path.join(MM, "lexicon.txt"), "w") as f:
        f.write("\n".join(lex) + "\n")
    json.dump({"proper": proper[:200], "oov": oov[:200],
               "n_proper": len(proper), "n_oov": len(oov),
               "n_train_msgs": len(texts)},
              open(os.path.join(MM, "lexicon_counts.json"), "w"), indent=1)

    print(f"train msgs: {len(texts):,}")
    print(f"proper nouns / names: {len(proper)}   top: "
          + ", ".join(w for w, _ in proper[:15]))
    print(f"slang / oov words:    {len(oov)}   top: "
          + ", ".join(w for w, _ in oov[:15]))
    print(f"lexicon total: {len(lex)} words -> lexicon.txt")


if __name__ == "__main__":
    main()
