import CoreGraphics
import Foundation

public struct CompatibilityLearningVisualScope: Codable, Equatable, Sendable {
    public let appVersion: String
    public let screen: String
    public let fieldShape: String

    public init(
        appVersion: String,
        screen: String,
        fieldShape: String
    ) {
        self.appVersion = appVersion
        self.screen = screen
        self.fieldShape = fieldShape
    }

    public var debugSummary: String {
        "app=\(appVersion); screen=\(screen); field=\(fieldShape)"
    }
}

public enum CompatibilityLearningVisualOffsetTrustStatus: String, Codable, Equatable, Sendable {
    case applied
    case refused
    case none
}

public enum CompatibilityLearningVisualOffsetTrustReason: String, Codable, Equatable, Sendable {
    case noVisualOffset = "no-visual-offset"
    case unsupportedReason = "unsupported-reason"
    case missingVisualScope = "missing-visual-scope"
    case missingCurrentContext = "missing-current-context"
    case appVersionChanged = "app-version-changed"
    case screenChanged = "screen-changed"
    case fieldShapeChanged = "field-shape-changed"
    case insufficientEvidence = "insufficient-evidence"
    case legacyHighConfidence = "legacy-high-confidence"
    case scopeMatched = "scope-matched"
}

public struct CompatibilityLearningVisualOffsetTrustDecision: Codable, Equatable, Sendable {
    public let status: CompatibilityLearningVisualOffsetTrustStatus
    public let reason: CompatibilityLearningVisualOffsetTrustReason

    public init(
        status: CompatibilityLearningVisualOffsetTrustStatus,
        reason: CompatibilityLearningVisualOffsetTrustReason
    ) {
        self.status = status
        self.reason = reason
    }

    public var isApplied: Bool {
        status == .applied
    }

    public static let none = CompatibilityLearningVisualOffsetTrustDecision(
        status: .none,
        reason: .noVisualOffset
    )
}

public struct CompatibilityLearningProfile: Codable, Equatable, Sendable {
    public let bundleIdentifier: String
    public var xOffset: CGFloat
    public var yOffset: CGFloat
    public var visualAppVersion: String?
    public var visualScreenFingerprint: String?
    public var visualFieldShapeFingerprint: String?
    public var renderModeOverride: SuggestionRenderMode?
    public var visualScope: CompatibilityLearningVisualScope?
    public var screenshotTracingEnabled: Bool
    public var screenshotTracingExpiresAt: String?
    public var observations: Int
    public var confidence: Double
    public var lastReason: String
    public var updatedAt: String

    public init(
        bundleIdentifier: String,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0,
        visualAppVersion: String? = nil,
        visualScreenFingerprint: String? = nil,
        visualFieldShapeFingerprint: String? = nil,
        renderModeOverride: SuggestionRenderMode? = nil,
        visualScope: CompatibilityLearningVisualScope? = nil,
        screenshotTracingEnabled: Bool = false,
        screenshotTracingExpiresAt: String? = nil,
        observations: Int = 0,
        confidence: Double = 0,
        lastReason: String = "",
        updatedAt: String = ""
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.visualAppVersion = visualAppVersion
        self.visualScreenFingerprint = visualScreenFingerprint
        self.visualFieldShapeFingerprint = visualFieldShapeFingerprint
        self.renderModeOverride = renderModeOverride
        self.visualScope = visualScope
        self.screenshotTracingEnabled = screenshotTracingEnabled
        self.screenshotTracingExpiresAt = screenshotTracingExpiresAt
        self.observations = observations
        self.confidence = confidence
        self.lastReason = lastReason
        self.updatedAt = updatedAt
    }

    public var hasVisualAdjustment: Bool {
        abs(xOffset) > 0.01 || abs(yOffset) > 0.01
    }

    public var hasTrustedVisualAdjustment: Bool {
        visualOffsetTrustDecision(
            matching: nil,
            allowUnscopedTrustedOffset: true
        ).isApplied
    }

    public func hasTrustedVisualAdjustment(
        in context: CompatibilityLearningVisualTrustContext?
    ) -> Bool {
        visualOffsetTrustDecision(in: context).isApplied
    }

    public func hasTrustedVisualAdjustment(matching visualScope: CompatibilityLearningVisualScope?) -> Bool {
        visualOffsetTrustDecision(
            matching: visualScope,
            allowUnscopedTrustedOffset: false
        ).isApplied
    }

    public func visualOffsetTrustDecision(
        in context: CompatibilityLearningVisualTrustContext?,
        allowMissingCurrentContext: Bool = false
    ) -> CompatibilityLearningVisualOffsetTrustDecision {
        let base = baseVisualOffsetTrustDecision()
        guard base.status != .none else {
            return base
        }

        guard base.status != .refused else {
            return base
        }

        if let storedScope = visualScope {
            guard let context else {
                return allowMissingCurrentContext
                    ? base
                    : refused(.missingCurrentContext)
            }

            return trustDecision(
                storedAppVersion: storedScope.appVersion,
                storedScreen: storedScope.screen,
                storedFieldShape: storedScope.fieldShape,
                context: context
            )
        }

        if hasContextScopedVisualTrust {
            guard let context else {
                return allowMissingCurrentContext
                    ? base
                    : refused(.missingCurrentContext)
            }

            return trustDecision(
                storedAppVersion: visualAppVersion,
                storedScreen: visualScreenFingerprint,
                storedFieldShape: visualFieldShapeFingerprint,
                context: context
            )
        }

        return base
    }

    public func visualOffsetTrustDecision(
        matching visualScope: CompatibilityLearningVisualScope?,
        allowUnscopedTrustedOffset: Bool
    ) -> CompatibilityLearningVisualOffsetTrustDecision {
        let base = baseVisualOffsetTrustDecision()
        guard base.status != .none else {
            return base
        }

        guard base.status != .refused else {
            return base
        }

        guard let storedScope = self.visualScope else {
            return allowUnscopedTrustedOffset
                ? base
                : refused(.missingVisualScope)
        }

        guard let visualScope else {
            return allowUnscopedTrustedOffset
                ? applied(.scopeMatched)
                : refused(.missingCurrentContext)
        }

        if storedScope.appVersion != visualScope.appVersion {
            return refused(.appVersionChanged)
        }

        if storedScope.screen != visualScope.screen {
            return refused(.screenChanged)
        }

        if storedScope.fieldShape != visualScope.fieldShape {
            return refused(.fieldShapeChanged)
        }

        return applied(.scopeMatched)
    }

    public var debugSummary: String {
        let render = renderModeOverride?.rawValue ?? "profile"
        let scope = visualScope?.debugSummary ?? "none"
        return "offset=(\(Self.format(xOffset)), \(Self.format(yOffset))), render=\(render), scope=\(scope), screenshots=\(screenshotTracingEnabled), observations=\(observations), confidence=\(Self.format(confidence))"
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private var hasContextScopedVisualTrust: Bool {
        [visualAppVersion, visualScreenFingerprint, visualFieldShapeFingerprint]
            .contains { ($0?.isEmpty == false) }
    }

    private func baseVisualOffsetTrustDecision() -> CompatibilityLearningVisualOffsetTrustDecision {
        guard hasVisualAdjustment else {
            return .none
        }

        guard lastReason == "manual-visual-nudge"
                || lastReason == "screenshot-visual-correction" else {
            return refused(.unsupportedReason)
        }

        if visualScope != nil || hasContextScopedVisualTrust {
            return applied(.scopeMatched)
        }

        guard lastReason == "screenshot-visual-correction",
              confidence >= 0.85 else {
            return refused(.insufficientEvidence)
        }

        return applied(.legacyHighConfidence)
    }

    private func trustDecision(
        storedAppVersion: String?,
        storedScreen: String?,
        storedFieldShape: String?,
        context: CompatibilityLearningVisualTrustContext
    ) -> CompatibilityLearningVisualOffsetTrustDecision {
        if let decision = compare(
            storedAppVersion,
            context.appVersion,
            mismatchReason: .appVersionChanged
        ) {
            return decision
        }

        if let decision = compare(
            storedScreen,
            context.screenFingerprint,
            mismatchReason: .screenChanged
        ) {
            return decision
        }

        if let decision = compare(
            storedFieldShape,
            context.fieldShapeFingerprint,
            mismatchReason: .fieldShapeChanged
        ) {
            return decision
        }

        return applied(.scopeMatched)
    }

    private func compare(
        _ stored: String?,
        _ current: String?,
        mismatchReason: CompatibilityLearningVisualOffsetTrustReason
    ) -> CompatibilityLearningVisualOffsetTrustDecision? {
        guard let stored, !stored.isEmpty else {
            return nil
        }

        guard let current, !current.isEmpty else {
            return refused(.missingCurrentContext)
        }

        guard stored == current else {
            return refused(mismatchReason)
        }

        return nil
    }

    private func applied(
        _ reason: CompatibilityLearningVisualOffsetTrustReason
    ) -> CompatibilityLearningVisualOffsetTrustDecision {
        CompatibilityLearningVisualOffsetTrustDecision(status: .applied, reason: reason)
    }

    private func refused(
        _ reason: CompatibilityLearningVisualOffsetTrustReason
    ) -> CompatibilityLearningVisualOffsetTrustDecision {
        CompatibilityLearningVisualOffsetTrustDecision(status: .refused, reason: reason)
    }
}

public struct CompatibilityLearningVisualTrustContext: Codable, Equatable, Sendable {
    public let appVersion: String?
    public let screenFingerprint: String?
    public let fieldShapeFingerprint: String?

    public init(
        appVersion: String? = nil,
        screenFingerprint: String? = nil,
        fieldShapeFingerprint: String? = nil
    ) {
        self.appVersion = appVersion
        self.screenFingerprint = screenFingerprint
        self.fieldShapeFingerprint = fieldShapeFingerprint
    }
}

public struct CompatibilityLearningAdjustment: Equatable, Sendable {
    public let profile: CompatibilityLearningProfile?
    public let effectiveRenderMode: SuggestionRenderMode
    public let renderModeOverrideIgnored: Bool
    public let visualOffsetTrustedOverride: Bool?
    public let visualOffsetTrustDecisionOverride: CompatibilityLearningVisualOffsetTrustDecision?

    public init(
        profile: CompatibilityLearningProfile?,
        effectiveRenderMode: SuggestionRenderMode,
        renderModeOverrideIgnored: Bool = false,
        visualOffsetTrustedOverride: Bool? = nil,
        visualOffsetTrustDecisionOverride: CompatibilityLearningVisualOffsetTrustDecision? = nil
    ) {
        self.profile = profile
        self.effectiveRenderMode = effectiveRenderMode
        self.renderModeOverrideIgnored = renderModeOverrideIgnored
        self.visualOffsetTrustedOverride = visualOffsetTrustedOverride
        self.visualOffsetTrustDecisionOverride = visualOffsetTrustDecisionOverride
    }

    public var shouldCaptureScreenshot: Bool {
        profile?.screenshotTracingEnabled == true
    }

    public var withoutVisualOffset: CompatibilityLearningAdjustment {
        guard var profile else {
            return self
        }

        profile.xOffset = 0
        profile.yOffset = 0

        return CompatibilityLearningAdjustment(
            profile: profile,
            effectiveRenderMode: effectiveRenderMode,
            renderModeOverrideIgnored: renderModeOverrideIgnored,
            visualOffsetTrustedOverride: false,
            visualOffsetTrustDecisionOverride: CompatibilityLearningVisualOffsetTrustDecision(
                status: .refused,
                reason: .noVisualOffset
            )
        )
    }

    public var trustedVisualOffsetOnly: CompatibilityLearningAdjustment {
        trustedVisualOffsetOnly(matching: nil, allowUnscopedTrustedOffset: true)
    }

    public func trustedVisualOffsetOnly(
        matching visualScope: CompatibilityLearningVisualScope?
    ) -> CompatibilityLearningAdjustment {
        trustedVisualOffsetOnly(matching: visualScope, allowUnscopedTrustedOffset: false)
    }

    public func trustedVisualOffsetOnly(
        context: CompatibilityLearningVisualTrustContext?
    ) -> CompatibilityLearningAdjustment {
        guard let profile else {
            return self
        }

        let decision = profile.visualOffsetTrustDecision(in: context)
        guard decision.isApplied else {
            return withoutVisualOffset(trustDecision: decision)
        }

        return CompatibilityLearningAdjustment(
            profile: profile,
            effectiveRenderMode: effectiveRenderMode,
            renderModeOverrideIgnored: renderModeOverrideIgnored,
            visualOffsetTrustedOverride: true,
            visualOffsetTrustDecisionOverride: decision
        )
    }

    private func trustedVisualOffsetOnly(
        matching visualScope: CompatibilityLearningVisualScope?,
        allowUnscopedTrustedOffset: Bool
    ) -> CompatibilityLearningAdjustment {
        guard let profile else {
            return self
        }

        let decision = profile.visualOffsetTrustDecision(
            matching: visualScope,
            allowUnscopedTrustedOffset: allowUnscopedTrustedOffset
        )
        guard decision.isApplied else {
            return withoutVisualOffset(trustDecision: decision)
        }

        return CompatibilityLearningAdjustment(
            profile: profile,
            effectiveRenderMode: effectiveRenderMode,
            renderModeOverrideIgnored: renderModeOverrideIgnored,
            visualOffsetTrustedOverride: true,
            visualOffsetTrustDecisionOverride: decision
        )
    }

    private func withoutVisualOffset(
        trustDecision: CompatibilityLearningVisualOffsetTrustDecision
    ) -> CompatibilityLearningAdjustment {
        guard var profile else {
            return self
        }

        profile.xOffset = 0
        profile.yOffset = 0

        return CompatibilityLearningAdjustment(
            profile: profile,
            effectiveRenderMode: effectiveRenderMode,
            renderModeOverrideIgnored: renderModeOverrideIgnored,
            visualOffsetTrustedOverride: false,
            visualOffsetTrustDecisionOverride: trustDecision
        )
    }

    public var metadata: [String: String] {
        guard let profile else {
            return [
                "learningApplied": "false",
                "learningRenderMode": effectiveRenderMode.rawValue,
                "learningRenderModeOverrideIgnored": "false",
                "learningVisualOffsetTrusted": "false",
                "learningVisualOffsetStatus": CompatibilityLearningVisualOffsetTrustStatus.none.rawValue,
                "learningVisualOffsetReason": CompatibilityLearningVisualOffsetTrustReason.noVisualOffset.rawValue
            ]
        }

        let renderModeOverrideApplied = profile.renderModeOverride != nil && !renderModeOverrideIgnored
        let trustDecision = visualOffsetTrustDecisionOverride
            ?? profile.visualOffsetTrustDecision(
                matching: nil,
                allowUnscopedTrustedOffset: true
            )
        let visualOffsetTrusted = trustDecision.isApplied
        return [
            "learningApplied": String(profile.hasVisualAdjustment || renderModeOverrideApplied),
            "learningRenderMode": effectiveRenderMode.rawValue,
            "learningRenderModeOverrideIgnored": String(renderModeOverrideIgnored),
            "learningXOffset": String(format: "%.1f", Double(profile.xOffset)),
            "learningYOffset": String(format: "%.1f", Double(profile.yOffset)),
            "learningVisualOffsetTrusted": String(visualOffsetTrusted),
            "learningVisualOffsetStatus": trustDecision.status.rawValue,
            "learningVisualOffsetReason": trustDecision.reason.rawValue,
            "learningVisualScope": profile.visualScope?.debugSummary ?? "none",
            "learningConfidence": String(format: "%.2f", profile.confidence),
            "learningObservations": String(profile.observations),
            "learningScreenshotTracing": String(profile.screenshotTracingEnabled)
        ]
    }

    public func adjusted(_ rect: CGRect?) -> CGRect? {
        guard let rect,
              let profile,
              profile.hasVisualAdjustment else {
            return rect
        }

        return rect.offsetBy(dx: profile.xOffset, dy: profile.yOffset)
    }
}

public extension PlacementTrustPolicy {
    static func compatibility(
        profile: CompatibilityProfile,
        learningAdjustment: CompatibilityLearningAdjustment
    ) -> PlacementTrustPolicy {
        let hasTrustedVisualAdjustment = learningAdjustment.profile?.hasTrustedVisualAdjustment == true
        let isGreenProfile = profile.supportLevel == .green

        return PlacementTrustPolicy(
            allowsLowConfidencePlacement: isGreenProfile || hasTrustedVisualAdjustment,
            allowsSyntheticCaretPlacement: isGreenProfile || hasTrustedVisualAdjustment,
            allowsDetachedAnchorPlacement: isGreenProfile || hasTrustedVisualAdjustment
        )
    }
}

public struct CompatibilityLearningEngine: Equatable, Sendable {
    public let profiles: [String: CompatibilityLearningProfile]

    public init(profiles: [String: CompatibilityLearningProfile] = [:]) {
        self.profiles = profiles
    }

    public func adjustment(
        for bundleIdentifier: String,
        profileRenderMode: SuggestionRenderMode
    ) -> CompatibilityLearningAdjustment {
        let profile = profiles[bundleIdentifier]
        let safeOverride = Self.safeRenderModeOverride(
            profile?.renderModeOverride,
            profileRenderMode: profileRenderMode
        )
        return CompatibilityLearningAdjustment(
            profile: profile,
            effectiveRenderMode: safeOverride ?? profileRenderMode,
            renderModeOverrideIgnored: profile?.renderModeOverride != nil && safeOverride == nil
        )
    }

    private static func safeRenderModeOverride(
        _ override: SuggestionRenderMode?,
        profileRenderMode: SuggestionRenderMode
    ) -> SuggestionRenderMode? {
        guard let override else {
            return nil
        }

        switch override {
        case .floatingMirror:
            switch profileRenderMode {
            case .inlineAdjacent, .floatingMirror:
                return .floatingMirror
            case .disabled:
                return nil
            }
        case .inlineAdjacent, .disabled:
            return nil
        }
    }
}
