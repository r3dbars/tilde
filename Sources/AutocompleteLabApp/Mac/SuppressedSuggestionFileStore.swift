import Foundation
import AutocompleteLabCore

final class SuppressedSuggestionFileStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.suppressed-suggestions")
    private let fileURL: URL
    private let secret: Data
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cachedStore: SuppressedSuggestionStore?

    init(
        fileURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AutocompleteLab/suppressed-suggestions.json"),
        secret: Data
    ) {
        self.fileURL = fileURL
        self.secret = secret
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var path: String {
        fileURL.path
    }

    func match(
        _ text: String,
        mode: CompletionRequestMode,
        scope: String
    ) -> SuppressedSuggestionEntry? {
        queue.sync {
            loadStore().match(
                text,
                mode: mode,
                scope: scope,
                secret: secret
            )
        }
    }

    @discardableResult
    func suppressExact(
        _ text: String,
        mode: CompletionRequestMode,
        scope: String,
        source: String = "menu"
    ) -> SuppressedSuggestionEntry? {
        queue.sync {
            var store = loadStore()
            guard let entry = store.suppressExact(
                text,
                mode: mode,
                scope: scope,
                secret: secret,
                source: source
            ) else {
                return nil
            }

            saveStore(store)
            return entry
        }
    }

    func deleteAll() {
        queue.sync {
            cachedStore = SuppressedSuggestionStore()
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func loadStore() -> SuppressedSuggestionStore {
        if let cachedStore {
            return cachedStore
        }

        let store: SuppressedSuggestionStore
        if let data = try? Data(contentsOf: fileURL),
           let entries = try? decoder.decode([SuppressedSuggestionEntry].self, from: data) {
            store = SuppressedSuggestionStore(entries: entries)
        } else {
            store = SuppressedSuggestionStore()
        }

        cachedStore = store
        return store
    }

    private func saveStore(_ store: SuppressedSuggestionStore) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encoder.encode(store.entries).write(to: fileURL, options: .atomic)
            cachedStore = store
        } catch {
            DiagnosticsLog.shared.record(
                "suppressed-suggestion-store-save-failed",
                metadata: ["reason": error.localizedDescription]
            )
        }
    }
}
