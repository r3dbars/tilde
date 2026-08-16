import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Window attribution")
struct WindowAttributionTests {
    private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> NormalizedDisplayRect {
        NormalizedDisplayRect(x: x, y: y, width: w, height: h)
    }

    @Test("A block inside a single window attributes to it")
    func singleWindowMatch() {
        let editor = WindowAttribution.WindowInfo(
            bundleIdentifier: "com.apple.TextEdit",
            title: "Untitled",
            frame: rect(0, 0, 0.5, 1.0)
        )
        let block = rect(0.1, 0.1, 0.1, 0.05)
        let match = WindowAttribution.attribute(boundingBox: block, frontToBackWindows: [editor])
        #expect(match?.bundleIdentifier == "com.apple.TextEdit")
    }

    @Test("Overlapping windows: the frontmost (first) one wins")
    func overlapPrefersFrontmost() {
        let front = WindowAttribution.WindowInfo(
            bundleIdentifier: "com.apple.Notes",
            title: "Note",
            frame: rect(0, 0, 0.6, 0.6)
        )
        let back = WindowAttribution.WindowInfo(
            bundleIdentifier: "com.apple.Safari",
            title: "Page",
            frame: rect(0, 0, 1.0, 1.0)
        )
        // Both frames contain this block's center; front-to-back order says Notes wins.
        let block = rect(0.2, 0.2, 0.1, 0.1)
        let match = WindowAttribution.attribute(boundingBox: block, frontToBackWindows: [front, back])
        #expect(match?.bundleIdentifier == "com.apple.Notes")

        // Reversing the (still valid) front-to-back order flips the winner —
        // this proves attribution trusts caller-supplied order, it doesn't
        // infer it.
        let reversedMatch = WindowAttribution.attribute(boundingBox: block, frontToBackWindows: [back, front])
        #expect(reversedMatch?.bundleIdentifier == "com.apple.Safari")
    }

    @Test("A block outside every window frame attributes to nothing")
    func noMatchReturnsNil() {
        let editor = WindowAttribution.WindowInfo(
            bundleIdentifier: "com.apple.TextEdit",
            title: "Untitled",
            frame: rect(0, 0, 0.3, 0.3)
        )
        let block = rect(0.8, 0.8, 0.05, 0.05)
        #expect(WindowAttribution.attribute(boundingBox: block, frontToBackWindows: [editor]) == nil)
    }

    @Test("Attribution keys off the block's center, not its corner")
    func usesCenterPoint() {
        // Block straddles the window's right edge; its top-left corner is
        // outside but its center is inside.
        let window = WindowAttribution.WindowInfo(
            bundleIdentifier: "com.example.app",
            title: nil,
            frame: rect(0.0, 0.0, 0.5, 0.5)
        )
        let block = rect(0.4, 0.2, 0.2, 0.05) // spans 0.4...0.6, center at 0.5 — on the boundary, inclusive
        #expect(WindowAttribution.attribute(boundingBox: block, frontToBackWindows: [window])?.bundleIdentifier
            == "com.example.app")
    }

    @Test("Empty window list attributes to nothing")
    func emptyWindowListReturnsNil() {
        #expect(WindowAttribution.attribute(boundingBox: rect(0, 0, 1, 1), frontToBackWindows: []) == nil)
    }
}
