#!/usr/bin/env python3
"""Converts public datasets into the SteadyType eval-corpus JSONL contract
consumed by script/golden_eval.py. Output files live OUTSIDE the repo under
~/.cache/steadytype-eval and are never committed.

Eval corpus JSONL contract (one JSON object per line):
    {"source": "discord|imessage|enron|aeslc|blog",
     "register": "chat|email|prose",
     "app": "<host app bundle id>",
     "text": "<a full real message exactly as its human author finished it>",
     "prior_messages": ["up to 3 earlier turns for context, oldest first"],
     "ts": "ISO8601, optional"}

Subcommands convert one public dataset each. Only "discord" is implemented
today; "enron", "aeslc", and "blog" are natural additions and should follow
the same shape (a cmd_<name>(args) function + its own argparse subparser)
without disturbing this one.

discord: converts mookiezi/Discord-Dialogues (ChatML exchanges) fetched via:
    hf download mookiezi/Discord-Dialogues --repo-type dataset \\
        --local-dir ~/.cache/steadytype-eval/discord
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

CACHE_ROOT = Path.home() / ".cache" / "steadytype-eval"
DISCORD_DIR = CACHE_ROOT / "discord"
DISCORD_OUT = CACHE_ROOT / "discord_eval.jsonl"
DISCORD_APP = "com.hnc.Discord"
DISCORD_HF_DOWNLOAD_CMD = (
    "hf download mookiezi/Discord-Dialogues --repo-type dataset "
    f"--local-dir {DISCORD_DIR}"
)

DEFAULT_MIN_WORDS = 5
MAX_WORDS = 60
MIN_ASCII_ALPHA_FRACTION = 0.8

CHATML_TURN = re.compile(r"<\|im_start\|>(\w+)\n(.*?)<\|im_end\|>", re.DOTALL)
CHATML_RESIDUE = re.compile(r"<\|[a-zA-Z_]+\|>")
URL_PATTERN = re.compile(r"https?://|www\.", re.IGNORECASE)
CODE_FENCE = re.compile(r"```")
DISCORD_MARKUP = re.compile(r"<@[!&]?\d+>|<#\d+>|<a?:\w+:\d+>")

PRIOR_MESSAGE_TRIM = 200
MAX_PRIOR_MESSAGES = 3


def text_digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def find_parquet_files(root):
    """All *.parquet files under root, excluding the hf-hub bookkeeping
    directory (root/.cache) that `hf download` leaves behind."""
    files = []
    for path in sorted(root.rglob("*.parquet")):
        rel = path.relative_to(root)
        if ".cache" in rel.parts:
            continue
        files.append(path)
    return files


def parse_chatml_turns(text):
    """Returns a list of (role, content) tuples in order, oldest first.
    Empty list if the text doesn't contain any recognizable ChatML turn."""
    return CHATML_TURN.findall(text)


def word_count(text):
    return len(text.split())


def has_alpha(text):
    return any(c.isalpha() for c in text)


def is_mostly_ascii(text):
    alpha_chars = [c for c in text if c.isalpha()]
    if not alpha_chars:
        return True  # handled separately by has_alpha
    ascii_alpha = sum(1 for c in alpha_chars if ord(c) < 128)
    return (ascii_alpha / len(alpha_chars)) >= MIN_ASCII_ALPHA_FRACTION


def classify_golden(golden, min_words, seen_goldens):
    """Returns None if golden passes every filter, else a short rejection
    reason string. Does NOT mutate seen_goldens on rejection; the caller adds
    the golden to seen_goldens itself once accepted."""
    wc = word_count(golden)
    if wc < min_words:
        return "under_min_words"
    if wc > MAX_WORDS:
        return "over_max_words"
    if not has_alpha(golden):
        return "no_alpha"
    if not is_mostly_ascii(golden):
        return "non_ascii"
    if URL_PATTERN.search(golden):
        return "has_url"
    if CODE_FENCE.search(golden):
        return "code_fence"
    if CHATML_RESIDUE.search(golden):
        return "chatml_residue"
    if DISCORD_MARKUP.search(golden):
        return "discord_markup"
    if golden in seen_goldens:
        return "duplicate"
    return None


def build_prior_messages(turns):
    """Up to the last MAX_PRIOR_MESSAGES turns preceding the final one,
    oldest first, each trimmed to PRIOR_MESSAGE_TRIM chars."""
    preceding = turns[:-1]
    kept = preceding[-MAX_PRIOR_MESSAGES:]
    return [content[:PRIOR_MESSAGE_TRIM] for _role, content in kept]


def sift_discord_rows(texts, min_words):
    """Scans every row's ChatML text, filters candidate golden messages, and
    returns (kept_records, reject_counts, rows_scanned). Deterministic: no
    randomness, only depends on the input rows and min_words."""
    reject_counts = {}
    unparseable = 0
    seen_goldens = set()
    kept = []

    for text in texts:
        turns = parse_chatml_turns(text)
        if not turns:
            unparseable += 1
            continue

        # Role is intentionally ignored: the harness needs any
        # human-authored continuation, not specifically a reply turn.
        golden = turns[-1][1]
        reason = classify_golden(golden, min_words, seen_goldens)
        if reason is not None:
            reject_counts[reason] = reject_counts.get(reason, 0) + 1
            continue

        seen_goldens.add(golden)
        kept.append(
            {
                "source": "discord",
                "register": "chat",
                "app": DISCORD_APP,
                "text": golden,
                "prior_messages": build_prior_messages(turns),
            }
        )

    if unparseable:
        reject_counts["unparseable"] = unparseable
    return kept, reject_counts, len(texts)


def select_deterministic(records, limit):
    """Order by sha256(text) and keep the first `limit`. Same input always
    produces the same byte-identical selection and order."""
    ordered = sorted(records, key=lambda r: text_digest(r["text"]))
    return ordered[:limit]


def write_jsonl(records, out_path):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        for rec in records:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")


def print_discord_summary(rows_scanned, reject_counts, kept_before_limit, kept_count, out_path):
    print("== discord eval-corpus sift ==")
    print(f"rows scanned: {rows_scanned}")
    print("rejections by reason:")
    for reason in sorted(reject_counts):
        print(f"  {reason}: {reject_counts[reason]}")
    total_rejected = sum(reject_counts.values())
    print(f"total rejected: {total_rejected}")
    print(f"candidates passing all filters: {kept_before_limit}")
    print(f"kept (after deterministic limit): {kept_count}")
    print(f"output: {out_path}")


def cmd_discord(args):
    if not DISCORD_DIR.exists() or not find_parquet_files(DISCORD_DIR):
        print("No parquet files found under " + str(DISCORD_DIR), file=sys.stderr)
        print("Download the dataset first with:", file=sys.stderr)
        print(f"  {DISCORD_HF_DOWNLOAD_CMD}", file=sys.stderr)
        return 1

    try:
        import pandas as pd
    except ImportError:
        print("pandas is required for the discord subcommand.", file=sys.stderr)
        print("Install it with: pip3 install pandas pyarrow", file=sys.stderr)
        return 1
    try:
        import pyarrow  # noqa: F401  (pandas' parquet engine; import verifies it's present)
    except ImportError:
        print("pyarrow is required for the discord subcommand.", file=sys.stderr)
        print("Install it with: pip3 install pandas pyarrow", file=sys.stderr)
        return 1

    parquet_files = find_parquet_files(DISCORD_DIR)
    texts = []
    for path in parquet_files:
        df = pd.read_parquet(path, columns=["text"])
        texts.extend(df["text"].tolist())

    kept, reject_counts, rows_scanned = sift_discord_rows(texts, args.min_words)
    selected = select_deterministic(kept, args.limit)
    write_jsonl(selected, DISCORD_OUT)
    print_discord_summary(rows_scanned, reject_counts, len(kept), len(selected), DISCORD_OUT)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    subparsers = parser.add_subparsers(dest="dataset", required=True)

    discord_parser = subparsers.add_parser("discord", help="convert mookiezi/Discord-Dialogues")
    discord_parser.add_argument("--min-words", type=int, default=DEFAULT_MIN_WORDS, help="minimum golden word count")
    discord_parser.add_argument("--limit", type=int, default=2000, help="max rows to keep, deterministic by sha256(text)")
    discord_parser.set_defaults(func=cmd_discord)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
