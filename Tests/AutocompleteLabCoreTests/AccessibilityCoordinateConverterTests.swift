import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Accessibility coordinate converter")
struct AccessibilityCoordinateConverterTests {
    @Test("Converts top-left accessibility rect to bottom-left AppKit rect")
    func convertsTopLeftToBottomLeft() {
        let accessibilityRect = CGRect(x: 158, y: 227, width: 0, height: 14)
        let appKitRect = AccessibilityCoordinateConverter.appKitRect(
            fromAccessibilityRect: accessibilityRect,
            screenHeight: 1080
        )

        #expect(appKitRect.minX == 158)
        #expect(appKitRect.minY == 839)
        #expect(appKitRect.height == 14)
    }

    @Test("Converts using the screen frame for non-zero screen origins")
    func convertsUsingScreenFrame() {
        let accessibilityRect = CGRect(x: 1590, y: 82, width: 12, height: 24)
        let appKitRect = AccessibilityCoordinateConverter.appKitRect(
            fromAccessibilityRect: accessibilityRect,
            screenFrame: CGRect(x: 1440, y: -240, width: 1600, height: 900)
        )

        #expect(appKitRect.minX == 1590)
        #expect(appKitRect.minY == 554)
        #expect(appKitRect.width == 12)
        #expect(appKitRect.height == 24)
    }
}
