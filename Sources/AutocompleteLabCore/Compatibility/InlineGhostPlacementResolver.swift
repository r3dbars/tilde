import CoreGraphics
import Foundation

public struct InlineGhostPlacementRequest: Equatable, Sendable {
    public let appBundleIdentifier: String?
    public let caretRect: CGRect
    public let textLineRect: CGRect?
    public let boundaryFrame: CGRect?
    public let textSize: CGSize
    public let screenFrame: CGRect
    public let minimumWidth: CGFloat
    public let maximumWidth: CGFloat

    public init(
        appBundleIdentifier: String?,
        caretRect: CGRect,
        textLineRect: CGRect?,
        boundaryFrame: CGRect?,
        textSize: CGSize,
        screenFrame: CGRect,
        minimumWidth: CGFloat,
        maximumWidth: CGFloat
    ) {
        self.appBundleIdentifier = appBundleIdentifier
        self.caretRect = caretRect
        self.textLineRect = textLineRect
        self.boundaryFrame = boundaryFrame
        self.textSize = textSize
        self.screenFrame = screenFrame
        self.minimumWidth = minimumWidth
        self.maximumWidth = maximumWidth
    }
}

public enum InlineGhostPlacementResolver {
    public static func resolve(
        _ request: InlineGhostPlacementRequest,
        registry: AppCompatibilityRegistry = .default
    ) -> InlineGhostPlacementDecision {
        let profile = registry.profile(for: request.appBundleIdentifier)
        let line = trustedLineRect(
            request.textLineRect,
            caretRect: request.caretRect,
            textHeight: request.textSize.height,
            profile: profile
        )
        let boundary = trustedBoundaryFrame(
            request.boundaryFrame,
            caretRect: request.caretRect,
            screenFrame: request.screenFrame,
            profile: profile
        )

        let verticalAnchorRect = line.rect ?? request.caretRect
        let height = max(verticalAnchorRect.height, request.caretRect.height, request.textSize.height)
        let boundsFrame = boundary.rect ?? request.screenFrame
        let preferredX = max(
            request.caretRect.maxX,
            boundsFrame.minX + profile.edgePadding,
            request.screenFrame.minX + 8
        )
        let preferredY = verticalAnchorRect.maxY - height
        let rightEdge = min(boundsFrame.maxX - profile.edgePadding, request.screenFrame.maxX - 8)
        let availableWidth = max(0, rightEdge - preferredX)
        let requiredVisibleTextWidth = min(request.textSize.width + 1, request.maximumWidth)
        let desiredWidth = min(
            max(request.textSize.width + 6, request.minimumWidth),
            request.maximumWidth
        )
        let width = min(desiredWidth, availableWidth)

        let minY = max(boundsFrame.minY + profile.edgePadding, request.screenFrame.minY + 4)
        let upperY = min(
            boundsFrame.maxY - height - profile.edgePadding,
            request.screenFrame.maxY - height - 4
        )
        let maxY = max(minY, upperY)
        let frame = CGRect(
            x: preferredX,
            y: min(max(preferredY, minY), maxY),
            width: width,
            height: height
        )

        return InlineGhostPlacementDecision(
            frame: frame,
            profileID: profile.id,
            profileName: profile.displayName,
            strategy: strategy(
                lineStatus: line.status,
                boundaryStatus: boundary.status,
                width: width,
                requiredVisibleTextWidth: requiredVisibleTextWidth,
                minimumVisibleWidth: profile.minimumVisibleWidth
            ),
            lineRectStatus: line.status,
            boundaryStatus: boundary.status
        )
    }

    private static func trustedLineRect(
        _ textLineRect: CGRect?,
        caretRect: CGRect,
        textHeight: CGFloat,
        profile: AppCompatibilityProfile
    ) -> (rect: CGRect?, status: LineRectValidationStatus) {
        guard profile.lineRectPolicy != .caretOnly else {
            return (nil, .ignoredByProfile)
        }

        guard let textLineRect else {
            return (nil, .missing)
        }

        guard textLineRect.hasFiniteGeometry,
              textLineRect.width >= 0,
              textLineRect.height > 0 else {
            return (nil, .invalidGeometry)
        }

        let expectedLineHeight = max(caretRect.height, textHeight, 1)
        let maximumReasonableHeight = max(
            expectedLineHeight * profile.maximumLineHeightMultiplier,
            expectedLineHeight + profile.minimumLineHeightAllowance
        )
        guard textLineRect.height <= maximumReasonableHeight else {
            return (nil, .tooTall)
        }

        let verticalTolerance = max(
            expectedLineHeight * profile.verticalToleranceMultiplier,
            profile.minimumVerticalTolerance
        )
        guard abs(textLineRect.midY - caretRect.midY) <= verticalTolerance else {
            return (nil, .verticallyDetached)
        }

        let horizontalTolerance = max(2, expectedLineHeight * 0.35)
        guard textLineRect.maxX <= caretRect.maxX + horizontalTolerance else {
            return (nil, .horizontallyDetached)
        }

        return (textLineRect, .used)
    }

    private static func trustedBoundaryFrame(
        _ boundaryFrame: CGRect?,
        caretRect: CGRect,
        screenFrame: CGRect,
        profile: AppCompatibilityProfile
    ) -> (rect: CGRect?, status: BoundaryValidationStatus) {
        guard profile.boundaryClipPolicy != .ignoreFocusedTextElement else {
            return (nil, .ignoredByProfile)
        }

        guard let boundaryFrame else {
            return (nil, .missing)
        }

        guard boundaryFrame.hasFiniteGeometry,
              boundaryFrame.width > 0,
              boundaryFrame.height > 0 else {
            return (nil, .invalidGeometry)
        }

        let intersection = boundaryFrame.intersection(screenFrame)
        guard !intersection.isNull else {
            return (nil, .outsideScreen)
        }

        if profile.boundaryClipPolicy == .clipToFocusedTextElementWhenCaretInside {
            let tolerance = max(caretRect.height, profile.minimumVerticalTolerance, 8)
            guard boundaryFrame.insetBy(dx: -tolerance, dy: -tolerance).contains(caretRect.center) else {
                return (nil, .caretOutside)
            }
        }

        return (intersection, .used)
    }

    private static func strategy(
        lineStatus: LineRectValidationStatus,
        boundaryStatus: BoundaryValidationStatus,
        width: CGFloat,
        requiredVisibleTextWidth: CGFloat,
        minimumVisibleWidth: CGFloat
    ) -> InlineGhostPlacementStrategy {
        guard width >= minimumVisibleWidth,
              width >= requiredVisibleTextWidth,
              boundaryStatus != .caretOutside else {
            return .hiddenNoRoom
        }

        let usesLine = lineStatus == .used
        let clipsToBoundary = boundaryStatus == .used

        switch (usesLine, clipsToBoundary) {
        case (true, true):
            return .clippedLineAnchored
        case (true, false):
            return .lineAnchored
        case (false, true):
            return .clippedCaretAnchored
        case (false, false):
            return .caretAnchored
        }
    }
}

private extension CGRect {
    var hasFiniteGeometry: Bool {
        origin.x.isFinite &&
            origin.y.isFinite &&
            size.width.isFinite &&
            size.height.isFinite
    }

    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
