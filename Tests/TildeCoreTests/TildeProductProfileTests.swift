import Testing
@testable import TildeCore

struct TildeProductProfileTests {
    @Test func resolvesExplicitPreviewProfile() {
        #expect(TildeProductProfile.resolve(
            bundleIdentifier: "anything",
            declaredProfile: "preview-26b"
        ) == .preview26B)
        #expect(TildeProductProfile.resolve(
            bundleIdentifier: "anything",
            declaredProfile: "model-preview"
        ) == .modelPreview)
    }

    @Test func resolvesPreviewBundleIdentifiersWithoutPlistHint() {
        #expect(TildeProductProfile.resolve(
            bundleIdentifier: "bar.r3d.tilde.preview26b",
            declaredProfile: nil
        ) == .preview26B)
        #expect(TildeProductProfile.resolve(
            bundleIdentifier: "bar.r3d.inputmethod.InlineGhostPreview26B",
            declaredProfile: nil
        ) == .preview26B)
        #expect(TildeProductProfile.resolve(
            bundleIdentifier: "bar.r3d.tilde.preview9b",
            declaredProfile: nil
        ) == .preview9B)
        #expect(TildeProductProfile.resolve(
            bundleIdentifier: "bar.r3d.inputmethod.InlineGhostPreview9B",
            declaredProfile: nil
        ) == .preview9B)
        #expect(TildeProductProfile.resolve(
            bundleIdentifier: "bar.r3d.tilde.modelpreview",
            declaredProfile: nil
        ) == .modelPreview)
        #expect(TildeProductProfile.resolve(
            bundleIdentifier: "bar.r3d.inputmethod.InlineGhostModelPreview",
            declaredProfile: nil
        ) == .modelPreview)
    }

    @Test func unknownAndTestBundlesFailSafeToProduction() {
        #expect(TildeProductProfile.resolve(
            bundleIdentifier: "org.swift.swiftpm.xctest",
            declaredProfile: nil
        ) == .production)
    }

    @Test func previewResourcesDoNotOverlapProduction() {
        let production = TildeProductProfile.production
        let previews = [TildeProductProfile.preview26B, .preview9B, .modelPreview]
        #expect(Set(previews.map(\.appBundleIdentifier)).count == previews.count)
        #expect(Set(previews.map(\.inputMethodBundleIdentifier)).count == previews.count)
        #expect(Set(previews.map(\.inputMethodConnectionName)).count == previews.count)
        #expect(Set(previews.map(\.supportDirectoryName)).count == previews.count)
        #expect(Set(previews.map(\.inputMethodInstalledBundleName)).count == previews.count)
        #expect(Set(previews.map(\.llamaServerPort)).count == previews.count)
        for preview in previews {
            #expect(preview.appBundleIdentifier != production.appBundleIdentifier)
            #expect(preview.inputMethodBundleIdentifier != production.inputMethodBundleIdentifier)
            #expect(preview.inputMethodConnectionName != production.inputMethodConnectionName)
            #expect(preview.supportDirectoryName != production.supportDirectoryName)
            #expect(preview.inputMethodInstalledBundleName != production.inputMethodInstalledBundleName)
            #expect(preview.llamaServerPort != production.llamaServerPort)
            #expect(preview.personalHistoryKeychainService != production.personalHistoryKeychainService)
        }
        #expect(production.generatedTokenBudget == 20)
        #expect(TildeProductProfile.preview26B.generatedTokenBudget == 8)
        #expect(TildeProductProfile.modelPreview.generatedTokenBudget == 8)
        #expect(TildeProductProfile.preview9B.generatedTokenBudget == 12)
        #expect(production.completionTemperature == 0)
        #expect(production.maximumVisibleWords == CompletionSuggestion.defaultMaxVisibleWords)
        #expect(TildeProductProfile.preview9B.completionTemperature == 0.10)
        #expect(TildeProductProfile.preview9B.maximumVisibleWords == 3)
        #expect(TildeProductProfile.preview26B.completionTemperature == 0)
        #expect(TildeProductProfile.preview26B.maximumVisibleWords == CompletionSuggestion.defaultMaxVisibleWords)
    }

    @Test func modelPreviewChoicesHaveStableOwnerFacingLabels() {
        #expect(PreviewModelChoice.resolve(persistedValue: nil) == .qwen35B9B)
        #expect(PreviewModelChoice.resolve(persistedValue: "unknown") == .qwen35B9B)
        #expect(PreviewModelChoice.resolve(
            persistedValue: PreviewModelChoice.gemma426B.rawValue
        ) == .gemma426B)
        #expect(PreviewModelChoice.allCases.allSatisfy { !$0.displayName.isEmpty })
    }

    @Test func productionModelChoicesDefaultSafelyAndDescribeResources() {
        #expect(TildeModelChoice.resolve(persistedValue: nil) == .gemma4E2B)
        #expect(TildeModelChoice.resolve(persistedValue: "unknown") == .gemma4E2B)
        #expect(TildeModelChoice.resolve(
            persistedValue: TildeModelChoice.qwen35B9B.rawValue
        ) == .qwen35B9B)
        #expect(TildeModelChoice.allCases == [.gemma4E2B, .qwen35B9B])
        #expect(TildeModelChoice.allCases.allSatisfy {
            !$0.displayName.isEmpty && !$0.approximateSize.isEmpty && !$0.resourceGuidance.isEmpty
        })
    }
}
