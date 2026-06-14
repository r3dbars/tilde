import Foundation
import Testing

@Suite("Live suggestion wiring")
struct LiveSuggestionWiringTests {
    @Test("App delegate wires product predictors and display policies through the orchestrator")
    func appDelegateWiresProductPredictorsAndDisplayPolicies() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")

        try require(appDelegate, contains: "private lazy var suggestionOrchestrator = SuggestionOrchestrator(")
        try require(appDelegate, contains: "wordCompletionRanker: wordCompletionRanker")
        try require(appDelegate, contains: "prefixFamilyCooldownPolicy: makePrefixFamilyCooldownPolicy()")
        try require(appDelegate, contains: "suggestionOrchestrator.beginRequest(SuggestionRequestInput(")
        try require(appDelegate, contains: "suggestionOrchestrator.startStreamingPresentation(suggestionID: suggestionID)")
        try require(appDelegate, contains: "suggestionOrchestrator.fastWordSelection(")
        try require(appDelegate, contains: "triggerReason: \"fast-word-completion\"")
        try require(appDelegate, contains: "suggestionOrchestrator.fastPhraseSelection(")
        try require(appDelegate, contains: "suggestionOrchestrator.fastPhraseFallbackLearningDecision(")
        try require(appDelegate, contains: "triggerReason: \"canned-bridge\"")
        try require(appDelegate, contains: "try await suggestionOrchestrator.suggestion(")
        try require(appDelegate, contains: "suggestionOrchestrator.shouldPresentStreamingPartial(")
        try require(appDelegate, contains: "suggestionOrchestrator.displayScoreDecision(")
        try require(appDelegate, contains: "suggestionOrchestrator.replacementDecision(")
        try require(appDelegate, contains: "suggestionOrchestrator.placementHealthPlan(")
        try require(appDelegate, contains: "suggestionOrchestrator.placementSuppressionResolution(")
    }

    @Test("Coverage manifest invokes public core reachability check")
    func coverageManifestInvokesPublicCoreReachabilityCheck() throws {
        let coverageCheck = try source("script/check_test_coverage_manifest.sh")

        try require(coverageCheck, contains: "./script/check_public_core_wiring.py")
    }
}

private func source(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = root.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private func require(_ text: String, contains needle: String) throws {
    if !text.contains(needle) {
        Issue.record("Expected source to contain \(needle)")
    }
}
