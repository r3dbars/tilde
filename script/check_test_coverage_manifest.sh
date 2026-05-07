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
require_file "Tests/AutocompleteLabCoreTests/AXFieldClassifierTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/AXFieldClassifierTests.swift" "Classifies search and URL fields" "field-kind classifier coverage"
require_pattern "Tests/AutocompleteLabCoreTests/AXFieldClassifierTests.swift" "Classifies form fields" "unsafe form-field coverage"

require_file "Tests/AutocompleteLabCoreTests/AnnoyanceSuppressorTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/AnnoyanceSuppressorTests.swift" "Decays scores by half-life" "annoyance half-life coverage"
require_pattern "Tests/AutocompleteLabCoreTests/AnnoyanceSuppressorTests.swift" "Repeated severe failures quiet the app" "app quiet-mode coverage"
require_pattern "Tests/AutocompleteLabCoreTests/AnnoyanceSuppressorTests.swift" "Wrong insertion hard-stops the field" "severe hard-stop coverage"

require_file "Tests/AutocompleteLabCoreTests/KeyboardActionRouterTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/KeyboardActionRouterTests.swift" "Option Tab passes through" "Option+Tab passthrough coverage"
require_pattern "Tests/AutocompleteLabCoreTests/KeyboardActionRouterTests.swift" "Backtick accepts all visible text" "full-accept key routing coverage"

require_file "Tests/AutocompleteLabCoreTests/RuntimePolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/RuntimePolicyTests.swift" "Runtime production readiness requires native preferred runtime" "native-runtime readiness coverage"
require_pattern "Tests/AutocompleteLabCoreTests/RuntimePolicyTests.swift" "Runtime readiness blocks suggestions" "runtime suppression coverage"

require_file "Tests/AutocompleteLabCoreTests/ModelPolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/ModelPolicyTests.swift" "app-owned Qwen MLX model" "app-owned MLX policy coverage"

require_file "Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift" "MVP target apps are explicitly profiled" "target app profile coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift" "Denylisted apps are never allowed" "denylist coverage"
require_file "Tests/AutocompleteLabCoreTests/CompatibilitySupportEvaluatorTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/CompatibilitySupportEvaluatorTests.swift" "TextEdit can pass supported gates" "compatibility supported-state coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompatibilitySupportEvaluatorTests.swift" "Obsidian detached suppression is a caveat" "compatibility caveat coverage"

require_file "Tests/AutocompleteLabCoreTests/DiagnosticValueRedactorTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/DiagnosticValueRedactorTests.swift" "without raw text" "privacy-safe diagnostics coverage"
require_pattern "Tests/AutocompleteLabCoreTests/DiagnosticValueRedactorTests.swift" "redacts likely raw text keys" "raw-text redaction coverage"

require_file "Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift" "Verifies accepted text landed exactly" "successful insertion verification coverage"
require_pattern "Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift" "Detects unchanged and partially inserted text" "failed insertion verification coverage"
require_pattern "Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift" "Detects duplicate accepted text" "duplicate insertion detection coverage"

require_file "Tests/AutocompleteLabCoreTests/AcceptanceSurvivalClassifierTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/AcceptanceSurvivalClassifierTests.swift" "Classifies exact kept text" "accepted-and-kept exact survival coverage"
require_pattern "Tests/AutocompleteLabCoreTests/AcceptanceSurvivalClassifierTests.swift" "Classifies immediate deletes as rejected" "accepted-and-kept rejection coverage"
require_file "Tests/AutocompleteLabCoreTests/AutocompleteTraceAnalyzerTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/AutocompleteTraceAnalyzerTests.swift" "summarizes field-kind slices" "field-kind trace slice coverage"

require_file "Tests/AutocompleteLabCoreTests/AutocompleteTraceEventTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/AutocompleteTraceEventTests.swift" "Encodes current schema and privacy versions" "trace schema version coverage"
require_pattern "Tests/AutocompleteLabCoreTests/AutocompleteTraceEventTests.swift" "Decodes old trace events without schema fields" "trace schema migration coverage"
require_pattern "Tests/AutocompleteLabCoreTests/AutocompleteTraceEventTests.swift" "Default trace redaction removes raw text" "default trace redaction coverage"

require_file "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift" "Suppresses low value one word phrase completions" "model-output cleanup coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift" "Allows single token word completion suffixes" "word-completion cleanup coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift" "Removes thinking tags" "thinking-tag cleanup coverage"

echo "Test coverage manifest verified."
