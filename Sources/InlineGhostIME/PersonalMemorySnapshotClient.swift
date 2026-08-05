import AutocompleteLabCore
import Foundation

/// Lock-protected reader for the app-built personal-memory snapshot. File work
/// stays off the keystroke path; lookups are dictionary reads from an immutable
/// in-memory value.
final class PersonalMemorySnapshotClient {
    static let shared = PersonalMemorySnapshotClient()

    private static let snapshotURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Tilde", isDirectory: true)
        .appendingPathComponent("personal-memory.json")

    private let queue = DispatchQueue(label: "bar.r3d.inputmethod.personal-memory", qos: .utility)
    private let lock = NSLock()
    private var snapshot: PersonalAutocompleteMemory = .empty
    private var nextRefresh = Date.distantPast

    private init() {
        refreshIfNeeded(force: true)
    }

    func wordCompletion(for prefix: String) -> String? {
        refreshIfNeeded()
        lock.lock()
        let current = snapshot
        lock.unlock()
        return current.wordCompletion(for: prefix)
    }

    private func refreshIfNeeded(force: Bool = false) {
        lock.lock()
        let shouldRefresh = force || Date() >= nextRefresh
        if shouldRefresh { nextRefresh = Date().addingTimeInterval(30) }
        lock.unlock()
        guard shouldRefresh else { return }

        queue.async { [weak self] in
            guard let self,
                  let data = try? Data(contentsOf: Self.snapshotURL),
                  let decoded = try? JSONDecoder().decode(PersonalAutocompleteMemory.self, from: data),
                  decoded.version == PersonalAutocompleteMemory.currentVersion else {
                return
            }
            self.lock.lock()
            self.snapshot = decoded
            self.lock.unlock()
        }
    }
}
