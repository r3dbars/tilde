#!/usr/bin/env python3
"""Self-test for the two data paths whose failures are invisible.

Both bugs guarded here shipped on 2026-07-29 and neither could be caught by
the Swift suite: one silently mis-assigned rows across the train/exam split,
the other silently deleted the writer's own journal entries. Failures in this
class do not crash and do not show up on screen — they just quietly produce
wrong data, which is the worst kind.

Run: python3 script/eval_hygiene_self_test.py     (exit 0 = all pass)
"""
import datetime
import importlib.util
import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
FAILURES = []


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(label, condition, detail=""):
    if condition:
        print(f"  PASS  {label}")
    else:
        print(f"  FAIL  {label}{(' — ' + detail) if detail else ''}")
        FAILURES.append(label)


# --------------------------------------------------------------- session map
def test_session_map():
    print("session split (script/live_quiz.py)")
    lq = load("lq", os.path.join(HERE, "live_quiz.py"))

    # Capture stamps are one-second resolution and the real logs already hold
    # 11 timestamps shared by two different apps. Keyed by ts alone, whichever
    # app sorted last silently overwrote the other's session — which can flip a
    # row to the wrong side of the train/exam split, the exact leak session
    # splitting exists to close.
    same_second = [
        {"ts": "2026-07-29T14:00:00Z", "app": "com.apple.mail"},
        {"ts": "2026-07-29T14:00:00Z", "app": "com.tinyspeck.slackmacgap"},
    ]
    smap = lq.build_session_map(same_second)
    check("two apps in the same second keep separate sessions",
          len(smap) == 2, f"got {len(smap)} entries")
    check("sessions are keyed by (app, ts)",
          all(isinstance(k, tuple) and len(k) == 2 for k in smap))

    # A gap longer than SESSION_GAP_S starts a new session; a shorter one does not.
    run = [{"ts": "2026-07-29T10:00:00Z", "app": "A"},
           {"ts": "2026-07-29T10:05:00Z", "app": "A"},
           {"ts": "2026-07-29T12:00:00Z", "app": "A"}]
    sessions = set(lq.build_session_map(run).values())
    check("a long pause starts a new session, a short one does not",
          len(sessions) == 2, f"got {len(sessions)} sessions")

    # Events may arrive shaped either way depending on the caller.
    mixed = [{"ts": "2026-07-29T10:00:00Z", "app_bundle": "A"},
             {"ts": "2026-07-29T10:01:00Z", "app": "A"}]
    check("handles both 'app' and 'app_bundle' shapes",
          len(set(lq.build_session_map(mixed).values())) == 1)

    # Unparseable timestamps must not crash or silently merge everything.
    junk = [{"ts": "garbage", "app": "A"}, {"ts": "2026-07-29T10:00:00Z", "app": "A"}]
    try:
        lq.build_session_map(junk)
        check("survives unparseable timestamps", True)
    except Exception as exc:                                  # noqa: BLE001
        check("survives unparseable timestamps", False, repr(exc))

    # A row absent from the map must read as "unknown", never as a session id.
    check("unknown (app, ts) looks up as None",
          lq.build_session_map(same_second).get(("nope", "1999-01-01T00:00:00Z")) is None)


# ----------------------------------------------------------------- organizer
def test_journal_organizer():
    print("journal organizer (script/journal_organize.py)")
    jo = load("jo", os.path.join(HERE, "journal_organize.py"))
    root = tempfile.mkdtemp(prefix="tilde-journal-selftest-")
    try:
        jo.USAGE = root
        jo.DAILY = os.path.join(root, "daily")
        jo.STORE = os.path.join(jo.DAILY, ".entries.jsonl")

        mac_a = os.path.join(root, "typing_journal_MacA.jsonl")
        mac_b = os.path.join(root, "typing_journal_MacB.jsonl")
        with open(mac_a, "w") as f:
            f.write(json.dumps({"ts": "2026-07-29T14:00:00Z",
                                "app_bundle": "com.apple.mail",
                                "text": "an entry written on the first mac"}) + "\n")
        with open(mac_b, "w") as f:
            f.write(json.dumps({"ts": "2026-07-29T14:05:00Z",
                                "app_bundle": "com.tinyspeck.slackmacgap",
                                "text": "an entry written on the second mac"}) + "\n")
            # Valid JSON, but not an object — plausible from a truncated write.
            # This used to raise AttributeError and abort the run; because the
            # source stream is append-only and never pruned, that broke every
            # future run, not just the one that hit it.
            f.write("42\n")
            f.write("{not json at all\n")

        jo.main()
        page = os.path.join(jo.DAILY, "2026-07-29.md")
        check("a malformed line does not abort the run", os.path.exists(page))
        text = open(page).read() if os.path.exists(page) else ""
        check("entries from both devices are rendered",
              "first mac" in text and "second mac" in text)

        # The destructive case: a device goes offline, or iCloud has not
        # materialised its file yet. Rebuilding the page from only what is
        # readable right now would erase entries already published.
        os.remove(mac_b)
        jo.main()
        text = open(page).read()
        check("a vanished device does not erase what it already contributed",
              "second mac" in text)
        check("the surviving device is still rendered", "first mac" in text)

        # Re-running must not duplicate.
        jo.main()
        text = open(page).read()
        check("re-running is idempotent", text.count("first mac") == 1)
    finally:
        shutil.rmtree(root, ignore_errors=True)


if __name__ == "__main__":
    test_session_map()
    print()
    test_journal_organizer()
    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} check(s): {', '.join(FAILURES)}")
        sys.exit(1)
    print("all eval-hygiene checks passed")
