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
    public let previousTextBeforeCursorUTF16Length: Int?
    public let acceptedTextUTF16Length: Int?
    public let currentTextBeforeCursorUTF16Length: Int?

    public init(
        profile: CompatibilityProfile,
        frontmostBundleIdentifier: String,
        frontmostProcessIdentifier: Int32,
        expectedFieldIdentity: FocusedFieldIdentity,
        contextRole: String?,
        verificationResult: InsertionVerificationResult,
        mismatch: InsertionVerificationContextMismatch,
        previousTextBeforeCursorUTF16Length: Int? = nil,
        acceptedTextUTF16Length: Int? = nil,
        currentTextBeforeCursorUTF16Length: Int? = nil
    ) {
        self.profile = profile
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
        self.frontmostProcessIdentifier = frontmostProcessIdentifier
        self.expectedFieldIdentity = expectedFieldIdentity
        self.contextRole = contextRole
        self.verificationResult = verificationResult
        self.mismatch = mismatch
        self.previousTextBeforeCursorUTF16Length = previousTextBeforeCursorUTF16Length
        self.acceptedTextUTF16Length = acceptedTextUTF16Length
        self.currentTextBeforeCursorUTF16Length = currentTextBeforeCursorUTF16Length
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
        case "axtextarea":
            guard !isOneCharacterChromiumTextAreaProof(input) else {
                return false
            }
            return true

        case "axtextfield":
            return true
        default:
            return false
        }
    }

    private func isOneCharacterChromiumTextAreaProof(_ input: InsertionVerificationContextRecoveryInput) -> Bool {
        guard input.currentTextBeforeCursorUTF16Length == 1,
              let previousLength = input.previousTextBeforeCursorUTF16Length,
              let acceptedLength = input.acceptedTextUTF16Length else {
            return false
        }

        return previousLength + acceptedLength == 1
    }

    private func normalizedRole(_ role: String?) -> String? {
        let normalized = role?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized?.isEmpty == false ? normalized : nil
    }
}
