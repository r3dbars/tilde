#!/usr/bin/env python3
"""Converts ConvoKit's "reddit-corpus-small" (a sample of ~297k utterances
from 100 highly-active subreddits, with real comment -> parent-comment
reply_to linkage) into the SteadyType REPLY-corpus JSONL contract consumed
by the screen-response quiz. Output files live OUTSIDE the repo under
~/.cache/steadytype-eval and are never committed.

Why a direct download instead of `pip3 install convokit`: the convokit
package pulls in a heavy, slow-to-resolve dependency tree (spacy, sklearn,
matplotlib, ...) just to call `download()`, which itself only does an HTTP
GET of a static zip plus a local unzip. That URL is public and stable
(resolved empirically from convokit's own download_config.json on GitHub:
https://raw.githubusercontent.com/CornellNLP/ConvoKit/master/download_config.json,
key "reddit-corpus-small"), so this script fetches it directly with
curl + unzip and never imports convokit.

REPLY-corpus JSONL contract (one JSON object per line):
    {"source": "reddit",
     "register": "chat",
     "app": "com.hnc.Discord",
     "text": "<a real REPLY someone wrote>",
     "prior_messages": ["the message(s) being replied to, oldest first, up to 3"],
     "ts": null}

The corpus's utterances.json is a flat JSON array of utterance objects
(id, user, root, reply_to, timestamp, text, meta). An utterance with
reply_to set is a real reply to another utterance in the same file
(reply_to -> id). "root" is the id of the top-level submission; when an
utterance IS a submission (id == root) with no selftext (a link post),
its title (looked up in conversations.json, keyed by submission id) is
used as a stand-in body so it still reads as a real message.

For each candidate reply: "text" = the reply body (after cleaning), and
prior_messages = its immediate parent plus up to 2 grandparents, walked via
reply_to, oldest first. A reply is dropped entirely (not counted toward the
shared per-filter rejects below) if its immediate parent can't be resolved
to real text -- missing from the corpus, or itself exactly "[deleted]" /
"[removed]" / empty after cleaning -- because that breaks the "prior_messages
MUST contain the message it responds to" contract. Grandparents are best-
effort: the chain simply stops (without rejecting the reply) the first time
an ancestor can't be resolved.

Cleaning (applied to reply text and every ancestor in the chain): reddit
renders quoted markdown as literal lines starting with the HTML entity
"&gt;" (not a literal ">"), so each line is checked against its
HTML-unescaped form and dropped if it starts with ">" -- this is the
"leading '>' quote line" residue the task calls out, just entity-encoded.
Remaining lines are rejoined, HTML-unescaped for real (&amp; etc.), stripped
of stray zero-width spaces, and whitespace-collapsed.

Shared filters applied to the golden reply text only, each counted
separately: under 4 or over 60 words; no alphabetic characters; under 80%
ASCII-alpha of alpha characters; contains a URL; source-specific
markup/quote residue (exact "[deleted]"/"[removed]" bodies that survived
cleaning, leftover markdown -- bold/strikethrough/code fences/links --
and /r/subreddit or /u/username mentions, none of which read as prose a
person would actually finish typing); exact-duplicate reply text already
kept.

Fetch the dataset first with:
    mkdir -p ~/.cache/steadytype-eval
    curl -sL -o ~/.cache/steadytype-eval/reddit-corpus-small.corpus.zip \\
        https://zissou.infosci.cornell.edu/convokit/datasets/subreddit-corpus/reddit-corpus-small.corpus.zip
    unzip -o -q ~/.cache/steadytype-eval/reddit-corpus-small.corpus.zip \\
        -d ~/.cache/steadytype-eval/reddit-corpus-small
"""
import argparse
import hashlib
import html
import json
import re
import sys
from pathlib import Path

CACHE_ROOT = Path.home() / ".cache" / "steadytype-eval"
REDDIT_DIR = CACHE_ROOT / "reddit-corpus-small"
REDDIT_ZIP = CACHE_ROOT / "reddit-corpus-small.corpus.zip"
REDDIT_OUT = CACHE_ROOT / "reddit_eval.jsonl"
REDDIT_SOURCE = "reddit"
REDDIT_REGISTER = "chat"
REDDIT_APP = "com.hnc.Discord"
REDDIT_ZIP_URL = (
    "https://zissou.infosci.cornell.edu/convokit/datasets/subreddit-corpus/"
    "reddit-corpus-small.corpus.zip"
)
REDDIT_FETCH_CMDS = (
    f"mkdir -p {CACHE_ROOT}\n"
    f"  curl -sL -o {REDDIT_ZIP} {REDDIT_ZIP_URL}\n"
    f"  unzip -o -q {REDDIT_ZIP} -d {REDDIT_DIR}"
)

DEFAULT_MIN_WORDS = 4
MAX_WORDS = 60
MIN_ASCII_ALPHA_FRACTION = 0.8
PRIOR_MESSAGE_TRIM = 300
MAX_PRIOR_MESSAGES = 3
ZERO_WIDTH_SPACE = "​"

URL_PATTERN = re.compile(r"https?://|www\.", re.IGNORECASE)
DELETED_OR_REMOVED = re.compile(r"^\s*\[(deleted|removed)\]\s*$", re.IGNORECASE)
# Source-specific residue: literal placeholders, leftover markdown syntax,
# and /r/ or /u/ mentions -- none of these read as prose a person actually
# finished typing.
MARKUP_RESIDUE = re.compile(
    r"\[deleted\]|\[removed\]"
    r"|\[[^\]]*\]\([^)]*\)"  # markdown link
    r"|\*\*[^*]+\*\*"  # bold
    r"|~~[^~]+~~"  # strikethrough
    r"|`[^`]+`"  # inline code / code fence residue
    r"|(?:^|\s)/?r/\w+"  # subreddit mention
    r"|(?:^|\s)/?u/\w+",  # user mention
    re.IGNORECASE,
)


def text_digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def find_utterances_file(root):
    """Locates utterances.json under root, however deeply the zip's
    top-level folder nested it. Returns None if not found."""
    matches = sorted(root.rglob("utterances.json"))
    return matches[0] if matches else None


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


def clean_text(text):
    """Drops entity-encoded markdown quote lines ("&gt; quoted text"),
    rejoins the remaining lines, HTML-unescapes the result, strips stray
    zero-width spaces, and collapses internal whitespace runs."""
    kept_lines = []
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped:
            continue
        if html.unescape(stripped).lstrip().startswith(">"):
            continue
        kept_lines.append(stripped)
    joined = " ".join(kept_lines)
    joined = html.unescape(joined)
    joined = joined.replace(ZERO_WIDTH_SPACE, "")
    return " ".join(joined.split())


def resolve_raw_text(utterance, conversations):
    """An utterance's raw text, falling back to its submission's title
    (from conversations.json) when the utterance IS a submission (id ==
    root) with no selftext -- a link post."""
    text = utterance["text"] or ""
    if not text.strip() and utterance["id"] == utterance["root"]:
        text = conversations.get(utterance["root"], {}).get("title") or ""
    return text


def is_deleted_or_removed(cleaned_text):
    return bool(DELETED_OR_REMOVED.match(cleaned_text))


def build_ancestor_chain(reply_utterance, by_id, conversations):
    """Walks reply_to from reply_utterance up to MAX_PRIOR_MESSAGES
    ancestors, nearest (immediate parent) first. Returns None if the
    immediate parent can't be resolved to real, non-placeholder text --
    that invalidates the whole reply, since prior_messages must contain the
    message being responded to. Grandparents are best-effort: the walk
    just stops (keeping what it already has) the first time an ancestor
    can't be resolved."""
    chain = []
    cur_id = reply_utterance["reply_to"]
    while cur_id is not None and len(chain) < MAX_PRIOR_MESSAGES:
        ancestor = by_id.get(cur_id)
        if ancestor is None:
            break
        cleaned = clean_text(resolve_raw_text(ancestor, conversations))
        if not cleaned or is_deleted_or_removed(cleaned):
            break
        chain.append(cleaned)
        cur_id = ancestor["reply_to"]
    if not chain:
        return None
    return chain


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


def sift_reddit_rows(utterances, conversations, min_words):
    """Scans every utterance with a reply_to, filters candidate golden
    replies, and returns (kept_records, reject_counts, rows_scanned).
    Deterministic: no randomness, only depends on the input rows and
    min_words."""
    by_id = {u["id"]: u for u in utterances}
    replies = [u for u in utterances if u["reply_to"] is not None]

    reject_counts = {}
    seen_goldens = set()
    kept = []

    for reply in replies:
        chain = build_ancestor_chain(reply, by_id, conversations)
        if chain is None:
            reject_counts["no_valid_parent"] = reject_counts.get("no_valid_parent", 0) + 1
            continue

        golden = clean_text(reply["text"] or "")
        reason = classify_golden(golden, min_words, seen_goldens)
        if reason is not None:
            reject_counts[reason] = reject_counts.get(reason, 0) + 1
            continue

        seen_goldens.add(golden)
        prior_messages = list(reversed(chain))  # oldest first, immediate parent last
        kept.append(
            {
                "source": REDDIT_SOURCE,
                "register": REDDIT_REGISTER,
                "app": REDDIT_APP,
                "text": golden,
                "prior_messages": [p[:PRIOR_MESSAGE_TRIM] for p in prior_messages],
                "ts": None,
            }
        )

    return kept, reject_counts, len(replies)


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
    print("== reddit REPLY-corpus sift ==")
    print(f"replies scanned: {rows_scanned}")
    print("rejections by reason:")
    for reason in sorted(reject_counts):
        print(f"  {reason}: {reject_counts[reason]}")
    total_rejected = sum(reject_counts.values())
    print(f"total rejected: {total_rejected}")
    print(f"candidates passing all filters: {kept_before_limit}")
    print(f"kept (after deterministic limit): {kept_count}")
    print(f"output: {out_path}")


def cmd_reddit(args):
    utterances_path = find_utterances_file(REDDIT_DIR)
    if utterances_path is None:
        print("No utterances.json found under " + str(REDDIT_DIR), file=sys.stderr)
        print("Download the dataset first with:", file=sys.stderr)
        print(f"  {REDDIT_FETCH_CMDS}", file=sys.stderr)
        return 1
    conversations_path = utterances_path.parent / "conversations.json"
    if not conversations_path.exists():
        print("No conversations.json alongside " + str(utterances_path), file=sys.stderr)
        return 1

    with open(utterances_path, encoding="utf-8") as f:
        utterances = json.load(f)
    with open(conversations_path, encoding="utf-8") as f:
        conversations = json.load(f)

    kept, reject_counts, rows_scanned = sift_reddit_rows(utterances, conversations, args.min_words)
    selected = select_deterministic(kept, args.limit)
    out_path = Path(args.out).expanduser()
    write_jsonl(selected, out_path)
    print_summary(rows_scanned, reject_counts, len(kept), len(selected), out_path)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--min-words", type=int, default=DEFAULT_MIN_WORDS, help="minimum golden word count")
    parser.add_argument("--limit", type=int, default=2000, help="max rows to keep, deterministic by sha256(text)")
    parser.add_argument("--out", type=str, default=str(REDDIT_OUT), help="output JSONL path")
    parser.set_defaults(func=cmd_reddit)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
