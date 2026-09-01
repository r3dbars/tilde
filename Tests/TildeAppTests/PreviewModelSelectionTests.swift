import TildeCore
import Foundation
import Testing
@testable import TildeApp

struct PreviewModelSelectionTests {
    @Test func productionRemainsPinnedRegardlessOfPreviewPreference() {
        let defaults = isolatedDefaults()
        defaults.set(PreviewModelChoice.gemma426B.rawValue, forKey: PreviewModelSelection.defaultsKey)
        #expect(PreviewModelSelection.choice(for: .production, defaults: defaults) == nil)
        #expect(PreviewModelSelection.descriptor(for: .production, defaults: defaults) == .gemma4E2BQ4KM)
    }

    @Test func consolidatedPreviewDefaultsTo9BAndPersists26B() {
        let defaults = isolatedDefaults()
        #expect(PreviewModelSelection.choice(for: .modelPreview, defaults: defaults) == .qwen35B9B)
        PreviewModelSelection.persist(.gemma426B, defaults: defaults)
        #expect(PreviewModelSelection.choice(for: .modelPreview, defaults: defaults) == .gemma426B)
        #expect(PreviewModelSelection.descriptor(for: .modelPreview, defaults: defaults) == .gemma426BA4BQ4KMPreview)
    }

    @Test func legacyPreviewsCannotBeRetargetedByPreference() {
        let defaults = isolatedDefaults()
        defaults.set(PreviewModelChoice.gemma426B.rawValue, forKey: PreviewModelSelection.defaultsKey)
        #expect(PreviewModelSelection.choice(for: .preview9B, defaults: defaults) == .qwen35B9B)
        defaults.set(PreviewModelChoice.qwen35B9B.rawValue, forKey: PreviewModelSelection.defaultsKey)
        #expect(PreviewModelSelection.choice(for: .preview26B, defaults: defaults) == .gemma426B)
    }

    @Test func consolidatedPreviewUsesQwenGodControlsOnlyForQwen() {
        let defaults = isolatedDefaults()
        PreviewModelSelection.persist(.qwen35B9B, defaults: defaults)
        #expect(PreviewModelSelection.completionProfile(
            for: .modelPreview,
            defaults: defaults
        ) == .preview9B)

        PreviewModelSelection.persist(.gemma426B, defaults: defaults)
        #expect(PreviewModelSelection.completionProfile(
            for: .modelPreview,
            defaults: defaults
        ) == .modelPreview)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "bar.r3d.tilde.tests.preview-model.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

struct TildeModelSelectionTests {
    @Test func productionDefaultsToGemmaAndPersistsQwen() {
        let defaults = isolatedDefaults()
        #expect(TildeModelSelection.choice(for: .production, defaults: defaults) == .gemma4E2B)

        TildeModelSelection.persist(.qwen35B9B, defaults: defaults)
        let choice = TildeModelSelection.choice(for: .production, defaults: defaults)
        #expect(choice == .qwen35B9B)
        #expect(TildeModelSelection.descriptor(
            for: .production,
            productionChoice: choice
        ) == .qwen35B9BQ4KM)
        #expect(TildeModelSelection.completionProfile(
            for: .production,
            productionChoice: choice
        ) == .preview9B)
    }

    @Test func productionGemmaKeepsProductionControls() {
        #expect(TildeModelSelection.descriptor(
            for: .production,
            productionChoice: .gemma4E2B
        ) == .gemma4E2BQ4KM)
        #expect(TildeModelSelection.completionProfile(
            for: .production,
            productionChoice: .gemma4E2B
        ) == .production)
    }

    @Test func previewsCannotReadTheProductionPreference() {
        let defaults = isolatedDefaults()
        TildeModelSelection.persist(.qwen35B9B, defaults: defaults)
        #expect(TildeModelSelection.choice(for: .preview9B, defaults: defaults) == nil)
        #expect(TildeModelSelection.choice(for: .modelPreview, defaults: defaults) == nil)
    }

    @Test func releaseProofDefaultsToGemmaAndCanSelectEitherPinnedModel() {
        #expect(TildeModelSelection.releaseProofChoice(environment: [:]) == .gemma4E2B)
        #expect(TildeModelSelection.releaseProofChoice(environment: [
            TildeModelSelection.releaseProofEnvironmentKey: TildeModelChoice.qwen35B9B.rawValue
        ]) == .qwen35B9B)
        #expect(TildeModelSelection.releaseProofChoice(environment: [
            TildeModelSelection.releaseProofEnvironmentKey: "unknown"
        ]) == .gemma4E2B)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "bar.r3d.tilde.tests.production-model.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
