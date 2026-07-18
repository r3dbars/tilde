#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT_DIR/script/check_complexity_budget.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/steadytype-complexity-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
unset PROOF_STRUCTURAL_CHANGE PROOF_DIFF_BASE PROOF_STRUCTURAL_LOC_EXCEPTION

fail() { echo "complexity budget self-test: $*" >&2; exit 1; }
require() { grep -Fq "$1" <<<"$2" || fail "missing '$1'"; }

fixture() {
  local root="$TMP_ROOT/$1"
  mkdir -p "$root/Sources/AutocompleteLabApp/App" "$root/Sources/AutocompleteLabCore" "$root/script" "$root/docs"
  cp "$CHECK" "$root/script/check_complexity_budget.sh"
  chmod +x "$root/script/check_complexity_budget.sh"
  printf '%s\n' 'struct Example {}' > "$root/Sources/AutocompleteLabCore/Example.swift"
  printf '%s\n' 'final class AppDelegate {}' > "$root/Sources/AutocompleteLabApp/App/AppDelegate.swift"
  printf '%s\n' '# fixture' > "$root/docs/fixture.md"
  git -C "$root" init -q
  git -C "$root" config user.email "complexity-budget@example.invalid"
  git -C "$root" config user.name "Complexity Budget Test"
  git -C "$root" add .
  git -C "$root" commit -qm baseline
  echo "$root"
}

pass_root="$(fixture pass)"
pass_output="$(cd "$pass_root" && script/check_complexity_budget.sh)"
require 'production Swift LOC: 2 / 90000' "$pass_output"
require 'AppDelegate LOC:      1 / 17244' "$pass_output"
require 'scripts:              1 / 35' "$pass_output"
require 'docs files:           1 / 30' "$pass_output"
require 'largest production Swift files' "$pass_output"

limit_root="$(fixture limits)"
awk 'BEGIN { for (i=1; i<=90001; i++) print "// line" }' > "$limit_root/Sources/AutocompleteLabCore/Huge.swift"
awk 'BEGIN { for (i=1; i<=17245; i++) print "// line" }' > "$limit_root/Sources/AutocompleteLabApp/App/AppDelegate.swift"
awk 'BEGIN { for (i=1; i<=3001; i++) print "// line" }' > "$limit_root/Sources/AutocompleteLabCore/Large.swift"
for i in $(seq 1 35); do : > "$limit_root/script/$i.sh"; done
for i in $(seq 1 30); do : > "$limit_root/docs/$i.md"; done
if limit_output="$(cd "$limit_root" && script/check_complexity_budget.sh 2>&1)"; then fail "ceilings did not fail"; fi
for message in 'production Swift LOC exceeds 90000' 'AppDelegate.swift LOC exceeds 17244' \
  'Large.swift exceeds 3000 LOC' 'script count exceeds 35' 'docs count exceeds 30'; do
  require "$message" "$limit_output"
done

structural_root="$(fixture structural)"
printf '%s\n' 'struct Example {' '  let value = 1' '}' > "$structural_root/Sources/AutocompleteLabCore/Example.swift"
git -C "$structural_root" add . && git -C "$structural_root" commit -qm growth
if growth="$(cd "$structural_root" && PROOF_STRUCTURAL_CHANGE=1 PROOF_DIFF_BASE=HEAD~1 script/check_complexity_budget.sh 2>&1)"; then
  fail "structural growth did not fail"
fi
require 'net +2' "$growth"
require 'must be net-negative' "$growth"
exception="$(cd "$structural_root" && PROOF_STRUCTURAL_CHANGE=1 PROOF_DIFF_BASE=HEAD~1 PROOF_STRUCTURAL_LOC_EXCEPTION=1 script/check_complexity_budget.sh)"
require 'exception acknowledged' "$exception"
: > "$structural_root/Sources/AutocompleteLabCore/Example.swift"
git -C "$structural_root" add . && git -C "$structural_root" commit -qm shrink
shrink="$(cd "$structural_root" && PROOF_STRUCTURAL_CHANGE=1 PROOF_DIFF_BASE=HEAD~2 script/check_complexity_budget.sh)"
require 'net -1' "$shrink"

require 'run_blocking "complexity budget" bash script/check_complexity_budget.sh' "$(<"$ROOT_DIR/script/proof.sh")"
echo "complexity budget self-test: PASS"
