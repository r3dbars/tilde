import Foundation
import AutocompleteLabCore

struct PersonalizationSelection: Sendable {
    let context: PersonalContext?
    let memory: PersonalWritingMemory?

    static let empty = PersonalizationSelection(context: nil, memory: nil)
}

@MainActor
final class PersonalizationCoordinator {
    private let indexer: PersonalWritingMemoryIndexer
    private let capturePolicy: PersonalCapturePolicy
    private let contextPolicy: PersonalizationContextPolicy
    private let rebuildDebounce: Duration
    private var rebuildTask: Task<Void, Never>?
    private var indexingIsEnabled = false
    private var cachedFieldKey: String?
    private var cachedContext: PersonalContext?
    private var cachedMemoryRevision: UInt64?

    init(
        indexer: PersonalWritingMemoryIndexer = .shared,
        capturePolicy: PersonalCapturePolicy = PersonalCapturePolicy(),
        contextPolicy: PersonalizationContextPolicy = PersonalizationContextPolicy(),
        rebuildDebounce: Duration = .seconds(45)
    ) {
        self.indexer = indexer
        self.capturePolicy = capturePolicy
        self.contextPolicy = contextPolicy
        self.rebuildDebounce = rebuildDebounce
    }

    func selection(
        isEnabled: Bool,
        context: FocusedTextContext,
        appBundleIdentifier: String,
        fieldClassification: AXFieldClassification,
        requestMode: CompletionRequestMode
    ) -> PersonalizationSelection {
        let captureDecision = capturePolicy.decision(for: PersonalCaptureInput(
            bundleIdentifier: appBundleIdentifier,
            role: context.role,
            subrole: context.subrole,
            fingerprint: context.fingerprint,
            isSecure: context.isSecure,
            fieldClassification: fieldClassification
        ))
        let snapshot = indexer.currentSnapshot()
        guard contextPolicy.allows(
            personalCaptureEnabled: isEnabled,
            captureDecision: captureDecision,
            requestMode: requestMode
        ), let memory = snapshot.memory else {
            return .empty
        }
        let fieldKey = "\(appBundleIdentifier)|\(context.elementIdentifier)"
        if cachedFieldKey == fieldKey,
           cachedMemoryRevision == snapshot.revision,
           let cachedContext {
            return PersonalizationSelection(context: cachedContext, memory: memory)
        }
        let personalContext = memory.personalContext(for: PersonalContextQuery(
            textBeforeCursor: context.textBeforeCursor,
            appBundleIdentifier: appBundleIdentifier
        ))
        cachedFieldKey = personalContext == nil ? nil : fieldKey
        cachedContext = personalContext
        cachedMemoryRevision = personalContext == nil ? nil : snapshot.revision
        return PersonalizationSelection(
            context: personalContext,
            memory: memory
        )
    }

    func refreshIndexing(isEnabled: Bool) {
        rebuildTask?.cancel()
        rebuildTask = nil
        indexingIsEnabled = isEnabled
        cachedFieldKey = nil
        cachedContext = nil
        cachedMemoryRevision = nil
        guard isEnabled else { return }
        indexer.rebuild()
    }

    func scheduleRebuildAfterAcceptedOrKeptText() {
        guard indexingIsEnabled else { return }
        rebuildTask?.cancel()
        rebuildTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.rebuildDebounce)
            guard !Task.isCancelled, self.indexingIsEnabled else { return }
            self.indexer.rebuild()
        }
    }

    func stop() {
        indexingIsEnabled = false
        rebuildTask?.cancel()
        rebuildTask = nil
    }

    func deleteAll() {
        stop()
        indexer.deleteAll()
    }
}
