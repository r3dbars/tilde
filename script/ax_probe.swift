// Accessibility-API probe: reads the frontmost app's on-screen TEXT directly
// via AXUIElement — the "read it, don't photograph it" alternative to OCR.
// Perfect text, no ~200ms screenshot+OCR, when the app exposes it.
//   swift script/ax_probe.swift            (reads the current frontmost app)
// Needs Accessibility permission for the running process (Terminal/IDE):
//   System Settings > Privacy & Security > Accessibility.
import Foundation
import AppKit
import ApplicationServices

func str(_ el: AXUIElement, _ attr: String) -> String? {
    var v: CFTypeRef?
    if AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success,
       let s = v as? String, !s.isEmpty { return s }
    return nil
}

func children(_ el: AXUIElement) -> [AXUIElement] {
    var v: CFTypeRef?
    if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &v) == .success,
       let arr = v as? [AXUIElement] { return arr }
    return []
}

// Collect readable text from the tree: text fields/areas' values + static text.
var lines: [String] = []
var roleCounts: [String: Int] = [:]
var visited = 0
func walk(_ el: AXUIElement, depth: Int) {
    if visited > 4000 || depth > 40 { return }
    visited += 1
    let role = str(el, kAXRoleAttribute) ?? "?"
    roleCounts[role, default: 0] += 1
    // The two attributes that carry real content:
    if let val = str(el, kAXValueAttribute), val.count > 1 { lines.append(val) }
    else if let t = str(el, kAXTitleAttribute), t.count > 1,
            role.contains("StaticText") || role.contains("Text") { lines.append(t) }
    for c in children(el) { walk(c, depth: depth + 1) }
}

guard AXIsProcessTrusted() else {
    FileHandle.standardError.write("NOT TRUSTED: grant Accessibility to this process in System Settings > Privacy & Security > Accessibility, then re-run.\n".data(using: .utf8)!)
    exit(5)
}

guard let app = NSWorkspace.shared.frontmostApplication else { exit(3) }
let appEl = AXUIElementCreateApplication(app.processIdentifier)
let t0 = Date()
walk(appEl, depth: 0)
let ms = Int(Date().timeIntervalSince(t0) * 1000)

let text = lines.joined(separator: "\n")
print("app: \(app.localizedName ?? "?")  elements: \(visited)  read: \(ms)ms  chars: \(text.count)")
let topRoles = roleCounts.sorted { $0.value > $1.value }.prefix(8)
    .map { "\($0.key):\($0.value)" }.joined(separator: " ")
print("roles: \(topRoles)")
print("---- first 800 chars of directly-read text ----")
print(String(text.prefix(800)))
