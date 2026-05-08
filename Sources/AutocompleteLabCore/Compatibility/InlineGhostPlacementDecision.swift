import CoreGraphics
import Foundation

public enum InlineGhostPlacementStrategy: String, Equatable, Sendable {
    case caretAnchored
    case lineAnchored
    case clippedCaretAnchored
    case clippedLineAnchored
    case hiddenNoRoom
}

public enum LineRectValidationStatus: String, Equatable, Sendable {
    case used
    case missing
    case ignoredByProfile
    case invalidGeometry
    case tooTall
    case verticallyDetached
    case horizontallyDetached
}

public enum BoundaryValidationStatus: String, Equatable, Sendable {
    case used
    case missing
    case ignoredByProfile
    case invalidGeometry
    case outsideScreen
    case caretOutside
}

public struct InlineGhostPlacementDecision: Equatable, Sendable {
    public let frame: CGRect
    public let profileID: String
    public let profileName: String
    public let strategy: InlineGhostPlacementStrategy
    public let lineRectStatus: LineRectValidationStatus
    public let boundaryStatus: BoundaryValidationStatus

    public init(
        frame: CGRect,
        profileID: String,
        profileName: String,
        strategy: InlineGhostPlacementStrategy,
        lineRectStatus: LineRectValidationStatus,
        boundaryStatus: BoundaryValidationStatus
    ) {
        self.frame = frame
        self.profileID = profileID
        self.profileName = profileName
        self.strategy = strategy
        self.lineRectStatus = lineRectStatus
        self.boundaryStatus = boundaryStatus
    }

    public var debugSummary: String {
        [
            "profile=\(profileID)",
            "strategy=\(strategy.rawValue)",
            "line=\(lineRectStatus.rawValue)",
            "boundary=\(boundaryStatus.rawValue)",
            "frame=\(frame.diagnosticDescription)"
        ].joined(separator: " ")
    }
}

public extension CGRect {
    var diagnosticDescription: String {
        "x:\(origin.x.roundedDiagnostic) y:\(origin.y.roundedDiagnostic) w:\(size.width.roundedDiagnostic) h:\(size.height.roundedDiagnostic)"
    }
}

private extension CGFloat {
    var roundedDiagnostic: String {
        String(format: "%.1f", Double(self))
    }
}
