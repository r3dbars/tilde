import Foundation
import AutocompleteLabCore

/// Owns the cancellable model download task while AppDelegate owns app state and follow-up actions.
@MainActor
final class ModelInstallHost {
    private var task: Task<Void, Never>?
    private var cancelRequested = false

    var isInstalling: Bool {
        task != nil
    }

    func start(
        manifest: LocalModelAssetManifest,
        destinationURL: URL,
        onProgress: @escaping @MainActor @Sendable (String) -> Void,
        onSuccess: @escaping @MainActor @Sendable (URL) -> Void,
        onCancelled: @escaping @MainActor @Sendable () -> Void,
        onFailure: @escaping @MainActor @Sendable (String) -> Void
    ) {
        guard task == nil else {
            return
        }

        cancelRequested = false
        let installer = LocalModelAssetInstaller(
            manifest: manifest,
            destinationURL: destinationURL
        )
        task = Task { [weak self, installer] in
            do {
                let installedURL = try await installer.install { progress in
                    onProgress(progress.userFacingText)
                }

                await MainActor.run {
                    guard let self else {
                        return
                    }
                    self.task = nil
                    onSuccess(installedURL)
                }
            } catch {
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    let wasCancelled = error is CancellationError || self.cancelRequested
                    self.task = nil
                    self.cancelRequested = false
                    if wasCancelled {
                        onCancelled()
                    } else {
                        onFailure(error.localizedDescription)
                    }
                }
            }
        }
    }

    func cancel() {
        guard task != nil else {
            return
        }

        cancelRequested = true
        task?.cancel()
    }
}
