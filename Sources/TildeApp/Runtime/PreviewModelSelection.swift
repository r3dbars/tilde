import TildeCore
import Foundation

/// Local-only selection for the consolidated model-preview build. Legacy
/// single-model previews remain fixed so an old test build cannot silently
/// change identity underneath an evaluation.
enum PreviewModelSelection {
    static let defaultsKey = "ExperimentalModelChoice"

    static func choice(
        for profile: TildeProductProfile,
        defaults: UserDefaults? = nil
    ) -> PreviewModelChoice? {
        switch profile {
        case .production:
            nil
        case .preview9B:
            .qwen35B9B
        case .preview26B:
            .gemma426B
        case .modelPreview:
            PreviewModelChoice.resolve(
                persistedValue: (defaults ?? profileDefaults)?.string(forKey: defaultsKey)
            )
        }
    }

    static func descriptor(
        for profile: TildeProductProfile,
        defaults: UserDefaults? = nil
    ) -> ModelDescriptor {
        switch choice(for: profile, defaults: defaults) {
        case .qwen35B9B: .qwen35B9BQ4KMPreview
        case .gemma426B: .gemma426BA4BQ4KMPreview
        case nil: .gemma4E2BQ4KM
        }
    }

    /// Reuses the Lab-promoted Qwen controls when the consolidated preview
    /// is currently serving Qwen, while leaving every other model untouched.
    static func completionProfile(
        for profile: TildeProductProfile,
        defaults: UserDefaults? = nil
    ) -> TildeProductProfile {
        choice(for: profile, defaults: defaults) == .qwen35B9B
            ? .preview9B
            : profile
    }

    static func persist(_ choice: PreviewModelChoice, defaults: UserDefaults? = nil) {
        (defaults ?? profileDefaults)?.set(choice.rawValue, forKey: defaultsKey)
    }

    private static var profileDefaults: UserDefaults? {
        .standard
    }
}
