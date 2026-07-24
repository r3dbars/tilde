#!/usr/bin/env python3
"""Converts sedthh/ubuntu_dialogue_qa (real Ubuntu IRC support-channel Q&A
pairs, derived from the Lowe et al. Ubuntu Dialogue Corpus) into the
SteadyType REPLY-corpus JSONL contract consumed by the screen-response quiz.
Output files live OUTSIDE the repo under ~/.cache/steadytype-eval and are
never committed.

Why this dataset and not the "official" Ubuntu Dialogue Corpus mirrors: the
canonical HF copies of the Ubuntu Dialogue Corpus (both the loading-script
version at ubuntu-dialogs-corpus/ubuntu_dialogs_corpus and the parquet mirror
at ntcuong777/ubuntu_dialogue_corpus_train) ship the "ranking dataset
creator" train.csv, which is tokenized, lowercased, and *Porter-stemmed*
("import" -> "import", "easily" -> "easi", "perhaps" -> "perhap") -- not real
human-written text, so it fails the "text is a real reply someone wrote"
requirement outright. sedthh/ubuntu_dialogue_qa instead derives from the raw
(unstemmed) Kaggle release of the same corpus, filtered to genuine
question/answer exchange pairs -- INSTRUCTION is the message being answered,
RESPONSE is the real reply someone wrote. Verified empirically before
building this loader (see docs/ script history).

REPLY-corpus JSONL contract (one JSON object per line):
    {"source": "ubuntu",
     "register": "chat",
     "app": "com.tinyspeck.slackmacgap",
     "text": "<a real REPLY someone wrote>",
     "prior_messages": ["the message(s) being replied to, oldest last-is-most-recent, up to 3"],
     "ts": null}

Each dataset row is one (INSTRUCTION, RESPONSE) pair: RESPONSE becomes
"text" (the golden reply, 4..60 words after filtering) and prior_messages is
the single-element list [INSTRUCTION] -- the message it replies to. Every
kept record therefore has exactly one prior message, satisfying the
"prior_messages MUST contain the message(s) it responds to (at least 1)"
requirement.

Fetch the dataset first with:
    hf download sedthh/ubuntu_dialogue_qa --repo-type dataset \\
        --local-dir ~/.cache/steadytype-eval/ubuntu_qa
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

CACHE_ROOT = Path.home() / ".cache" / "steadytype-eval"
UBUNTU_DIR = CACHE_ROOT / "ubuntu_qa"
UBUNTU_OUT = CACHE_ROOT / "ubuntu_eval.jsonl"
UBUNTU_SOURCE = "ubuntu"
UBUNTU_REGISTER = "chat"
UBUNTU_APP = "com.tinyspeck.slackmacgap"
UBUNTU_HF_DOWNLOAD_CMD = (
    "hf download sedthh/ubuntu_dialogue_qa --repo-type dataset "
    f"--local-dir {UBUNTU_DIR}"
)

DEFAULT_MIN_WORDS = 4
MAX_WORDS = 60
MIN_ASCII_ALPHA_FRACTION = 0.8
PRIOR_MESSAGE_TRIM = 400

URL_PATTERN = re.compile(r"https?://|www\.", re.IGNORECASE)
# IRC support-channel residue that survived the Kaggle Q&A extraction:
# bot-factoid references (ubottu/FloodBot are Ubuntu-channel infobots),
# bang-prefixed bot commands, and paste-site link mentions (the site name
# alone, without a scheme, so URL_PATTERN above would miss it).
MARKUP_RESIDUE = re.compile(
    r"\bubottu\b|\bfactoid\b|\bfloodbot\b|^\s*!\w|pastebin|paste\.ubuntu",
    re.IGNORECASE,
)


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


def normalize(text):
    """Collapses internal whitespace runs (newlines, tabs, double-spaces)
    into single spaces, so both golden text and prior context read as
    normal prose."""
    return " ".join(text.split())


def classify_golden(golden, min_words, seen_goldens):
    """Returns None if golden passes every shared filter, else a short
    rejection reason string. Does NOT mutate seen_goldens on rejection; the
    caller adds the golden to seen_goldens itself once accepted."""
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
    if MARKUP_RESIDUE.search(golden):
        return "markup_residue"
    if golden in seen_goldens:
        return "duplicate"
    return None


def sift_ubuntu_rows(pairs, min_words):
    """Scans every (instruction, response) pair, filters candidate golden
    replies, and returns (kept_records, reject_counts, rows_scanned).
    Deterministic: no randomness, only depends on the input rows and
    min_words."""
    reject_counts = {}
    seen_goldens = set()
    kept = []

    for instruction, response in pairs:
        prior = normalize(instruction)
        golden = normalize(response)

        if not prior:
            reject_counts["empty_prior"] = reject_counts.get("empty_prior", 0) + 1
            continue

        reason = classify_golden(golden, min_words, seen_goldens)
        if reason is not None:
            reject_counts[reason] = reject_counts.get(reason, 0) + 1
            continue

        seen_goldens.add(golden)
        kept.append(
            {
                "source": UBUNTU_SOURCE,
                "register": UBUNTU_REGISTER,
                "app": UBUNTU_APP,
                "text": golden,
                "prior_messages": [prior[:PRIOR_MESSAGE_TRIM]],
                "ts": None,
            }
        )

    return kept, reject_counts, len(pairs)


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
    print("== ubuntu REPLY-corpus sift ==")
    print(f"pairs scanned: {rows_scanned}")
    print("rejections by reason:")
    for reason in sorted(reject_counts):
        print(f"  {reason}: {reject_counts[reason]}")
    total_rejected = sum(reject_counts.values())
    print(f"total rejected: {total_rejected}")
    print(f"candidates passing all filters: {kept_before_limit}")
    print(f"kept (after deterministic limit): {kept_count}")
    print(f"output: {out_path}")


def cmd_ubuntu(args):
    if not UBUNTU_DIR.exists() or not find_parquet_files(UBUNTU_DIR):
        print("No parquet files found under " + str(UBUNTU_DIR), file=sys.stderr)
        print("Download the dataset first with:", file=sys.stderr)
        print(f"  {UBUNTU_HF_DOWNLOAD_CMD}", file=sys.stderr)
        return 1

    try:
        import pandas as pd
    except ImportError:
        print("pandas is required for the ubuntu subcommand.", file=sys.stderr)
        print("Install it with: pip3 install pandas pyarrow", file=sys.stderr)
        return 1
    try:
        import pyarrow  # noqa: F401  (pandas' parquet engine; import verifies it's present)
    except ImportError:
        print("pyarrow is required for the ubuntu subcommand.", file=sys.stderr)
        print("Install it with: pip3 install pandas pyarrow", file=sys.stderr)
        return 1

    parquet_files = find_parquet_files(UBUNTU_DIR)
    pairs = []
    for path in parquet_files:
        df = pd.read_parquet(path, columns=["INSTRUCTION", "RESPONSE"])
        pairs.extend(zip(df["INSTRUCTION"].tolist(), df["RESPONSE"].tolist()))

    kept, reject_counts, rows_scanned = sift_ubuntu_rows(pairs, args.min_words)
    selected = select_deterministic(kept, args.limit)
    out_path = Path(args.out).expanduser()
    write_jsonl(selected, out_path)
    print_summary(rows_scanned, reject_counts, len(kept), len(selected), out_path)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--min-words", type=int, default=DEFAULT_MIN_WORDS, help="minimum golden word count")
    parser.add_argument("--limit", type=int, default=2000, help="max rows to keep, deterministic by sha256(text)")
    parser.add_argument("--out", type=str, default=str(UBUNTU_OUT), help="output JSONL path")
    parser.set_defaults(func=cmd_ubuntu)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
