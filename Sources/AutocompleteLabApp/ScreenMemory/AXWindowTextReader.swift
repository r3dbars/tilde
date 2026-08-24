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

    /// Subtrees that never carry message text. Skipping them bounds huge
    /// windows and saves IPC; measured 2026-08-24 it loses zero blocks on
    /// chat windows.
    private static let prunedRoles: Set<String> = [
        kAXMenuBarRole as String, kAXMenuRole as String, kAXMenuItemRole as String,
        kAXToolbarRole as String, kAXScrollBarRole as String, kAXSplitterRole as String,
        kAXImageRole as String, kAXPopUpButtonRole as String, kAXButtonRole as String,
    ]

    /// All attributes a node might need, fetched in ONE round trip.
    /// Per-attribute AXUIElementCopyAttributeValue calls cost one IPC each;
    /// batching measured 41ms -> 27ms on a live Messages window (92 nodes).
    private static let batchedAttributes = [
        kAXRoleAttribute as String, kAXChildrenAttribute as String,
        kAXValueAttribute as String, kAXTitleAttribute as String,
        kAXPositionAttribute as String, kAXSizeAttribute as String,
    ]

    /// Walks the AX window matching `window` and returns display-normalized
    /// text blocks in the exact shape the OCR path produces, or nil when
    /// the tree yields too little to trust.
    static func blocks(for window: SCWindow, display: SCDisplay) -> [ScreenSnapshot.TextBlock]? {
        guard isAvailable(), let pid = window.owningApplication?.processID else { return nil }
        let app = AXUIElementCreateApplication(pid)
        // A wedged target app must cost at most one bounded call, never the
        // system default multi-second IPC timeout.
        AXUIElementSetMessagingTimeout(app, 0.05)
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
            let attributes = batched(element)
            let role = attributes[kAXRoleAttribute as String] as? String ?? ""
            if textRoles.contains(role) {
                let text = (attributes[kAXValueAttribute as String] as? String)
                    ?? (attributes[kAXTitleAttribute as String] as? String) ?? ""
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let frame = frame(
                       position: attributes[kAXPositionAttribute as String],
                       size: attributes[kAXSizeAttribute as String]
                   ) {
                    collected.append((text, frame))
                }
            }
            if prunedRoles.contains(role) { continue }
            if let children = attributes[kAXChildrenAttribute as String] as? [AXUIElement] {
                queue.append(contentsOf: children)
            }
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
                let attrs = batched(candidate)
                if let f = self.frame(
                       position: attrs[kAXPositionAttribute as String],
                       size: attrs[kAXSizeAttribute as String]
                   ),
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

    private static func batched(_ element: AXUIElement) -> [String: CFTypeRef] {
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(
            element, batchedAttributes as CFArray, AXCopyMultipleAttributeOptions(), &values
        ) == .success, let list = values as? [CFTypeRef] else { return [:] }
        var out: [String: CFTypeRef] = [:]
        for (index, name) in batchedAttributes.enumerated() where index < list.count {
            let value = list[index]
            // Missing attributes come back as AXValue error placeholders.
            if CFGetTypeID(value) == AXValueGetTypeID(), AXValueGetType(value as! AXValue) == .axError { continue }
            out[name] = value
        }
        return out
    }

    private static func frame(position: CFTypeRef?, size: CFTypeRef?) -> CGRect? {
        guard let position, CFGetTypeID(position) == AXValueGetTypeID(),
              let size, CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var box = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &box) else { return nil }
        return CGRect(origin: point, size: box)
    }
}
