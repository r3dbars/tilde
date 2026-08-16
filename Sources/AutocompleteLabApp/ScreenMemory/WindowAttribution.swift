import AutocompleteLabCore

/// Maps one OCR text block back to the window it most likely came from.
/// Pure geometry — no ScreenCaptureKit or Vision types — so it is testable
/// with synthetic window lists, independent of a live display or a granted
/// Screen Recording permission.
enum WindowAttribution {
    struct WindowInfo: Equatable, Sendable {
        let bundleIdentifier: String?
        let title: String?
        /// Same top-left-origin space, normalized to the captured display,
        /// as the OCR block's `boundingBox`.
        let frame: NormalizedDisplayRect
    }

    /// `windows` must be front-to-back ordered (frontmost first) — Apple
    /// does not document an ordering guarantee for
    /// `SCShareableContent.windows`, so the caller is responsible for
    /// sorting (ScreenCaptureService sorts by `windowLayer`) before calling
    /// this. The first window whose frame contains the block's center point
    /// wins, so a block sitting in the overlap of two windows attributes to
    /// whichever is actually on top, not whichever the OS happened to
    /// enumerate first.
    static func attribute(boundingBox: NormalizedDisplayRect, frontToBackWindows windows: [WindowInfo]) -> WindowInfo? {
        windows.first { $0.frame.contains(x: boundingBox.centerX, y: boundingBox.centerY) }
    }
}
