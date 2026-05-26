#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SCORECARD="docs/product/steadytype-product-scorecard.md"

python3 script/check_steadytype_scorecard.py --scorecard "$SCORECARD" >"$TMP_DIR/pass.txt"

if ! grep -F "SteadyType scorecard verified" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "scorecard self-test expected the real scorecard to verify" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi

MANUAL_LIVE="$TMP_DIR/manual-live.txt"
PROOF_LIVE="$TMP_DIR/proof-live.txt"
LATENCY_SELECTOR_LIVE="$TMP_DIR/latency-selector-live.txt"
python3 - "$MANUAL_LIVE" "$PROOF_LIVE" "$LATENCY_SELECTOR_LIVE" <<'PY'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text(
    "Insertion proof status: docs/product/manual-smoke-runs.md\n"
    "10 target app pass(es) still need real manual smoke proof.\n",
    encoding="utf-8",
)
Path(sys.argv[2]).write_text(
    "Proof manifest gaps:\n"
    "Proof manifest verified.\n",
    encoding="utf-8",
)
PY

python3 - "$SCORECARD" "$LATENCY_SELECTOR_LIVE" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
latency_line = next(line for line in source.splitlines() if line.startswith("| Latency |"))
green = re.search(
    r"select_latency_window[.]py\b[^|]*?: selected "
    r"diagnosticsLine=([0-9]+), traceStartLine=([0-9]+), "
    r"firstVisibleSamples=([0-9]+), modelSamples=([0-9]+), "
    r"fastWordVisibleSamples=([0-9]+)",
    latency_line,
)
red = re.search(
    r"select_latency_window[.]py\b[^|]*?: failed red because "
    r"(.+?), with diagnosticsLine=([0-9]+), traceStartLine=([0-9]+), "
    r"firstVisibleSamples=([0-9]+), modelSamples=([0-9]+), "
    r"fastWordVisibleSamples=([0-9]+)",
    latency_line,
)
if green:
    diagnostics, trace, first_visible, model, fast_word = green.groups()
    output = (
        f"AUTOCOMPLETE_LAB_LOG_START_LINE={int(diagnostics) - 1}\n"
        f"AUTOCOMPLETE_LAB_TRACE_START_LINE={trace}\n"
        "Latency window: selected latest sampled default runtime launch; "
        f"diagnosticsLine={diagnostics}; traceStartLine={trace}; diagnosticsEndLine=none; "
        f"traceEndLine=none; firstVisibleSamples={first_visible}; modelSamples={model}; "
        f"fastWordVisibleSamples={fast_word}\n"
    )
elif red:
    reason, diagnostics, trace, first_visible, model, fast_word = red.groups()
    output = (
        f"Latency window: {reason}; diagnosticsLine={diagnostics}; traceStartLine={trace}; "
        "diagnosticsEndLine=none; traceEndLine=none; "
        f"firstVisibleSamples={first_visible}; modelSamples={model}; "
        f"fastWordVisibleSamples={fast_word}\n"
    )
else:
    raise SystemExit("could not parse scorecard latency selector claim")

Path(sys.argv[2]).write_text(output, encoding="utf-8")
PY

python3 script/check_steadytype_scorecard.py \
  --scorecard "$SCORECARD" \
  --live \
  --manual-smoke-output "$MANUAL_LIVE" \
  --proof-manifest-output "$PROOF_LIVE" \
  --latency-selector-output "$LATENCY_SELECTOR_LIVE" \
  >"$TMP_DIR/live-pass.txt"

if ! grep -F "SteadyType scorecard verified" "$TMP_DIR/live-pass.txt" >/dev/null; then
  echo "scorecard self-test expected live fixture counts to verify" >&2
  cat "$TMP_DIR/live-pass.txt" >&2
  exit 1
fi

python3 script/check_steadytype_scorecard.py \
  --scorecard "$SCORECARD" \
  --live \
  --manual-smoke-output "$MANUAL_LIVE" \
  --proof-manifest-output "$PROOF_LIVE" \
  --latency-selector-output "$LATENCY_SELECTOR_LIVE" \
  >"$TMP_DIR/live-latency-pass.txt"

if ! grep -F "SteadyType scorecard verified" "$TMP_DIR/live-latency-pass.txt" >/dev/null; then
  echo "scorecard self-test expected strict latency selector fixture to verify" >&2
  cat "$TMP_DIR/live-latency-pass.txt" >&2
  exit 1
fi

LATENCY_SELECTOR_RED="$TMP_DIR/latency-selector-red.txt"
cat >"$LATENCY_SELECTOR_RED" <<'EOF'
Latency window: latest default runtime launch has too few samples; diagnosticsLine=25000; traceStartLine=6300; diagnosticsEndLine=none; traceEndLine=none; firstVisibleSamples=1; modelSamples=1; fastWordVisibleSamples=0
EOF

if python3 script/check_steadytype_scorecard.py \
  --scorecard "$SCORECARD" \
  --live \
  --manual-smoke-output "$MANUAL_LIVE" \
  --proof-manifest-output "$PROOF_LIVE" \
  --latency-selector-output "$LATENCY_SELECTOR_RED" \
  >"$TMP_DIR/live-latency-red.txt" 2>&1; then
  echo "scorecard self-test expected stale red latency count to fail" >&2
  exit 1
fi

if ! grep -F "diagnosticsLine claim is" "$TMP_DIR/live-latency-red.txt" >/dev/null ||
   ! grep -F "live output reports 25000" "$TMP_DIR/live-latency-red.txt" >/dev/null; then
  echo "scorecard self-test missing stale red latency selector failure" >&2
  cat "$TMP_DIR/live-latency-red.txt" >&2
  exit 1
fi

LATENCY_SELECTOR_DRIFT="$TMP_DIR/latency-selector-drift.txt"
python3 - "$LATENCY_SELECTOR_LIVE" "$LATENCY_SELECTOR_DRIFT" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
source = re.sub(r"modelSamples=[0-9]+", "modelSamples=1", source, count=1)
Path(sys.argv[2]).write_text(source, encoding="utf-8")
PY

if python3 script/check_steadytype_scorecard.py \
  --scorecard "$SCORECARD" \
  --live \
  --manual-smoke-output "$MANUAL_LIVE" \
  --proof-manifest-output "$PROOF_LIVE" \
  --latency-selector-output "$LATENCY_SELECTOR_DRIFT" \
  >"$TMP_DIR/live-latency-drift.txt" 2>&1; then
  echo "scorecard self-test expected stale latency selector count to fail" >&2
  exit 1
fi

if ! grep -F "modelSamples claim is" "$TMP_DIR/live-latency-drift.txt" >/dev/null ||
   ! grep -F "live output reports 1" "$TMP_DIR/live-latency-drift.txt" >/dev/null; then
  echo "scorecard self-test missing stale latency selector count failure" >&2
  cat "$TMP_DIR/live-latency-drift.txt" >&2
  exit 1
fi

MANUAL_DRIFT="$TMP_DIR/manual-drift.md"
python3 - "$SCORECARD" "$MANUAL_DRIFT" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
source = source.replace(
    "failed with 10 stale or pending rows",
    "failed with 9 stale or pending rows",
    1,
)
Path(sys.argv[2]).write_text(source, encoding="utf-8")
PY

if python3 script/check_steadytype_scorecard.py \
  --scorecard "$MANUAL_DRIFT" \
  --live \
  --manual-smoke-output "$MANUAL_LIVE" \
  --proof-manifest-output "$PROOF_LIVE" \
  >"$TMP_DIR/manual-drift.txt" 2>&1; then
  echo "scorecard self-test expected live manual count drift to fail" >&2
  exit 1
fi

if ! grep -F "manual smoke stale/pending count claim is 9, live output reports 10" "$TMP_DIR/manual-drift.txt" >/dev/null; then
  echo "scorecard self-test missing live manual count drift failure" >&2
  cat "$TMP_DIR/manual-drift.txt" >&2
  exit 1
fi

PROOF_DRIFT="$TMP_DIR/proof-drift.md"
python3 - "$SCORECARD" "$PROOF_DRIFT" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
source = source.replace("0 manifest issues", "1 manifest issues", 1)
Path(sys.argv[2]).write_text(source, encoding="utf-8")
PY

if python3 script/check_steadytype_scorecard.py \
  --scorecard "$PROOF_DRIFT" \
  --live \
  --manual-smoke-output "$MANUAL_LIVE" \
  --proof-manifest-output "$PROOF_LIVE" \
  >"$TMP_DIR/proof-drift.txt" 2>&1; then
  echo "scorecard self-test expected live proof manifest count drift to fail" >&2
  exit 1
fi

if ! grep -F "proof manifest issue count claim is 1, live output reports 0" "$TMP_DIR/proof-drift.txt" >/dev/null; then
  echo "scorecard self-test missing live proof manifest count drift failure" >&2
  cat "$TMP_DIR/proof-drift.txt" >&2
  exit 1
fi

BAD_SCORE="$TMP_DIR/bad-score.md"
sed -E 's#(\| Latency \| )[0-9]+/100#\1101/100#' "$SCORECARD" >"$BAD_SCORE"

if python3 script/check_steadytype_scorecard.py --scorecard "$BAD_SCORE" >"$TMP_DIR/bad-score.txt" 2>&1; then
  echo "scorecard self-test expected invalid score to fail" >&2
  exit 1
fi

if ! grep -F "Latency: score must be between 0 and 100" "$TMP_DIR/bad-score.txt" >/dev/null; then
  echo "scorecard self-test missing invalid score failure" >&2
  cat "$TMP_DIR/bad-score.txt" >&2
  exit 1
fi

STALE_ROUND_UP="$TMP_DIR/stale-round-up.md"
sed 's#| Placement | 70/100 |#| Placement | 90/100 |#' "$SCORECARD" >"$STALE_ROUND_UP"

if python3 script/check_steadytype_scorecard.py --scorecard "$STALE_ROUND_UP" >"$TMP_DIR/stale.txt" 2>&1; then
  echo "scorecard self-test expected stale rounded-up proof to fail" >&2
  exit 1
fi

if ! grep -F "Placement: contains 'stale', so score must stay <= 75/100" "$TMP_DIR/stale.txt" >/dev/null; then
  echo "scorecard self-test missing stale proof failure" >&2
  cat "$TMP_DIR/stale.txt" >&2
  exit 1
fi

PENDING_ROUND_UP="$TMP_DIR/pending-round-up.md"
sed 's#| Tab safety | 74/100 |#| Tab safety | 90/100 |#' "$SCORECARD" >"$PENDING_ROUND_UP"

if python3 script/check_steadytype_scorecard.py --scorecard "$PENDING_ROUND_UP" >"$TMP_DIR/pending.txt" 2>&1; then
  echo "scorecard self-test expected pending rounded-up proof to fail" >&2
  exit 1
fi

if ! grep -F "Tab safety: contains 'stale', so score must stay <= 75/100" "$TMP_DIR/pending.txt" >/dev/null; then
  echo "scorecard self-test missing stale Tab safety proof failure" >&2
  cat "$TMP_DIR/pending.txt" >&2
  exit 1
fi

ZERO_LATENCY_METRIC="$TMP_DIR/zero-latency-metric.md"
python3 - "$ZERO_LATENCY_METRIC" <<'PY'
from pathlib import Path
import sys

areas = [
    "Suggestion quality",
    "Placement",
    "Tab safety",
    "Latency",
    "Privacy",
    "App coverage",
    "Onboarding",
    "Controls",
    "Diagnostics",
    "Model readiness",
    "Beta readiness",
    "Test/proof coverage",
]

lines = [
    "# Scorecard",
    "",
    "Overall score: 76/100.",
    "",
    "| Area | Score | Evidence | Why It Is Not Higher | Next Proof |",
    "| --- | --- | --- | --- | --- |",
]
for area in areas:
    score = "75/100"
    evidence = "`./script/check.sh`: passed."
    why = "More proof needed."
    if area == "Latency":
        score = "90/100"
        evidence = (
            "`./script/latency_benchmark_report.py`: first visible n=5 avg 142ms; "
            "Stale/late suppression: n=0; latency beta gate passed."
        )
        why = "Strict TextEdit default-runtime latency is fresh and model-backed."
    lines.append(f"| {area} | {score} | {evidence} | {why} | Run `./script/check.sh`. |")

Path(sys.argv[1]).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

python3 script/check_steadytype_scorecard.py --scorecard "$ZERO_LATENCY_METRIC" >"$TMP_DIR/zero-latency-metric.txt"

for term in stale pending blocked; do
  BAD_ZERO_LATENCY_METRIC="$TMP_DIR/zero-latency-metric-$term.md"
  python3 - "$ZERO_LATENCY_METRIC" "$BAD_ZERO_LATENCY_METRIC" "$term" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
term = sys.argv[3]
source = source.replace(
    "Strict TextEdit default-runtime latency is fresh and model-backed.",
    f"Strict TextEdit default-runtime latency is fresh, but manual app proof is {term}.",
)
Path(sys.argv[2]).write_text(source, encoding="utf-8")
PY

  if python3 script/check_steadytype_scorecard.py --scorecard "$BAD_ZERO_LATENCY_METRIC" >"$TMP_DIR/zero-latency-metric-$term.txt" 2>&1; then
    echo "scorecard self-test expected unresolved $term language beside zero-count latency metric to fail" >&2
    exit 1
  fi

  if ! grep -F "Latency: contains '$term', so score must stay <= 75/100" "$TMP_DIR/zero-latency-metric-$term.txt" >/dev/null; then
    echo "scorecard self-test missing unresolved $term failure beside zero-count latency metric" >&2
    cat "$TMP_DIR/zero-latency-metric-$term.txt" >&2
    exit 1
  fi
done

PERFECT_UNRESOLVED="$TMP_DIR/perfect-unresolved.md"
sed -e 's#Overall score: 78/100\.#Overall score: 79/100.#' \
  -e 's#| Diagnostics | 90/100 |#| Diagnostics | 100/100 |#' \
  "$SCORECARD" >"$PERFECT_UNRESOLVED"

if python3 script/check_steadytype_scorecard.py --scorecard "$PERFECT_UNRESOLVED" >"$TMP_DIR/perfect.txt" 2>&1; then
  echo "scorecard self-test expected unresolved 100/100 row to fail" >&2
  exit 1
fi

if ! grep -F "Diagnostics: 100/100 requires resolved row gates" "$TMP_DIR/perfect.txt" >/dev/null; then
  echo "scorecard self-test missing unresolved 100/100 failure" >&2
  cat "$TMP_DIR/perfect.txt" >&2
  exit 1
fi

PERFECT_RUN_AGAIN="$TMP_DIR/perfect-run-again.md"
python3 - "$PERFECT_RUN_AGAIN" <<'PY'
from pathlib import Path
import sys

areas = [
    "Suggestion quality",
    "Placement",
    "Tab safety",
    "Latency",
    "Privacy",
    "App coverage",
    "Onboarding",
    "Controls",
    "Diagnostics",
    "Model readiness",
    "Beta readiness",
    "Test/proof coverage",
]

lines = [
    "# Scorecard",
    "",
    "Overall score: 100/100.",
    "",
    "| Area | Score | Evidence | Why It Is Not Higher | Next Proof |",
    "| --- | --- | --- | --- | --- |",
]
for area in areas:
    next_proof = "`./script/check.sh`: passed gate."
    if area == "Latency":
        next_proof = "Run `./script/check.sh` again."
    lines.append(
        f"| {area} | 100/100 | `./script/check.sh`: passed. | Complete. | {next_proof} |"
    )

Path(sys.argv[1]).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

if python3 script/check_steadytype_scorecard.py --scorecard "$PERFECT_RUN_AGAIN" >"$TMP_DIR/perfect-run-again.txt" 2>&1; then
  echo "scorecard self-test expected 100/100 row with future run proof to fail" >&2
  exit 1
fi

if ! grep -F "Latency: 100/100 requires resolved row gates" "$TMP_DIR/perfect-run-again.txt" >/dev/null ||
   ! grep -F "unfinished next proof" "$TMP_DIR/perfect-run-again.txt" >/dev/null; then
  echo "scorecard self-test missing future run proof 100/100 failure" >&2
  cat "$TMP_DIR/perfect-run-again.txt" >&2
  exit 1
fi

MISSING_AREA="$TMP_DIR/missing-area.md"
grep -v '^| Model readiness |' "$SCORECARD" >"$MISSING_AREA"

if python3 script/check_steadytype_scorecard.py --scorecard "$MISSING_AREA" >"$TMP_DIR/missing.txt" 2>&1; then
  echo "scorecard self-test expected missing area to fail" >&2
  exit 1
fi

if ! grep -F "missing required score area: model readiness" "$TMP_DIR/missing.txt" >/dev/null; then
  echo "scorecard self-test missing required-area failure" >&2
  cat "$TMP_DIR/missing.txt" >&2
  exit 1
fi

LIVE_SCORECARD="$TMP_DIR/live-scorecard.md"
LATENCY_SELECTOR_GREEN="$TMP_DIR/latency-selector-green.txt"
cat >"$LATENCY_SELECTOR_GREEN" <<'EOF'
AUTOCOMPLETE_LAB_LOG_START_LINE=24210
AUTOCOMPLETE_LAB_TRACE_START_LINE=6225
Latency window: selected latest sampled default runtime launch; diagnosticsLine=24211; traceStartLine=6225; diagnosticsEndLine=none; traceEndLine=none; firstVisibleSamples=5; modelSamples=20; fastWordVisibleSamples=0
EOF

python3 - "$LIVE_SCORECARD" <<'PY'
from pathlib import Path
import sys

areas = [
    "Suggestion quality",
    "Placement",
    "Tab safety",
    "Latency",
    "Privacy",
    "App coverage",
    "Onboarding",
    "Controls",
    "Diagnostics",
    "Model readiness",
    "Beta readiness",
    "Test/proof coverage",
]

lines = [
    "# Scorecard",
    "",
    "Overall score: 75/100.",
    "",
    "| Area | Score | Evidence | Why It Is Not Higher | Next Proof |",
    "| --- | --- | --- | --- | --- |",
]
for area in areas:
    evidence = "`./script/check.sh`: passed."
    if area == "Latency":
        evidence += (
            " `./script/select_latency_window.py`: selected diagnosticsLine=24211, "
            "traceStartLine=6225, firstVisibleSamples=5, modelSamples=20, "
            "fastWordVisibleSamples=0."
        )
    if area == "App coverage":
        evidence += " `manual_smoke_status.sh --strict`: failed with 7 stale or pending rows."
    if area == "Test/proof coverage":
        evidence += " `check_proof_manifest.sh --require-all`: failed with 3 manifest issues."
    lines.append(
        f"| {area} | 75/100 | {evidence} | More proof needed. | Run `./script/check.sh`. |"
    )

Path(sys.argv[1]).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

cat >"$TMP_DIR/manual-smoke-live.txt" <<'EOF'
7 target app passes still need real manual smoke proof.
EOF

cat >"$TMP_DIR/proof-manifest-live.txt" <<'EOF'
Proof manifest check failed with 3 issue(s).
EOF

python3 script/check_steadytype_scorecard.py \
  --scorecard "$LIVE_SCORECARD" \
  --live \
  --manual-smoke-output "$TMP_DIR/manual-smoke-live.txt" \
  --proof-manifest-output "$TMP_DIR/proof-manifest-live.txt" \
  --latency-selector-output "$LATENCY_SELECTOR_GREEN" \
  >"$TMP_DIR/live-pass.txt"

cat >"$TMP_DIR/manual-smoke-live-bad.txt" <<'EOF'
8 target app passes still need real manual smoke proof.
EOF

if python3 script/check_steadytype_scorecard.py \
  --scorecard "$LIVE_SCORECARD" \
  --live \
  --manual-smoke-output "$TMP_DIR/manual-smoke-live-bad.txt" \
  --proof-manifest-output "$TMP_DIR/proof-manifest-live.txt" \
  --latency-selector-output "$LATENCY_SELECTOR_GREEN" \
  >"$TMP_DIR/live-bad.txt" 2>&1; then
  echo "scorecard self-test expected live manual count mismatch to fail" >&2
  exit 1
fi

if ! grep -F "manual smoke stale/pending count claim is 7, live output reports 8" "$TMP_DIR/live-bad.txt" >/dev/null; then
  echo "scorecard self-test missing live manual count mismatch failure" >&2
  cat "$TMP_DIR/live-bad.txt" >&2
  exit 1
fi

if python3 script/check_steadytype_scorecard.py \
  --scorecard "$LIVE_SCORECARD" \
  --manual-smoke-output "$TMP_DIR/manual-smoke-live.txt" \
  >"$TMP_DIR/live-args.txt" 2>&1; then
  echo "scorecard self-test expected live output files to require --live" >&2
  exit 1
fi

if python3 script/check_steadytype_scorecard.py \
  --scorecard "$SCORECARD" \
  --latency-selector-output "$LATENCY_SELECTOR_LIVE" \
  >"$TMP_DIR/latency-live-args.txt" 2>&1; then
  echo "scorecard self-test expected latency selector output files to require --live" >&2
  exit 1
fi

echo "SteadyType scorecard self-test passed."
