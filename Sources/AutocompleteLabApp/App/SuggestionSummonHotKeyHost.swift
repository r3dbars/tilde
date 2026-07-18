import Foundation

/// Owns the Carbon registration for the global summon shortcut.
///
/// Suggestion policy remains in AppDelegate; this host only manages the
/// native hotkey resource and forwards its action.
@MainActor
final class SuggestionSummonHotKeyHost {
    private let hotKey: SuggestionSummonHotKey

    var descriptor: SuggestionSummonHotKeyDescriptor {
        hotKey.descriptor
    }

    init(handler: @escaping SuggestionSummonHotKey.Handler) {
        hotKey = SuggestionSummonHotKey(handler: handler)
    }

    @discardableResult
    func start() -> Bool {
        hotKey.start()
    }

    func stop() {
        hotKey.stop()
    }
}
