public enum InsertionVerificationPreflightFailureReason: String, Equatable, Sendable {
    case missingFrontmostApplication = "verification-missing-frontmost-app"
    case frontmostApplicationChanged = "verification-frontmost-app-changed"
    case missingFocusedTextContext = "verification-missing-focused-context"
    case focusedFieldChanged = "verification-focused-field-changed"
}

public enum InsertionVerificationPreflightContext: Equatable, Sendable {
    case missingFrontmostApplication
    case frontmostApplication(bundleIdentifier: String, fieldIdentity: FocusedFieldIdentity?)
}

public enum InsertionVerificationPreflightDecision: Equatable, Sendable {
    case proceed
    case fail(InsertionVerificationPreflightFailureReason)

    public var failureReason: InsertionVerificationPreflightFailureReason? {
        if case let .fail(reason) = self {
            return reason
        }
        return nil
    }
}

public struct InsertionVerificationPreflightPolicy: Equatable, Sendable {
    public init() {}

    public func decision(
        expectedFieldIdentity: FocusedFieldIdentity,
        currentContext: InsertionVerificationPreflightContext
    ) -> InsertionVerificationPreflightDecision {
        switch currentContext {
        case .missingFrontmostApplication:
            return .fail(.missingFrontmostApplication)
        case let .frontmostApplication(bundleIdentifier, fieldIdentity):
            guard bundleIdentifier == expectedFieldIdentity.bundleIdentifier else {
                return .fail(.frontmostApplicationChanged)
            }

            guard let fieldIdentity else {
                return .fail(.missingFocusedTextContext)
            }

            guard fieldIdentity == expectedFieldIdentity else {
                return .fail(.focusedFieldChanged)
            }

            return .proceed
        }
    }
}
