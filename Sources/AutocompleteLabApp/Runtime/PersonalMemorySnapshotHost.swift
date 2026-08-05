import AutocompleteLabCore
import Foundation

/// Builds a compact cross-session memory from the owner's opted-in Tilde usage
/// logs. Raw events are read on a utility queue; the keyboard consumes only the
/// qualified snapshot from owner-only Application Support.
final class PersonalMemorySnapshotHost: @unchecked Sendable {
    static let snapshotURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Tilde", isDirectory: true)
        .appendingPathComponent("personal-memory.json")

    static let seedURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(
            "Library/Mobile Documents/com~apple~CloudDocs/Tilde-usage",
            isDirectory: true
        )
        .appendingPathComponent("personal-memory-seed.json")

    private let queue = DispatchQueue(label: "bar.r3d.tilde.personal-memory", qos: .utility)
    private let lock = NSLock()
    private let learningEnabled: @Sendable () -> Bool
    private let logURLs: @Sendable () -> [URL]
    private let seed: URL
    private let output: URL
    private var snapshot: PersonalAutocompleteMemory = .empty
    private var timer: DispatchSourceTimer?

    init(
        learningEnabled: @escaping @Sendable () -> Bool = {
            UserDefaults(suiteName: TildeSettings.keyboardSuiteName)?
                .bool(forKey: TildeSettings.KeyboardKey.learning.rawValue) ?? false
        },
        logURLs: @escaping @Sendable () -> [URL] = PersonalMemorySnapshotHost.usageLogURLs,
        seedURL: URL = PersonalMemorySnapshotHost.seedURL,
        outputURL: URL = PersonalMemorySnapshotHost.snapshotURL
    ) {
        self.learningEnabled = learningEnabled
        self.logURLs = logURLs
        self.seed = seedURL
        self.output = outputURL
        if let existing = Self.decode(from: outputURL) {
            snapshot = existing
        }
    }

    func start() {
        queue.async { [weak self] in self?.rebuild() }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in self?.rebuild() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func refreshNow() {
        queue.async { [weak self] in self?.rebuild() }
    }

    func examples(after context: String, limit: Int = 2) -> [PersonalWritingExample] {
        lock.lock()
        let current = snapshot
        lock.unlock()
        return current.examples(after: context, limit: limit)
    }

    func counts() -> (words: Int, phrases: Int) {
        lock.lock()
        let current = snapshot
        lock.unlock()
        return (current.wordPrefixes.count, current.phraseBuckets.count)
    }

    private func rebuild() {
        guard learningEnabled() else {
            setSnapshot(.empty)
            return
        }

        let seeded = Self.decode(from: seed) ?? .empty
        let live = Self.liveMemory(from: logURLs())
        let merged = seeded.merging(live)
        setSnapshot(merged)
        persist(merged)
        DiagnosticsLog.shared.record("personal-memory-ready", metadata: [
            "wordPrefixes": String(merged.wordPrefixes.count),
            "phraseBuckets": String(merged.phraseBuckets.count),
            "sourceObservations": String(merged.sourceObservations),
            "seedAttached": String(seeded != .empty),
        ])
    }

    private func setSnapshot(_ value: PersonalAutocompleteMemory) {
        lock.lock()
        snapshot = value
        lock.unlock()
    }

    private func persist(_ value: PersonalAutocompleteMemory) {
        let directory = output.deletingLastPathComponent()
        guard SecureLocalStorage.createDirectory(at: directory),
              let data = try? JSONEncoder().encode(value),
              (try? data.write(to: output, options: .atomic)) != nil else {
            DiagnosticsLog.shared.record("personal-memory-write-failed", metadata: [:])
            return
        }
        SecureLocalStorage.restrictFile(at: output)
    }

    static func liveMemory(from urls: [URL]) -> PersonalAutocompleteMemory {
        var builder = PersonalAutocompleteMemoryBuilder()
        var seenContexts: Set<String> = []

        for url in urls {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            contents.enumerateLines { line, _ in
                guard let data = line.data(using: .utf8),
                      let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return }

                let context = event["context"] as? String ?? ""
                if !context.isEmpty, seenContexts.insert(context).inserted {
                    builder.observeVocabulary(context)
                }

                let kind = event["event"] as? String
                let continuation: String?
                switch kind {
                case "accept_word", "accept_all":
                    continuation = event["accepted"] as? String
                case "typed_instead":
                    continuation = event["typed"] as? String
                default:
                    continuation = nil
                }
                if let continuation, !continuation.isEmpty {
                    builder.observeOutcome(context: context, continuation: continuation)
                }
            }
        }
        return builder.snapshot()
    }

    private static func decode(from url: URL) -> PersonalAutocompleteMemory? {
        guard let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(PersonalAutocompleteMemory.self, from: data),
              value.version == PersonalAutocompleteMemory.currentVersion else {
            return nil
        }
        return value
    }

    private static func usageLogURLs() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folders = [
            home.appendingPathComponent(
                "Library/Mobile Documents/com~apple~CloudDocs/Tilde-usage",
                isDirectory: true
            ),
            home.appendingPathComponent("Library/Application Support/Tilde/usage", isDirectory: true),
        ]
        return folders.flatMap { folder in
            (try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            ))?.filter {
                $0.lastPathComponent.hasPrefix("ghost_events") && $0.pathExtension == "jsonl"
            } ?? []
        }
    }
}
