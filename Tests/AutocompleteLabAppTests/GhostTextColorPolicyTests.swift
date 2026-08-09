import AppKit
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Ghost text color policy")
struct GhostTextColorPolicyTests {
    @Test("Inline ghost uses a light fill with a dark halo in dark editors")
    func inlineGhostUsesLightFillWithDarkHaloInDarkEditors() throws {
        let rendering = GhostTextColorPolicy.rendering(
            matching: NSColor.white,
            renderMode: .inlineAdjacent
        )
        let fill = try #require(deviceRGBComponents(rendering.color))
        let halo = try #require(deviceRGBComponents(try #require(rendering.halo?.shadowColor)))

        #expect(fill.red > 0.72)
        #expect(fill.red < 0.88)
        #expect(fill.green == fill.red)
        #expect(fill.blue == fill.red)
        #expect(fill.alpha >= 0.85)
        #expect(halo.red < 0.1)
        #expect(halo.alpha > 0.3)
    }

    @Test("Inline ghost keeps a subdued fill with a light halo in light editors")
    func inlineGhostKeepsSubduedFillWithLightHaloInLightEditors() throws {
        let rendering = GhostTextColorPolicy.rendering(
            matching: NSColor.black,
            renderMode: .inlineAdjacent
        )
        let fill = try #require(deviceRGBComponents(rendering.color))
        let halo = try #require(deviceRGBComponents(try #require(rendering.halo?.shadowColor)))

        #expect(fill.red > 0.35)
        #expect(fill.red < 0.50)
        #expect(fill.green == fill.red)
        #expect(fill.blue == fill.red)
        #expect(fill.alpha < 0.85)
        #expect(halo.red > 0.9)
    }

    @Test("Unknown editor colors use the dual-legible default with a halo")
    func unknownEditorColorsUseDualLegibleDefaultWithHalo() throws {
        let rendering = GhostTextColorPolicy.rendering(
            matching: nil,
            renderMode: .inlineAdjacent
        )
        let fill = try #require(deviceRGBComponents(rendering.color))

        #expect(fill.red > 0.45)
        #expect(fill.red < 0.60)
        #expect(fill.green == fill.red)
        #expect(fill.blue == fill.red)
        #expect(fill.alpha == 0.82)
        #expect(rendering.halo != nil)
    }

    @Test("Inline ghost always carries a halo so no background can hide it")
    func inlineGhostAlwaysCarriesHalo() throws {
        for foreground in [NSColor.white, NSColor.black, nil] {
            let rendering = GhostTextColorPolicy.rendering(
                matching: foreground,
                renderMode: .inlineAdjacent
            )
            let halo = try #require(rendering.halo)

            #expect(halo.shadowBlurRadius > 0)
            #expect(halo.shadowOffset == .zero)
        }
    }

    @Test("Floating mirror uses system label color without a halo")
    func floatingMirrorUsesSystemLabelColorWithoutHalo() {
        let rendering = GhostTextColorPolicy.rendering(
            matching: NSColor.white,
            renderMode: .floatingMirror
        )

        #expect(rendering.color == NSColor.labelColor)
        #expect(rendering.halo == nil)
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
