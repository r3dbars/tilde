import Foundation
import AutocompleteLabCore

/// Builds and owns the local, derived index used for personal writing suggestions.
/// Journal reads and index writes stay off the main thread; callers read an atomic snapshot.
final class PersonalWritingMemoryIndexer: @unchecked Sendable {
    static let shared = PersonalWritingMemoryIndexer(
        personalCaptureFolderURL: FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/SteadyType/Personal Capture")
    )

    private let personalCaptureFolderURL: URL
    private let indexFileURL: URL
    private let queue = DispatchQueue(label: "app.steadytype.personal-writing-memory-index")
    private let snapshotLock = NSLock()
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var memorySnapshot: PersonalWritingMemory?
    private var memoryRevision: UInt64 = 0

    init(
        personalCaptureFolderURL: URL,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.personalCaptureFolderURL = personalCaptureFolderURL
        self.indexFileURL = personalCaptureFolderURL
            .appendingPathComponent("Index/personal-writing-memory.json")
        self.calendar = calendar
        self.now = now
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? Data(contentsOf: indexFileURL),
           let memory = try? decoder.decode(PersonalWritingMemory.self, from: data),
           memory.schemaVersion == PersonalWritingMemory.currentSchemaVersion {
            memorySnapshot = memory
            memoryRevision = 1
        }
    }

    var path: String {
        indexFileURL.path
    }

    func currentMemory() -> PersonalWritingMemory? {
        snapshotLock.withLock { memorySnapshot }
    }

    func currentSnapshot() -> (memory: PersonalWritingMemory?, revision: UInt64) {
        snapshotLock.withLock { (memorySnapshot, memoryRevision) }
    }

    func rebuild() {
        queue.async { [weak self] in
            self?.rebuildNow()
        }
    }

    /// Test/proof seam. Production uses `rebuild()` so journal I/O never blocks the UI.
    func rebuildAndWait() {
        queue.sync { [weak self] in
            self?.rebuildNow()
        }
    }

    func deleteAll() {
        queue.sync { [self] in
            try? FileManager.default.removeItem(at: indexFileURL.deletingLastPathComponent())
            snapshotLock.withLock {
                memorySnapshot = nil
                memoryRevision &+= 1
            }
        }
    }

    func waitForPendingWork() {
        queue.sync {}
    }

    private func rebuildNow() {
        let buildDate = now()
        let entries = allJournalEntries()
        let memory = PersonalWritingMemoryBuilder().build(entries: entries, now: buildDate)

        do {
            let directoryURL = indexFileURL.deletingLastPathComponent()
            guard SecureLocalStorage.createDirectory(at: directoryURL) else {
                throw CocoaError(.fileWriteNoPermission)
            }
            try encoder.encode(memory).write(to: indexFileURL, options: .atomic)
            SecureLocalStorage.restrictFile(at: indexFileURL)
            snapshotLock.withLock {
                memorySnapshot = memory
                memoryRevision &+= 1
            }
        } catch {
            DiagnosticsLog.shared.record(
                "personal-writing-memory-index-failed",
                metadata: [
                    "reason": DiagnosticValueRedactor.stringSummary(
                        length: String(describing: error).count
                    )
                ]
            )
        }
    }

    private func allJournalEntries() -> [PersonalCaptureJournalEntry] {
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: personalCaptureFolderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []).filter {
            $0.pathExtension.lowercased() == "md"
                && $0.deletingPathExtension().lastPathComponent.range(
                    of: #"^\d{4}-\d{2}-\d{2}$"#,
                    options: .regularExpression
                ) != nil
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        return files.flatMap { fileURL -> [PersonalCaptureJournalEntry] in
            let dayString = fileURL.deletingPathExtension().lastPathComponent
            guard let markdown = try? String(contentsOf: fileURL, encoding: .utf8) else {
                return []
            }
            return PersonalCaptureJournalParser().entries(
                inDailyMarkdown: markdown,
                dayString: dayString
            )
        }
    }

}
