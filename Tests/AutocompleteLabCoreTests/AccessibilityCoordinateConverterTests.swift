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

    @Test("Resolves primary display conversion")
    func resolvesPrimaryDisplayConversion() throws {
        let conversion = AccessibilityCoordinateConverter.appKitConversion(
            fromAccessibilityRect: CGRect(x: 100, y: 240, width: 0, height: 20),
            screenHeight: 900,
            displays: [
                AccessibilityDisplayGeometry(
                    identifier: "primary",
                    frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                    backingScaleFactor: 2
                )
            ]
        )

        let display = try #require(conversion.display)
        #expect(display.identifier == "primary")
        #expect(conversion.appKitRect.minX == 100)
        #expect(conversion.appKitRect.minY == 640)
        #expect(conversion.appKitProbeRect.width == 1)
    }

    @Test("Resolves a display left of the primary display")
    func resolvesLeftOfPrimaryDisplayConversion() throws {
        let conversion = AccessibilityCoordinateConverter.appKitConversion(
            fromAccessibilityRect: CGRect(x: -1200, y: 180, width: 0, height: 20),
            screenHeight: 900,
            displays: [
                AccessibilityDisplayGeometry(
                    identifier: "primary",
                    frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                    backingScaleFactor: 2
                ),
                AccessibilityDisplayGeometry(
                    identifier: "left",
                    frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                    backingScaleFactor: 1
                )
            ]
        )

        let display = try #require(conversion.display)
        #expect(display.identifier == "left")
        #expect(conversion.appKitRect.minX == -1200)
        #expect(conversion.appKitRect.minY == 700)
    }

    @Test("Resolves a display above the primary display")
    func resolvesAbovePrimaryDisplayConversion() throws {
        let conversion = AccessibilityCoordinateConverter.appKitConversion(
            fromAccessibilityRect: CGRect(x: 320, y: -320, width: 0, height: 20),
            screenHeight: 900,
            displays: [
                AccessibilityDisplayGeometry(
                    identifier: "primary",
                    frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                    backingScaleFactor: 2
                ),
                AccessibilityDisplayGeometry(
                    identifier: "above",
                    frame: CGRect(x: 0, y: 900, width: 1440, height: 900),
                    backingScaleFactor: 2
                )
            ]
        )

        let display = try #require(conversion.display)
        #expect(display.identifier == "above")
        #expect(conversion.appKitRect.minX == 320)
        #expect(conversion.appKitRect.minY == 1200)
    }

    @Test("Keeps Retina and non-Retina display frames in point coordinates")
    func keepsMixedScaleDisplayFramesInPointCoordinates() throws {
        let conversion = AccessibilityCoordinateConverter.appKitConversion(
            fromAccessibilityRect: CGRect(x: 1600, y: 100, width: 0, height: 20),
            screenHeight: 900,
            displays: [
                AccessibilityDisplayGeometry(
                    identifier: "primary-retina",
                    frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                    backingScaleFactor: 2
                ),
                AccessibilityDisplayGeometry(
                    identifier: "right-non-retina",
                    frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
                    backingScaleFactor: 1
                )
            ]
        )

        let display = try #require(conversion.display)
        #expect(display.identifier == "right-non-retina")
        #expect(display.backingScaleFactor == 1)
        #expect(conversion.appKitRect.minX == 1600)
        #expect(conversion.appKitRect.minY == 780)
    }
}
