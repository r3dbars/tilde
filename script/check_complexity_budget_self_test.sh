#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT_DIR/script/check_complexity_budget.sh"
PROOF="$ROOT_DIR/script/proof.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/steadytype-complexity-budget-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  echo "complexity budget self-test: $*" >&2
  exit 1
}

new_fixture() {
  local name="$1"
  local fixture="$TMP_ROOT/$name"
  mkdir -p "$fixture/Sources/AutocompleteLabApp/App" "$fixture/Sources/AutocompleteLabCore" "$fixture/script" "$fixture/docs"
  cp "$CHECK" "$fixture/script/check_complexity_budget.sh"
  chmod +x "$fixture/script/check_complexity_budget.sh"
  git -C "$fixture" init -q
  git -C "$fixture" config user.email "complexity-budget@example.invalid"
  git -C "$fixture" config user.name "Complexity Budget Test"
  printf '%s\n' 'struct Example {}' > "$fixture/Sources/AutocompleteLabCore/Example.swift"
  printf '%s\n' 'final class AppDelegate {}' > "$fixture/Sources/AutocompleteLabApp/App/AppDelegate.swift"
  printf '%s\n' '# fixture' > "$fixture/docs/fixture.md"
  git -C "$fixture" add .
  git -C "$fixture" commit -qm baseline
  echo "$fixture"
}

proof_functions="$(sed -n '/^is_truthy()/,/^}/p; /^run_complexity_budget()/,/^}/p' "$PROOF")"
if ! (
  cd "$ROOT_DIR"
  PROOF_STRUCTURAL_CHANGE= PROOF_DIFF_BASE= PROOF_STRUCTURAL_LOC_EXCEPTION= \
    /bin/bash -u -c "$proof_functions"$'\nrun_complexity_budget' >/dev/null
); then
  fail "normal proof integration failed under macOS Bash"
fi
if ! (
  cd "$ROOT_DIR"
  PROOF_STRUCTURAL_CHANGE=1 PROOF_DIFF_BASE=HEAD PROOF_STRUCTURAL_LOC_EXCEPTION=1 \
    /bin/bash -u -c "$proof_functions"$'\nrun_complexity_budget' >/dev/null
); then
  fail "structural proof integration failed under macOS Bash"
fi

pass_fixture="$(new_fixture pass)"
pass_output="$(cd "$pass_fixture" && script/check_complexity_budget.sh)"
grep -Fq 'production Swift LOC: 2 / 90000' <<<"$pass_output" || fail "missing production LOC report"
grep -Fq 'AppDelegate LOC:      1 / 17244' <<<"$pass_output" || fail "missing AppDelegate report"
grep -Fq 'scripts:              1 / 35' <<<"$pass_output" || fail "missing scripts report"
grep -Fq 'docs files:           1 / 30' <<<"$pass_output" || fail "missing docs report"
grep -Fq 'largest production Swift files' <<<"$pass_output" || fail "missing largest-files report"
grep -Fq '[PASS] complexity budget' <<<"$pass_output" || fail "under-budget fixture did not pass"

total_fixture="$(new_fixture total-limit)"
awk 'BEGIN { for (i = 1; i <= 90001; i++) print "// production line" }' \
  > "$total_fixture/Sources/AutocompleteLabCore/Huge.swift"
if total_output="$(cd "$total_fixture" && script/check_complexity_budget.sh 2>&1)"; then
  fail "total production LOC ceiling did not fail"
fi
grep -Fq 'production Swift LOC exceeds 90000' <<<"$total_output" || fail "wrong total LOC failure"

app_fixture="$(new_fixture app-delegate-limit)"
awk 'BEGIN { for (i = 1; i <= 17245; i++) print "// app delegate line" }' \
  > "$app_fixture/Sources/AutocompleteLabApp/App/AppDelegate.swift"
if app_output="$(cd "$app_fixture" && script/check_complexity_budget.sh 2>&1)"; then
  fail "AppDelegate ceiling did not fail"
fi
grep -Fq 'AppDelegate.swift exceeds 17244 LOC' <<<"$app_output" || fail "wrong AppDelegate failure"

file_fixture="$(new_fixture file-limit)"
awk 'BEGIN { for (i = 1; i <= 3001; i++) print "// production line" }' \
  > "$file_fixture/Sources/AutocompleteLabCore/Large.swift"
if file_output="$(cd "$file_fixture" && script/check_complexity_budget.sh 2>&1)"; then
  fail "non-AppDelegate file ceiling did not fail"
fi
grep -Fq 'Large.swift exceeds the non-AppDelegate ceiling of 3000 LOC' <<<"$file_output" || fail "wrong file LOC failure"

count_fixture="$(new_fixture count-limits)"
for index in $(seq 1 35); do
  : > "$count_fixture/script/extra-$index.sh"
done
for index in $(seq 1 30); do
  : > "$count_fixture/docs/extra-$index.md"
done
if count_output="$(cd "$count_fixture" && script/check_complexity_budget.sh 2>&1)"; then
  fail "script/docs ceilings did not fail"
fi
grep -Fq 'script count exceeds 35' <<<"$count_output" || fail "wrong script-count failure"
grep -Fq 'docs count exceeds 30' <<<"$count_output" || fail "wrong docs-count failure"

structural_fixture="$(new_fixture structural)"
printf '%s\n' 'struct Example {' '    let value = 1' '}' \
  > "$structural_fixture/Sources/AutocompleteLabCore/Example.swift"
git -C "$structural_fixture" add .
git -C "$structural_fixture" commit -qm growth
if structural_output="$(cd "$structural_fixture" && script/check_complexity_budget.sh --structural --base HEAD~1 2>&1)"; then
  fail "non-negative structural diff did not fail"
fi
grep -Fq 'net +2' <<<"$structural_output" || fail "wrong structural growth report"
grep -Fq 'must be net-negative' <<<"$structural_output" || fail "missing structural failure"

exception_output="$(cd "$structural_fixture" && script/check_complexity_budget.sh --structural --base HEAD~1 --structural-exception)"
grep -Fq 'exception acknowledged' <<<"$exception_output" || fail "structural exception did not pass"

: > "$structural_fixture/Sources/AutocompleteLabCore/Example.swift"
git -C "$structural_fixture" add .
git -C "$structural_fixture" commit -qm shrink
shrink_output="$(cd "$structural_fixture" && script/check_complexity_budget.sh --structural --base HEAD~2)"
grep -Fq 'net -1' <<<"$shrink_output" || fail "wrong structural shrink report"
grep -Fq '[PASS] complexity budget' <<<"$shrink_output" || fail "net-negative structural diff did not pass"

echo "complexity budget self-test: PASS"
