import Foundation

public enum InsertionModePlan {
    public static func modes(for profile: CompatibilityProfile) -> [InsertionMode] {
        var modes: [InsertionMode] = []

        append(profile.insertionMode, to: &modes)

        if let fallback = profile.fallbackInsertionMode {
            append(fallback, to: &modes)
        }

        return modes
    }

    private static func append(_ mode: InsertionMode, to modes: inout [InsertionMode]) {
        guard mode != .disabled,
              mode != .clipboardFallbackOptIn,
              !modes.contains(mode) else {
            return
        }

        modes.append(mode)
    }
}
