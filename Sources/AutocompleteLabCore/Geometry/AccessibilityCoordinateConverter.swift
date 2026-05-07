import CoreGraphics
import Foundation

public struct AccessibilityDisplayGeometry: Equatable, Sendable {
    public let identifier: String
    public let frame: CGRect
    public let backingScaleFactor: CGFloat

    public init(
        identifier: String,
        frame: CGRect,
        backingScaleFactor: CGFloat = 1
    ) {
        self.identifier = identifier
        self.frame = frame
        self.backingScaleFactor = backingScaleFactor
    }
}

public struct AccessibilityDisplayConversion: Equatable, Sendable {
    public let appKitRect: CGRect
    public let appKitProbeRect: CGRect
    public let display: AccessibilityDisplayGeometry?

    public init(
        appKitRect: CGRect,
        appKitProbeRect: CGRect,
        display: AccessibilityDisplayGeometry?
    ) {
        self.appKitRect = appKitRect
        self.appKitProbeRect = appKitProbeRect
        self.display = display
    }
}

public enum AccessibilityCoordinateConverter {
    public static func appKitRect(fromAccessibilityRect rect: CGRect, screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screenHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    public static func appKitProbeRect(
        fromAccessibilityRect rect: CGRect,
        screenHeight: CGFloat,
        minimumSize: CGFloat = 1
    ) -> CGRect {
        let convertedRect = appKitRect(fromAccessibilityRect: rect, screenHeight: screenHeight)
        let width = max(convertedRect.width, minimumSize)
        let height = max(convertedRect.height, minimumSize)

        return CGRect(
            x: convertedRect.midX - (width / 2),
            y: convertedRect.midY - (height / 2),
            width: width,
            height: height
        )
    }

    public static func accessibilityRect(fromAppKitRect rect: CGRect, screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screenHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    public static func appKitConversion(
        fromAccessibilityRect rect: CGRect,
        screenHeight: CGFloat,
        displays: [AccessibilityDisplayGeometry],
        minimumProbeSize: CGFloat = 1
    ) -> AccessibilityDisplayConversion {
        let convertedRect = appKitRect(fromAccessibilityRect: rect, screenHeight: screenHeight)
        let probeRect = appKitProbeRect(
            fromAccessibilityRect: rect,
            screenHeight: screenHeight,
            minimumSize: minimumProbeSize
        )

        return AccessibilityDisplayConversion(
            appKitRect: convertedRect,
            appKitProbeRect: probeRect,
            display: display(containingAppKitRect: probeRect, displays: displays)
        )
    }

    public static func display(
        containingAppKitRect rect: CGRect,
        displays: [AccessibilityDisplayGeometry]
    ) -> AccessibilityDisplayGeometry? {
        displays
            .compactMap { display -> (display: AccessibilityDisplayGeometry, area: CGFloat)? in
                let intersection = display.frame.intersection(rect)
                guard !intersection.isNull,
                      intersection.width > 0,
                      intersection.height > 0 else {
                    return nil
                }

                return (display, intersection.width * intersection.height)
            }
            .max { $0.area < $1.area }?
            .display
    }
}
