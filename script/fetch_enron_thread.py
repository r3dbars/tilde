#!/usr/bin/env python3
"""Converts LLM-PBE/enron-email (raw Enron email bodies, one JSON object per
line, field "text") into the SteadyType REPLY-corpus JSONL contract used by
the screen-response quiz. Output files live OUTSIDE the repo under
~/.cache/steadytype-eval and are never committed.

REPLY-corpus JSONL contract (one JSON object per line):
    {"source": "enron_thread",
     "register": "email",
     "app": "com.apple.mail",
     "text": "<the NEW reply text a real person wrote>",
     "prior_messages": ["the quoted original message it replies to"],
     "ts": null}

Every Enron email body in this dataset is the FULL raw message: the new
reply text at the top, then (for reply/forward emails) a quoted copy of the
message being replied to below it, introduced by one of a handful of quote
styles this era of Outlook/Lotus Notes produced:

    -----Original Message-----
    From: ...
    To: ...
    Sent: ...
    Subject: ...

    <Name> <email> on MM/DD/YYYY HH:MM:SS AM/PM
    To: ...
    cc: ...
    Subject: ...

    ---------------------- Forwarded by <Name> on MM/DD/YYYY ----------

    <Name> wrote:
    > quoted line
    > quoted line

We find the EARLIEST such quote-start marker in the body (scanning top to
bottom); everything above it is candidate reply text (after stripping a
trailing contact/signature block), everything below it is the quoted
original (after stripping the header lines and cutting at any deeper nested
quote). Emails with no quote-start marker at all are not reply situations
and are skipped outright (not counted against the shared filters below,
which apply only to real reply candidates).

Fetch the dataset first with:
    hf download LLM-PBE/enron-email --repo-type dataset \\
        --local-dir ~/.cache/steadytype-eval/enron-email
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

CACHE_ROOT = Path.home() / ".cache" / "steadytype-eval"
ENRON_DIR = CACHE_ROOT / "enron-email"
ENRON_RAW_FILE = ENRON_DIR / "enron_email_all.jsonl"
ENRON_OUT = CACHE_ROOT / "enron_thread_eval.jsonl"
ENRON_SOURCE = "enron_thread"
ENRON_REGISTER = "email"
ENRON_APP = "com.apple.mail"
ENRON_HF_DOWNLOAD_CMD = (
    "hf download LLM-PBE/enron-email --repo-type dataset "
    f"--local-dir {ENRON_DIR}"
)

DEFAULT_MIN_WORDS = 4
MAX_WORDS = 60
MIN_ASCII_ALPHA_FRACTION = 0.8

MAX_PRIOR_MESSAGE_WORDS = 90
MAX_PRIOR_MESSAGE_CHARS = 600
MIN_PRIOR_MESSAGE_WORDS = 4
BACKWARD_ATTRIBUTION_WALK_CAP = 8  # lines

URL_PATTERN = re.compile(r"https?://|www\.", re.IGNORECASE)
ATTACHMENT_RESIDUE = re.compile(r"<<[^<>]+>>|\(See attached file:[^)]*\)", re.IGNORECASE)

# --- quote-start marker patterns (each finds the FIRST line of its kind) ---
ORIGINAL_MSG_DASHES = re.compile(r"^-{2,}\s*Original Message\s*-{2,}\s*$", re.IGNORECASE)
FORWARDED_BANNER = re.compile(r"-{2,}\s*Forwarded\s+(by|Message)\b", re.IGNORECASE)
ANGLE_QUOTE = re.compile(r"^\s*>")
WROTE_LINE = re.compile(r".+\bwrote\s*:\s*$", re.IGNORECASE)
# header lines that make up an Outlook/Lotus Notes quote-block preamble
HEADER_LINE = re.compile(
    r"^\s*(From|To|Cc|Bcc|Sent|Subject|Date|Importance|Attachments?)\s*:",
    re.IGNORECASE,
)
# raw SMTP/MIME transport headers -- these show up in a handful of bodies
# that are literally a forwarded raw message dump, not human reply text.
EMAIL_SERVER_HEADER = re.compile(
    r"^\s*(Return-Path|Received|Message-ID|MIME-Version|Content-Type|"
    r"Content-Transfer-Encoding|Reply-To|In-Reply-To|References|X-[\w-]+)\s*:",
    re.IGNORECASE,
)
# same header set, no line-start anchor -- for scanning the already-joined
# (newline-free) final reply text as a last defensive net.
EMAIL_SERVER_HEADER_ANYWHERE = re.compile(
    r"\b(Return-Path|Received: from|Message-ID|MIME-Version|Content-Type|"
    r"Content-Transfer-Encoding|Reply-To|In-Reply-To|References)\s*:",
    re.IGNORECASE,
)
DATE_TIME_LINE = re.compile(
    r"^\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2}(:\d{2})?\s*(AM|PM)?\s*$", re.IGNORECASE
)
INLINE_ATTRIBUTION_DATE = re.compile(
    r"\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2}(:\d{2})?\s*(AM|PM)?\s*$", re.IGNORECASE
)
PLEASE_RESPOND = re.compile(r"^Please respond to\b", re.IGNORECASE)
EMAIL_ANGLE = re.compile(r"<[^<>@\s]+@[^<>\s]+>")
# a leftover fragment of a wrapped "---- Forwarded by X on DATE \nHH:MM AM ----"
# banner: a continuation line made up only of a time and dashes.
BANNER_CONTINUATION_LINE = re.compile(r"^[\s\d:apmAPM-]+$")
EMAIL_TOKEN = re.compile(r"[\w.\-+']+@[\w.\-]+")


def is_header_continuation_line(line):
    """True for a line that's a wrapped continuation of a To:/Cc: header
    value: either a recipient list (2+ email addresses -- clearly a header
    value, even if names are quoted alongside), or a single bare email
    address with no other real words (e.g. '<parrino@mail.utexas.edu>')."""
    if "@" not in line:
        return False
    tokens = EMAIL_TOKEN.findall(line)
    if len(tokens) >= 2:
        return True
    residue = EMAIL_TOKEN.sub(" ", line)
    residue = re.sub(r"[<>\"';,]", " ", residue)
    return not any(len(w) >= 3 and w.isalpha() for w in residue.split())

# --- trailing signature/contact-block stripping (applied to reply text) ---
SIGNATURE_LINE = re.compile(
    r"^\s*(Thanks|Thank you|Regards|Best regards|Warm regards|Kind regards|"
    r"Best wishes|Best|Sincerely|Cheers|Warmly|Respectfully)\s*[,.]?\s*\S{0,25}\s*$",
    re.IGNORECASE,
)
CONTACT_BLOCK_LINE = re.compile(
    r"^\s*(Phone|Fax|Cell|Tel|Mobile|Office)\s*:|"
    r"\(?\d{3}\)?[-.\s]\d{3}[-.\s]\d{4}|"
    r"\bEnron Corp\b|\bManaging Director\b|\bVice President\b|"
    r"^\s*Room\s+\S+|"
    r"^\s*\d+\s+\w+\s+(Street|St|Ave|Avenue|Road|Rd|Blvd)\b|"
    r"^\s*[A-Za-z .]+,\s*[A-Z]{2}\s+\d{5}",
    re.IGNORECASE,
)
NAME_LINE = re.compile(r"^[A-Z][a-zA-Z.\-']*(\s+[A-Z][a-zA-Z.\-']*){0,3}$")

# defensive net: if any of these survive into the final reply text, the
# split logic missed something -- reject rather than ship quote residue.
QUOTE_RESIDUE_PATTERNS = [
    ORIGINAL_MSG_DASHES,
    FORWARDED_BANNER,
    ANGLE_QUOTE,
    WROTE_LINE,
    HEADER_LINE,
    EMAIL_SERVER_HEADER_ANYWHERE,
    ATTACHMENT_RESIDUE,
]


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


def find_direct_markers(lines):
    """Returns a dict of {line_index: marker_kind} for every marker that can
    be identified from its own line alone (no backward context needed)."""
    markers = {}
    for i, raw in enumerate(lines):
        line = raw.strip()
        if not line:
            continue
        if ORIGINAL_MSG_DASHES.match(line) and i not in markers:
            markers[i] = "original_msg_dashes"
        elif FORWARDED_BANNER.search(line) and i not in markers:
            markers[i] = "forwarded_banner"
        elif ANGLE_QUOTE.match(raw) and i not in markers:
            markers[i] = "angle_quote"
        elif WROTE_LINE.match(line) and i not in markers:
            markers[i] = "wrote_line"
    return markers


def find_attribution_block_start(lines, to_line_index):
    """Given the index of a "To:" header line, walks backward through the
    contiguous run of non-blank lines above it (capped at
    BACKWARD_ATTRIBUTION_WALK_CAP) looking for a Lotus-Notes-style sender
    attribution ("Name <email> on DATE TIME", split across a name line and a
    DATE_TIME_LINE, or a "Please respond to" line). Returns the index of the
    top of that run if the run contains real attribution evidence (a date or
    an angle-bracket email), else None."""
    start = to_line_index
    j = to_line_index - 1
    saw_attribution_evidence = False
    steps = 0
    while j >= 0 and steps < BACKWARD_ATTRIBUTION_WALK_CAP:
        line = lines[j].strip()
        if not line:
            break
        if DATE_TIME_LINE.match(line) or INLINE_ATTRIBUTION_DATE.search(line):
            saw_attribution_evidence = True
        if PLEASE_RESPOND.match(line) or EMAIL_ANGLE.search(line):
            saw_attribution_evidence = True
        start = j
        j -= 1
        steps += 1
    if not saw_attribution_evidence:
        return None
    return start


def find_split_index(lines):
    """Returns the line index where the quoted original begins (the
    earliest quote-start marker of any kind), or None if this body has no
    reply/quote structure at all."""
    candidates = []
    direct = find_direct_markers(lines)
    candidates.extend(direct.keys())
    for i, raw in enumerate(lines):
        if HEADER_LINE.match(raw.strip()) and raw.strip().lower().startswith("to"):
            block_start = find_attribution_block_start(lines, i)
            if block_start is not None:
                candidates.append(block_start)
    if not candidates:
        return None
    return min(candidates)


def strip_trailing_signature(reply_lines):
    """Pops trailing blank/signature/contact-block lines off the end of the
    candidate reply. A bare name line (e.g. "Vince") is only popped once
    we're already mid-signature-block (after popping a real signature or
    contact line), so a legitimate short final sentence is left alone."""
    lines = list(reply_lines)
    stripped_any_sig = False
    while lines:
        line = lines[-1]
        stripped = line.strip()
        if not stripped:
            lines.pop()
            continue
        if SIGNATURE_LINE.match(stripped) or CONTACT_BLOCK_LINE.search(stripped):
            lines.pop()
            stripped_any_sig = True
            continue
        if stripped_any_sig and NAME_LINE.match(stripped):
            lines.pop()
            continue
        break
    return lines


def build_reply_text(lines, split_index):
    reply_lines = lines[:split_index]
    reply_lines = strip_trailing_signature(reply_lines)
    # defensive: drop any stray header/quote lines that shouldn't be here
    reply_lines = [
        l
        for l in reply_lines
        if not HEADER_LINE.match(l.strip()) and not EMAIL_SERVER_HEADER.match(l.strip())
    ]
    joined = " ".join(l.strip() for l in reply_lines if l.strip())
    return " ".join(joined.split())


def build_prior_message(lines, split_index):
    """Extracts the quoted original message body starting at split_index:
    skips the marker line itself, skips the header preamble (From/To/Cc/
    Sent/Subject or "Please respond to"), skips blank lines, then collects
    body lines until a nested quote marker, a header line, or the length
    cap is hit."""
    n = len(lines)
    i = split_index
    if i >= n:
        return ""
    first = lines[i].strip()
    if ORIGINAL_MSG_DASHES.match(first) or FORWARDED_BANNER.search(first) or WROTE_LINE.match(first):
        i += 1
    # skip a wrapped forwarded-banner continuation line (date/time + dashes only)
    if i < n and FORWARDED_BANNER.search(first) and BANNER_CONTINUATION_LINE.match(lines[i].strip()):
        i += 1
    # skip header preamble: Please-respond-to / attribution date lines / header lines
    while i < n:
        s = lines[i].strip()
        if not s:
            i += 1
            continue
        if (
            HEADER_LINE.match(s)
            or EMAIL_SERVER_HEADER.match(s)
            or PLEASE_RESPOND.match(s)
            or DATE_TIME_LINE.match(s)
            or BANNER_CONTINUATION_LINE.match(s)
            or is_header_continuation_line(s)
            or (INLINE_ATTRIBUTION_DATE.search(s) and len(s.split()) < 12)
        ):
            i += 1
            continue
        break
    # skip a run of blank lines after the header preamble
    while i < n and not lines[i].strip():
        i += 1

    body_lines = []
    words_so_far = 0
    chars_so_far = 0
    while i < n:
        raw = lines[i]
        s = raw.strip()
        if not s:
            i += 1
            # a blank line right after we already have body content, followed
            # by another quote-start marker, signals the end of this quoted
            # message -- stop rather than swallow a second nested quote.
            if body_lines and i < n:
                nxt = lines[i].strip()
                if (
                    ORIGINAL_MSG_DASHES.match(nxt)
                    or FORWARDED_BANNER.search(nxt)
                    or ANGLE_QUOTE.match(lines[i])
                    or WROTE_LINE.match(nxt)
                    or HEADER_LINE.match(nxt)
                    or EMAIL_SERVER_HEADER.match(nxt)
                ):
                    break
            continue
        if ANGLE_QUOTE.match(raw):
            s = ANGLE_QUOTE.sub("", raw, count=1).strip()
            if not s:
                i += 1
                continue
        elif (
            ORIGINAL_MSG_DASHES.match(s)
            or FORWARDED_BANNER.search(s)
            or WROTE_LINE.match(s)
            or HEADER_LINE.match(s)
            or EMAIL_SERVER_HEADER.match(s)
        ):
            break
        body_lines.append(s)
        words_so_far += len(s.split())
        chars_so_far += len(s) + 1
        if words_so_far >= MAX_PRIOR_MESSAGE_WORDS or chars_so_far >= MAX_PRIOR_MESSAGE_CHARS:
            break
        i += 1

    joined = " ".join(body_lines)
    joined = " ".join(joined.split())
    return joined[:MAX_PRIOR_MESSAGE_CHARS]


def has_quote_residue(text):
    for pattern in QUOTE_RESIDUE_PATTERNS:
        if pattern.search(text):
            return True
    return False


def classify_candidate(reply_text, prior_text, min_words, seen_goldens):
    """Returns None if the candidate passes every shared filter, else a
    short rejection reason string. Does NOT mutate seen_goldens on
    rejection; the caller adds to seen_goldens only once accepted."""
    if not prior_text or not has_alpha(prior_text):
        return "empty_prior"
    if word_count(prior_text) < MIN_PRIOR_MESSAGE_WORDS:
        return "prior_too_short"
    prior_residue = URL_PATTERN.sub(" ", prior_text)
    if URL_PATTERN.search(prior_text) and not any(
        len(w) >= 3 and w.isalpha() for w in prior_residue.split()
    ):
        return "prior_is_url"
    if EMAIL_SERVER_HEADER_ANYWHERE.search(prior_text) or ATTACHMENT_RESIDUE.search(prior_text):
        return "prior_quote_residue"
    wc = word_count(reply_text)
    if wc < min_words:
        return "under_min_words"
    if wc > MAX_WORDS:
        return "over_max_words"
    if not has_alpha(reply_text):
        return "no_alpha"
    if not is_mostly_ascii(reply_text):
        return "non_ascii"
    if URL_PATTERN.search(reply_text):
        return "has_url"
    if ATTACHMENT_RESIDUE.search(reply_text):
        return "attachment_residue"
    if has_quote_residue(reply_text):
        return "quote_residue"
    if reply_text in seen_goldens:
        return "duplicate"
    return None


def sift_enron_rows(raw_lines_iter, min_words):
    """Scans every Enron email body, finds the earliest reply/quote split,
    builds a (reply_text, prior_message) candidate, filters it, and returns
    (kept_records, reject_counts, rows_scanned). Deterministic: no
    randomness, only depends on the input rows and min_words."""
    reject_counts = {}
    seen_goldens = set()
    kept = []
    rows_scanned = 0

    for raw_line in raw_lines_iter:
        raw_line = raw_line.strip()
        if not raw_line:
            continue
        try:
            obj = json.loads(raw_line)
        except (ValueError, json.JSONDecodeError):
            continue
        body = obj.get("text")
        if not body:
            continue
        rows_scanned += 1

        lines = body.split("\n")
        split_index = find_split_index(lines)
        if split_index is None or split_index == 0:
            reject_counts["no_quote_marker"] = reject_counts.get("no_quote_marker", 0) + 1
            continue

        reply_text = build_reply_text(lines, split_index)
        prior_text = build_prior_message(lines, split_index)

        reason = classify_candidate(reply_text, prior_text, min_words, seen_goldens)
        if reason is not None:
            reject_counts[reason] = reject_counts.get(reason, 0) + 1
            continue

        seen_goldens.add(reply_text)
        kept.append(
            {
                "source": ENRON_SOURCE,
                "register": ENRON_REGISTER,
                "app": ENRON_APP,
                "text": reply_text,
                "prior_messages": [prior_text],
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
    print("== enron_thread REPLY-corpus sift ==")
    print(f"emails scanned: {rows_scanned}")
    print("rejections by reason:")
    for reason in sorted(reject_counts):
        print(f"  {reason}: {reject_counts[reason]}")
    total_rejected = sum(reject_counts.values())
    print(f"total rejected: {total_rejected}")
    print(f"candidates passing all filters: {kept_before_limit}")
    print(f"kept (after deterministic limit): {kept_count}")
    print(f"output: {out_path}")


def cmd_enron_thread(args):
    raw_path = Path(args.raw_file).expanduser() if args.raw_file else ENRON_RAW_FILE
    if not raw_path.exists():
        print("No raw file found at " + str(raw_path), file=sys.stderr)
        print("Download the dataset first with:", file=sys.stderr)
        print(f"  {ENRON_HF_DOWNLOAD_CMD}", file=sys.stderr)
        return 1

    def raw_lines():
        with open(raw_path, "r", encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if args.max_scan is not None and i >= args.max_scan:
                    break
                yield line

    kept, reject_counts, rows_scanned = sift_enron_rows(raw_lines(), args.min_words)
    selected = select_deterministic(kept, args.limit)
    out_path = Path(args.out).expanduser()
    write_jsonl(selected, out_path)
    print_summary(rows_scanned, reject_counts, len(kept), len(selected), out_path)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--min-words", type=int, default=DEFAULT_MIN_WORDS, help="minimum reply word count")
    parser.add_argument("--limit", type=int, default=2000, help="max rows to keep, deterministic by sha256(text)")
    parser.add_argument("--out", type=str, default=str(ENRON_OUT), help="output JSONL path")
    parser.add_argument("--raw-file", type=str, default=None, help="override path to enron_email_all.jsonl")
    parser.add_argument("--max-scan", type=int, default=None, help="only scan the first N raw rows (debugging)")
    parser.set_defaults(func=cmd_enron_thread)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
