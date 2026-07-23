#!/usr/bin/env python3
"""Converts the li2017dailydialog/daily_dialog HF dataset into the SteadyType
eval-corpus JSONL contract consumed by script/golden_eval.py. Output files
live OUTSIDE the repo under ~/.cache/steadytype-eval and are never committed.

Eval corpus JSONL contract (one JSON object per line):
    {"source": "dailydialog",
     "register": "chat",
     "app": "com.apple.MobileSMS",
     "text": "<a single real human-written utterance, exactly as finished>",
     "prior_messages": ["up to 3 earlier turns of the same dialog, oldest first"],
     "ts": null}

daily_dialog's "dialog" column is a list of utterances per multi-turn chat.
Each utterance of 5..60 words becomes a golden "text"; the up-to-3 preceding
utterances of the same dialog become prior_messages. The raw text inserts a
space before punctuation and around some contraction apostrophes (e.g.
"I ' m", "yes ."); this script trims that spacing back to normal prose
before applying the shared quality filters.

Fetch via:
    hf download li2017dailydialog/daily_dialog --repo-type dataset \\
        --local-dir ~/.cache/steadytype-eval/dailydialog

The dataset ships only as a loading script (no parquet in the main
revision); the auto-converted parquet lives on the "refs/convert/parquet"
revision, so a second download is needed to get actual data files:
    hf download li2017dailydialog/daily_dialog --repo-type dataset \\
        --revision refs/convert/parquet \\
        --local-dir ~/.cache/steadytype-eval/dailydialog_parquet
Then merge the "default/<split>/*.parquet" tree into the dailydialog dir
(this script looks for default/{train,validation,test}/*.parquet under
--data-dir).
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

CACHE_ROOT = Path.home() / ".cache" / "steadytype-eval"
DAILYDIALOG_DIR = CACHE_ROOT / "dailydialog"
DAILYDIALOG_OUT = CACHE_ROOT / "dailydialog_eval.jsonl"
DAILYDIALOG_APP = "com.apple.MobileSMS"
DAILYDIALOG_HF_DOWNLOAD_CMD = (
    "hf download li2017dailydialog/daily_dialog --repo-type dataset "
    f"--local-dir {DAILYDIALOG_DIR} && "
    "hf download li2017dailydialog/daily_dialog --repo-type dataset "
    f"--revision refs/convert/parquet --local-dir {DAILYDIALOG_DIR}_parquet"
)
SPLITS = ("train", "validation", "test")

DEFAULT_MIN_WORDS = 5
MAX_WORDS = 60
MIN_ASCII_ALPHA_FRACTION = 0.8

URL_PATTERN = re.compile(r"https?://|www\.", re.IGNORECASE)
DAILYDIALOG_RESIDUE = re.compile(r"__eou__|__eot__", re.IGNORECASE)

# daily_dialog inserts a space before punctuation, and around some
# contraction apostrophes (e.g. "I ' m", "don ' t", "Let ' s"). Trim both
# back to normal prose spacing.
CONTRACTION_SPACE = re.compile(r"(\w) ' (s|t|re|ll|ve|d|m)\b", re.IGNORECASE)
PUNCT_SPACE = re.compile(r"\s+([.,!?;:])")
MULTI_SPACE = re.compile(r"\s+")

PRIOR_MESSAGE_TRIM = 200
MAX_PRIOR_MESSAGES = 3


def text_digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def find_split_parquet_files(root):
    """Returns {split: [Path, ...]} for the default/<split>/*.parquet tree,
    excluding the hf-hub bookkeeping directory (root/.cache)."""
    found = {}
    for split in SPLITS:
        split_dir = root / "default" / split
        if not split_dir.exists():
            continue
        files = []
        for path in sorted(split_dir.rglob("*.parquet")):
            rel = path.relative_to(root)
            if ".cache" in rel.parts:
                continue
            files.append(path)
        if files:
            found[split] = files
    return found


def trim_utterance(text):
    """Un-does daily_dialog's inserted spacing before punctuation and around
    contraction apostrophes, e.g. "I ' m" -> "I'm", "yes ." -> "yes."."""
    # Normalize typographic apostrophes/quotes to ASCII first so the
    # contraction regex (ASCII ') matches the curly-quote rows too.
    text = text.replace("’", "'").replace("‘", "'")
    text = CONTRACTION_SPACE.sub(r"\1'\2", text)
    text = PUNCT_SPACE.sub(r"\1", text)
    text = MULTI_SPACE.sub(" ", text).strip()
    return text


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
    if DAILYDIALOG_RESIDUE.search(golden):
        return "dailydialog_residue"
    if golden in seen_goldens:
        return "duplicate"
    return None


def build_prior_messages(trimmed_turns, idx):
    """Up to the last MAX_PRIOR_MESSAGES trimmed utterances preceding index
    idx in the same dialog, oldest first, each trimmed to PRIOR_MESSAGE_TRIM
    chars."""
    preceding = trimmed_turns[max(0, idx - MAX_PRIOR_MESSAGES):idx]
    return [t[:PRIOR_MESSAGE_TRIM] for t in preceding]


def sift_dailydialog_rows(dialogs, min_words):
    """Scans every dialog's utterances, filters candidate golden messages,
    and returns (kept_records, reject_counts, rows_scanned). rows_scanned is
    the number of individual utterances examined (not dialogs). Deterministic:
    no randomness, only depends on the input dialogs and min_words."""
    reject_counts = {}
    seen_goldens = set()
    kept = []
    rows_scanned = 0

    for dialog in dialogs:
        trimmed_turns = [trim_utterance(u) for u in dialog]
        for idx, golden in enumerate(trimmed_turns):
            rows_scanned += 1
            reason = classify_golden(golden, min_words, seen_goldens)
            if reason is not None:
                reject_counts[reason] = reject_counts.get(reason, 0) + 1
                continue

            seen_goldens.add(golden)
            kept.append(
                {
                    "source": "dailydialog",
                    "register": "chat",
                    "app": DAILYDIALOG_APP,
                    "text": golden,
                    "prior_messages": build_prior_messages(trimmed_turns, idx),
                    "ts": None,
                }
            )

    return kept, reject_counts, rows_scanned


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


def print_summary(rows_scanned, reject_counts, kept_before_limit, kept_count, out_path):
    print("== dailydialog eval-corpus sift ==")
    print(f"utterances scanned: {rows_scanned}")
    print("rejections by reason:")
    for reason in sorted(reject_counts):
        print(f"  {reason}: {reject_counts[reason]}")
    total_rejected = sum(reject_counts.values())
    print(f"total rejected: {total_rejected}")
    print(f"candidates passing all filters: {kept_before_limit}")
    print(f"kept (after deterministic limit): {kept_count}")
    print(f"output: {out_path}")


def cmd_dailydialog(args):
    data_dir = Path(args.data_dir)
    split_files = find_split_parquet_files(data_dir)
    if not split_files:
        print("No parquet files found under " + str(data_dir / "default"), file=sys.stderr)
        print("Download the dataset first with:", file=sys.stderr)
        print(f"  {DAILYDIALOG_HF_DOWNLOAD_CMD}", file=sys.stderr)
        print(
            "then merge the refs/convert/parquet download's default/ tree "
            "into the plain download's directory.",
            file=sys.stderr,
        )
        return 1

    try:
        import pandas as pd
    except ImportError:
        print("pandas is required for the dailydialog subcommand.", file=sys.stderr)
        print("Install it with: pip3 install pandas pyarrow", file=sys.stderr)
        return 1
    try:
        import pyarrow  # noqa: F401  (pandas' parquet engine; import verifies it's present)
    except ImportError:
        print("pyarrow is required for the dailydialog subcommand.", file=sys.stderr)
        print("Install it with: pip3 install pandas pyarrow", file=sys.stderr)
        return 1

    dialogs = []
    for split in SPLITS:
        for path in split_files.get(split, []):
            df = pd.read_parquet(path, columns=["dialog"])
            for dialog in df["dialog"].tolist():
                dialogs.append(list(dialog))

    kept, reject_counts, rows_scanned = sift_dailydialog_rows(dialogs, args.min_words)
    selected = select_deterministic(kept, args.limit)
    out_path = Path(args.out)
    write_jsonl(selected, out_path)
    print_summary(rows_scanned, reject_counts, len(kept), len(selected), out_path)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--data-dir",
        default=str(DAILYDIALOG_DIR),
        help="local dir holding default/{train,validation,test}/*.parquet (default: %(default)s)",
    )
    parser.add_argument("--min-words", type=int, default=DEFAULT_MIN_WORDS, help="minimum golden word count")
    parser.add_argument("--limit", type=int, default=2000, help="max rows to keep, deterministic by sha256(text)")
    parser.add_argument("--out", default=str(DAILYDIALOG_OUT), help="output JSONL path (default: %(default)s)")
    parser.set_defaults(func=cmd_dailydialog)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
