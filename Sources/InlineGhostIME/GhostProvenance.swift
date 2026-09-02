import TildeCore

/// What the outcome ledger is told about a ghost's origin: the register the
/// generator actually composed with and which expert produced the text.
/// Both come from the app's response receipt for model ghosts and are fixed
/// for the dictionary path; the keyboard never re-derives a register from
/// the host bundle for a ghost the app served.
struct GhostProvenance: Equatable, Sendable {
    let register: ContinuationRegister
    let source: TextFreeCandidateSource

    init(register: ContinuationRegister, source: TextFreeCandidateSource) {
        self.register = register
        self.source = source
    }

    /// An app older than the receipt sends neither field: the register
    /// falls back to the host's own and the source is labelled legacy,
    /// never guessed as the base model.
    init(receipt: GhostBrainResponse, hostBundleIdentifier: String) {
        register = receipt.register.flatMap(ContinuationRegister.init(rawValue:))
            ?? ContinuationRegister.from(bundleIdentifier: hostBundleIdentifier)
        source = receipt.source.flatMap(TextFreeCandidateSource.init(rawValue:))
            ?? .unknownLegacy
    }
}
