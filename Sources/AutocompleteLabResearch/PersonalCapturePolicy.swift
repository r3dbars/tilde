import Foundation

import AutocompleteLabCore

public enum PersonalCaptureBlockReason: Equatable, Sendable {
    case secureContext
    case sensitiveField(SensitiveFieldProofCategory)
    case browserHostedSurface(BrowserHostedSurface)
    case suppressedFieldKind(AXFieldKind)

    public var rawValue: String {
        switch self {
        case .secureContext:
            return "secure-context"
        case let .sensitiveField(category):
            return "sensitive-field:\(category.rawValue)"
        case let .browserHostedSurface(surface):
            return "browser-hosted-surface:\(surface.rawValue)"
        case let .suppressedFieldKind(kind):
            return "suppressed-field-kind:\(kind.rawValue)"
        }
    }
}

public struct PersonalCaptureInput: Equatable, Sendable {
    public let bundleIdentifier: String
    public let role: String?
    public let subrole: String?
    public let fingerprint: FocusedElementFingerprint
    public let isSecure: Bool
    public let fieldClassification: AXFieldClassification

    public init(
        bundleIdentifier: String,
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint,
        isSecure: Bool,
        fieldClassification: AXFieldClassification
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.role = role
        self.subrole = subrole
        self.fingerprint = fingerprint
        self.isSecure = isSecure
        self.fieldClassification = fieldClassification
    }
}

public struct PersonalCaptureDecision: Equatable, Sendable {
    public let canCapture: Bool
    public let blockReason: PersonalCaptureBlockReason?
    public let metadata: [String: String]

    public init(
        canCapture: Bool,
        blockReason: PersonalCaptureBlockReason? = nil,
        metadata: [String: String] = [:]
    ) {
        self.canCapture = canCapture
        self.blockReason = blockReason
        self.metadata = metadata
    }

    public static func allowed(metadata: [String: String]) -> PersonalCaptureDecision {
        PersonalCaptureDecision(canCapture: true, metadata: metadata)
    }

    public static func blocked(
        _ reason: PersonalCaptureBlockReason,
        metadata: [String: String]
    ) -> PersonalCaptureDecision {
        PersonalCaptureDecision(canCapture: false, blockReason: reason, metadata: metadata)
    }
}

public struct PersonalCapturePolicy: Equatable, Sendable {
    private let sensitiveTextFieldPolicy = SensitiveTextFieldPolicy()
    private let browserHostedSurfacePolicy = BrowserHostedSurfacePolicy()

    public init() {}

    public func decision(for input: PersonalCaptureInput) -> PersonalCaptureDecision {
        var metadata = input.fieldClassification.traceMetadata
        metadata["personalCapturePolicy"] = "v1"

        if input.isSecure {
            metadata["personalCaptureDecision"] = "blocked"
            metadata["personalCaptureBlockReason"] = PersonalCaptureBlockReason.secureContext.rawValue
            return .blocked(.secureContext, metadata: metadata)
        }

        let sensitiveAssessment = sensitiveTextFieldPolicy.assessment(
            role: input.role,
            subrole: input.subrole,
            fingerprint: input.fingerprint
        )
        metadata.merge(sensitiveAssessment.traceMetadata) { current, _ in current }
        if sensitiveAssessment.isSensitive {
            let category = sensitiveAssessment.category ?? .password
            let reason = PersonalCaptureBlockReason.sensitiveField(category)
            metadata["personalCaptureDecision"] = "blocked"
            metadata["personalCaptureBlockReason"] = reason.rawValue
            return .blocked(reason, metadata: metadata)
        }

        switch browserHostedSurfacePolicy.decision(
            bundleIdentifier: input.bundleIdentifier,
            fingerprint: input.fingerprint
        ) {
        case .allowed:
            break
        case let .blocked(block):
            let reason = PersonalCaptureBlockReason.browserHostedSurface(block.surface)
            metadata.merge(block.traceMetadata) { current, _ in current }
            metadata["personalCaptureDecision"] = "blocked"
            metadata["personalCaptureBlockReason"] = reason.rawValue
            return .blocked(reason, metadata: metadata)
        }

        if input.fieldClassification.suppressesSuggestionsByDefault {
            let reason = PersonalCaptureBlockReason.suppressedFieldKind(input.fieldClassification.kind)
            metadata["personalCaptureDecision"] = "blocked"
            metadata["personalCaptureBlockReason"] = reason.rawValue
            return .blocked(reason, metadata: metadata)
        }

        metadata["personalCaptureDecision"] = "allowed"
        return .allowed(metadata: metadata)
    }
}
