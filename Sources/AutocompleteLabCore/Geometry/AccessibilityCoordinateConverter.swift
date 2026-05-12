import CoreGraphics
import Foundation

public enum AccessibilityCoordinateConverter {
    public static func appKitRect(fromAccessibilityRect rect: CGRect, screenHeight: CGFloat) -> CGRect {
        appKitRect(
            fromAccessibilityRect: rect,
            screenFrame: CGRect(x: 0, y: 0, width: 0, height: screenHeight)
        )
    }

    public static func appKitRect(fromAccessibilityRect rect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screenFrame.maxY - rect.minY - rect.height,
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

    public static func bestScreenFrame(
        containingAccessibilityRect rect: CGRect,
        screenFrames: [CGRect],
        screenHeight: CGFloat
    ) -> CGRect? {
        let probeRect = appKitProbeRect(
            fromAccessibilityRect: rect,
            screenHeight: screenHeight
        )
        return screenFrames
            .compactMap { screenFrame -> (frame: CGRect, area: CGFloat)? in
                let intersection = screenFrame.intersection(probeRect)
                guard !intersection.isNull,
                      intersection.width > 0,
                      intersection.height > 0 else {
                    return nil
                }

                return (screenFrame, intersection.width * intersection.height)
            }
            .max { $0.area < $1.area }?
            .frame
    }

}
