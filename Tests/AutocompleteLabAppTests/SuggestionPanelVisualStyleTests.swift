import AppKit
import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Suggestion panel visual style")
struct SuggestionPanelVisualStyleTests {
    @Test("Inline ghost text uses dynamic system color across native appearances")
    func inlineGhostTextUsesDynamicSystemColorAcrossNativeAppearances() throws {
        let style = SuggestionPanelVisualStyle.native

        #expect(style.usesDynamicSystemInlineTextColor)
        #expect(style.usesFocusedFieldFontWhenAvailable)
        #expect(style.appearanceCoverage.coversLightDarkAndHighContrast)

        for appearance in style.appearanceCoverage.appearances {
            let ghost = try resolvedComponents(
                of: style.textColor(for: .inlineAdjacent),
                in: appearance
            )
            let background = try resolvedComponents(of: .textBackgroundColor, in: appearance)
            let contrast = contrastRatio(blend(ghost, over: background), background)

            #expect(contrast >= style.minimumInlineTextContrastRatio)
        }
    }

    @Test("Floating mirror keeps system material and label color")
    func floatingMirrorKeepsSystemMaterialAndLabelColor() {
        let style = SuggestionPanelVisualStyle.native

        #expect(style.mirrorMaterial == .popover)
        #expect(style.mirrorCornerRadius == 7)
        #expect(style.textColor(for: .floatingMirror) == .labelColor)
        #expect(style.textColor(for: .disabled) == .secondaryLabelColor)
    }

    // MARK: - SuggestionPanelAppearancePolicy

    @Test("No accessibility restrictions: fade-in 0.12s, translucent popover")
    func noRestrictionsGivesFadeAndPopover() {
        let policy = SuggestionPanelAppearancePolicy.resolve(
            reduceMotion: false,
            reduceTransparency: false
        )

        #expect(policy.fadeInDuration == 0.12)
        #expect(policy.backdropStyle == .translucent(material: .popover))
    }

    @Test("Reduce motion: fade-in is zero, backdrop is still translucent")
    func reduceMotionSkipsFadeKeepsTranslucency() {
        let policy = SuggestionPanelAppearancePolicy.resolve(
            reduceMotion: true,
            reduceTransparency: false
        )

        #expect(policy.fadeInDuration == 0)
        #expect(policy.backdropStyle == .translucent(material: .popover))
    }

    @Test("Reduce transparency: fade-in is present, backdrop is solid")
    func reduceTransparencyKeepsFadeGivesSolid() {
        let policy = SuggestionPanelAppearancePolicy.resolve(
            reduceMotion: false,
            reduceTransparency: true
        )

        #expect(policy.fadeInDuration == 0.12)
        #expect(policy.backdropStyle == .solid)
    }

    @Test("Both restrictions: fade-in zero and solid backdrop")
    func bothRestrictionsGiveInstantAndSolid() {
        let policy = SuggestionPanelAppearancePolicy.resolve(
            reduceMotion: true,
            reduceTransparency: true
        )

        #expect(policy.fadeInDuration == 0)
        #expect(policy.backdropStyle == .solid)
    }

    @Test("Custom default material is passed through when transparency is allowed")
    func customDefaultMaterialPassedThrough() {
        let policy = SuggestionPanelAppearancePolicy.resolve(
            reduceMotion: false,
            reduceTransparency: false,
            defaultMaterial: .sidebar
        )

        #expect(policy.backdropStyle == .translucent(material: .sidebar))
    }

    @Test("Custom default material is ignored when reduce transparency is on")
    func customDefaultMaterialIgnoredWhenReduceTransparency() {
        let policy = SuggestionPanelAppearancePolicy.resolve(
            reduceMotion: false,
            reduceTransparency: true,
            defaultMaterial: .sidebar
        )

        #expect(policy.backdropStyle == .solid)
    }

    private func resolvedComponents(
        of color: NSColor,
        in appearance: NSAppearance
    ) throws -> ColorComponents {
        var resolved: ColorComponents?
        appearance.performAsCurrentDrawingAppearance {
            guard let srgb = color.usingColorSpace(.sRGB) else {
                return
            }
            resolved = ColorComponents(
                red: Double(srgb.redComponent),
                green: Double(srgb.greenComponent),
                blue: Double(srgb.blueComponent),
                alpha: Double(srgb.alphaComponent)
            )
        }

        return try #require(resolved)
    }

    private func blend(
        _ foreground: ColorComponents,
        over background: ColorComponents
    ) -> ColorComponents {
        let alpha = foreground.alpha + background.alpha * (1 - foreground.alpha)
        return ColorComponents(
            red: (foreground.red * foreground.alpha + background.red * background.alpha * (1 - foreground.alpha)) / alpha,
            green: (foreground.green * foreground.alpha + background.green * background.alpha * (1 - foreground.alpha)) / alpha,
            blue: (foreground.blue * foreground.alpha + background.blue * background.alpha * (1 - foreground.alpha)) / alpha,
            alpha: alpha
        )
    }

    private func contrastRatio(_ first: ColorComponents, _ second: ColorComponents) -> Double {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05) / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private func relativeLuminance(_ color: ColorComponents) -> Double {
        0.2126 * linearized(color.red)
            + 0.7152 * linearized(color.green)
            + 0.0722 * linearized(color.blue)
    }

    private func linearized(_ component: Double) -> Double {
        component <= 0.03928
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

private struct ColorComponents {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}
