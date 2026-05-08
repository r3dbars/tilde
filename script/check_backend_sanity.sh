#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "backend sanity failed: $*" >&2
  exit 1
}

if rg -n "MockModelRuntime" Sources/AutocompleteLabApp >/dev/null; then
  rg -n "MockModelRuntime" Sources/AutocompleteLabApp >&2
  fail "app target must not wire mock model runtime"
fi

copy_paths=(
  README.md
  Sources
  docs/research/runtime-options.md
  docs/product/private-beta-plan.md
  docs/product/beta-readiness-checklist.md
)

if rg -n "falls back to mock suggestions|Mock Fallback|gemmaLocalWithMockFallback" "${copy_paths[@]}" >/dev/null; then
  rg -n "falls back to mock suggestions|Mock Fallback|gemmaLocalWithMockFallback" "${copy_paths[@]}" >&2
  fail "product copy must not present mock fallback as runtime readiness"
fi

if rg -n "return \\.mock" Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift >/dev/null; then
  rg -n "return \\.mock" Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift >&2
  fail "runtime bootstrap must not select mock for app readiness"
fi

if ! rg -n "mockFallbackAllowed.*false" Sources/AutocompleteLabApp/Runtime/AppModelRuntimeFactory.swift >/dev/null; then
  fail "runtime bootstrap diagnostics must state mock fallback is disabled"
fi

if rg -n "MockCompletionEngine|mockFallback" Sources/AutocompleteLabCore/Engine/LocalCompletionEngine.swift >/dev/null; then
  rg -n "MockCompletionEngine|mockFallback" Sources/AutocompleteLabCore/Engine/LocalCompletionEngine.swift >&2
  fail "legacy local completion engine must fail closed instead of falling back to mock suggestions"
fi

if ! rg -n "no mock runtime fallback" docs/research/runtime-options.md >/dev/null; then
  fail "runtime docs must state the no-mock beta rule"
fi

echo "Backend sanity verified: no production mock runtime fallback."
