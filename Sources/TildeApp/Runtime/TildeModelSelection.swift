import Foundation
import TildeCore

/// Selection for the official Tilde app. Preview identities keep their own
/// fixed/experimental selection rules and cannot retarget production.
enum TildeModelSelection {
    static let defaultsKey = "SelectedModelChoice"
    static let releaseProofEnvironmentKey = "TILDE_RELEASE_PROOF_MODEL"

    static func choice(
        for profile: TildeProductProfile,
        defaults: UserDefaults? = nil
    ) -> TildeModelChoice? {
        guard profile == .production else { return nil }
        return TildeModelChoice.resolve(
            persistedValue: (defaults ?? .standard).string(forKey: defaultsKey)
        )
    }

    static func releaseProofChoice(environment: [String: String]) -> TildeModelChoice {
        TildeModelChoice.resolve(persistedValue: environment[releaseProofEnvironmentKey])
    }

    static func descriptor(
        for profile: TildeProductProfile,
        productionChoice: TildeModelChoice?,
        previewDefaults: UserDefaults? = nil
    ) -> ModelDescriptor {
        switch productionChoice {
        case .gemma4E2B: .gemma4E2BQ4KM
        case .qwen35B9B: .qwen35B9BQ4KM
        case nil: PreviewModelSelection.descriptor(for: profile, defaults: previewDefaults)
        }
    }

    static func completionProfile(
        for profile: TildeProductProfile,
        productionChoice: TildeModelChoice?,
        previewDefaults: UserDefaults? = nil
    ) -> TildeProductProfile {
        if productionChoice == .qwen35B9B { return .preview9B }
        return PreviewModelSelection.completionProfile(for: profile, defaults: previewDefaults)
    }

    static func persist(_ choice: TildeModelChoice, defaults: UserDefaults? = nil) {
        (defaults ?? .standard).set(choice.rawValue, forKey: defaultsKey)
    }
}
