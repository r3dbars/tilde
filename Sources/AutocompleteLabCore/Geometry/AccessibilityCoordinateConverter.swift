import CoreGraphics
import Foundation

public enum AccessibilityCoordinateConverter {
    public static func appKitRect(fromAccessibilityRect rect: CGRect, screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screenHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    public static func appKitRect(fromAccessibilityRect rect: CGRect, in screenFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screenFrame.maxY - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    public static func appKitProbeRect(
        fromAccessibilityRect rect: CGRect,
        in screenFrame: CGRect,
        minimumSize: CGFloat = 1
    ) -> CGRect {
        let convertedRect = appKitRect(fromAccessibilityRect: rect, in: screenFrame)
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

    public static func accessibilityRect(fromAppKitRect rect: CGRect, in screenFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screenFrame.maxY - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
