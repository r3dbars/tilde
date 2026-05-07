import Foundation

public enum InsertionModePlan {
    public static func modes(
        for profile: CompatibilityProfile,
        skipping skippedModes: Set<InsertionMode> = []
    ) -> [InsertionMode] {
        var modes: [InsertionMode] = []

        append(profile.insertionMode, to: &modes, skipping: skippedModes)

        if let fallback = profile.fallbackInsertionMode {
            append(fallback, to: &modes, skipping: skippedModes)
        }

        return modes
    }

    private static func append(
        _ mode: InsertionMode,
        to modes: inout [InsertionMode],
        skipping skippedModes: Set<InsertionMode>
    ) {
        guard mode != .disabled,
              mode != .clipboardFallbackOptIn,
              !skippedModes.contains(mode),
              !modes.contains(mode) else {
            return
        }

        modes.append(mode)
    }
}
