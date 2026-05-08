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

    @Test("Converts bottom-left AppKit rect back to top-left accessibility rect")
    func convertsBottomLeftBackToTopLeft() {
        let appKitRect = CGRect(x: 158, y: 839, width: 0, height: 14)
        let accessibilityRect = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: appKitRect,
            screenHeight: 1080
        )

        #expect(accessibilityRect.minX == 158)
        #expect(accessibilityRect.minY == 227)
        #expect(accessibilityRect.height == 14)
    }

    @Test("Converts accessibility rects on negative-origin screens")
    func convertsNegativeOriginScreenRects() {
        let mainScreenHeight: CGFloat = 878
        let screenFrame = CGRect(x: -2560, y: 303, width: 2560, height: 1440)
        let accessibilityRect = CGRect(x: -1380, y: 165, width: 0, height: 20)
        let appKitRect = AccessibilityCoordinateConverter.appKitRect(
            fromAccessibilityRect: accessibilityRect,
            screenHeight: mainScreenHeight
        )
        let roundTripRect = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: appKitRect,
            screenHeight: mainScreenHeight
        )

        #expect(appKitRect.minX == -1380)
        #expect(appKitRect.minY == 693)
        #expect(screenFrame.contains(CGPoint(x: appKitRect.midX, y: appKitRect.midY)))
        #expect(roundTripRect == accessibilityRect)
    }

    @Test("Builds non-empty probe rects for zero-width carets")
    func buildsProbeRectForZeroWidthCarets() {
        let mainScreenHeight: CGFloat = 878
        let screenFrame = CGRect(x: -2560, y: 303, width: 2560, height: 1440)
        let caretRect = CGRect(x: -1380, y: 165, width: 0, height: 20)
        let probeRect = AccessibilityCoordinateConverter.appKitProbeRect(
            fromAccessibilityRect: caretRect,
            screenHeight: mainScreenHeight
        )

        #expect(probeRect.width == 1)
        #expect(probeRect.height == 20)
        #expect(screenFrame.intersects(probeRect))
    }

    @Test("Finds screen above the main display")
    func findsScreenAboveMainDisplay() {
        let mainScreenHeight: CGFloat = 900
        let mainScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let upperScreen = CGRect(x: 0, y: 900, width: 1440, height: 900)
        let caretOnUpperScreen = CGRect(x: 640, y: -140, width: 0, height: 20)

        let bestScreen = AccessibilityCoordinateConverter.bestScreenFrame(
            containingAccessibilityRect: caretOnUpperScreen,
            screenFrames: [mainScreen, upperScreen],
            screenHeight: mainScreenHeight
        )

        #expect(bestScreen == upperScreen)
    }

    @Test("Finds screen below the main display")
    func findsScreenBelowMainDisplay() {
        let mainScreenHeight: CGFloat = 900
        let lowerScreen = CGRect(x: 0, y: -900, width: 1440, height: 900)
        let mainScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let caretOnLowerScreen = CGRect(x: 640, y: 1_040, width: 0, height: 20)

        let bestScreen = AccessibilityCoordinateConverter.bestScreenFrame(
            containingAccessibilityRect: caretOnLowerScreen,
            screenFrames: [lowerScreen, mainScreen],
            screenHeight: mainScreenHeight
        )

        #expect(bestScreen == lowerScreen)
    }

    @Test("Returns nil when no screen contains the converted caret")
    func returnsNilWhenNoScreenContainsConvertedCaret() {
        let bestScreen = AccessibilityCoordinateConverter.bestScreenFrame(
            containingAccessibilityRect: CGRect(x: 4_000, y: 4_000, width: 0, height: 20),
            screenFrames: [CGRect(x: 0, y: 0, width: 1440, height: 900)],
            screenHeight: 900
        )

        #expect(bestScreen == nil)
    }
}
