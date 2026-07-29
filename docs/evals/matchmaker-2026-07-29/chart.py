#!/usr/bin/env python3
"""Side-by-side bar chart of the matchmaker A/B (with vs without precedents),
in the style of the model-comparison charts: grouped bars per metric, one
panel per paper. Reads ab_results.json (+ optional ab_results_loose.json)."""
import json
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

MM = os.path.expanduser("~/.cache/steadytype-eval/matchmaker")
OUT = os.path.join(MM, "matchmaker_ab.png")

METRICS = [("word1", "word-1"), ("word12", "first-2"), ("word123", "first-3"),
           ("similar", "similar★"), ("meaning", "meaning")]

BG = "#0D0D0D"
FG = "#F5F5F7"
MUTED = "#8A8A90"
WITHOUT_C = "#5B5B60"
WITH_C = "#FF3B30"
WITH2_C = "#FF8C42"


def load(path):
    p = os.path.join(MM, path)
    return json.load(open(p)) if os.path.exists(p) else None


def main():
    res = load("ab_results.json")
    loose = load("ab_results_loose.json")
    if not res:
        sys.exit("no ab_results.json yet")

    papers = [("live", "LIVE paper (your real recent typing)"),
              ("texting", "TEXTING paper (frozen iMessage held-out)")]

    fig, axes = plt.subplots(1, 2, figsize=(13, 5.2), facecolor=BG)
    for ax, (paper, title) in zip(axes, papers):
        ax.set_facecolor(BG)
        wo = res[f"{paper}_without"]
        wi = res[f"{paper}_with"]
        lo = loose.get(f"{paper}_with") if loose else None

        x = np.arange(len(METRICS))
        n_series = 3 if lo else 2
        w = 0.8 / n_series

        def bars(offset, data, color, label):
            vals = [data[m] for m, _ in METRICS]
            b = ax.bar(x + offset, vals, w, color=color, label=label, zorder=3)
            for rect, v in zip(b, vals):
                ax.text(rect.get_x() + rect.get_width() / 2, v + 0.008,
                        f"{v*100:.1f}", ha="center", va="bottom",
                        fontsize=8, color=FG)

        bars(-w * (n_series - 1) / 2, wo, WITHOUT_C, "without matchmaker")
        bars(-w * (n_series - 1) / 2 + w, wi,
             WITH_C, "with — strict floor (205 memories)")
        if lo:
            bars(-w * (n_series - 1) / 2 + 2 * w, lo, WITH2_C,
                 "with — loose floor (897 memories)")

        note = ("  ⚠ 77/99 questions twin-contaminated in WITH arms"
                if paper == "live" else "  (twin-free by construction)")
        ax.set_title(f"{title}\nn={wo['n']}{note}", color=FG, fontsize=10)
        ax.set_xticks(x)
        ax.set_xticklabels([lbl for _, lbl in METRICS], color=FG, fontsize=9)
        ax.tick_params(colors=MUTED)
        for s in ax.spines.values():
            s.set_color(MUTED)
        ax.grid(axis="y", color="#2C2C2E", zorder=0)
        ax.set_ylim(0, max(0.35, max(
            d[m] for d in ([wo, wi] + ([lo] if lo else []))
            for m, _ in METRICS) * 1.25))
        ax.legend(facecolor=BG, edgecolor=MUTED, labelcolor=FG, fontsize=9)

    fig.suptitle("Matchmaker A/B — champion model, precedents in the scaffold slot",
                 color=FG, fontsize=13)
    fig.tight_layout()
    fig.savefig(OUT, dpi=160, facecolor=BG)
    print(f"chart: {OUT}")


if __name__ == "__main__":
    main()
