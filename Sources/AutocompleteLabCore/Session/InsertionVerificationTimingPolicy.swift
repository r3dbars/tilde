import Foundation

public struct InsertionVerificationTimingPolicy: Equatable, Sendable {
    public let defaultDelayMilliseconds: Int
    public let notesDelayMilliseconds: Int
    public let notesReadOnlyRecheckDelayMilliseconds: Int
    public let claudeCodeDelayMilliseconds: Int

    public init(
        defaultDelayMilliseconds: Int = 140,
        notesDelayMilliseconds: Int = 320,
        notesReadOnlyRecheckDelayMilliseconds: Int = 280,
        claudeCodeDelayMilliseconds: Int = 640
    ) {
        self.defaultDelayMilliseconds = max(0, defaultDelayMilliseconds)
        self.notesDelayMilliseconds = max(self.defaultDelayMilliseconds, notesDelayMilliseconds)
        self.notesReadOnlyRecheckDelayMilliseconds = max(0, notesReadOnlyRecheckDelayMilliseconds)
        self.claudeCodeDelayMilliseconds = max(self.defaultDelayMilliseconds, claudeCodeDelayMilliseconds)
    }

    public func delayMilliseconds(
        for profile: CompatibilityProfile,
        retryCount: Int
    ) -> Int {
        if profile.bundleIdentifier == "com.apple.Notes" {
            return notesDelayMilliseconds
        }

        if profile.bundleIdentifier == "com.anthropic.claude-code" {
            return claudeCodeDelayMilliseconds
        }

        return defaultDelayMilliseconds
    }

    public func readOnlyRecheckDelayMilliseconds(
        for profile: CompatibilityProfile,
        result: InsertionVerificationResult,
        retryCount: Int
    ) -> Int? {
        guard profile.bundleIdentifier == "com.apple.Notes",
              result == .unchanged else {
            return nil
        }

        return notesReadOnlyRecheckDelayMilliseconds
    }
}
