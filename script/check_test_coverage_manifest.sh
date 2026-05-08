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
require_pattern "Tests/AutocompleteLabCoreTests/CompletionActivationPolicyTests.swift" "Blocks selected text" "selected-text activation coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionActivationPolicyTests.swift" "Blocks suggestions in the middle of existing text" "middle-of-line activation coverage"

require_file "Tests/AutocompleteLabCoreTests/SensitiveTextFieldPolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/SensitiveTextFieldPolicyTests.swift" "Blocks browser and Electron password-like fields" "password-like sensitive field coverage"
require_pattern "Tests/AutocompleteLabCoreTests/SensitiveTextFieldPolicyTests.swift" "Blocks token and API key fields" "token/API-key sensitive field coverage"

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

require_file "Tests/AutocompleteLabCoreTests/PlacementHealthTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/PlacementHealthTests.swift" "Falls back when caret is outside focused bounds" "placement self-healing coverage"
require_pattern "Tests/AutocompleteLabCoreTests/PlacementHealthTests.swift" "Suppresses missing inline caret when detached anchors are disabled" "unsafe detached placement coverage"
require_pattern "Tests/AutocompleteLabCoreTests/PlacementHealthTests.swift" "placementConfidenceBand" "placement confidence metadata coverage"
require_pattern "Tests/AutocompleteLabCoreTests/PlacementHealthTests.swift" "Drops stale text line rects" "stale text-line rejection coverage"

require_file "Tests/AutocompleteLabCoreTests/SuggestionPanelFrameCalculatorTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/SuggestionPanelFrameCalculatorTests.swift" "vertical editor clipping" "vertical clipping frame coverage"

require_file "Tests/AutocompleteLabCoreTests/PromptEditorFingerprintPolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/PromptEditorFingerprintPolicyTests.swift" "Blocks large central dogfood text areas" "dogfood prompt textbox coverage"
require_pattern "Tests/AutocompleteLabCoreTests/PromptEditorFingerprintPolicyTests.swift" "Allows prompt-like composer geometry" "prompt geometry fallback coverage"

require_file "Tests/AutocompleteLabCoreTests/DiagnosticValueRedactorTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/DiagnosticValueRedactorTests.swift" "without raw text" "privacy-safe diagnostics coverage"
require_pattern "Tests/AutocompleteLabCoreTests/DiagnosticValueRedactorTests.swift" "redacts likely raw text keys" "raw-text redaction coverage"

require_file "Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift" "Verifies accepted text landed exactly" "successful insertion verification coverage"
require_pattern "Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift" "Detects unchanged and partially inserted text" "failed insertion verification coverage"
require_file "Tests/AutocompleteLabCoreTests/InsertionVerificationPreflightPolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/InsertionVerificationPreflightPolicyTests.swift" "Fails when focus moved to another app" "post-accept app mismatch coverage"
require_pattern "Tests/AutocompleteLabCoreTests/InsertionVerificationPreflightPolicyTests.swift" "Fails when focus moved to another field in the same app" "post-accept field mismatch coverage"

require_file "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift" "Suppresses one word twitch completions" "model-output cleanup coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift" "Allows single token word completion suffixes" "word-completion cleanup coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift" "Removes thinking tags" "thinking-tag cleanup coverage"

require_file "Tests/AutocompleteLabCoreTests/CompletionQualityEvalTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionQualityEvalTests.swift" "Keeps suggestions usable for the tight typing loop" "quality eval corpus coverage"

require_file "Tests/AutocompleteLabCoreTests/SuggestionPresentationGateTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/SuggestionPresentationGateTests.swift" "streamed phrase partials wait for enough visible words" "streaming presentation coverage"
require_pattern "Tests/AutocompleteLabCoreTests/SuggestionPresentationGateTests.swift" "streaming suppresses duplicate and tiny same-word changes" "streaming churn coverage"

require_file "Tests/AutocompleteLabCoreTests/SuggestionAcceptanceGuardTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/SuggestionAcceptanceGuardTests.swift" "Blocks accept after app bundle changes" "wrong-app accept guard coverage"
require_pattern "Tests/AutocompleteLabCoreTests/SuggestionAcceptanceGuardTests.swift" "Blocks accept when text before cursor changed" "text snapshot accept guard coverage"
require_file "Tests/AutocompleteLabCoreTests/FocusedFieldIdentityPolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/FocusedFieldIdentityPolicyTests.swift" "Stable bounds mode uses a deterministic hash fixture" "stable field identity hash coverage"

require_file "Tests/AutocompleteLabCoreTests/TypingBurstPolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/TypingBurstPolicyTests.swift" "Fast repeated character inserts become a burst" "typing-burst silence coverage"

require_file "Tests/AutocompleteLabCoreTests/CompletionConfidencePolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionConfidencePolicyTests.swift" "Blocks thin-context phrase continuations" "low-confidence weak-context coverage"
require_pattern "Tests/AutocompleteLabCoreTests/CompletionConfidencePolicyTests.swift" "Yellow profiles make long phrase suggestions low confidence" "profile confidence penalty coverage"

require_file "Tests/AutocompleteLabCoreTests/TracePrivacyPolicyTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/TracePrivacyPolicyTests.swift" "Secure field traces keep only shape data by default" "secure-field trace privacy coverage"
require_pattern "Tests/AutocompleteLabCoreTests/TracePrivacyPolicyTests.swift" "Unsupported app traces redact typed content by default" "unsupported-app trace privacy coverage"

require_file "Tests/AutocompleteLabCoreTests/WordCompletionCandidateRankerTests.swift"
require_pattern "Tests/AutocompleteLabCoreTests/WordCompletionCandidateRankerTests.swift" "suppresses tiny recent suffixes until the fragment is strong" "recent-word completion quality coverage"

echo "Test coverage manifest verified."
