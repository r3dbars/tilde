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
                            "font_px": font_px, "text": text})
            idx += 1
    with open(GT_FILE, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")
    print("generated %d test images -> %s" % (len(records), OCR_DIR))


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
    for r in rows:
        got, ms, rc = run_ocr(os.path.join(OCR_DIR, r["image"]), env_extra)
        sim, recall = score(r["text"], got)
        sims.append(sim); recalls.append(recall); lats.append(ms)
    n = len(rows)
    res = {
        "label": label,
        "similarity": round(sum(sims) / n, 4),
        "word_recall": round(sum(recalls) / n, 4),
        "p50_ms": sorted(lats)[n // 2],
        "images": n,
    }
    return res, list(zip(rows, sims, recalls))


def cmd_run(args):
    res, per = evaluate({}, "current-knobs")
    if not res:
        return 1
    print("OCR accuracy (current knobs): similarity %.1f%%  word-recall %.1f%%  p50 %dms  over %d images" % (
        100 * res["similarity"], 100 * res["word_recall"], res["p50_ms"], res["images"]))
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
        print("  %-28s similarity %.1f%%  word-recall %.1f%%  p50 %dms" % (
            label, 100 * res["similarity"], 100 * res["word_recall"], res["p50_ms"]), flush=True)
    results.sort(key=lambda r: (r["word_recall"], r["similarity"]), reverse=True)
    print("\n== best OCR config ==")
    b = results[0]
    print("%s  ->  word-recall %.1f%%  similarity %.1f%%  p50 %dms" % (
        b["label"], 100 * b["word_recall"], 100 * b["similarity"], b["p50_ms"]))
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
