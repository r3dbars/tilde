import Foundation

/// A capture-space rectangle normalized to the full display, origin top-left,
/// (0,0)-(1,1). Deliberately not CGRect: Core stays free of CoreGraphics so
/// this type — and everything built on it — has no AppKit/CoreGraphics
/// dependency to carry into Phase 2's pure scene classifier.
public struct NormalizedDisplayRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var centerX: Double { x + width / 2 }
    public var centerY: Double { y + height / 2 }

    public func contains(x px: Double, y py: Double) -> Bool {
        px >= minX && px <= maxX && py >= minY && py <= maxY
    }
}

/// One on-device OCR pass over the full display, kept memory-only in Phase 1.
/// The app builds this from ScreenCaptureKit + Vision; Core stays a pure,
/// testable shape so Phase 2's scene classifier and Phase 3's redaction can
/// consume it without ever importing AppKit/Vision.
public struct ScreenSnapshot: Equatable, Sendable {
    /// One OCR-recognized run of text, attributed to the window it most
    /// likely belongs to (best-effort — attribution can be nil).
    public struct TextBlock: Equatable, Sendable {
        public let text: String
        public let boundingBox: NormalizedDisplayRect
        public let windowOwnerBundleIdentifier: String?
        public let windowTitle: String?
        /// The owning window's own frame, same normalized/display-relative
        /// space as `boundingBox` — `nil` exactly when attribution is `nil`.
        /// Phase 2's scene classifier needs this to bucket a message bubble
        /// as self/other by its position *within its window*, not within
        /// the display (see `ScreenScene.OCRBlock.windowFrame`).
        public let windowFrame: NormalizedDisplayRect?

        public init(
            text: String,
            boundingBox: NormalizedDisplayRect,
            windowOwnerBundleIdentifier: String? = nil,
            windowTitle: String? = nil,
            windowFrame: NormalizedDisplayRect? = nil
        ) {
            self.text = text
            self.boundingBox = boundingBox
            self.windowOwnerBundleIdentifier = windowOwnerBundleIdentifier
            self.windowTitle = windowTitle
            self.windowFrame = windowFrame
        }
    }

    public let capturedAt: Date
    /// CGDirectDisplayID, kept as a plain UInt32 so Core never imports
    /// CoreGraphics' display headers for one integer.
    public let displayID: UInt32
    public let blocks: [TextBlock]

    public init(capturedAt: Date, displayID: UInt32, blocks: [TextBlock]) {
        self.capturedAt = capturedAt
        self.displayID = displayID
        self.blocks = blocks
    }

    /// Every window bundle identifier this snapshot's text touched, deduped.
    /// This is what capture-time exclusion logic (and, later, redaction
    /// scoping) checks against — not just the frontmost app, since capture
    /// is full-display and can see windows behind the one in focus.
    public var ownerBundleIdentifiers: Set<String> {
        Set(blocks.compactMap(\.windowOwnerBundleIdentifier))
    }
}
