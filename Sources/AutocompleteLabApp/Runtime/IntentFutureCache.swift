import AutocompleteLabCore
import Foundation

/// Process-local, memory-only cache for the semantic read of the current scene.
/// Candidate/scene text is never logged or persisted; a scene change replaces
/// the prior immediately. This is the first serving primitive for doing work
/// before the next visible ghost instead of rebuilding intent from zero.
final class IntentFutureCache: @unchecked Sendable {
    static let shared = IntentFutureCache()

    private let lock = NSLock()
    private var cachedScene: ScreenScene.Scene?
    private var cachedPrior: [IntentFuture] = []

    func futures(scene: ScreenScene.Scene?, textBeforeCursor: String) -> [IntentFuture] {
        guard let scene else {
            return IntentFuturesPlanner.futures(scene: nil, textBeforeCursor: textBeforeCursor)
        }

        let prior: [IntentFuture] = lock.withLock {
            if cachedScene != scene {
                cachedScene = scene
                cachedPrior = IntentFuturesPlanner.futures(scene: scene, textBeforeCursor: "")
            }
            return cachedPrior
        }
        let live = IntentFuturesPlanner.futures(scene: scene, textBeforeCursor: textBeforeCursor)
        return IntentFutureFusion.fuse(prior: prior, live: live)
    }

    func reset() {
        lock.withLock {
            cachedScene = nil
            cachedPrior = []
        }
    }
}
