#!/usr/bin/env python3
"""Quality probe for the ghost brain: a fixed corpus across registers, scored
for the failure modes dogfood has surfaced. Run before and after any prompt or
cleaner change; compare the summary lines. Requires the SteadyType app running.
"""
import json
import socket
import sys
import time

SOCK = "/Users/redbars/Library/Application Support/SteadyType/ghost.sock"

CORPUS = [
    ("chat", "com.tinyspeck.slackmacgap", "yeah lol that makes sense, I think we "),
    ("chat", "com.tinyspeck.slackmacgap", "ok sounds good, let's plan to "),
    ("chat", "com.anthropic.claudefordesktop", "damn this is working way better than "),
    ("chat", "com.tinyspeck.slackmacgap", "I'm running a bit late but I can "),
    ("chat", "com.hnc.Discord", "honestly the new build feels "),
    ("email", "com.apple.mail", "Hi Sarah, thanks for the proposal. My main concern is the timeline, since we "),
    ("email", "com.apple.mail", "Just following up on my last note — I wanted to "),
    ("email", "com.apple.mail", "Thanks for the quick turnaround. The revised numbers look "),
    ("email", "com.microsoft.Outlook", "I'd love to set up a call next week to "),
    ("prose", "com.apple.TextEdit", "The architecture of the system means that we "),
    ("prose", "com.apple.TextEdit", "The most surprising result of the experiment was "),
    ("prose", "md.obsidian", "Three factors explain the improvement. First, the "),
    ("prose", "com.apple.TextEdit", "After the migration, the team noticed that "),
    ("question", "com.anthropic.claudefordesktop", "Okay let's see how good this is at predicting what I want to say back to the message that you gave us? "),
]

PERSONA = ["as an ai", "language model", "ai chatbot", "i cannot assist", "i can't assist"]


def ask(ctx, app):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(60)
    s.connect(SOCK)
    t0 = time.time()
    s.sendall((json.dumps({"v": 1, "context": ctx, "app": app, "field": "quality-probe"}) + "\n").encode())
    buf = b""
    while True:
        c = s.recv(4096)
        if not c:
            return "", 0
        buf += c
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            o = json.loads(line)
            if not o.get("partial"):
                return o.get("suggestion", ""), int((time.time() - t0) * 1000)


NEVER_END_ON = {
    "a", "an", "the", "of", "on", "in", "to", "at", "by", "as", "if",
    "and", "or", "but", "with", "for", "from", "that", "than", "so",
    "my", "your", "our", "their", "his", "her", "its", "is", "are",
    "was", "be", "been", "will", "would", "can", "could", "should",
    "very", "more", "most", "quite", "really",
}


def dangling(text):
    words = text.rstrip().rstrip(".!?,;:").split()
    return bool(words) and words[-1].lower().strip(".,") in NEVER_END_ON


def main():
    total = spoke = persona = frag = 0
    latencies = []
    for register, app, ctx in CORPUS:
        text, ms = ask(ctx, app)
        total += 1
        latencies.append(ms)
        flags = []
        if text.strip():
            spoke += 1
            low = text.lower()
            if any(m in low for m in PERSONA):
                persona += 1
                flags.append("PERSONA")
            if dangling(text):
                frag += 1
                flags.append("DANGLING")
        else:
            flags.append("silent")
        print(f"[{register:8s}] {ms:4d}ms {' '.join(flags):10s} {ctx[-32:]!r} -> {text[:52]!r}")
        time.sleep(0.4)

    latencies.sort()
    print("\n== summary ==")
    print(f"spoke: {spoke}/{total}  persona leaks: {persona}  dangling fragments: {frag}")
    print(f"latency p50 {latencies[len(latencies)//2]}ms  max {latencies[-1]}ms")
    return 0


if __name__ == "__main__":
    sys.exit(main())
