// Targeted Accessibility probe: reads ONLY the focused element's container
// (its parent, walking up a few levels to find a real "surrounding
// conversation" container) instead of the whole app tree.
//
// The whole-tree walk in ax_probe.swift takes ~800ms on a chat-heavy app
// because it visits thousands of elements. Real usage only needs "the
// message being replied to" — a handful of elements near the caret. This
// probe starts at kAXFocusedUIElementAttribute, climbs to a small container,
// and walks a tightly capped local subtree.
//
//   swiftc -O script/ax_probe_targeted.swift -o /tmp/ax_probe_targeted
//   /tmp/ax_probe_targeted
//
// Needs Accessibility permission for the running process:
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

func element(_ el: AXUIElement, _ attr: String) -> AXUIElement? {
    var v: CFTypeRef?
    if AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success {
        // AXUIElement is a CF type; force-cast via unsafe bit cast guard.
        if CFGetTypeID(v) == AXUIElementGetTypeID() {
            return (v as! AXUIElement)
        }
    }
    return nil
}

func children(_ el: AXUIElement) -> [AXUIElement] {
    var v: CFTypeRef?
    if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &v) == .success,
       let arr = v as? [AXUIElement] { return arr }
    return []
}

func role(_ el: AXUIElement) -> String {
    return str(el, kAXRoleAttribute) ?? "?"
}

// Tight caps: this is meant to answer "what's near the caret", not map the app.
let maxElements = 150
let maxDepth = 6
let maxClimb = 5

var lines: [String] = []
var roleCounts: [String: Int] = [:]
var visited = 0

func walk(_ el: AXUIElement, depth: Int) {
    if visited >= maxElements || depth > maxDepth { return }
    visited += 1
    let r = role(el)
    roleCounts[r, default: 0] += 1
    if let val = str(el, kAXValueAttribute), val.count > 1 { lines.append(val) }
    else if let t = str(el, kAXTitleAttribute), t.count > 1,
            r.contains("StaticText") || r.contains("Text") { lines.append(t) }
    else if let d = str(el, kAXDescriptionAttribute), d.count > 1,
            r.contains("StaticText") || r.contains("Text") { lines.append(d) }
    for c in children(el) {
        if visited >= maxElements { return }
        walk(c, depth: depth + 1)
    }
}

guard AXIsProcessTrusted() else {
    FileHandle.standardError.write("NOT TRUSTED: grant Accessibility to this process (System Settings > Privacy & Security > Accessibility), then re-run.\n".data(using: .utf8)!)
    exit(5)
}

guard let app = NSWorkspace.shared.frontmostApplication else {
    FileHandle.standardError.write("No frontmost app.\n".data(using: .utf8)!)
    exit(3)
}

let appEl = AXUIElementCreateApplication(app.processIdentifier)

let t0 = Date()

// 1. Focused UI element (the caret / active field).
guard let focused = element(appEl, kAXFocusedUIElementAttribute) else {
    let ms = Int(Date().timeIntervalSince(t0) * 1000)
    print("app: \(app.localizedName ?? "?")  read: \(ms)ms")
    print("No focused UI element exposed by this app via AX. (App may not support AX focus, or nothing is focused.)")
    exit(4)
}
let focusedRole = role(focused)
let focusedValue = str(focused, kAXValueAttribute) ?? str(focused, kAXTitleAttribute) ?? ""

// 2. Climb from the focused element toward a container that looks like it
// holds multiple siblings (the surrounding conversation), rather than
// hardcoding one parent hop — chat UIs vary in how many wrapper views they
// nest between a text field and the message list.
var container = focused
var climbed = 0
while climbed < maxClimb {
    guard let parent = element(container, kAXParentAttribute) else { break }
    container = parent
    climbed += 1
    // Stop climbing once we find a container with more than one child —
    // that's likely the list/stack of messages, not another single wrapper.
    if children(container).count > 1 { break }
}
let containerRole = role(container)

// 3. Walk the local subtree only (container + its children/siblings),
// tightly capped — this is the "nearby conversation", not the whole app.
walk(container, depth: 0)

let ms = Int(Date().timeIntervalSince(t0) * 1000)
let text = lines.joined(separator: "\n")

print("app: \(app.localizedName ?? "?")  elements: \(visited)  climbed: \(climbed)  read: \(ms)ms  chars: \(text.count)")
print("focused element role: \(focusedRole)  value(prefix): \(String(focusedValue.prefix(80)))")
print("container role: \(containerRole)")
let topRoles = roleCounts.sorted { $0.value > $1.value }.prefix(8)
    .map { "\($0.key):\($0.value)" }.joined(separator: " ")
print("roles: \(topRoles)")
print("---- text found near focus (first 1200 chars) ----")
print(String(text.prefix(1200)))
