#!/usr/bin/env python3
"""Golden-continuation eval harness for the ghost brain (Smart Compose-style).

Replays real, human-finished messages against the RUNNING SteadyType ghost
brain and scores how well its suggestions predict what the author actually
typed next. Each corpus record's "text" is treated as ground truth: we cut it
at a deterministic word boundary to build a (context, golden-continuation)
pair, send the context to the brain over the same unix-socket protocol as
script/quality_probe.py, and compare the returned suggestion against the
golden continuation.

Corpus JSONL contract (one JSON object per line), data lives OUTSIDE the repo
under ~/.cache/steadytype-eval and is never committed:
    {"source": "discord|imessage|enron|aeslc|blog",
     "register": "chat|email|prose",
     "app": "<host app bundle id>",
     "text": "<a full real message exactly as its human author finished it>",
     "prior_messages": ["up to 3 earlier turns for context, oldest first"],
     "ts": "ISO8601, optional"}

Screen-context A/B (--context): the brain accepts an optional "page" field
that overrides its live screen-OCR resolver. --context off (default) sends
"page":"" forcing NO screen context — the clean baseline arm. --context prior
sends the record's prior_messages joined as the page text, simulating what
screen OCR would capture (the conversation being replied to). --context live
omits the field entirely, leaving the app's real resolver in charge. The
typed "context" string is always built solely from a prefix of the record's
own "text".

Run with --selftest to validate the cut + scoring logic offline (no socket,
no corpus file needed). Otherwise pass one or more --corpus files and the
SteadyType app must already be running (unix socket at
~/Library/Application Support/SteadyType/ghost.sock).
"""
import argparse
import hashlib
import json
import socket
import sys
import time

SOCK = "/Users/redbars/Library/Application Support/SteadyType/ghost.sock"

CUT_FRACTIONS = (0.4, 0.6, 0.8)
MIN_CONTEXT_WORDS = 3
MIN_GOLDEN_WORDS = 2


def text_digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def pick_cut_fraction(text):
    """Deterministically choose a cut fraction from CUT_FRACTIONS using the
    sha256 of the text, so re-running the eval on the same corpus always
    quizzes the same (context, golden) split per record."""
    digest = text_digest(text)
    idx = int(digest[:8], 16) % len(CUT_FRACTIONS)
    return CUT_FRACTIONS[idx]


def build_quiz(text):
    """Cut `text` at a word boundary to build (context, golden). Returns None
    if the record doesn't have enough words on both sides of the cut.

    The context string MUST end with exactly one trailing space after the
    cut word. The ghost brain infers completion mode from the context tail:
    a context ending in a letter/digit is mid-word (word-completion mode,
    phrase engine silent), while a trailing space after a whole word puts it
    in phrase mode. Cutting at a word boundary and appending a single space
    is what makes the brain treat this as a phrase-continuation request
    instead of a word-completion request.
    """
    words = text.split()
    if len(words) < MIN_CONTEXT_WORDS + MIN_GOLDEN_WORDS:
        return None
    fraction = pick_cut_fraction(text)
    cut = int(round(len(words) * fraction))
    cut = max(MIN_CONTEXT_WORDS, min(cut, len(words) - MIN_GOLDEN_WORDS))
    context_words = words[:cut]
    golden_words = words[cut:]
    if len(context_words) < MIN_CONTEXT_WORDS or len(golden_words) < MIN_GOLDEN_WORDS:
        return None
    context = " ".join(context_words) + " "  # single trailing space: see docstring
    golden = " ".join(golden_words)
    return context, golden


def normalize_word(word):
    return word.lower().strip(".,!?;:\"'()[]{}")


def build_page(record, mode):
    """Build the request's "page" value for a context mode: "" forces no
    screen context, a non-empty string is used as the OCR page text, and
    None omits the field (live resolver behavior)."""
    if mode == "live":
        return None
    if mode == "prior":
        prior = [p for p in record.get("prior_messages", []) if p.strip()]
        return "\n".join(prior)
    return ""


def connect_with_retry(sock_path, timeout, retries=20, retry_wait=3.0):
    """Connect to the brain socket, retrying while the app is down/restarting
    (a watchdog may relaunch it). Raises after the last attempt fails."""
    for attempt in range(retries + 1):
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(timeout)
        try:
            s.connect(sock_path)
            return s
        except (ConnectionRefusedError, FileNotFoundError):
            s.close()
            if attempt == retries:
                raise
            time.sleep(retry_wait)


def ask(ctx, app, sock_path=SOCK, timeout=60, page=None):
    s = connect_with_retry(sock_path, timeout)
    t0 = time.time()
    request = {"v": 1, "context": ctx, "app": app, "field": "golden-eval"}
    if page is not None:
        request["page"] = page
    s.sendall((json.dumps(request) + "\n").encode())
    buf = b""
    while True:
        c = s.recv(4096)
        if not c:
            return "", int((time.time() - t0) * 1000), False
        buf += c
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            o = json.loads(line)
            if not o.get("partial"):
                return o.get("suggestion", ""), int((time.time() - t0) * 1000), bool(o.get("page"))


def exact_match_at_n(suggestion, golden, n):
    sug_words = [normalize_word(w) for w in suggestion.split()][:n]
    gold_words = [normalize_word(w) for w in golden.split()][:n]
    if len(sug_words) < n or len(gold_words) < n:
        return False
    return sug_words == gold_words


def keystrokes_saved(suggestion, golden):
    """Count consecutive matching words from the start of suggestion vs
    golden (case/punctuation-normalized). Return keystrokes saved = sum of
    len(word) + 1 (for the trailing space) over matched words."""
    sug_words = suggestion.split()
    gold_words = golden.split()
    matched = 0
    for sw, gw in zip(sug_words, gold_words):
        if normalize_word(sw) != normalize_word(gw):
            break
        matched += 1
    # Deliberate: counts the RAW suggestion's characters (what accepting
    # actually inserts), not the normalized/golden form.
    saved = sum(len(w) + 1 for w in sug_words[:matched])
    return matched, saved


def new_bucket():
    return {
        "total": 0,
        "skipped": 0,
        "spoke": 0,
        "em1_all": 0,
        "em2_all": 0,
        "em3_all": 0,
        "em1_spoken": 0,
        "em2_spoken": 0,
        "em3_spoken": 0,
        "keystrokes_total": 0,
        "page_attached": 0,
        "latencies": [],
    }


def record_result(bucket, spoke, em1, em2, em3, saved, latency_ms):
    bucket["total"] += 1
    bucket["latencies"].append(latency_ms)
    if spoke:
        bucket["spoke"] += 1
        bucket["keystrokes_total"] += saved
        if em1:
            bucket["em1_spoken"] += 1
        if em2:
            bucket["em2_spoken"] += 1
        if em3:
            bucket["em3_spoken"] += 1
    if em1:
        bucket["em1_all"] += 1
    if em2:
        bucket["em2_all"] += 1
    if em3:
        bucket["em3_all"] += 1


def percentile(sorted_vals, pct):
    if not sorted_vals:
        return 0
    idx = min(len(sorted_vals) - 1, int(round(pct * (len(sorted_vals) - 1))))
    return sorted_vals[idx]


def summarize(name, bucket):
    total = bucket["total"]
    spoke = bucket["spoke"]
    lines = []
    lines.append(f"-- {name} --")
    lines.append(f"cases: {total}  skipped: {bucket['skipped']}")
    if total == 0:
        return "\n".join(lines)
    spoke_rate = spoke / total
    lines.append(f"spoke rate: {spoke}/{total} ({spoke_rate:.1%})")
    for n in (1, 2, 3):
        all_hits = bucket[f"em{n}_all"]
        spoken_hits = bucket[f"em{n}_spoken"]
        all_rate = all_hits / total
        spoken_rate = (spoken_hits / spoke) if spoke else 0.0
        lines.append(
            f"ExactMatch@{n}: {all_hits}/{total} ({all_rate:.1%}) over all cases, "
            f"{spoken_hits}/{spoke} ({spoken_rate:.1%}) over spoken cases"
        )
    ks_total = bucket["keystrokes_total"]
    ks_mean = (ks_total / spoke) if spoke else 0.0
    lines.append(f"keystrokes saved: total {ks_total}, mean/spoken-case {ks_mean:.1f}")
    lat = sorted(bucket["latencies"])
    p50 = percentile(lat, 0.50)
    p95 = percentile(lat, 0.95)
    lines.append(f"latency: p50 {p50}ms  p95 {p95}ms  max {lat[-1]}ms")
    lines.append(f"screen context attached: {bucket['page_attached']}/{total}")
    return "\n".join(lines)


def load_corpus(paths):
    records = []
    for path in paths:
        with open(path, "r", encoding="utf-8") as f:
            for line_no, line in enumerate(f, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError as e:
                    print(f"skip malformed line {path}:{line_no}: {e}", file=sys.stderr)
                    continue
                records.append(obj)
    return records


def subsample(records, limit):
    if limit is None or limit >= len(records):
        return records
    ordered = sorted(records, key=lambda r: text_digest(r.get("text", "")))
    return ordered[:limit]


def run_eval(records, sleep_s, verbose_k, sock_path=SOCK, context_mode="off"):
    overall = new_bucket()
    by_register = {}
    by_source = {}
    mismatch_examples = []
    aborted = None

    for case_no, rec in enumerate(records, start=1):
        text = rec.get("text", "")
        register = rec.get("register", "unknown")
        source = rec.get("source", "unknown")
        app = rec.get("app", "")

        quiz = build_quiz(text)
        if quiz is None:
            overall["skipped"] += 1
            by_register.setdefault(register, new_bucket())["skipped"] += 1
            by_source.setdefault(source, new_bucket())["skipped"] += 1
            continue

        context, golden = quiz
        page = build_page(rec, context_mode)
        try:
            suggestion, latency_ms, page_attached = ask(context, app, sock_path=sock_path, page=page)
        except (OSError, ConnectionError) as e:
            # Never lose a partial run: stop here and report what completed.
            aborted = f"aborted at case {case_no}/{len(records)}: {e}"
            break
        spoke = bool(suggestion.strip())
        em1 = exact_match_at_n(suggestion, golden, 1)
        em2 = exact_match_at_n(suggestion, golden, 2)
        em3 = exact_match_at_n(suggestion, golden, 3)
        _, saved = keystrokes_saved(suggestion, golden)

        reg_bucket = by_register.setdefault(register, new_bucket())
        src_bucket = by_source.setdefault(source, new_bucket())
        for bucket in (overall, reg_bucket, src_bucket):
            record_result(bucket, spoke, em1, em2, em3, saved, latency_ms)
            if page_attached:
                bucket["page_attached"] += 1

        if verbose_k and not em1 and len(mismatch_examples) < verbose_k:
            mismatch_examples.append((context, golden, suggestion))

        if sleep_s > 0:
            time.sleep(sleep_s)

    return overall, by_register, by_source, mismatch_examples, aborted


def print_report(overall, by_register, by_source, mismatch_examples, aborted=None):
    if aborted:
        print(f"!! {aborted} — report covers completed cases only\n")
    print(summarize("overall", overall))
    print()
    for register in sorted(by_register):
        print(summarize(f"register={register}", by_register[register]))
        print()
    for source in sorted(by_source):
        print(summarize(f"source={source}", by_source[source]))
        print()
    if mismatch_examples:
        print("-- mismatch examples --")
        for context, golden, suggestion in mismatch_examples:
            print(f"context:  ...{context[-60:]!r}")
            print(f"golden:   {golden[:60]!r}")
            print(f"got:      {suggestion[:60]!r}")
            print()


def make_synthetic_corpus():
    """~6 inline synthetic records for --selftest: no socket, no corpus file."""
    return [
        {
            "source": "discord",
            "register": "chat",
            "app": "com.hnc.Discord",
            "text": "yeah honestly I think we should just wait until tomorrow to ship it",
        },
        {
            "source": "enron",
            "register": "email",
            "app": "com.apple.mail",
            "text": "Thanks for the quick turnaround on this, the revised numbers look good to me",
        },
        {
            "source": "blog",
            "register": "prose",
            "app": "com.apple.TextEdit",
            "text": "The most surprising result of the experiment was how quickly the model converged",
        },
        {
            "source": "imessage",
            "register": "chat",
            "app": "com.apple.MobileSMS",
            "text": "running a bit late but I can still make the seven o clock reservation",
        },
        {
            "source": "aeslc",
            "register": "email",
            "app": "com.microsoft.Outlook",
            "text": "I would love to set up a call next week to walk through the proposal",
        },
        {
            "source": "discord",
            "register": "chat",
            "app": "com.hnc.Discord",
            "text": "too",
        },
    ]


def selftest():
    # 1. cut determinism: same text always yields the same fraction/cut.
    text = "the quick brown fox jumps over the lazy dog again and again today"
    f1 = pick_cut_fraction(text)
    f2 = pick_cut_fraction(text)
    assert f1 == f2, "cut fraction must be deterministic for the same text"
    assert f1 in CUT_FRACTIONS

    quiz1 = build_quiz(text)
    quiz2 = build_quiz(text)
    assert quiz1 == quiz2, "build_quiz must be deterministic"
    context, golden = quiz1
    assert context.endswith(" ") and not context.endswith("  "), "context must end with exactly one space"
    assert not context[-2].isspace(), "only one trailing space, not a run of them"
    assert len(context.split()) >= MIN_CONTEXT_WORDS
    assert len(golden.split()) >= MIN_GOLDEN_WORDS
    assert context.strip() + " " + golden == text, "context+golden must reconstruct the original text"

    # 2. too-short records are skipped.
    assert build_quiz("hi there") is None, "too few words overall should skip"
    assert build_quiz("a b c d") is None or len(build_quiz("a b c d")[1].split()) >= MIN_GOLDEN_WORDS

    # 3. normalize_word strips case/punctuation.
    assert normalize_word("Hello,") == "hello"
    assert normalize_word("WORLD!") == "world"
    assert normalize_word("don't") == "don't"

    # 4. exact_match_at_n hits and misses.
    assert exact_match_at_n("thanks for the help", "thanks for the help today", 3) is True
    assert exact_match_at_n("Thanks, for the", "thanks for the", 3) is True  # punctuation-insensitive
    assert exact_match_at_n("thanks a lot", "thanks for the", 2) is False
    assert exact_match_at_n("thanks", "thanks for the", 2) is False  # suggestion too short for N

    # 5. keystrokes_saved arithmetic: matched, saved.
    matched, saved = keystrokes_saved("thanks for the help", "thanks for the meeting")
    assert matched == 3, matched
    expected_saved = len("thanks") + 1 + len("for") + 1 + len("the") + 1
    assert saved == expected_saved, (saved, expected_saved)

    matched0, saved0 = keystrokes_saved("nope entirely different", "thanks for the meeting")
    assert matched0 == 0
    assert saved0 == 0

    matched_full, saved_full = keystrokes_saved("thanks for the", "thanks for the")
    assert matched_full == 3
    assert saved_full == expected_saved

    # 6. scoring bucket bookkeeping via record_result, using synthetic corpus
    # to also exercise build_quiz across varied lengths (incl. the 1-word
    # "too" record which must be skipped).
    synthetic = make_synthetic_corpus()
    quizzed = 0
    skipped = 0
    for rec in synthetic:
        q = build_quiz(rec["text"])
        if q is None:
            skipped += 1
        else:
            quizzed += 1
    assert skipped == 1, f"expected exactly the 1-word record to be skipped, got {skipped}"
    assert quizzed == len(synthetic) - 1

    # exercise record_result/summarize end-to-end without a socket.
    bucket = new_bucket()
    cases = [
        (True, True, True, False, 10, 120),   # spoke, EM1, EM2, not EM3
        (True, False, False, False, 0, 80),   # spoke, no matches
        (False, False, False, False, 0, 200),  # silent
    ]
    for spoke, em1, em2, em3, saved, latency in cases:
        record_result(bucket, spoke, em1, em2, em3, saved, latency)
    assert bucket["total"] == 3
    assert bucket["spoke"] == 2
    assert bucket["em1_all"] == 1
    assert bucket["em1_spoken"] == 1
    assert bucket["em2_all"] == 1
    assert bucket["em3_all"] == 0
    assert bucket["keystrokes_total"] == 10
    summary_text = summarize("selftest-bucket", bucket)
    assert "spoke rate: 2/3" in summary_text
    assert "ExactMatch@1: 1/3" in summary_text

    # 7. build_page context-arm construction.
    rec_with_prior = {"prior_messages": ["hey are you coming tonight", "we're at the usual spot"]}
    assert build_page(rec_with_prior, "off") == ""
    assert build_page(rec_with_prior, "live") is None
    assert build_page(rec_with_prior, "prior") == "hey are you coming tonight\nwe're at the usual spot"
    assert build_page({}, "prior") == "", "no priors -> empty page (forces none)"

    # 8. percentile sanity.
    assert percentile([10, 20, 30, 40, 50], 0.50) == 30
    assert percentile([], 0.50) == 0

    # 9. subsample determinism and ordering by sha256(text).
    recs = [{"text": f"record number {i} with enough words to pass"} for i in range(10)]
    sub_a = subsample(recs, 4)
    sub_b = subsample(recs, 4)
    assert [r["text"] for r in sub_a] == [r["text"] for r in sub_b], "subsample must be deterministic"
    assert len(sub_a) == 4
    expected_order = sorted(recs, key=lambda r: text_digest(r["text"]))[:4]
    assert sub_a == expected_order

    print("selftest OK: cut determinism, quiz skip logic, exact-match, keystrokes, bucket scoring, subsampling all pass")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", action="append", default=[], help="path to a corpus JSONL file (repeatable)")
    parser.add_argument("--limit", type=int, default=None, help="deterministic subsample size (order by sha256 of text)")
    parser.add_argument("--verbose", type=int, default=0, metavar="K", help="print K mismatch examples")
    parser.add_argument("--sleep", type=float, default=0.25, help="seconds to sleep between cases")
    parser.add_argument("--sock", default=SOCK, help="path to the ghost brain unix socket")
    parser.add_argument(
        "--context", choices=("off", "prior", "live"), default="off",
        help="screen-context arm: off = force none (clean baseline), "
             "prior = send prior_messages as the OCR page, live = app resolver decides"
    )
    parser.add_argument("--selftest", action="store_true", help="run offline self-test of cut/scoring logic and exit")
    args = parser.parse_args()

    if args.selftest:
        selftest()
        return 0

    if not args.corpus:
        parser.error("--corpus PATH is required (repeatable) unless --selftest is passed")

    records = load_corpus(args.corpus)
    records = subsample(records, args.limit)
    if not records:
        print("no records loaded from corpus", file=sys.stderr)
        return 1

    overall, by_register, by_source, mismatch_examples, aborted = run_eval(
        records, sleep_s=args.sleep, verbose_k=args.verbose, sock_path=args.sock,
        context_mode=args.context
    )
    print_report(overall, by_register, by_source, mismatch_examples, aborted)
    return 1 if aborted else 0


if __name__ == "__main__":
    sys.exit(main())
