#!/usr/bin/env python3
"""Converts barilan/blog_authorship_corpus into the SteadyType eval-corpus
JSONL contract consumed by script/golden_eval.py. Output lives OUTSIDE the
repo under ~/.cache/steadytype-eval and is never committed.

Eval corpus JSONL contract (one JSON object per line):
    {"source": "blog",
     "register": "prose",
     "app": "com.apple.TextEdit",
     "text": "<a single natural sentence from a real blog post>",
     "prior_messages": ["up to 3 earlier sentences of the same post, oldest first"],
     "ts": null}

Fetch the dataset first with:
    hf download barilan/blog_authorship_corpus --repo-type dataset \\
        --local-dir ~/.cache/steadytype-eval/blog

Unlike newer HF datasets, this one is NOT shipped as parquet: `hf download`
lands a `datasets`-style loading script (blog_authorship_corpus.py) plus a
single data/blogs.zip containing one raw XML-ish file per blogger
(<blogger-id>.<gender>.<age>.<job>.<horoscope>.xml, latin-1 encoded, informal
tags that a real XML parser chokes on -- confirmed empirically by inspecting
the archive and the reference loading script, which itself parses these
files line-by-line with regex rather than xml.etree). So this loader reads
directly from the zip with the stdlib (zipfile + re); no pandas/pyarrow
dependency is needed for this particular source, and none is imported.

Each blogger file contains repeated <date>...</date><post>...</post> blocks.
This loader joins the lines inside each <post> into one blob, splits that
blob into sentences, and treats each sentence as a candidate golden with the
preceding sentences of the *same post* as prior_messages -- matching "split
each post into sentences" rather than the reference loader's per-line rows.
"""
import argparse
import hashlib
import html
import json
import re
import sys
import zipfile
from pathlib import Path

CACHE_ROOT = Path.home() / ".cache" / "steadytype-eval"
BLOG_DIR = CACHE_ROOT / "blog"
BLOG_ZIP = BLOG_DIR / "data" / "blogs.zip"
DEFAULT_OUT = CACHE_ROOT / "blog_eval.jsonl"
BLOG_SOURCE = "blog"
BLOG_REGISTER = "prose"
BLOG_APP = "com.apple.TextEdit"
BLOG_HF_DOWNLOAD_CMD = (
    "hf download barilan/blog_authorship_corpus --repo-type dataset "
    f"--local-dir {BLOG_DIR}"
)

DEFAULT_MIN_WORDS = 5
MAX_WORDS = 60
MIN_ASCII_ALPHA_FRACTION = 0.8
MIN_ALNUM_FRACTION = 0.4  # below this, a "sentence" is mostly punctuation/emoticons

POST_BLOCK = re.compile(r"<post>(.*?)</post>", re.DOTALL | re.IGNORECASE)
SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+(?=[A-Za-z0-9\"'])")
URL_PATTERN = re.compile(r"https?://|www\.", re.IGNORECASE)
URLLINK_RESIDUE = re.compile(r"urllink", re.IGNORECASE)
BLOGGER_BOILERPLATE = re.compile(
    r"\b(posted by|posted at|permalink|trackback|comments\s*\()", re.IGNORECASE
)
WHITESPACE = re.compile(r"\s+")

PRIOR_MESSAGE_TRIM = 200
MAX_PRIOR_MESSAGES = 3


def text_digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


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


def is_mostly_punctuation(text):
    stripped = text.replace(" ", "")
    if not stripped:
        return True
    alnum = sum(1 for c in stripped if c.isalnum())
    return (alnum / len(stripped)) < MIN_ALNUM_FRACTION


def is_all_caps_shouting(text):
    """True if the sentence has alphabetic content but no lowercase letters
    at all (allowing for a handful of short all-caps sentences that are
    genuinely fine, e.g. "OK.", would still be caught here -- acceptable,
    since real shouting posts are the overwhelmingly common case and the
    filter is documented/counted rather than silent)."""
    letters = [c for c in text if c.isalpha()]
    if len(letters) < 4:
        return False
    return not any(c.islower() for c in letters)


def clean_post_text(raw_block):
    """Un-escapes HTML entities, joins the block's lines into one blob, and
    collapses whitespace. Does NOT strip urlLink -- that happens per-sentence
    below so the rejection reason can be counted precisely."""
    unescaped = html.unescape(raw_block)
    lines = [line.strip() for line in unescaped.splitlines()]
    lines = [line for line in lines if line]
    joined = " ".join(lines)
    return WHITESPACE.sub(" ", joined).strip()


def split_sentences(post_text):
    if not post_text:
        return []
    return [s.strip() for s in SENTENCE_SPLIT.split(post_text) if s.strip()]


def iter_post_sentences(zip_path):
    """Yields (file_name, [sentence, sentence, ...]) for every <post> block
    in every blogger file in the zip, in archive order. One yield per post
    (not per file) so posts from the same blogger stay separately ordered."""
    with zipfile.ZipFile(zip_path) as zf:
        names = sorted(n for n in zf.namelist() if n.endswith(".xml"))
        for name in names:
            raw_bytes = zf.read(name)
            try:
                content = raw_bytes.decode("latin_1")
            except UnicodeDecodeError:
                continue
            for match in POST_BLOCK.finditer(content):
                post_text = clean_post_text(match.group(1))
                sentences = split_sentences(post_text)
                if sentences:
                    yield name, sentences


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
    if URLLINK_RESIDUE.search(golden):
        return "urllink_residue"
    if BLOGGER_BOILERPLATE.search(golden):
        return "blogger_boilerplate"
    if is_all_caps_shouting(golden):
        return "all_caps_shouting"
    if is_mostly_punctuation(golden):
        return "mostly_punctuation"
    if golden in seen_goldens:
        return "duplicate"
    return None


def build_prior_messages(sentences, idx):
    """Up to the last MAX_PRIOR_MESSAGES sentences preceding sentences[idx]
    within the same post, oldest first, each trimmed to PRIOR_MESSAGE_TRIM
    chars. Raw sentences (pre-filter) are used, same as their neighbor."""
    preceding = sentences[:idx]
    kept = preceding[-MAX_PRIOR_MESSAGES:]
    return [s[:PRIOR_MESSAGE_TRIM] for s in kept]


def sift_blog_posts(zip_path, min_words):
    """Scans every post's sentences, filters candidate goldens, and returns
    (kept_records, reject_counts, posts_scanned). Deterministic: no
    randomness, only depends on the input files and min_words."""
    reject_counts = {}
    seen_goldens = set()
    kept = []
    posts_scanned = 0

    for _file_name, sentences in iter_post_sentences(zip_path):
        posts_scanned += 1
        for idx, golden in enumerate(sentences):
            reason = classify_golden(golden, min_words, seen_goldens)
            if reason is not None:
                reject_counts[reason] = reject_counts.get(reason, 0) + 1
                continue

            seen_goldens.add(golden)
            kept.append(
                {
                    "source": BLOG_SOURCE,
                    "register": BLOG_REGISTER,
                    "app": BLOG_APP,
                    "text": golden,
                    "prior_messages": build_prior_messages(sentences, idx),
                    "ts": None,
                }
            )

    return kept, reject_counts, posts_scanned


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


def print_summary(posts_scanned, reject_counts, kept_before_limit, kept_count, out_path):
    print("== blog eval-corpus sift ==")
    print(f"posts scanned: {posts_scanned}")
    print("rejections by reason:")
    for reason in sorted(reject_counts):
        print(f"  {reason}: {reject_counts[reason]}")
    total_rejected = sum(reject_counts.values())
    print(f"total rejected: {total_rejected}")
    print(f"candidates passing all filters: {kept_before_limit}")
    print(f"kept (after deterministic limit): {kept_count}")
    print(f"output: {out_path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--min-words", type=int, default=DEFAULT_MIN_WORDS, help="minimum golden word count")
    parser.add_argument("--limit", type=int, default=2000, help="max rows to keep, deterministic by sha256(text)")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output JSONL path")
    args = parser.parse_args()

    if not BLOG_ZIP.exists():
        print("No blogs.zip found at " + str(BLOG_ZIP), file=sys.stderr)
        print("Download the dataset first with:", file=sys.stderr)
        print(f"  {BLOG_HF_DOWNLOAD_CMD}", file=sys.stderr)
        return 1

    kept, reject_counts, posts_scanned = sift_blog_posts(BLOG_ZIP, args.min_words)
    selected = select_deterministic(kept, args.limit)
    write_jsonl(selected, args.out)
    print_summary(posts_scanned, reject_counts, len(kept), len(selected), args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
