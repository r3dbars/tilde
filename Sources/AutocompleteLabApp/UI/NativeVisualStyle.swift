import AppKit
import AutocompleteLabCore

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
