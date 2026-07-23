#!/usr/bin/env python3
"""OCR-accuracy harness: the missing referee for the app's "eyes".

The language quiz feeds the model CLEAN text as a stand-in for OCR, so it never
tests whether the OCR actually reads the screen correctly. This does: it renders
images with KNOWN ground-truth text (real messages/emails/prose from the diverse
corpus, at varied sizes/contrast), runs them through the app's exact Vision OCR
settings (script/ocr_probe.swift, honoring the STEADYTYPE_OCR_* knobs), and
scores the reading against the truth.

Metrics per image: similarity (difflib ratio on normalized text) and word recall
(fraction of ground-truth words the OCR captured), plus latency.

Usage:
  python3 script/ocr_eval.py --generate         # build the test image set once
  python3 script/ocr_eval.py --run              # score current OCR knobs (from env)
  python3 script/ocr_eval.py --sweep            # try knob combos, rank them

Data lives under ~/.cache/steadytype-eval/ocr_test (never committed).
"""
import argparse
import difflib
import json
import os
import re
import subprocess
import sys
import time

CACHE = os.path.expanduser("~/.cache/steadytype-eval")
OCR_DIR = os.path.join(CACHE, "ocr_test")
GT_FILE = os.path.join(OCR_DIR, "ground_truth.jsonl")
PROBE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ocr_probe.swift")
DIVERSE = os.path.join(CACHE, "diverse_eval.jsonl")

FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"


def sample_texts():
    """Real messages/emails/prose from the diverse corpus for realistic screen
    content, plus a couple of crafted UI-ish lines. Deterministic order."""
    texts = []
    if os.path.exists(DIVERSE):
        rows = [json.loads(l) for l in open(DIVERSE)]
        rows.sort(key=lambda r: r.get("text", ""))
        by_reg = {}
        for r in rows:
            by_reg.setdefault(r.get("register", "?"), []).append(r["text"])
        for reg in ("chat", "email", "prose"):
            for t in by_reg.get(reg, [])[:3]:
                texts.append((reg, t))
    texts.append(("ui", "Send me the Q3 report when you get a chance, thanks!"))
    texts.append(("ui", "Meeting moved to 3pm in the small conference room."))
    return texts


def _font(px):
    from PIL import ImageFont
    return ImageFont.truetype(FONT, px)


def _wrap(text, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        if len(cur) + len(w) + 1 > width:
            lines.append(cur); cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur:
        lines.append(cur)
    return lines


def render_hard(records):
    """Realistic mockups where the target text is surrounded by distractor
    chrome (sidebars, names, timestamps), in colored bubbles, small fonts, and
    low-contrast / dark-mode conditions — the cases that actually break OCR.
    Ground truth is the TARGET message only, not the chrome."""
    from PIL import Image, ImageDraw
    idx = len(records)
    out = []
    DISTRACT = ["Alex Rivera", "9:41 AM", "Jordan", "Yesterday", "Design team",
                "Re: budget", "typing…", "3 unread", "Inbox (12)", "Mom"]

    def chat(text, dark, small, name):
        nonlocal idx
        W, H = 720, 300
        bg = (24, 25, 28) if dark else (255, 255, 255)
        side = (34, 35, 39) if dark else (244, 245, 247)
        muted = (120, 122, 128)
        bubble = (11, 94, 215) if not dark else (11, 94, 215)   # blue bubble
        bubble_txt = (255, 255, 255)
        img = Image.new("RGB", (W, H), bg)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, 190, H], fill=side)
        for i in range(5):
            d.text((14, 18 + i * 42), DISTRACT[i % len(DISTRACT)], font=_font(12), fill=muted)
            d.text((14, 34 + i * 42), DISTRACT[(i + 3) % len(DISTRACT)], font=_font(10), fill=muted)
        d.text((210, 14), name, font=_font(14), fill=muted)
        d.text((560, 14), "9:41 AM", font=_font(11), fill=muted)
        fp = 12 if small else 15
        lines = _wrap(text, 46 if small else 40)
        bw = 470
        bh = 16 + len(lines) * int(fp * 1.5) + 12
        d.rounded_rectangle([210, 54, 210 + bw, 54 + bh], radius=14, fill=bubble)
        for i, ln in enumerate(lines):
            d.text((228, 66 + i * int(fp * 1.5)), ln, font=_font(fp), fill=bubble_txt)
        d.text((228, 54 + bh + 6), "Delivered", font=_font(10), fill=muted)
        name_out = "ocr_%02d_chat_%s%s.png" % (idx, "dark" if dark else "light", "_sm" if small else "")
        img.save(os.path.join(OCR_DIR, name_out))
        out.append({"image": name_out, "register": "chat", "style": "hard-chat",
                    "difficulty": "hard", "text": text})
        idx += 1

    def email(text):
        nonlocal idx
        W = 720
        lines = _wrap(text, 70)
        H = 150 + len(lines) * 26
        img = Image.new("RGB", (W, H), (255, 255, 255))
        d = ImageDraw.Draw(img)
        muted = (140, 142, 148)
        d.text((24, 18), "From: Alex Rivera <alex@example.com>", font=_font(12), fill=muted)
        d.text((24, 38), "To: me;  Cc: Jordan, Sam", font=_font(12), fill=muted)
        d.text((24, 58), "Subject: Re: Q3 planning", font=_font(12), fill=muted)
        d.line([24, 84, W - 24, 84], fill=(225, 226, 230))
        for i, ln in enumerate(lines):
            d.text((24, 100 + i * 26), ln, font=_font(15), fill=(35, 36, 40))
        name_out = "ocr_%02d_email.png" % idx
        img.save(os.path.join(OCR_DIR, name_out))
        out.append({"image": name_out, "register": "email", "style": "hard-email",
                    "difficulty": "hard", "text": text})
        idx += 1

    texts = [t for _, t in sample_texts()]
    chat(texts[0], dark=False, small=False, name="Alex Rivera")
    chat(texts[1], dark=True, small=False, name="Jordan")
    chat(texts[2] if len(texts) > 2 else texts[0], dark=True, small=True, name="Design team")
    chat(texts[3] if len(texts) > 3 else texts[0], dark=False, small=True, name="Mom")
    for t in [t for r, t in sample_texts() if r == "email"][:2]:
        email(t)
    for t in [t for r, t in sample_texts() if r == "prose"][:2]:
        email(t)
    return out


def generate():
    from PIL import Image, ImageDraw, ImageFont
    os.makedirs(OCR_DIR, exist_ok=True)
    # (font_px, fg, bg, label) — vary size and contrast, incl. a dark-mode case.
    styles = [
        (28, (20, 20, 20), (255, 255, 255), "large-light"),
        (18, (30, 30, 30), (245, 245, 245), "medium-light"),
        (13, (40, 40, 40), (255, 255, 255), "small-light"),
        (18, (235, 235, 235), (28, 28, 30), "medium-dark"),
    ]
    records = []
    idx = 0
    for reg, text in sample_texts():
        for font_px, fg, bg, style in styles:
            font = ImageFont.truetype(FONT, font_px)
            # wrap to ~40 chars, pad into a screen-region-like image
            words, lines, cur = text.split(), [], ""
            for w in words:
                if len(cur) + len(w) + 1 > 42:
                    lines.append(cur); cur = w
                else:
                    cur = (cur + " " + w).strip()
            if cur:
                lines.append(cur)
            pad, lh = 24, int(font_px * 1.5)
            img = Image.new("RGB", (620, pad * 2 + lh * len(lines)), bg)
            d = ImageDraw.Draw(img)
            for i, ln in enumerate(lines):
                d.text((pad, pad + i * lh), ln, font=font, fill=fg)
            name = "ocr_%02d_%s.png" % (idx, style)
            img.save(os.path.join(OCR_DIR, name))
            records.append({"image": name, "register": reg, "style": style,
                            "difficulty": "easy", "font_px": font_px, "text": text})
            idx += 1
    records += render_hard(records)
    with open(GT_FILE, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")
    hard = sum(1 for r in records if r.get("difficulty") == "hard")
    print("generated %d test images (%d easy, %d hard) -> %s" % (
        len(records), len(records) - hard, hard, OCR_DIR))


def normalize(s):
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s]", " ", s.lower())).strip()


def score(truth, got):
    t, g = normalize(truth), normalize(got)
    sim = difflib.SequenceMatcher(None, t, g).ratio()
    tw, gw = t.split(), set(g.split())
    recall = sum(1 for w in tw if w in gw) / max(1, len(tw))
    return sim, recall


def run_ocr(image_path, env_extra):
    env = dict(os.environ)
    env.update(env_extra)
    # Prefer a precompiled binary (OCR_PROBE_BIN) so latency reflects real OCR,
    # not the ~0.5s `swift` compile each call.
    binary = os.environ.get("OCR_PROBE_BIN")
    cmd = [binary, image_path] if binary and os.path.exists(binary) else ["swift", PROBE, image_path]
    t0 = time.time()
    out = subprocess.run(cmd, capture_output=True, text=True, env=env)
    ms = int((time.time() - t0) * 1000)
    return out.stdout.strip(), ms, out.returncode


def evaluate(env_extra, label=""):
    if not os.path.exists(GT_FILE):
        print("no test images; run --generate first", file=sys.stderr)
        return None
    rows = [json.loads(l) for l in open(GT_FILE)]
    sims, recalls, lats = [], [], []
    by_diff = {"easy": [], "hard": []}
    per = []
    for r in rows:
        got, ms, rc = run_ocr(os.path.join(OCR_DIR, r["image"]), env_extra)
        sim, recall = score(r["text"], got)
        sims.append(sim); recalls.append(recall); lats.append(ms)
        by_diff.setdefault(r.get("difficulty", "easy"), []).append(recall)
        per.append((r, sim, recall))
    n = len(rows)
    res = {
        "label": label,
        "similarity": round(sum(sims) / n, 4),
        "word_recall": round(sum(recalls) / n, 4),
        "recall_easy": round(sum(by_diff["easy"]) / max(1, len(by_diff["easy"])), 4),
        "recall_hard": round(sum(by_diff["hard"]) / max(1, len(by_diff["hard"])), 4),
        "p50_ms": sorted(lats)[n // 2],
        "images": n,
    }
    return res, per


def cmd_run(args):
    res, per = evaluate({}, "current-knobs")
    if not res:
        return 1
    print("OCR accuracy (current knobs): word-recall %.1f%%  [easy %.1f%% / HARD %.1f%%]  p50 %dms  over %d images" % (
        100 * res["word_recall"], 100 * res["recall_easy"], 100 * res["recall_hard"],
        res["p50_ms"], res["images"]))
    if args.verbose:
        for r, sim, rec in sorted(per, key=lambda x: x[1])[:6]:
            print("  worst: %-16s sim %.0f%% recall %.0f%%  %r" % (
                r["style"], 100 * sim, 100 * rec, r["text"][:40]))
    return 0


def cmd_sweep(args):
    # each knob combo to try; None = default
    combos = [
        ({}, "accurate+langcorr (default)"),
        ({"STEADYTYPE_OCR_LEVEL": "fast"}, "fast+langcorr"),
        ({"STEADYTYPE_OCR_LANG_CORRECTION": "0"}, "accurate+noLangcorr"),
        ({"STEADYTYPE_OCR_LEVEL": "fast", "STEADYTYPE_OCR_LANG_CORRECTION": "0"}, "fast+noLangcorr"),
        ({"STEADYTYPE_OCR_MIN_TEXT_HEIGHT": "0.003"}, "accurate+smallerMinHeight"),
        ({"STEADYTYPE_OCR_MIN_TEXT_HEIGHT": "0.012"}, "accurate+largerMinHeight"),
    ]
    results = []
    for env_extra, label in combos:
        res, _ = evaluate(env_extra, label)
        results.append(res)
        print("  %-28s recall %.1f%%  [easy %.1f%% / HARD %.1f%%]  p50 %dms" % (
            label, 100 * res["word_recall"], 100 * res["recall_easy"],
            100 * res["recall_hard"], res["p50_ms"]), flush=True)
    # Rank on the HARD set — that's where reading quality actually matters.
    results.sort(key=lambda r: (r["recall_hard"], r["word_recall"]), reverse=True)
    print("\n== best OCR config (ranked on hard/realistic images) ==")
    b = results[0]
    print("%s  ->  HARD recall %.1f%%  overall %.1f%%  p50 %dms" % (
        b["label"], 100 * b["recall_hard"], 100 * b["word_recall"], b["p50_ms"]))
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--generate", action="store_true")
    p.add_argument("--run", action="store_true")
    p.add_argument("--sweep", action="store_true")
    p.add_argument("--verbose", action="store_true")
    a = p.parse_args()
    if a.generate:
        generate(); return 0
    if a.sweep:
        return cmd_sweep(a)
    return cmd_run(a)


if __name__ == "__main__":
    sys.exit(main())
