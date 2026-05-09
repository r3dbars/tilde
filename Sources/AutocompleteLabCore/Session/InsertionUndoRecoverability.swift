import Foundation

public enum InsertionUndoRecoverabilityLevel: String, Equatable, Sendable {
    case nativeSingleEdit
    case appRollback
    case degraded
    case unavailable

    public var displayName: String {
        switch self {
        case .nativeSingleEdit:
            "native single edit"
        case .appRollback:
            "app rollback"
        case .degraded:
            "degraded"
        case .unavailable:
            "unavailable"
        }
    }
}

public enum InsertionUndoRecoverabilityStatus: String, Equatable, Sendable {
    case proven
    case degraded
    case missing
    case unsupported
}

public struct InsertionUndoRecoverabilityProof: Equatable, Sendable {
    public let appBundleIdentifier: String
    public let acceptMode: String
    public let insertionVerified: Bool
    public let undoMechanism: InsertionUndoRecoverabilityLevel?
    public let sameSliceUndoProof: Bool
    public let restoredOriginalTarget: Bool

    public init(
        appBundleIdentifier: String,
        acceptMode: String,
        insertionVerified: Bool,
        undoMechanism: InsertionUndoRecoverabilityLevel?,
        sameSliceUndoProof: Bool,
        restoredOriginalTarget: Bool
    ) {
        self.appBundleIdentifier = appBundleIdentifier
        self.acceptMode = acceptMode
        self.insertionVerified = insertionVerified
        self.undoMechanism = undoMechanism
        self.sameSliceUndoProof = sameSliceUndoProof
        self.restoredOriginalTarget = restoredOriginalTarget
    }
}

public struct InsertionUndoRecoverabilityDecision: Equatable, Sendable {
    public let status: InsertionUndoRecoverabilityStatus
    public let guarantee: InsertionUndoRecoverabilityLevel
    public let reason: String

    public init(
        status: InsertionUndoRecoverabilityStatus,
        guarantee: InsertionUndoRecoverabilityLevel,
        reason: String
    ) {
        self.status = status
        self.guarantee = guarantee
        self.reason = reason
    }
}

public struct InsertionUndoRecoverabilityModel: Equatable, Sendable {
    public init() {}

    public func expectedGuarantee(
        for profile: CompatibilityProfile,
        acceptMode: String
    ) -> InsertionUndoRecoverabilityLevel {
        guard profile.canPresentSuggestions else {
            return .unavailable
        }

        if isFullAccept(acceptMode), !profile.supportsFullAcceptance {
            return .unavailable
        }

        switch profile.bundleIdentifier {
        case "com.apple.TextEdit", "com.google.Chrome":
            return .nativeSingleEdit
        case "com.apple.Notes", "md.obsidian":
            return .degraded
        default:
            return profile.supportsOneWordAcceptance ? .degraded : .unavailable
        }
    }

    public func evaluate(
        profile: CompatibilityProfile,
        proof: InsertionUndoRecoverabilityProof
    ) -> InsertionUndoRecoverabilityDecision {
        let expected = expectedGuarantee(for: profile, acceptMode: proof.acceptMode)
        guard expected != .unavailable else {
            return InsertionUndoRecoverabilityDecision(
                status: .unsupported,
                guarantee: .unavailable,
                reason: "This accept mode is not supported for this surface."
            )
        }

        guard proof.insertionVerified else {
            return InsertionUndoRecoverabilityDecision(
                status: .missing,
                guarantee: expected,
                reason: "Undo proof cannot count until insertion verification passes."
            )
        }

        guard proof.sameSliceUndoProof, proof.restoredOriginalTarget else {
            return InsertionUndoRecoverabilityDecision(
                status: .missing,
                guarantee: expected,
                reason: "Needs same-slice undo proof that restores the original target."
            )
        }

        switch proof.undoMechanism {
        case .nativeSingleEdit:
            return InsertionUndoRecoverabilityDecision(
                status: .proven,
                guarantee: .nativeSingleEdit,
                reason: "Native undo restored the accepted insertion as one edit."
            )
        case .appRollback:
            return InsertionUndoRecoverabilityDecision(
                status: expected == .nativeSingleEdit ? .degraded : .proven,
                guarantee: .appRollback,
                reason: expected == .nativeSingleEdit
                    ? "Recovered through app rollback; native single-edit undo is not proven."
                    : "Recovered through the app rollback path."
            )
        case .degraded:
            return InsertionUndoRecoverabilityDecision(
                status: .degraded,
                guarantee: .degraded,
                reason: "Undo is explicitly degraded for this surface."
            )
        case .unavailable, nil:
            return InsertionUndoRecoverabilityDecision(
                status: .missing,
                guarantee: expected,
                reason: "No undo mechanism proof was recorded."
            )
        }
    }

    public func failureMetadata(
        profile: CompatibilityProfile,
        acceptMode: String,
        rollbackAvailable: Bool,
        rollbackMechanism: InsertionUndoRecoverabilityLevel?
    ) -> [String: String] {
        let expected = expectedGuarantee(for: profile, acceptMode: acceptMode)
        return [
            "undoExpectedGuarantee": expected.rawValue,
            "rollbackAvailable": String(rollbackAvailable),
            "rollbackMechanism": rollbackMechanism?.rawValue ?? "none",
            "failureRecoverability": rollbackAvailable ? "recoverable" : "degraded"
        ]
    }

    private func isFullAccept(_ acceptMode: String) -> Bool {
        acceptMode == "acceptAllVisible" || acceptMode == "full"
    }
}
