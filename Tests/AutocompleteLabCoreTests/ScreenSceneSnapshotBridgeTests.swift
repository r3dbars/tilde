import Foundation
import Testing
@testable import AutocompleteLabCore

/// Screen Memory plan Phase 2 PR 2b: `ScreenScene.freshScene` and
/// `ScreenScene.classify(snapshot:...)` — the bridge from Phase 1's
/// memory-only `ScreenSnapshot` into Phase 2's classifier, plus the
/// staleness gate the live completion path relies on to never await a
/// capture.
@Suite("Screen scene snapshot bridge")
struct ScreenSceneSnapshotBridgeTests {
    private let slack = "com.tinyspeck.slackmacgap"
    private let fullDisplay = NormalizedDisplayRect(x: 0, y: 0, width: 1, height: 1)
    private let referenceMoment = Date(timeIntervalSince1970: 1_700_000_000)

    private func textBlock(
        _ text: String,
        x: Double,
        y: Double,
        width: Double = 0.35,
        window: String? = nil
    ) -> ScreenSnapshot.TextBlock {
        ScreenSnapshot.TextBlock(
            text: text,
            boundingBox: NormalizedDisplayRect(x: x, y: y, width: width, height: 0.05),
            windowOwnerBundleIdentifier: window,
            windowTitle: nil,
            windowFrame: window != nil ? fullDisplay : nil
        )
    }

    private func snapshot(capturedAt: Date, blocks: [ScreenSnapshot.TextBlock]) -> ScreenSnapshot {
        ScreenSnapshot(capturedAt: capturedAt, displayID: 1, blocks: blocks)
    }

    // MARK: - Conversion correctness

    @Test("classify(snapshot:) converts blocks field-for-field and reaches the same verdict as OCRBlock classification")
    func snapshotClassificationMatchesDirectOCRBlockClassification() {
        let blocks = [
            textBlock("hey are you around today", x: 0.05, y: 0.30, window: slack),
            textBlock("yeah free after 3pm works", x: 0.55, y: 0.60, window: slack),
        ]
        let snap = snapshot(capturedAt: referenceMoment, blocks: blocks)

        let viaSnapshot = ScreenScene.classify(snapshot: snap, frontmostBundleID: slack, fieldText: "")
        let viaBlocks = ScreenScene.classify(
            blocks: blocks.map(ScreenScene.OCRBlock.init(snapshotBlock:)),
            frontmostBundleID: slack,
            fieldText: ""
        )
        #expect(viaSnapshot == viaBlocks)
        #expect(viaSnapshot.mode == .replying)
        #expect(viaSnapshot.conversationTurns.count == 2)
    }

    @Test("A block with no window attribution converts to a nil windowFrame, not the full display")
    func unattributedBlockHasNilWindowFrame() {
        let raw = ScreenSnapshot.TextBlock(
            text: "stray text",
            boundingBox: NormalizedDisplayRect(x: 0.1, y: 0.1, width: 0.3, height: 0.05)
        )
        let converted = ScreenScene.OCRBlock(snapshotBlock: raw)
        #expect(converted.windowOwnerBundleID == nil)
        #expect(converted.windowFrame == nil)
    }

    // MARK: - Staleness gate

    @Test("A snapshot within the 20s cap is used")
    func freshSnapshotWithinCapIsUsed() {
        let blocks = [
            textBlock("hey are you around today", x: 0.05, y: 0.30, window: slack),
            textBlock("yeah free after 3pm works", x: 0.55, y: 0.60, window: slack),
        ]
        let snap = snapshot(capturedAt: referenceMoment, blocks: blocks)
        let now = referenceMoment.addingTimeInterval(19)
        let scene = ScreenScene.freshScene(from: snap, now: now, frontmostBundleID: slack, fieldText: "")
        #expect(scene?.mode == .replying)
    }

    @Test("Exactly at the 20s cap is still fresh (inclusive boundary)")
    func exactlyAtCapIsStillFresh() {
        let blocks = [
            textBlock("hey are you around today", x: 0.05, y: 0.30, window: slack),
            textBlock("yeah free after 3pm works", x: 0.55, y: 0.60, window: slack),
        ]
        let snap = snapshot(capturedAt: referenceMoment, blocks: blocks)
        let now = referenceMoment.addingTimeInterval(ScreenScene.defaultStalenessCapSeconds)
        let scene = ScreenScene.freshScene(from: snap, now: now, frontmostBundleID: slack, fieldText: "")
        #expect(scene != nil)
    }

    @Test("A snapshot older than the 20s cap is dropped: exactly today's (nil) behavior")
    func staleSnapshotIsDropped() {
        let blocks = [
            textBlock("hey are you around today", x: 0.05, y: 0.30, window: slack),
            textBlock("yeah free after 3pm works", x: 0.55, y: 0.60, window: slack),
        ]
        let snap = snapshot(capturedAt: referenceMoment, blocks: blocks)
        let now = referenceMoment.addingTimeInterval(20.001)
        let scene = ScreenScene.freshScene(from: snap, now: now, frontmostBundleID: slack, fieldText: "")
        #expect(scene == nil)
    }

    @Test("A snapshot stamped in the future is dropped fail-closed, not treated as instantly fresh")
    func futureCapturedAtIsDroppedFailClosed() {
        let blocks = [textBlock("hey are you around today", x: 0.05, y: 0.30, window: slack)]
        let snap = snapshot(capturedAt: referenceMoment.addingTimeInterval(5), blocks: blocks)
        let scene = ScreenScene.freshScene(from: snap, now: referenceMoment, frontmostBundleID: slack, fieldText: "")
        #expect(scene == nil)
    }

    @Test("No snapshot at all is exactly today's (nil) behavior")
    func absentSnapshotYieldsNil() {
        let scene = ScreenScene.freshScene(
            from: nil, now: referenceMoment, frontmostBundleID: slack, fieldText: "anything"
        )
        #expect(scene == nil)
    }

    @Test("A custom staleness cap is honored")
    func customStalenessCapIsHonored() {
        let blocks = [
            textBlock("hey are you around today", x: 0.05, y: 0.30, window: slack),
            textBlock("yeah free after 3pm works", x: 0.55, y: 0.60, window: slack),
        ]
        let snap = snapshot(capturedAt: referenceMoment, blocks: blocks)
        let now = referenceMoment.addingTimeInterval(3)
        #expect(ScreenScene.freshScene(
            from: snap, now: now, stalenessCapSeconds: 2, frontmostBundleID: slack, fieldText: ""
        ) == nil)
        #expect(ScreenScene.freshScene(
            from: snap, now: now, stalenessCapSeconds: 10, frontmostBundleID: slack, fieldText: ""
        ) != nil)
    }

    // MARK: - Dedupe survives the bridge end to end

    @Test("A fresh snapshot whose only block duplicates the field text yields no context, not a duplicate")
    func dedupeSurvivesTheFullBridge() {
        let blocks = [textBlock("hey are you around today", x: 0.05, y: 0.30, window: slack)]
        let snap = snapshot(capturedAt: referenceMoment, blocks: blocks)
        let scene = ScreenScene.freshScene(
            from: snap,
            now: referenceMoment.addingTimeInterval(1),
            frontmostBundleID: slack,
            fieldText: "hey are you around today"
        )
        // Only one bubble worth of usable text and it's deduped away, so
        // there aren't 2 distinct turns to form a message list -- composing.
        #expect(scene?.mode == .composing)
        #expect(scene?.conversationTurns.isEmpty != false)
    }
}
