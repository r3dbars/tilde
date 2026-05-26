public struct ObsidianFullAcceptCaretRepairPolicy: Equatable, Sendable {
    public init() {}

    public func shouldRepair(
        bundleIdentifier: String,
        action: KeyboardAction?,
        snapshot: FocusedTextSnapshot?,
        currentFieldIdentity: FocusedFieldIdentity?
    ) -> Bool {
        guard bundleIdentifier == "md.obsidian",
              action == .acceptAllVisible,
              let snapshot,
              !snapshot.textBeforeCursor.isEmpty,
              snapshot.textAfterCursor.isEmpty,
              snapshot.fieldIdentity == currentFieldIdentity else {
            return false
        }

        return true
    }
}
