#!/usr/bin/env python3
"""Converts Yale-LILY/aeslc (cleaned Enron email bodies) into the SteadyType
eval-corpus JSONL contract consumed by script/golden_eval.py. Output files
live OUTSIDE the repo under ~/.cache/steadytype-eval and are never committed.

Eval corpus JSONL contract (one JSON object per line):
    {"source": "aeslc",
     "register": "email",
     "app": "com.apple.mail",
     "text": "<one real human-written sentence, exactly as finished>",
     "prior_messages": ["up to 3 earlier sentences of the same email, oldest first"],
     "ts": null}

Each aeslc email body is split into sentences. Every sentence of 5..60 words
becomes a golden "text", with up to 3 preceding sentences of the SAME email
as prior_messages. Quoted-reply lines (leading ">"), header-like lines
(From:/To:/Cc:/Subject:/Sent:/Date:/Re:/Fwd:/FW:), forwarded-message banners,
and signature/valediction lines are dropped before sentence splitting.

Fetch the dataset first with:
    hf download Yale-LILY/aeslc --repo-type dataset \\
        --local-dir ~/.cache/steadytype-eval/aeslc
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

CACHE_ROOT = Path.home() / ".cache" / "steadytype-eval"
AESLC_DIR = CACHE_ROOT / "aeslc"
AESLC_OUT = CACHE_ROOT / "aeslc_eval.jsonl"
AESLC_SOURCE = "aeslc"
AESLC_REGISTER = "email"
AESLC_APP = "com.apple.mail"
AESLC_HF_DOWNLOAD_CMD = (
    "hf download Yale-LILY/aeslc --repo-type dataset "
    f"--local-dir {AESLC_DIR}"
)

DEFAULT_MIN_WORDS = 5
MAX_WORDS = 60
MIN_ASCII_ALPHA_FRACTION = 0.8

URL_PATTERN = re.compile(r"https?://|www\.", re.IGNORECASE)
ATTACHMENT_RESIDUE = re.compile(r"<<[^<>]+>>")

# Line-level filters applied before sentence splitting.
QUOTED_LINE = re.compile(r"^\s*>")
HEADER_LINE = re.compile(
    r"^\s*(From|To|Cc|Bcc|Subject|Sent|Date|Re|Fwd|FW|Ref|Importance|Attachments?)\s*:",
    re.IGNORECASE,
)
FORWARDED_BANNER = re.compile(
    r"-{2,}\s*(Original Message|Forwarded)|^\s*Forwarded by\b",
    re.IGNORECASE,
)
SIGNATURE_LINE = re.compile(
    r"^\s*(Thanks|Thank you|Regards|Best regards|Warm regards|Kind regards|"
    r"Best wishes|Best|Sincerely|Cheers|Warmly|Respectfully)\s*[,.]?\s*\S{0,25}\s*$",
    re.IGNORECASE,
)

# Splits a line of text into sentences on '.', '!', '?' followed by
# whitespace and an uppercase letter/digit/quote (a simple, non-NLP
# heuristic; imperfect splits are filtered out downstream by word count).
SENTENCE_SPLIT = re.compile(r'(?<=[.!?])\s+(?=[A-Z0-9"\'])')

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


def is_droppable_line(line, line_reject_counts):
    """Returns True if this line should be dropped before sentence
    splitting (quoted reply, header, forwarded banner, signature). Tallies
    the reason in line_reject_counts as a side effect."""
    stripped = line.strip()
    if not stripped:
        return True
    if QUOTED_LINE.match(stripped):
        line_reject_counts["quoted_line"] = line_reject_counts.get("quoted_line", 0) + 1
        return True
    if HEADER_LINE.match(stripped):
        line_reject_counts["header_line"] = line_reject_counts.get("header_line", 0) + 1
        return True
    if FORWARDED_BANNER.search(stripped):
        line_reject_counts["forwarded_banner"] = line_reject_counts.get("forwarded_banner", 0) + 1
        return True
    if SIGNATURE_LINE.match(stripped):
        line_reject_counts["signature_line"] = line_reject_counts.get("signature_line", 0) + 1
        return True
    return False


def split_into_sentences(body, line_reject_counts):
    """Drops quoted/header/banner/signature lines, then splits the
    remaining text of an email body into sentences, in order."""
    kept_lines = [
        line.strip()
        for line in body.split("\n")
        if not is_droppable_line(line, line_reject_counts)
    ]
    joined = " ".join(kept_lines)
    # Collapse the internal multi-space runs Enron bodies are full of, so both
    # golden text and prior context read as normal prose ("look  good" is not
    # a real quiz unit).
    sentences = [" ".join(s.split()) for s in SENTENCE_SPLIT.split(joined) if s.strip()]
    return sentences


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
    if ATTACHMENT_RESIDUE.search(golden):
        return "attachment_residue"
    if golden in seen_goldens:
        return "duplicate"
    return None


def build_prior_messages(sentences, index):
    """Up to the last MAX_PRIOR_MESSAGES sentences preceding sentences[index]
    (same email), oldest first, each trimmed to PRIOR_MESSAGE_TRIM chars."""
    preceding = sentences[:index]
    kept = preceding[-MAX_PRIOR_MESSAGES:]
    return [s[:PRIOR_MESSAGE_TRIM] for s in kept]


def sift_aeslc_rows(bodies, min_words):
    """Scans every email body's sentences, filters candidate golden
    sentences, and returns (kept_records, reject_counts, rows_scanned).
    Deterministic: no randomness, only depends on the input rows and
    min_words."""
    reject_counts = {}
    seen_goldens = set()
    kept = []

    for body in bodies:
        sentences = split_into_sentences(body, reject_counts)
        for i, golden in enumerate(sentences):
            reason = classify_golden(golden, min_words, seen_goldens)
            if reason is not None:
                reject_counts[reason] = reject_counts.get(reason, 0) + 1
                continue

            seen_goldens.add(golden)
            kept.append(
                {
                    "source": AESLC_SOURCE,
                    "register": AESLC_REGISTER,
                    "app": AESLC_APP,
                    "text": golden,
                    "prior_messages": build_prior_messages(sentences, i),
                    "ts": None,
                }
            )

    return kept, reject_counts, len(bodies)


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
    print("== aeslc eval-corpus sift ==")
    print(f"emails scanned: {rows_scanned}")
    print("rejections by reason:")
    for reason in sorted(reject_counts):
        print(f"  {reason}: {reject_counts[reason]}")
    total_rejected = sum(reject_counts.values())
    print(f"total rejected: {total_rejected}")
    print(f"candidates passing all filters: {kept_before_limit}")
    print(f"kept (after deterministic limit): {kept_count}")
    print(f"output: {out_path}")


def cmd_aeslc(args):
    if not AESLC_DIR.exists() or not find_parquet_files(AESLC_DIR):
        print("No parquet files found under " + str(AESLC_DIR), file=sys.stderr)
        print("Download the dataset first with:", file=sys.stderr)
        print(f"  {AESLC_HF_DOWNLOAD_CMD}", file=sys.stderr)
        return 1

    try:
        import pandas as pd
    except ImportError:
        print("pandas is required for the aeslc subcommand.", file=sys.stderr)
        print("Install it with: pip3 install pandas pyarrow", file=sys.stderr)
        return 1
    try:
        import pyarrow  # noqa: F401  (pandas' parquet engine; import verifies it's present)
    except ImportError:
        print("pyarrow is required for the aeslc subcommand.", file=sys.stderr)
        print("Install it with: pip3 install pandas pyarrow", file=sys.stderr)
        return 1

    parquet_files = find_parquet_files(AESLC_DIR)
    bodies = []
    for path in parquet_files:
        df = pd.read_parquet(path, columns=["email_body"])
        bodies.extend(df["email_body"].tolist())

    kept, reject_counts, rows_scanned = sift_aeslc_rows(bodies, args.min_words)
    selected = select_deterministic(kept, args.limit)
    out_path = Path(args.out).expanduser()
    write_jsonl(selected, out_path)
    print_summary(rows_scanned, reject_counts, len(kept), len(selected), out_path)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--min-words", type=int, default=DEFAULT_MIN_WORDS, help="minimum golden word count")
    parser.add_argument("--limit", type=int, default=2000, help="max rows to keep, deterministic by sha256(text)")
    parser.add_argument("--out", type=str, default=str(AESLC_OUT), help="output JSONL path")
    parser.set_defaults(func=cmd_aeslc)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
