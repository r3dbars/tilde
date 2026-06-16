import ApplicationServices
import CoreGraphics
import Testing
@testable import AutocompleteLabApp

/// Locks the crash-safety contract for the Accessibility boundary. The focused-text and caret
/// reads used to force-cast raw `CFTypeRef` attribute values to `AXUIElement` / `AXValue`,
/// which terminates the whole menu-bar process if a target app returns an unexpected CF type.
/// The reads now route through these guards, which must degrade to nil (→ "no suggestion")
/// rather than crash.
@Suite("Accessibility client AX type guards")
struct AccessibilityClientAXTypeGuardTests {
    @Test("A non-AXValue CF value is rejected instead of force-cast")
    func rejectsNonAXValue() {
        let notAnAXValue: CFTypeRef = "not an ax value" as CFString
        #expect(AccessibilityClient.axValue(from: notAnAXValue) == nil)
    }

    @Test("A real AXValue is accepted")
    func acceptsAXValue() {
        var point = CGPoint(x: 1, y: 2)
        let value = AXValueCreate(.cgPoint, &point)!
        #expect(AccessibilityClient.axValue(from: value) != nil)
    }

    @Test("A non-AXUIElement CF value is rejected instead of force-cast")
    func rejectsNonAXUIElement() {
        let notAnElement: CFTypeRef = "not an element" as CFString
        #expect(AccessibilityClient.axUIElement(from: notAnElement) == nil)
    }

    @Test("An AXUIElement is accepted")
    func acceptsAXUIElement() {
        let systemWide: CFTypeRef = AXUIElementCreateSystemWide()
        #expect(AccessibilityClient.axUIElement(from: systemWide) != nil)
    }
}
