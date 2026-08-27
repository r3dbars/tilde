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
