import ApplicationServices
import AppKit
import AutocompleteLabCore
import ScreenCaptureKit

/// Reads the frontmost window's text through the Accessibility tree — the
/// exact strings the app itself draws, with real frames, in ~1ms — instead
/// of screenshotting and OCRing pixels. Reading only: the covenant's ban on
/// an Accessibility *insertion* path stands. Used only when the user has
/// granted Tilde the Accessibility permission; apps whose trees carry no
/// text (many Chromium/Electron apps) simply return too little and the OCR
/// path runs as before. The same gates apply upstream (Screen Memory
/// toggle, Secure Input, exclusion list) because this runs inside the same
/// capture attempt that OCR would.
enum AXWindowTextReader {
    static let nodeBudget = 3_000
    static let timeoutSeconds = 0.15
    /// Below this much text the tree is considered unreadable and the
    /// caller falls back to OCR.
    static let minimumBlocks = 2
    static let minimumCharacters = 40

    static func isAvailable() -> Bool { AXIsProcessTrusted() }

    private static let textRoles: Set<String> = [
        kAXStaticTextRole as String, kAXTextAreaRole as String, kAXTextFieldRole as String,
        kAXCellRole as String,
    ]

    /// Walks the AX window matching `window` and returns display-normalized
    /// text blocks in the exact shape the OCR path produces, or nil when
    /// the tree yields too little to trust.
    static func blocks(for window: SCWindow, display: SCDisplay) -> [ScreenSnapshot.TextBlock]? {
        guard isAvailable(), let pid = window.owningApplication?.processID else { return nil }
        let app = AXUIElementCreateApplication(pid)
        guard let axWindow = matchWindow(app: app, frame: window.frame) else { return nil }
        let owner = window.owningApplication?.bundleIdentifier
        let windowFrame = ScreenCaptureService.normalize(window.frame, in: display.frame)

        var collected: [(String, CGRect)] = []
        var visited = 0
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var queue: [AXUIElement] = [axWindow]
        var index = 0
        while index < queue.count, visited < nodeBudget, Date() < deadline {
            let element = queue[index]; index += 1; visited += 1
            let role = string(element, kAXRoleAttribute as String) ?? ""
            if textRoles.contains(role) {
                let text = string(element, kAXValueAttribute as String)
                    ?? string(element, kAXTitleAttribute as String) ?? ""
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let frame = frame(element) {
                    collected.append((text, frame))
                }
            }
            queue.append(contentsOf: children(element))
        }

        let totalCharacters = collected.reduce(0) { $0 + $1.0.count }
        guard collected.count >= minimumBlocks, totalCharacters >= minimumCharacters else { return nil }
        return collected.map { text, frame in
            ScreenSnapshot.TextBlock(
                text: text,
                boundingBox: ScreenCaptureService.normalize(frame, in: display.frame),
                windowOwnerBundleIdentifier: owner,
                windowTitle: window.title,
                windowFrame: windowFrame
            )
        }
    }

    private static func matchWindow(app: AXUIElement, frame: CGRect) -> AXUIElement? {
        var windows: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows) == .success,
           let list = windows as? [AXUIElement] {
            for candidate in list {
                if let f = self.frame(candidate),
                   abs(f.origin.x - frame.origin.x) < 4, abs(f.origin.y - frame.origin.y) < 4,
                   abs(f.width - frame.width) < 8, abs(f.height - frame.height) < 8 {
                    return candidate
                }
            }
        }
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focused) == .success,
           CFGetTypeID(focused) == AXUIElementGetTypeID() {
            return (focused as! AXUIElement)
        }
        return nil
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private static func frame(_ element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let positionValue = position, CFGetTypeID(positionValue) == AXValueGetTypeID(),
              let sizeValue = size, CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        var box = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &box) else { return nil }
        return CGRect(origin: point, size: box)
    }
}
