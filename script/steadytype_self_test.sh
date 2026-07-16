#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

COMMAND="$ROOT_DIR/script/steadytype"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "steadytype dispatch self-test FAILED: $*" >&2
  exit 1
}

[[ -x "$COMMAND" ]] || fail "$COMMAND is not executable"

capture_exit() {
  local output_file="$1"
  shift
  local status=0
  "$@" >"$output_file" 2>&1 || status=$?
  echo "$status"
}

source "$COMMAND"

CAPTURED=()
run_target() {
  CAPTURED=("$@")
}

assert_dispatch() {
  local operation="$1"
  shift
  local expected=("$@")
  local index

  CAPTURED=()
  dispatch "$operation"

  [[ "${#CAPTURED[@]}" -eq "${#expected[@]}" ]] \
    || fail "$operation dispatched ${#CAPTURED[@]} arguments instead of ${#expected[@]}"

  for ((index = 0; index < ${#expected[@]}; index++)); do
    [[ "${CAPTURED[$index]}" == "${expected[$index]}" ]] \
      || fail "$operation argument $index was '${CAPTURED[$index]}' instead of '${expected[$index]}'"
  done
}

assert_dispatch build "$ROOT_DIR/script/build_and_run.sh" --bundle-only
assert_dispatch test "$ROOT_DIR/script/proof.sh" fast
assert_dispatch smoke "$ROOT_DIR/script/smoke_test.sh"
assert_dispatch eval "$ROOT_DIR/script/check_quality_eval.sh"
assert_dispatch release "$ROOT_DIR/script/package_release.sh"

CAPTURED=()
dispatch release --check
[[ "${#CAPTURED[@]}" -eq 2 ]] \
  || fail "release did not forward exactly one argument"
[[ "${CAPTURED[0]}" == "$ROOT_DIR/script/package_release.sh" ]] \
  || fail "release dispatched to the wrong command"
[[ "${CAPTURED[1]}" == "--check" ]] \
  || fail "release did not forward --check"

for operation in build test smoke eval; do
  extra_status=0
  dispatch "$operation" unexpected >"$TMP_DIR/$operation-extra.out" 2>&1 \
    || extra_status=$?
  [[ "$extra_status" -eq 2 ]] \
    || fail "$operation accepted an unexpected argument"
done

help_status="$(capture_exit "$TMP_DIR/help.out" "$COMMAND" --help)"
[[ "$help_status" -eq 0 ]] || fail "--help exited $help_status instead of 0"

for operation in build test smoke eval release; do
  grep -Eq "^  $operation[[:space:]]" "$TMP_DIR/help.out" \
    || fail "--help is missing $operation"
done

operation_count="$(grep -Ec '^  (build|test|smoke|eval|release)[[:space:]]' "$TMP_DIR/help.out")"
[[ "$operation_count" -eq 5 ]] \
  || fail "--help exposes $operation_count operations instead of exactly 5"

missing_status="$(capture_exit "$TMP_DIR/missing.out" "$COMMAND")"
[[ "$missing_status" -eq 2 ]] \
  || fail "missing operation exited $missing_status instead of 2"

unknown_status="$(capture_exit "$TMP_DIR/unknown.out" "$COMMAND" unknown)"
[[ "$unknown_status" -eq 2 ]] \
  || fail "unknown operation exited $unknown_status instead of 2"
grep -Fq "unknown operation 'unknown'" "$TMP_DIR/unknown.out" \
  || fail "unknown operation did not explain the error"

echo "steadytype dispatch self-test: PASS"
