import CoreGraphics
import Foundation

/// The app process a capture request concerns.
struct RunningApplicationInfo: Equatable, Sendable {
    let bundleIdentifier: String
    let localizedName: String
    let processIdentifier: pid_t
}

/// Minimal description of the focused field for screen-context capture — the
/// only surviving concern of the old accessibility layer. The input method has
/// no AX view of the world, so `GhostScreenContextBridge` fills this from the
/// requesting app's frontmost window.
struct FocusedTextContext: Equatable, Sendable {
    let elementIdentifier: Int
    let textBeforeCursor: String
    let selectedTextLength: Int
    let caretRect: CGRect?
    let elementRect: CGRect?
    let windowRect: CGRect?
    let windowIdentifier: Int?
    let textLineRect: CGRect?
    let isSecure: Bool
}
