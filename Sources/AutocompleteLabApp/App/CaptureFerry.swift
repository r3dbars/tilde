import Foundation

/// Ferries capture written locally by the keyboard into the owner's iCloud
/// folder. The keyboard writes only to its permission-free local directory
/// (its iCloud grant dies on every re-sign); this app holds the user's
/// actual iCloud consent and is always running, so syncing is its job.
///
/// Mechanism: byte-offset tailing. For each file in the local usage
/// directory, remember how many bytes have been ferried (app defaults) and
/// append only the new bytes to the same-named file in iCloud. Append-only
/// JSONL on both ends makes this safe to interrupt and resume.
final class CaptureFerry: @unchecked Sendable {

    static let shared = CaptureFerry()

    private let localDirectory =
        NSString(string: "~/Library/Application Support/SteadyType/usage").expandingTildeInPath
    private let icloudDirectory =
        NSString(string: "~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage").expandingTildeInPath

    private let queue = DispatchQueue(label: "bar.r3d.steadytype.capture-ferry", qos: .utility)
    private var timer: DispatchSourceTimer?

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 15, repeating: 60)
        t.setEventHandler { [weak self] in self?.ferryOnce() }
        t.resume()
        timer = t
    }

    private func offsetKey(_ name: String) -> String { "ferry.offset.\(name)" }

    private func ferryOnce() {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: localDirectory), !names.isEmpty else { return }
        guard fm.fileExists(atPath: NSString(string: "~/Library/Mobile Documents/com~apple~CloudDocs")
            .expandingTildeInPath) else { return }
        try? fm.createDirectory(atPath: icloudDirectory, withIntermediateDirectories: true)

        for name in names where name.hasSuffix(".jsonl") {
            let localPath = localDirectory + "/" + name
            let remotePath = icloudDirectory + "/" + name
            guard let attrs = try? fm.attributesOfItem(atPath: localPath),
                  let size = attrs[.size] as? UInt64 else { continue }
            var offset = UInt64(max(0, UserDefaults.standard.integer(forKey: offsetKey(name))))
            if offset > size { offset = 0 } // local file was reset/rotated
            guard size > offset else { continue }

            guard let reader = FileHandle(forReadingAtPath: localPath) else { continue }
            defer { try? reader.close() }
            guard (try? reader.seek(toOffset: offset)) != nil,
                  let data = try? reader.readToEnd(), !data.isEmpty else { continue }

            if !fm.fileExists(atPath: remotePath) {
                fm.createFile(atPath: remotePath, contents: nil)
            }
            guard let writer = FileHandle(forWritingAtPath: remotePath) else { continue }
            defer { try? writer.close() }
            guard (try? writer.seekToEnd()) != nil,
                  (try? writer.write(contentsOf: data)) != nil else { continue }

            UserDefaults.standard.set(Int(offset) + data.count, forKey: offsetKey(name))
        }
    }
}
