import Foundation

/// Reason a text-insertion write was refused because the live focused target no longer
/// matches the field the accepted suggestion was validated against.
public enum InsertionTargetMismatchReason: String, Equatable, Sendable {
    /// The live focused target could not be resolved at write time.
    case missingCurrentTarget = "insertion-target-missing-current"
    /// The frontmost application (bundle id or pid) changed since acceptance was validated.
    case appChanged = "insertion-target-app-changed"
    /// Focus moved to a different element within the same application.
    case fieldChanged = "insertion-target-field-changed"
}

public enum InsertionTargetIdentityDecision: Equatable, Sendable {
    case allow
    case block(InsertionTargetMismatchReason)

    public var isAllowed: Bool {
        if case .allow = self {
            return true
        }
        return false
    }

    public var blockReason: InsertionTargetMismatchReason? {
        if case let .block(reason) = self {
            return reason
        }
        return nil
    }
}

/// Pure guard that binds a text-insertion write to the field identity that the acceptance
/// pipeline already validated.
///
/// The accept-time guards (`SuggestionAcceptanceGuard`) compare the shown and current field
/// at *decision* time, but the actual Accessibility write happens a few hops later and
/// independently re-resolves "the frontmost application / focused element". If focus is stolen
/// in that window (a notification, an app self-activating, a malicious app calling
/// `AXUIElementSetAttributeValue`-triggering activation), the accepted text — which is the
/// user's own private continuation — can land in a different app or field than the one the
/// user saw the suggestion in. This guard closes that time-of-check/time-of-use gap by
/// refusing the write when the live target drifted from the validated one.
public struct InsertionTargetIdentityGuard: Equatable, Sendable {
    public init() {}

    /// - Parameters:
    ///   - expected: the field identity validated by the acceptance pipeline (what the user saw).
    ///   - current: the field identity resolved immediately before the write. `nil` when the
    ///     focused element could not be read; treated as a refusal (fail closed).
    ///   - requireElementMatch: when `false` (e.g. the descendant-text fallback, where the
    ///     written element legitimately differs from the element used to read context) only the
    ///     application identity (bundle id + pid) is enforced. Cross-application drift is always
    ///     refused regardless of this flag.
    public func decision(
        expected: FocusedFieldIdentity,
        current: FocusedFieldIdentity?,
        requireElementMatch: Bool = true
    ) -> InsertionTargetIdentityDecision {
        guard let current else {
            return .block(.missingCurrentTarget)
        }

        guard expected.bundleIdentifier == current.bundleIdentifier,
              expected.processIdentifier == current.processIdentifier else {
            return .block(.appChanged)
        }

        if requireElementMatch,
           expected.elementIdentifier != current.elementIdentifier {
            return .block(.fieldChanged)
        }

        return .allow
    }
}
