import CoreGraphics
import Foundation

public struct CompatibilityLearningProfile: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 3
    public static let unscopedSurfaceIdentifier = "unscoped-legacy"
    public static let unscopedVersionRangeDescription = "legacy-unproven"

    public var schemaVersion: Int
    public let bundleIdentifier: String
    public var surfaceIdentifier: String
    public var versionRangeDescription: String
    public var preferredPath: CompatibilityPreferredPath
    public var hardCaps: [CompatibilityHardCap]
    public var proofLabel: String?
    public var proofArtifactPath: String?
    public var lastVerifiedAt: String?
    public var xOffset: CGFloat
    public var yOffset: CGFloat
    public var visualAppVersion: String?
    public var visualScreenFingerprint: String?
    public var visualFieldShapeFingerprint: String?
    public var renderModeOverride: SuggestionRenderMode?
    public var screenshotTracingEnabled: Bool
    public var screenshotTracingExpiresAt: String?
    public var observations: Int
    public var confidence: Double
    public var lastReason: String
    public var updatedAt: String

    public init(
        bundleIdentifier: String,
        schemaVersion: Int = Self.currentSchemaVersion,
        surfaceIdentifier: String = Self.unscopedSurfaceIdentifier,
        versionRangeDescription: String = Self.unscopedVersionRangeDescription,
        preferredPath: CompatibilityPreferredPath = .blocked,
        hardCaps: [CompatibilityHardCap] = [.diagnosticsOnly],
        proofLabel: String? = nil,
        proofArtifactPath: String? = nil,
        lastVerifiedAt: String? = nil,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0,
        visualAppVersion: String? = nil,
        visualScreenFingerprint: String? = nil,
        visualFieldShapeFingerprint: String? = nil,
        renderModeOverride: SuggestionRenderMode? = nil,
        screenshotTracingEnabled: Bool = false,
        screenshotTracingExpiresAt: String? = nil,
        observations: Int = 0,
        confidence: Double = 0,
        lastReason: String = "",
        updatedAt: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.bundleIdentifier = bundleIdentifier
        self.surfaceIdentifier = surfaceIdentifier
        self.versionRangeDescription = versionRangeDescription
        self.preferredPath = preferredPath
        self.hardCaps = hardCaps
        self.proofLabel = proofLabel
        self.proofArtifactPath = proofArtifactPath
        self.lastVerifiedAt = lastVerifiedAt
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.visualAppVersion = visualAppVersion
        self.visualScreenFingerprint = visualScreenFingerprint
        self.visualFieldShapeFingerprint = visualFieldShapeFingerprint
        self.renderModeOverride = renderModeOverride
        self.screenshotTracingEnabled = screenshotTracingEnabled
        self.screenshotTracingExpiresAt = screenshotTracingExpiresAt
        self.observations = observations
        self.confidence = confidence
        self.lastReason = lastReason
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case bundleIdentifier
        case surfaceIdentifier
        case versionRangeDescription
        case preferredPath
        case hardCaps
        case proofLabel
        case proofArtifactPath
        case lastVerifiedAt
        case xOffset
        case yOffset
        case visualAppVersion
        case visualScreenFingerprint
        case visualFieldShapeFingerprint
        case renderModeOverride
        case screenshotTracingEnabled
        case screenshotTracingExpiresAt
        case observations
        case confidence
        case lastReason
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        surfaceIdentifier = try container.decodeIfPresent(String.self, forKey: .surfaceIdentifier)
            ?? Self.unscopedSurfaceIdentifier
        versionRangeDescription = try container.decodeIfPresent(String.self, forKey: .versionRangeDescription)
            ?? Self.unscopedVersionRangeDescription
        preferredPath = try container.decodeIfPresent(CompatibilityPreferredPath.self, forKey: .preferredPath)
            ?? .blocked
        hardCaps = try container.decodeIfPresent([CompatibilityHardCap].self, forKey: .hardCaps)
            ?? [.diagnosticsOnly]
        proofLabel = try container.decodeIfPresent(String.self, forKey: .proofLabel)
        proofArtifactPath = try container.decodeIfPresent(String.self, forKey: .proofArtifactPath)
        lastVerifiedAt = try container.decodeIfPresent(String.self, forKey: .lastVerifiedAt)
        xOffset = try container.decodeIfPresent(CGFloat.self, forKey: .xOffset) ?? 0
        yOffset = try container.decodeIfPresent(CGFloat.self, forKey: .yOffset) ?? 0
        visualAppVersion = try container.decodeIfPresent(String.self, forKey: .visualAppVersion)
        visualScreenFingerprint = try container.decodeIfPresent(String.self, forKey: .visualScreenFingerprint)
        visualFieldShapeFingerprint = try container.decodeIfPresent(String.self, forKey: .visualFieldShapeFingerprint)
        renderModeOverride = try container.decodeIfPresent(SuggestionRenderMode.self, forKey: .renderModeOverride)
        screenshotTracingEnabled = try container.decodeIfPresent(Bool.self, forKey: .screenshotTracingEnabled) ?? false
        screenshotTracingExpiresAt = try container.decodeIfPresent(String.self, forKey: .screenshotTracingExpiresAt)
        observations = try container.decodeIfPresent(Int.self, forKey: .observations) ?? 0
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        lastReason = try container.decodeIfPresent(String.self, forKey: .lastReason) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(surfaceIdentifier, forKey: .surfaceIdentifier)
        try container.encode(versionRangeDescription, forKey: .versionRangeDescription)
        try container.encode(preferredPath, forKey: .preferredPath)
        try container.encode(hardCaps, forKey: .hardCaps)
        try container.encodeIfPresent(proofLabel, forKey: .proofLabel)
        try container.encodeIfPresent(proofArtifactPath, forKey: .proofArtifactPath)
        try container.encodeIfPresent(lastVerifiedAt, forKey: .lastVerifiedAt)
        try container.encode(xOffset, forKey: .xOffset)
        try container.encode(yOffset, forKey: .yOffset)
        try container.encodeIfPresent(visualAppVersion, forKey: .visualAppVersion)
        try container.encodeIfPresent(visualScreenFingerprint, forKey: .visualScreenFingerprint)
        try container.encodeIfPresent(visualFieldShapeFingerprint, forKey: .visualFieldShapeFingerprint)
        try container.encodeIfPresent(renderModeOverride, forKey: .renderModeOverride)
        try container.encode(screenshotTracingEnabled, forKey: .screenshotTracingEnabled)
        try container.encodeIfPresent(screenshotTracingExpiresAt, forKey: .screenshotTracingExpiresAt)
        try container.encode(observations, forKey: .observations)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(lastReason, forKey: .lastReason)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    public var hasVisualAdjustment: Bool {
        abs(xOffset) > 0.01 || abs(yOffset) > 0.01
    }

    public var hasTrustedVisualAdjustment: Bool {
        hasTrustedVisualAdjustment(in: nil)
    }

    public var compatibilityScopeIsCurrent: Bool {
        schemaVersion >= Self.currentSchemaVersion
            && surfaceIdentifier != Self.unscopedSurfaceIdentifier
            && versionRangeDescription != Self.unscopedVersionRangeDescription
    }

    public var profileIdentifier: String {
        "\(bundleIdentifier)::\(surfaceIdentifier)::\(preferredPath.rawValue)"
    }

    public var scopeMetadata: [String: String] {
        var metadata = [
            "learningCompatibilityProfileID": profileIdentifier,
            "learningCompatibilitySchemaVersion": String(schemaVersion),
            "learningCompatibilitySurface": surfaceIdentifier,
            "learningCompatibilityVersionRange": versionRangeDescription,
            "learningCompatibilityPreferredPath": preferredPath.rawValue,
            "learningCompatibilityHardCaps": hardCaps.map(\.rawValue).joined(separator: ",")
        ]

        metadata["learningCompatibilityProofLabel"] = proofLabel
        metadata["learningCompatibilityProofArtifactPath"] = proofArtifactPath
        metadata["learningCompatibilityLastVerifiedAt"] = lastVerifiedAt
        return metadata
    }

    public mutating func applyCompatibilityScope(from profile: CompatibilityProfile?) {
        schemaVersion = Self.currentSchemaVersion

        guard let profile else {
            surfaceIdentifier = "user-created-unproven"
            versionRangeDescription = "unproven-current-local"
            preferredPath = .blocked
            hardCaps = [.diagnosticsOnly, .unknownCustomEditorDetectOnly]
            proofLabel = nil
            proofArtifactPath = nil
            lastVerifiedAt = nil
            return
        }

        surfaceIdentifier = profile.surfaceIdentifier
        versionRangeDescription = profile.versionRangeDescription
        preferredPath = profile.preferredPath
        hardCaps = profile.hardCaps
        proofLabel = profile.proofLabel
        proofArtifactPath = profile.proofArtifactPath
        lastVerifiedAt = profile.lastVerifiedAt
    }

    public func hasTrustedVisualAdjustment(
        in context: CompatibilityLearningVisualTrustContext?
    ) -> Bool {
        guard hasVisualAdjustment else {
            return false
        }

        guard lastReason == "manual-visual-nudge"
                || lastReason == "screenshot-visual-correction" else {
            return false
        }

        guard let context else {
            return true
        }

        return matchesVisualTrustContext(context)
    }

    public var debugSummary: String {
        let render = renderModeOverride?.rawValue ?? "profile"
        return "profile=\(profileIdentifier), offset=(\(Self.format(xOffset)), \(Self.format(yOffset))), render=\(render), screenshots=\(screenshotTracingEnabled), observations=\(observations), confidence=\(Self.format(confidence))"
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func matchesVisualTrustContext(
        _ context: CompatibilityLearningVisualTrustContext
    ) -> Bool {
        matches(visualAppVersion, context.appVersion)
            && matches(visualScreenFingerprint, context.screenFingerprint)
            && matches(visualFieldShapeFingerprint, context.fieldShapeFingerprint)
    }

    private func matches(_ stored: String?, _ current: String?) -> Bool {
        guard let stored, !stored.isEmpty else {
            return true
        }

        return stored == current
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
        trustedVisualOffsetOnly(context: nil)
    }

    public func trustedVisualOffsetOnly(
        context: CompatibilityLearningVisualTrustContext?
    ) -> CompatibilityLearningAdjustment {
        guard let profile,
              !profile.hasTrustedVisualAdjustment(in: context) else {
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

        var metadata = [
            "learningApplied": String(profile.hasVisualAdjustment || profile.renderModeOverride != nil),
            "learningRenderMode": effectiveRenderMode.rawValue,
            "learningXOffset": String(format: "%.1f", Double(profile.xOffset)),
            "learningYOffset": String(format: "%.1f", Double(profile.yOffset)),
            "learningVisualOffsetTrusted": String(profile.hasTrustedVisualAdjustment),
            "learningConfidence": String(format: "%.2f", profile.confidence),
            "learningObservations": String(profile.observations),
            "learningScreenshotTracing": String(profile.screenshotTracingEnabled)
        ]
        metadata.merge(profile.scopeMetadata) { current, _ in current }
        return metadata
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
