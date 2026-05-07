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

public struct CompatibilityLearningProfile: Codable, Equatable, Sendable {
    public let bundleIdentifier: String
    public var xOffset: CGFloat
    public var yOffset: CGFloat
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
        guard hasVisualAdjustment,
              visualScope != nil else {
            return false
        }

        return lastReason == "manual-visual-nudge" || lastReason == "screenshot-visual-correction"
    }

    public func hasTrustedVisualAdjustment(matching visualScope: CompatibilityLearningVisualScope?) -> Bool {
        guard hasTrustedVisualAdjustment,
              let storedScope = self.visualScope,
              let visualScope else {
            return false
        }

        return storedScope == visualScope
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
}

public struct CompatibilityLearningAdjustment: Equatable, Sendable {
    public let profile: CompatibilityLearningProfile?
    public let effectiveRenderMode: SuggestionRenderMode
    public let renderModeOverrideIgnored: Bool

    public init(
        profile: CompatibilityLearningProfile?,
        effectiveRenderMode: SuggestionRenderMode,
        renderModeOverrideIgnored: Bool = false
    ) {
        self.profile = profile
        self.effectiveRenderMode = effectiveRenderMode
        self.renderModeOverrideIgnored = renderModeOverrideIgnored
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
            renderModeOverrideIgnored: renderModeOverrideIgnored
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

    private func trustedVisualOffsetOnly(
        matching visualScope: CompatibilityLearningVisualScope?,
        allowUnscopedTrustedOffset: Bool
    ) -> CompatibilityLearningAdjustment {
        guard let profile,
              !(allowUnscopedTrustedOffset
                ? profile.hasTrustedVisualAdjustment
                : profile.hasTrustedVisualAdjustment(matching: visualScope)) else {
            return self
        }

        return withoutVisualOffset
    }

    public var metadata: [String: String] {
        guard let profile else {
            return [
                "learningApplied": "false",
                "learningRenderMode": effectiveRenderMode.rawValue,
                "learningRenderModeOverrideIgnored": "false",
                "learningVisualOffsetTrusted": "false"
            ]
        }

        let renderModeOverrideApplied = profile.renderModeOverride != nil && !renderModeOverrideIgnored
        return [
            "learningApplied": String(profile.hasVisualAdjustment || renderModeOverrideApplied),
            "learningRenderMode": effectiveRenderMode.rawValue,
            "learningRenderModeOverrideIgnored": String(renderModeOverrideIgnored),
            "learningXOffset": String(format: "%.1f", Double(profile.xOffset)),
            "learningYOffset": String(format: "%.1f", Double(profile.yOffset)),
            "learningVisualOffsetTrusted": String(profile.hasTrustedVisualAdjustment),
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
            allowsSyntheticCaretPlacement: isGreenProfile || hasTrustedVisualAdjustment
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
