#!/usr/bin/env python3
"""Mine few-shot scaffold candidates for the chat register from the local
Discord-Dialogues corpus. Emits ready-to-use scaffold blocks (identical format
to RawContinuationPrompt.scaffold(.chat)) under ~/.cache/steadytype-eval/
scaffolds/ for the tuning sweep. Deterministic: candidates ordered by sha256,
no randomness. Data stays outside the repo.
"""
import hashlib
import os
import re
import sys

CACHE = os.path.expanduser("~/.cache/steadytype-eval")
DISCORD_DIR = os.path.join(CACHE, "discord")
OUT_DIR = os.path.join(CACHE, "scaffolds")

HEADER = ("The following are real chat messages being written by their authors, "
          "continued naturally in the same casual voice.")

TURN_RE = re.compile(r"<\|im_start\|>(user|assistant)\n(.*?)<\|im_end\|>", re.DOTALL)
URL_RE = re.compile(r"https?://|www\.")
MARKUP_RE = re.compile(r"<@|<:|<#|</|:[a-z_]+:|```")
# Skip obviously abusive/offensive rows; casual/lowercase tone is wanted.
BAD_RE = re.compile(r"\b(fag|nigg|retard|rape|kys)\b", re.IGNORECASE)


def iter_messages():
    import pyarrow.parquet as pq
    files = [os.path.join(DISCORD_DIR, "data", f)
             for f in sorted(os.listdir(os.path.join(DISCORD_DIR, "data")))
             if f.endswith(".parquet")]
    for path in files:
        table = pq.read_table(path, columns=["text"])
        for val in table.column("text").to_pylist():
            for role, content in TURN_RE.findall(val or ""):
                yield content.strip()


def clean(msg):
    if not msg or URL_RE.search(msg) or MARKUP_RE.search(msg) or BAD_RE.search(msg):
        return None
    if not any(c.isalpha() for c in msg):
        return None
    ascii_letters = sum(1 for c in msg if c.isalpha() and ord(c) < 128)
    letters = sum(1 for c in msg if c.isalpha())
    if letters == 0 or ascii_letters / letters < 0.9:
        return None
    return " ".join(msg.split())


def make_example(msg):
    """Split a message into prefix->continuation at ~45% (word boundary).
    Returns (words, prefix, continuation) or None."""
    words = msg.split()
    n = len(words)
    if n < 6 or n > 16:
        return None
    cut = max(2, min(n - 2, round(n * 0.45)))
    prefix = " ".join(words[:cut])
    cont = " ".join(words[cut:])
    if " " not in prefix or " " not in cont:
        return None
    # A tidy continuation for display: lead-lowercase already casual.
    return n, prefix, cont


def block(examples):
    lines = [HEADER, ""]
    for _, prefix, cont in examples:
        lines.append("Text: " + prefix)
        lines.append("Continuation: " + cont)
        lines.append("")
    return "\n".join(lines) + "\n\n"


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    seen = set()
    pool = []  # (sha, n, prefix, cont)
    for msg in iter_messages():
        c = clean(msg)
        if not c:
            continue
        ex = make_example(c)
        if not ex:
            continue
        key = c.lower()
        if key in seen:
            continue
        seen.add(key)
        sha = hashlib.sha256(c.encode("utf-8")).hexdigest()
        pool.append((sha, ex[0], ex[1], ex[2]))
        if len(pool) >= 200000:
            break
    pool.sort(key=lambda t: t[0])
    examples = [(n, p, cc) for _, n, p, cc in pool]

    def by_len(lo, hi):
        return [e for e in examples if lo <= e[0] <= hi]

    veryshort = by_len(6, 8)[:3]
    short = by_len(6, 10)[:3]
    medium = by_len(11, 16)[:3]
    longs = by_len(14, 16)[:3]
    mixed = (by_len(6, 8)[:1] + by_len(11, 13)[:1] + by_len(14, 16)[:1])

    def spread(count):
        # round-robin across length bands for variety
        bands = [by_len(6, 8), by_len(9, 11), by_len(12, 16)]
        out, i = [], 0
        used = set()
        while len(out) < count and any(bands):
            band = bands[i % 3]
            for e in band:
                if id(e) not in used:
                    out.append(e); used.add(id(e)); break
            i += 1
            if i > count * 6:
                break
        return out[:count]

    files = {
        "chat_veryshort.txt": veryshort,
        "chat_short.txt": short,
        "chat_medium.txt": medium,
        "chat_long.txt": longs,
        "chat_mixed.txt": mixed,
        "chat_size1.txt": spread(1),
        "chat_size6.txt": spread(6),
        "chat_size10.txt": spread(10),
        "chat_size14.txt": spread(14),
    }
    for name, exs in files.items():
        if not exs:
            print("WARN: no examples for", name, file=sys.stderr)
            continue
        with open(os.path.join(OUT_DIR, name), "w", encoding="utf-8") as f:
            f.write(block(exs))
        print("wrote %-20s %d examples" % (name, len(exs)))

    print("\n--- chat_short.txt ---")
    print(open(os.path.join(OUT_DIR, "chat_short.txt")).read())
    print("--- chat_size6.txt ---")
    print(open(os.path.join(OUT_DIR, "chat_size6.txt")).read())
    return 0


if __name__ == "__main__":
    sys.exit(main())
