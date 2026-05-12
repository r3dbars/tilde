import AppKit
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Ghost text color policy")
struct GhostTextColorPolicyTests {
    @Test("Inline ghost uses a light neutral color in dark editors")
    func inlineGhostUsesLightNeutralColorInDarkEditors() throws {
        let color = GhostTextColorPolicy.color(
            matching: NSColor.white,
            renderMode: .inlineAdjacent
        )
        let components = try #require(deviceRGBComponents(color))

        #expect(components.red > 0.78)
        #expect(components.green > 0.78)
        #expect(components.blue > 0.78)
        #expect(components.alpha >= 0.85)
    }

    @Test("Inline ghost keeps a subdued neutral color in light editors")
    func inlineGhostKeepsSubduedNeutralColorInLightEditors() throws {
        let color = GhostTextColorPolicy.color(
            matching: NSColor.black,
            renderMode: .inlineAdjacent
        )
        let components = try #require(deviceRGBComponents(color))

        #expect(components.red > 0.45)
        #expect(components.red < 0.60)
        #expect(components.green == components.red)
        #expect(components.blue == components.red)
        #expect(components.alpha < 0.85)
    }

    @Test("Unknown editor colors use the safe default ghost color")
    func unknownEditorColorsUseSafeDefaultGhostColor() throws {
        let color = GhostTextColorPolicy.color(
            matching: nil,
            renderMode: .inlineAdjacent
        )
        let components = try #require(deviceRGBComponents(color))

        #expect(components.red > 0.60)
        #expect(components.red < 0.70)
        #expect(components.green == components.red)
        #expect(components.blue == components.red)
        #expect(components.alpha == 0.82)
    }

    @Test("Floating mirror uses system label color")
    func floatingMirrorUsesSystemLabelColor() {
        #expect(
            GhostTextColorPolicy.color(
                matching: NSColor.white,
                renderMode: .floatingMirror
            ) == NSColor.labelColor
        )
    }

    private func deviceRGBComponents(_ color: NSColor) -> (
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat
    )? {
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            return nil
        }

        return (
            red: rgbColor.redComponent,
            green: rgbColor.greenComponent,
            blue: rgbColor.blueComponent,
            alpha: rgbColor.alphaComponent
        )
    }
}
