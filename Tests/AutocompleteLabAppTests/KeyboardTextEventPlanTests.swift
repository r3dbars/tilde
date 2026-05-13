import CoreGraphics
import Testing
@testable import AutocompleteLabApp

@Suite("Keyboard text event plan")
struct KeyboardTextEventPlanTests {
    @Test("Maps plain prose to hardware key strokes")
    func mapsPlainProseToHardwareKeyStrokes() throws {
        let strokes = try #require(KeyboardTextEventPlan.hardwareKeyStrokes(for: "The test."))

        #expect(strokes.count == 9)
        #expect(strokes[0].virtualKey == 17)
        #expect(strokes[0].flags.contains(.maskShift))
        #expect(strokes[1].virtualKey == 4)
        #expect(strokes[1].flags.isEmpty)
        #expect(strokes[3].virtualKey == 49)
        #expect(strokes[8].virtualKey == 47)
    }

    @Test("Maps Obsidian accepted suffixes to hardware key strokes")
    func mapsObsidianAcceptedSuffixesToHardwareKeyStrokes() throws {
        let strokes = try #require(KeyboardTextEventPlan.hardwareKeyStrokes(for: " instant"))

        #expect(strokes.count == 8)
        #expect(strokes[0].virtualKey == 49)
        #expect(strokes[1].virtualKey == 34)
        #expect(strokes[7].virtualKey == 17)
    }

    @Test("Returns nil for text that needs Unicode insertion")
    func returnsNilForUnsupportedUnicode() {
        #expect(KeyboardTextEventPlan.hardwareKeyStrokes(for: "cafe\u{0301}") == nil)
    }
}
