import Foundation

public enum InsertionVerificationContextMismatch: String, Equatable, Sendable {
    case fieldIdentity = "field-identity"
    case targetFingerprint = "target-fingerprint"
}

public struct InsertionVerificationContextRecoveryInput: Equatable, Sendable {
    public let profile: CompatibilityProfile
    public let frontmostBundleIdentifier: String
    public let frontmostProcessIdentifier: Int32
    public let expectedFieldIdentity: FocusedFieldIdentity
    public let contextRole: String?
    public let verificationResult: InsertionVerificationResult
    public let mismatch: InsertionVerificationContextMismatch

    public init(
        profile: CompatibilityProfile,
        frontmostBundleIdentifier: String,
        frontmostProcessIdentifier: Int32,
        expectedFieldIdentity: FocusedFieldIdentity,
        contextRole: String?,
        verificationResult: InsertionVerificationResult,
        mismatch: InsertionVerificationContextMismatch
    ) {
        self.profile = profile
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
        self.frontmostProcessIdentifier = frontmostProcessIdentifier
        self.expectedFieldIdentity = expectedFieldIdentity
        self.contextRole = contextRole
        self.verificationResult = verificationResult
        self.mismatch = mismatch
    }
}

public struct InsertionVerificationContextRecoveryPolicy: Equatable, Sendable {
    public init() {}

    public func canRecover(_ input: InsertionVerificationContextRecoveryInput) -> Bool {
        guard input.frontmostBundleIdentifier == input.profile.bundleIdentifier,
              input.frontmostProcessIdentifier == input.expectedFieldIdentity.processIdentifier,
              input.verificationResult.isVerified else {
            return false
        }

        if input.profile.bundleIdentifier == "md.obsidian" {
            return canRecoverObsidianCodeMirrorSwap(input)
        }

        if input.profile.appFamily == .chromium {
            return canRecoverChromiumTargetFingerprintChurn(input)
        }

        return false
    }

    private func canRecoverObsidianCodeMirrorSwap(_ input: InsertionVerificationContextRecoveryInput) -> Bool {
        switch normalizedRole(input.contextRole) {
        case "axtextarea", "axwebarea":
            return true
        default:
            return false
        }
    }

    private func canRecoverChromiumTargetFingerprintChurn(_ input: InsertionVerificationContextRecoveryInput) -> Bool {
        guard input.mismatch == .targetFingerprint else {
            return false
        }

        switch normalizedRole(input.contextRole) {
        case "axtextarea", "axtextfield":
            return true
        default:
            return false
        }
    }

    private func normalizedRole(_ role: String?) -> String? {
        let normalized = role?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized?.isEmpty == false ? normalized : nil
    }
}
