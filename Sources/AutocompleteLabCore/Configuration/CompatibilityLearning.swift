import CoreGraphics
import Foundation

public struct CompatibilityLearningProfile: Codable, Equatable, Sendable {
    public let bundleIdentifier: String
    public var xOffset: CGFloat
    public var yOffset: CGFloat
    public var renderModeOverride: SuggestionRenderMode?
    public var screenshotTracingEnabled: Bool
    public var observations: Int
    public var confidence: Double
    public var lastReason: String
    public var updatedAt: String

    public init(
        bundleIdentifier: String,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0,
        renderModeOverride: SuggestionRenderMode? = nil,
        screenshotTracingEnabled: Bool = false,
        observations: Int = 0,
        confidence: Double = 0,
        lastReason: String = "",
        updatedAt: String = ""
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.renderModeOverride = renderModeOverride
        self.screenshotTracingEnabled = screenshotTracingEnabled
        self.observations = observations
        self.confidence = confidence
        self.lastReason = lastReason
        self.updatedAt = updatedAt
    }

    public var hasVisualAdjustment: Bool {
        abs(xOffset) > 0.01 || abs(yOffset) > 0.01
    }

    public var hasTrustedVisualAdjustment: Bool {
        guard hasVisualAdjustment else {
            return false
        }

        if lastReason == "manual-visual-nudge" || lastReason == "screenshot-visual-correction" {
            return true
        }

        return confidence >= 0.6 && observations >= 3
    }

    public var debugSummary: String {
        let render = renderModeOverride?.rawValue ?? "profile"
        return "offset=(\(Self.format(xOffset)), \(Self.format(yOffset))), render=\(render), screenshots=\(screenshotTracingEnabled), observations=\(observations), confidence=\(Self.format(confidence))"
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

    public init(
        profile: CompatibilityLearningProfile?,
        effectiveRenderMode: SuggestionRenderMode
    ) {
        self.profile = profile
        self.effectiveRenderMode = effectiveRenderMode
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
            effectiveRenderMode: effectiveRenderMode
        )
    }

    public var trustedVisualOffsetOnly: CompatibilityLearningAdjustment {
        guard let profile,
              !profile.hasTrustedVisualAdjustment else {
            return self
        }

        return withoutVisualOffset
    }

    public var metadata: [String: String] {
        guard let profile else {
            return [
                "learningApplied": "false",
                "learningRenderMode": effectiveRenderMode.rawValue,
                "learningVisualOffsetTrusted": "false"
            ]
        }

        return [
            "learningApplied": String(profile.hasVisualAdjustment || profile.renderModeOverride != nil),
            "learningRenderMode": effectiveRenderMode.rawValue,
            "learningXOffset": String(format: "%.1f", Double(profile.xOffset)),
            "learningYOffset": String(format: "%.1f", Double(profile.yOffset)),
            "learningVisualOffsetTrusted": String(profile.hasTrustedVisualAdjustment),
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
        return CompatibilityLearningAdjustment(
            profile: profile,
            effectiveRenderMode: profile?.renderModeOverride ?? profileRenderMode
        )
    }
}
