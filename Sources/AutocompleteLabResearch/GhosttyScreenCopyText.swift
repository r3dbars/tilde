import Foundation

struct GhosttyScreenCopyText: Equatable {
    let text: String
    let transport: String

    static func read(
        from pasteboardText: String,
        fileManager: FileManager = .default
    ) -> GhosttyScreenCopyText {
        let trimmed = pasteboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\n"), trimmed.hasPrefix("/") else {
            return GhosttyScreenCopyText(text: pasteboardText, transport: "pasteboardText")
        }

        let url = URL(fileURLWithPath: trimmed).standardizedFileURL
        guard filePathAllowed(url.path) else {
            return GhosttyScreenCopyText(text: pasteboardText, transport: "filePathRejected")
        }
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType,
              type == .typeRegular else {
            return GhosttyScreenCopyText(text: pasteboardText, transport: "filePathUnreadable")
        }
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard fileSize >= 0, fileSize <= 1_000_000 else {
            return GhosttyScreenCopyText(text: pasteboardText, transport: "filePathTooLarge")
        }
        guard let fileText = try? String(contentsOf: url, encoding: .utf8) else {
            return GhosttyScreenCopyText(text: pasteboardText, transport: "filePathUnreadable")
        }
        return GhosttyScreenCopyText(text: fileText, transport: "screenFile")
    }

    private static func filePathAllowed(_ path: String) -> Bool {
        path.hasPrefix("/var/folders/")
            || path.hasPrefix("/private/var/folders/")
            || path.hasPrefix("/tmp/")
            || path.hasPrefix("/private/tmp/")
    }
}
