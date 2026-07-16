import Foundation

/// How the floating suggestion panel should present itself, given the user's
/// macOS accessibility display preferences.
///
/// This is a pure value so the decision can be unit-tested without AppKit. The
/// app shell reads the live system preferences and maps `background` onto the
/// native `NSVisualEffectView` material (or a solid fill) and `firstAppearanceFadeDuration`
/// onto the first-appearance animation.
public struct SuggestionPanelAccessibilityPresentation: Equatable, Sendable {
    /// The backdrop fill the floating mirror should use.
    public enum Background: Equatable, Sendable {
        /// Translucent vibrancy material — the default native look.
        case translucentMaterial
        /// Opaque, solid fill — used when the user asks to reduce transparency.
        case solid
    }

    /// How long the panel's first appearance should fade in. Zero means snap in
    /// with no animation (Reduce Motion).
    public let firstAppearanceFadeDuration: TimeInterval

    /// Which backdrop fill to use behind the floating mirror.
    public let background: Background

    public init(firstAppearanceFadeDuration: TimeInterval, background: Background) {
        self.firstAppearanceFadeDuration = firstAppearanceFadeDuration
        self.background = background
    }

    /// Whether the first appearance should animate at all. False under Reduce Motion.
    public var animatesFirstAppearance: Bool {
        firstAppearanceFadeDuration > 0
    }
}

/// Decides how the floating suggestion panel presents itself from the two macOS
/// accessibility display preferences. Pure and deterministic — no AppKit.
public enum SuggestionPanelAccessibilityPresentationPolicy {
    /// The gentle fade used on first appearance when motion is allowed. Matches
    /// the feel of native transient overlays.
    public static let defaultFirstAppearanceFadeDuration: TimeInterval = 0.12

    /// Resolve the panel presentation from the live accessibility preferences.
    ///
    /// - Parameters:
    ///   - reduceMotion: `NSWorkspace.accessibilityDisplayShouldReduceMotion`.
    ///     When true, the panel snaps in with no fade.
    ///   - reduceTransparency: `NSWorkspace.accessibilityDisplayShouldReduceTransparency`.
    ///     When true, the panel uses a solid background instead of translucency.
    public static func resolve(
        reduceMotion: Bool,
        reduceTransparency: Bool,
        prefersImmediateAppearance: Bool = false
    ) -> SuggestionPanelAccessibilityPresentation {
        SuggestionPanelAccessibilityPresentation(
            firstAppearanceFadeDuration: reduceMotion || prefersImmediateAppearance
                ? 0
                : defaultFirstAppearanceFadeDuration,
            background: reduceTransparency ? .solid : .translucentMaterial
        )
    }
}
