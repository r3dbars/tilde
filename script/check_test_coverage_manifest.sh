#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "test coverage manifest failed: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing $path"
}

require_pattern() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  grep -E "$pattern" "$path" >/dev/null || fail "missing $label in $path"
}

require_file "Tests/AutocompleteLabCoreTests/CompletionActivationPolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionActivationPolicyTests.swift" "Blocks secure or suppressed fields" "secure-field activation coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionActivationPolicyTests.swift" "Blocks suggestions in the middle of existing text" "middle-of-line activation coverage"

require_file "Tests/AutocompleteLabCoreTests/KeyboardActionRouterTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/KeyboardActionRouterTests.swift" "Option Tab passes through" "Option+Tab passthrough coverage"
require_pattern "Tests/AutocompleteLabCoreTests/KeyboardActionRouterTests.swift" "Backtick accepts all visible text" "full-accept key routing coverage"

require_file "Tests/AutocompleteLabCoreTests/RuntimePolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/RuntimePolicyTests.swift" "Runtime production readiness requires native preferred runtime" "native-runtime readiness coverage"
require_pattern "Tests/AutocompleteLabCoreTests/RuntimePolicyTests.swift" "Runtime readiness blocks suggestions" "runtime suppression coverage"

require_file "Tests/AutocompleteLabCoreTests/ModelPolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/ModelPolicyTests.swift" "app-owned large MLX model" "app-owned MLX policy coverage"

require_file "Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift" "MVP target apps are explicitly profiled" "target app profile coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift" "Denylisted apps are never allowed" "denylist coverage"

require_file "Tests/AutocompleteLabCoreTests/DiagnosticValueRedactorTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/DiagnosticValueRedactorTests.swift" "without raw text" "privacy-safe diagnostics coverage"
require_pattern "Tests/AutocompleteLabCoreTests/DiagnosticValueRedactorTests.swift" "redacts likely raw text keys" "raw-text redaction coverage"

require_file "Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift" "Verifies accepted text landed exactly" "successful insertion verification coverage"
require_pattern "Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift" "Detects unchanged and partially inserted text" "failed insertion verification coverage"

require_file "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift" "Suppresses one word twitch completions" "model-output cleanup coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift" "Removes thinking tags" "thinking-tag cleanup coverage"

echo "Test coverage manifest verified."
