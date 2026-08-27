import Foundation

enum TildeInstallationLocation {
    static func requiresMove(bundleURL: URL, volumeIsReadOnly: Bool?) -> Bool {
        bundleURL.standardizedFileURL.path.hasPrefix("/Volumes/") || volumeIsReadOnly == true
    }

    static func requiresMove(bundleURL: URL = Bundle.main.bundleURL) -> Bool {
        let values = try? bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey])
        return requiresMove(bundleURL: bundleURL, volumeIsReadOnly: values?.volumeIsReadOnly)
    }
}
