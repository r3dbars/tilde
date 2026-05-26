import Foundation

public struct ObsidianTrustedEndOfDocumentSnapshotPolicy: Sendable {
    public init() {}

    public func repairPreviousSnapshot(
        fieldIdentity: FocusedFieldIdentity,
        previousSnapshot: FocusedTextSnapshot?,
        trustedSnapshot: FocusedTextSnapshot?
    ) -> FocusedTextSnapshot? {
        guard fieldIdentity.bundleIdentifier == "md.obsidian" else {
            return previousSnapshot
        }

        if let previousSnapshot,
           previousSnapshot.fieldIdentity == fieldIdentity,
           previousSnapshot.textAfterCursor.isEmpty {
            return previousSnapshot
        }

        guard let trustedSnapshot,
              trustedSnapshot.fieldIdentity == fieldIdentity,
              shouldRemember(snapshot: trustedSnapshot) else {
            return previousSnapshot
        }

        return trustedSnapshot
    }

    public func shouldRemember(snapshot: FocusedTextSnapshot) -> Bool {
        snapshot.fieldIdentity.bundleIdentifier == "md.obsidian"
            && snapshot.textAfterCursor.isEmpty
            && snapshot.textBeforeCursor.count >= 300
            && snapshot.textBeforeCursor.last?.isNewline != true
    }
}
