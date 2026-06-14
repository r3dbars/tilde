import AppKit
import AutocompleteLabCore

// MARK: - Accessibility display policy

/// Pure function: maps accessibility prefs to concrete panel appearance choices.
/// Unit-testable without UI — takes plain booleans, returns plain value types.
enum SuggestionPanelBackdropStyle: Equatable {
    /// Use an NSVisualEffectView with the given material (translucent, system-matched).
    case translucent(material: NSVisualEffectView.Material)
    /// Use a solid opaque background instead of a translucent material.
    case solid
}

struct SuggestionPanelAppearancePolicy: Equatable {
    /// Duration of the fade-in animation on first panel appearance (0 = instant snap).
    let fadeInDuration: TimeInterval
    /// How the floating mirror backdrop should be rendered.
    let backdropStyle: SuggestionPanelBackdropStyle

    /// Derive appearance choices from raw accessibility prefs.
    ///
    /// - Parameters:
    ///   - reduceMotion: Value of `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.
    ///   - reduceTransparency: Value of `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency`.
    ///   - defaultMaterial: The translucent material to use when transparency is allowed.
    static func resolve(
        reduceMotion: Bool,
        reduceTransparency: Bool,
        defaultMaterial: NSVisualEffectView.Material = .popover
    ) -> SuggestionPanelAppearancePolicy {
        SuggestionPanelAppearancePolicy(
            fadeInDuration: reduceMotion ? 0 : 0.12,
            backdropStyle: reduceTransparency ? .solid : .translucent(material: defaultMaterial)
        )
    }
}

// MARK: - Native appearance coverage

struct NativeAppearanceCoverage: Equatable {
    let appearanceNames: [String]

    static let lightDarkAndHighContrast = NativeAppearanceCoverage(
        appearanceNames: [
            NSAppearance.Name.aqua.rawValue,
            NSAppearance.Name.darkAqua.rawValue,
            NSAppearance.Name.accessibilityHighContrastAqua.rawValue,
            NSAppearance.Name.accessibilityHighContrastDarkAqua.rawValue
        ]
    )

    var coversLightDarkAndHighContrast: Bool {
        let required = Set(Self.lightDarkAndHighContrast.appearanceNames)
        return Set(appearanceNames).isSuperset(of: required)
    }

    var appearances: [NSAppearance] {
        appearanceNames.compactMap { NSAppearance(named: NSAppearance.Name($0)) }
    }
}

struct SuggestionPanelVisualStyle {
    let appearanceCoverage: NativeAppearanceCoverage
    let mirrorMaterial: NSVisualEffectView.Material
    let mirrorCornerRadius: CGFloat
    let usesDynamicSystemInlineTextColor: Bool
    let usesFocusedFieldFontWhenAvailable: Bool
    let minimumInlineTextContrastRatio: Double

    static let native = SuggestionPanelVisualStyle(
        appearanceCoverage: .lightDarkAndHighContrast,
        mirrorMaterial: .popover,
        mirrorCornerRadius: 7,
        usesDynamicSystemInlineTextColor: true,
        usesFocusedFieldFontWhenAvailable: true,
        minimumInlineTextContrastRatio: 3
    )

    func textColor(for renderMode: SuggestionRenderMode) -> NSColor {
        switch renderMode {
        case .floatingMirror:
            return .labelColor
        case .inlineAdjacent:
            return .placeholderTextColor
        case .disabled:
            return .secondaryLabelColor
        }
    }
}
