#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CURRENT_COMMIT="$(git rev-parse --short=12 HEAD)"
PASS_REPORT="$TMP_DIR/manual-smoke-pass.md"
STALE_REPORT="$TMP_DIR/manual-smoke-stale.md"
NO_FINGERPRINT_REPORT="$TMP_DIR/manual-smoke-no-fingerprint.md"
PROMPT_REPORT="$TMP_DIR/manual-smoke-prompt.md"
OUTPUT="$TMP_DIR/output.txt"
APP_BINARY="$TMP_DIR/AutocompleteLab"
ARCHIVE_PATH="$TMP_DIR/SteadyType.zip"

write_report_header() {
  local path="$1"
  cat >"$path" <<'EOF'
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
EOF
}

write_report_header "$PASS_REPORT"
cat >>"$PASS_REPORT" <<EOF
| 2026-05-09T00:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:$CURRENT_COMMIT\` |
EOF

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$PASS_REPORT" \
  script/manual_proof_refresh.sh --verify-target textedit >"$OUTPUT"

if ! grep -F "TextEdit: current proof recorded" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not accept current TextEdit proof" >&2
  exit 1
fi

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$PASS_REPORT" \
  script/manual_proof_refresh.sh --print --target textedit >"$OUTPUT"

if ! grep -F "Summary: 1 current, 0 stale, 0 pending, 0 need refresh." "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not summarize current target proof" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

if grep -F "script/real_app_smoke.sh textedit" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test should not print a next command for current proof" >&2
  exit 1
fi

write_report_header "$STALE_REPORT"
cat >>"$STALE_REPORT" <<'EOF'
| 2026-05-09T00:00:00Z | TextEdit | `com.apple.TextEdit` | `default` | 2 | `inlineAdjacent|floatingMirror` | lines 1-2 in `/tmp/diagnostics.log` | lines 1-2 in `/tmp/traces.jsonl`; visual `strict-complete`; build `commit:deadbeef0000` |
EOF

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$STALE_REPORT" \
  script/manual_proof_refresh.sh --print --target textedit >"$OUTPUT"

if ! grep -F "Summary: 0 current, 1 stale, 0 pending, 1 need refresh." "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not summarize stale target proof" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

if ! grep -F "# status: stale - stale commit fingerprint" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not annotate stale next command" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$STALE_REPORT" \
  script/manual_proof_refresh.sh --verify-target textedit >"$OUTPUT" 2>&1; then
  echo "manual proof refresh self-test expected stale commit proof to fail" >&2
  exit 1
fi

if ! grep -F "stale commit fingerprint" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not explain stale commit proof" >&2
  exit 1
fi

SOURCE_COMPATIBLE_COMMIT="$(git rev-parse --short=12 HEAD~1 2>/dev/null || true)"
if [[ -n "$SOURCE_COMPATIBLE_COMMIT" ]]; then
  write_report_header "$STALE_REPORT"
  cat >>"$STALE_REPORT" <<EOF
| 2026-05-09T00:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:$SOURCE_COMPATIBLE_COMMIT\` |
EOF

  if ! AUTOCOMPLETE_LAB_PROOF_SOURCE_PATHS="__manual_proof_refresh_self_test_no_source_path__" \
    AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$STALE_REPORT" \
    script/manual_proof_refresh.sh --verify-target textedit >"$OUTPUT" 2>&1; then
    echo "manual proof refresh self-test should accept source-compatible commit proof" >&2
    exit 1
  fi

  AUTOCOMPLETE_LAB_PROOF_SOURCE_PATHS="__manual_proof_refresh_self_test_no_source_path__" \
    AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$STALE_REPORT" \
    script/manual_proof_refresh.sh --print --target textedit >"$OUTPUT"

  if ! grep -F -- "- TextEdit: current (source-compatible commit fingerprint)" "$OUTPUT" >/dev/null; then
    echo "manual proof refresh self-test did not summarize source-compatible commit proof" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
fi

CLAUDE_POLICY_ONLY_COMMIT=""
CURRENT_HEAD="$(git rev-parse --verify HEAD)"
while IFS= read -r candidate; do
  [[ "$candidate" != "$CURRENT_HEAD" ]] || continue
  changed_paths="$(git diff --name-only "$candidate".."$CURRENT_HEAD" -- Package.swift Package.resolved Sources | tr '\n' ' ')"
  if [[ "$changed_paths" == "Sources/AutocompleteLabCore/Configuration/ClaudeCodeTerminalHostProofPolicy.swift " ]]; then
    CLAUDE_POLICY_ONLY_COMMIT="$(git rev-parse --short=12 "$candidate")"
    break
  fi
done < <(git rev-list --max-count=120 HEAD)

if [[ -n "$CLAUDE_POLICY_ONLY_COMMIT" ]]; then
  write_report_header "$STALE_REPORT"
  cat >>"$STALE_REPORT" <<EOF
| 2026-05-09T00:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:$CLAUDE_POLICY_ONLY_COMMIT,app-sha256:stale-app-binary\` |
| 2026-05-09T00:01:00Z | Claude Code | \`com.anthropic.claude-code\` | \`default\` | 1 | \`inlineAdjacent|floatingMirror\` | lines 3-4 in \`/tmp/diagnostics.log\` | lines 3-4 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; prompt no-submit confirmed; build \`commit:$CLAUDE_POLICY_ONLY_COMMIT,app-sha256:stale-app-binary\` |
EOF

  if ! AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$STALE_REPORT" \
    script/manual_proof_refresh.sh --verify-target textedit >"$OUTPUT" 2>&1; then
    echo "manual proof refresh self-test should accept TextEdit proof through Claude Code-only source changes" >&2
    exit 1
  fi

  if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$STALE_REPORT" \
    script/manual_proof_refresh.sh --verify-target claude-code >"$OUTPUT" 2>&1; then
    echo "manual proof refresh self-test should stale Claude Code proof after Claude Code policy changes" >&2
    exit 1
  fi

  if ! grep -F "stale commit fingerprint" "$OUTPUT" >/dev/null; then
    echo "manual proof refresh self-test did not explain Claude Code policy staleness" >&2
    exit 1
  fi
fi

printf 'same app binary\n' >"$APP_BINARY"
APP_SHA="$(shasum -a 256 "$APP_BINARY" | awk '{print $1}')"
write_report_header "$STALE_REPORT"
cat >>"$STALE_REPORT" <<EOF
| 2026-05-09T00:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:deadbeef0000,app-sha256:$APP_SHA\` |
EOF

if ! AUTOCOMPLETE_LAB_APP_BINARY="$APP_BINARY" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$STALE_REPORT" \
  script/manual_proof_refresh.sh --verify-target textedit >"$OUTPUT" 2>&1; then
  echo "manual proof refresh self-test should accept current app binary proof after docs-only commits" >&2
  exit 1
fi

if ! grep -F "TextEdit: current proof recorded" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not accept current app binary proof" >&2
  exit 1
fi

printf 'current archive\n' >"$ARCHIVE_PATH"
ARCHIVE_SHA="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
write_report_header "$STALE_REPORT"
cat >>"$STALE_REPORT" <<EOF
| 2026-05-09T00:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:$CURRENT_COMMIT,archive-sha256:deadbeef\` |
EOF

if AUTOCOMPLETE_LAB_ARCHIVE_PATH="$ARCHIVE_PATH" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$STALE_REPORT" \
  script/manual_proof_refresh.sh --verify-target textedit >"$OUTPUT" 2>&1; then
  :
else
  echo "manual proof refresh self-test should accept current commit proof even when a rebuild changed the archive hash" >&2
  exit 1
fi

if ! grep -F "TextEdit: current proof recorded" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not accept current commit proof with stale archive hash" >&2
  exit 1
fi

write_report_header "$STALE_REPORT"
cat >>"$STALE_REPORT" <<'EOF'
| 2026-05-09T00:00:00Z | TextEdit | `com.apple.TextEdit` | `default` | 2 | `inlineAdjacent|floatingMirror` | lines 1-2 in `/tmp/diagnostics.log` | lines 1-2 in `/tmp/traces.jsonl`; visual `strict-complete`; build `archive-sha256:deadbeef` |
EOF

if AUTOCOMPLETE_LAB_ARCHIVE_PATH="$ARCHIVE_PATH" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$STALE_REPORT" \
  script/manual_proof_refresh.sh --verify-target textedit >"$OUTPUT" 2>&1; then
  echo "manual proof refresh self-test expected archive-only stale proof to fail" >&2
  exit 1
fi

if ! grep -F "stale archive fingerprint" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not explain archive-only stale proof" >&2
  exit 1
fi

write_report_header "$PASS_REPORT"
cat >>"$PASS_REPORT" <<EOF
| 2026-05-09T00:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:deadbeef0000,archive-sha256:$ARCHIVE_SHA\` |
EOF

AUTOCOMPLETE_LAB_ARCHIVE_PATH="$ARCHIVE_PATH" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$PASS_REPORT" \
  script/manual_proof_refresh.sh --verify-target textedit >"$OUTPUT"

if ! grep -F "TextEdit: current proof recorded" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test should accept a current archive proof after docs commit" >&2
  exit 1
fi

write_report_header "$NO_FINGERPRINT_REPORT"
cat >>"$NO_FINGERPRINT_REPORT" <<'EOF'
| 2026-05-09T00:00:00Z | TextEdit | `com.apple.TextEdit` | `default` | 2 | `inlineAdjacent|floatingMirror` | lines 1-2 in `/tmp/diagnostics.log` | lines 1-2 in `/tmp/traces.jsonl`; visual `strict-complete` |
EOF

if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$NO_FINGERPRINT_REPORT" \
  script/manual_proof_refresh.sh --verify-target textedit >"$OUTPUT" 2>&1; then
  echo "manual proof refresh self-test expected missing current proof to fail" >&2
  exit 1
fi

if ! grep -F "missing current app/source proof fingerprint" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not explain missing proof fingerprint" >&2
  exit 1
fi

write_report_header "$PROMPT_REPORT"
cat >>"$PROMPT_REPORT" <<EOF
| 2026-05-09T00:00:00Z | Codex | \`com.openai.codex\` | \`default\` | 1 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:$CURRENT_COMMIT\` |
EOF

if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$PROMPT_REPORT" \
  script/manual_proof_refresh.sh --verify-target codex >"$OUTPUT" 2>&1; then
  echo "manual proof refresh self-test expected prompt proof without no-submit confirmation to fail" >&2
  exit 1
fi

if ! grep -F "missing prompt no-submit confirmation" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not explain missing no-submit prompt proof" >&2
  exit 1
fi

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$PROMPT_REPORT" \
  script/manual_proof_refresh.sh --print --target codex >"$OUTPUT"

if ! grep -F "Summary: 0 current, 0 stale, 1 pending, 1 need refresh." "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not summarize pending prompt proof" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

if ! grep -F "# status: pending - missing prompt no-submit confirmation" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh self-test did not annotate pending prompt next command" >&2
  exit 1
fi

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$NO_FINGERPRINT_REPORT" \
  script/manual_proof_refresh.sh --print >"$OUTPUT"
for expected in \
  "Default scope: beta-safe rows only. Use --all for proof-only or blocked lanes." \
  "Beta-safe target status:" \
  "# textedit - TextEdit" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit" \
  "script/manual_proof_refresh.sh --verify-target textedit" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-theme --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-pane --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-long-note --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture contenteditable"; do
  if ! grep -F "$expected" "$OUTPUT" >/dev/null; then
    echo "manual proof refresh print output missed: $expected" >&2
    exit 1
  fi
done

for unexpected in \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea-public" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-dark --manual-gate"; do
  if grep -F "$unexpected" "$OUTPUT" >/dev/null; then
    echo "manual proof refresh default print included proof-only target: $unexpected" >&2
    exit 1
  fi
done

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$NO_FINGERPRINT_REPORT" \
  script/manual_proof_refresh.sh --print --all >"$OUTPUT"
for expected in \
  "All proof target status:" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea-public" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-dark --manual-gate"; do
  if ! grep -F "$expected" "$OUTPUT" >/dev/null; then
    echo "manual proof refresh --all print output missed: $expected" >&2
    exit 1
  fi
done

script/manual_proof_refresh.sh --dry-run --target textedit >"$OUTPUT"
if ! grep -F "would run 1: TextEdit" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh dry-run did not list the selected target" >&2
  exit 1
fi

if script/manual_proof_refresh.sh --run >"$OUTPUT" 2>&1; then
  echo "manual proof refresh --run should require --target or --all" >&2
  exit 1
fi

if ! grep -F -- "--run needs --target SLUG or --all" "$OUTPUT" >/dev/null; then
  echo "manual proof refresh --run did not explain target selection" >&2
  exit 1
fi

if script/manual_proof_refresh.sh --dry-run --target nope >"$OUTPUT" 2>&1; then
  echo "manual proof refresh should reject unknown targets" >&2
  exit 1
fi

echo "Manual proof refresh self-test passed."
